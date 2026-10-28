use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum WorkspaceError {
    #[error("not a git repository: {0}")]
    NotARepository(PathBuf),
    #[error("repository not in the workspace: {0}")]
    RepoNotFound(PathBuf),
    #[error("worktree not found: {0}")]
    WorktreeNotFound(PathBuf),
    #[error("namespace not found: {0}")]
    NamespaceNotFound(String),
    #[error("the main checkout can't be removed")]
    CannotRemoveMainCheckout,
    #[error("invalid branch name {name:?}: {reason}")]
    InvalidBranch { name: String, reason: &'static str },
    #[error("invalid worktree path {0:?}: use an absolute path or one starting with ~")]
    InvalidPath(String),
    #[error("git failed: {0}")]
    Git(String),
    #[error("workspace storage failed: {0}")]
    Store(String),
}
