//! Ports implemented by the infrastructure layer. All of them block; the
//! application calls them off the async threads.

use std::path::{Path, PathBuf};

use super::{
    Branches, Namespace, NamespaceId, NewWorktree, Repo, WorkspaceError, Worktree, WorktreeStatus,
};

/// Read and change git repositories.
pub trait Git: Send + Sync + 'static {
    /// Canonical path of the main checkout of the repository at `path`
    /// (which can be any folder inside any of its worktrees).
    fn main_checkout(&self, path: &Path) -> Result<PathBuf, WorkspaceError>;
    /// URL of `origin`, or of the first remote.
    fn remote_url(&self, repo: &Path) -> Result<Option<String>, WorkspaceError>;
    /// Worktrees, main checkout first. Status is left empty.
    fn worktrees(&self, repo: &Path) -> Result<Vec<Worktree>, WorkspaceError>;
    fn status(&self, worktree: &Path) -> Result<WorktreeStatus, WorkspaceError>;
    /// A path that exists and isn't an empty folder is left alone:
    /// [`WorkspaceError::PathTaken`].
    fn add_worktree(&self, repo: &Path, worktree: &NewWorktree) -> Result<(), WorkspaceError>;
    /// Without `force`, a worktree with changes (ignored files aside) is
    /// left as is: [`WorkspaceError::HasChanges`].
    fn remove_worktree(
        &self,
        repo: &Path,
        worktree: &Path,
        force: bool,
    ) -> Result<(), WorkspaceError>;
    /// `git branch -d`: only a merged branch ([`WorkspaceError::BranchNotMerged`]
    /// otherwise).
    fn delete_branch(&self, repo: &Path, branch: &str) -> Result<(), WorkspaceError>;
    fn branches(&self, repo: &Path) -> Result<Branches, WorkspaceError>;
}

/// What the store keeps between runs.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct StoredWorkspace {
    /// In sidebar order.
    pub namespaces: Vec<Namespace>,
    pub repos: Vec<Repo>,
}

/// Persistence of namespaces and registered repositories.
pub trait WorkspaceStore: Send + Sync + 'static {
    fn load(&self) -> Result<StoredWorkspace, WorkspaceError>;
    /// Inserts or replaces the namespace at `position` (clamped).
    fn save_namespace(&self, namespace: &Namespace, position: usize) -> Result<(), WorkspaceError>;
    fn delete_namespace(&self, id: &NamespaceId) -> Result<(), WorkspaceError>;
    fn save_repo(&self, repo: &Repo) -> Result<(), WorkspaceError>;
}

/// Finds git repositories on disk.
pub trait RepoFinder: Send + Sync + 'static {
    /// Folders scanned when the client names none.
    fn default_roots(&self) -> Vec<PathBuf>;
    /// Repository folders under `roots` (not descending into repositories).
    fn find(&self, roots: &[PathBuf]) -> Vec<PathBuf>;
}
