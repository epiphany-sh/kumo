//! Agent CLIs started by hand in the profile's terminals (someone typed
//! `claude` in a shell): what's in each terminal's foreground, read on
//! output at most once a second, and its screen read like a session's.

use std::collections::HashSet;
use std::sync::{Arc, Weak};
use std::time::{Duration, Instant};

use futures::StreamExt;
use kumo_domain::agents::{
    ActivityTracker, AgentState, ProcessDetails, ProcessInspector, TerminalAgent, agent_program,
};
use kumo_domain::terminal::{TerminalEvent, TerminalId, TerminalStatus};

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
    if let Some(service) = service.upgrade() {
        service.set_terminal_agent(&terminal, None);
    }
}
