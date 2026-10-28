use super::TerminalId;

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum TerminalError {
    #[error("terminal not found: {0}")]
    NotFound(TerminalId),
    #[error("terminal id must not be empty")]
    InvalidId,
    #[error("invalid terminal size {cols}x{rows}")]
    InvalidSize { cols: u32, rows: u32 },
    #[error("invalid launch spec: {0}")]
    InvalidLaunchSpec(String),
    #[error("failed to spawn process: {0}")]
    Spawn(String),
    #[error("pty I/O error: {0}")]
    Io(String),
    #[error("terminal session is closed")]
    SessionClosed,
}
