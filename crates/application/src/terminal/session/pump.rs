//! The pump: turns PTY chunks into coalesced, sequenced batches.

use std::sync::Arc;
use std::time::Duration;

use kumo_domain::terminal::{BatchBuilder, ExitStatus, OutputChunk, TerminalId};
use kumo_domain::time::Timestamp;
use tokio::sync::{mpsc, oneshot};

use super::cursor::CursorAnswers;
use super::hub::OutputHub;
use super::recorder::Recorder;

pub(super) struct Pump {
    pub(super) id: TerminalId,
    pub(super) chunks: mpsc::Receiver<OutputChunk>,
    pub(super) exit: oneshot::Receiver<ExitStatus>,
    pub(super) hub: Arc<OutputHub>,
    pub(super) max_batch_bytes: usize,
    pub(super) exit_drain_idle: Duration,
    /// A shell's: reads the commands it ran out of its output.
    pub(super) recorder: Option<Recorder>,
    /// On a PTY that holds its program for it: says where the cursor is
    /// while no client does.
    pub(super) cursor: Option<CursorAnswers>,
}

impl Pump {
    /// What the session itself reads from a chunk, and the chunk as it's
    /// published; None when nothing of it is left to.
    fn read(&mut self, mut chunk: OutputChunk) -> Option<OutputChunk> {
        if let Some(cursor) = &mut self.cursor {
            chunk.data = cursor.filter(chunk.data);
            if chunk.data.is_empty() {
                return None;
            }
        }
        if let Some(recorder) = &mut self.recorder {
            recorder.feed(&chunk);
        }
        Some(chunk)
    }

    async fn publish(&mut self, builder: BatchBuilder, seq: &mut u64) {
        // Before the output that says it's done: whoever sees that and
        // asks for the history finds the command there.
        if let Some(recorder) = &mut self.recorder {
            recorder.flush(&self.id).await;
        }
        *seq += 1;
        let batch = builder.build(*seq);
        tracing::trace!(
            terminal = %self.id,
            seq = *seq,
            bytes = batch.data.len(),
            chunks = batch.chunks,
            queued_us = Timestamp::now().since(batch.first_read_at).as_micros() as u64,
            "publish batch"
        );
        self.hub.publish(batch).await;
    }

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
            let Some(first) = self.read(first) else {
                continue;
            };
            let mut builder = BatchBuilder::new(first, self.max_batch_bytes);
            while builder.has_room() {
                match self.chunks.try_recv() {
                    Ok(chunk) => {
                        if let Some(chunk) = self.read(chunk) {
                            builder.push(chunk);
                        }
                    }
                    Err(_) => break,
                }
            }
            self.publish(builder, &mut seq).await;
        }
        // The start of a request it held back, that never was one.
        let held = self.cursor.as_mut().map(CursorAnswers::release);
        if let Some(held) = held.filter(|held| !held.is_empty()) {
            let chunk = OutputChunk::new(held.into(), Timestamp::now());
            let builder = BatchBuilder::new(chunk, self.max_batch_bytes);
            self.publish(builder, &mut seq).await;
        }

        let exit = match exit {
            Some(status) => status,
            None => self.exit.await.unwrap_or(ExitStatus::UNKNOWN),
        };
        tracing::debug!(terminal = %self.id, code = exit.code(), batches = seq, "terminal exited");
        self.hub.finish(exit).await;
        if let Some(recorder) = &self.recorder {
            recorder.ended();
        }
        exit
    }
}
