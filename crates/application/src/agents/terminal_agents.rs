//! Agent CLIs started by hand in the profile's terminals (someone typed
//! `claude` in a shell): what's in each terminal's foreground, read on
//! output at most once a second, and its screen read like a session's.
//! What it runs on (model, effort) is read from its CLI's own files, as a
//! session's usage is, when its provider's usage is read.

use std::collections::HashSet;
use std::sync::{Arc, Weak};
use std::time::{Duration, Instant};

use futures::StreamExt;
use kumo_domain::agents::{
    ActivityTracker, AgentModel, AgentSessionId, AgentState, ProcessDetails, ProcessInspector,
    TerminalAgent, UsageReading, UsageSource, UsageTarget, agent_program,
};
use kumo_domain::terminal::{TerminalEvent, TerminalId, TerminalStatus};
use kumo_domain::time::Timestamp;

use super::AgentService;
use crate::terminal::Attachment;

/// New terminals are looked for this often.
const SCAN_EVERY: Duration = Duration::from_secs(2);
/// A terminal's foreground is read at most this often while it prints.
const CHECK_EVERY: Duration = Duration::from_secs(1);
/// …and this often while it's quiet.
const QUIET_CHECK_EVERY: Duration = Duration::from_secs(3);
const TICK: Duration = Duration::from_millis(250);
/// A new foreground that isn't an agent is read again for this long: right
/// after the fork, before its exec, it still looks like the shell.
const RECHECK_FOR: Duration = Duration::from_secs(5);
/// How long before it's seen a CLI may have started: its files are
/// matched by start time.
const STARTED_BEFORE: Duration = Duration::from_secs(10);

impl AgentService {
    /// Starts following the profile's terminals for agent CLIs started by
    /// hand. Stops once the service is gone.
    pub fn watch_terminals(self: &Arc<Self>, inspector: Arc<dyn ProcessInspector>) {
        tokio::spawn(scan(Arc::downgrade(self), inspector));
    }

    fn set_terminal_agent(&self, terminal: &TerminalId, agent: Option<TerminalAgent>) {
        let current = self
            .watch()
            .borrow()
            .terminal_agents
            .iter()
            .find(|a| &a.terminal == terminal)
            .cloned();
        if current == agent {
            return;
        }
        self.update_snapshot(|snapshot| {
            snapshot.terminal_agents.retain(|a| &a.terminal != terminal);
            if let Some(agent) = agent {
                snapshot.terminal_agents.push(agent);
            }
        });
    }

    /// Where `provider_id`'s model is read, when its usage is.
    async fn usage_source_for(&self, provider_id: &str) -> Option<Arc<dyn UsageSource>> {
        let providers = self.providers().await.ok()?;
        let view = providers
            .into_iter()
            .find(|v| v.provider.id == provider_id)?;
        self.usage_source(&view.provider)
    }

    /// The providers' programs, to tell a CLI by.
    async fn programs(&self) -> Vec<(String, String)> {
        self.providers()
            .await
            .unwrap_or_default()
            .into_iter()
            .map(|p| (p.provider.id, p.provider.program))
            .collect()
    }
}

async fn scan(service: Weak<AgentService>, inspector: Arc<dyn ProcessInspector>) {
    let mut followed: HashSet<TerminalId> = HashSet::new();
    loop {
        {
            let Some(service) = service.upgrade() else {
                return;
            };
            let sessions: HashSet<TerminalId> =
                service.sessions().into_iter().map(|s| s.terminal).collect();
            for info in service.terminals.list() {
                let running = matches!(info.status, TerminalStatus::Running);
                if !running || sessions.contains(&info.id) || followed.contains(&info.id) {
                    continue;
                }
                let Ok(attachment) = service.terminals.attach(&info.id, false) else {
                    continue;
                };
                followed.insert(info.id.clone());
                tokio::spawn(follow(
                    Arc::downgrade(&service),
                    info.id,
                    attachment,
                    Arc::clone(&inspector),
                ));
            }
            // Gone terminals can be followed again (ids aren't reused).
            let alive: HashSet<TerminalId> =
                service.terminals.list().into_iter().map(|i| i.id).collect();
            followed.retain(|id| alive.contains(id));
        }
        tokio::time::sleep(SCAN_EVERY).await;
    }
}

/// Reads what a CLI started by hand runs on.
struct ModelReader {
    source: Arc<dyn UsageSource>,
    target: UsageTarget,
    reading: UsageReading,
}

impl ModelReader {
    async fn start(
        service: &AgentService,
        provider_id: &str,
        pid: u32,
        cwd: &std::path::Path,
    ) -> Option<Self> {
        let source = service.usage_source_for(provider_id).await?;
        let now = Timestamp::now().as_unix_nanos();
        let before = u64::try_from(STARTED_BEFORE.as_nanos()).unwrap_or(0);
        Some(Self {
            source,
            target: UsageTarget {
                session_id: AgentSessionId::generate(),
                worktree: cwd.to_owned(),
                started_at: Timestamp::from_unix_nanos(now.saturating_sub(before)),
                pid: Some(pid),
            },
            reading: UsageReading::default(),
        })
    }

