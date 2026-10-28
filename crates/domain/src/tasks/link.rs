use std::path::PathBuf;

use super::TaskId;
use crate::time::Timestamp;

/// A task being worked on in a worktree.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TaskLink {
    pub task: TaskId,
    pub worktree: PathBuf,
    pub branch: String,
    pub created: Timestamp,
}
