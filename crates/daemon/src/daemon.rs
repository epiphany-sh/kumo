use std::future::Future;
use std::sync::Arc;

use anyhow::Context;
use kumo_application::daemon::HelloService;
use kumo_application::terminal::TerminalService;
use kumo_domain::daemon::{ApiVersion, DaemonEndpoint, DiscoveryStore};
use kumo_grpc::server::{GrpcServer, Services};
use kumo_infrastructure::discovery::FileDiscoveryStore;
use kumo_infrastructure::pty::PortablePtySystem;
use kumo_infrastructure::security::generate_auth_token;

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
        let discovery = match config.data_dir {
            Some(dir) => FileDiscoveryStore::in_dir(dir),
            None => FileDiscoveryStore::default_location()
                .context("no local data directory for the discovery file")?,
        };
        ensure_not_running(&discovery).await?;

        let token = generate_auth_token().context("generating auth token")?;
        let terminals = Arc::new(TerminalService::new(
            Arc::new(PortablePtySystem),
            config.session,
        ));
        let services = Services {
            hello: HelloService::new(env!("CARGO_PKG_VERSION")),
            terminals: Arc::clone(&terminals),
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
