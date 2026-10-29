use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError, Weak};
use std::time::Duration;

use kumo_domain::changes::{ChangeWatcher, WatchGuard};
use kumo_domain::tasks::{
    Detected, SecretStore, SourceId, SourceOptions, Task, TaskConnector, TaskDetail, TaskError,
    TaskId, TaskLink, TaskSource, TaskStatus, TaskStore,
};
use kumo_domain::time::Timestamp;
use tokio::sync::{Notify, watch};
use tokio::task::JoinHandle;

use super::{SourceView, TaskBoard};

/// The adapters the service works with.
#[derive(Clone)]
pub struct TaskPorts {
    pub store: Arc<dyn TaskStore>,
    pub secrets: Arc<dyn SecretStore>,
    /// One per kind of source.
    pub connectors: Vec<Arc<dyn TaskConnector>>,
    pub watcher: Arc<dyn ChangeWatcher>,
}

impl std::fmt::Debug for TaskPorts {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TaskPorts").finish_non_exhaustive()
    }
}

/// When sources are read.
#[derive(Debug, Clone, Copy)]
pub struct TaskTiming {
    /// APIs can't push to a desktop app: they are read on this interval (and
    /// whenever the user asks).
    pub remote_every: Duration,
    /// Local files change in bursts: wait for them to settle.
    pub settle: Duration,
}

impl Default for TaskTiming {
    fn default() -> Self {
        Self {
            remote_every: Duration::from_secs(180),
            settle: Duration::from_millis(150),
        }
    }
}

/// Keeps one source fresh; dropping it stops it.
struct Worker {
    wake: Arc<Notify>,
    task: JoinHandle<()>,
}

impl Drop for Worker {
    fn drop(&mut self) {
        self.task.abort();
    }
}

/// Tasks from the user's tools. The board is served from the local cache
/// right away; each enabled source is re-read in the background (on file
/// changes for local ones, on an interval for APIs) and the board is pushed
/// again when it changes.
pub struct TaskService {
    ports: TaskPorts,
    timing: TaskTiming,
    board: Mutex<TaskBoard>,
    published: watch::Sender<Arc<TaskBoard>>,
    workers: Mutex<HashMap<SourceId, Worker>>,
    /// Read once from the keychain (each read may ask the user).
    secrets: Mutex<HashMap<SourceId, Option<String>>>,
    this: Weak<TaskService>,
}

impl std::fmt::Debug for TaskService {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TaskService").finish_non_exhaustive()
    }
}

impl TaskService {
    /// Loads the cache and starts keeping enabled sources fresh.
    pub async fn load(ports: TaskPorts, timing: TaskTiming) -> Result<Arc<Self>, TaskError> {
        let store = Arc::clone(&ports.store);
        let (sources, links) = blocking(move || {
            let sources = store
                .sources()?
                .into_iter()
                .map(|source| {
                    let tasks = if source.enabled {
                        store.tasks(&source.id)?
                    } else {
                        vec![]
                    };
                    Ok((source, tasks))
                })
                .collect::<Result<Vec<_>, TaskError>>()?;
            Ok((sources, store.links()?))
        })
        .await?;
        let board = TaskBoard {
            version: 1,
            sources: sources
                .into_iter()
                .map(|(source, tasks)| SourceView {
                    source,
                    has_secret: false,
                    syncing: false,
                    last_synced: None,
                    error: None,
                    tasks: tasks.into(),
                    tasks_version: 1,
                })
                .collect(),
            links,
        };
        let (published, _) = watch::channel(Arc::new(board.clone()));
        let service = Arc::new_cyclic(|this| Self {
            ports,
            timing,
            board: Mutex::new(board),
            published,
            workers: Mutex::new(HashMap::new()),
            secrets: Mutex::new(HashMap::new()),
            this: this.clone(),
        });
        let sources: Vec<TaskSource> = service
            .lock()
            .sources
            .iter()
            .map(|v| v.source.clone())
            .collect();
        // The keychain may ask the user first (a new build, a new item): the
        // daemon must answer meanwhile, so secrets are read afterwards.
        let starting = Arc::clone(&service);
        tokio::spawn(async move {
            for source in sources {
                if source.kind().needs_secret() {
                    let has_secret = starting.secret(&source.id).await.ok().flatten().is_some();
                    starting.update(|b| {
                        b.source_mut(&source.id)
                            .into_iter()
                            .for_each(|v| v.has_secret = has_secret)
                    });
                }
                if source.enabled {
                    starting.start_worker(&source);
                }
            }
        });
        Ok(service)
    }

