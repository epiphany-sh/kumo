/// Whether the program turned bracketed paste on (`ESC[?2004h`) or off
/// (`ESC[?2004l`), by the last of them in `output`; None when neither is
/// there.
pub fn bracketed_paste(output: &[u8]) -> Option<bool> {
    let on = find_last(output, b"\x1b[?2004h");
    let off = find_last(output, b"\x1b[?2004l");
    match (on, off) {
        (None, None) => None,
        (Some(_), None) => Some(true),
        (None, Some(_)) => Some(false),
        (Some(on), Some(off)) => Some(on > off),
    }
}

fn find_last(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    haystack.windows(needle.len()).rposition(|w| w == needle)
}

/// `text` as typed into a terminal: escapes dropped, and wrapped as a
/// bracketed paste when `bracketed` (several lines then go in as one
/// message instead of one per line).
pub fn typed_text(text: &str, bracketed: bool) -> String {
    let text = text.replace('\x1b', "");
    if bracketed {
        format!("\x1b[200~{text}\x1b[201~")
    } else {
        text
    }
}

/// Terminal output as plain text: escape sequences dropped, cursor jumps
/// read as line breaks and cursor-forward as a space, so lines drawn by
/// TUIs still come out as lines.
pub fn plain_text(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut chars = text.chars().peekable();
    while let Some(c) = chars.next() {
        if c != '\u{1b}' {
            if !c.is_control() || matches!(c, '\n' | '\r' | '\t') {
                out.push(c);
            }
            continue;
        }
        match chars.next() {
            // CSI: parameters, then a final byte in @..~.
            Some('[') => {
                for c in chars.by_ref() {
                    if ('@'..='~').contains(&c) {
                        match c {
                            'H' | 'f' | 'd' | 'E' | 'F' => out.push('\n'),
                            'C' => out.push(' '),
                            _ => {}
                        }
                        break;
                    }
                }
            }
            // OSC / DCS…: until BEL or ESC \.
            Some(']' | 'P' | '_' | '^') => {
                while let Some(c) = chars.next() {
                    if c == '\u{7}' || (c == '\u{1b}' && chars.peek() == Some(&'\\')) {
                        chars.next_if_eq(&'\\');
                        break;
                    }
                }
            }
            _ => {}
        }
    }
    out
}

/// Collects output until whole lines are in, so escape sequences and
/// multi-byte characters split across reads come out intact.
#[derive(Debug, Default)]
pub struct LineSplitter {
    pending: Vec<u8>,
}

impl LineSplitter {
    /// Bytes kept waiting for a line break before they're read anyway.
    const MAX_PENDING: usize = 16 * 1024;

    /// The plain lines completed by `bytes` (split on `\n` and `\r`).
    pub fn push(&mut self, bytes: &[u8]) -> Vec<String> {
        self.pending.extend_from_slice(bytes);
        let end = match self
            .pending
            .iter()
            .rposition(|b| matches!(b, b'\n' | b'\r'))
        {
            Some(at) => at + 1,
            None if self.pending.len() > Self::MAX_PENDING => self.pending.len(),
            None => return Vec::new(),
        };
        let done: Vec<u8> = self.pending.drain(..end).collect();
        plain_text(&String::from_utf8_lossy(&done))
            .split(['\n', '\r'])
            .map(str::trim_end)
            .filter(|l| !l.is_empty())
            .map(str::to_owned)
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn paste_mode_is_the_last_one_set() {
        assert_eq!(bracketed_paste(b"plain"), None);
        assert_eq!(bracketed_paste(b"\x1b[?2004h> "), Some(true));
        assert_eq!(bracketed_paste(b"\x1b[?2004h..\x1b[?2004l$ "), Some(false));
        assert_eq!(bracketed_paste(b"\x1b[?2004l..\x1b[?2004h"), Some(true));
        assert_eq!(typed_text("a\x1b[2Jb", true), "\x1b[200~a[2Jb\x1b[201~");
        assert_eq!(typed_text("ab", false), "ab");
    }

    #[test]
    fn drops_escapes_and_keeps_tui_lines_apart() {
        assert_eq!(
            plain_text("\x1b[1;32mok\x1b[0m\x1b]0;title\x07 \x1b[3;1Hnext\x1b[2Cword"),
            "ok \nnext word"
        );
    }

    #[test]
    fn lines_wait_for_their_end() {
        let mut lines = LineSplitter::default();
        assert!(lines.push(b"test result: \x1b[32").is_empty());
        assert_eq!(
            lines.push(b"mok\x1b[0m. 3 passed\r\n\r\nnext"),
            ["test result: ok. 3 passed"]
        );
        assert_eq!(lines.push(b"\n"), ["next"]);
    }
}
