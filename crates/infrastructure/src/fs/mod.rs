//! Files inside worktrees.

mod local;
mod project;

pub use local::LocalFileStore;
pub use project::LocalProjectReader;