    /// The board now, then whenever it changes.
    pub fn watch(&self) -> watch::Receiver<Arc<TaskBoard>> {
        self.published.subscribe()
    }

    pub fn board(&self) -> Arc<TaskBoard> {
        Arc::clone(&self.published.borrow())
    }

    // ---- Sources ----

    /// Creates (`id` None) or updates a source. `secret`, when given,
    /// replaces its stored API token.
    pub async fn save_source(
        &self,
        id: Option<SourceId>,
        name: &str,
        options: SourceOptions,
        enabled: bool,
        secret: Option<String>,
    ) -> Result<SourceView, TaskError> {
        let kind = options.kind();
        let current = match &id {
            Some(id) => Some(
                self.lock()
                    .source(id)
                    .cloned()
                    .ok_or_else(|| TaskError::UnknownSource(id.to_string()))?,
            ),
            None => None,
        };
        if let Some(current) = &current
            && current.source.kind() != kind
        {
            return Err(TaskError::Invalid(format!(
                "a {} source can't become {kind}: add a new one",
                current.source.kind()
            )));
        }
        let secret = secret
            .map(|s| s.trim().to_owned())
            .filter(|s| !s.is_empty());
        let has_secret = secret.is_some() || current.as_ref().is_some_and(|c| c.has_secret);
        if kind.needs_secret() && enabled && !has_secret {
            return Err(TaskError::Auth(format!("{kind} needs an API token")));
        }
        let name = name.trim();
        let source = TaskSource {
            id: id.unwrap_or_else(SourceId::generate),
            name: if name.is_empty() { kind.name() } else { name }.to_owned(),
            options,
            enabled,
        };

        let options_changed = current
            .as_ref()
            .is_some_and(|c| c.source.options != source.options);
        let reload = current
            .as_ref()
            .is_none_or(|c| options_changed || c.source.enabled != source.enabled);

        let (store, secrets) = (
            Arc::clone(&self.ports.store),
            Arc::clone(&self.ports.secrets),
        );
        let (saved, new_secret) = (source.clone(), secret.clone());
        let cached = blocking(move || {
            if let Some(secret) = &new_secret {
                secrets.set(&saved.id, secret)?;
            }
            store.save_source(&saved)?;
            if options_changed {
                // They came from somewhere else.
                store.replace_tasks(&saved.id, &[])?;
                store.delete_details(&saved.id)?;
            }
            if saved.enabled {
                store.tasks(&saved.id)
            } else {
                Ok(vec![])
            }
        })
        .await?;
        if let Some(secret) = secret {
            self.lock_secrets().insert(source.id.clone(), Some(secret));
        }

        let view = self.update(|board| {
            if board.source(&source.id).is_none() {
                board.sources.push(SourceView {
                    source: source.clone(),
                    has_secret,
                    syncing: false,
                    last_synced: None,
                    error: None,
                    tasks: Arc::from([]),
                    tasks_version: 0,
                });
            }
            let Some(view) = board.source_mut(&source.id) else {
                unreachable!("just added")
            };
            view.source = source.clone();
            view.has_secret = has_secret;
            if reload {
                view.error = None;
                view.last_synced = None;
                if *view.tasks != *cached {
                    view.tasks = cached.into();
                    view.tasks_version += 1;
                }
            }
            view.clone()
        });

        self.stop_worker(&source.id);
        if source.enabled {
            self.start_worker(&source);
        }
        Ok(view)
    }

