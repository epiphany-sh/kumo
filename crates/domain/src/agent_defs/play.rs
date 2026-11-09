/// One thing a test run printed, or how it ended.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PlayEventKind {
    /// One stdout line of stream-json, as is.
    Line(String),
    /// Its exit code: the last event.
    Exited(i32),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlayEvent {
    pub kind: PlayEventKind,
    /// Since the start.
    pub at_ms: i64,
}

/// A test run of an agent, with everything it printed.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct PlayRecord {
    pub id: String,
    pub task: String,
    /// The unsaved draft ran.
    pub draft: bool,
    pub started_unix_ms: i64,
    pub events: Vec<PlayEvent>,
    pub running: bool,
}

impl PlayRecord {
    /// Test runs kept per agent.
    pub const KEEP: usize = 10;
    /// Lines kept per run: a runaway one doesn't fill the store.
    pub const MAX_LINES: usize = 5_000;

    /// Adds a line, unless it already has [`Self::MAX_LINES`]. True when
    /// it was kept.
    pub fn push_line(&mut self, line: String, at_ms: i64) -> bool {
        let lines = self
            .events
            .iter()
            .filter(|e| matches!(e.kind, PlayEventKind::Line(_)))
            .count();
        if lines >= Self::MAX_LINES {
            return false;
        }
        self.events.push(PlayEvent {
            kind: PlayEventKind::Line(line),
            at_ms,
        });
        true
    }

    pub fn exit(&mut self, code: i32, at_ms: i64) {
        self.running = false;
        self.events.push(PlayEvent {
            kind: PlayEventKind::Exited(code),
            at_ms,
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_run_keeps_its_lines_up_to_the_cap() {
        let mut play = PlayRecord {
            running: true,
            ..Default::default()
        };
        for i in 0..PlayRecord::MAX_LINES + 3 {
            play.push_line(format!("{i}"), 0);
        }
        play.exit(0, 9);
        assert_eq!(play.events.len(), PlayRecord::MAX_LINES + 1);
        assert_eq!(play.events.last().unwrap().kind, PlayEventKind::Exited(0));
        assert!(!play.running);
    }
}
