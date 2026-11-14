use std::sync::Arc;

use kumo_domain::profiles::{ProfileEnv, ProfileId};
use kumo_domain::terminal::{
    CommandMarks, LaunchSpec, NoShellIntegration, PtySystem, ShellIntegration, TerminalActivity,
    TerminalError, TerminalId, TerminalInfo, TerminalStatus,
};
use tokio::sync::watch;

use super::registry::SessionRegistry;
use super::session::Recorder;
use super::{CommandHistory, RepoHistory, SessionConfig, Subscription, TerminalSession};

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
    /// What [`Self::open_shell`] adds to the user's shell.
    shells: Arc<dyn ShellIntegration>,
    config: SessionConfig,
    registry: Arc<SessionRegistry>,
    scope: Option<ProfileId>,
    /// What the profile's processes get (git identity, credentials, key).
    env: ProfileEnv,
    /// Where the profile's shells' commands are remembered.
    history: Option<CommandHistory>,
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
            shells: Arc::new(NoShellIntegration),
            config,
            registry: Arc::default(),
            scope: None,
            env: ProfileEnv::default(),
            history: None,
        }
    }

    /// Shells opened with [`Self::open_shell`] get `shells`.
    pub fn with_shell_integration(mut self, shells: Arc<dyn ShellIntegration>) -> Self {
        self.shells = shells;
        self
    }

    /// The same terminals, seen from `profile`: what it opens is tagged
    /// with it and gets `env` (under the variables it sets itself), and
    /// other profiles' terminals are not found.
    pub fn scoped(&self, profile: ProfileId, env: ProfileEnv) -> Self {
        Self {
            pty: Arc::clone(&self.pty),
            shells: Arc::clone(&self.shells),
            config: self.config.clone(),
            registry: Arc::clone(&self.registry),
            scope: Some(profile),
            env,
            history: None,
        }
    }

    /// Shells opened with [`Self::open_shell`] remember their commands in
    /// `history`.
    pub fn with_history(mut self, history: CommandHistory) -> Self {
        self.history = Some(history);
        self
    }

    /// The profile this service is scoped to; None sees every terminal.
    pub fn scope(&self) -> Option<&ProfileId> {
        self.scope.as_ref()
    }

    /// Spawns the program on a new PTY. Must be called within a Tokio runtime.
    pub fn open(&self, spec: LaunchSpec) -> Result<TerminalId, TerminalError> {
        self.spawn(spec, None)
    }

    fn spawn(
        &self,
        spec: LaunchSpec,
        recorder: Option<Recorder>,
    ) -> Result<TerminalId, TerminalError> {
        let spec = spec.with_default_env(self.env.get().env());
        let process = self.pty.spawn(&spec)?;
        let id = TerminalId::generate();
        let session = TerminalSession::start(id.clone(), &spec, process, &self.config, recorder);
        self.registry.insert(session, self.scope.clone());
        tracing::info!(terminal = %id, program = spec.program(), "terminal opened");
        Ok(id)
    }

    /// Like [`Self::open`], for the user's interactive shell: it reports
    /// its prompts and commands (see [`ShellIntegration`]), and the ones it
    /// runs are remembered when `remember` (see [`Self::history`]).
    pub fn open_shell(
        &self,
        spec: LaunchSpec,
        remember: bool,
    ) -> Result<TerminalId, TerminalError> {
        // Fresh for each shell: its command lines are signed with it.
        let nonce = TerminalId::generate().to_string();
        let spec = self.shells.apply(spec, &nonce);
        let recorder = Recorder::new(
            CommandMarks::new(nonce),
            self.history.clone().filter(|_| remember),
        )
        .telling(Arc::clone(self.registry.changes()));
        self.spawn(spec, Some(recorder))
    }

    /// The commands remembered for the repository the terminal's shell is
    /// in (what it ran outside one, elsewhere), last run first, and the
    /// folder it's in.
    pub async fn history(
        &self,
        id: &TerminalId,
        limit: usize,
    ) -> Result<(RepoHistory, Option<std::path::PathBuf>), TerminalError> {
        let cwd = self.registry.get(id, self.scope.as_ref())?.current_dir();
        let Some(history) = self.history.clone() else {
            return Ok((
                RepoHistory {
                    repo: None,
                    entries: Vec::new(),
                },
                cwd,
            ));
        };
        let dir = cwd.clone();
        let found = blocking(move || history.recent(dir.as_deref(), limit)).await?;
        Ok((found, cwd))
    }

    /// Forgets the commands of the repository the terminal's shell is in,
    /// or every command when `everything`. Returns how many.
    pub async fn forget_history(
        &self,
        id: Option<&TerminalId>,
        everything: bool,
    ) -> Result<usize, TerminalError> {
        let cwd = match id {
            Some(id) => self.registry.get(id, self.scope.as_ref())?.current_dir(),
            None => None,
        };
        let Some(history) = self.history.clone() else {
            return Ok(0);
        };
        blocking(move || {
            if everything {
                history.forget_all()
            } else {
                history.forget(cwd.as_deref())
            }
        })
        .await
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

    /// Like [`Self::close`], and what it started goes too (an agent's tools).
    pub fn close_tree(&self, id: &TerminalId) -> Result<(), TerminalError> {
        let session = self.registry.remove(id, self.scope.as_ref())?;
        session.kill_tree()?;
        tracing::info!(terminal = %id, "terminal closed with what it started");
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

    /// What each shell it sees is doing (programs that aren't shells with
    /// Kumo's integration are left out), oldest first.
    pub fn activity(&self) -> Vec<TerminalActivity> {
        let mut shells: Vec<_> = self
            .registry
            .all(self.scope.as_ref())
            .into_iter()
            .filter_map(|session| {
                let activity = session.shell_activity()?;
                Some((
                    session.info().opened_at,
                    TerminalActivity {
                        id: session.id().clone(),
                        cwd: session.current_dir(),
                        activity,
                    },
                ))
            })
            .collect();
        shells.sort_by_key(|(opened_at, _)| *opened_at);
        shells.into_iter().map(|(_, shell)| shell).collect()
    }

    /// Changes when a terminal opens or closes, or a shell's activity
    /// changes: read [`Self::activity`] again then. Shared by every scope.
    pub fn activity_changes(&self) -> watch::Receiver<u64> {
        self.registry.changes().subscribe()
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

/// Runs a store call off the async threads.
async fn blocking<T: Send + 'static>(
    call: impl FnOnce() -> Result<T, kumo_domain::terminal::HistoryError> + Send + 'static,
) -> Result<T, TerminalError> {
    tokio::task::spawn_blocking(call)
        .await
        .map_err(|e| TerminalError::Io(e.to_string()))?
        .map_err(TerminalError::from)
}
