use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;

use kumo_domain::changes::{
    ChangeWatcher, ChangesError, CommitInfo, CommitOptions, DiffScope, FileContent, FileDiff,
    FileList, FileStore, GitChanges, RelativePath, WorktreeChanges,
};
use tokio::sync::mpsc;

use crate::workspace::WorkspaceService;

/// Files read at once; bigger ones come back truncated.
const MAX_READ_BYTES: usize = 2 * 1024 * 1024;
/// Files listed at once.
const MAX_LISTED_FILES: usize = 50_000;
/// Saving a file or a git command touches many files: wait for the burst
/// to settle before reading the status again.
const SETTLE: Duration = Duration::from_millis(150);

/// The adapters the service works with.
#[derive(Clone)]
pub struct ChangesPorts {
    pub git: Arc<dyn GitChanges>,
    pub files: Arc<dyn FileStore>,
    pub watcher: Arc<dyn ChangeWatcher>,
}

impl std::fmt::Debug for ChangesPorts {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ChangesPorts").finish_non_exhaustive()
    }
}

/// Changes, files and history of the worktrees in the workspace. Any other
/// path is refused.
#[derive(Debug)]
pub struct ChangesService {
    ports: ChangesPorts,
    workspace: Arc<WorkspaceService>,
}

impl ChangesService {
    pub fn new(ports: ChangesPorts, workspace: Arc<WorkspaceService>) -> Self {
        Self { ports, workspace }
    }

    pub async fn status(&self, worktree: &Path) -> Result<WorktreeChanges, ChangesError> {
        let worktree = self.worktree(worktree).await?;
        self.read_status(worktree).await
    }

    /// The status now, then whenever it changes, until the receiver is
    /// dropped. Each change also refreshes the workspace (sidebar counts).
    pub async fn watch_status(
        self: &Arc<Self>,
        worktree: &Path,
    ) -> Result<mpsc::Receiver<Result<WorktreeChanges, ChangesError>>, ChangesError> {
        let worktree = self.worktree(worktree).await?;
        let git = Arc::clone(&self.ports.git);
        let watched = worktree.clone();
        let paths = blocking(move || git.watched_paths(&watched)).await?;

        let (signal, mut signals) = mpsc::channel::<()>(1);
        let guard = self.ports.watcher.watch(
            &paths,
            Box::new(move || {
                let _ = signal.try_send(());
            }),
        )?;

        let (updates, receiver) = mpsc::channel(4);
        let service = Arc::clone(self);
        tokio::spawn(async move {
            let _guard = guard; // watching stops when this task ends
            let mut last = None;
            loop {
                let status = service.read_status(worktree.clone()).await;
                if last.as_ref() != Some(&status) {
                    if updates.send(status.clone()).await.is_err() {
                        break;
                    }
                    if last.is_some() {
                        service.workspace.refresh_worktree(&worktree).await;
                    }
                    last = Some(status);
                }
                tokio::select! {
                    () = updates.closed() => break,
                    signal = signals.recv() => if signal.is_none() { break },
                }
                tokio::time::sleep(SETTLE).await;
                while signals.try_recv().is_ok() {}
            }
            tracing::debug!(worktree = %worktree.display(), "status watch ended");
        });
        Ok(receiver)
    }

    pub async fn list_files(&self, worktree: &Path) -> Result<FileList, ChangesError> {
        let worktree = self.worktree(worktree).await?;
        let git = Arc::clone(&self.ports.git);
        blocking(move || git.list_files(&worktree, MAX_LISTED_FILES)).await
    }

    pub async fn read_file(
        &self,
        worktree: &Path,
        path: &str,
    ) -> Result<FileContent, ChangesError> {
        let (worktree, path) = (self.worktree(worktree).await?, RelativePath::parse(path)?);
        let files = Arc::clone(&self.ports.files);
        blocking(move || files.read(&worktree, &path, MAX_READ_BYTES)).await
    }

    pub async fn write_file(
        &self,
        worktree: &Path,
        path: &str,
        bytes: Vec<u8>,
    ) -> Result<(), ChangesError> {
        let (worktree, path) = (self.worktree(worktree).await?, RelativePath::parse(path)?);
        let files = Arc::clone(&self.ports.files);
        blocking(move || files.write(&worktree, &path, &bytes)).await
    }

