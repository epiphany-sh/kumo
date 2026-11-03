//! Ports implemented by the infrastructure layer. They block.

use std::path::{Path, PathBuf};

use super::AgentError;

/// A provider's saved settings: overrides for a known CLI, or a whole
/// custom agent.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StoredProvider {
    pub id: String,
    pub name: String,
    pub program: String,
    pub args: String,
    pub custom: bool,
    pub enabled: bool,
    pub is_default: bool,
    pub read_usage: bool,
}

pub trait AgentStore: Send + Sync + 'static {
    /// In the order they were added.
    fn load(&self) -> Result<Vec<StoredProvider>, AgentError>;
    fn save(&self, provider: &StoredProvider) -> Result<(), AgentError>;
    fn delete(&self, id: &str) -> Result<(), AgentError>;
}

/// Finds programs the way the user's shell would.
pub trait ProgramLocator: Send + Sync + 'static {
    /// Absolute path of `program` (a name on PATH, or a path).
    fn locate(&self, program: &str) -> Option<PathBuf>;
    /// The user's PATH, for the processes Kumo starts (GUI apps don't get
    /// the one from the shell profile).
    fn search_path(&self) -> String;
    /// First line of `<program> --version`.
    fn version(&self, program: &Path) -> Result<String, AgentError>;
    /// Where sign-in flows start.
    fn home(&self) -> PathBuf;
}

/// The CLIs' own folders in a profile (see [`super::CLI_HOMES`]).
pub trait CliHomes: Send + Sync + 'static {
    /// The variables that point `provider` at the profile's folder, which
    /// exists once this returns. Empty when it shares the user's (the
    /// default profile, and CLIs whose sign-in can't be separated).
    fn env(&self, provider: &str) -> Result<Vec<(String, String)>, AgentError>;
    /// Whether `provider` signs in for this profile only.
    fn own_sign_in(&self, provider: &str) -> bool;
}

/// The user's own folders: no variable for any CLI.
#[derive(Debug, Clone, Copy, Default)]
pub struct SharedCliHomes;

impl CliHomes for SharedCliHomes {
    fn env(&self, _provider: &str) -> Result<Vec<(String, String)>, AgentError> {
        Ok(Vec::new())
    }
    fn own_sign_in(&self, _provider: &str) -> bool {
        false
    }
}
