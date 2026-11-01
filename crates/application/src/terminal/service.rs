use std::sync::Arc;

use kumo_domain::profiles::ProfileId;
use kumo_domain::terminal::{
    LaunchSpec, PtySystem, TerminalError, TerminalId, TerminalInfo, TerminalStatus,
};

use super::registry::SessionRegistry;
use super::{SessionConfig, Subscription, TerminalSession};

/// A client attached to a session: a handle to drive it and its output.
#[derive(Debug)]
pub struct Attachment {
    pub session: Arc<TerminalSession>,
    pub output: Subscription,
}

/// Terminal use cases: open, attach, list and close sessions.
///
/// Terminals are processes of the whole daemon, but each remembers the
/// profile that opened it. A service scoped to a profile ([`Self::scoped`])
/// opens terminals for it and only sees those; the unscoped one sees all.
pub struct TerminalService {
    pty: Arc<dyn PtySystem>,
    config: SessionConfig,
    registry: Arc<SessionRegistry>,
    scope: Option<ProfileId>,
}

impl std::fmt::Debug for TerminalService {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TerminalService")
            .field("config", &self.config)
            .field("registry", &self.registry)
            .field("scope", &self.scope)
            .finish_non_exhaustive()
    }
}

impl TerminalService {
    pub fn new(pty: Arc<dyn PtySystem>, config: SessionConfig) -> Self {
        Self {
            pty,
            config,
            registry: Arc::default(),
            scope: None,
        }
    }

    /// The same terminals, seen from `profile`: what it opens is tagged
    /// with it, and other profiles' terminals are not found.
    pub fn scoped(&self, profile: ProfileId) -> Self {
        Self {
            pty: Arc::clone(&self.pty),
            config: self.config.clone(),
            registry: Arc::clone(&self.registry),
            scope: Some(profile),
        }
    }

    /// The profile this service is scoped to; None sees every terminal.
    pub fn scope(&self) -> Option<&ProfileId> {
        self.scope.as_ref()
    }

    /// Spawns the program on a new PTY. Must be called within a Tokio runtime.
    pub fn open(&self, spec: LaunchSpec) -> Result<TerminalId, TerminalError> {
        let process = self.pty.spawn(&spec)?;
        let id = TerminalId::generate();
        let session = TerminalSession::start(id.clone(), &spec, process, &self.config);
        self.registry.insert(session, self.scope.clone());
        tracing::info!(terminal = %id, program = spec.program(), "terminal opened");
        Ok(id)
    }

    /// Attaches to a session, optionally replaying buffered output first.
    pub fn attach(&self, id: &TerminalId, with_replay: bool) -> Result<Attachment, TerminalError> {
        let session = self.registry.get(id, self.scope.as_ref())?;
        let output = session.subscribe(with_replay);
        Ok(Attachment { session, output })
    }

    /// Kills the process (if running) and forgets the session.
    pub fn close(&self, id: &TerminalId) -> Result<(), TerminalError> {
        let session = self.registry.remove(id, self.scope.as_ref())?;
        session.kill()?;
        tracing::info!(terminal = %id, "terminal closed");
        Ok(())
    }

    /// All sessions, oldest first.
    pub fn list(&self) -> Vec<TerminalInfo> {
        let mut infos: Vec<_> = self
            .registry
            .all(self.scope.as_ref())
            .iter()
            .map(|s| s.info())
            .collect();
        infos.sort_by_key(|info| info.opened_at);
        infos
    }

    /// Sessions whose process is still alive.
    pub fn running(&self) -> usize {
        self.registry
            .all(self.scope.as_ref())
            .iter()
            .filter(|s| matches!(s.info().status, TerminalStatus::Running))
            .count()
    }

    /// Kills every session it sees: all of them when the daemon shuts
    /// down, a profile's when it's deleted.
    pub fn close_all(&self) {
        for session in self.registry.all(self.scope.as_ref()) {
            if let Err(error) = self.close(session.id()) {
                tracing::warn!(terminal = %session.id(), %error, "failed to close terminal");
            }
        }
    }
}
