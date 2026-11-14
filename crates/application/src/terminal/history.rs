//! The commands run in a profile's shells, remembered per repository.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use kumo_domain::terminal::{
    CommandHistoryStore, CommandRun, HistoryEntry, HistoryError, RepoLocator,
};

/// A repository's commands, last run first.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RepoHistory {
    /// Its main checkout; None for what ran outside a repository.
    pub repo: Option<PathBuf>,
    pub entries: Vec<HistoryEntry>,
}

/// What a profile's shells ran, kept by the repository they ran in: its
/// worktrees share it (`cargo test` is as good in each).
#[derive(Clone)]
pub struct CommandHistory {
    store: Arc<dyn CommandHistoryStore>,
    repos: Arc<dyn RepoLocator>,
}

impl std::fmt::Debug for CommandHistory {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("CommandHistory").finish_non_exhaustive()
    }
}

impl CommandHistory {
    pub fn new(store: Arc<dyn CommandHistoryStore>, repos: Arc<dyn RepoLocator>) -> Self {
        Self { store, repos }
    }

    fn repo_of(&self, dir: Option<&Path>) -> Option<PathBuf> {
        dir.and_then(|dir| self.repos.repo_of(dir))
    }

    /// Remembers `run` in the repository it ran in. Blocking.
    pub fn record(&self, run: &CommandRun) -> Result<(), HistoryError> {
        let repo = self.repo_of(run.cwd.as_deref());
        self.store.record(repo.as_deref(), run)
    }

    /// The commands of the repository `dir` is in. Blocking.
    pub fn recent(&self, dir: Option<&Path>, limit: usize) -> Result<RepoHistory, HistoryError> {
        let repo = self.repo_of(dir);
        let entries = self.store.recent(repo.as_deref(), limit)?;
        Ok(RepoHistory { repo, entries })
    }

    /// Forgets the commands of the repository `dir` is in. Blocking.
    pub fn forget(&self, dir: Option<&Path>) -> Result<usize, HistoryError> {
        let repo = self.repo_of(dir);
        self.store.forget(repo.as_deref())
    }

    /// Forgets every command. Blocking.
    pub fn forget_all(&self) -> Result<usize, HistoryError> {
        self.store.forget_all()
    }
}
