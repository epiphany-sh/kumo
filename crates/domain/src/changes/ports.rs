//! Ports implemented by the infrastructure layer. They block; the
//! application calls them off the async threads.

use std::path::{Path, PathBuf};

use super::{
    ChangesError, CommitInfo, CommitOptions, DiffScope, FileContent, FileDiff, FileList,
    RelativePath, WorktreeChanges,
};

/// Git operations on one worktree (`worktree` is its absolute path).
pub trait GitChanges: Send + Sync + 'static {
    fn status(&self, worktree: &Path) -> Result<WorktreeChanges, ChangesError>;
    fn list_files(&self, worktree: &Path, limit: usize) -> Result<FileList, ChangesError>;
    fn diff(
        &self,
        worktree: &Path,
        path: &RelativePath,
        scope: DiffScope,
    ) -> Result<FileDiff, ChangesError>;
    fn stage(&self, worktree: &Path, paths: &[RelativePath]) -> Result<(), ChangesError>;
    fn unstage(&self, worktree: &Path, paths: &[RelativePath]) -> Result<(), ChangesError>;
    fn restore(&self, worktree: &Path, paths: &[RelativePath]) -> Result<(), ChangesError>;
    fn commit(&self, worktree: &Path, options: &CommitOptions) -> Result<CommitInfo, ChangesError>;
    fn push(&self, worktree: &Path) -> Result<(), ChangesError>;
    /// Updates the remote branches from the branch's remote (`origin` when
    /// it has no upstream).
    fn fetch(&self, worktree: &Path) -> Result<(), ChangesError>;
    /// Brings in the upstream's commits, only by fast-forward: it never
    /// creates a merge commit.
    fn pull(&self, worktree: &Path) -> Result<(), ChangesError>;
    fn undo_last_commit(&self, worktree: &Path) -> Result<(), ChangesError>;
    fn log(&self, worktree: &Path, limit: usize) -> Result<Vec<CommitInfo>, ChangesError>;
    /// Folders whose changes affect the status: the worktree and its git dir.
    fn watched_paths(&self, worktree: &Path) -> Result<Vec<PathBuf>, ChangesError>;
}

/// Reads and writes files inside a worktree, never outside it (symlinks
/// included).
pub trait FileStore: Send + Sync + 'static {
    fn read(
        &self,
        worktree: &Path,
        path: &RelativePath,
        max_bytes: usize,
    ) -> Result<FileContent, ChangesError>;
    fn write(&self, worktree: &Path, path: &RelativePath, bytes: &[u8])
    -> Result<(), ChangesError>;
    /// Renames or moves a file or folder, creating `to`'s folders. Fails
    /// when `to` already exists.
    fn rename(
        &self,
        worktree: &Path,
        from: &RelativePath,
        to: &RelativePath,
    ) -> Result<(), ChangesError>;
    /// Deletes a file, or a folder with everything in it.
    fn remove(&self, worktree: &Path, path: &RelativePath) -> Result<(), ChangesError>;
}

/// Keeps a watch alive; dropping it stops watching.
pub trait WatchGuard: Send {}

/// Calls `on_change` (from any thread) when something under `paths`
/// changes. Bursts are not coalesced here.
pub trait ChangeWatcher: Send + Sync + 'static {
    fn watch(
        &self,
        paths: &[PathBuf],
        on_change: Box<dyn Fn() + Send + Sync>,
    ) -> Result<Box<dyn WatchGuard>, ChangesError>;
}
