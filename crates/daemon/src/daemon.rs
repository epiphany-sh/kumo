use std::future::Future;
use std::sync::Arc;

use anyhow::Context;
use kumo_application::agents::{AgentPorts, AgentService};
use kumo_application::changes::{ChangesPorts, ChangesService};
use kumo_application::daemon::HelloService;
use kumo_application::terminal::TerminalService;
use kumo_application::workspace::{WorkspacePorts, WorkspaceService};
use kumo_domain::daemon::{ApiVersion, DaemonEndpoint, DiscoveryStore};
use kumo_domain::workspace::WorktreeLocation;
use kumo_grpc::server::{GrpcServer, Services};
use kumo_infrastructure::agents::ShellPathLocator;
use kumo_infrastructure::discovery::FileDiscoveryStore;
use kumo_infrastructure::fs::LocalFileStore;
use kumo_infrastructure::git::{FsRepoFinder, GitCli};
use kumo_infrastructure::pty::PortablePtySystem;
use kumo_infrastructure::security::generate_auth_token;
use kumo_infrastructure::storage::{SqliteAgentStore, SqliteWorkspaceStore};
use kumo_infrastructure::watch::NotifyWatcher;

use crate::DaemonConfig;
use crate::single_instance::ensure_not_running;

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
                    locator: Arc::new(match config.agent_path {
                        Some(path) => ShellPathLocator::with_path(&home, path),
                        None => ShellPathLocator::new(&home),
                    }),
                },
                Arc::clone(&terminals),
                workspace,
            )),
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
