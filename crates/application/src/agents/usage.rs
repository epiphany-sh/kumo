//! Follows what agents report about their usage: the latest plan reading
//! per provider (account-wide, so it outlives sessions) and the latest
//! context reading per session.

use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;

use kumo_domain::agents::{
    AgentSession, AgentSessionId, AgentState, ContextSlice, ContextSliceKind, PlanUsage,
    SessionUsage, UsageReading, UsageReport, UsageSource, UsageTarget,
};
use kumo_domain::time::Timestamp;

use super::service::{AgentService, ProviderView};

/// How often a session's reports are read. Claude Code updates its
/// status line at most every 300 ms; Codex writes once per turn.
const POLL: Duration = Duration::from_secs(2);

#[derive(Debug, Default)]
pub(super) struct UsageState {
    plans_loaded: bool,
    plans: HashMap<String, PlanUsage>,
    sessions: HashMap<AgentSessionId, Followed>,
}

#[derive(Debug)]
struct Followed {
    target: UsageTarget,
    reading: UsageReading,
    read_at: Option<Timestamp>,
}

impl UsageState {
    pub(super) fn plans_loaded(&self) -> bool {
        self.plans_loaded
    }

    /// Readings saved by an earlier run; newer ones read since win.
    pub(super) fn restore(&mut self, saved: Vec<PlanUsage>) {
        self.plans_loaded = true;
        for plan in saved {
            let newer = self
                .plans
                .get(&plan.provider_id)
                .is_some_and(|p| p.read_at >= plan.read_at);
            if !newer {
                self.plans.insert(plan.provider_id.clone(), plan);
            }
        }
    }

    pub(super) fn follow(&mut self, target: UsageTarget) {
        self.sessions.insert(
            target.session_id.clone(),
            Followed {
                target,
                reading: UsageReading::default(),
                read_at: None,
            },
        );
    }

    /// Stops following a session; what its source needs to clean up.
    pub(super) fn forget(&mut self, id: &AgentSessionId) -> Option<UsageTarget> {
        self.sessions.remove(id).map(|f| f.target)
    }

    /// Takes in a new reading of `provider_id`'s session `id`. Returns the
    /// plan to save when it carried one.
    pub(super) fn record(
        &mut self,
        provider_id: &str,
        id: &AgentSessionId,
        reading: UsageReading,
        now: Timestamp,
    ) -> Option<PlanUsage> {
        let followed = self.sessions.get_mut(id)?;
        let plan = reading.plan.clone();
        followed.reading = std::mem::take(&mut followed.reading).merged(reading);
        followed.read_at = Some(now);
        let plan = PlanUsage {
            provider_id: provider_id.to_owned(),
            plan: plan.as_ref()?.plan.clone(),
            windows: plan?.windows,
            problem: String::new(),
            read_at: now,
        };
        self.plans.insert(provider_id.to_owned(), plan.clone());
        Some(plan)
    }

    /// Plans of connected providers whose usage is read (windows past their
    /// reset dropped: what they said no longer holds), and the sessions
    /// that reported something.
    pub(super) fn report(
        &self,
        providers: &[ProviderView],
        sessions: &[AgentSession],
        now: Timestamp,
    ) -> UsageReport {
        let reads = |id: &str| {
            providers
                .iter()
                .find(|v| v.provider.id == id)
                .filter(|v| v.provider.enabled && v.provider.reads_usage())
        };
        let mut plans: Vec<PlanUsage> = self
            .plans
            .values()
            .filter(|plan| reads(&plan.provider_id).is_some())
            .filter_map(|plan| {
                let windows: Vec<_> = plan
                    .windows
                    .iter()
                    .filter(|w| w.resets_at.is_none_or(|at| at > now))
                    .cloned()
                    .collect();
                (!windows.is_empty()).then(|| PlanUsage {
                    windows,
                    ..plan.clone()
                })
            })
            .collect();
        // In the order the providers are listed.
        plans.sort_by_key(|plan| {
            providers
                .iter()
                .position(|v| v.provider.id == plan.provider_id)
        });
        let sessions = sessions
            .iter()
            .filter_map(|session| {
                let followed = self.sessions.get(&session.id)?;
                let reading = &followed.reading;
                if reading.model.is_none() && reading.context.is_none() {
                    return None;
                }
                let running = !matches!(session.state, AgentState::Exited(_));
                let compact_command = providers
                    .iter()
                    .find(|v| v.provider.id == session.provider_id)
                    .and_then(|v| v.provider.compact_command())
                    .filter(|_| running)
                    .unwrap_or_default()
                    .to_owned();
                Some(SessionUsage {
                    session_id: session.id.clone(),
                    model: reading.model.clone().unwrap_or_default(),
                    context_max: reading.context.map_or(0, |c| c.max),
                    // No breakdown by kind is reported: one total.
                    slices: reading
                        .context
                        .map(|c| ContextSlice {
                            kind: ContextSliceKind::Total,
                            tokens: c.tokens,
                        })
                        .into_iter()
                        .collect(),
                    turns: 0,
                    compact_command,
                    read_at: followed.read_at.unwrap_or(now),
                })
            })
            .collect();
        UsageReport { plans, sessions }
    }
}

