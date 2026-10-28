use kumo_domain::agents::AgentError;
use kumo_domain::changes::ChangesError;
use kumo_domain::pipelines::PipelinesError;
use kumo_domain::tasks::TaskError;
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

/// Maps an agent error; messages are written for the user.
pub fn agents_status_from(error: AgentError) -> Status {
    let message = error.to_string();
    match error {
        AgentError::UnknownProvider(_)
        | AgentError::UnknownSession(_)
        | AgentError::UnknownWorktree(_) => Status::not_found(message),
        AgentError::InvalidArgs(_) | AgentError::Invalid(_) => Status::invalid_argument(message),
        AgentError::NoProvider
        | AgentError::NotInstalled(_)
        | AgentError::Test(_)
        | AgentError::Launch(_) => Status::failed_precondition(message),
        AgentError::Store(_) => Status::internal(message),
    }
}

/// Maps a task error; messages are written for the user. Credential
/// problems are not `UNAUTHENTICATED`: that one means the daemon's token.
pub fn tasks_status_from(error: TaskError) -> Status {
    let message = error.to_string();
    match error {
        TaskError::UnknownSource(_) | TaskError::UnknownTask(_) => Status::not_found(message),
        TaskError::Invalid(_) => Status::invalid_argument(message),
        TaskError::Unsupported { .. } | TaskError::Auth(_) | TaskError::Source(_) => {
            Status::failed_precondition(message)
        }
        TaskError::Conflict(_) => Status::aborted(message),
        TaskError::Unavailable(_) => Status::unavailable(message),
        TaskError::Store(_) | TaskError::Secret(_) => Status::internal(message),
    }
}

pub fn pipelines_status_from(error: PipelinesError) -> Status {
    let message = error.to_string();
    match error {
        PipelinesError::UnknownWorktree(_) | PipelinesError::UnknownHost(_) => {
            Status::not_found(message)
        }
        PipelinesError::Invalid(_) => Status::invalid_argument(message),
        PipelinesError::Secret(_) => Status::internal(message),
        PipelinesError::Ci(problem) if problem.keeps_last_run() => Status::unavailable(message),
        PipelinesError::Ci(_) => Status::failed_precondition(message),
    }
}
