use std::sync::Arc;

use kumo_domain::daemon::{ApiVersion, Executable};
use kumo_domain::time::Timestamp;

/// Answer to a client handshake.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HelloReply {
    pub api_version: ApiVersion,
    pub server_version: String,
    pub server_time: Timestamp,
    /// The daemon's program was replaced on disk (an update): restarting
    /// runs the new one.
    pub outdated: bool,
}

/// Version handshake. The daemon always answers with its own version; the
/// client decides whether it can operate.
#[derive(Clone)]
pub struct HelloService {
    server_version: String,
    executable: Arc<dyn Executable>,
}

impl std::fmt::Debug for HelloService {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("HelloService")
            .field("server_version", &self.server_version)
            .finish_non_exhaustive()
    }
}

impl HelloService {
    pub fn new(server_version: impl Into<String>, executable: Arc<dyn Executable>) -> Self {
        Self {
            server_version: server_version.into(),
            executable,
        }
    }

    pub fn hello(&self, client_api_version: ApiVersion, client_name: &str) -> HelloReply {
        if !client_api_version.is_compatible_with(ApiVersion::CURRENT) {
            tracing::warn!(
                client = client_name,
                client_api = %client_api_version,
                server_api = %ApiVersion::CURRENT,
                "client API version mismatch"
            );
        }
        HelloReply {
            api_version: ApiVersion::CURRENT,
            server_version: self.server_version.clone(),
            server_time: Timestamp::now(),
            outdated: self.executable.replaced(),
        }
    }
}
