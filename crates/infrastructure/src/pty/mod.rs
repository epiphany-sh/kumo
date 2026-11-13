//! Pseudo-terminal adapter.

mod portable;
mod shell_integration;

pub use portable::PortablePtySystem;
pub use shell_integration::{ShellScripts, shell_integration};
