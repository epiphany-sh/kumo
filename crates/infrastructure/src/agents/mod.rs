//! Finding coding-agent CLIs and reading their usage.

mod homes;
mod locator;
mod usage;

pub use homes::ProfileCliHomes;
pub use locator::ShellPathLocator;
pub use usage::{ClaudeStatusLine, CodexRollouts, claude_config_dir, codex_home};
