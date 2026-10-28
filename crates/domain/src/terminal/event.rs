use super::{ExitStatus, OutputBatch};

/// What a subscriber of a terminal session receives, in order.
/// `Exited` is always the last event.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TerminalEvent {
    Output(OutputBatch),
    Exited(ExitStatus),
}
