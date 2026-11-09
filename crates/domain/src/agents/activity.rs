use std::time::{Duration, Instant};

use super::AgentState;
use crate::terminal::plain_text;

/// Turns an agent's terminal output into "working" or "needs input".
///
/// Agent TUIs redraw while they work (spinners, streamed text) and go
/// quiet when it's the user's turn. Many also ring the bell or send a
/// desktop notification (OSC 9 / OSC 777) when they ask something: that
/// lasts until it's answered, even if a prompt keeps blinking meanwhile.
/// Pure: the caller passes the clock.
#[derive(Debug)]
pub struct ActivityTracker {
    quiet_after: Duration,
    state: AgentState,
    last_output: Instant,
    attention_at: Option<Instant>,
    resized_at: Option<Instant>,
    /// It's waiting because it asked (bell, notification), not just quiet.
    asked: bool,
    /// The output being read told it's only waiting for its next message.
    told_idle: bool,
    /// The output being read told it's working (an answer it got, maybe
    /// elsewhere).
    told_working: bool,
    osc: OscState,
}

#[derive(Debug, Clone, PartialEq, Eq)]
enum OscState {
    Ground,
    Escape,
    /// Inside `ESC ]`, collecting the first bytes to recognize it.
    Osc(Vec<u8>),
    OscEscape(Vec<u8>),
}

/// Output right after a notification or a resize is the TUI redrawing, not
/// new work.
const REDRAW_GRACE: Duration = Duration::from_millis(600);
/// This much output at once is work; less, while it's asking, is its prompt
/// blinking (Claude Code writes about 40 bytes every 0.6 s).
const WORK_OUTPUT: usize = 512;
/// How much of a notification is read to tell what it says.
const OSC_HEAD: usize = 96;
/// What Claude Code says when its turn ended: it isn't asking anything.
const IDLE_NOTICE: &[u8] = b"waiting for your input";

impl ActivityTracker {
    pub fn new(now: Instant, quiet_after: Duration) -> Self {
        Self {
            quiet_after,
            state: AgentState::Working,
            last_output: now,
            attention_at: None,
            resized_at: None,
            asked: false,
            told_idle: false,
            told_working: false,
            osc: OscState::Ground,
        }
    }

    pub fn state(&self) -> AgentState {
        self.state
    }

    /// Waiting because it asked for attention (an approval, usually), so
    /// what's typed now would answer it; false when it's only quiet.
    pub fn asked(&self) -> bool {
        self.state == AgentState::NeedsInput && self.asked
    }

    /// Feeds output. Returns the new state if it changed.
    pub fn on_output(&mut self, bytes: &[u8], now: Instant) -> Option<AgentState> {
        if matches!(self.state, AgentState::Exited(_)) {
            return None;
        }
        self.last_output = now;
        let attention = self.scan(bytes);
        if std::mem::take(&mut self.told_working) {
            return self.set(AgentState::Working);
        }
        if attention {
            self.attention_at = Some(now);
            self.asked = true;
            return self.set(AgentState::NeedsInput);
        }
        let small = bytes.len() < WORK_OUTPUT;
        if std::mem::take(&mut self.told_idle) && small {
            return None;
        }
        if self.asked && small {
            return None;
        }
        let redrawing = [self.attention_at, self.resized_at]
            .into_iter()
            .flatten()
            .any(|t| now.duration_since(t) < REDRAW_GRACE);
        if self.state == AgentState::NeedsInput && redrawing {
            return None;
        }
        self.set(AgentState::Working)
    }

    /// Its terminal changed size at `at`: it redraws, and that isn't work.
    pub fn resized(&mut self, at: Instant) {
        self.resized_at = Some(at);
    }

    /// Someone typed in its terminal at `at`: typed after it asked, that's
    /// the answer. Returns the new state if it changed.
    pub fn typed(&mut self, at: Instant) -> Option<AgentState> {
        if !self.asked() || self.attention_at.is_none_or(|asked| at <= asked) {
            return None;
        }
        self.last_output = at;
        self.set(AgentState::Working)
    }

    /// Called periodically: quiet for long enough means it's your turn.
    pub fn tick(&mut self, now: Instant) -> Option<AgentState> {
        if self.state == AgentState::Working
            && now.duration_since(self.last_output) >= self.quiet_after
        {
            self.asked = false;
            return self.set(AgentState::NeedsInput);
        }
        None
    }

