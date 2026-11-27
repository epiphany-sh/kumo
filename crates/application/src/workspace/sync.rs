//! Keeps the workspace in step with what happens outside the app: a
//! `git worktree add` in a terminal, an agent editing files, a commit from
//! the shell.
//!
//! One watch per repository. A file changing in a worktree re-reads only
//! that worktree's status; a change to what the repository shares (its
//! branches, its list of worktrees, its remote) re-reads the repository.
//! Either goes through the [`Scheduler`], so an agent writing nonstop
//! costs a read every few seconds, not several a second.

use std::collections::{HashMap, HashSet};
use std::ffi::OsString;
use std::path::{Component, Path, PathBuf};
use std::sync::{Arc, Mutex, PoisonError, Weak};

use futures::FutureExt;
use kumo_domain::changes::{ChangeWatcher, WatchGuard};
use kumo_domain::workspace::{RepoState, WorkspaceSnapshot};
use tokio::sync::{Notify, watch};

use super::WorkspaceService;
use super::schedule::{Presence, Refresh, Scheduler, Timing};

/// Folders of build output and dependencies: what changes there never
/// changes a status worth showing right away (git usually ignores them).
const SKIPPED_FOLDERS: &[&str] = &[
    "node_modules",
    "target",
    ".dart_tool",
    "dist",
    "build",
    ".next",
    ".cache",
    ".venv",
    "__pycache__",
    ".gradle",
    ".turbo",
];

/// What a change on disk calls for re-reading.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub(super) enum Target {
    /// Remote, worktrees and every worktree's status (the main checkout's
    /// path).
    Repo(PathBuf),
    /// One worktree's status.
    Worktree(PathBuf),
}

/// A repository's watch: what it covers, alive while kept.
struct Watched {
    worktrees: Vec<PathBuf>,
    _guard: Option<Box<dyn WatchGuard>>,
}

type Dirty = Arc<Mutex<HashSet<Target>>>;

/// Runs until the service is dropped. Every repository in a namespace is
/// watched: its main checkout (git's shared folder, where `git worktree add`
/// writes, lives there) and each linked worktree outside it.
pub(super) async fn run(
    service: Weak<WorkspaceService>,
    watcher: Arc<dyn ChangeWatcher>,
    mut snapshots: watch::Receiver<Arc<WorkspaceSnapshot>>,
    presence: watch::Receiver<Presence>,
) {
    let dirty: Dirty = Arc::default();
    let wake = Arc::new(Notify::new());
    let scheduler = Scheduler::new(Timing::default(), presence, refresher(service.clone()));
    let mut watched: HashMap<PathBuf, Watched> = HashMap::new();

    loop {
        let snapshot = Arc::clone(&snapshots.borrow_and_update());
        rewatch(&mut watched, &snapshot, &watcher, &dirty, &wake).await;

        tokio::select! {
            changed = snapshots.changed() => if changed.is_err() { break },
            () = wake.notified() => {
                if service.strong_count() == 0 {
                    break;
                }
                for target in std::mem::take(&mut *lock(&dirty)) {
                    scheduler.notify(target);
                }
            }
        }
    }
    tracing::debug!("workspace sync ended");
}

fn refresher(service: Weak<WorkspaceService>) -> Refresh<Target> {
    Arc::new(move |target| {
        let service = service.clone();
        async move {
            let Some(service) = service.upgrade() else {
                return;
            };
            match target {
                Target::Repo(repo) => service.refresh_repo(&repo).await,
                Target::Worktree(worktree) => service.refresh_worktree_status(&worktree).await,
            }
        }
        .boxed()
    })
}

