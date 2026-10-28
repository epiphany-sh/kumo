//! Ports implemented by the infrastructure layer.

use super::{DaemonEndpoint, DaemonError};

/// Where the running daemon advertises its endpoint to clients.
pub trait DiscoveryStore: Send + Sync {
    fn load(&self) -> Result<Option<DaemonEndpoint>, DaemonError>;
    /// Must be atomic: readers never see a partially written record.
    fn save(&self, endpoint: &DaemonEndpoint) -> Result<(), DaemonError>;
    /// Removing a missing record is not an error.
    fn remove(&self) -> Result<(), DaemonError>;
}
