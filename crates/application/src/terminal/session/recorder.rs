//! Reads a shell's command marks out of its output, on the pump, and
//! remembers the commands it ran.

use std::path::PathBuf;
use std::sync::{Arc, Mutex, PoisonError};
use std::time::Duration;

use kumo_domain::terminal::{CommandMarks, CommandRun, OutputChunk, ShellActivity, TerminalId};

use crate::terminal::CommandHistory;
use crate::terminal::registry::{Changes, changed};

/// How long the output waits for a finished command to be stored: a client
/// that sees it done and asks for the history then finds it there. A slow
/// disk doesn't hold the terminal longer.
const STORE_WAIT: Duration = Duration::from_millis(250);

/// The folder the shell said it's in last, shared with its session.
pub(in crate::terminal) type ShellCwd = Arc<Mutex<Option<PathBuf>>>;

/// What the shell is doing, shared with its session.
pub(in crate::terminal) type SharedActivity = Arc<Mutex<ShellActivity>>;

pub(in crate::terminal) struct Recorder {
    marks: CommandMarks,
    /// Where finished commands go; None keeps nothing (only the folder).
    history: Option<CommandHistory>,
    cwd: ShellCwd,
    /// What [`Self::cwd`] holds, to touch it only when it changes.
    seen_cwd: Option<PathBuf>,
    activity: SharedActivity,
    /// [`CommandMarks::changes`] when [`Self::activity`] was last set.
    seen_changes: u64,
    /// Told when the activity changes; None in tests.
    changes: Option<Changes>,
    done: Vec<CommandRun>,
}

impl Recorder {
    pub(in crate::terminal) fn new(marks: CommandMarks, history: Option<CommandHistory>) -> Self {
        Self {
            marks,
            history,
            cwd: Arc::default(),
            seen_cwd: None,
            activity: Arc::default(),
            seen_changes: 0,
            changes: None,
            done: Vec::new(),
        }
    }

    /// Tells `changes` when what the shell does changes.
    pub(in crate::terminal) fn telling(mut self, changes: Changes) -> Self {
        self.changes = Some(changes);
        self
    }

    /// What its shell is doing.
    pub(super) fn activity(&self) -> SharedActivity {
        Arc::clone(&self.activity)
    }

    /// The shell exited: nothing runs in it any more.
    pub(super) fn ended(&self) {
        let mut activity = self.activity.lock().unwrap_or_else(PoisonError::into_inner);
        if activity.running.take().is_some() {
            drop(activity);
            self.tell();
        }
    }

    fn tell(&self) {
        if let Some(changes) = &self.changes {
            changed(changes);
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
        if self.marks.changes() != self.seen_changes {
            self.seen_changes = self.marks.changes();
            *self.activity.lock().unwrap_or_else(PoisonError::into_inner) = self.marks.activity();
            self.tell();
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

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use bytes::Bytes;
    use kumo_domain::terminal::{CommandMarks, OutputChunk};
    use kumo_domain::time::Timestamp;
    use tokio::sync::watch;

    use super::Recorder;

    fn chunk(text: &'static str) -> OutputChunk {
        OutputChunk::new(Bytes::from_static(text.as_bytes()), Timestamp::now())
    }

    #[test]
    fn a_command_starting_and_ending_is_shared_and_told_once_each() {
        let changes = Arc::new(watch::channel(0_u64).0);
        let mut seen = changes.subscribe();
        let mut recorder =
            Recorder::new(CommandMarks::new("n"), None).telling(Arc::clone(&changes));
        let activity = recorder.activity();

        recorder.feed(&chunk(
            "\x1b]133;A\x07$ \x1b]633;E;make;n\x07\x1b]133;C\x07",
        ));
        assert!(seen.has_changed().unwrap());
        seen.mark_unchanged();
        assert_eq!(
            activity
                .lock()
                .unwrap()
                .running
                .as_ref()
                .map(|r| r.command.as_str()),
            Some("make")
        );

        recorder.feed(&chunk("building…\r\n"));
        assert!(!seen.has_changed().unwrap(), "output alone changes nothing");

        recorder.feed(&chunk("\x1b]133;D;2\x07"));
        assert!(seen.has_changed().unwrap());
        seen.mark_unchanged();
        let now = activity.lock().unwrap().clone();
        assert_eq!(now.running, None);
        assert_eq!(now.last.and_then(|l| l.exit), Some(2));
    }

    #[test]
    fn a_shell_that_exits_mid_command_runs_nothing() {
        let changes = Arc::new(watch::channel(0_u64).0);
        let mut recorder =
            Recorder::new(CommandMarks::new("n"), None).telling(Arc::clone(&changes));
        recorder.feed(&chunk("\x1b]133;C\x07"));
        let seen = changes.subscribe();
        recorder.ended();
        assert!(seen.has_changed().unwrap());
        assert_eq!(recorder.activity().lock().unwrap().running, None);
    }
}
