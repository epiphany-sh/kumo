use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, PoisonError};
use std::time::Duration;

use bytes::Bytes;
use kumo_domain::agents::{
    AgentContext, AgentError, AgentEventKind, AgentPreset, AgentProvider, AgentSession,
    AgentSessionId, AgentState, AgentStore, PRESETS, PlanUsage, PlanUsageStore, ProgramLocator,
    StoredProvider, UsageReport, UsageSource, UsageTarget,
};
use kumo_domain::terminal::{LaunchSpec, TerminalError, TerminalId, TerminalSize};
use kumo_domain::time::Timestamp;
use tokio::sync::watch;

use super::monitor;
use super::usage::{self, UsageState};
use crate::terminal::TerminalService;
use crate::workspace::WorkspaceService;

/// Silence after which a running agent is considered to wait for input.
const QUIET_AFTER: Duration = Duration::from_millis(2500);

#[derive(Clone)]
pub struct AgentPorts {
    pub store: Arc<dyn AgentStore>,
    pub locator: Arc<dyn ProgramLocator>,
    /// Where the CLIs that report their usage report it.
    pub usage: Vec<Arc<dyn UsageSource>>,
    pub plans: Arc<dyn PlanUsageStore>,
}

impl std::fmt::Debug for AgentPorts {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("AgentPorts").finish_non_exhaustive()
    }
}

/// A provider and where its program is, if installed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProviderView {
    pub provider: AgentProvider,
    pub resolved: Option<PathBuf>,
}

/// What the user sets for a provider in Settings › AI agents.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProviderSettings {
    pub name: String,
    pub program: String,
    pub args: String,
    pub enabled: bool,
    pub is_default: bool,
    /// None: unchanged (on for a new provider).
    pub read_usage: Option<bool>,
}

/// Every agent session, pushed whole on each change.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct AgentsSnapshot {
    pub version: u64,
    pub sessions: Vec<AgentSession>,
}

/// Coding agents: providers (known CLIs and custom commands) and the
/// sessions they run, each in its own terminal inside a worktree.
#[derive(Debug)]
pub struct AgentService {
    ports: AgentPorts,
    terminals: Arc<TerminalService>,
    workspace: Arc<WorkspaceService>,
    sessions: Mutex<AgentsSnapshot>,
    published: watch::Sender<Arc<AgentsSnapshot>>,
    usage: Mutex<UsageState>,
    quiet_after: Duration,
}

impl AgentService {
    pub fn new(
        ports: AgentPorts,
        terminals: Arc<TerminalService>,
        workspace: Arc<WorkspaceService>,
    ) -> Self {
        let (published, _) = watch::channel(Arc::new(AgentsSnapshot::default()));
        Self {
            ports,
            terminals,
            workspace,
            sessions: Mutex::new(AgentsSnapshot::default()),
            published,
            usage: Mutex::default(),
            quiet_after: QUIET_AFTER,
        }
    }

    // ---- Providers ----

    /// Known CLIs (with the user's settings) followed by custom agents.
    pub async fn providers(&self) -> Result<Vec<ProviderView>, AgentError> {
        let (store, locator) = (
            Arc::clone(&self.ports.store),
            Arc::clone(&self.ports.locator),
        );
        blocking(move || {
            let providers = merge(store.load()?);
            Ok(providers
                .into_iter()
                .map(|provider| {
                    let resolved = locator.locate(&provider.program);
                    ProviderView { provider, resolved }
                })
                .collect())
        })
        .await
    }

    /// Copies `source`'s provider rows (program, args, settings) into this
    /// service's store, replacing rows with the same id. Nothing else is
    /// copied: sign-ins and sessions stay where they are.
    pub async fn copy_providers_from(&self, source: &AgentService) -> Result<(), AgentError> {
        let (from, to) = (
            Arc::clone(&source.ports.store),
            Arc::clone(&self.ports.store),
        );
        blocking(move || from.load()?.iter().try_for_each(|p| to.save(p))).await
    }

