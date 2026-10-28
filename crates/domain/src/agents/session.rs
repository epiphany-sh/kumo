use std::fmt;
use std::path::PathBuf;

use crate::terminal::{ExitStatus, TerminalId};
use crate::time::Timestamp;

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct AgentSessionId(String);

impl AgentSessionId {
    pub fn generate() -> Self {
        Self(uuid::Uuid::new_v4().simple().to_string())
    }

    pub fn parse(raw: &str) -> Option<Self> {
        let raw = raw.trim();
        (!raw.is_empty()).then(|| Self(raw.to_owned()))
    }
}

impl fmt::Display for AgentSessionId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// What an agent is doing, as seen from its terminal.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AgentState {
    Working,
    /// Quiet, or it asked for attention (bell / notification).
    NeedsInput,
    Exited(ExitStatus),
}

/// An agent running (or that ran) in a worktree, in its own terminal.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AgentSession {
    pub id: AgentSessionId,
    pub provider_id: String,
    pub provider_name: String,
    pub short: String,
    pub worktree: PathBuf,
    pub terminal: TerminalId,
    pub title: String,
    pub prompt: String,
    pub state: AgentState,
    pub started_at: Timestamp,
    pub state_since: Timestamp,
    pub last_line: String,
}

impl AgentSession {
    /// The card title: the given one, else the prompt's first line, else
    /// the agent's name.
    pub fn title_for(title: &str, prompt: &str, provider_name: &str) -> String {
        let title = title.trim();
        if !title.is_empty() {
            return title.to_owned();
        }
        match prompt.lines().map(str::trim).find(|l| !l.is_empty()) {
            Some(line) if line.chars().count() > 80 => {
                format!("{}…", line.chars().take(79).collect::<String>())
            }
            Some(line) => line.to_owned(),
            None => provider_name.to_owned(),
        }
    }
}
