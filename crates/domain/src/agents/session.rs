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
    /// What it was given to work from, in the order it got it.
    pub context: Vec<AgentContext>,
    /// What it did, oldest first; the last [`AgentSession::MAX_EVENTS`].
    pub events: Vec<AgentEvent>,
}

/// Where a piece of context came from.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ContextKind {
    Task,
    Doc,
    /// Code selected in a file.
    Code,
}

/// A ticket or page an agent was given.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AgentContext {
    pub kind: ContextKind,
    /// e.g. "PRC-412 · Bulk discounts by category".
    pub title: String,
    /// Where it lives, e.g. "Jira" or "Confluence · Pricing".
    pub detail: String,
    pub url: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AgentEventKind {
    Started,
    Edited,
    Ran,
    Read,
    Searched,
    /// Another tool, named in the text.
    Tool,
    /// Its turn ended; the text is what it said last.
    Waiting,
    /// It was sent a ticket or page.
    Context,
    /// The process ended; the text says how.
    Exited,
}

/// One step of an agent's timeline.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AgentEvent {
    pub at: Timestamp,
    pub kind: AgentEventKind,
    pub text: String,
}

impl AgentSession {
    pub const MAX_EVENTS: usize = 80;

    /// Adds a step to the timeline. Waiting twice in a row (nothing done
    /// in between) is one step, updated.
    pub fn record(&mut self, kind: AgentEventKind, text: String, at: Timestamp) {
        if kind == AgentEventKind::Waiting
            && let Some(last) = self.events.last_mut()
            && last.kind == AgentEventKind::Waiting
        {
            last.at = at;
            last.text = text;
            return;
        }
        self.events.push(AgentEvent { at, kind, text });
        if self.events.len() > Self::MAX_EVENTS {
            let extra = self.events.len() - Self::MAX_EVENTS;
            self.events.drain(..extra);
        }
    }

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