    /// Creates (`id` None: a custom agent) or updates a provider.
    pub async fn save_provider(
        &self,
        id: Option<String>,
        settings: ProviderSettings,
    ) -> Result<ProviderView, AgentError> {
        let ProviderSettings {
            name,
            program,
            args,
            enabled,
            is_default,
            read_usage,
        } = settings;
        let current = match &id {
            Some(id) => Some(self.provider(id).await?),
            None => None,
        };
        let provider = match current {
            Some(current) => AgentProvider {
                name: if current.custom {
                    name.trim().to_owned()
                } else {
                    current.name
                },
                short: if current.custom {
                    AgentProvider::badge_for(&name)
                } else {
                    current.short
                },
                program: program.trim().to_owned(),
                args: args.trim().to_owned(),
                enabled,
                is_default: is_default && enabled,
                read_usage: read_usage.unwrap_or(current.read_usage),
                ..current
            },
            None => AgentProvider {
                id: uuid_like(),
                name: name.trim().to_owned(),
                short: AgentProvider::badge_for(&name),
                program: program.trim().to_owned(),
                args: args.trim().to_owned(),
                custom: true,
                enabled,
                is_default: is_default && enabled,
                read_usage: read_usage.unwrap_or(true),
                preset: None,
            },
        };
        provider.validate()?;
        let stored = StoredProvider {
            id: provider.id.clone(),
            name: provider.name.clone(),
            program: provider.program.clone(),
            args: provider.args.clone(),
            custom: provider.custom,
            enabled: provider.enabled,
            is_default: provider.is_default,
            read_usage: provider.read_usage,
        };
        let store = Arc::clone(&self.ports.store);
        blocking(move || store.save(&stored)).await?;
        // As the list shows it (e.g. the default may be implied).
        let id = provider.id;
        self.providers()
            .await?
            .into_iter()
            .find(|view| view.provider.id == id)
            .ok_or(AgentError::UnknownProvider(id))
    }

    /// Removes a custom agent. Known CLIs can only be disconnected.
    pub async fn delete_provider(&self, id: &str) -> Result<(), AgentError> {
        let provider = self.provider(id).await?;
        if !provider.custom {
            return Err(AgentError::Invalid(format!(
                "{} is built in: disconnect it instead",
                provider.name
            )));
        }
        let (store, id) = (Arc::clone(&self.ports.store), id.to_owned());
        blocking(move || store.delete(&id)).await
    }

    /// `<program> --version`.
    pub async fn test_provider(&self, id: &str) -> Result<String, AgentError> {
        let program = self.installed(&self.provider(id).await?).await?;
        let locator = Arc::clone(&self.ports.locator);
        blocking(move || locator.version(&program)).await
    }

    /// Opens a terminal running the CLI's own sign-in, in the home folder.
    pub async fn login(&self, id: &str) -> Result<TerminalId, AgentError> {
        let provider = self.provider(id).await?;
        let program = self.installed(&provider).await?;
        let spec = LaunchSpec::new(program.display().to_string())
            .map_err(launch_error)?
            .with_args(provider.login_args())
            .with_cwd(Some(self.ports.locator.home()))
            .with_env([("PATH".to_owned(), self.ports.locator.search_path())]);
        self.terminals.open(spec).map_err(launch_error)
    }

    // ---- Sessions ----