/// `args` with what `source` needs to read the session in front; as they
/// were if it can't (a session never fails to start over its usage), or
/// if the user's own arguments already set what it would.
pub(super) async fn launch_args(
    source: &Arc<dyn UsageSource>,
    target: &UsageTarget,
    args: Vec<String>,
) -> Vec<String> {
    let (source, target) = (Arc::clone(source), target.clone());
    let extra = match tokio::task::spawn_blocking(move || source.launch_args(&target)).await {
        Ok(Ok(extra)) => extra,
        Ok(Err(e)) => {
            tracing::warn!(error = %e, "agent usage won't be read");
            return args;
        }
        Err(_) => return args,
    };
    if extra
        .first()
        .is_some_and(|flag| args.iter().any(|a| a == flag))
    {
        return args;
    }
    extra.into_iter().chain(args).collect()
}

/// Reads the session's reports until it's dismissed, or once more after
/// it exits.
pub(super) async fn follow(
    service: Arc<AgentService>,
    target: UsageTarget,
    source: Arc<dyn UsageSource>,
) {
    let provider_id = source.provider_id().to_owned();
    let mut ticker = tokio::time::interval(POLL);
    loop {
        ticker.tick().await;
        let Some(state) = service.state_of(&target.session_id) else {
            break;
        };
        let (reader, read_for) = (Arc::clone(&source), target.clone());
        if let Ok(Some(reading)) = tokio::task::spawn_blocking(move || reader.read(&read_for)).await
        {
            let plan = service.usage_lock().record(
                &provider_id,
                &target.session_id,
                reading,
                Timestamp::now(),
            );
            if let Some(plan) = plan {
                service.save_plan(plan).await;
            }
        }
        if matches!(state, AgentState::Exited(_)) {
            break;
        }
    }
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use kumo_domain::agents::{
        AgentPreset, AgentProvider, ContextReading, PlanReading, UsageWindow,
    };
    use kumo_domain::terminal::{ExitStatus, TerminalId};

    use super::*;

    fn at(secs: u64) -> Timestamp {
        Timestamp::from_unix_nanos(secs * 1_000_000_000)
    }

    fn provider(id: &str, enabled: bool) -> ProviderView {
        ProviderView {
            provider: AgentProvider {
                enabled,
                ..AgentProvider::from_preset(AgentPreset::find(id).unwrap())
            },
            resolved: None,
        }
    }

    fn session(id: &str, provider: &str, state: AgentState) -> AgentSession {
        AgentSession {
            id: AgentSessionId::parse(id).unwrap(),
            provider_id: provider.into(),
            provider_name: provider.into(),
            short: "XX".into(),
            worktree: PathBuf::from("/wt"),
            terminal: TerminalId::generate(),
            title: String::new(),
            prompt: String::new(),
            state,
            started_at: at(0),
            state_since: at(0),
            last_line: String::new(),
            context: Vec::new(),
            events: Vec::new(),
        }
    }

    fn target(id: &str) -> UsageTarget {
        UsageTarget {
            session_id: AgentSessionId::parse(id).unwrap(),
            worktree: PathBuf::from("/wt"),
            started_at: at(0),
        }
    }

    fn reading(resets_at: u64) -> UsageReading {
        UsageReading {
            model: Some("Opus".into()),
            context: Some(ContextReading {
                max: 200_000,
                tokens: 15_500,
            }),
            plan: Some(PlanReading {
                plan: String::new(),
                windows: vec![
                    UsageWindow::percent_over_minutes(300, 23.5, Some(at(resets_at))),
                    UsageWindow::percent_over_minutes(10_080, 41.2, None),
                ],
            }),
        }
    }

    #[test]
    fn nothing_read_is_an_empty_report() {
        let state = UsageState::default();
        let report = state.report(
            &[provider("claude", true), provider("gemini", true)],
            &[session("s1", "gemini", AgentState::Working)],
            at(10),
        );
        assert_eq!(report, UsageReport::default());

        // Followed, but it hasn't reported anything yet.
        let mut state = UsageState::default();
        state.follow(target("s1"));
        let report = state.report(
            &[provider("claude", true)],
            &[session("s1", "claude", AgentState::Working)],
            at(10),
        );
        assert_eq!(report, UsageReport::default());
    }

    #[test]
    fn reports_the_plan_and_the_session_as_last_read() {
        let mut state = UsageState::default();
        state.follow(target("s1"));
        let saved = state
            .record("claude", &target("s1").session_id, reading(1_000), at(10))
            .unwrap();
        assert_eq!((saved.windows.len(), saved.read_at), (2, at(10)));
        // A later report without the plan or context keeps them.
        assert_eq!(
            state.record(
                "claude",
                &target("s1").session_id,
                UsageReading::default(),
                at(20)
            ),
            None
        );

        let providers = [provider("claude", true)];
        let report = state.report(
            &providers,
            &[session("s1", "claude", AgentState::NeedsInput)],
            at(30),
        );
        assert_eq!(report.plans.len(), 1);
        assert_eq!(report.plans[0].read_at, at(10));
        let s = &report.sessions[0];
        assert_eq!(
            (s.model.as_str(), s.context_max, s.compact_command.as_str()),
            ("Opus", 200_000, "/compact")
        );
        assert_eq!(
            s.slices,
            [ContextSlice {
                kind: ContextSliceKind::Total,
                tokens: 15_500
            }]
        );

        // Past the 5-hour reset its numbers no longer hold.
        let later = state.report(&providers, &[], at(2_000));
        assert_eq!(later.plans[0].windows.len(), 1);
        assert!(later.sessions.is_empty());
        // A finished session can't be compacted.
        let done = state.report(
            &providers,
            &[session(
                "s1",
                "claude",
                AgentState::Exited(ExitStatus::new(0)),
            )],
            at(30),
        );
        assert_eq!(done.sessions[0].compact_command, "");
    }

    #[test]
    fn disconnected_or_turned_off_providers_show_no_plan() {
        let mut state = UsageState::default();
        state.restore(vec![PlanUsage {
            provider_id: "claude".into(),
            plan: String::new(),
            windows: reading(1_000).plan.unwrap().windows,
            problem: String::new(),
            read_at: at(5),
        }]);
        assert_eq!(
            state
                .report(&[provider("claude", true)], &[], at(10))
                .plans
                .len(),
            1
        );
        assert!(
            state
                .report(&[provider("claude", false)], &[], at(10))
                .plans
                .is_empty()
        );
        let mut off = provider("claude", true);
        off.provider.read_usage = false;
        assert!(state.report(&[off], &[], at(10)).plans.is_empty());
    }

    #[test]
    fn a_newer_reading_wins_over_the_saved_one() {
        let mut state = UsageState::default();
        state.follow(target("s1"));
        state.record("codex", &target("s1").session_id, reading(9_000), at(50));
        state.restore(vec![PlanUsage {
            provider_id: "codex".into(),
            plan: "old".into(),
            windows: Vec::new(),
            problem: String::new(),
            read_at: at(5),
        }]);
        assert!(state.plans_loaded());
        assert_eq!(state.plans["codex"].read_at, at(50));
    }
}