    pub fn exited(&mut self, status: crate::terminal::ExitStatus) -> Option<AgentState> {
        self.set(AgentState::Exited(status))
    }

    fn set(&mut self, state: AgentState) -> Option<AgentState> {
        if state == AgentState::Working {
            self.asked = false;
        }
        (self.state != state).then(|| {
            self.state = state;
            state
        })
    }

    /// Whether `bytes` ask for attention: a bell outside escape sequences,
    /// or an OSC 9 / OSC 777 notification.
    fn scan(&mut self, bytes: &[u8]) -> bool {
        let mut attention = false;
        for &b in bytes {
            self.osc = match std::mem::replace(&mut self.osc, OscState::Ground) {
                OscState::Ground => match b {
                    0x1b => OscState::Escape,
                    0x07 => {
                        attention = true;
                        OscState::Ground
                    }
                    _ => OscState::Ground,
                },
                OscState::Escape => {
                    if b == b']' {
                        OscState::Osc(Vec::new())
                    } else {
                        OscState::Ground
                    }
                }
                OscState::Osc(mut head) => match b {
                    0x07 => {
                        attention |= self.notified(&head);
                        OscState::Ground
                    }
                    0x1b => OscState::OscEscape(head),
                    _ => {
                        if head.len() < OSC_HEAD {
                            head.push(b);
                        }
                        OscState::Osc(head)
                    }
                },
                OscState::OscEscape(head) => {
                    if b == b'\\' {
                        attention |= self.notified(&head);
                        OscState::Ground
                    } else {
                        OscState::Osc(head)
                    }
                }
            };
        }
        attention
    }

    /// Whether an OSC asks for attention. "Waiting for your input" is only
    /// its turn ending, and `9;4;` is a progress bar. `7501;state=…` says
    /// what it's doing (GitHub Copilot CLI): `blocked` is asking, `working`
    /// is working, `idle` and `done` are its turn ending.
    fn notified(&mut self, head: &[u8]) -> bool {
        if let Some(state) = head.strip_prefix(b"7501;state=") {
            let is = |s: &[u8]| {
                state.starts_with(s) && matches!(state.get(s.len()), None | Some(b':' | b';'))
            };
            self.told_working = is(b"working");
            if is(b"idle") || is(b"done") {
                // Answered or turned down: it isn't asking anymore.
                self.told_idle = true;
                self.asked = false;
            }
            return is(b"blocked");
        }
        let notification = head.starts_with(b"9;") || head.starts_with(b"777;notify");
        if !notification || head.starts_with(b"9;4;") {
            return false;
        }
        let idle = head.windows(IDLE_NOTICE.len()).any(|w| w == IDLE_NOTICE);
        self.told_idle |= idle;
        !idle
    }
}

/// The last readable line of an agent's output, for its card.
#[derive(Debug, Default)]
pub struct LastLine {
    tail: String,
}

impl LastLine {
    const KEEP: usize = 4096;
    const MAX_LEN: usize = 160;

    /// Feeds output; escape sequences are dropped.
    pub fn push(&mut self, bytes: &[u8]) {
        self.tail
            .push_str(&plain_text(&String::from_utf8_lossy(bytes)));
        if self.tail.len() > Self::KEEP {
            let cut = self.tail.len() - Self::KEEP;
            let cut = (cut..self.tail.len())
                .find(|i| self.tail.is_char_boundary(*i))
                .unwrap_or(0);
            self.tail.drain(..cut);
        }
    }

    /// The last line with some words in it (TUI borders and spinners skipped).
    pub fn get(&self) -> String {
        let line = self
            .tail
            .split(['\n', '\r'])
            .map(|l| l.trim_matches(|c: char| c.is_whitespace() || is_decoration(c)))
            .rfind(|l| l.chars().filter(|c| c.is_alphanumeric()).count() >= 3)
            .unwrap_or_default();
        if line.chars().count() > Self::MAX_LEN {
            format!(
                "{}…",
                line.chars().take(Self::MAX_LEN - 1).collect::<String>()
            )
        } else {
            line.to_owned()
        }
    }
}