    /// Starts an agent in a worktree of the workspace, in a new terminal.
    /// `provider_id` None uses the default agent; `context` is what the
    /// prompt hands it (a ticket, a page), for the record.
    pub async fn start(
        self: &Arc<Self>,
        provider_id: Option<&str>,
        worktree: &Path,
        prompt: &str,
        title: &str,
        context: Vec<AgentContext>,
        size: TerminalSize,
    ) -> Result<AgentSession, AgentError> {
        let provider = match provider_id {
            Some(id) => self.provider(id).await?,
            None => self.default_provider().await?,
        };
        if !provider.enabled {
            return Err(AgentError::Invalid(format!(
                "connect {} in Settings › AI agents first",
                provider.name
            )));
        }
        let worktree = self
            .workspace
            .known_worktree(worktree)
            .await
            .ok_or_else(|| AgentError::UnknownWorktree(worktree.into()))?;
        let program = self.installed(&provider).await?;
        let (mut args, prompt_passed) = provider.launch_args(prompt)?;
        let id = AgentSessionId::generate();
        // Before it starts: a session's files are matched by start time.
        let target = UsageTarget {
            session_id: id.clone(),
            worktree: worktree.clone(),
            started_at: Timestamp::now(),
        };
        let source = self.usage_source(&provider);
        if let Some(source) = &source {
            args = usage::launch_args(source, &target, args).await;
        }
        let spec = LaunchSpec::new(program.display().to_string())
            .map_err(launch_error)?
            .with_args(args)
            .with_cwd(Some(worktree.clone()))
            .with_env([("PATH".to_owned(), self.ports.locator.search_path())])
            .with_size(size);
        let terminal = self.terminals.open(spec).map_err(launch_error)?;
        let attachment = self
            .terminals
            .attach(&terminal, false)
            .map_err(launch_error)?;

        let now = Timestamp::now();
        let mut session = AgentSession {
            id,
            provider_id: provider.id.clone(),
            provider_name: provider.name.clone(),
            short: provider.short.clone(),
            worktree,
            terminal,
            title: AgentSession::title_for(title, prompt, &provider.name),
            prompt: prompt.to_owned(),
            state: AgentState::Working,
            started_at: now,
            state_since: now,
            last_line: String::new(),
            context: Vec::new(),
            events: Vec::new(),
        };
        session.record(AgentEventKind::Started, provider.name.clone(), now);
        for item in context {
            session.record(AgentEventKind::Context, item.title.clone(), now);
            session.context.push(item);
        }
        self.update(|snapshot| snapshot.sessions.push(session.clone()));
        tracing::info!(agent = provider.id, session = %session.id, worktree = %session.worktree.display(), "agent started");

        // CLIs that don't take the prompt as an argument get it typed in.
        let typed = (!prompt_passed && !prompt.trim().is_empty()).then(|| prompt.to_owned());
        tokio::spawn(monitor::run(
            Arc::clone(self),
            session.id.clone(),
            attachment,
            typed,
            self.quiet_after,
        ));
        if let Some(source) = source {
            self.usage_lock().follow(target.clone());
            tokio::spawn(usage::follow(Arc::clone(self), target, source));
        }
        Ok(session)
    }

    /// Sends a ticket or page to a running agent: `text` is typed into its
    /// terminal and submitted, and `context` joins what it was given.
    pub async fn add_context(
        &self,
        id: &AgentSessionId,
        context: AgentContext,
        text: &str,
    ) -> Result<AgentSession, AgentError> {
        let session = self.session(id)?;
        if matches!(session.state, AgentState::Exited(_)) {
            return Err(AgentError::Invalid(format!(
                "{} already finished: start a new agent",
                session.provider_name
            )));
        }
        let text = text.trim();
        if !text.is_empty() {
            self.type_in(&session, text).await?;
        }
        self.update_session(id, |session| {
            session.record(
                AgentEventKind::Context,
                context.title.clone(),
                Timestamp::now(),
            );
            if !session.context.contains(&context) {
                session.context.push(context);
            }
        });
        self.session(id)
    }

    /// Types the agent's own compact command (`/compact`, `/compress`)
    /// into its terminal and submits it.
    pub async fn compact(&self, id: &AgentSessionId) -> Result<AgentSession, AgentError> {
        let session = self.session(id)?;
        if matches!(session.state, AgentState::Exited(_)) {
            return Err(AgentError::Invalid(format!(
                "{} already finished",
                session.provider_name
            )));
        }
        let command = self
            .provider(&session.provider_id)
            .await?
            .compact_command()
            .ok_or_else(|| {
                AgentError::Invalid(format!(
                    "{} has no command to compact its context",
                    session.provider_name
                ))
            })?;
        self.type_in(&session, command).await?;
        self.session(id)
    }

    /// What's left on each connected agent's plan and how full each
    /// session's context is, as last read. Empty when nothing is readable.
    pub async fn usage(&self) -> Result<UsageReport, AgentError> {
        self.load_plans().await;
        let providers = self.providers().await?;
        let sessions = self.sessions();
        Ok(self
            .usage_lock()
            .report(&providers, &sessions, Timestamp::now()))
    }

