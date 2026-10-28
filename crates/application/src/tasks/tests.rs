use std::collections::{BTreeMap, HashMap};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use kumo_domain::changes::{ChangeWatcher, ChangesError, WatchGuard};
use kumo_domain::tasks::{
    Detected, Priority, SecretStore, SourceId, SourceKind, SourceOptions, Task, TaskConnector,
    TaskError, TaskId, TaskLink, TaskSource, TaskStatus, TaskStore,
};
use tokio::sync::watch;

use super::{TaskBoard, TaskPorts, TaskService, TaskTiming};

// ---- Fakes ----

#[derive(Default)]
struct MemStore {
    sources: Mutex<Vec<TaskSource>>,
    tasks: Mutex<HashMap<SourceId, Vec<Task>>>,
    links: Mutex<Vec<TaskLink>>,
}

impl TaskStore for MemStore {
    fn sources(&self) -> Result<Vec<TaskSource>, TaskError> {
        Ok(self.sources.lock().unwrap().clone())
    }
    fn save_source(&self, source: &TaskSource) -> Result<(), TaskError> {
        let mut sources = self.sources.lock().unwrap();
        match sources.iter_mut().find(|s| s.id == source.id) {
            Some(s) => *s = source.clone(),
            None => sources.push(source.clone()),
        }
        Ok(())
    }
    fn delete_source(&self, id: &SourceId) -> Result<(), TaskError> {
        self.sources.lock().unwrap().retain(|s| &s.id != id);
        self.tasks.lock().unwrap().remove(id);
        Ok(())
    }
    fn tasks(&self, source: &SourceId) -> Result<Vec<Task>, TaskError> {
        Ok(self
            .tasks
            .lock()
            .unwrap()
            .get(source)
            .cloned()
            .unwrap_or_default())
    }
    fn replace_tasks(&self, source: &SourceId, tasks: &[Task]) -> Result<(), TaskError> {
        self.tasks
            .lock()
            .unwrap()
            .insert(source.clone(), tasks.to_vec());
        Ok(())
    }
    fn links(&self) -> Result<Vec<TaskLink>, TaskError> {
        Ok(self.links.lock().unwrap().clone())
    }
    /// Keyed by task and worktree, like the real one.
    fn save_link(&self, link: &TaskLink) -> Result<(), TaskError> {
        self.delete_link(link)?;
        self.links.lock().unwrap().push(link.clone());
        Ok(())
    }
    fn delete_link(&self, link: &TaskLink) -> Result<(), TaskError> {
        self.links
            .lock()
            .unwrap()
            .retain(|l| !(l.task == link.task && l.worktree == link.worktree));
        Ok(())
    }
}

#[derive(Default)]
struct MemSecrets(Mutex<HashMap<SourceId, String>>);

impl SecretStore for MemSecrets {
    fn get(&self, source: &SourceId) -> Result<Option<String>, TaskError> {
        Ok(self.0.lock().unwrap().get(source).cloned())
    }
    fn set(&self, source: &SourceId, secret: &str) -> Result<(), TaskError> {
        self.0
            .lock()
            .unwrap()
            .insert(source.clone(), secret.to_owned());
        Ok(())
    }
    fn delete(&self, source: &SourceId) -> Result<(), TaskError> {
        self.0.lock().unwrap().remove(source);
        Ok(())
    }
}

/// Serves `titles` (with statuses) for any source of its kind.
struct FakeConnector {
    kind: SourceKind,
    items: Mutex<Vec<(String, TaskStatus)>>,
    fail_fetch: AtomicBool,
    fail_write: AtomicBool,
    fetches: AtomicUsize,
    secrets_seen: Mutex<Vec<Option<String>>>,
}

impl FakeConnector {
    fn new(kind: SourceKind, items: &[(&str, TaskStatus)]) -> Arc<Self> {
        Arc::new(Self {
            kind,
            items: Mutex::new(items.iter().map(|(t, s)| ((*t).to_owned(), *s)).collect()),
            fail_fetch: AtomicBool::new(false),
            fail_write: AtomicBool::new(false),
            fetches: AtomicUsize::new(0),
            secrets_seen: Mutex::new(vec![]),
        })
    }
}

