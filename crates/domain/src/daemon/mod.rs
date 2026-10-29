//! The daemon itself: API versioning, the loopback-only listen rule, the
//! bearer token and the discovery record clients use to find it.

mod api_version;
mod auth_token;
mod endpoint;
mod error;
mod listen_address;
mod ports;

pub use api_version::ApiVersion;
pub use auth_token::AuthToken;
pub use endpoint::DaemonEndpoint;
pub use error::DaemonError;
pub use listen_address::ListenAddress;
pub use ports::{DiscoveryStore, Executable};
