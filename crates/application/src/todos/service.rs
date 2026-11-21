use std::path::PathBuf;
use std::sync::{Arc, Mutex, PoisonError};

use kumo_domain::time::Timestamp;
use kumo_domain::todos::{Todo, TodoError, TodoId, TodoRun, TodoStatus, TodoStep, TodoStore};
use tokio::sync::watch;

/// What an edit changes; None leaves it as it is.
#[derive(Debug, Clone, Default)]
pub struct TodoEdit {
    pub title: Option<String>,
    pub notes: Option<String>,
    /// Some(None): any repository.
    pub repo_path: Option<Option<PathBuf>>,
    pub done: Option<bool>,
}

/// A move to another status, and who made it.
#[derive(Debug, Clone)]
pub struct StatusChange {
    pub status: TodoStatus,
    /// An agent's name, "You" or "Kumo".
    pub by: String,
    pub note: String,
    /// With [`TodoStatus::PullRequest`].
    pub pr: Option<(u64, String)>,
    /// With [`TodoStatus::Open`]: forget the run too.
    pub clear_run: bool,
}

/// The profile's TODOs, kept in its database and published to watchers.
pub struct TodoService {
    store: Arc<dyn TodoStore>,
    todos: Mutex<Vec<Todo>>,
    published: watch::Sender<Arc<Vec<Todo>>>,
}

impl std::fmt::Debug for TodoService {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TodoService").finish_non_exhaustive()
    }
}

impl TodoService {
    pub async fn load(store: Arc<dyn TodoStore>) -> Result<Arc<Self>, TodoError> {
        let reader = Arc::clone(&store);
        let todos = blocking(move || reader.todos()).await?;
        let (published, _) = watch::channel(Arc::new(todos.clone()));
        Ok(Arc::new(Self {
            store,
            todos: Mutex::new(todos),
            published,
        }))
    }

    /// Newest first, now and whenever one changes.
    pub fn watch(&self) -> watch::Receiver<Arc<Vec<Todo>>> {
        self.published.subscribe()
    }

    pub fn todos(&self) -> Arc<Vec<Todo>> {
        Arc::clone(&self.published.borrow())
    }

    pub async fn add(
        &self,
        title: &str,
        notes: &str,
        repo_path: Option<PathBuf>,
    ) -> Result<Todo, TodoError> {
        let todo = Todo::new(title, notes, repo_path, Timestamp::now())?;
        self.save(todo, true).await
    }

    pub async fn update(&self, id: &TodoId, edit: TodoEdit) -> Result<Todo, TodoError> {
        let mut todo = self.get(id)?;
        if let Some(title) = edit.title {
            todo.title = Todo::checked_title(&title)?;
        }
        if let Some(notes) = edit.notes {
            todo.notes = notes.trim_end().to_owned();
        }
        if let Some(repo) = edit.repo_path {
            todo.repo_path = repo;
        }
        if let Some(done) = edit.done {
            todo.done = done;
        }
        self.save(todo, false).await
    }

    pub async fn delete(&self, id: &TodoId) -> Result<(), TodoError> {
        self.get(id)?;
        let store = Arc::clone(&self.store);
        let key = id.clone();
        blocking(move || store.delete(&key)).await?;
        self.publish(|todos| todos.retain(|t| &t.id != id));
        Ok(())
    }

    /// Records where it runs: its worktree and agent are up. It starts out
    /// working, as the agent is told to say once it begins.
    pub async fn attach(&self, id: &TodoId, run: TodoRun) -> Result<Todo, TodoError> {
        let mut todo = self.get(id)?;
        if run.worktree_path.as_os_str().is_empty() {
            return Err(TodoError::Invalid("a run needs its worktree".into()));
        }
        let agent = if run.agent_name.is_empty() {
            "You".to_owned()
        } else {
            run.agent_name.clone()
        };
        if todo.repo_path.is_none() && !run.repo_path.as_os_str().is_empty() {
            todo.repo_path = Some(run.repo_path.clone());
        }
        todo.run = Some(run);
        todo.done = false;
        todo.steps.clear();
        todo.move_to(
            TodoStep {
                status: TodoStatus::Working,
                by: agent,
                at: Timestamp::now(),
                note: String::new(),
            },
            false,
        )?;
        self.save(todo, false).await
    }

    pub async fn set_status(&self, id: &TodoId, change: StatusChange) -> Result<Todo, TodoError> {
        let mut todo = self.get(id)?;
        let by = change.by.trim();
        let by = if by.is_empty() { "You" } else { by };
        let step = TodoStep {
            status: change.status,
            by: by.to_owned(),
            at: Timestamp::now(),
            note: change.note.trim().chars().take(200).collect(),
        };
        todo.move_to(step, change.clear_run)?;
        if let (Some((number, url)), Some(run)) = (change.pr, todo.run.as_mut()) {
            run.pr_number = number;
            run.pr_url = url;
        }
        self.save(todo, false).await
    }

    /// What an agent reports from its terminal: only the statuses it may
    /// set (not pushed, the PR or merged), and only on a TODO it runs.
    pub async fn report(
        &self,
        id: &TodoId,
        word: &str,
        agent: &str,
        note: &str,
    ) -> Result<Todo, TodoError> {
        let status = TodoStatus::from_word(word).ok_or_else(|| {
            TodoError::Invalid(format!(
                "unknown status \"{word}\": use working, testing or review"
            ))
        })?;
        if !status.agent_may_report() {
            return Err(TodoError::Invalid(format!(
                "an agent reports working, testing or review; {status} is the user's or Kumo's"
            )));
        }
        let todo = self.get(id)?;
        if todo.run.is_none() || todo.status() >= TodoStatus::Pushed {
            return Err(TodoError::Invalid(
                "this TODO isn't with an agent now".into(),
            ));
        }
        let by = todo
            .run
            .as_ref()
            .map(|r| r.agent_name.clone())
            .filter(|n| !n.is_empty());
        self.set_status(
            id,
            StatusChange {
                status,
                by: by.unwrap_or_else(|| agent.to_owned()),
                note: note.to_owned(),
                pr: None,
                clear_run: false,
            },
        )
        .await
    }

    fn get(&self, id: &TodoId) -> Result<Todo, TodoError> {
        self.lock()
            .iter()
            .find(|t| &t.id == id)
            .cloned()
            .ok_or_else(|| TodoError::Unknown(id.to_string()))
    }

    async fn save(&self, todo: Todo, new: bool) -> Result<Todo, TodoError> {
        let store = Arc::clone(&self.store);
        let saved = todo.clone();
        blocking(move || store.save(&saved)).await?;
        self.publish(|todos| match todos.iter_mut().find(|t| t.id == todo.id) {
            Some(slot) => *slot = todo.clone(),
            None if new => todos.insert(0, todo.clone()),
            None => todos.push(todo.clone()),
        });
        Ok(todo)
    }

    fn publish(&self, change: impl FnOnce(&mut Vec<Todo>)) {
        let mut todos = self.lock();
        change(&mut todos);
        self.published.send_replace(Arc::new(todos.clone()));
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, Vec<Todo>> {
        self.todos.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

async fn blocking<T: Send + 'static>(
    f: impl FnOnce() -> Result<T, TodoError> + Send + 'static,
) -> Result<T, TodoError> {
    tokio::task::spawn_blocking(f)
        .await
        .map_err(|e| TodoError::Store(format!("blocking task failed: {e}")))?
}
