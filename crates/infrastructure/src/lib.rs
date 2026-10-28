//! Kumo infrastructure layer: OS-facing implementations of domain ports.
//!
//! - [`pty`]: pseudo-terminals via `portable-pty` (ConPTY on Windows).
//! - [`discovery`]: the `daemon.json` discovery file.
//! - [`security`]: secure randomness for auth tokens.
//! - [`git`]: git repositories through the `git` command line.
//! - [`fs`]: files inside worktrees.
//! - [`watch`]: file system change notifications.
//! - [`storage`]: SQLite persistence.

pub mod discovery;
pub mod fs;
pub mod git;
pub mod pty;
pub mod security;
pub mod storage;
pub mod watch;
