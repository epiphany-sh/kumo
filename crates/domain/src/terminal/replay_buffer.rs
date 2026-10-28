use std::collections::VecDeque;

use super::OutputBatch;

/// Most recent output batches, bounded by total bytes.
///
/// Lets a client that (re)attaches catch up. The oldest batches are dropped
/// first; the newest batch is always kept even if it alone exceeds the
/// capacity.
#[derive(Debug)]
pub struct ReplayBuffer {
    capacity_bytes: usize,
    len_bytes: usize,
    batches: VecDeque<OutputBatch>,
}

impl ReplayBuffer {
    pub fn new(capacity_bytes: usize) -> Self {
        Self {
            capacity_bytes,
            len_bytes: 0,
            batches: VecDeque::new(),
        }
    }

    pub fn push(&mut self, batch: OutputBatch) {
        self.len_bytes += batch.data.len();
        self.batches.push_back(batch);
        while self.len_bytes > self.capacity_bytes && self.batches.len() > 1 {
            if let Some(evicted) = self.batches.pop_front() {
                self.len_bytes -= evicted.data.len();
            }
        }
    }

    /// Copy of the buffered batches, oldest first. Cheap: data is shared.
    pub fn snapshot(&self) -> Vec<OutputBatch> {
        self.batches.iter().cloned().collect()
    }

    pub fn len_bytes(&self) -> usize {
        self.len_bytes
    }
}

#[cfg(test)]
mod tests {
    use bytes::Bytes;

    use super::*;
    use crate::time::Timestamp;

    fn batch(seq: u64, len: usize) -> OutputBatch {
        OutputBatch {
            seq,
            data: Bytes::from(vec![b'x'; len]),
            first_read_at: Timestamp::from_unix_nanos(0),
            chunks: 1,
        }
    }

    #[test]
    fn evicts_oldest_beyond_capacity() {
        let mut replay = ReplayBuffer::new(10);
        replay.push(batch(1, 4));
        replay.push(batch(2, 4));
        replay.push(batch(3, 4));
        let seqs: Vec<_> = replay.snapshot().iter().map(|b| b.seq).collect();
        assert_eq!(seqs, vec![2, 3]);
        assert_eq!(replay.len_bytes(), 8);
    }

    #[test]
    fn keeps_newest_batch_even_if_oversized() {
        let mut replay = ReplayBuffer::new(10);
        replay.push(batch(1, 4));
        replay.push(batch(2, 50));
        let seqs: Vec<_> = replay.snapshot().iter().map(|b| b.seq).collect();
        assert_eq!(seqs, vec![2]);
    }
}
