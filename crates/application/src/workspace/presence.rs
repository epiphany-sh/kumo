//! Whether the user can see the app, as its clients (UI windows) tell it.
//!
//! The daemon outlives its clients, so a presence must not outlive the
//! client that reported it: a UI minimized, then quit or crashed, would
//! otherwise leave refreshes paused until the next focus change. A client
//! counts only while it watches the workspace (holds a [`ClientLease`]);
//! its presence goes when its last watch ends. Several clients combine:
//! visible if any is, focused if any is. A watching client that hasn't
//! reported yet counts as in front, and so does having no client at all
//! ([`Presence::default`]).

use std::collections::HashMap;
use std::sync::{Arc, Mutex, PoisonError};

use tokio::sync::watch;

use super::Presence;

#[derive(Debug, Default)]
struct Client {
    /// Live watches of this client (a reconnect may briefly overlap).
    watches: usize,
    /// None until it reports one.
    presence: Option<Presence>,
}

#[derive(Debug)]
pub(super) struct Presences {
    clients: Mutex<HashMap<String, Client>>,
    combined: watch::Sender<Presence>,
}

impl Presences {
    pub fn new() -> Arc<Self> {
        Arc::new(Self {
            clients: Mutex::default(),
            combined: watch::Sender::new(Presence::default()),
        })
    }

    pub fn subscribe(&self) -> watch::Receiver<Presence> {
        self.combined.subscribe()
    }

    /// `client` watches the workspace until the lease is dropped.
    pub fn attach(self: &Arc<Self>, client: &str) -> ClientLease {
        self.update(|clients| {
            clients.entry(client.to_owned()).or_default().watches += 1;
        });
        ClientLease {
            presences: Arc::clone(self),
            client: client.to_owned(),
        }
    }

    /// Ignored for a client that doesn't watch: nothing would ever clear it.
    pub fn set(&self, client: &str, presence: Presence) {
        self.update(|clients| {
            if let Some(known) = clients.get_mut(client) {
                known.presence = Some(presence);
            }
        });
    }

    fn detach(&self, client: &str) {
        self.update(|clients| {
            if let Some(known) = clients.get_mut(client) {
                known.watches -= 1;
                if known.watches == 0 {
                    clients.remove(client);
                }
            }
        });
    }

    fn update(&self, change: impl FnOnce(&mut HashMap<String, Client>)) {
        let mut clients = self.clients.lock().unwrap_or_else(PoisonError::into_inner);
        change(&mut clients);
        let combined = combine(clients.values());
        self.combined.send_if_modified(|current| {
            let changed = *current != combined;
            *current = combined;
            changed
        });
    }
}

fn combine<'a>(clients: impl Iterator<Item = &'a Client>) -> Presence {
    let mut presences = clients.map(|c| c.presence.unwrap_or_default()).peekable();
    if presences.peek().is_none() {
        return Presence::default();
    }
    presences.fold(
        Presence {
            focused: false,
            visible: false,
        },
        |all, one| Presence {
            focused: all.focused || one.focused,
            visible: all.visible || one.visible,
        },
    )
}

/// A client watching the workspace; dropping it forgets its presence.
#[derive(Debug)]
pub struct ClientLease {
    presences: Arc<Presences>,
    client: String,
}

impl Drop for ClientLease {
    fn drop(&mut self) {
        self.presences.detach(&self.client);
    }
}