    /// Forgets a source, its tasks, links and token.
    pub async fn delete_source(&self, id: &SourceId) -> Result<(), TaskError> {
        if self.lock().source(id).is_none() {
            return Err(TaskError::UnknownSource(id.to_string()));
        }
        self.stop_worker(id);
        let (store, secrets) = (
            Arc::clone(&self.ports.store),
            Arc::clone(&self.ports.secrets),
        );
        let links: Vec<TaskLink> = self
            .lock()
            .links
            .iter()
            .filter(|l| &l.task.source() == id)
            .cloned()
            .collect();
        let deleted = id.clone();
        blocking(move || {
            for link in &links {
                store.delete_link(link)?;
            }
            store.delete_source(&deleted)?;
            if let Err(error) = secrets.delete(&deleted) {
                tracing::warn!(%error, "couldn't remove the source's token");
            }
            Ok(())
        })
        .await?;
        self.lock_secrets().remove(id);
        self.update(|board| {
            board.sources.retain(|s| &s.source.id != id);
            board.links.retain(|l| &l.task.source() != id);
        });
        Ok(())
    }

    /// Checks options and credentials without saving them. Without a new
    /// `secret`, the one stored for `id` is used.
    pub async fn test_source(
        &self,
        id: Option<SourceId>,
        options: SourceOptions,
        secret: Option<String>,
    ) -> Result<String, TaskError> {
        let kind = options.kind();
        let secret = match secret
            .map(|s| s.trim().to_owned())
            .filter(|s| !s.is_empty())
        {
            Some(secret) => Some(secret),
            None => match &id {
                Some(id) => self.secret(id).await?,
                None => None,
            },
        };
        if kind.needs_secret() && secret.is_none() {
            return Err(TaskError::Auth(format!("enter your {kind} API token")));
        }
        let source = TaskSource {
            id: id.unwrap_or_else(SourceId::generate),
            name: kind.name().to_owned(),
            options,
            enabled: true,
        };
        let connector = self.connector(&source)?;
        blocking(move || connector.test(&source, secret.as_deref())).await
    }

    /// Sources found on this machine that aren't configured yet.
    pub async fn detect(&self) -> Result<Vec<Detected>, TaskError> {
        let connectors = self.ports.connectors.clone();
        let detected = blocking(move || {
            Ok(connectors
                .iter()
                .flat_map(|c| c.detect())
                .collect::<Vec<_>>())
        })
        .await?;
        let board = self.lock();
        Ok(detected
            .into_iter()
            .filter(|d| !board.sources.iter().any(|s| s.source.options == d.options))
            .collect())
    }

    /// Reads a source (or all of them) now.
    pub fn sync(&self, id: Option<&SourceId>) -> Result<(), TaskError> {
        let workers = self.lock_workers();
        match id {
            Some(id) => {
                let worker = workers
                    .get(id)
                    .ok_or_else(|| TaskError::UnknownSource(id.to_string()))?;
                worker.wake.notify_one();
            }
            None => workers.values().for_each(|w| w.wake.notify_one()),
        }
        Ok(())
    }

    // ---- Tasks ----