    /// Types `text` into the agent's terminal and submits it. Several
    /// lines go as one paste (agent TUIs read bracketed paste); then it's
    /// submitted on its own, as a person would.
    async fn type_in(&self, session: &AgentSession, text: &str) -> Result<(), AgentError> {
        let attachment = self
            .terminals
            .attach(&session.terminal, false)
            .map_err(launch_error)?;
        let text = text.replace('\x1b', "");
        let typed = if text.contains('\n') {
            format!("\x1b[200~{text}\x1b[201~")
        } else {
            text
        };
        attachment
            .session
            .write(Bytes::from(typed))
            .await
            .map_err(launch_error)?;
        tokio::time::sleep(Duration::from_millis(80)).await;
        attachment
            .session
            .write(Bytes::from_static(b"\r"))
            .await
            .map_err(launch_error)
    }

    /// Kills the agent's process; its session ends as exited.
    pub fn stop(&self, id: &AgentSessionId) -> Result<(), AgentError> {
        let terminal = self.session(id)?.terminal;
        match self.terminals.close(&terminal) {
            Ok(()) | Err(TerminalError::NotFound(_)) => Ok(()),
            Err(e) => Err(launch_error(e)),
        }
    }

    /// Forgets a finished session (a running one is stopped first).
    pub fn dismiss(&self, id: &AgentSessionId) -> Result<(), AgentError> {
        let session = self.session(id)?;
        let _ = self.terminals.close(&session.terminal);
        self.update(|snapshot| snapshot.sessions.retain(|s| &s.id != id));
        if let Some(target) = self.usage_lock().forget(id)
            && let Some(source) = self
                .ports
                .usage
                .iter()
                .find(|s| s.provider_id() == session.provider_id)
                .cloned()
        {
            tokio::task::spawn_blocking(move || source.forget(&target));
        }
        Ok(())
    }

    pub fn watch(&self) -> watch::Receiver<Arc<AgentsSnapshot>> {
        self.published.subscribe()
    }

    pub fn sessions(&self) -> Vec<AgentSession> {
        self.lock().sessions.clone()
    }

    /// Applies a change to one session and publishes.
    pub(super) fn update_session(
        &self,
        id: &AgentSessionId,
        change: impl FnOnce(&mut AgentSession),
    ) {
        self.update(|snapshot| {
            if let Some(session) = snapshot.sessions.iter_mut().find(|s| &s.id == id) {
                change(session);
            }
        });
    }

