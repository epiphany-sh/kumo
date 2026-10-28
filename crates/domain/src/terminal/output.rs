use bytes::Bytes;

use crate::time::Timestamp;

/// One raw read from the PTY.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OutputChunk {
    pub data: Bytes,
    pub read_at: Timestamp,
}

impl OutputChunk {
    pub fn new(data: Bytes, read_at: Timestamp) -> Self {
        Self { data, read_at }
    }
}

/// Several chunks coalesced into one message for subscribers.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OutputBatch {
    /// Monotonic per session, starting at 1.
    pub seq: u64,
    pub data: Bytes,
    /// When the first coalesced chunk was read from the PTY.
    pub first_read_at: Timestamp,
    /// How many chunks were coalesced.
    pub chunks: u32,
}
