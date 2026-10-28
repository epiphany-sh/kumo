use bytes::{Bytes, BytesMut};

use super::{OutputBatch, OutputChunk};
use crate::time::Timestamp;

/// Coalesces chunks that are already waiting into a single batch.
///
/// The caller seeds it with the chunk it just received and keeps pushing
/// chunks that are *already available* while [`has_room`](Self::has_room)
/// holds. It never waits: under light traffic (typing) a batch is one chunk
/// and leaves immediately; under heavy traffic batches grow on their own.
#[derive(Debug)]
pub struct BatchBuilder {
    max_bytes: usize,
    first_read_at: Timestamp,
    chunks: Vec<Bytes>,
    len: usize,
}

impl BatchBuilder {
    pub fn new(first: OutputChunk, max_bytes: usize) -> Self {
        let len = first.data.len();
        Self {
            max_bytes,
            first_read_at: first.read_at,
            chunks: vec![first.data],
            len,
        }
    }

    pub fn has_room(&self) -> bool {
        self.len < self.max_bytes
    }

    pub fn push(&mut self, chunk: OutputChunk) {
        self.len += chunk.data.len();
        self.chunks.push(chunk.data);
    }

    pub fn len(&self) -> usize {
        self.len
    }

    pub fn is_empty(&self) -> bool {
        self.len == 0
    }

    /// Builds the batch. A single chunk is passed through without copying.
    pub fn build(mut self, seq: u64) -> OutputBatch {
        let chunks = u32::try_from(self.chunks.len()).unwrap_or(u32::MAX);
        let data = if self.chunks.len() == 1 {
            self.chunks.pop().unwrap_or_default()
        } else {
            let mut joined = BytesMut::with_capacity(self.len);
            for chunk in &self.chunks {
                joined.extend_from_slice(chunk);
            }
            joined.freeze()
        };
        OutputBatch {
            seq,
            data,
            first_read_at: self.first_read_at,
            chunks,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn chunk(data: &'static [u8], at: u64) -> OutputChunk {
        OutputChunk::new(Bytes::from_static(data), Timestamp::from_unix_nanos(at))
    }

    #[test]
    fn single_chunk_passes_through() {
        let batch = BatchBuilder::new(chunk(b"a", 7), 16).build(1);
        assert_eq!(batch.data, Bytes::from_static(b"a"));
        assert_eq!((batch.seq, batch.chunks), (1, 1));
        assert_eq!(batch.first_read_at.as_unix_nanos(), 7);
    }

    #[test]
    fn joins_chunks_and_keeps_first_timestamp() {
        let mut builder = BatchBuilder::new(chunk(b"ab", 1), 16);
        builder.push(chunk(b"cd", 2));
        let batch = builder.build(9);
        assert_eq!(batch.data, Bytes::from_static(b"abcd"));
        assert_eq!(batch.chunks, 2);
        assert_eq!(batch.first_read_at.as_unix_nanos(), 1);
    }

    #[test]
    fn stops_having_room_at_max() {
        let mut builder = BatchBuilder::new(chunk(b"abc", 1), 4);
        assert!(builder.has_room());
        builder.push(chunk(b"d", 2));
        assert!(!builder.has_room());
    }
}
