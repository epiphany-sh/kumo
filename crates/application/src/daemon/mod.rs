//! Daemon-level use cases.

mod control;
mod hello;

pub use control::{DaemonControl, ShutdownRefused};
pub use hello::{HelloReply, HelloService};
