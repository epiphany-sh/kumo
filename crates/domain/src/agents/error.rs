use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum AgentError {
    #[error("unknown agent: {0}")]
    UnknownProvider(String),
    #[error("no agent connected: connect one in Settings › AI agents")]
    NoProvider,
    #[error("{0} is not installed (not found on your PATH)")]
    NotInstalled(String),
    #[error("invalid arguments: {0}")]
    InvalidArgs(String),
    #[error("{0}")]
    Invalid(String),
    #[error("unknown agent session: {0}")]
    UnknownSession(String),
    #[error("not a worktree in the workspace: {0}")]
    UnknownWorktree(PathBuf),
    #[error("can't start the agent: {0}")]
    Launch(String),
    #[error("{0}")]
    Test(String),
    #[error("agent settings storage failed: {0}")]
    Store(String),
}