impl TaskConnector for FakeConnector {
    fn kind(&self) -> SourceKind {
        self.kind
    }
    fn fetch(&self, source: &TaskSource, secret: Option<&str>) -> Result<Vec<Task>, TaskError> {
        self.fetches.fetch_add(1, Ordering::SeqCst);
        self.secrets_seen
            .lock()
            .unwrap()
            .push(secret.map(str::to_owned));
        if self.fail_fetch.load(Ordering::SeqCst) {
            return Err(TaskError::Unavailable("offline".into()));
        }
        Ok(self
            .items
            .lock()
            .unwrap()
            .iter()
            .map(|(title, status)| task(&source.id, title, *status))
            .collect())
    }
    fn set_status(
        &self,
        _source: &TaskSource,
        _secret: Option<&str>,
        task: &Task,
        status: TaskStatus,
    ) -> Result<(), TaskError> {
        if self.fail_write.load(Ordering::SeqCst) {
            return Err(TaskError::Auth("token expired".into()));
        }
        for item in self.items.lock().unwrap().iter_mut() {
            if item.0 == task.title {
                item.1 = status;
            }
        }
        Ok(())
    }
    fn test(&self, source: &TaskSource, secret: Option<&str>) -> Result<String, TaskError> {
        Ok(format!("{} via {}", source.kind(), secret.unwrap_or("-")))
    }
    fn watched_paths(&self, _source: &TaskSource) -> Vec<PathBuf> {
        if self.kind.is_local() {
            vec![PathBuf::from("/vault")]
        } else {
            vec![]
        }
    }
    fn detect(&self) -> Vec<Detected> {
        vec![Detected {
            name: "Found".into(),
            options: vault("/found"),
        }]
    }
}

/// Fires its callbacks when told to.
#[derive(Default)]
struct ManualWatcher(Mutex<Vec<Arc<dyn Fn() + Send + Sync>>>);

struct NoGuard;
impl WatchGuard for NoGuard {}

impl ManualWatcher {
    fn fire(&self) {
        for callback in self.0.lock().unwrap().iter() {
            callback();
        }
    }
}

impl ChangeWatcher for ManualWatcher {
    fn watch(
        &self,
        _paths: &[PathBuf],
        on_change: Box<dyn Fn() + Send + Sync>,
    ) -> Result<Box<dyn WatchGuard>, ChangesError> {
        self.0.lock().unwrap().push(Arc::from(on_change));
        Ok(Box::new(NoGuard))
    }
}

fn task(source: &SourceId, title: &str, status: TaskStatus) -> Task {
    Task {
        id: TaskId::new(source, &title.replace(' ', "-")),
        key: "K".into(),
        ticket: None,
        title: title.into(),
        status,
        priority: Priority::None,
        due: None,
        url: None,
        context: String::new(),
        labels: vec![],
        updated: None,
    }
}

fn vault(path: &str) -> SourceOptions {
    SourceOptions::Obsidian { vault: path.into() }
}

fn todoist() -> SourceOptions {
    SourceOptions::from_map(SourceKind::Todoist, &BTreeMap::new()).unwrap()
}

struct Fixture {
    store: Arc<MemStore>,
    secrets: Arc<MemSecrets>,
    notes: Arc<FakeConnector>,
    todo: Arc<FakeConnector>,
    watcher: Arc<ManualWatcher>,
}

impl Fixture {
    fn new() -> Self {
        Self {
            store: Arc::default(),
            secrets: Arc::default(),
            notes: FakeConnector::new(SourceKind::Obsidian, &[("Call Ana", TaskStatus::Todo)]),
            todo: FakeConnector::new(SourceKind::Todoist, &[("Pay rent", TaskStatus::Todo)]),
            watcher: Arc::default(),
        }
    }

