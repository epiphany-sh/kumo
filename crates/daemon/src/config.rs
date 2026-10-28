use std::path::PathBuf;

use kumo_application::terminal::SessionConfig;
use kumo_domain::daemon::ListenAddress;

/// How to run the daemon.
#[derive(Debug, Clone, Default)]
pub struct DaemonConfig {
    pub listen: ListenAddress,
    /// Directory for `daemon.json`. `None` uses the per-user default.
    pub data_dir: Option<PathBuf>,
    pub session: SessionConfig,
}
