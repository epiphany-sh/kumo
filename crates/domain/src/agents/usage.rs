//! What's left on an agent's plan and how full its context window is, as
//! the agent's own CLI reports them. Only what a CLI documents (or writes
//! in a stable format) is read: a number that can't be read is left out,
//! never estimated.

use std::path::PathBuf;

use super::{AgentError, AgentSessionId};
use crate::time::Timestamp;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UsageUnit {
    Percent,
    Requests,
    Dollars,
}

/// One limit of a plan, e.g. the 5-hour session or the weekly cap.
#[derive(Debug, Clone, PartialEq)]
pub struct UsageWindow {
    /// "5-hour session", "Weekly", "Spend limit · monthly".
    pub label: String,
    /// "5h", "wk", "mo".
    pub short: String,
    /// In `unit`s; percent: 0–100.
    pub left: f64,
    /// 100 for percent.
    pub of: f64,
    pub unit: UsageUnit,
    pub resets_at: Option<Timestamp>,
}

impl UsageWindow {
    /// A window the CLI reports as a used percentage.
    pub fn percent_used(
        label: impl Into<String>,
        short: impl Into<String>,
        used: f64,
        resets_at: Option<Timestamp>,
    ) -> Self {
        Self {
            label: label.into(),
            short: short.into(),
            left: (100.0 - used).clamp(0.0, 100.0),
            of: 100.0,
            unit: UsageUnit::Percent,
            resets_at,
        }
    }

    /// A rolling window named after its length, as the CLI states it:
    /// 300 → "5-hour session", 10080 → "Weekly".
    pub fn percent_over_minutes(minutes: u64, used: f64, resets_at: Option<Timestamp>) -> Self {
        let (label, short) = window_name(minutes);
        Self::percent_used(label, short, used, resets_at)
    }
}

/// Label and badge for a window of `minutes`.
fn window_name(minutes: u64) -> (String, String) {
    const HOUR: u64 = 60;
    const DAY: u64 = 24 * HOUR;
    match minutes {
        m if m == 7 * DAY => ("Weekly".into(), "wk".into()),
        m if m == DAY => ("Daily".into(), "day".into()),
        m if m % DAY == 0 => (format!("{}-day", m / DAY), format!("{}d", m / DAY)),
        m if m % HOUR == 0 => (
            format!("{}-hour session", m / HOUR),
            format!("{}h", m / HOUR),
        ),
        m => (format!("{m}-minute"), format!("{m}m")),
    }
}

/// What's left on one provider's plan. Plan limits are account-wide, so
/// the last reading stands for the provider until a newer one comes.
#[derive(Debug, Clone, PartialEq)]
pub struct PlanUsage {
    pub provider_id: String,
    /// "Claude Max", "ChatGPT Plus"; empty when the CLI doesn't say.
    pub plan: String,
    pub windows: Vec<UsageWindow>,
    /// Why it can't be read now; empty when fine.
    pub problem: String,
    pub read_at: Timestamp,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ContextSliceKind {
    /// Everything in the window, when there's no breakdown.
    Total,
    System,
    Files,
    Conversation,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ContextSlice {
    pub kind: ContextSliceKind,
    pub tokens: u64,
}

/// How full a session's context window is.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SessionUsage {
    pub session_id: AgentSessionId,
    /// Empty when unknown.
    pub model: String,
    /// 0 when unknown.
    pub context_max: u64,
    pub slices: Vec<ContextSlice>,
    /// 0 when unknown.
    pub turns: u32,
    /// What compacts its context; empty when it can't be compacted.
    pub compact_command: String,
    pub read_at: Timestamp,
}

/// Everything readable now. Empty when nothing is.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct UsageReport {
    pub plans: Vec<PlanUsage>,
    pub sessions: Vec<SessionUsage>,
}

/// The context window as one reading reports it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ContextReading {
    pub max: u64,
    pub tokens: u64,
}

/// The plan as one reading reports it.
#[derive(Debug, Clone, PartialEq)]
pub struct PlanReading {
    /// Empty when the CLI doesn't say.
    pub plan: String,
    pub windows: Vec<UsageWindow>,
}

/// What a session last reported. Each part is None when that report
/// didn't carry it (early in a session, right after a compaction): the
/// last good value stands.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct UsageReading {
    pub model: Option<String>,
    pub context: Option<ContextReading>,
    pub plan: Option<PlanReading>,
}

impl UsageReading {
    pub fn is_empty(&self) -> bool {
        self.model.is_none() && self.context.is_none() && self.plan.is_none()
    }

    /// `newer` over `self`, part by part.
    pub fn merged(self, newer: UsageReading) -> UsageReading {
        UsageReading {
            model: newer.model.or(self.model),
            context: newer.context.or(self.context),
            plan: newer.plan.or(self.plan),
        }
    }
}

/// The session a usage source reads for.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UsageTarget {
    pub session_id: AgentSessionId,
    pub worktree: PathBuf,
    pub started_at: Timestamp,
}

/// Reads one CLI's own reports of its usage. Blocks.
pub trait UsageSource: Send + Sync + 'static {
    /// The preset it reads (e.g. "claude").
    fn provider_id(&self) -> &str;
    /// Arguments to start the session with so that it reports, if any
    /// (prepends them to the CLI's own).
    fn launch_args(&self, target: &UsageTarget) -> Result<Vec<String>, AgentError>;
    /// What the session reported since the last call; None when nothing
    /// new or nothing readable.
    fn read(&self, target: &UsageTarget) -> Option<UsageReading>;
    /// The session is gone: drop what was kept for it.
    fn forget(&self, target: &UsageTarget);
}

/// Where the last plan readings are kept across restarts. Blocks.
pub trait PlanUsageStore: Send + Sync + 'static {
    fn load_plans(&self) -> Result<Vec<PlanUsage>, AgentError>;
    fn save_plan(&self, plan: &PlanUsage) -> Result<(), AgentError>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn windows_are_named_after_their_length() {
        let name = |m| {
            let w = UsageWindow::percent_over_minutes(m, 0.0, None);
            (w.label, w.short)
        };
        assert_eq!(name(300), ("5-hour session".into(), "5h".into()));
        assert_eq!(name(10080), ("Weekly".into(), "wk".into()));
        assert_eq!(name(1440), ("Daily".into(), "day".into()));
        assert_eq!(name(43200), ("30-day".into(), "30d".into()));
        assert_eq!(name(90), ("90-minute".into(), "90m".into()));
    }

    #[test]
    fn left_is_what_is_not_used_and_never_below_zero() {
        assert_eq!(UsageWindow::percent_used("x", "x", 23.5, None).left, 76.5);
        assert_eq!(UsageWindow::percent_used("x", "x", 112.0, None).left, 0.0);
    }

    #[test]
    fn a_newer_reading_keeps_what_it_lacks_from_the_older() {
        let older = UsageReading {
            model: Some("Opus".into()),
            context: Some(ContextReading {
                max: 200_000,
                tokens: 5_000,
            }),
            plan: None,
        };
        let newer = UsageReading {
            context: Some(ContextReading {
                max: 200_000,
                tokens: 9_000,
            }),
            ..UsageReading::default()
        };
        let merged = older.merged(newer);
        assert_eq!(merged.model.as_deref(), Some("Opus"));
        assert_eq!(merged.context.unwrap().tokens, 9_000);
    }
}