    async fn service(&self) -> Arc<TaskService> {
        TaskService::load(
            TaskPorts {
                store: self.store.clone(),
                secrets: self.secrets.clone(),
                connectors: vec![self.notes.clone(), self.todo.clone()],
                watcher: self.watcher.clone(),
            },
            TaskTiming {
                remote_every: Duration::from_secs(3600),
                settle: Duration::from_millis(5),
            },
        )
        .await
        .unwrap()
    }
}

async fn until(
    rx: &mut watch::Receiver<Arc<TaskBoard>>,
    what: &str,
    ok: impl Fn(&TaskBoard) -> bool,
) -> Arc<TaskBoard> {
    let waited = tokio::time::timeout(Duration::from_secs(5), rx.wait_for(|b| ok(b)))
        .await
        .map(|board| board.map(|b| Arc::clone(&b)));
    match waited {
        Ok(Ok(board)) => board,
        _ => panic!("timed out waiting for: {what}\n{:#?}", rx.borrow()),
    }
}

fn titles(board: &TaskBoard) -> Vec<(String, TaskStatus)> {
    board
        .sources
        .iter()
        .flat_map(|s| s.tasks.iter().map(|t| (t.title.clone(), t.status)))
        .collect()
}

// ---- Tests ----

#[tokio::test]
async fn serves_the_cache_first_then_syncs_in_the_background() {
    let f = Fixture::new();
    let source = TaskSource {
        id: SourceId::parse("notes").unwrap(),
        name: "Notes".into(),
        options: vault("/vault"),
        enabled: true,
    };
    f.store.save_source(&source).unwrap();
    f.store
        .replace_tasks(&source.id, &[task(&source.id, "Cached", TaskStatus::Todo)])
        .unwrap();

    let service = f.service().await;
    let mut rx = service.watch();
    assert!(titles(&service.board()).contains(&("Cached".into(), TaskStatus::Todo)));

    let board = until(&mut rx, "first sync", |b| {
        titles(b) == [("Call Ana".to_owned(), TaskStatus::Todo)]
    })
    .await;
    assert!(board.sources[0].last_synced.is_some());
    assert_eq!(
        f.store.tasks(&source.id).unwrap()[0].title,
        "Call Ana",
        "cached"
    );

    // A file change in the vault re-reads it.
    f.notes
        .items
        .lock()
        .unwrap()
        .push(("Buy milk".into(), TaskStatus::Done));
    f.watcher.fire();
    until(&mut rx, "re-read on change", |b| titles(b).len() == 2).await;
}

#[tokio::test]
async fn api_sources_need_a_token_kept_in_the_secret_store() {
    let f = Fixture::new();
    let service = f.service().await;
    let missing = service.save_source(None, "", todoist(), true, None).await;
    assert!(matches!(missing, Err(TaskError::Auth(_))), "{missing:?}");

    let view = service
        .save_source(None, "", todoist(), true, Some(" tok-1 ".into()))
        .await
        .unwrap();
    assert_eq!(view.source.name, "Todoist");
    assert!(view.has_secret);
    assert_eq!(
        f.secrets.get(&view.source.id).unwrap().as_deref(),
        Some("tok-1")
    );

    let mut rx = service.watch();
    until(&mut rx, "todoist sync", |b| {
        titles(b) == [("Pay rent".to_owned(), TaskStatus::Todo)]
    })
    .await;
    assert_eq!(
        f.todo.secrets_seen.lock().unwrap()[0].as_deref(),
        Some("tok-1")
    );

    // Re-saving without a token keeps the stored one; testing uses it too.
    let id = view.source.id.clone();
    service
        .save_source(Some(id.clone()), "Personal", todoist(), true, None)
        .await
        .unwrap();
    let tested = service
        .test_source(Some(id.clone()), todoist(), None)
        .await
        .unwrap();
    assert_eq!(tested, "Todoist via tok-1");

    service.delete_source(&id).await.unwrap();
    assert_eq!(f.secrets.get(&id).unwrap(), None);
    assert!(service.board().sources.is_empty());
}

