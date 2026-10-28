//! Kumo domain layer.
//!
//! Pure business types and rules. This crate does no I/O and depends on no
//! runtime or transport: outer layers implement its ports (traits).
//!
//! - [`changes`]: changes, files and history of one worktree.
//! - [`terminal`]: PTY-backed terminal sessions, their output and lifecycle.
//! - [`daemon`]: daemon identity, security and discovery rules.
//! - [`workspace`]: namespaces, git repositories and their worktrees.

pub mod changes;
pub mod daemon;
pub mod terminal;
pub mod time;
pub mod workspace;
