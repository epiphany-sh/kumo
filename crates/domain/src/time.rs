use std::time::{Duration, SystemTime, UNIX_EPOCH};

/// Wall-clock instant as nanoseconds since the Unix epoch.
///
/// Used for latency tracing across processes (daemon and clients share the
/// machine clock), so it is wall-clock rather than monotonic.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Timestamp(u64);

impl Timestamp {
    pub fn now() -> Self {
        let since_epoch = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or(Duration::ZERO);
        Self(u64::try_from(since_epoch.as_nanos()).unwrap_or(u64::MAX))
    }

    pub const fn from_unix_nanos(nanos: u64) -> Self {
        Self(nanos)
    }

    pub const fn as_unix_nanos(self) -> u64 {
        self.0
    }

    /// Time elapsed from `earlier` to `self`; zero if `earlier` is later.
    pub fn since(self, earlier: Timestamp) -> Duration {
        Duration::from_nanos(self.0.saturating_sub(earlier.0))
    }
}
