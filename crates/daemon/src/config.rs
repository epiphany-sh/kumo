use std::path::PathBuf;

use kumo_application::terminal::SessionConfig;
use kumo_domain::daemon::ListenAddress;

/// How to run the daemon.
#[derive(Debug, Clone, Default)]
pub struct DaemonConfig {
    pub listen: ListenAddress,
    /// Directory for `daemon.json` and `kumo.db`. `None` uses the per-user
    /// default (`<data_local_dir>/kumo`).
    pub data_dir: Option<PathBuf>,
    /// The user's home: default worktree location (`~/wt`) and the usual
    /// folders scanned for repositories. `None` uses the real one.
    pub home: Option<PathBuf>,
    /// PATH used to find agent CLIs. `None` reads the login shell's (tests
    /// pass their own).
    pub agent_path: Option<String>,
    /// Where API tokens of task sources are kept.
    pub secrets: SecretsBackend,
    pub session: SessionConfig,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum SecretsBackend {
    /// The OS keychain.
    #[default]
    Keychain,
    /// In memory, gone when the daemon stops (tests).
    Memory,
}