    /// Writes the status back to the source. The board shows it right away
    /// and goes back if the source refuses.
    pub async fn set_status(&self, id: &TaskId, status: TaskStatus) -> Result<Task, TaskError> {
        let (source, task) = {
            let board = self.lock();
            let view = board
                .source(&id.source())
                .filter(|v| v.source.enabled)
                .ok_or_else(|| TaskError::UnknownSource(id.source().to_string()))?;
            let task = view
                .tasks
                .iter()
                .find(|t| &t.id == id)
                .cloned()
                .ok_or_else(|| TaskError::UnknownTask(id.to_string()))?;
            (view.source.clone(), task)
        };
        let kind = source.kind();
        if !kind.writable().contains(&status) {
            return Err(TaskError::Unsupported { kind, status });
        }
        if task.status == status {
            return Ok(task);
        }
        let updated = Task {
            status,
            ..task.clone()
        };
        self.replace_task(&updated, None);

        let written = async {
            let secret = self.secret(&source.id).await?;
            let connector = self.connector(&source)?;
            let (source, task) = (source.clone(), task.clone());
            blocking(move || connector.set_status(&source, secret.as_deref(), &task, status)).await
        }
        .await;
        match written {
            Ok(()) => {
                self.persist_tasks(&source.id).await;
                self.patch_detail(id, status).await;
                Ok(updated)
            }
            Err(error) => {
                self.replace_task(&task, Some(status));
                Err(error)
            }
        }
    }

    /// The whole ticket. A detail read less than [`DETAIL_FRESH_FOR`] ago
    /// is served from the cache unless `refresh`; when the source can't be
    /// reached, the cached one is served marked stale.
    ///
    /// [`DETAIL_FRESH_FOR`]: kumo_domain::tasks::DETAIL_FRESH_FOR
    pub async fn get_task(&self, id: &TaskId, refresh: bool) -> Result<TaskDetail, TaskError> {
        let (source, known) = {
            let board = self.lock();
            let view = board
                .source(&id.source())
                .filter(|v| v.source.enabled)
                .ok_or_else(|| TaskError::UnknownSource(id.source().to_string()))?;
            let known = view.tasks.iter().find(|t| &t.id == id).cloned();
            (view.source.clone(), known)
        };
        let store = Arc::clone(&self.ports.store);
        let key = id.clone();
        let cached = blocking(move || store.detail(&key)).await?;
        if let Some(cached) = &cached
            && !refresh
            && cached.is_fresh(Timestamp::now())
        {
            return Ok(cached.clone());
        }

        let fetched = async {
            let secret = self.secret(&source.id).await?;
            if source.kind().needs_secret() && secret.is_none() {
                return Err(TaskError::Auth(format!(
                    "add your {} API token in Settings › Tasks",
                    source.kind()
                )));
            }
            let connector = self.connector(&source)?;
            let (reading, key) = (source.clone(), id.clone());
            let mut detail = blocking(move || {
                connector.detail(&reading, secret.as_deref(), &key, known.as_ref())
            })
            .await?;
            detail.fetched = Timestamp::now();
            detail.stale = None;
            Ok(detail)
        }
        .await;

        match (fetched, cached) {
            (Ok(detail), _) => {
                let store = Arc::clone(&self.ports.store);
                let saved = detail.clone();
                if let Err(error) = blocking(move || store.save_detail(&saved)).await {
                    tracing::warn!(%error, "couldn't cache a task's detail");
                }
                Ok(detail)
            }
            (Err(error), Some(cached)) if unreachable(&error) => {
                tracing::debug!(task = %id, %error, "serving a cached task detail");
                Ok(TaskDetail {
                    stale: Some(short(&error.to_string())),
                    ..cached
                })
            }
            (Err(error), _) => Err(error),
        }
    }

    /// Records that `task` is being worked on in `worktree`.
    pub async fn link(
        &self,
        task: TaskId,
        worktree: PathBuf,
        branch: String,
    ) -> Result<TaskLink, TaskError> {
        let link = TaskLink {
            task,
            worktree,
            branch,
            created: Timestamp::now(),
        };
        let store = Arc::clone(&self.ports.store);
        let saved = link.clone();
        blocking(move || store.save_link(&saved)).await?;
        self.update(|board| {
            board
                .links
                .retain(|l| !(l.task == link.task && l.worktree == link.worktree));
            board.links.push(link.clone());
        });
        Ok(link)
    }

