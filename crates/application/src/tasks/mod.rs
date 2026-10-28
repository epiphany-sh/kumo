//! Task use cases: configure sources, keep their tasks in the local cache
//! fresh in the background, write statuses back and link tasks to
//! worktrees.

mod board;
mod service;

pub use board::{SourceView, TaskBoard};
pub use service::{TaskPorts, TaskService, TaskTiming};

#[cfg(test)]
mod tests;
