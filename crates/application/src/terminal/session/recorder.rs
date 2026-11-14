//! Reads a shell's command marks out of its output, on the pump, and
//! remembers the commands it ran.

use std::path::PathBuf;
use std::sync::{Arc, Mutex, PoisonError};
use std::time::Duration;

use kumo_domain::terminal::{CommandMarks, CommandRun, OutputChunk, TerminalId};

use crate::terminal::CommandHistory;

/// How long the output waits for a finished command to be stored: a client
/// that sees it done and asks for the history then finds it there. A slow
/// disk doesn't hold the terminal longer.
const STORE_WAIT: Duration = Duration::from_millis(250);

/// The folder the shell said it's in last, shared with its session.
pub(in crate::terminal) type ShellCwd = Arc<Mutex<Option<PathBuf>>>;

pub(in crate::terminal) struct Recorder {
    marks: CommandMarks,
    /// Where finished commands go; None keeps nothing (only the folder).
    history: Option<CommandHistory>,
    cwd: ShellCwd,
    /// What [`Self::cwd`] holds, to touch it only when it changes.
    seen_cwd: Option<PathBuf>,
    done: Vec<CommandRun>,
}

impl Recorder {
    pub(in crate::terminal) fn new(marks: CommandMarks, history: Option<CommandHistory>) -> Self {
        Self {
            marks,
            history,
            cwd: Arc::default(),
            seen_cwd: None,
            done: Vec::new(),
        }
    }

    /// The folder its shell said it's in last.
    pub(super) fn cwd(&self) -> ShellCwd {
        Arc::clone(&self.cwd)
    }

    pub(super) fn feed(&mut self, chunk: &OutputChunk) {
        self.marks.feed(&chunk.data, chunk.read_at, &mut self.done);
        if self.marks.cwd() != self.seen_cwd.as_ref() {
            self.seen_cwd = self.marks.cwd().cloned();
            self.cwd
                .lock()
                .unwrap_or_else(PoisonError::into_inner)
                .clone_from(&self.seen_cwd);
        }
    }

    /// Stores the commands finished in what was fed since the last call.
    pub(super) async fn flush(&mut self, id: &TerminalId) {
        if self.done.is_empty() {
            return;
        }
        let runs = std::mem::take(&mut self.done);
        let Some(history) = self.history.clone() else {
            return;
        };
        let terminal = id.clone();
        let store = tokio::task::spawn_blocking(move || {
            for run in &runs {
                if let Err(error) = history.record(run) {
                    tracing::warn!(%terminal, %error, "command not remembered");
                }
            }
        });
        if tokio::time::timeout(STORE_WAIT, store).await.is_err() {
            tracing::debug!(terminal = %id, "storing a command took long: output went on");
        }
    }
}
