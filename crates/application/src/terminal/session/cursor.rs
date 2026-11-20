//! Answers a PTY that holds its program until the terminal says where its
//! cursor is (ConPTY asks first thing), while no client is there to say it:
//! a test run or an agent nobody watches would never start otherwise.

use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};

use bytes::Bytes;
use kumo_domain::terminal::CursorRequests;
use tokio::sync::mpsc;

/// Top left: the pseudo-console just started.
const ANSWER: &[u8] = b"\x1b[1;1R";

/// The clients attached to a session that answer for it (see
/// [`ClientGuard`]).
pub(super) type Clients = Arc<AtomicUsize>;

/// A client attached to a session: while one is, the session leaves the
/// answers to it. Dropping it detaches.
#[derive(Debug)]
pub struct ClientGuard(Clients);

impl ClientGuard {
    pub(super) fn new(clients: &Clients) -> Self {
        clients.fetch_add(1, Ordering::SeqCst);
        Self(Arc::clone(clients))
    }
}

impl Drop for ClientGuard {
    fn drop(&mut self) {
        self.0.fetch_sub(1, Ordering::SeqCst);
    }
}

/// Answers the requests in the output while no client is attached, and
/// takes them out of it: a client attaching later replays the output, and
/// would answer them again.
#[derive(Debug)]
pub(super) struct CursorAnswers {
    requests: CursorRequests,
    clients: Clients,
    input: mpsc::Sender<Bytes>,
}

impl CursorAnswers {
    pub(super) fn new(clients: Clients, input: mpsc::Sender<Bytes>) -> Self {
        Self {
            requests: CursorRequests::new(),
            clients,
            input,
        }
    }

    /// `data` as the clients get it.
    pub(super) fn filter(&mut self, data: Bytes) -> Bytes {
        if self.clients.load(Ordering::SeqCst) > 0 {
            // A client answers: everything goes through, as written.
            let mut held = self.requests.release();
            if held.is_empty() {
                return data;
            }
            held.extend_from_slice(&data);
            return held.into();
        }
        let stripped = self.requests.strip(&data);
        for _ in 0..stripped.requests {
            // Never blocks the pump: a full input queue is someone typing.
            let _ = self.input.try_send(Bytes::from_static(ANSWER));
        }
        stripped.output.into()
    }

    /// The start of a request held back at the end of the output.
    pub(super) fn release(&mut self) -> Vec<u8> {
        self.requests.release()
    }
}
