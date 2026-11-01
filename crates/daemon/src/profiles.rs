//! Builds each profile's services over that profile's data folder.

use std::path::PathBuf;
use std::sync::Arc;

use futures::future::BoxFuture;
use kumo_application::agents::{AgentPorts, AgentService};
use kumo_application::changes::{ChangesPorts, ChangesService};
use kumo_application::docs::{DocsPorts, DocsService};
use kumo_application::pipelines::{PipelinesPorts, PipelinesService, PipelinesTiming};
use kumo_application::profiles::{OpenProfile, ProfileServices};
use kumo_application::pulls::{PullRequestPorts, PullRequestService};
use kumo_application::tasks::{TaskPorts, TaskService, TaskTiming};
use kumo_application::terminal::TerminalService;
use kumo_application::test_runs::{TestPorts, TestService};
use kumo_application::workspace::{WorkspacePorts, WorkspaceService};
use kumo_domain::agents::ProgramLocator;
use kumo_domain::pipelines::{HostTokens, TokenFallback};
use kumo_domain::profiles::{Profile, ProfileActivity, ProfileError};
use kumo_domain::tasks::{SecretStore, TaskConnector};
use kumo_domain::workspace::{WorkspaceStore, WorktreeLocation};
use kumo_infrastructure::agents::{ClaudeStatusLine, CodexRollouts, codex_home};
use kumo_infrastructure::ci::{
    BitbucketPipelines, BitbucketPulls, GhTokenFallback, GitHubActions, GitHubPulls, GitLabCi,
    GitLabPulls,
};
use kumo_infrastructure::docs::{ConfluenceDocs, VaultDocs};
use kumo_infrastructure::fs::{LocalFileStore, LocalProjectReader};
use kumo_infrastructure::git::{FsRepoFinder, GitCli};
use kumo_infrastructure::profiles::profile_dir;
use kumo_infrastructure::storage::{SqliteAgentStore, SqliteTaskStore, SqliteWorkspaceStore};
use kumo_infrastructure::tasks::{
    BearConnector, GitHubConnector, JiraConnector, ObsidianConnector, TodoistConnector,
};
use kumo_infrastructure::watch::NotifyWatcher;

const DATABASE: &str = "kumo.db";

/// What every profile shares: the machine, its programs and its terminals.
pub(crate) struct ProfileOpener {
    pub data_dir: PathBuf,
    pub home: PathBuf,
    pub locator: Arc<dyn ProgramLocator>,
    pub secrets: Arc<dyn SecretStore>,
    pub host_tokens: Arc<dyn HostTokens>,
    pub terminals: Arc<TerminalService>,
}

impl OpenProfile<ProfileServices> for ProfileOpener {
    fn open<'a>(
        &'a self,
        profile: &'a Profile,
    ) -> BoxFuture<'a, Result<ProfileServices, ProfileError>> {
        Box::pin(async move {
            self.build(profile).await.map_err(|e| ProfileError::Open {
                id: profile.id.to_string(),
                reason: format!("{e:#}"),
            })
        })
    }

    fn stats(&self, profile: &Profile) -> ProfileActivity {
        let db = profile_dir(&self.data_dir, &profile.id).join(DATABASE);
        if !db.exists() {
            return ProfileActivity::default();
        }
        let stored = SqliteWorkspaceStore::open(&db)
            .ok()
            .and_then(|s| s.load().ok());
        stored.map_or_else(ProfileActivity::default, |stored| ProfileActivity {
            namespaces: u32::try_from(stored.namespaces.len()).unwrap_or(u32::MAX),
            repos: u32::try_from(stored.repos.len()).unwrap_or(u32::MAX),
            ..ProfileActivity::default()
        })
    }
}