/// Starts, replaces or drops watches so they match the snapshot's
/// repositories and worktrees.
async fn rewatch(
    watched: &mut HashMap<PathBuf, Watched>,
    snapshot: &WorkspaceSnapshot,
    watcher: &Arc<dyn ChangeWatcher>,
    dirty: &Dirty,
    wake: &Arc<Notify>,
) {
    watched.retain(|repo, _| snapshot.repos.iter().any(|r| &r.repo.path == repo));
    for state in &snapshot.repos {
        let worktrees: Vec<PathBuf> = state.worktrees.iter().map(|w| w.path.clone()).collect();
        if watched
            .get(&state.repo.path)
            .is_some_and(|w| w.worktrees == worktrees)
        {
            continue;
        }
        let guard = start(watcher, state, dirty, wake).await;
        // What changed before the watch started (an agent that edits right
        // after `git worktree add`) shows with one more read.
        lock(dirty).insert(Target::Repo(state.repo.path.clone()));
        wake.notify_one();
        watched.insert(
            state.repo.path.clone(),
            Watched {
                worktrees,
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
    state: &RepoState,
    dirty: &Dirty,
    wake: &Arc<Notify>,
) -> Option<Box<dyn WatchGuard>> {
    let paths = paths_of(state);
    if paths.is_empty() {
        return None;
    }
    let repo = state.repo.path.clone();
    let (watcher, state) = (Arc::clone(watcher), state.clone());
    let (dirty, wake) = (Arc::clone(dirty), Arc::clone(wake));
    let folders = paths.len();
    let started = tokio::task::spawn_blocking(move || {
        let layout = Layout::read(&state);
        watcher.watch(
            &paths,
            Box::new(move |changed: &[PathBuf]| {
                let targets: Vec<Target> =
                    changed.iter().filter_map(|p| layout.classify(p)).collect();
                if targets.is_empty() {
                    return;
                }
                lock(&dirty).extend(targets);
                wake.notify_one();
            }),
        )
    })
    .await;
    match started {
        Ok(Ok(guard)) => {
            tracing::debug!(repo = %repo.display(), folders, "watching repository");
            Some(guard)
        }
        Ok(Err(error)) => {
            tracing::warn!(repo = %repo.display(), %error, "can't watch the repository: changes show on the next refresh");
            None
        }
        Err(_) => None,
    }
}

/// Where a repository's files are, to tell what a changed path belongs to.
#[derive(Debug, Clone)]
struct Layout {
    repo: PathBuf,
    /// The main checkout's `.git`, shared by every worktree.
    git_dir: PathBuf,
    main: Option<PathBuf>,
    /// Longest first: a worktree inside another one wins.
    worktrees: Vec<PathBuf>,
    /// Folder under `.git/worktrees/` → the linked worktree it serves.
    linked: HashMap<OsString, PathBuf>,
}

impl Layout {
    /// Reads each linked worktree's `.git` file (`gitdir: …/worktrees/<name>`).
    fn read(state: &RepoState) -> Self {
        let linked = state
            .worktrees
            .iter()
            .filter(|w| !w.is_main)
            .filter_map(|w| {
                let file = std::fs::read_to_string(w.path.join(".git")).ok()?;
                let git_dir = file.trim().strip_prefix("gitdir:")?.trim();
                let name = Path::new(git_dir).file_name()?.to_os_string();
                Some((name, w.path.clone()))
            })
            .collect();
        Self::new(state, linked)
    }

    fn new(state: &RepoState, linked: HashMap<OsString, PathBuf>) -> Self {
        let mut worktrees: Vec<PathBuf> = state.worktrees.iter().map(|w| w.path.clone()).collect();
        worktrees.sort_by_key(|p| std::cmp::Reverse(p.components().count()));
        Self {
            repo: state.repo.path.clone(),
            git_dir: state.repo.path.join(".git"),
            main: state
                .worktrees
                .iter()
                .find(|w| w.is_main)
                .map(|w| w.path.clone()),
            worktrees,
            linked,
        }
    }

    /// What `path` changing calls for, if anything.
    fn classify(&self, path: &Path) -> Option<Target> {
        let repo = || Some(Target::Repo(self.repo.clone()));
        let main = || match &self.main {
            Some(main) => Some(Target::Worktree(main.clone())),
            None => repo(),
        };
        if path
            .file_name()
            .is_some_and(|n| n.to_string_lossy().ends_with(".lock"))
        {
            return None; // git renames it into place: that's the change
        }
        if let Ok(inside) = path.strip_prefix(&self.git_dir) {
            let parts: Vec<&str> = names(inside);
            return match parts.as_slice() {
                [] | ["HEAD" | "packed-refs" | "config"] | ["refs", ..] => repo(),
                ["objects" | "logs", ..] => None,
                ["index"] => main(),
                ["worktrees"] | ["worktrees", _] => repo(),
                ["worktrees", _, "logs", ..] => None,
                ["worktrees", _, "HEAD" | "gitdir" | "locked" | "commondir"] => repo(),
                ["worktrees", name, ..] => match self.linked.get(std::ffi::OsStr::new(name)) {
                    Some(worktree) => Some(Target::Worktree(worktree.clone())),
                    None => repo(),
                },
                // ORIG_HEAD, MERGE_HEAD, a rebase's folder…: the main checkout.
                _ => main(),
            };
        }
        let worktree = self.worktrees.iter().find(|w| path.starts_with(w))?;
        let inside = path.strip_prefix(worktree).unwrap_or(Path::new(""));
        if names(inside)
            .iter()
            .any(|part| SKIPPED_FOLDERS.contains(part))
        {
            return None;
        }
        Some(Target::Worktree(worktree.clone()))
    }
}

fn names(path: &Path) -> Vec<&str> {
    path.components()
        .filter_map(|c| match c {
            Component::Normal(name) => name.to_str(),
            _ => None,
        })
        .collect()
}

fn lock(dirty: &Mutex<HashSet<Target>>) -> std::sync::MutexGuard<'_, HashSet<Target>> {
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

    /// `/r/api` with `/r/api/.claude/worktrees/fix` inside and `/r/api-fix`
    /// next to it.
    fn layout() -> Layout {
        let root = Path::new("/r");
        let state = RepoState {
            repo: Repo::new(root.join("api"), None),
            worktrees: vec![
                worktree(&root.join("api"), true),
                worktree(&root.join("api/.claude/worktrees/fix"), false),
                worktree(&root.join("api-fix"), false),
            ],
            error: None,
        };
        let linked = HashMap::from([
            ("fix".into(), root.join("api/.claude/worktrees/fix")),
            ("api-fix".into(), root.join("api-fix")),
        ]);
        Layout::new(&state, linked)
    }

    fn classify(path: &str) -> Option<Target> {
        layout().classify(Path::new(path))
    }

    fn wt(path: &str) -> Option<Target> {
        Some(Target::Worktree(PathBuf::from(path)))
    }

    fn repo() -> Option<Target> {
        Some(Target::Repo(PathBuf::from("/r/api")))
    }

    #[test]
    fn a_file_belongs_to_the_innermost_worktree() {
        assert_eq!(classify("/r/api/src/main.rs"), wt("/r/api"));
        assert_eq!(
            classify("/r/api/.claude/worktrees/fix/src/main.rs"),
            wt("/r/api/.claude/worktrees/fix")
        );
        assert_eq!(classify("/r/api-fix/handler.go"), wt("/r/api-fix"));
        assert_eq!(classify("/elsewhere/file"), None);
    }

    #[test]
    fn build_output_and_dependencies_are_skipped() {
        for path in [
            "/r/api/target/debug/kumo",
            "/r/api/web/node_modules/x/index.js",
            "/r/api-fix/app/.dart_tool/cache",
            "/r/api/py/__pycache__/m.pyc",
        ] {
            assert_eq!(classify(path), None, "{path}");
        }
        // The folder names count only inside the worktree.
        assert_eq!(classify("/r/api-fix/src/targets.rs"), wt("/r/api-fix"));
    }

    #[test]
    fn what_the_repository_shares_rereads_the_repository() {
        for path in [
            "/r/api/.git/HEAD",
            "/r/api/.git/refs/heads/main",
            "/r/api/.git/refs/remotes/origin/main",
            "/r/api/.git/packed-refs",
            "/r/api/.git/config",
            "/r/api/.git/worktrees/new",
            "/r/api/.git/worktrees/fix/HEAD",
            "/r/api/.git/worktrees/unknown/index",
        ] {
            assert_eq!(classify(path), repo(), "{path}");
        }
    }

    #[test]
    fn a_worktrees_own_git_files_reread_that_worktree() {
        assert_eq!(classify("/r/api/.git/index"), wt("/r/api"));
        assert_eq!(classify("/r/api/.git/MERGE_HEAD"), wt("/r/api"));
        assert_eq!(
            classify("/r/api/.git/worktrees/api-fix/index"),
            wt("/r/api-fix")
        );
        assert_eq!(
            classify("/r/api/.git/worktrees/fix/index"),
            wt("/r/api/.claude/worktrees/fix")
        );
    }

    #[test]
    fn git_bookkeeping_is_skipped() {
        for path in [
            "/r/api/.git/objects/ab/cdef",
            "/r/api/.git/logs/HEAD",
            "/r/api/.git/worktrees/fix/logs/HEAD",
            "/r/api/.git/index.lock",
            "/r/api/.git/refs/heads/main.lock",
        ] {
            assert_eq!(classify(path), None, "{path}");
        }
    }
}
