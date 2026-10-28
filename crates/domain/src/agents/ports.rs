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
