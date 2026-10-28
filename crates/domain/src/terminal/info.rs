use std::path::PathBuf;

use super::{TerminalId, TerminalStatus};
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
