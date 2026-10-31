//! Finding coding-agent CLIs and reading their usage.

mod locator;
mod usage;

pub use locator::ShellPathLocator;
pub use usage::{ClaudeStatusLine, CodexRollouts, codex_home};