#[tokio::test]
async fn status_changes_show_at_once_and_roll_back_when_refused() {
    let f = Fixture::new();
    let service = f.service().await;
    let view = service
        .save_source(None, "Vault", vault("/vault"), true, None)
        .await
        .unwrap();
    let mut rx = service.watch();
    let board = until(&mut rx, "sync", |b| b.task_count() == 1).await;
    let id = board.sources[0].tasks[0].id.clone();

    let done = service.set_status(&id, TaskStatus::Done).await.unwrap();
    assert_eq!(done.status, TaskStatus::Done);
    assert_eq!(service.board().task(&id).unwrap().status, TaskStatus::Done);
    assert_eq!(
        f.store.tasks(&view.source.id).unwrap()[0].status,
        TaskStatus::Done
    );
    assert_eq!(
        f.notes.items.lock().unwrap()[0].1,
        TaskStatus::Done,
        "written back"
    );

    f.notes.fail_write.store(true, Ordering::SeqCst);
    let refused = service.set_status(&id, TaskStatus::Todo).await;
    assert!(matches!(refused, Err(TaskError::Auth(_))));
    assert_eq!(
        service.board().task(&id).unwrap().status,
        TaskStatus::Done,
        "rolled back"
    );

    let review = service.set_status(&id, TaskStatus::Review).await;
    assert!(
        matches!(review, Err(TaskError::Unsupported { .. })),
        "{review:?}"
    );
}

#[tokio::test]
async fn failed_syncs_keep_the_cached_tasks() {
    let f = Fixture::new();
    let service = f.service().await;
    let view = service
        .save_source(None, "Vault", vault("/vault"), true, None)
        .await
        .unwrap();
    let mut rx = service.watch();
    until(&mut rx, "sync", |b| b.task_count() == 1).await;

    f.notes.fail_fetch.store(true, Ordering::SeqCst);
    service.sync(Some(&view.source.id)).unwrap();
    let board = until(&mut rx, "error", |b| b.sources[0].error.is_some()).await;
    assert_eq!(board.sources[0].error.as_deref(), Some("offline"));
    assert_eq!(board.task_count(), 1);
}

#[tokio::test]
async fn disabling_or_repointing_a_source_resets_what_it_shows() {
    let f = Fixture::new();
    let service = f.service().await;
    let view = service
        .save_source(None, "Vault", vault("/vault"), true, None)
        .await
        .unwrap();
    let id = view.source.id.clone();
    let mut rx = service.watch();
    until(&mut rx, "sync", |b| b.task_count() == 1).await;

    service
        .save_source(Some(id.clone()), "Vault", vault("/vault"), false, None)
        .await
        .unwrap();
    assert_eq!(service.board().task_count(), 0);
    assert_eq!(
        f.store.tasks(&id).unwrap().len(),
        1,
        "cache kept while disabled"
    );
    service.sync(Some(&id)).unwrap_err();

    service
        .save_source(Some(id.clone()), "Vault", vault("/other"), true, None)
        .await
        .unwrap();
    let fetches = f.notes.fetches.load(Ordering::SeqCst);
    until(&mut rx, "re-read", |b| b.task_count() == 1).await;
    assert!(f.notes.fetches.load(Ordering::SeqCst) > fetches);

    let kind_change = service
        .save_source(Some(id), "Vault", todoist(), true, Some("t".into()))
        .await;
    assert!(matches!(kind_change, Err(TaskError::Invalid(_))));
}

#[tokio::test]
async fn links_tasks_to_worktrees_and_detects_unconfigured_sources() {
    let f = Fixture::new();
    let service = f.service().await;
    let view = service
        .save_source(None, "Vault", vault("/found"), true, None)
        .await
        .unwrap();
    assert!(service.detect().await.unwrap().is_empty(), "already added");

    let id = TaskId::new(&view.source.id, "x");
    service
        .link(id.clone(), "/wt/a".into(), "feat/a".into())
        .await
        .unwrap();
    service
        .link(id.clone(), "/wt/a".into(), "feat/a".into())
        .await
        .unwrap();
    assert_eq!(service.board().links.len(), 1);
    service.unlink(&id, "/wt/a".as_ref()).await.unwrap();
    assert!(service.board().links.is_empty());
    assert!(f.store.links().unwrap().is_empty());
}
