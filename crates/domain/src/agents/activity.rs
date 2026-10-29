use std::time::{Duration, Instant};

use super::AgentState;
use crate::terminal::plain_text;

/// Turns an agent's terminal output into "working" or "needs input".
///
/// Agent TUIs redraw while they work (spinners, streamed text) and go
/// quiet when it's the user's turn. Many also ring the bell or send a
/// desktop notification (OSC 9 / OSC 777) when they need attention. Pure:
/// the caller passes the clock.
#[derive(Debug)]
pub struct ActivityTracker {
    quiet_after: Duration,
    state: AgentState,
    last_output: Instant,
    attention_at: Option<Instant>,
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

/// Output right after a notification is the TUI redrawing, not new work.
const ATTENTION_GRACE: Duration = Duration::from_millis(600);

impl ActivityTracker {
    pub fn new(now: Instant, quiet_after: Duration) -> Self {
        Self {
            quiet_after,
            state: AgentState::Working,
            last_output: now,
            attention_at: None,
            osc: OscState::Ground,
        }
    }

    pub fn state(&self) -> AgentState {
        self.state
    }

    /// Feeds output. Returns the new state if it changed.
    pub fn on_output(&mut self, bytes: &[u8], now: Instant) -> Option<AgentState> {
        if matches!(self.state, AgentState::Exited(_)) {
            return None;
        }
        self.last_output = now;
        if self.scan(bytes) {
            self.attention_at = Some(now);
            return self.set(AgentState::NeedsInput);
        }
        let in_grace = self
            .attention_at
            .is_some_and(|t| now.duration_since(t) < ATTENTION_GRACE);
        if self.state == AgentState::NeedsInput && in_grace {
            return None;
        }
        self.set(AgentState::Working)
    }

    /// Called periodically: quiet for long enough means it's your turn.
    pub fn tick(&mut self, now: Instant) -> Option<AgentState> {
        if self.state == AgentState::Working
            && now.duration_since(self.last_output) >= self.quiet_after
        {
            return self.set(AgentState::NeedsInput);
        }
        None
    }

    pub fn exited(&mut self, status: crate::terminal::ExitStatus) -> Option<AgentState> {
        self.set(AgentState::Exited(status))
    }

    fn set(&mut self, state: AgentState) -> Option<AgentState> {
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
                        attention |= is_notification(&head);
                        OscState::Ground
                    }
                    0x1b => OscState::OscEscape(head),
                    _ => {
                        if head.len() < 16 {
                            head.push(b);
                        }
                        OscState::Osc(head)
                    }
                },
                OscState::OscEscape(head) => {
                    if b == b'\\' {
                        attention |= is_notification(&head);
                        OscState::Ground
                    } else {
                        OscState::Osc(head)
                    }
                }
            };
        }
        attention
    }
}

fn is_notification(head: &[u8]) -> bool {
    head.starts_with(b"9;") || head.starts_with(b"777;notify")
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
            tracker.on_output(b"new work", t0 + Duration::from_secs(1)),
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
