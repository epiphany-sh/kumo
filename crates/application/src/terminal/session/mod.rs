//! A live terminal session: owns the PTY handles, its I/O threads and the
//! pump task, and fans output out to subscribers.

mod hub;
mod io_threads;
mod pump;

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, PoisonError};

use bytes::Bytes;
use kumo_domain::terminal::{
    LaunchSpec, PtyKiller, PtyMaster, PtyProcess, TerminalError, TerminalId, TerminalInfo,
    TerminalSize, TerminalStatus,
};
use kumo_domain::time::Timestamp;
use tokio::sync::{mpsc, oneshot};

pub use hub::Subscription;

use super::SessionConfig;
use hub::OutputHub;
use pump::Pump;

type SharedMaster = Arc<Mutex<Option<Box<dyn PtyMaster>>>>;

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

        let pump = Pump {
            id: id.clone(),
            chunks: chunk_rx,
            exit: exit_rx,
            hub: Arc::clone(&hub),
            max_batch_bytes: config.max_batch_bytes,
            exit_drain_idle: config.exit_drain_idle,
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

    /// Subscribes to output. See [`Subscription`] for ordering guarantees.
    pub fn subscribe(&self, with_replay: bool) -> Subscription {
        self.hub.subscribe(with_replay)
    }

    /// Queues input for the PTY. Waits if the input queue is full.
    pub async fn write(&self, data: Bytes) -> Result<(), TerminalError> {
        self.input
            .send(data)
            .await
            .map_err(|_| TerminalError::SessionClosed)
    }

    /// Resizing a finished session is a no-op.
    pub fn resize(&self, size: TerminalSize) -> Result<(), TerminalError> {
        let master = self.master.lock().unwrap_or_else(PoisonError::into_inner);
        match master.as_ref() {
            Some(master) => master.resize(size),
            None => Ok(()),
        }
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
