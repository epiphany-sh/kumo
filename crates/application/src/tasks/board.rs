use std::sync::Arc;

use kumo_domain::tasks::{SourceId, Task, TaskId, TaskLink, TaskSource};
use kumo_domain::time::Timestamp;

/// A source and the tasks it last returned.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceView {
    pub source: TaskSource,
    /// An API token is stored for it.
    pub has_secret: bool,
    pub syncing: bool,
    pub last_synced: Option<Timestamp>,
    /// Why the last sync failed; its cached tasks are still shown.
    pub error: Option<String>,
    /// Empty while the source is disabled.
    pub tasks: Arc<[Task]>,
    /// Bumped only when `tasks` changes, so clients resend only those.
    pub tasks_version: u64,
}

/// Everything the Tasks view shows, pushed whole on each change (last
/// wins). Task lists are shared, so cloning it is cheap.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct TaskBoard {
    pub version: u64,
    pub sources: Vec<SourceView>,
    pub links: Vec<TaskLink>,
}

impl TaskBoard {
    pub fn source(&self, id: &SourceId) -> Option<&SourceView> {
        self.sources.iter().find(|s| &s.source.id == id)
    }

    pub(super) fn source_mut(&mut self, id: &SourceId) -> Option<&mut SourceView> {
        self.sources.iter_mut().find(|s| &s.source.id == id)
    }

    pub fn task(&self, id: &TaskId) -> Option<&Task> {
        self.source(&id.source())?
            .tasks
            .iter()
            .find(|t| &t.id == id)
    }

    pub fn task_count(&self) -> usize {
        self.sources.iter().map(|s| s.tasks.len()).sum()
    }
}
