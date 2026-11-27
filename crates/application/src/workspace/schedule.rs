//! When to re-read git after files change on disk.
//!
//! An agent writing files nonstop would otherwise have git re-read many
//! times a second. Each key (a repository or a worktree) is refreshed:
//!
//! - a short [nudge](Timing::nudge) after the first change, so a single
//!   save shows right away. Later changes don't push it back: a stream of
//!   them can't starve the refresh.
//! - then at most once per [gap](Timing::min_gap) (counted from the end of
//!   the last run), or per run's duration if git got slow, up to
//!   [`max_gap`](Timing::max_gap).
//! - one run at a time: changes during a run cause exactly one more.
//!
//! A window in the background stretches the gap; a hidden one pauses
//! refreshes until it shows again, then catches up once.

use std::collections::HashMap;
use std::hash::Hash;
use std::sync::{Arc, Mutex, PoisonError};
use std::time::Duration;

use futures::future::BoxFuture;
use tokio::sync::{mpsc, watch};
use tokio::time::Instant;

/// Whether the user can see the app.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Presence {
    /// The window has the keyboard focus.
    pub focused: bool,
    /// The window is on screen (not minimized or hidden).
    pub visible: bool,
}

impl Default for Presence {
    /// Until a client says otherwise: in front of the user.
    fn default() -> Self {
        Self {
            focused: true,
            visible: true,
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub(crate) struct Timing {
    /// From the first change to the first run.
    pub nudge: Duration,
    /// Between the end of a run and the start of the next.
    pub min_gap: Duration,
    /// The longest gap, however slow git got.
    pub max_gap: Duration,
    /// How much longer the gap is while the window is in the background.
    pub unfocused_factor: u32,
}

impl Default for Timing {
    fn default() -> Self {
        Self {
            nudge: Duration::from_millis(125),
            min_gap: Duration::from_secs(3),
            max_gap: Duration::from_secs(5 * 60),
            unfocused_factor: 20,
        }
    }
}

impl Timing {
    /// When the run asked for at `first` is due, given the last run's end
    /// and duration.
    fn due(
        &self,
        first: Instant,
        last: Option<(Instant, Duration)>,
        presence: Presence,
    ) -> Instant {
        let nudged = first + self.nudge;
        let Some((ended, took)) = last else {
            return nudged;
        };
        let factor = if presence.focused {
            1
        } else {
            self.unfocused_factor
        };
        let gap = (self.min_gap * factor).max(took).min(self.max_gap);
        nudged.max(ended + gap)
    }
}

/// Runs one key's refresh.
pub(crate) type Refresh<K> = Arc<dyn Fn(K) -> BoxFuture<'static, ()> + Send + Sync>;

/// Refreshes keys as their changes come in (see the module docs). Must be
/// used inside a Tokio runtime; dropping it stops every key's schedule.
pub(crate) struct Scheduler<K> {
    timing: Timing,
    presence: watch::Receiver<Presence>,
    refresh: Refresh<K>,
    keys: Mutex<HashMap<K, mpsc::Sender<()>>>,
}

impl<K: Clone + Eq + Hash + Send + Sync + 'static> Scheduler<K> {
    pub fn new(timing: Timing, presence: watch::Receiver<Presence>, refresh: Refresh<K>) -> Self {
        Self {
            timing,
            presence,
            refresh,
            keys: Mutex::default(),
        }
    }

    /// Something changed for `key`: it'll be refreshed when due.
    pub fn notify(&self, key: K) {
        let mut keys = self.keys.lock().unwrap_or_else(PoisonError::into_inner);
        let changes = keys.entry(key.clone()).or_insert_with(|| {
            // One slot: changes waiting for a run are one change.
            let (changes, pending) = mpsc::channel(1);
            tokio::spawn(drive(
                key,
                pending,
                self.presence.clone(),
                self.timing,
                Arc::clone(&self.refresh),
            ));
            changes
        });
        let _ = changes.try_send(());
    }
}

/// One key's schedule, until the scheduler is dropped.
async fn drive<K: Clone>(
    key: K,
    mut pending: mpsc::Receiver<()>,
    mut presence: watch::Receiver<Presence>,
    timing: Timing,
    refresh: Refresh<K>,
) {
    let mut last: Option<(Instant, Duration)> = None;
    while pending.recv().await.is_some() {
        let first = Instant::now();
        wait_until_due(&timing, first, last, &mut presence).await;
        // What changed until now, this run reads.
        while pending.try_recv().is_ok() {}
        let started = Instant::now();
        refresh(key.clone()).await;
        let ended = Instant::now();
        last = Some((ended, ended - started));
    }
}

/// Sleeps until the run is due, following the window: hidden waits for it
/// to show, the background stretches the gap, back in front shortens it.
async fn wait_until_due(
    timing: &Timing,
    first: Instant,
    last: Option<(Instant, Duration)>,
    presence: &mut watch::Receiver<Presence>,
) {
    let mut told = true; // false once nobody can change the presence
    loop {
        let now = *presence.borrow_and_update();
        if !told {
            tokio::time::sleep_until(timing.due(first, last, now)).await;
            return;
        }
        if !now.visible {
            told = presence.changed().await.is_ok();
            continue;
        }
        tokio::select! {
            () = tokio::time::sleep_until(timing.due(first, last, now)) => return,
            changed = presence.changed() => told = changed.is_ok(),
        }
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Mutex;

    use futures::FutureExt;

    use super::*;

    const NUDGE: Duration = Duration::from_millis(125);
    const GAP: Duration = Duration::from_secs(3);

    /// Records when each run started; each run takes `took`.
    struct Fixture {
        scheduler: Scheduler<&'static str>,
        presence: watch::Sender<Presence>,
        runs: Arc<Mutex<Vec<(&'static str, Duration)>>>,
        start: Instant,
    }

    fn fixture(took: Duration) -> Fixture {
        let (presence, watched) = watch::channel(Presence::default());
        let runs: Arc<Mutex<Vec<(&'static str, Duration)>>> = Arc::default();
        let start = Instant::now();
        let seen = Arc::clone(&runs);
        let refresh: Refresh<&'static str> = Arc::new(move |key| {
            seen.lock().unwrap().push((key, start.elapsed()));
            tokio::time::sleep(took).boxed()
        });
        Fixture {
            scheduler: Scheduler::new(Timing::default(), watched, refresh),
            presence,
            runs,
            start,
        }
    }

    impl Fixture {
        fn runs(&self) -> Vec<Duration> {
            self.runs
                .lock()
                .unwrap()
                .iter()
                .map(|(_, at)| *at)
                .collect()
        }

        /// Sleeps until `at` since the fixture started.
        async fn until(&self, at: Duration) {
            tokio::time::sleep_until(self.start + at).await;
        }
    }

    fn ms(n: u64) -> Duration {
        Duration::from_millis(n)
    }

    #[tokio::test(start_paused = true)]
    async fn the_first_change_runs_after_the_nudge() {
        let f = fixture(ms(10));
        f.scheduler.notify("wt");
        f.until(NUDGE - ms(1)).await;
        assert!(f.runs().is_empty(), "ran before the nudge");
        f.until(NUDGE + ms(1)).await;
        assert_eq!(f.runs(), vec![NUDGE]);
    }

    #[tokio::test(start_paused = true)]
    async fn later_changes_dont_push_the_first_run_back() {
        let f = fixture(ms(10));
        for at in [0, 50, 100, 120] {
            f.until(ms(at)).await;
            f.scheduler.notify("wt");
        }
        f.until(ms(500)).await;
        assert_eq!(f.runs(), vec![NUDGE]);
    }

    #[tokio::test(start_paused = true)]
    async fn a_stream_of_changes_runs_at_most_once_per_gap() {
        let f = fixture(ms(200));
        let mut at = Duration::ZERO;
        while at < Duration::from_secs(20) {
            f.until(at).await;
            f.scheduler.notify("wt");
            at += ms(10);
        }
        f.until(Duration::from_secs(30)).await;
        let runs = f.runs();
        assert_eq!(runs[0], NUDGE);
        for pair in runs.windows(2) {
            // Gap counted from the end of the previous run (200 ms long).
            assert!(pair[1] - pair[0] >= GAP + ms(200), "{runs:?}");
        }
        // 20 s of changes: the first run, then one every 3.2 s or so.
        assert!((6..=8).contains(&runs.len()), "{runs:?}");
    }

    #[tokio::test(start_paused = true)]
    async fn changes_during_a_run_cause_exactly_one_more() {
        let f = fixture(Duration::from_secs(1));
        f.scheduler.notify("wt");
        // The run goes from 125 ms to 1125 ms.
        for at in [500, 700, 900] {
            f.until(ms(at)).await;
            f.scheduler.notify("wt");
        }
        f.until(Duration::from_secs(30)).await;
        assert_eq!(f.runs(), vec![NUDGE, ms(1125) + GAP]);
    }

    #[tokio::test(start_paused = true)]
    async fn a_slow_run_stretches_the_gap() {
        let f = fixture(Duration::from_secs(10));
        f.scheduler.notify("wt");
        f.until(ms(200)).await;
        f.scheduler.notify("wt");
        f.until(Duration::from_secs(60)).await;
        // Ends at 10.125 s; waits as long as it took, not 3 s.
        assert_eq!(f.runs(), vec![NUDGE, NUDGE + Duration::from_secs(20)]);
    }

    #[tokio::test(start_paused = true)]
    async fn in_the_background_the_gap_is_twenty_times_longer() {
        let f = fixture(ms(0));
        f.presence.send_replace(Presence {
            focused: false,
            visible: true,
        });
        f.scheduler.notify("wt");
        f.until(Duration::from_secs(1)).await;
        f.scheduler.notify("wt");
        f.until(Duration::from_secs(120)).await;
        assert_eq!(f.runs(), vec![NUDGE, NUDGE + Duration::from_secs(60)]);
    }

    #[tokio::test(start_paused = true)]
    async fn back_in_front_the_short_gap_applies_again() {
        let f = fixture(ms(0));
        f.presence.send_replace(Presence {
            focused: false,
            visible: true,
        });
        f.scheduler.notify("wt");
        f.until(Duration::from_secs(1)).await;
        f.scheduler.notify("wt");
        f.until(Duration::from_secs(10)).await;
        f.presence.send_replace(Presence::default());
        f.until(Duration::from_secs(20)).await;
        // Due at 3.125 s, already past when the window came back.
        assert_eq!(f.runs(), vec![NUDGE, Duration::from_secs(10)]);
    }

    #[tokio::test(start_paused = true)]
    async fn hidden_pauses_then_catches_up_once() {
        let f = fixture(ms(0));
        f.presence.send_replace(Presence {
            focused: false,
            visible: false,
        });
        for at in [0, 1000, 5000, 60_000] {
            f.until(ms(at)).await;
            f.scheduler.notify("wt");
        }
        f.until(Duration::from_secs(600)).await;
        assert!(f.runs().is_empty(), "ran while hidden");

        f.presence.send_replace(Presence::default());
        f.until(Duration::from_secs(700)).await;
        assert_eq!(f.runs(), vec![Duration::from_secs(600)]);
    }

    #[tokio::test(start_paused = true)]
    async fn hidden_without_changes_runs_nothing_on_return() {
        let f = fixture(ms(0));
        f.presence.send_replace(Presence {
            focused: false,
            visible: false,
        });
        f.until(Duration::from_secs(10)).await;
        f.presence.send_replace(Presence::default());
        f.until(Duration::from_secs(20)).await;
        assert!(f.runs().is_empty());
    }

    #[tokio::test(start_paused = true)]
    async fn keys_have_their_own_schedules() {
        let f = fixture(ms(0));
        f.scheduler.notify("a");
        f.until(ms(1000)).await;
        f.scheduler.notify("b");
        f.until(ms(2000)).await;
        let runs = f.runs.lock().unwrap().clone();
        assert_eq!(runs, vec![("a", NUDGE), ("b", ms(1000) + NUDGE)]);
    }
}
