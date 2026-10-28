use std::net::SocketAddr;

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
}
