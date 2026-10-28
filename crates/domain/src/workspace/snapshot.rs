use super::{Namespace, Repo, Worktree};

/// A repository with what git last said about it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RepoState {
    pub repo: Repo,
    /// Main checkout first.
    pub worktrees: Vec<Worktree>,
    /// Why git could not be read (folder moved or deleted…).
    pub error: Option<String>,
}

/// Everything the UI shows about the workspace, pushed whole on every change.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct WorkspaceSnapshot {
    pub version: u64,
    pub namespaces: Vec<Namespace>,
    /// Repositories referenced by a namespace, in first-seen order.
    pub repos: Vec<RepoState>,
}
