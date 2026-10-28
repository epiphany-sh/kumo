use super::CiProblem;

/// Messages are written for the user: they reach the UI as is.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum PipelinesError {
    #[error("not a worktree of the workspace: {0}")]
    UnknownWorktree(String),
    #[error("no repository host {0} in the workspace")]
    UnknownHost(String),
    #[error("{0}")]
    Invalid(String),
    #[error("keychain: {0}")]
    Secret(String),
    /// The provider refused or failed an action (re-run, test).
    #[error("{0}")]
    Ci(CiProblem),
}