    async fn read(&mut self) -> AgentModel {
        let (source, target) = (Arc::clone(&self.source), self.target.clone());
        if let Ok(Some(new)) = tokio::task::spawn_blocking(move || source.read(&target)).await {
            self.reading = std::mem::take(&mut self.reading).merged(new);
        }
        self.reading.agent_model()
    }

    fn stop(self) {
        tokio::task::spawn_blocking(move || self.source.forget(&self.target));
    }
}

/// What a terminal's foreground was last time: its pid, and the agent CLI
/// it is (provider id, program, folder), if one.
struct Seen {
    pid: Option<u32>,
    agent: Option<(String, String, std::path::PathBuf)>,
    /// When this pid came to the foreground.
    since: Instant,
}

async fn follow(
    service: Weak<AgentService>,
    terminal: TerminalId,
    attachment: Attachment,
    inspector: Arc<dyn ProcessInspector>,
) {
    let Attachment { session, output } = attachment;
    let mut events = Box::pin(output.into_stream());
    let mut ticker = tokio::time::interval(TICK);
    let mut seen = Seen {
        pid: None,
        agent: None,
        since: Instant::now(),
    };
    let mut tracker: Option<ActivityTracker> = None;
    let mut agent: Option<TerminalAgent> = None;
    // The pid it was started for, and the reader if its usage is read.
    let mut model_reader: Option<(u32, Option<ModelReader>)> = None;
    let mut checked = Instant::now()
        .checked_sub(QUIET_CHECK_EVERY)
        .unwrap_or_else(Instant::now);
    loop {
        let printed = tokio::select! {
            event = events.next() => match event {
                Some(TerminalEvent::Output(batch)) => {
                    if let Some(tracker) = tracker.as_mut() {
                        super::monitor::read_input(tracker, &session);
                        tracker.on_output(&batch.data, Instant::now());
                    }
                    true
                }
                Some(TerminalEvent::Exited(_)) | None => break,
            },
            _ = ticker.tick() => {
                if let Some(tracker) = tracker.as_mut() {
                    super::monitor::read_input(tracker, &session);
                    tracker.tick(Instant::now());
                }
                false
            }
        };
        let Some(service) = service.upgrade() else {
            return;
        };
        let due = if printed {
            CHECK_EVERY
        } else {
            QUIET_CHECK_EVERY
        };
        if checked.elapsed() >= due {
            checked = Instant::now();
            let pid = session.foreground();
            let new = pid != seen.pid;
            if new || (seen.agent.is_none() && pid.is_some() && seen.since.elapsed() < RECHECK_FOR)
            {
                let details: Option<ProcessDetails> = match pid {
                    Some(pid) => {
                        let inspector = Arc::clone(&inspector);
                        tokio::task::spawn_blocking(move || inspector.inspect(pid))
                            .await
                            .ok()
                            .flatten()
                    }
                    None => None,
                };
                let agent = match details {
                    Some(d) => {
                        let programs = service.programs().await;
                        agent_program(&d.exe.display().to_string(), &d.args, &programs)
                            .map(|(id, program)| (id.clone(), program.clone(), d.cwd))
                    }
                    None => None,
                };
                seen = Seen {
                    pid,
                    agent,
                    since: if new { Instant::now() } else { seen.since },
                };
            }
            let pid = seen.pid.filter(|_| seen.agent.is_some());
            if model_reader.as_ref().map(|(p, _)| *p) != pid {
                if let Some((_, Some(old))) = model_reader.take() {
                    old.stop();
                }
                if let (Some(pid), Some((provider_id, _, cwd))) = (pid, &seen.agent) {
                    model_reader = Some((
                        pid,
                        ModelReader::start(&service, provider_id, pid, cwd).await,
                    ));
                }
            }
            let model = match model_reader.as_mut() {
                Some((_, Some(reader))) => reader.read().await,
                _ => AgentModel::default(),
            };
            match &seen.agent {
                Some((provider_id, program, cwd)) => {
                    if tracker.is_none() {
                        tracker = Some(ActivityTracker::new(Instant::now(), service.quiet_after));
                    }
                    agent = Some(TerminalAgent {
                        terminal: terminal.clone(),
                        provider_id: provider_id.clone(),
                        program: program.rsplit('/').next().unwrap_or(program).to_owned(),
                        cwd: cwd.clone(),
                        state: AgentState::Working,
                        busy: true,
                        model,
                    });
                }
                None => {
                    tracker = None;
                    agent = None;
                }
            }
        }
        let shown = agent.clone().map(|mut a| {
            if let Some(tracker) = &tracker {
                a.state = if tracker.asked() {
                    AgentState::NeedsInput
                } else {
                    AgentState::Working
                };
                a.busy = tracker.state() == AgentState::Working;
            }
            a
        });
        service.set_terminal_agent(&terminal, shown);
    }
    if let Some((_, Some(reader))) = model_reader {
        reader.stop();
    }
    if let Some(service) = service.upgrade() {
        service.set_terminal_agent(&terminal, None);
    }
}
