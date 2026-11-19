//! A live terminal session: owns the PTY handles, its I/O threads and the
//! pump task, and fans output out to subscribers.

mod hub;
mod io_threads;
mod pump;
mod recorder;

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::time::Instant;

use bytes::Bytes;
use kumo_domain::terminal::{
    LaunchSpec, PtyKiller, PtyMaster, PtyProcess, ShellActivity, TerminalError, TerminalId,
    TerminalInfo, TerminalSize, TerminalStatus, is_answer,
};
use kumo_domain::time::Timestamp;
use tokio::sync::{mpsc, oneshot};

pub use hub::Subscription;

use super::SessionConfig;
use hub::OutputHub;
use pump::Pump;
pub(in crate::terminal) use recorder::Recorder;
use recorder::{SharedActivity, ShellCwd};

type SharedMaster = Arc<Mutex<Option<Box<dyn PtyMaster>>>>;

fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(PoisonError::into_inner)
}

pub struct TerminalSession {
    id: TerminalId,
    program: String,
    cwd: Option<PathBuf>,
    opened_at: Timestamp,
    input: mpsc::Sender<Bytes>,
    /// `None` once the session finished and the PTY was released.
    master: SharedMaster,
    killer: Mutex<Box<dyn PtyKiller>>,
    hub: Arc<OutputHub>,
    /// When its size last changed, and when someone last answered in it.
    resized_at: Mutex<Option<Instant>>,
    answered_at: Mutex<Option<Instant>>,
    /// A shell's folder, as it says at each prompt.
    shell_cwd: Option<ShellCwd>,
    /// A shell's command running and last one done.
    shell_activity: Option<SharedActivity>,
}

impl std::fmt::Debug for TerminalSession {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TerminalSession")
            .field("id", &self.id)
            .field("program", &self.program)
            .field("status", &self.hub.status())
            .finish_non_exhaustive()
    }
}

impl TerminalSession {
    /// Wires a freshly spawned process: starts its I/O threads and the pump.
    /// Must be called from within a Tokio runtime.
    pub(super) fn start(
        id: TerminalId,
        spec: &LaunchSpec,
        process: PtyProcess,
        config: &SessionConfig,
        recorder: Option<Recorder>,
    ) -> Arc<Self> {
        let PtyProcess {
            reader,
            writer,
            master,
            child,
            killer,
        } = process;

        let (chunk_tx, chunk_rx) = mpsc::channel(config.chunk_queue_capacity);
        let (input_tx, input_rx) = mpsc::channel(config.input_queue_capacity);
        let (exit_tx, exit_rx) = oneshot::channel();
        io_threads::spawn_reader(&id, reader, chunk_tx, config.read_buffer_bytes);
        io_threads::spawn_writer(&id, writer, input_rx);
        io_threads::spawn_waiter(&id, child, exit_tx);

        let hub = Arc::new(OutputHub::new(
            config.replay_capacity_bytes,
            config.subscriber_queue_capacity,
        ));
        let master: SharedMaster = Arc::new(Mutex::new(Some(master)));
        let shell_cwd = recorder.as_ref().map(Recorder::cwd);
        let shell_activity = recorder.as_ref().map(Recorder::activity);

        let pump = Pump {
            id: id.clone(),
            chunks: chunk_rx,
            exit: exit_rx,
            hub: Arc::clone(&hub),
            max_batch_bytes: config.max_batch_bytes,
            exit_drain_idle: config.exit_drain_idle,
            recorder,
        };
        let released = Arc::clone(&master);
        tokio::spawn(async move {
            pump.run().await;
            // Release the PTY: unblocks readers on platforms (ConPTY) that
            // only signal EOF once the pseudo-console is closed.
            released
                .lock()
                .unwrap_or_else(PoisonError::into_inner)
                .take();
        });

        Arc::new(Self {
            id,
            program: spec.program().to_owned(),
            cwd: spec.cwd().map(Path::to_path_buf),
            opened_at: Timestamp::now(),
            input: input_tx,
            master,
            killer: Mutex::new(killer),
            hub,
            resized_at: Mutex::new(None),
            answered_at: Mutex::new(None),
            shell_cwd,
            shell_activity,
        })
    }

    pub fn id(&self) -> &TerminalId {
        &self.id
    }

    pub fn status(&self) -> TerminalStatus {
        self.hub.status()
    }

    pub fn info(&self) -> TerminalInfo {
        TerminalInfo {
            id: self.id.clone(),
            program: self.program.clone(),
            cwd: self.cwd.clone(),
            status: self.status(),
            opened_at: self.opened_at,
        }
    }

    /// The folder its shell is in: the one it said last, or the one it
    /// opened in.
    pub fn current_dir(&self) -> Option<PathBuf> {
        self.shell_cwd
            .as_ref()
            .and_then(|cwd| lock(cwd).clone())
            .or_else(|| self.cwd.clone())
    }

    /// What its shell is doing; None for a program that isn't a shell
    /// with Kumo's integration.
    pub fn shell_activity(&self) -> Option<ShellActivity> {
        self.shell_activity.as_ref().map(|a| lock(a).clone())
    }