    pub async fn unlink(&self, task: &TaskId, worktree: &std::path::Path) -> Result<(), TaskError> {
        let Some(link) = self
            .lock()
            .links
            .iter()
            .find(|l| &l.task == task && l.worktree == worktree)
            .cloned()
        else {
            return Ok(());
        };
        let store = Arc::clone(&self.ports.store);
        let deleted = link.clone();
        blocking(move || store.delete_link(&deleted)).await?;
        self.update(|board| board.links.retain(|l| *l != link));
        Ok(())
    }

    // ---- Background sync ----

    fn start_worker(&self, source: &TaskSource) {
        let wake = Arc::new(Notify::new());
        let service = self.this.clone();
        let id = source.id.clone();
        let local = source.kind().is_local();
        let watched = match (local, self.connector(source)) {
            (true, Ok(connector)) => connector.watched_paths(source),
            _ => vec![],
        };
        let (watcher, timing, signal) = (
            Arc::clone(&self.ports.watcher),
            self.timing,
            Arc::clone(&wake),
        );
        let task = tokio::spawn(async move {
            let _watch = watch_files(watcher, watched, Arc::clone(&signal)).await;
            loop {
                let Some(service) = service.upgrade() else {
                    return;
                };
                service.sync_source(&id).await;
                drop(service);
                if local {
                    signal.notified().await;
                    tokio::time::sleep(timing.settle).await;
                } else {
                    tokio::select! {
                        () = signal.notified() => {}
                        () = tokio::time::sleep(timing.remote_every) => {}
                    }
                }
            }
        });
        self.lock_workers()
            .insert(source.id.clone(), Worker { wake, task });
    }

    fn stop_worker(&self, id: &SourceId) {
        self.lock_workers().remove(id);
    }

    async fn sync_source(&self, id: &SourceId) {
        let Some(source) = self
            .lock()
            .source(id)
            .filter(|v| v.source.enabled)
            .map(|v| v.source.clone())
        else {
            return;
        };
        self.update(|b| b.source_mut(id).into_iter().for_each(|v| v.syncing = true));
        let fetched = async {
            let secret = self.secret(id).await?;
            if source.kind().needs_secret() && secret.is_none() {
                return Err(TaskError::Auth(format!(
                    "add your {} API token in Settings › Tasks",
                    source.kind()
                )));
            }
            let connector = self.connector(&source)?;
            let reading = source.clone();
            let tasks = blocking(move || connector.fetch(&reading, secret.as_deref())).await?;
            let unchanged = self.lock().source(id).is_some_and(|v| *v.tasks == *tasks);
            if !unchanged {
                let (store, id) = (Arc::clone(&self.ports.store), id.clone());
                let saved = tasks.clone();
                blocking(move || store.replace_tasks(&id, &saved)).await?;
            }
            Ok(tasks)
        }
        .await;
        self.update(|board| {
            let Some(view) = board.source_mut(id) else {
                return;
            };
            view.syncing = false;
            match fetched {
                Ok(tasks) => {
                    view.last_synced = Some(Timestamp::now());
                    view.error = None;
                    if *view.tasks != *tasks {
                        view.tasks = tasks.into();
                        view.tasks_version += 1;
                    }
                }
                Err(error) => {
                    tracing::debug!(source = %id, %error, "task sync failed");
                    view.error = Some(error.to_string());
                }
            }
        });
    }

    // ---- Helpers ----

    /// Puts `task` in its source's list; with `only_if`, only while the
    /// listed one still has that status (a sync may have replaced it).
    fn replace_task(&self, task: &Task, only_if: Option<TaskStatus>) {
        self.update(|board| {
            let Some(view) = board.source_mut(&task.id.source()) else {
                return;
            };
            let Some(at) = view.tasks.iter().position(|t| t.id == task.id) else {
                return;
            };
            if only_if.is_some_and(|status| view.tasks[at].status != status) {
                return;
            }
            let mut tasks = view.tasks.to_vec();
            tasks[at] = task.clone();
            view.tasks = tasks.into();
            view.tasks_version += 1;
        });
    }

