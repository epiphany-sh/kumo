//! Keeps the workspace in step with what happens outside the app: a
//! `git worktree add` in a terminal, an agent editing files, a commit from
//! the shell.

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, PoisonError, Weak};
use std::time::Duration;

use kumo_domain::changes::{ChangeWatcher, WatchGuard};
use kumo_domain::workspace::{RepoState, WorkspaceSnapshot};
use tokio::sync::{Notify, watch};

use super::WorkspaceService;

/// A git command or a build touches many files: wait for the burst to
/// settle before reading the repository again.
const SETTLE: Duration = Duration::from_millis(300);

/// A repository's watch: the folders it covers, alive while kept.
struct Watched {
    paths: Vec<PathBuf>,
    _guard: Option<Box<dyn WatchGuard>>,
}

/// Runs until the service is dropped. Every repository in a namespace is
/// watched: its main checkout (git's shared folder, where `git worktree add`
/// writes, lives there) and each linked worktree outside it.
pub(super) async fn run(
    service: Weak<WorkspaceService>,
    watcher: Arc<dyn ChangeWatcher>,
    mut snapshots: watch::Receiver<Arc<WorkspaceSnapshot>>,
) {
    let dirty: Arc<Mutex<HashSet<PathBuf>>> = Arc::default();
    let wake = Arc::new(Notify::new());
    let mut watched: HashMap<PathBuf, Watched> = HashMap::new();

    loop {
        let snapshot = Arc::clone(&snapshots.borrow_and_update());
        rewatch(&mut watched, &snapshot, &watcher, &dirty, &wake).await;

        tokio::select! {
            changed = snapshots.changed() => if changed.is_err() { break },
            () = wake.notified() => {
                tokio::time::sleep(SETTLE).await;
                let repos = std::mem::take(&mut *lock(&dirty));
                let Some(service) = service.upgrade() else { break };
                for repo in repos {
                    service.refresh_repo(&repo).await;
                }
            }
        }
    }
    tracing::debug!("workspace sync ended");
}

/// Starts, replaces or drops watches so they match the snapshot's
/// repositories and worktrees.
async fn rewatch(
    watched: &mut HashMap<PathBuf, Watched>,
    snapshot: &WorkspaceSnapshot,
    watcher: &Arc<dyn ChangeWatcher>,
    dirty: &Arc<Mutex<HashSet<PathBuf>>>,
    wake: &Arc<Notify>,
) {
    watched.retain(|repo, _| snapshot.repos.iter().any(|r| &r.repo.path == repo));
    for state in &snapshot.repos {
        let paths = paths_of(state);
        if watched
            .get(&state.repo.path)
            .is_some_and(|w| w.paths == paths)
        {
            continue;
        }
        let guard = start(watcher, &state.repo.path, &paths, dirty, wake).await;
        // What changed before the watch started (an agent that edits right
        // after `git worktree add`) shows with one more read.
        lock(dirty).insert(state.repo.path.clone());
        wake.notify_one();
        watched.insert(
            state.repo.path.clone(),
            Watched {
                paths,
                _guard: guard,
            },
        );
    }
}

/// The main checkout, then the worktrees not inside a folder already
/// watched. Folders that are gone are left out.
fn paths_of(state: &RepoState) -> Vec<PathBuf> {
    let mut paths: Vec<PathBuf> = Vec::new();
    let candidates =
        std::iter::once(&state.repo.path).chain(state.worktrees.iter().map(|w| &w.path));
    for path in candidates {
        if path.is_dir() && !paths.iter().any(|p| path.starts_with(p)) {
            paths.push(path.clone());
        }
    }
    paths
}

async fn start(
    watcher: &Arc<dyn ChangeWatcher>,
    repo: &Path,
    paths: &[PathBuf],
    dirty: &Arc<Mutex<HashSet<PathBuf>>>,
    wake: &Arc<Notify>,
) -> Option<Box<dyn WatchGuard>> {
    if paths.is_empty() {
        return None;
    }
    let (watcher, paths_owned) = (Arc::clone(watcher), paths.to_vec());
    let (dirty, wake, owner) = (Arc::clone(dirty), Arc::clone(wake), repo.to_path_buf());
    let started = tokio::task::spawn_blocking(move || {
        watcher.watch(
            &paths_owned,
            Box::new(move || {
                lock(&dirty).insert(owner.clone());
                wake.notify_one();
            }),
        )
    })
    .await;
    match started {
        Ok(Ok(guard)) => {
            tracing::debug!(repo = %repo.display(), folders = paths.len(), "watching repository");
            Some(guard)
        }
        Ok(Err(error)) => {
            tracing::warn!(repo = %repo.display(), %error, "can't watch the repository: changes show on the next refresh");
            None
        }
        Err(_) => None,
    }
}

fn lock(dirty: &Mutex<HashSet<PathBuf>>) -> std::sync::MutexGuard<'_, HashSet<PathBuf>> {
    dirty.lock().unwrap_or_else(PoisonError::into_inner)
}

#[cfg(test)]
mod tests {
    use kumo_domain::workspace::{Repo, Worktree};

    use super::*;

    fn worktree(path: &Path, is_main: bool) -> Worktree {
        Worktree {
            path: path.to_path_buf(),
            branch: Some("main".into()),
            head: String::new(),
            is_main,
            locked: false,
            status: Default::default(),
        }
    }

    #[test]
    fn watches_the_main_checkout_and_worktrees_outside_it() {
        let root = std::env::temp_dir().join(format!("kumo-sync-{}", std::process::id()));
        let (main, inside, sibling, gone) = (
            root.join("api"),
            root.join("api/.claude/worktrees/fix"),
            root.join("api-fix"),
            root.join("api-gone"),
        );
        for dir in [&inside, &sibling] {
            std::fs::create_dir_all(dir).unwrap();
        }
        let state = RepoState {
            repo: Repo::new(main.clone(), None),
            worktrees: vec![
                worktree(&main, true),
                worktree(&inside, false),
                worktree(&sibling, false),
                worktree(&gone, false),
            ],
            error: None,
        };

        assert_eq!(paths_of(&state), vec![main, sibling]);
        std::fs::remove_dir_all(root).unwrap();
    }
}
