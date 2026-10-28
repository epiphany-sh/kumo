use kumo_domain::daemon::ApiVersion;
use kumo_domain::time::Timestamp;

/// Answer to a client handshake.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HelloReply {
    pub api_version: ApiVersion,
    pub server_version: String,
    pub server_time: Timestamp,
}

/// Version handshake. The daemon always answers with its own version; the
/// client decides whether it can operate.
#[derive(Debug, Clone)]
pub struct HelloService {
    server_version: String,
}

impl HelloService {
    pub fn new(server_version: impl Into<String>) -> Self {
        Self {
            server_version: server_version.into(),
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
        }
    }
}
