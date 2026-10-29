use std::net::SocketAddr;
use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum DaemonError {
    #[error("refusing to listen on non-loopback address {0}")]
    NonLoopbackAddress(SocketAddr),
    #[error("failed to listen on {addr}: {reason}")]
    Bind { addr: SocketAddr, reason: String },
    #[error("malformed auth token")]
    InvalidToken,
    #[error("discovery file error: {0}")]
    Discovery(String),
    #[error("a daemon is already running at {addr} (pid {pid})")]
    AlreadyRunning { addr: SocketAddr, pid: u32 },
    /// Another daemon holds the lock but hasn't advertised itself yet.
    #[error("another daemon is starting (it holds {0})")]
    AlreadyStarting(PathBuf),
    #[error("can't take the instance lock {path}: {reason}")]
    Lock { path: PathBuf, reason: String },
}
