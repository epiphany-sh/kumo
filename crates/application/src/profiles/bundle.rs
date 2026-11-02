use std::path::PathBuf;
use std::sync::Arc;

use futures::future::BoxFuture;
use kumo_domain::agents::AgentState;
use kumo_domain::pipelines::PipelinesError;
use kumo_domain::profiles::{
    GhAccount, Profile, ProfileActivity, ProfileChanges, ProfileError, ProfileId,
};
use kumo_domain::terminal::TerminalId;
use kumo_domain::workspace::WorktreeLocation;
use tokio::sync::broadcast::error::RecvError;

use super::{GitEnvironment, ProfileBundle, ProfileService};
use crate::agents::AgentService;
use crate::changes::ChangesService;
use crate::docs::DocsService;
use crate::pipelines::{GitCredential, PipelinesService};
use crate::pulls::PullRequestService;
use crate::tasks::TaskService;
use crate::terminal::TerminalService;
use crate::test_runs::TestService;
use crate::workspace::WorkspaceService;

/// Every per-profile use case, over that profile's stores.
#[derive(Debug, Clone)]
pub struct ProfileServices {
    /// The user's home, for `~/` in the worktrees folder.
    pub home: PathBuf,
    pub workspace: Arc<WorkspaceService>,
    pub changes: Arc<ChangesService>,
    pub agents: Arc<AgentService>,
    pub tasks: Arc<TaskService>,
    pub pipelines: Arc<PipelinesService>,
    pub pulls: Arc<PullRequestService>,
    pub docs: Arc<DocsService>,
    pub tests: Arc<TestService>,
    /// The daemon's terminals, scoped to this profile.
    pub terminals: Arc<TerminalService>,
    /// What its git, terminals and agents get.
    pub git: Arc<GitEnvironment>,
}

impl ProfileBundle for ProfileServices {
    fn activity(&self) -> ProfileActivity {
        let mut activity = ProfileActivity::default();
        for session in self.agents.sessions() {
            match session.state {
                AgentState::Working => activity.agents_running += 1,
                AgentState::NeedsInput => activity.agents_waiting += 1,
                AgentState::Exited(_) => {}
            }
        }
        let snapshot = self.workspace.watch().borrow().clone();
        activity.namespaces = count(snapshot.namespaces.len());
        activity.repos = count(snapshot.repos.len());
        activity.terminals_open = count(self.terminals.running());
        activity
    }

    fn configure(&self, profile: &Profile) {
        self.git.configure(profile);
        match WorktreeLocation::new(&self.home).with_root(&profile.worktrees_dir) {
            Ok(location) => self.workspace.set_location(location),
            Err(error) => tracing::warn!(
                profile = %profile.id,
                %error,
                "worktrees folder ignored"
            ),
        }
    }

    fn close(&self) -> BoxFuture<'_, ()> {
        Box::pin(async move {
            for session in self.agents.sessions() {
                if !matches!(session.state, AgentState::Exited(_)) {
                    let _ = self.agents.stop(&session.id);
                }
            }
            self.terminals.close_all();
        })
    }

    fn copy_agents_from<'a>(&'a self, source: &'a Self) -> BoxFuture<'a, Result<(), ProfileError>> {
        Box::pin(async move {
            self.agents
                .copy_providers_from(&source.agents)
                .await
                .map_err(|e| ProfileError::Storage(e.to_string()))
        })
    }
}

fn count(n: usize) -> u32 {
    u32::try_from(n).unwrap_or(u32::MAX)
}

impl ProfileService<ProfileServices> {
    /// Opens a terminal signing `gh` in to `host` for the profile `id`
    /// names. The account it signs in becomes the profile's account on that
    /// host; `gh`'s active account stays what it was. The outer error is
    /// the profile's, the inner one the sign-in's.
    pub async fn sign_in_with_gh(
        self: &Arc<Self>,
        id: Option<&str>,
        host: &str,
    ) -> Result<Result<TerminalId, PipelinesError>, ProfileError> {
        let profile = self.find_profile(id)?;
        let bundle = self.resolve(Some(profile.id.as_str())).await?;
        let mut signed_in = bundle.pipelines.signed_in();
        let terminal = match bundle.pipelines.sign_in_with_cli(host).await {
            Ok(terminal) => terminal,
            Err(error) => return Ok(Err(error)),
        };
        let (service, host) = (Arc::clone(self), host.to_owned());
        tokio::spawn(async move {
            loop {
                match signed_in.recv().await {
                    Ok((h, login)) if h == host && !login.is_empty() => {
                        service.adopt_gh_account(&profile.id, &h, &login).await;
                        return;
                    }
                    Ok(_) | Err(RecvError::Lagged(_)) => {}
                    Err(RecvError::Closed) => return,
                }
            }
        });
        Ok(Ok(terminal))
    }

    /// Makes `login` the profile's account on `host`.
    async fn adopt_gh_account(&self, id: &ProfileId, host: &str, login: &str) {
        let Ok(profile) = self.find_profile(Some(id.as_str())) else {
            return;
        };
        let mut accounts: Vec<GhAccount> = profile
            .gh_accounts
            .into_iter()
            .filter(|a| !a.host.eq_ignore_ascii_case(host))
            .collect();
        accounts.push(GhAccount::new(host, login));
        let changes = ProfileChanges {
            gh_accounts: Some(accounts),
            ..ProfileChanges::default()
        };
        match self.update(id.as_str(), changes).await {
            Ok(_) => tracing::info!(profile = %id, host, login, "gh account added"),
            Err(error) => tracing::warn!(profile = %id, %error, "gh account not saved"),
        }
    }

    /// What `kumod git-credential` hands git for `host`, as the profile
    /// `id` names. Only hosts of that profile's remotes. Never logged.
    pub async fn git_credential(
        &self,
        id: Option<&str>,
        host: &str,
    ) -> Result<Option<GitCredential>, ProfileError> {
        let bundle = self.resolve(id).await?;
        bundle
            .pipelines
            .git_credential(host)
            .await
            .map_err(|e| match e {
                PipelinesError::UnknownHost(host) => ProfileError::UnknownHost(host),
                other => ProfileError::Storage(other.to_string()),
            })
    }
}
