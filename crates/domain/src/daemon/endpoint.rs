use std::net::SocketAddr;

use super::{ApiVersion, AuthToken};

/// Everything a client needs to find and talk to a running daemon.
/// Persisted as the discovery file.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DaemonEndpoint {
    pub api_version: ApiVersion,
    pub pid: u32,
    pub addr: SocketAddr,
    pub token: AuthToken,
}
