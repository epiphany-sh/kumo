//! The pump: turns PTY chunks into coalesced, sequenced batches.

use std::sync::Arc;
use std::time::Duration;

use kumo_domain::terminal::{BatchBuilder, ExitStatus, OutputChunk, TerminalId};
use kumo_domain::time::Timestamp;
use tokio::sync::{mpsc, oneshot};

use super::hub::OutputHub;

pub(super) struct Pump {
    pub(super) id: TerminalId,
    pub(super) chunks: mpsc::Receiver<OutputChunk>,
    pub(super) exit: oneshot::Receiver<ExitStatus>,
    pub(super) hub: Arc<OutputHub>,
    pub(super) max_batch_bytes: usize,
    pub(super) exit_drain_idle: Duration,
}

impl Pump {
    /// Runs until the process exited and its output was drained. Returns
    /// the exit status after publishing it.
    ///
    /// Coalescing adds no latency: it never waits for more data, it only
    /// takes what is already queued (kumo.md §5.4).
    pub(super) async fn run(mut self) -> ExitStatus {
        let mut seq = 0_u64;
        let mut exit = None;

        loop {
            let next = match exit {
                // Running: wait for output or for the process to end.
                None => tokio::select! {
                    biased;
                    chunk = self.chunks.recv() => chunk,
                    status = &mut self.exit => {
                        exit = Some(status.unwrap_or(ExitStatus::UNKNOWN));
                        continue;
                    }
                },
                // Exited: drain what is left, but don't wait forever for an
                // EOF that may never come.
                Some(_) => tokio::time::timeout(self.exit_drain_idle, self.chunks.recv())
                    .await
                    .unwrap_or(None),
            };
            let Some(first) = next else { break };

            let mut builder = BatchBuilder::new(first, self.max_batch_bytes);
            while builder.has_room() {
                match self.chunks.try_recv() {
                    Ok(chunk) => builder.push(chunk),
                    Err(_) => break,
                }
            }
            seq += 1;
            let batch = builder.build(seq);
            tracing::trace!(
                terminal = %self.id,
                seq,
                bytes = batch.data.len(),
                chunks = batch.chunks,
                queued_us = Timestamp::now().since(batch.first_read_at).as_micros() as u64,
                "publish batch"
            );
            self.hub.publish(batch).await;
        }

        let exit = match exit {
            Some(status) => status,
            None => self.exit.await.unwrap_or(ExitStatus::UNKNOWN),
        };
        tracing::debug!(terminal = %self.id, code = exit.code(), batches = seq, "terminal exited");
        self.hub.finish(exit).await;
        exit
    }
}
