use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ChangesError {
    #[error("not a worktree in the workspace: {0}")]
    UnknownWorktree(PathBuf),
    #[error("invalid path {0:?}: must be relative and stay inside the worktree")]
    InvalidPath(String),
    #[error("commit message is empty")]
    EmptyMessage,
    #[error("git failed: {0}")]
    Git(String),
    #[error("file error: {0}")]
    Io(String),
}
