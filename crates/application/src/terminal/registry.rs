use std::collections::HashMap;
use std::sync::{Arc, PoisonError, RwLock};

use kumo_domain::profiles::ProfileId;
use kumo_domain::terminal::{TerminalError, TerminalId};

use super::TerminalSession;

/// Live and finished-but-not-closed sessions, by id, each with the profile
/// that opened it.
#[derive(Debug, Default)]
pub(super) struct SessionRegistry {
    sessions: RwLock<HashMap<TerminalId, Entry>>,
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
        sessions
            .remove(id)
            .map(|entry| entry.session)
            .ok_or_else(|| TerminalError::NotFound(id.clone()))
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
