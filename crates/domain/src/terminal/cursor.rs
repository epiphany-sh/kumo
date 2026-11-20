//! The terminal's "where is the cursor?" request (DSR 6, `ESC[6n`), found
//! in output read in pieces.

/// What a program (or ConPTY, first thing) asks the terminal.
pub const CURSOR_REQUEST: &[u8] = b"\x1b[6n";

/// Finds the cursor requests in output read in pieces, a request split
/// between two included.
#[derive(Debug, Default, Clone)]
pub struct CursorRequests {
    /// The start of a request the last piece ended with.
    held: Vec<u8>,
}

/// A piece of output without its whole requests.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Stripped {
    pub output: Vec<u8>,
    /// How many requests were taken out.
    pub requests: usize,
}

impl CursorRequests {
    pub fn new() -> Self {
        Self::default()
    }

    /// `data` (after what the last piece held back) with its requests
    /// taken out and counted. The start of a request at its end is held
    /// back until the next piece says whether it is one.
    pub fn strip(&mut self, data: &[u8]) -> Stripped {
        let mut input = std::mem::take(&mut self.held);
        input.extend_from_slice(data);
        let mut output = Vec::with_capacity(input.len());
        let mut requests = 0;
        let mut i = 0;
        while i < input.len() {
            let rest = &input[i..];
            if rest.starts_with(CURSOR_REQUEST) {
                requests += 1;
                i += CURSOR_REQUEST.len();
            } else if rest.len() < CURSOR_REQUEST.len() && CURSOR_REQUEST.starts_with(rest) {
                self.held = rest.to_vec();
                break;
            } else {
                output.push(input[i]);
                i += 1;
            }
        }
        Stripped { output, requests }
    }

    /// What's held back, given up: the output it belongs to, as it was.
    pub fn release(&mut self) -> Vec<u8> {
        std::mem::take(&mut self.held)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn stripped(output: &[u8], requests: usize) -> Stripped {
        Stripped {
            output: output.to_vec(),
            requests,
        }
    }

    #[test]
    fn takes_out_whole_requests() {
        let mut found = CursorRequests::new();
        assert_eq!(found.strip(b"a\x1b[6nb\x1b[6n"), stripped(b"ab", 2));
        assert_eq!(
            found.strip(b"\x1b[5n\x1b[16n"),
            stripped(b"\x1b[5n\x1b[16n", 0)
        );
    }

    #[test]
    fn a_request_split_between_pieces_is_found() {
        let mut found = CursorRequests::new();
        assert_eq!(found.strip(b"x\x1b"), stripped(b"x", 0));
        assert_eq!(found.strip(b"["), stripped(b"", 0));
        assert_eq!(found.strip(b"6ny"), stripped(b"y", 1));
        // Not one after all: given back.
        assert_eq!(found.strip(b"\x1b[6"), stripped(b"", 0));
        assert_eq!(found.strip(b"5m"), stripped(b"\x1b[65m", 0));
    }

    #[test]
    fn what_is_held_back_can_be_given_up() {
        let mut found = CursorRequests::new();
        assert_eq!(found.strip(b"a\x1b["), stripped(b"a", 0));
        assert_eq!(found.release(), b"\x1b[");
        assert_eq!(found.strip(b"6n"), stripped(b"6n", 0));
    }
}