    /// Keeps a cached detail in step with a status Kumo wrote back.
    async fn patch_detail(&self, id: &TaskId, status: TaskStatus) {
        let (store, key) = (Arc::clone(&self.ports.store), id.clone());
        let patched = blocking(move || match store.detail(&key)? {
            Some(mut detail) if detail.task.status != status => {
                detail.task.status = status;
                store.save_detail(&detail)
            }
            _ => Ok(()),
        })
        .await;
        if let Err(error) = patched {
            tracing::warn!(%error, "couldn't update a cached task detail");
        }
    }

    async fn persist_tasks(&self, id: &SourceId) {
        let Some(tasks) = self.lock().source(id).map(|v| Arc::clone(&v.tasks)) else {
            return;
        };
        let (store, id) = (Arc::clone(&self.ports.store), id.clone());
        if let Err(error) = blocking(move || store.replace_tasks(&id, &tasks)).await {
            tracing::warn!(%error, "couldn't cache tasks");
        }
    }

    async fn secret(&self, id: &SourceId) -> Result<Option<String>, TaskError> {
        if let Some(secret) = self.lock_secrets().get(id) {
            return Ok(secret.clone());
        }
        let (secrets, key) = (Arc::clone(&self.ports.secrets), id.clone());
        let secret = blocking(move || secrets.get(&key)).await?;
        self.lock_secrets().insert(id.clone(), secret.clone());
        Ok(secret)
    }

    fn connector(&self, source: &TaskSource) -> Result<Arc<dyn TaskConnector>, TaskError> {
        self.ports
            .connectors
            .iter()
            .find(|c| c.kind() == source.kind())
            .cloned()
            .ok_or_else(|| TaskError::Invalid(format!("{} isn't supported here", source.kind())))
    }

    fn update<T>(&self, change: impl FnOnce(&mut TaskBoard) -> T) -> T {
        let mut board = self.lock();
        let result = change(&mut board);
        board.version += 1;
        self.published.send_replace(Arc::new(board.clone()));
        result
    }

    fn lock(&self) -> MutexGuard<'_, TaskBoard> {
        self.board.lock().unwrap_or_else(PoisonError::into_inner)
    }

    fn lock_workers(&self) -> MutexGuard<'_, HashMap<SourceId, Worker>> {
        self.workers.lock().unwrap_or_else(PoisonError::into_inner)
    }

    fn lock_secrets(&self) -> MutexGuard<'_, HashMap<SourceId, Option<String>>> {
        self.secrets.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

async fn watch_files(
    watcher: Arc<dyn ChangeWatcher>,
    paths: Vec<PathBuf>,
    wake: Arc<Notify>,
) -> Option<Box<dyn WatchGuard>> {
    if paths.is_empty() {
        return None;
    }
    let started = tokio::task::spawn_blocking(move || {
        watcher.watch(&paths, Box::new(move || wake.notify_one()))
    })
    .await;
    match started {
        Ok(Ok(guard)) => Some(guard),
        Ok(Err(error)) => {
            tracing::warn!(%error, "can't watch the source's files: changes show on the next sync");
            None
        }
        Err(_) => None,
    }
}

/// The source couldn't be asked (offline, down, signed out): the cache is
/// still the best answer.
fn unreachable(error: &TaskError) -> bool {
    matches!(error, TaskError::Unavailable(_) | TaskError::Auth(_))
}

/// The first line of an error, cut to fit a notice.
fn short(message: &str) -> String {
    const MAX: usize = 160;
    let line = message.lines().next().unwrap_or_default().trim();
    if line.chars().count() <= MAX {
        line.to_owned()
    } else {
        let cut: String = line.chars().take(MAX - 1).collect();
        format!("{}…", cut.trim_end())
    }
}

async fn blocking<T: Send + 'static>(
    f: impl FnOnce() -> Result<T, TaskError> + Send + 'static,
) -> Result<T, TaskError> {
    tokio::task::spawn_blocking(f)
        .await
        .map_err(|e| TaskError::Store(format!("blocking task failed: {e}")))?
}
