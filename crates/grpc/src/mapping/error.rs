use kumo_domain::terminal::TerminalError;
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
