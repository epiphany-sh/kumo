use std::fmt;
use std::path::PathBuf;

use crate::time::Timestamp;

/// Messages are written for the user: they reach the UI as is.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum TodoError {
    #[error("unknown TODO: {0}")]
    Unknown(String),
    #[error("{0}")]
    Invalid(String),
    #[error("TODO storage failed: {0}")]
    Store(String),
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct TodoId(String);

impl TodoId {
    pub fn generate() -> Self {
        Self(uuid::Uuid::new_v4().simple().to_string())
    }

    /// Ids come from the store, the UI or an agent's `KUMO_TODO`.
    pub fn parse(raw: &str) -> Result<Self, TodoError> {
        let raw = raw.trim();
        if raw.is_empty()
            || raw.len() > 64
            || !raw.chars().all(|c| c.is_ascii_alphanumeric() || c == '-')
        {
            return Err(TodoError::Unknown(raw.to_owned()));
        }
        Ok(Self(raw.to_owned()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for TodoId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// Where a TODO is. The agent moves it through working, testing and review;
/// the user approves (pushed) and opens the pull request; Kumo sees it merge.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum TodoStatus {
    /// Not handed to an agent yet.
    Open,
    Working,
    Testing,
    /// The agent is done and its tests pass: the user's turn.
    Review,
    Pushed,
    PullRequest,
    Merged,
}

impl TodoStatus {
    pub const ALL: [TodoStatus; 7] = [
        TodoStatus::Open,
        TodoStatus::Working,
        TodoStatus::Testing,
        TodoStatus::Review,
        TodoStatus::Pushed,
        TodoStatus::PullRequest,
        TodoStatus::Merged,
    ];

    /// The word an agent types: `kumod todo testing`.
    pub fn word(self) -> &'static str {
        match self {
            TodoStatus::Open => "open",
            TodoStatus::Working => "working",
            TodoStatus::Testing => "testing",
            TodoStatus::Review => "review",
            TodoStatus::Pushed => "pushed",
            TodoStatus::PullRequest => "pr",
            TodoStatus::Merged => "merged",
        }
    }

    pub fn from_word(word: &str) -> Option<Self> {
        let word = word.trim().to_ascii_lowercase();
        Self::ALL.into_iter().find(|s| s.word() == word)
    }

    /// The ones an agent may report itself. Pushing needs the user's
    /// approval, and the pull request and its merge are Kumo's to see.
    pub fn agent_may_report(self) -> bool {
        matches!(
            self,
            TodoStatus::Working | TodoStatus::Testing | TodoStatus::Review
        )
    }
}

impl fmt::Display for TodoStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.word())
    }
}

/// When it reached a status, who moved it there, and what they said.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TodoStep {
    pub status: TodoStatus,
    /// An agent's name, "You" or "Kumo".
    pub by: String,
    pub at: Timestamp,
    pub note: String,
}

/// Where a TODO runs once handed to an agent.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct TodoRun {
    pub repo_path: PathBuf,
    pub worktree_path: PathBuf,
    pub branch: String,
    pub base: String,
    pub provider_id: String,
    pub agent_name: String,
    pub model: String,
    pub effort: String,
    /// The agent session on it; empty once it's gone.
    pub session_id: String,
    pub pr_number: u64,
    pub pr_url: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Todo {
    pub id: TodoId,
    pub title: String,
    pub notes: String,
    /// The repository it's about; None: any.
    pub repo_path: Option<PathBuf>,
    pub done: bool,
    pub created: Timestamp,
    pub run: Option<TodoRun>,
    /// Oldest first; empty while open.
    pub steps: Vec<TodoStep>,
}

/// Longest title kept: a TODO is a line, its notes hold the rest.
const MAX_TITLE: usize = 500;

impl Todo {
    pub fn new(
        title: &str,
        notes: &str,
        repo_path: Option<PathBuf>,
        now: Timestamp,
    ) -> Result<Self, TodoError> {
        Ok(Self {
            id: TodoId::generate(),
            title: Self::checked_title(title)?,
            notes: notes.trim_end().to_owned(),
            repo_path,
            done: false,
            created: now,
            run: None,
            steps: Vec::new(),
        })
    }