impl ProfileOpener {
    /// Every per-profile service over `<profile dir>/kumo.db`.
    async fn build(&self, profile: &Profile) -> anyhow::Result<ProfileServices> {
        let dir = profile_dir(&self.data_dir, &profile.id);
        std::fs::create_dir_all(&dir)?;
        let db = dir.join(DATABASE);
        let home = &self.home;
        let locator = &self.locator;

        let workspace = Arc::new(
            WorkspaceService::load(WorkspacePorts {
                git: Arc::new(GitCli::default()),
                store: Arc::new(SqliteWorkspaceStore::open(&db)?),
                finder: Arc::new(FsRepoFinder::new(home)),
                watcher: Arc::new(NotifyWatcher),
                location: WorktreeLocation::new(home),
            })
            .await?,
        );
        // Git state is read in the background: the daemon answers right away.
        let initial = Arc::clone(&workspace);
        tokio::spawn(async move { initial.refresh().await });
        // Worktrees and changes made from a terminal show without a refresh.
        workspace.sync();

        let connectors: Vec<Arc<dyn TaskConnector>> = vec![
            Arc::new(ObsidianConnector::new(home)),
            Arc::new(BearConnector::new(home)),
            Arc::new(GitHubConnector::new(Arc::clone(locator))),
            Arc::new(JiraConnector::default()),
            Arc::new(TodoistConnector::default()),
        ];
        let task_store = Arc::new(SqliteTaskStore::open(&db)?);
        // Docs read through the task sources' accounts and vaults.
        let docs = Arc::new(DocsService::new(
            DocsPorts {
                sources: task_store.clone(),
                secrets: Arc::clone(&self.secrets),
                connectors: vec![Arc::new(ConfluenceDocs::default()), Arc::new(VaultDocs)],
            },
            std::time::Duration::from_secs(60),
        ));
        let tasks = TaskService::load(
            TaskPorts {
                store: task_store,
                secrets: Arc::clone(&self.secrets),
                connectors,
                watcher: Arc::new(NotifyWatcher),
            },
            TaskTiming::default(),
        )
        .await?;

        // gh's sign-in: one cached token for pipelines and pull requests.
        let gh: Arc<dyn TokenFallback> = Arc::new(GhTokenFallback::new(Arc::clone(locator)));
        let pipelines = Arc::new(PipelinesService::new(
            PipelinesPorts {
                clients: vec![
                    Arc::new(GitHubActions::default()),
                    Arc::new(GitLabCi::default()),
                    Arc::new(BitbucketPipelines::default()),
                ],
                tokens: Arc::clone(&self.host_tokens),
                fallback: Arc::clone(&gh),
                branches: Arc::new(GitCli::default()),
                terminals: Arc::clone(&self.terminals) as _,
            },
            PipelinesTiming::default(),
            workspace.watch(),
        ));
        let pulls = Arc::new(PullRequestService::new(
            PullRequestPorts {
                clients: vec![
                    Arc::new(GitHubPulls::default()),
                    Arc::new(GitLabPulls::default()),
                    Arc::new(BitbucketPulls::default()),
                ],
                tokens: Arc::clone(&self.host_tokens),
                fallback: gh,
                branches: Arc::new(GitCli::default()),
            },
            workspace.watch(),
            std::time::Duration::from_secs(60),
        ));

        let agent_store = Arc::new(SqliteAgentStore::open(&db)?);
        let agents = Arc::new(AgentService::new(
            AgentPorts {
                store: agent_store.clone(),
                locator: Arc::clone(locator),
                // Plan limits and context windows, as the CLIs report them.
                usage: vec![
                    Arc::new(ClaudeStatusLine::new(&dir.join("agents"), home)),
                    Arc::new(CodexRollouts::new(&codex_home(home))),
                ],
                plans: agent_store,
            },
            Arc::clone(&self.terminals),
            Arc::clone(&workspace),
        ));
        let changes = Arc::new(ChangesService::new(
            ChangesPorts {
                git: Arc::new(GitCli::default()),
                files: Arc::new(LocalFileStore),
                watcher: Arc::new(NotifyWatcher),
            },
            Arc::clone(&workspace),
        ));
        let tests = Arc::new(TestService::new(
            TestPorts {
                files: Arc::new(LocalProjectReader),
                locator: Arc::clone(locator),
            },
            Arc::clone(&self.terminals),
            Arc::clone(&workspace),
        ));
        Ok(ProfileServices {
            home: home.clone(),
            workspace,
            changes,
            agents,
            tasks,
            pipelines,
            pulls,
            docs,
            tests,
        })
    }
}