    /// Subscribes to output. See [`Subscription`] for ordering guarantees.
    pub fn subscribe(&self, with_replay: bool) -> Subscription {
        self.hub.subscribe(with_replay)
    }

    /// Queues input for the PTY. Waits if the input queue is full.
    pub async fn write(&self, data: Bytes) -> Result<(), TerminalError> {
        if is_answer(&data) {
            *lock(&self.answered_at) = Some(Instant::now());
        }
        self.input
            .send(data)
            .await
            .map_err(|_| TerminalError::SessionClosed)
    }

    /// Resizing a finished session is a no-op.
    pub fn resize(&self, size: TerminalSize) -> Result<(), TerminalError> {
        *lock(&self.resized_at) = Some(Instant::now());
        let master = self.master.lock().unwrap_or_else(PoisonError::into_inner);
        match master.as_ref() {
            Some(master) => master.resize(size),
            None => Ok(()),
        }
    }

    pub fn resized_at(&self) -> Option<Instant> {
        *lock(&self.resized_at)
    }

    /// When someone last typed an answer in it ([`is_answer`]).
    pub fn answered_at(&self) -> Option<Instant> {
        *lock(&self.answered_at)
    }

    /// The process in its foreground (what was typed in its shell, or the
    /// shell); None once it exited or where the OS can't tell. May block
    /// (see [`kumo_domain::terminal::ForegroundProbe`]): call it off the
    /// async runtime. The PTY isn't held meanwhile.
    pub fn foreground(&self) -> Option<u32> {
        let probe = lock(&self.master).as_ref().map(|m| m.foreground())?;
        probe()
    }

    /// Kills the process and what it started. For agents, whose tools are
    /// theirs: a shell's `nohup server &` is the user's, and [`Self::kill`]
    /// leaves it. Killing an exited process is a no-op.
    pub fn kill_tree(&self) -> Result<(), TerminalError> {
        if matches!(self.status(), TerminalStatus::Exited(_)) {
            return Ok(());
        }
        lock(&self.killer).kill_tree()
    }

    /// Kills the process. Killing an exited process is a no-op.
    pub fn kill(&self) -> Result<(), TerminalError> {
        if matches!(self.status(), TerminalStatus::Exited(_)) {
            return Ok(());
        }
        self.killer
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .kill()
    }
}

#[cfg(test)]
mod tests {
    use std::io::{Read, Write};
    use std::sync::mpsc as std_mpsc;
    use std::time::Duration;

    use kumo_domain::terminal::{ExitStatus, ForegroundProbe, PtyChild};

    use super::*;

    /// Blocks until dropped: a PTY that stays open.
    struct Open(std_mpsc::Receiver<()>);

    impl Read for Open {
        fn read(&mut self, _: &mut [u8]) -> std::io::Result<usize> {
            let _ = self.0.recv();
            Ok(0)
        }
    }

    impl PtyChild for Open {
        fn wait(&mut self) -> Result<ExitStatus, TerminalError> {
            let _ = self.0.recv();
            Ok(ExitStatus::UNKNOWN)
        }
    }

    struct Sink;

    impl Write for Sink {
        fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
            Ok(buf.len())
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }

    struct NoKill;

    impl PtyKiller for NoKill {
        fn kill(&mut self) -> Result<(), TerminalError> {
            Ok(())
        }
        fn kill_tree(&mut self) -> Result<(), TerminalError> {
            Ok(())
        }
    }

    /// Its foreground waits for a resize to go through first.
    struct SlowMaster(Arc<Mutex<Option<std_mpsc::Receiver<()>>>>);

    impl PtyMaster for SlowMaster {
        fn resize(&self, _: TerminalSize) -> Result<(), TerminalError> {
            Ok(())
        }
        fn foreground(&self) -> ForegroundProbe {
            let resized = lock(&self.0).take();
            Box::new(move || {
                resized?.recv_timeout(Duration::from_secs(5)).ok()?;
                Some(42)
            })
        }
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn reading_the_foreground_does_not_hold_the_pty() {
        let (_keep_reader, reader) = std_mpsc::channel();
        let (_keep_child, child) = std_mpsc::channel();
        let (resized, on_resize) = std_mpsc::channel();
        let process = PtyProcess {
            reader: Box::new(Open(reader)),
            writer: Box::new(Sink),
            master: Box::new(SlowMaster(Arc::new(Mutex::new(Some(on_resize))))),
            child: Box::new(Open(child)),
            killer: Box::new(NoKill),
        };
        let spec = LaunchSpec::new("sh").unwrap();
        let session = TerminalSession::start(
            TerminalId::generate(),
            &spec,
            process,
            &SessionConfig::default(),
            None,
        );
        let reading = {
            let session = Arc::clone(&session);
            std::thread::spawn(move || session.foreground())
        };
        std::thread::sleep(Duration::from_millis(100));
        session.resize(TerminalSize::new(80, 24).unwrap()).unwrap();
        resized.send(()).unwrap();
        assert_eq!(reading.join().unwrap(), Some(42));
    }
}
