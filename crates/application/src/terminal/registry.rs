use std::collections::HashMap;
use std::sync::{Arc, PoisonError, RwLock};

use kumo_domain::terminal::{TerminalError, TerminalId};

use super::TerminalSession;

/// Live and finished-but-not-closed sessions, by id.
#[derive(Debug, Default)]
pub(super) struct SessionRegistry {
    sessions: RwLock<HashMap<TerminalId, Arc<TerminalSession>>>,
}

impl SessionRegistry {
    pub(super) fn insert(&self, session: Arc<TerminalSession>) {
        self.write().insert(session.id().clone(), session);
    }

    pub(super) fn get(&self, id: &TerminalId) -> Result<Arc<TerminalSession>, TerminalError> {
        self.read()
            .get(id)
            .cloned()
            .ok_or_else(|| TerminalError::NotFound(id.clone()))
    }

    pub(super) fn remove(&self, id: &TerminalId) -> Result<Arc<TerminalSession>, TerminalError> {
        self.write()
            .remove(id)
            .ok_or_else(|| TerminalError::NotFound(id.clone()))
    }

    pub(super) fn all(&self) -> Vec<Arc<TerminalSession>> {
        self.read().values().cloned().collect()
    }

    fn read(&self) -> std::sync::RwLockReadGuard<'_, HashMap<TerminalId, Arc<TerminalSession>>> {
        self.sessions.read().unwrap_or_else(PoisonError::into_inner)
    }

    fn write(&self) -> std::sync::RwLockWriteGuard<'_, HashMap<TerminalId, Arc<TerminalSession>>> {
        self.sessions
            .write()
            .unwrap_or_else(PoisonError::into_inner)
    }
}
