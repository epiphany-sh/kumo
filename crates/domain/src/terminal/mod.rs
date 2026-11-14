//! Terminal sessions: a program running on a pseudo-terminal whose output is
//! coalesced into batches, kept in a bounded replay buffer and streamed to
//! subscribers.

mod batch_builder;
mod error;
mod event;
mod exit_status;
mod history;
mod id;
mod info;
mod launch_spec;
mod marks;
mod output;
mod ports;
mod replay_buffer;
mod shell_integration;
mod size;
mod status;
mod text;

pub use batch_builder::BatchBuilder;
pub use error::TerminalError;
pub use event::TerminalEvent;
pub use exit_status::ExitStatus;
pub use history::{CommandHistoryStore, HISTORY_LIMIT, HistoryEntry, HistoryError, RepoLocator};
pub use id::TerminalId;
pub use info::{TerminalActivity, TerminalInfo};
pub use launch_spec::LaunchSpec;
pub use marks::{CommandMarks, CommandRun, FinishedCommand, RunningCommand, ShellActivity};
pub use output::{OutputBatch, OutputChunk};
pub use ports::{PtyChild, PtyKiller, PtyMaster, PtyProcess, PtySystem};
pub use replay_buffer::ReplayBuffer;
pub use shell_integration::{NoShellIntegration, ShellIntegration};
pub use size::TerminalSize;
pub use status::TerminalStatus;
pub use text::{LineSplitter, bracketed_paste, is_answer, plain_text, typed_text};
