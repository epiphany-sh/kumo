//! Tasks from the tools the user already works with (Obsidian, Bear, GitHub
//! Issues, Jira, Todoist), cached locally so nothing waits on the network.
//! A task can be worked on in a worktree; its status goes back to the tool.

mod error;
mod filter;
mod link;
mod markdown;
mod ports;
mod source;
mod task;

pub use error::TaskError;
pub use filter::TaskFilter;
pub use link::TaskLink;
pub use markdown::{Checkbox, parse_checkboxes, set_checkbox};
pub use ports::{Detected, SecretStore, TaskConnector, TaskStore};
pub use source::{SourceId, SourceKind, SourceOptions, TaskSource};
pub use task::{Priority, Task, TaskId, TaskStatus};
