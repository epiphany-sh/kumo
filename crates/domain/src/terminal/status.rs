use super::ExitStatus;

/// Lifecycle of a terminal session.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TerminalStatus {
    Running,
    /// The process ended. The session stays registered until closed.
    Exited(ExitStatus),
}

impl TerminalStatus {
    pub fn exit_status(self) -> Option<ExitStatus> {
        match self {
            Self::Running => None,
            Self::Exited(status) => Some(status),
        }
    }
}
