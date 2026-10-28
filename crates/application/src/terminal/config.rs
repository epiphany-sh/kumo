use std::time::Duration;

/// Tuning knobs of a terminal session. Defaults follow kumo.md §5 and §8.
#[derive(Debug, Clone)]
pub struct SessionConfig {
    /// Size of each blocking `read()` from the PTY.
    pub read_buffer_bytes: usize,
    /// Bounded queue between the PTY reader thread and the pump. When full,
    /// the reader blocks and so does the child process (backpressure).
    pub chunk_queue_capacity: usize,
    /// Upper bound for coalescing already-queued chunks into one batch.
    pub max_batch_bytes: usize,
    /// Bounded replay kept for clients that (re)attach.
    pub replay_capacity_bytes: usize,
    /// Batches buffered per subscriber before the pump waits on it.
    pub subscriber_queue_capacity: usize,
    /// Bounded queue of client input waiting to be written to the PTY.
    pub input_queue_capacity: usize,
    /// After the process exits, how long to wait for more output before
    /// declaring the session finished (some platforms never signal EOF while
    /// grandchildren keep the PTY open).
    pub exit_drain_idle: Duration,
}

impl Default for SessionConfig {
    fn default() -> Self {
        Self {
            read_buffer_bytes: 64 * 1024,
            chunk_queue_capacity: 64,
            max_batch_bytes: 256 * 1024,
            replay_capacity_bytes: 2 * 1024 * 1024,
            subscriber_queue_capacity: 4,
            input_queue_capacity: 256,
            exit_drain_idle: Duration::from_millis(100),
        }
    }
}
