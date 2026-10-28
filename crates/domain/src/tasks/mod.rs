//! Tasks from the tools the user already works with (Obsidian, Bear, GitHub
//! Issues, Jira, Todoist), cached locally so nothing waits on the network.
//! A task can be worked on in a worktree; its status goes back to the tool.

mod detail;
mod error;
mod filter;
mod link;
mod markdown;
mod meta;
mod ports;
mod source;
mod task;

pub use detail::{
    Attachment, Comment, DETAIL_FRESH_FOR, LinkKind, LinkedTask, TaskDetail, TimeTracking,
};

pub use error::TaskError;
pub use filter::TaskFilter;
pub use link::TaskLink;
pub use markdown::{Checkbox, parse_checkboxes, section_around, set_checkbox};
pub use meta::{Person, Points, Progress, Sprint, SprintState, TaskRef, TaskRelation, TaskType};
pub use ports::{Detected, SecretStore, TaskConnector, TaskStore};
pub use source::{SourceId, SourceKind, SourceOptions, TaskSource};
pub use task::{Priority, Task, TaskId, TaskStatus};
