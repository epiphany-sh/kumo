use std::future::Future;
use std::sync::Arc;

use anyhow::Context;
use kumo_application::agents::{AgentPorts, AgentService};
use kumo_application::changes::{ChangesPorts, ChangesService};
use kumo_application::daemon::HelloService;
use kumo_application::pipelines::{PipelinesPorts, PipelinesService, PipelinesTiming};
use kumo_application::pulls::{PullRequestPorts, PullRequestService};
use kumo_application::tasks::{TaskPorts, TaskService, TaskTiming};
use kumo_application::terminal::TerminalService;
use kumo_application::workspace::{WorkspacePorts, WorkspaceService};
use kumo_domain::agents::ProgramLocator;
use kumo_domain::daemon::{ApiVersion, DaemonEndpoint, DiscoveryStore};
use kumo_domain::pipelines::{HostTokens, TokenFallback};
use kumo_domain::tasks::{SecretStore, TaskConnector};
use kumo_domain::workspace::WorktreeLocation;
use kumo_grpc::server::{GrpcServer, Services};
use kumo_infrastructure::agents::ShellPathLocator;
use kumo_infrastructure::ci::{
    BitbucketPipelines, BitbucketPulls, GhTokenFallback, GitHubActions, GitHubPulls, GitLabCi,
    GitLabPulls,
};
use kumo_infrastructure::discovery::FileDiscoveryStore;
use kumo_infrastructure::fs::LocalFileStore;
use kumo_infrastructure::git::{FsRepoFinder, GitCli};
use kumo_infrastructure::pty::PortablePtySystem;
use kumo_infrastructure::secrets::{KeychainSecretStore, MemorySecretStore};
use kumo_infrastructure::security::generate_auth_token;
use kumo_infrastructure::storage::{SqliteAgentStore, SqliteTaskStore, SqliteWorkspaceStore};
use kumo_infrastructure::tasks::{
    BearConnector, GitHubConnector, JiraConnector, ObsidianConnector, TodoistConnector,
};
use kumo_infrastructure::watch::NotifyWatcher;

use crate::single_instance::ensure_not_running;
use crate::{DaemonConfig, SecretsBackend};

/// A started daemon: listening, advertised, not yet serving.
#[derive(Debug)]
pub struct Daemon {
    server: GrpcServer,
    endpoint: DaemonEndpoint,
    discovery: FileDiscoveryStore,
    terminals: Arc<TerminalService>,
}

