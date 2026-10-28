//! Kumo application layer: the use cases the daemon exposes.
//!
//! Depends only on the domain and its ports; the infrastructure adapters
//! and the gRPC transport are plugged in from outside.
//!
//! - [`agents`]: the user's coding-agent CLIs and their sessions.
//! - [`changes`]: changes, files and history of one worktree.
//! - [`terminal`]: open, attach to, drive and close terminal sessions.
//! - [`daemon`]: daemon-level use cases (handshake).
//! - [`workspace`]: namespaces, repositories and worktrees.

pub mod agents;
pub mod changes;
pub mod daemon;
pub mod terminal;
pub mod workspace;
