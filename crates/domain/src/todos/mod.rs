//! The user's own TODOs: kept on this Mac by the profile, never synced.
//!
//! A TODO can be handed to an agent in a new worktree. From then on it has a
//! status: the agent reports how it goes (working, testing, then waiting for
//! the user's review), the user approves and pushes, and Kumo follows the
//! pull request until it merges.

mod todo;

pub use todo::{Todo, TodoError, TodoId, TodoRun, TodoStatus, TodoStep};

/// Where TODOs are kept. Blocks; the application calls it off the async
/// threads.
pub trait TodoStore: Send + Sync + 'static {
    /// Newest first.
    fn todos(&self) -> Result<Vec<Todo>, TodoError>;
    /// Inserts or replaces `todo`.
    fn save(&self, todo: &Todo) -> Result<(), TodoError>;
    fn delete(&self, id: &TodoId) -> Result<(), TodoError>;
}
