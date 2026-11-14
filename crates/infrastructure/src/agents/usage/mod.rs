//! Reading coding agents' plan limits and context windows from what their
//! CLIs report, and asking their accounts with the CLIs' own sign-ins.

mod account;
mod claude;
mod claude_account;
mod claude_transcript;
mod codex;
mod codex_account;
mod copilot;
mod copilot_account;
mod lines;

pub use claude::{ClaudeStatusLine, claude_config_dir};
pub use claude_account::ClaudeAccount;
pub use codex::{CodexRollouts, codex_home};
pub use codex_account::CodexAccount;
pub use copilot::{CopilotEvents, copilot_home};
pub use copilot_account::CopilotAccount;
