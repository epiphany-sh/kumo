use super::{SourceKind, TaskStatus};

/// Messages are written for the user: they reach the UI as is.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum TaskError {
    #[error("unknown task source: {0}")]
    UnknownSource(String),
    #[error("unknown task: {0}")]
    UnknownTask(String),
    #[error("{0}")]
    Invalid(String),
    #[error("{kind} can't mark tasks as {status}")]
    Unsupported {
        kind: SourceKind,
        status: TaskStatus,
    },
    /// Missing, expired or rejected credentials.
    #[error("{0}")]
    Auth(String),
    /// Network down, service unavailable, file missing…: retried later.
    #[error("{0}")]
    Unavailable(String),
    /// The source answered something unexpected.
    #[error("{0}")]
    Source(String),
    #[error("the task changed in {0} since it was read: sync and try again")]
    Conflict(SourceKind),
    #[error("task storage failed: {0}")]
    Store(String),
    #[error("keychain: {0}")]
    Secret(String),
}
