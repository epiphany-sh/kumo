//! The whole ticket, read when the user opens it: what a card can't hold.

use super::{Person, Task, TaskRef};
use crate::time::Timestamp;

/// How long a ticket's detail is served from the cache before the source is
/// asked again.
pub const DETAIL_FRESH_FOR: std::time::Duration = std::time::Duration::from_secs(120);

/// How another ticket relates to this one.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum LinkKind {
    Blocks,
    BlockedBy,
    Relates,
    Duplicates,
    DuplicatedBy,
    Other,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinkedTask {
    pub kind: LinkKind,
    /// The source's own wording ("is blocked by", "clones").
    pub relation: String,
    pub task: TaskRef,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Attachment {
    pub name: String,
    /// Readable: "PNG image", "CSV", "PDF".
    pub kind: String,
    pub size_bytes: u64,
    pub url: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Comment {
    pub author: Option<Person>,
    pub created: Option<Timestamp>,
    /// Markdown.
    pub body: String,
}

/// Estimated, logged and remaining time, in the source's wording ("1d 4h")
/// and in seconds.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct TimeTracking {
    pub estimate: String,
    pub logged: String,
    pub remaining: String,
    pub estimate_seconds: u64,
    pub logged_seconds: u64,
    pub remaining_seconds: u64,
}

impl TimeTracking {
    pub fn is_empty(&self) -> bool {
        *self == Self::default()
    }
}

/// Everything about one ticket.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TaskDetail {
    /// The card's fields, as fresh as the detail.
    pub task: Task,
    pub reporter: Option<Person>,
    pub created: Option<Timestamp>,
    /// Markdown (rich text converted).
    pub description: String,
    /// Markdown; empty when the source has no such field.
    pub acceptance_criteria: String,
    pub subtasks: Vec<TaskRef>,
    pub links: Vec<LinkedTask>,
    pub attachments: Vec<Attachment>,
    /// Oldest first, all of them.
    pub comments: Vec<Comment>,
    pub components: Vec<String>,
    pub fix_versions: Vec<String>,
    pub time_tracking: Option<TimeTracking>,
    /// Where a personal task lives ("Weekly.md · line 14").
    pub location: String,
    /// When the source answered.
    pub fetched: Timestamp,
    /// Why it's served from the cache: the source couldn't be reached.
    pub stale: Option<String>,
}

impl TaskDetail {
    /// Only what the card already says: for sources with nothing more.
    pub fn basic(task: Task) -> Self {
        Self {
            task,
            reporter: None,
            created: None,
            description: String::new(),
            acceptance_criteria: String::new(),
            subtasks: vec![],
            links: vec![],
            attachments: vec![],
            comments: vec![],
            components: vec![],
            fix_versions: vec![],
            time_tracking: None,
            location: String::new(),
            fetched: Timestamp::now(),
            stale: None,
        }
    }

    /// Fresh enough to answer without asking the source again.
    pub fn is_fresh(&self, now: Timestamp) -> bool {
        now.since(self.fetched) < DETAIL_FRESH_FOR
    }
}
