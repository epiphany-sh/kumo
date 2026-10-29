use std::sync::Arc;

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
pub struct TerminalService {
    pty: Arc<dyn PtySystem>,
    config: SessionConfig,
    registry: SessionRegistry,
}

impl std::fmt::Debug for TerminalService {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TerminalService")
            .field("config", &self.config)
            .field("registry", &self.registry)
            .finish_non_exhaustive()
    }
}

impl TerminalService {
    pub fn new(pty: Arc<dyn PtySystem>, config: SessionConfig) -> Self {
        Self {
            pty,
            config,
            registry: SessionRegistry::default(),
        }
    }

    /// Spawns the program on a new PTY. Must be called within a Tokio runtime.
    pub fn open(&self, spec: LaunchSpec) -> Result<TerminalId, TerminalError> {
        let process = self.pty.spawn(&spec)?;
        let id = TerminalId::generate();
        let session = TerminalSession::start(id.clone(), &spec, process, &self.config);
        self.registry.insert(session);
        tracing::info!(terminal = %id, program = spec.program(), "terminal opened");
        Ok(id)
    }

    /// Attaches to a session, optionally replaying buffered output first.
    pub fn attach(&self, id: &TerminalId, with_replay: bool) -> Result<Attachment, TerminalError> {
        let session = self.registry.get(id)?;
        let output = session.subscribe(with_replay);
        Ok(Attachment { session, output })
    }

    /// Kills the process (if running) and forgets the session.
    pub fn close(&self, id: &TerminalId) -> Result<(), TerminalError> {
        let session = self.registry.remove(id)?;
        session.kill()?;
        tracing::info!(terminal = %id, "terminal closed");
        Ok(())
    }

    /// All sessions, oldest first.
    pub fn list(&self) -> Vec<TerminalInfo> {
        let mut infos: Vec<_> = self.registry.all().iter().map(|s| s.info()).collect();
        infos.sort_by_key(|info| info.opened_at);
        infos
    }

    /// Sessions whose process is still alive.
    pub fn running(&self) -> usize {
        self.registry
            .all()
            .iter()
            .filter(|s| matches!(s.info().status, TerminalStatus::Running))
            .count()
    }

    /// Kills every session. Used when the daemon shuts down.
    pub fn close_all(&self) {
        for session in self.registry.all() {
            if let Err(error) = self.close(session.id()) {
                tracing::warn!(terminal = %session.id(), %error, "failed to close terminal");
            }
        }
    }
}