/// Box drawing, blocks and braille spinners.
fn is_decoration(c: char) -> bool {
    matches!(c as u32, 0x2500..=0x259F | 0x2800..=0x28FF | 0x2190..=0x21FF | 0x25A0..=0x25FF)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::terminal::ExitStatus;

    const QUIET: Duration = Duration::from_secs(2);

    #[test]
    fn quiet_means_needs_input_and_output_means_working() {
        let t0 = Instant::now();
        let mut tracker = ActivityTracker::new(t0, QUIET);
        assert_eq!(tracker.tick(t0 + Duration::from_secs(1)), None);
        assert_eq!(tracker.tick(t0 + QUIET), Some(AgentState::NeedsInput));
        assert_eq!(
            tracker.on_output(b"thinking", t0 + Duration::from_secs(5)),
            Some(AgentState::Working)
        );
        assert_eq!(
            tracker.exited(ExitStatus::new(0)),
            Some(AgentState::Exited(ExitStatus::new(0)))
        );
        assert_eq!(
            tracker.on_output(b"late", t0 + Duration::from_secs(9)),
            None
        );
    }

    #[test]
    fn asking_is_told_apart_from_being_quiet() {
        let t0 = Instant::now();
        let mut quiet = ActivityTracker::new(t0, Duration::from_secs(1));
        quiet.tick(t0 + Duration::from_secs(2));
        assert!(quiet.state() == AgentState::NeedsInput && !quiet.asked());
        let mut asking = ActivityTracker::new(t0, Duration::from_secs(1));
        asking.on_output(b"Allow?\x07", t0);
        assert!(asking.asked());
        asking.typed(t0 + Duration::from_secs(1));
        assert!(!asking.asked());
        assert_eq!(asking.state(), AgentState::Working);
    }

    /// What GitHub Copilot CLI 1.0.107 wrote in a terminal: OSC 7501, ended
    /// by `ESC \`, with its redraw after it.
    #[test]
    fn copilot_says_when_it_works_asks_and_ends_its_turn() {
        let t0 = Instant::now();
        let at = |ms| t0 + Duration::from_millis(ms);
        let mut tracker = ActivityTracker::new(t0, QUIET);
        tracker.tick(at(3000));
        let working = b"h\x1b]7501;state=working:app=copilot\x1b\\\x1b[?25l\x1b[24A";
        assert_eq!(
            tracker.on_output(working, at(3100)),
            Some(AgentState::Working)
        );
        // Split across chunks, with its prompt drawn after it.
        assert_eq!(
            tracker.on_output(b"\x1b]7501;state=blocked:app=co", at(3200)),
            None
        );
        assert_eq!(
            tracker.on_output(b"pilot:kind=permission\x1b\\\x1b[90m\xe2\x95\xad", at(3200)),
            Some(AgentState::NeedsInput)
        );
        assert!(tracker.asked());
        assert_eq!(tracker.on_output(&[b'x'; 40], at(3900)), None);
        assert!(tracker.asked(), "its prompt redrawing isn't an answer");
        // Answered in the terminal: it says it's working, however little it
        // printed.
        assert_eq!(
            tracker.on_output(b"\x1b]7501;state=working:app=copilot\x1b\\", at(5000)),
            Some(AgentState::Working)
        );
        assert!(!tracker.asked());
        // Its turn ends: waiting, not asking.
        assert_eq!(
            tracker.on_output(b"\x1b]7501;state=done:app=copilot\x1b\\ok", at(6000)),
            None
        );
        assert_eq!(tracker.tick(at(6000) + QUIET), Some(AgentState::NeedsInput));
        assert!(!tracker.asked());
        // Lookalikes aren't states.
        let mut other = ActivityTracker::new(t0, QUIET);
        other.tick(at(3000));
        other.on_output(b"\x1b]7501;state=blockedish\x07", at(3100));
        assert!(!other.asked());
        other.on_output(b"\x1b]7502;state=blocked\x07", at(3200));
        assert!(!other.asked());
    }

    #[test]
    fn it_keeps_asking_while_its_prompt_blinks_until_it_is_answered() {
        let t0 = Instant::now();
        let at = |ms| t0 + Duration::from_millis(ms);
        let mut tracker = ActivityTracker::new(t0, QUIET);
        tracker.typed(t0);
        tracker.on_output(b"\x1b]9;Claude needs your permission\x07", at(100));
        assert!(tracker.asked());
        for ms in (700..10_000).step_by(600) {
            assert_eq!(tracker.on_output(&[b'x'; 40], at(ms)), None);
            tracker.tick(at(ms));
            assert!(tracker.asked(), "at {ms} ms");
        }
        // Typed before it asked: not the answer.
        assert_eq!(tracker.typed(t0), None);
        assert_eq!(tracker.typed(at(10_000)), Some(AgentState::Working));
        assert!(!tracker.asked());
    }

    #[test]
    fn real_output_ends_a_question_answered_elsewhere() {
        let t0 = Instant::now();
        let mut tracker = ActivityTracker::new(t0, QUIET);
        tracker.on_output(b"Allow?\x07", t0);
        assert_eq!(
            tracker.on_output(&[b'x'; WORK_OUTPUT], t0 + Duration::from_secs(1)),
            Some(AgentState::Working)
        );
        assert!(!tracker.asked());
    }

    #[test]
    fn the_end_of_its_turn_is_not_a_question_and_leaves_it_waiting() {
        let t0 = Instant::now();
        let mut tracker = ActivityTracker::new(t0, QUIET);
        tracker.tick(t0 + QUIET);
        assert_eq!(
            tracker.on_output(
                b"\x1b]9;Claude is waiting for your input\x07",
                t0 + Duration::from_secs(60),
            ),
            None
        );
        assert_eq!(tracker.state(), AgentState::NeedsInput);
        assert!(!tracker.asked());
    }

    #[test]
    fn a_progress_bar_is_not_a_question() {
        let t0 = Instant::now();
        let mut tracker = ActivityTracker::new(t0, QUIET);
        tracker.on_output(b"\x1b]9;4;1;50\x07", t0);
        assert_eq!(tracker.state(), AgentState::Working);
    }

    /// What made a note under the terminal flash: it appears when the agent
    /// goes quiet, resizes the terminal, the agent redraws, and that was read
    /// as work, which took the note away.
    #[test]
    fn redrawing_after_a_resize_is_not_work() {
        let t0 = Instant::now();
        let at = |ms| t0 + Duration::from_millis(ms);
        let mut tracker = ActivityTracker::new(t0, QUIET);
        assert_eq!(tracker.tick(at(2_000)), Some(AgentState::NeedsInput));
        tracker.resized(at(2_100));
        assert_eq!(tracker.on_output(b"redraw", at(2_110)), None);
        assert_eq!(tracker.state(), AgentState::NeedsInput);
        // Later output is work again.
        assert_eq!(
            tracker.on_output(b"thinking", at(2_800)),
            Some(AgentState::Working)
        );
    }

    #[test]
    fn bell_and_notifications_ask_for_attention_but_osc_terminators_do_not() {
        let t0 = Instant::now();
        let mut tracker = ActivityTracker::new(t0, QUIET);
        // A window title ends with BEL: not a bell.
        assert_eq!(tracker.on_output(b"\x1b]0;claude\x07working", t0), None);
        assert_eq!(tracker.state(), AgentState::Working);
        // Split across chunks: OSC 9 notification.
        assert_eq!(tracker.on_output(b"\x1b]9;Claude needs", t0), None);
        assert_eq!(
            tracker.on_output(b" your input\x07", t0),
            Some(AgentState::NeedsInput)
        );
        // The redraw right after doesn't count as new work.
        assert_eq!(
            tracker.on_output(b"redraw", t0 + Duration::from_millis(100)),
            None
        );
        assert_eq!(
            tracker.typed(t0 + Duration::from_secs(1)),
            Some(AgentState::Working)
        );
        assert_eq!(
            tracker.on_output(b"\x07", t0 + Duration::from_secs(2)),
            Some(AgentState::NeedsInput)
        );
    }

    #[test]
    fn last_line_skips_escapes_borders_and_spinners() {
        let mut last = LastLine::default();
        last.push(b"\x1b[1;32m\xe2\x97\x8f Edit src/lib.rs\x1b[0m\r\n");
        last.push("╭──────╮\r\n│ > _  │\r\n╰──────╯\r\n⠋\r\n".as_bytes());
        assert_eq!(last.get(), "Edit src/lib.rs");
        last.push(b"\x1b]0;title\x07Running tests\r\n");
        assert_eq!(last.get(), "Running tests");
    }
}
