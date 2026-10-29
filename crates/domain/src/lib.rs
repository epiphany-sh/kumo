//! Kumo domain layer.
//!
//! Pure business types and rules. This crate does no I/O and depends on no
//! runtime or transport: outer layers implement its ports (traits).
//!
//! - [`agents`]: the user's coding-agent CLIs and the sessions they run.
//! - [`changes`]: changes, files and history of one worktree.
//! - [`terminal`]: PTY-backed terminal sessions, their output and lifecycle.
//! - [`daemon`]: daemon identity, security and discovery rules.
//! - [`pipelines`]: CI runs of a worktree's branch on its repository's host.
//! - [`pulls`]: pull requests of the workspace's repositories.
//! - [`tasks`]: tasks from the user's tools, cached locally.
//! - [`test_runs`]: a worktree's tests, run and read as they go.
//! - [`workspace`]: namespaces, git repositories and their worktrees.

pub mod agents;
pub mod changes;
pub mod daemon;
pub mod docs;
pub mod pipelines;
pub mod pulls;
pub mod tasks;
pub mod terminal;
pub mod test_runs;
pub mod time;
pub mod workspace;