impl Daemon {
    /// Checks for another instance, binds on loopback and writes the
    /// discovery file.
    pub async fn start(config: DaemonConfig) -> anyhow::Result<Self> {
        let data_dir = match config.data_dir {
            Some(dir) => dir,
            None => dirs::data_local_dir()
                .context("no local data directory")?
                .join("kumo"),
        };
        let home = match config.home {
            Some(home) => home,
            None => dirs::home_dir().context("no home directory")?,
        };
        let discovery = FileDiscoveryStore::in_dir(&data_dir);
        ensure_not_running(&discovery).await?;

        let workspace = Arc::new(
            WorkspaceService::load(WorkspacePorts {
                git: Arc::new(GitCli::default()),
                store: Arc::new(SqliteWorkspaceStore::open(&data_dir.join("kumo.db"))?),
                finder: Arc::new(FsRepoFinder::new(&home)),
                location: WorktreeLocation::new(&home),
            })
            .await?,
        );
        // Git state is read in the background: the daemon answers right away.
        let initial = Arc::clone(&workspace);
        tokio::spawn(async move { initial.refresh().await });

        let token = generate_auth_token().context("generating auth token")?;
        let terminals = Arc::new(TerminalService::new(
            Arc::new(PortablePtySystem),
            config.session,
        ));
        let locator: Arc<dyn ProgramLocator> = Arc::new(match config.agent_path {
            Some(path) => ShellPathLocator::with_path(&home, path),
            None => ShellPathLocator::new(&home),
        });
        // One keychain for task sources and repository hosts.
        let (secrets, host_tokens): (Arc<dyn SecretStore>, Arc<dyn HostTokens>) =
            match config.secrets {
                SecretsBackend::Keychain => {
                    let keychain = Arc::new(KeychainSecretStore::new());
                    (keychain.clone(), keychain)
                }
                SecretsBackend::Memory => {
                    let memory = Arc::new(MemorySecretStore::default());
                    (memory.clone(), memory)
                }
            };
        let connectors: Vec<Arc<dyn TaskConnector>> = vec![
            Arc::new(ObsidianConnector::new(&home)),
            Arc::new(BearConnector::new(&home)),
            Arc::new(GitHubConnector::new(Arc::clone(&locator))),
            Arc::new(JiraConnector::default()),
            Arc::new(TodoistConnector::default()),
        ];
        let tasks = TaskService::load(
            TaskPorts {
                store: Arc::new(SqliteTaskStore::open(&data_dir.join("kumo.db"))?),
                secrets,
                connectors,
                watcher: Arc::new(NotifyWatcher),
            },
            TaskTiming::default(),
        )
        .await?;

        // gh's sign-in, shared: one cached token for pipelines and pull requests.
        let gh: Arc<dyn TokenFallback> = Arc::new(GhTokenFallback::new(Arc::clone(&locator)));
        let pipelines = Arc::new(PipelinesService::new(
            PipelinesPorts {
                clients: vec![
                    Arc::new(GitHubActions::default()),
                    Arc::new(GitLabCi::default()),
                    Arc::new(BitbucketPipelines::default()),
                ],
                tokens: Arc::clone(&host_tokens),
                fallback: Arc::clone(&gh),
                branches: Arc::new(GitCli::default()),
                terminals: Arc::clone(&terminals) as _,
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
                tokens: host_tokens,
                fallback: gh,
                branches: Arc::new(GitCli::default()),
            },
            workspace.watch(),
            std::time::Duration::from_secs(60),
        ));

        let services = Services {
            hello: HelloService::new(env!("CARGO_PKG_VERSION")),
            terminals: Arc::clone(&terminals),
            workspace: Arc::clone(&workspace),
            changes: Arc::new(ChangesService::new(
                ChangesPorts {
                    git: Arc::new(GitCli::default()),
                    files: Arc::new(LocalFileStore),
                    watcher: Arc::new(NotifyWatcher),
                },
                Arc::clone(&workspace),
            )),
            agents: Arc::new(AgentService::new(
                AgentPorts {
                    store: Arc::new(SqliteAgentStore::open(&data_dir.join("kumo.db"))?),
                    locator,
                },
                Arc::clone(&terminals),
                workspace,
            )),
            tasks,
            pipelines,
            pulls,
        };
        let server = GrpcServer::bind(config.listen, token.clone(), services).await?;

        let endpoint = DaemonEndpoint {
            api_version: ApiVersion::CURRENT,
            pid: std::process::id(),
            addr: server.local_addr(),
            token,
        };
        discovery.save(&endpoint)?;
        tracing::info!(
            addr = %endpoint.addr,
            discovery = %discovery.path().display(),
            "kumod listening"
        );
        Ok(Self {
            server,
            endpoint,
            discovery,
            terminals,
        })
    }

    pub fn endpoint(&self) -> &DaemonEndpoint {
        &self.endpoint
    }

    /// Serves until `shutdown` resolves, then kills all terminals and
    /// removes the discovery file.
    pub async fn run(self, shutdown: impl Future<Output = ()>) -> anyhow::Result<()> {
        let served = self.server.serve(shutdown).await;
        self.terminals.close_all();
        if let Err(error) = self.discovery.remove() {
            tracing::warn!(%error, "failed to remove discovery file");
        }
        tracing::info!("kumod stopped");
        served.context("gRPC server failed")
    }
}
