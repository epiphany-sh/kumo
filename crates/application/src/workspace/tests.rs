//! What changes on disk re-reads: [`WorkspaceService::sync`] with a git
//! that counts its reads and a watcher fired by hand.

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use kumo_domain::changes::{ChangeWatcher, ChangesError, OnChange, WatchGuard};
use kumo_domain::workspace::{
    Branches, Git, Namespace, NamespaceId, NewWorktree, Repo, RepoFinder, StoredWorkspace,
    WorkspaceError, WorkspaceStore, Worktree, WorktreeLocation, WorktreeStatus,
};

use super::{Presence, WorkspacePorts, WorkspaceService};

/// A repository with its main checkout and one linked worktree. Each
/// status read reports one more changed file.
#[derive(Default)]
struct CountingGit {
    worktrees: Vec<PathBuf>,
    listed: Mutex<usize>,
    statuses: Mutex<Vec<PathBuf>>,
}

impl CountingGit {
    fn listed(&self) -> usize {
        *self.listed.lock().unwrap()
    }

    fn statuses(&self) -> Vec<PathBuf> {
        self.statuses.lock().unwrap().clone()
    }

    fn forget(&self) {
        *self.listed.lock().unwrap() = 0;
        self.statuses.lock().unwrap().clear();
    }
}

impl Git for CountingGit {
    fn main_checkout(&self, path: &Path) -> Result<PathBuf, WorkspaceError> {
        Ok(path.to_path_buf())
    }

    fn remote_url(&self, _repo: &Path) -> Result<Option<String>, WorkspaceError> {
        Ok(None)
    }

    fn worktrees(&self, _repo: &Path) -> Result<Vec<Worktree>, WorkspaceError> {
        *self.listed.lock().unwrap() += 1;
        Ok(self
            .worktrees
            .iter()
            .enumerate()
            .map(|(n, path)| Worktree {
                path: path.clone(),
                branch: Some(format!("b{n}")),
                head: String::new(),
                is_main: n == 0,
                locked: false,
                status: WorktreeStatus::default(),
            })
            .collect())
    }

    fn status(&self, worktree: &Path) -> Result<WorktreeStatus, WorkspaceError> {
        let mut statuses = self.statuses.lock().unwrap();
        statuses.push(worktree.to_path_buf());
        Ok(WorktreeStatus {
            changed_files: u32::try_from(statuses.len()).unwrap(),
            ..WorktreeStatus::default()
        })
    }

    fn add_worktree(&self, _repo: &Path, _worktree: &NewWorktree) -> Result<(), WorkspaceError> {
        unimplemented!()
    }

    fn remove_worktree(&self, _: &Path, _: &Path, _: bool) -> Result<(), WorkspaceError> {
        unimplemented!()
    }

    fn delete_branch(&self, _repo: &Path, _branch: &str) -> Result<(), WorkspaceError> {
        unimplemented!()
    }

    fn branches(&self, _repo: &Path) -> Result<Branches, WorkspaceError> {
        unimplemented!()
    }
}

struct OneRepo(PathBuf);

impl WorkspaceStore for OneRepo {
    fn load(&self) -> Result<StoredWorkspace, WorkspaceError> {
        Ok(StoredWorkspace {
            namespaces: vec![Namespace::new(
                NamespaceId::generate(),
                "work",
                [self.0.clone()],
                false,
            )],
            repos: vec![Repo::new(self.0.clone(), None)],
        })
    }

    fn save_namespace(&self, _: &Namespace, _: usize) -> Result<(), WorkspaceError> {
        Ok(())
    }

    fn delete_namespace(&self, _: &NamespaceId) -> Result<(), WorkspaceError> {
        Ok(())
    }

    fn save_repo(&self, _: &Repo) -> Result<(), WorkspaceError> {
        Ok(())
    }
}

struct NoRepos;

impl RepoFinder for NoRepos {
    fn default_roots(&self) -> Vec<PathBuf> {
        Vec::new()
    }

    fn find(&self, _roots: &[PathBuf]) -> Vec<PathBuf> {
        Vec::new()
    }
}

type Callback = Arc<dyn Fn(&[PathBuf]) + Send + Sync>;

#[derive(Default)]
struct ManualWatcher(Mutex<Vec<Callback>>);

struct NoGuard;
impl WatchGuard for NoGuard {}

impl ManualWatcher {
    fn watching(&self) -> bool {
        !self.0.lock().unwrap().is_empty()
    }

    fn fire(&self, path: &Path) {
        for callback in self.0.lock().unwrap().iter() {
            callback(&[path.to_path_buf()]);
        }
    }
}

impl ChangeWatcher for ManualWatcher {
    fn watch(
        &self,
        _paths: &[PathBuf],
        on_change: OnChange,
    ) -> Result<Box<dyn WatchGuard>, ChangesError> {
        self.0.lock().unwrap().push(Arc::from(on_change));
        Ok(Box::new(NoGuard))
    }
}

struct Fixture {
    service: Arc<WorkspaceService>,
    git: Arc<CountingGit>,
    watcher: Arc<ManualWatcher>,
    main: PathBuf,
    linked: PathBuf,
    root: PathBuf,
}

impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.root);
    }
}

