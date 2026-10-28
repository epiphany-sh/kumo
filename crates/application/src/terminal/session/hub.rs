//! Fan-out of a session's output to its subscribers, with replay.

use std::sync::{Mutex, MutexGuard, PoisonError};

use futures::Stream;
use futures::stream::{self, StreamExt};
use kumo_domain::terminal::{ExitStatus, OutputBatch, ReplayBuffer, TerminalEvent, TerminalStatus};
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;

/// What a new subscriber gets: the replay snapshot, then live events.
///
/// Replay and live never overlap and never leave a gap: both are taken under
/// the same lock the pump uses to publish.
#[derive(Debug)]
pub struct Subscription {
    replay: Vec<OutputBatch>,
    /// Set when the session had already exited at subscribe time.
    exited: Option<ExitStatus>,
    live: mpsc::Receiver<TerminalEvent>,
}

impl Subscription {
    pub fn replay(&self) -> &[OutputBatch] {
        &self.replay
    }

    /// All events in order: replay, then live output, then `Exited`.
    pub fn into_stream(self) -> impl Stream<Item = TerminalEvent> + Send + 'static {
        let replay = stream::iter(self.replay.into_iter().map(TerminalEvent::Output));
        let already_exited = stream::iter(self.exited.map(TerminalEvent::Exited));
        replay
            .chain(already_exited)
            .chain(ReceiverStream::new(self.live))
    }
}

#[derive(Debug)]
struct Subscriber {
    id: u64,
    tx: mpsc::Sender<TerminalEvent>,
}

#[derive(Debug)]
struct HubState {
    replay: ReplayBuffer,
    subscribers: Vec<Subscriber>,
    next_subscriber_id: u64,
    status: TerminalStatus,
}

#[derive(Debug)]
pub(super) struct OutputHub {
    state: Mutex<HubState>,
    subscriber_queue_capacity: usize,
}

impl OutputHub {
    pub(super) fn new(replay_capacity_bytes: usize, subscriber_queue_capacity: usize) -> Self {
        Self {
            state: Mutex::new(HubState {
                replay: ReplayBuffer::new(replay_capacity_bytes),
                subscribers: Vec::new(),
                next_subscriber_id: 0,
                status: TerminalStatus::Running,
            }),
            subscriber_queue_capacity,
        }
    }

    pub(super) fn status(&self) -> TerminalStatus {
        self.lock().status
    }

    /// Atomically snapshots the replay and registers a live subscriber.
    pub(super) fn subscribe(&self, with_replay: bool) -> Subscription {
        let (tx, live) = mpsc::channel(self.subscriber_queue_capacity);
        let mut state = self.lock();
        let replay = if with_replay {
            state.replay.snapshot()
        } else {
            Vec::new()
        };
        let exited = state.status.exit_status();
        if exited.is_none() {
            let id = state.next_subscriber_id;
            state.next_subscriber_id += 1;
            state.subscribers.push(Subscriber { id, tx });
        }
        Subscription {
            replay,
            exited,
            live,
        }
    }

    /// Records the batch for replay and delivers it to every subscriber,
    /// waiting on slow ones (backpressure). Gone subscribers are dropped.
    pub(super) async fn publish(&self, batch: OutputBatch) {
        let targets = {
            let mut state = self.lock();
            state.replay.push(batch.clone());
            state
                .subscribers
                .iter()
                .map(|s| (s.id, s.tx.clone()))
                .collect::<Vec<_>>()
        };
        let mut gone = Vec::new();
        for (id, tx) in targets {
            if tx.send(TerminalEvent::Output(batch.clone())).await.is_err() {
                gone.push(id);
            }
        }
        if !gone.is_empty() {
            self.lock().subscribers.retain(|s| !gone.contains(&s.id));
        }
    }

    /// Marks the session as exited and sends the final event. Subscribers'
    /// streams end right after it.
    pub(super) async fn finish(&self, exit: ExitStatus) {
        let subscribers = {
            let mut state = self.lock();
            state.status = TerminalStatus::Exited(exit);
            std::mem::take(&mut state.subscribers)
        };
        for subscriber in subscribers {
            let _ = subscriber.tx.send(TerminalEvent::Exited(exit)).await;
        }
    }

    fn lock(&self) -> MutexGuard<'_, HubState> {
        // State stays consistent even if a holder panicked: recover it.
        self.state.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

#[cfg(test)]
mod tests {
    use bytes::Bytes;
    use kumo_domain::time::Timestamp;

    use super::*;

    fn batch(seq: u64) -> OutputBatch {
        OutputBatch {
            seq,
            data: Bytes::from(seq.to_string()),
            first_read_at: Timestamp::now(),
            chunks: 1,
        }
    }

    fn seqs(events: &[TerminalEvent]) -> Vec<u64> {
        events
            .iter()
            .filter_map(|e| match e {
                TerminalEvent::Output(b) => Some(b.seq),
                TerminalEvent::Exited(_) => None,
            })
            .collect()
    }

    #[tokio::test]
    async fn replay_then_live_without_gaps_or_duplicates() {
        let hub = OutputHub::new(1024, 8);
        hub.publish(batch(1)).await;
        hub.publish(batch(2)).await;
        let subscription = hub.subscribe(true);
        hub.publish(batch(3)).await;
        hub.finish(ExitStatus::new(0)).await;

        let events: Vec<_> = subscription.into_stream().collect().await;
        assert_eq!(seqs(&events), vec![1, 2, 3]);
        assert_eq!(
            events.last(),
            Some(&TerminalEvent::Exited(ExitStatus::new(0)))
        );
    }

    #[tokio::test]
    async fn without_replay_only_live() {
        let hub = OutputHub::new(1024, 8);
        hub.publish(batch(1)).await;
        let subscription = hub.subscribe(false);
        hub.publish(batch(2)).await;
        hub.finish(ExitStatus::new(3)).await;

        let events: Vec<_> = subscription.into_stream().collect().await;
        assert_eq!(seqs(&events), vec![2]);
    }

    #[tokio::test]
    async fn subscribing_after_exit_gets_replay_and_exit() {
        let hub = OutputHub::new(1024, 8);
        hub.publish(batch(1)).await;
        hub.finish(ExitStatus::new(7)).await;

        let events: Vec<_> = hub.subscribe(true).into_stream().collect().await;
        assert_eq!(seqs(&events), vec![1]);
        assert_eq!(
            events.last(),
            Some(&TerminalEvent::Exited(ExitStatus::new(7)))
        );
        assert_eq!(hub.status(), TerminalStatus::Exited(ExitStatus::new(7)));
    }

    #[tokio::test]
    async fn dropped_subscribers_are_forgotten() {
        let hub = OutputHub::new(1024, 8);
        drop(hub.subscribe(false));
        hub.publish(batch(1)).await;
        assert!(hub.lock().subscribers.is_empty());
    }
}
