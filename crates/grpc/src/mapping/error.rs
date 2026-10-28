use kumo_domain::changes::ChangesError;
use kumo_domain::terminal::TerminalError;
use kumo_domain::workspace::WorkspaceError;
use tonic::Status;

/// Maps a domain error to the gRPC status clients see.
pub fn status_from(error: TerminalError) -> Status {
    let message = error.to_string();
    match error {
        TerminalError::NotFound(_) => Status::not_found(message),
        TerminalError::InvalidId
        | TerminalError::InvalidSize { .. }
        | TerminalError::InvalidLaunchSpec(_) => Status::invalid_argument(message),
        TerminalError::Spawn(_) | TerminalError::SessionClosed => {
            Status::failed_precondition(message)
        }
        TerminalError::Io(_) => Status::internal(message),
    }
}

/// Maps a workspace error. Git's own message (e.g. "branch already exists")
/// reaches the client as is.
pub fn workspace_status_from(error: WorkspaceError) -> Status {
    let message = error.to_string();
    match error {
        WorkspaceError::NotARepository(_)
        | WorkspaceError::InvalidBranch { .. }
        | WorkspaceError::InvalidPath(_) => Status::invalid_argument(message),
        WorkspaceError::RepoNotFound(_)
        | WorkspaceError::WorktreeNotFound(_)
        | WorkspaceError::NamespaceNotFound(_) => Status::not_found(message),
        WorkspaceError::CannotRemoveMainCheckout | WorkspaceError::Git(_) => {
            Status::failed_precondition(message)
        }
        WorkspaceError::Store(_) => Status::internal(message),
    }
}

/// Maps an error on a worktree's changes; git's message reaches the client.
pub fn changes_status_from(error: ChangesError) -> Status {
    let message = error.to_string();
    match error {
        ChangesError::UnknownWorktree(_) => Status::not_found(message),
        ChangesError::InvalidPath(_) | ChangesError::EmptyMessage => {
            Status::invalid_argument(message)
        }
        ChangesError::Git(_) => Status::failed_precondition(message),
        ChangesError::Io(_) => Status::internal(message),
    }
}
