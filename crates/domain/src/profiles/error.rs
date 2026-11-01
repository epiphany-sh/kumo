/// Why a profile operation failed.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ProfileError {
    #[error("unknown workspace: {0}")]
    NotFound(String),
    #[error("invalid workspace id: {0:?}")]
    InvalidId(String),
    #[error("a workspace needs a name")]
    EmptyName,
    #[error("invalid color {0:?}: use #RRGGBB")]
    InvalidColor(String),
    #[error("the first workspace holds Kumo's original data and can't be deleted")]
    DefaultProfile,
    #[error("the last workspace can't be deleted")]
    LastProfile,
    #[error("workspace {0} is open in a window")]
    InUse(String),
    #[error("workspace storage: {0}")]
    Storage(String),
    #[error("couldn't open workspace {id}: {reason}")]
    Open { id: String, reason: String },
}
