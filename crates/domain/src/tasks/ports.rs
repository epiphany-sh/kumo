//! Ports implemented by the infrastructure layer. They block; the
//! application calls them off the async threads.

use std::path::PathBuf;

use super::{
    SourceId, SourceKind, SourceOptions, Task, TaskDetail, TaskError, TaskId, TaskLink, TaskSource,
    TaskStatus,
};

/// The local cache: sources, their last fetched tasks and the links to
/// worktrees.
pub trait TaskStore: Send + Sync + 'static {
    /// In the order they were added.
    fn sources(&self) -> Result<Vec<TaskSource>, TaskError>;
    fn save_source(&self, source: &TaskSource) -> Result<(), TaskError>;
    /// Also forgets its tasks.
    fn delete_source(&self, id: &SourceId) -> Result<(), TaskError>;
    fn tasks(&self, source: &SourceId) -> Result<Vec<Task>, TaskError>;
    /// Replaces every task of `source`.
    fn replace_tasks(&self, source: &SourceId, tasks: &[Task]) -> Result<(), TaskError>;
    fn links(&self) -> Result<Vec<TaskLink>, TaskError>;
    /// Links are keyed by task and worktree.
    fn save_link(&self, link: &TaskLink) -> Result<(), TaskError>;
    fn delete_link(&self, link: &TaskLink) -> Result<(), TaskError>;
    /// The last detail read for a task, with when it was read.
    fn detail(&self, id: &TaskId) -> Result<Option<TaskDetail>, TaskError>;
    /// Replaces the cached detail of `detail.task`.
    fn save_detail(&self, detail: &TaskDetail) -> Result<(), TaskError>;
    /// Forgets every cached detail of `source` (it now reads elsewhere).
    fn delete_details(&self, source: &SourceId) -> Result<(), TaskError>;
}

/// API tokens, in the OS keychain.
pub trait SecretStore: Send + Sync + 'static {
    fn get(&self, source: &SourceId) -> Result<Option<String>, TaskError>;
    fn set(&self, source: &SourceId, secret: &str) -> Result<(), TaskError>;
    fn delete(&self, source: &SourceId) -> Result<(), TaskError>;
}

/// A source found on this machine, ready to add.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Detected {
    pub name: String,
    pub options: SourceOptions,
}

/// Talks to one kind of tool. `secret` is the source's API token, when its
/// kind needs one.
pub trait TaskConnector: Send + Sync + 'static {
    fn kind(&self) -> SourceKind;
    /// Every task the source currently shows.
    fn fetch(&self, source: &TaskSource, secret: Option<&str>) -> Result<Vec<Task>, TaskError>;
    /// Writes `status` back; only the kind's [`SourceKind::writable`] ones.
    fn set_status(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        task: &Task,
        status: TaskStatus,
    ) -> Result<(), TaskError>;
    /// The whole ticket `id`. `known` is the board's copy, when it's on the
    /// board (linked tickets and parents may not be). By default, only
    /// what the card says.
    fn detail(
        &self,
        _source: &TaskSource,
        _secret: Option<&str>,
        id: &TaskId,
        known: Option<&Task>,
    ) -> Result<TaskDetail, TaskError> {
        known
            .map(|task| TaskDetail::basic(task.clone()))
            .ok_or_else(|| TaskError::UnknownTask(id.to_string()))
    }
    /// Checks the options and credentials; says who or what it reached.
    fn test(&self, source: &TaskSource, secret: Option<&str>) -> Result<String, TaskError>;
    /// Files whose changes mean the tasks changed (local sources).
    fn watched_paths(&self, source: &TaskSource) -> Vec<PathBuf>;
    /// Sources of this kind found on this machine.
    fn detect(&self) -> Vec<Detected>;
}