/// The workspace synced, after the reads its start makes.
async fn synced(name: &str) -> Fixture {
    let root = std::env::temp_dir().join(format!("kumo-ws-{name}-{}", std::process::id()));
    let (main, linked) = (root.join("api"), root.join("api-fix"));
    for dir in [&main, &linked] {
        std::fs::create_dir_all(dir).unwrap();
    }
    let git = Arc::new(CountingGit {
        worktrees: vec![main.clone(), linked.clone()],
        ..CountingGit::default()
    });
    let watcher = Arc::new(ManualWatcher::default());
    let service = Arc::new(
        WorkspaceService::load(WorkspacePorts {
            git: Arc::clone(&git) as Arc<dyn Git>,
            store: Arc::new(OneRepo(main.clone())),
            finder: Arc::new(NoRepos),
            watcher: Arc::clone(&watcher) as Arc<dyn ChangeWatcher>,
            location: WorktreeLocation::new(&root),
        })
        .await
        .unwrap(),
    );
    service.refresh().await;
    service.sync();
    // Starting to watch reads the repository once more.
    eventually(|| watcher.watching() && git.listed() >= 2).await;
    tokio::time::sleep(Duration::from_millis(200)).await;
    git.forget();
    Fixture {
        service,
        git,
        watcher,
        main,
        linked,
        root,
    }
}

async fn eventually(done: impl Fn() -> bool) {
    tokio::time::timeout(Duration::from_secs(5), async {
        while !done() {
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .expect("never happened");
}

#[tokio::test(flavor = "multi_thread")]
async fn a_file_changing_in_a_worktree_rereads_only_that_worktree() {
    let f = synced("one").await;
    let mut refreshed = f.service.refreshed();
    let mut snapshots = f.service.watch();
    snapshots.borrow_and_update();

    f.watcher.fire(&f.linked.join("src/handler.go"));
    eventually(|| !f.git.statuses().is_empty()).await;
    tokio::time::sleep(Duration::from_millis(300)).await;

    assert_eq!(f.git.statuses(), vec![f.linked.clone()]);
    assert_eq!(f.git.listed(), 0, "the repository was read");
    assert_eq!(refreshed.recv().await.unwrap(), f.linked);
    // The sidebar shows the new status.
    assert!(snapshots.has_changed().unwrap());
    let snapshot = snapshots.borrow_and_update().clone();
    let linked = snapshot.repos[0]
        .worktrees
        .iter()
        .find(|w| w.path == f.linked)
        .unwrap();
    assert_eq!(linked.status.changed_files, 1);
}

#[tokio::test(flavor = "multi_thread")]
async fn a_build_folder_changing_reads_nothing() {
    let f = synced("build").await;
    f.watcher.fire(&f.main.join("target/debug/kumod"));
    f.watcher
        .fire(&f.linked.join("web/node_modules/x/index.js"));
    tokio::time::sleep(Duration::from_millis(500)).await;
    assert!(f.git.statuses().is_empty());
    assert_eq!(f.git.listed(), 0);
}

#[tokio::test(flavor = "multi_thread")]
async fn a_branch_moving_rereads_the_repository() {
    let f = synced("refs").await;
    f.watcher.fire(&f.main.join(".git/refs/heads/main"));
    eventually(|| f.git.listed() == 1 && f.git.statuses().len() == 2).await;
    tokio::time::sleep(Duration::from_millis(300)).await;
    assert_eq!(f.git.listed(), 1);
    assert_eq!(f.git.statuses().len(), 2, "every worktree once");
}

#[tokio::test(flavor = "multi_thread")]
async fn a_stream_of_changes_reads_once_then_waits() {
    let f = synced("stream").await;
    for n in 0..50 {
        f.watcher.fire(&f.main.join(format!("src/file{n}.rs")));
        tokio::time::sleep(Duration::from_millis(20)).await;
    }
    // A second of writes: the first read, then the rest waits for the gap.
    assert_eq!(f.git.statuses(), vec![f.main.clone()]);
}

const HIDDEN: Presence = Presence {
    focused: false,
    visible: false,
};

#[tokio::test(start_paused = true)]
async fn a_hidden_window_that_goes_away_stops_pausing_refreshes() {
    let f = synced("hidden-gone").await;
    let window = f.service.attach("window-1");
    f.service.set_presence("window-1", HIDDEN);

    f.watcher.fire(&f.linked.join("src/handler.go"));
    tokio::time::sleep(Duration::from_secs(600)).await;
    assert!(f.git.statuses().is_empty(), "read while hidden");

    // The UI quits (or crashes) while minimized: its watch ends.
    drop(window);
    eventually(|| f.git.statuses() == vec![f.linked.clone()]).await;
}

#[tokio::test(start_paused = true)]
async fn one_hidden_window_does_not_pause_another_visible_one() {
    let f = synced("two-windows").await;
    let _hidden = f.service.attach("window-1");
    let _shown = f.service.attach("window-2");
    f.service.set_presence("window-1", HIDDEN);
    f.service.set_presence("window-2", Presence::default());

    f.watcher.fire(&f.linked.join("src/handler.go"));
    eventually(|| f.git.statuses() == vec![f.linked.clone()]).await;
}

#[tokio::test(start_paused = true)]
async fn a_client_that_does_not_watch_cannot_pause_refreshes() {
    let f = synced("not-watching").await;
    f.service.set_presence("gone", HIDDEN);

    f.watcher.fire(&f.linked.join("src/handler.go"));
    eventually(|| f.git.statuses() == vec![f.linked.clone()]).await;
}
