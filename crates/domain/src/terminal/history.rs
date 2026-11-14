//! The commands run in a profile's terminals, remembered per repository:
//! what the history panel lists and what the terminal suggests as you type.

use std::path::{Path, PathBuf};

use super::CommandRun;
use crate::time::Timestamp;

/// Most commands remembered per repository (and outside them): the ones
/// run longest ago go first.
pub const HISTORY_LIMIT: usize = 5_000;

/// A command as remembered: the same line run again is the same entry.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HistoryEntry {
    pub command: String,
    pub runs: u32,
    pub last_run: Timestamp,
    /// Status of its last run, when the shell reported one.
    pub last_exit: Option<i32>,
    /// Where it last ran, when the shell said.
    pub last_cwd: Option<PathBuf>,
}

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum HistoryError {
    #[error("command history: {0}")]
    Storage(String),
}

/// Where the history is kept. `repo` is the repository's main checkout;
/// None is everything run outside one.
pub trait CommandHistoryStore: Send + Sync + 'static {
    /// Remembers `run`: a new entry, or one more run of the same line.
    /// Keeps at most [`HISTORY_LIMIT`] per repository.
    fn record(&self, repo: Option<&Path>, run: &CommandRun) -> Result<(), HistoryError>;

    /// The repository's commands, last run first.
    fn recent(&self, repo: Option<&Path>, limit: usize) -> Result<Vec<HistoryEntry>, HistoryError>;

    /// Forgets the repository's commands. Returns how many.
    fn forget(&self, repo: Option<&Path>) -> Result<usize, HistoryError>;

    /// Forgets every command. Returns how many.
    fn forget_all(&self) -> Result<usize, HistoryError>;
}

/// The repository a folder belongs to: its main checkout, also from inside
/// one of its worktrees.
pub trait RepoLocator: Send + Sync + 'static {
    fn repo_of(&self, dir: &Path) -> Option<PathBuf>;
}
