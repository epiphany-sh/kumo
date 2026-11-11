use std::path::PathBuf;

use kumo_application::terminal::SessionConfig;
use kumo_domain::daemon::ListenAddress;

/// How to run the daemon.
#[derive(Debug, Clone, Default)]
pub struct DaemonConfig {
    pub listen: ListenAddress,
    /// Directory for `daemon.json` and `kumo.db`. `None` uses the per-user
    /// default (`<data_local_dir>/kumo`, `kumo-<channel>` for a channel
    /// build).
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
    /// The `kumod` git runs as its credential helper (`kumod
    /// git-credential`). `None` is this program.
    pub credential_helper: Option<PathBuf>,
    /// How long a minute of your agents' time limits lasts. `None` is a
    /// minute (tests pass less).
    pub agent_minute: Option<std::time::Duration>,
    /// Whether the agents' accounts are asked for their plan usage.
    pub plan_accounts: PlanAccounts,
}

/// Asking the agents' accounts uses the CLIs' real sign-ins (the OS
/// keychain isn't per home) and the network.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum PlanAccounts {
    /// With each CLI's sign-in.
    #[default]
    Ask,
    /// Only what sessions report (tests).
    Never,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum SecretsBackend {
    /// The OS keychain.
    #[default]
    Keychain,
    /// In memory, gone when the daemon stops (tests).
    Memory,
}
