use std::path::PathBuf;

use super::{ShellActivity, TerminalId, TerminalStatus};
use crate::time::Timestamp;

/// Read-only summary of a terminal session.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TerminalInfo {
    pub id: TerminalId,
    pub program: String,
    /// Where it started; `None` for the daemon's own directory.
    pub cwd: Option<PathBuf>,
    pub status: TerminalStatus,
    pub opened_at: Timestamp,
}

/// What a shell is doing, and where.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TerminalActivity {
    pub id: TerminalId,
    /// The folder its shell said it's in last, or the one it opened in.
    pub cwd: Option<PathBuf>,
    /// Nothing runs in a shell that exited.
    pub activity: ShellActivity,
}
