//! Reading coding agents' plan limits and context windows from what their
//! CLIs report.

mod claude;
mod codex;

pub use claude::ClaudeStatusLine;
pub use codex::{CodexRollouts, codex_home};
