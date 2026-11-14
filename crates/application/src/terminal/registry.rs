use std::collections::HashMap;
use std::sync::{Arc, PoisonError, RwLock};

use kumo_domain::profiles::ProfileId;
use kumo_domain::terminal::{TerminalError, TerminalId};
use tokio::sync::watch;

use super::TerminalSession;

/// Goes up when a terminal opens, closes or its shell's activity changes.
pub(super) type Changes = Arc<watch::Sender<u64>>;

/// Live and finished-but-not-closed sessions, by id, each with the profile
/// that opened it.
#[derive(Debug)]
pub(super) struct SessionRegistry {
    sessions: RwLock<HashMap<TerminalId, Entry>>,
    changes: Changes,
}

impl Default for SessionRegistry {
    fn default() -> Self {
        Self {
            sessions: RwLock::default(),
            changes: Arc::new(watch::channel(0).0),
        }
    }
}

/// Tells [`SessionRegistry::changes`]'s watchers something changed.
pub(super) fn changed(changes: &Changes) {
    changes.send_modify(|n| *n = n.wrapping_add(1));
}

#[derive(Debug)]
struct Entry {
    session: Arc<TerminalSession>,
    profile: Option<ProfileId>,
}

impl Entry {
    /// Whether a service scoped to `scope` sees it. No scope sees all.
    fn visible(&self, scope: Option<&ProfileId>) -> bool {
        scope.is_none_or(|scope| self.profile.as_ref() == Some(scope))
    }
}

impl SessionRegistry {
    pub(super) fn insert(&self, session: Arc<TerminalSession>, profile: Option<ProfileId>) {
        self.write()
            .insert(session.id().clone(), Entry { session, profile });
        changed(&self.changes);
    }

    /// Where changes to the terminals are told.
    pub(super) fn changes(&self) -> &Changes {
        &self.changes
    }

    /// The session, if `scope` sees it: another profile's is not found.
    pub(super) fn get(
        &self,
        id: &TerminalId,
        scope: Option<&ProfileId>,
    ) -> Result<Arc<TerminalSession>, TerminalError> {
        self.read()
            .get(id)
            .filter(|entry| entry.visible(scope))
            .map(|entry| Arc::clone(&entry.session))
            .ok_or_else(|| TerminalError::NotFound(id.clone()))
    }

    pub(super) fn remove(
        &self,
        id: &TerminalId,
        scope: Option<&ProfileId>,
    ) -> Result<Arc<TerminalSession>, TerminalError> {
        let mut sessions = self.write();
        if !sessions.get(id).is_some_and(|entry| entry.visible(scope)) {
            return Err(TerminalError::NotFound(id.clone()));
        }
        let removed = sessions
            .remove(id)
            .map(|entry| entry.session)
            .ok_or_else(|| TerminalError::NotFound(id.clone()));
        drop(sessions);
        changed(&self.changes);
        removed
    }

    pub(super) fn all(&self, scope: Option<&ProfileId>) -> Vec<Arc<TerminalSession>> {
        self.read()
            .values()
            .filter(|entry| entry.visible(scope))
            .map(|entry| Arc::clone(&entry.session))
            .collect()
    }

    fn read(&self) -> std::sync::RwLockReadGuard<'_, HashMap<TerminalId, Entry>> {
        self.sessions.read().unwrap_or_else(PoisonError::into_inner)
    }

    fn write(&self) -> std::sync::RwLockWriteGuard<'_, HashMap<TerminalId, Entry>> {
        self.sessions
            .write()
            .unwrap_or_else(PoisonError::into_inner)
    }
}