    pub fn checked_title(title: &str) -> Result<String, TodoError> {
        let title = title.trim();
        if title.is_empty() {
            return Err(TodoError::Invalid("a TODO needs a title".into()));
        }
        Ok(title.chars().take(MAX_TITLE).collect())
    }

    /// The current status: the last step's, or open.
    pub fn status(&self) -> TodoStatus {
        self.steps.last().map_or(TodoStatus::Open, |s| s.status)
    }

    /// Moves it to `status`. Going back (the user asked for changes) drops
    /// the steps after it, so the record reads as what happened last.
    /// Open forgets the run when `clear_run`.
    pub fn move_to(&mut self, step: TodoStep, clear_run: bool) -> Result<(), TodoError> {
        if step.status == TodoStatus::Open {
            self.steps.clear();
            if clear_run {
                self.run = None;
            }
            return Ok(());
        }
        if self.run.is_none() {
            return Err(TodoError::Invalid(
                "hand it to an agent first: it has no worktree yet".into(),
            ));
        }
        self.steps.retain(|s| s.status < step.status);
        self.steps.push(step);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn step(status: TodoStatus, by: &str) -> TodoStep {
        TodoStep {
            status,
            by: by.into(),
            at: Timestamp::from_unix_nanos(1),
            note: String::new(),
        }
    }

    fn running() -> Todo {
        let mut todo = Todo::new(
            "  Retry on rate limits ",
            "",
            None,
            Timestamp::from_unix_nanos(0),
        )
        .unwrap();
        todo.run = Some(TodoRun {
            branch: "fix/retry".into(),
            ..TodoRun::default()
        });
        todo
    }

    #[test]
    fn a_title_is_trimmed_and_required() {
        assert_eq!(running().title, "Retry on rate limits");
        assert!(Todo::new("   ", "", None, Timestamp::now()).is_err());
    }

    #[test]
    fn ids_are_plain_words() {
        assert!(TodoId::parse("0f3a9c-x").is_ok());
        assert!(TodoId::parse("../etc").is_err());
        assert!(TodoId::parse("").is_err());
    }

    #[test]
    fn statuses_read_from_the_words_agents_type() {
        for status in TodoStatus::ALL {
            assert_eq!(TodoStatus::from_word(status.word()), Some(status));
        }
        assert_eq!(
            TodoStatus::from_word(" Testing "),
            Some(TodoStatus::Testing)
        );
        assert_eq!(TodoStatus::from_word("done"), None);
        assert!(TodoStatus::Review.agent_may_report());
        assert!(!TodoStatus::Pushed.agent_may_report());
        assert!(!TodoStatus::Merged.agent_may_report());
    }

    #[test]
    fn moving_back_drops_the_later_steps() {
        let mut todo = running();
        for s in [TodoStatus::Working, TodoStatus::Testing, TodoStatus::Review] {
            todo.move_to(step(s, "Claude Code"), false).unwrap();
        }
        assert_eq!(todo.status(), TodoStatus::Review);
        // Asked for changes: working again, testing and review are gone.
        todo.move_to(step(TodoStatus::Working, "Claude Code"), false)
            .unwrap();
        assert_eq!(todo.steps.len(), 1);
        assert_eq!(todo.status(), TodoStatus::Working);
    }

    #[test]
    fn a_status_needs_a_run_and_open_can_forget_it() {
        let mut todo = Todo::new("x", "", None, Timestamp::now()).unwrap();
        assert!(
            todo.move_to(step(TodoStatus::Working, "You"), false)
                .is_err()
        );
        let mut todo = running();
        todo.move_to(step(TodoStatus::Merged, "Kumo"), false)
            .unwrap();
        todo.move_to(step(TodoStatus::Open, "You"), true).unwrap();
        assert_eq!(todo.status(), TodoStatus::Open);
        assert!(todo.run.is_none());
    }
}
