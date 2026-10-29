//! Kumo application layer: the use cases the daemon exposes.
//!
//! Depends only on the domain and its ports; the infrastructure adapters
//! and the gRPC transport are plugged in from outside.
//!
//! - [`agents`]: the user's coding-agent CLIs and their sessions.
//! - [`changes`]: changes, files and history of one worktree.
//! - [`terminal`]: open, attach to, drive and close terminal sessions.
//! - [`daemon`]: daemon-level use cases (handshake).
//! - [`tasks`]: tasks from the user's tools, synced in the background.
//! - [`test_runs`]: a worktree's tests, run in a terminal and read.
//! - [`workspace`]: namespaces, repositories and worktrees.

pub mod agents;
pub mod changes;
pub mod daemon;
pub mod docs;
pub mod pipelines;
pub mod pulls;
pub mod tasks;
pub mod terminal;
pub mod test_runs;
pub mod workspace;