    pub async fn diff(
        &self,
        worktree: &Path,
        path: &str,
        scope: DiffScope,
    ) -> Result<FileDiff, ChangesError> {
        let (worktree, path) = (self.worktree(worktree).await?, RelativePath::parse(path)?);
        let git = Arc::clone(&self.ports.git);
        blocking(move || git.diff(&worktree, &path, scope)).await
    }

    pub async fn stage(&self, worktree: &Path, paths: &[String]) -> Result<(), ChangesError> {
        self.on_paths(worktree, paths, |git, wt, paths| git.stage(wt, paths))
            .await
    }

    pub async fn unstage(&self, worktree: &Path, paths: &[String]) -> Result<(), ChangesError> {
        self.on_paths(worktree, paths, |git, wt, paths| git.unstage(wt, paths))
            .await
    }

    /// Back to HEAD: discards changes to these files.
    pub async fn restore(&self, worktree: &Path, paths: &[String]) -> Result<(), ChangesError> {
        self.on_paths(worktree, paths, |git, wt, paths| git.restore(wt, paths))
            .await
    }

    pub async fn commit(
        &self,
        worktree: &Path,
        options: CommitOptions,
    ) -> Result<CommitInfo, ChangesError> {
        let worktree = self.worktree(worktree).await?;
        let git = Arc::clone(&self.ports.git);
        let target = worktree.clone();
        let commit = blocking(move || git.commit(&target, &options)).await?;
        tracing::info!(worktree = %worktree.display(), commit = commit.short_sha, "committed");
        self.workspace.refresh_worktree(&worktree).await;
        Ok(commit)
    }

    pub async fn push(&self, worktree: &Path) -> Result<(), ChangesError> {
        self.on_worktree(worktree, |git, wt| git.push(wt)).await
    }

    pub async fn fetch(&self, worktree: &Path) -> Result<(), ChangesError> {
        self.on_worktree(worktree, |git, wt| git.fetch(wt)).await
    }

    pub async fn pull(&self, worktree: &Path) -> Result<(), ChangesError> {
        self.on_worktree(worktree, |git, wt| git.pull(wt)).await
    }

    pub async fn undo_last_commit(&self, worktree: &Path) -> Result<(), ChangesError> {
        self.on_worktree(worktree, |git, wt| git.undo_last_commit(wt))
            .await
    }

    pub async fn log(
        &self,
        worktree: &Path,
        limit: usize,
    ) -> Result<Vec<CommitInfo>, ChangesError> {
        let worktree = self.worktree(worktree).await?;
        let git = Arc::clone(&self.ports.git);
        blocking(move || git.log(&worktree, limit.clamp(1, 500))).await
    }

    /// The canonical path of a worktree in the workspace.
    async fn worktree(&self, path: &Path) -> Result<PathBuf, ChangesError> {
        self.workspace
            .known_worktree(path)
            .await
            .ok_or_else(|| ChangesError::UnknownWorktree(path.into()))
    }

    async fn read_status(&self, worktree: PathBuf) -> Result<WorktreeChanges, ChangesError> {
        let git = Arc::clone(&self.ports.git);
        blocking(move || git.status(&worktree)).await
    }

    async fn on_worktree(
        &self,
        worktree: &Path,
        action: impl FnOnce(&dyn GitChanges, &Path) -> Result<(), ChangesError> + Send + 'static,
    ) -> Result<(), ChangesError> {
        let worktree = self.worktree(worktree).await?;
        let git = Arc::clone(&self.ports.git);
        let target = worktree.clone();
        blocking(move || action(git.as_ref(), &target)).await?;
        self.workspace.refresh_worktree(&worktree).await;
        Ok(())
    }

    async fn on_paths(
        &self,
        worktree: &Path,
        paths: &[String],
        action: impl FnOnce(&dyn GitChanges, &Path, &[RelativePath]) -> Result<(), ChangesError>
        + Send
        + 'static,
    ) -> Result<(), ChangesError> {
        let paths = paths
            .iter()
            .map(|p| RelativePath::parse(p))
            .collect::<Result<Vec<_>, _>>()?;
        if paths.is_empty() {
            return Ok(());
        }
        self.on_worktree(worktree, move |git, wt| action(git, wt, &paths))
            .await
    }
}

async fn blocking<T: Send + 'static>(
    f: impl FnOnce() -> Result<T, ChangesError> + Send + 'static,
) -> Result<T, ChangesError> {
    tokio::task::spawn_blocking(f)
        .await
        .map_err(|e| ChangesError::Git(format!("blocking task failed: {e}")))?
}