    fn update(&self, change: impl FnOnce(&mut AgentsSnapshot)) {
        let snapshot = {
            let mut snapshot = self.lock();
            change(&mut snapshot);
            snapshot.version += 1;
            snapshot.clone()
        };
        self.published.send_replace(Arc::new(snapshot));
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, AgentsSnapshot> {
        self.sessions.lock().unwrap_or_else(PoisonError::into_inner)
    }

    pub(super) fn usage_lock(&self) -> std::sync::MutexGuard<'_, UsageState> {
        self.usage.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// The session's state; None once dismissed.
    pub(super) fn state_of(&self, id: &AgentSessionId) -> Option<AgentState> {
        self.lock()
            .sessions
            .iter()
            .find(|s| &s.id == id)
            .map(|s| s.state)
    }

    /// Where `provider`'s usage is read, when it reports it and that's on.
    fn usage_source(&self, provider: &AgentProvider) -> Option<Arc<dyn UsageSource>> {
        if !provider.reads_usage() {
            return None;
        }
        self.ports
            .usage
            .iter()
            .find(|s| s.provider_id() == provider.id)
            .cloned()
    }

    /// The plan readings kept from earlier runs, once.
    async fn load_plans(&self) {
        if self.usage_lock().plans_loaded() {
            return;
        }
        let plans = Arc::clone(&self.ports.plans);
        match blocking(move || plans.load_plans()).await {
            Ok(saved) => self.usage_lock().restore(saved),
            Err(e) => tracing::warn!(error = %e, "can't read the saved plan usage"),
        }
    }

    /// Keeps a plan reading for its provider, here and across restarts.
    pub(super) async fn save_plan(&self, plan: PlanUsage) {
        let plans = Arc::clone(&self.ports.plans);
        if let Err(e) = blocking(move || plans.save_plan(&plan)).await {
            tracing::warn!(error = %e, "can't save the plan usage");
        }
    }

    fn session(&self, id: &AgentSessionId) -> Result<AgentSession, AgentError> {
        self.lock()
            .sessions
            .iter()
            .find(|s| &s.id == id)
            .cloned()
            .ok_or_else(|| AgentError::UnknownSession(id.to_string()))
    }

    async fn provider(&self, id: &str) -> Result<AgentProvider, AgentError> {
        let store = Arc::clone(&self.ports.store);
        let providers = blocking(move || Ok(merge(store.load()?))).await?;
        providers
            .into_iter()
            .find(|p| p.id == id)
            .ok_or_else(|| AgentError::UnknownProvider(id.to_owned()))
    }

    async fn default_provider(&self) -> Result<AgentProvider, AgentError> {
        let store = Arc::clone(&self.ports.store);
        let providers = blocking(move || Ok(merge(store.load()?))).await?;
        providers
            .into_iter()
            .find(|p| p.enabled && p.is_default)
            .ok_or(AgentError::NoProvider)
    }

    async fn installed(&self, provider: &AgentProvider) -> Result<PathBuf, AgentError> {
        let (locator, program) = (Arc::clone(&self.ports.locator), provider.program.clone());
        blocking(move || {
            locator
                .locate(&program)
                .ok_or(AgentError::NotInstalled(program))
        })
        .await
    }
}

/// Known CLIs with the saved overrides, then custom agents. When no
/// connected provider is marked default, the first connected one is.
fn merge(stored: Vec<StoredProvider>) -> Vec<AgentProvider> {
    let mut providers: Vec<AgentProvider> =
        PRESETS.iter().map(AgentProvider::from_preset).collect();
    for saved in &stored {
        if let Some(known) = providers
            .iter_mut()
            .find(|p| !saved.custom && p.id == saved.id)
        {
            known.program = saved.program.clone();
            known.args = saved.args.clone();
            known.enabled = saved.enabled;
            known.is_default = saved.is_default && saved.enabled;
            known.read_usage = saved.read_usage;
        }
    }
    providers.extend(
        stored
            .into_iter()
            .filter(|s| s.custom && AgentPreset::find(&s.id).is_none())
            .map(|s| AgentProvider {
                short: AgentProvider::badge_for(&s.name),
                id: s.id,
                name: s.name,
                program: s.program,
                args: s.args,
                custom: true,
                enabled: s.enabled,
                is_default: s.is_default && s.enabled,
                read_usage: s.read_usage,
                preset: None,
            }),
    );
    if !providers.iter().any(|p| p.is_default)
        && let Some(first) = providers.iter_mut().find(|p| p.enabled)
    {
        first.is_default = true;
    }
    providers
}

fn uuid_like() -> String {
    AgentSessionId::generate().to_string()
}

fn launch_error(error: TerminalError) -> AgentError {
    AgentError::Launch(error.to_string())
}

async fn blocking<T: Send + 'static>(
    f: impl FnOnce() -> Result<T, AgentError> + Send + 'static,
) -> Result<T, AgentError> {
    tokio::task::spawn_blocking(f)
        .await
        .map_err(|e| AgentError::Launch(format!("blocking task failed: {e}")))?
}

#[cfg(test)]
mod tests {
    use super::*;

    fn stored(id: &str, custom: bool, enabled: bool, default: bool) -> StoredProvider {
        StoredProvider {
            id: id.into(),
            name: format!("{id} agent"),
            program: id.into(),
            args: String::new(),
            custom,
            enabled,
            is_default: default,
            read_usage: true,
        }
    }

    #[test]
    fn merges_presets_with_settings_and_customs() {
        let providers = merge(vec![
            stored("codex", false, true, false),
            stored("mine", true, true, false),
        ]);
        assert_eq!(providers.len(), PRESETS.len() + 1);
        let codex = providers.iter().find(|p| p.id == "codex").unwrap();
        assert!(
            codex.enabled && codex.is_default,
            "first connected one becomes the default"
        );
        let mine = providers.last().unwrap();
        assert!(mine.custom && !mine.is_default);
        assert_eq!(mine.short, "MA");
    }

    #[test]
    fn a_disconnected_provider_is_never_the_default() {
        let providers = merge(vec![
            stored("claude", false, false, true),
            stored("gemini", false, true, false),
        ]);
        let defaults: Vec<_> = providers
            .iter()
            .filter(|p| p.is_default)
            .map(|p| p.id.as_str())
            .collect();
        assert_eq!(defaults, vec!["gemini"]);
    }
}
