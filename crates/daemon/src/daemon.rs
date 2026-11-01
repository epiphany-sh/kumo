use std::future::Future;
use std::sync::Arc;
use std::time::Duration;

use anyhow::Context;
use kumo_application::daemon::{DaemonControl, HelloService};
use kumo_application::profiles::ProfileService;
use kumo_application::terminal::TerminalService;
use kumo_domain::agents::ProgramLocator;
use kumo_domain::daemon::{ApiVersion, DaemonEndpoint, DiscoveryStore};
use kumo_domain::pipelines::HostTokens;
use kumo_domain::tasks::SecretStore;
use kumo_grpc::server::{GrpcServer, Services};
use kumo_infrastructure::agents::ShellPathLocator;
use kumo_infrastructure::discovery::FileDiscoveryStore;
use kumo_infrastructure::executable::ProgramFile;
use kumo_infrastructure::profiles::FileProfileStore;
use kumo_infrastructure::pty::PortablePtySystem;
use kumo_infrastructure::secrets::{KeychainSecretStore, MemorySecretStore};
use kumo_infrastructure::security::generate_auth_token;

use crate::profiles::ProfileOpener;
use crate::single_instance::{InstanceLock, ensure_not_running, lock};
use crate::{DaemonConfig, SecretsBackend};

/// A started daemon: listening, advertised, not yet serving.
#[derive(Debug)]
pub struct Daemon {
    server: GrpcServer,
    endpoint: DaemonEndpoint,
    discovery: FileDiscoveryStore,
    terminals: Arc<TerminalService>,
    control: DaemonControl,
    _lock: InstanceLock,
}

/// Once stopping, streams still open (a UI watching) get this long to end.
const STOP_GRACE: Duration = Duration::from_secs(2);

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
        let instance = lock(&data_dir).await?;

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

        // Every other service is per profile, built the first time a call
        // names it. The default one (Kumo's data from before profiles) is
        // opened now, so its repositories are read at start as before.
        let opener = ProfileOpener {
            data_dir: data_dir.clone(),
            home: home.clone(),
            locator,
            secrets,
            host_tokens,
            terminals: Arc::clone(&terminals),
        };
        let profiles = Arc::new(ProfileService::load(
            Arc::new(FileProfileStore::in_dir(&data_dir)),
            Arc::new(opener),
        )?);
        profiles.resolve(None).await?;

        let control = DaemonControl::new(Arc::clone(&terminals));
        let services = Services {
            hello: HelloService::new(
                // Release builds say which (make release VERSION=…).
                option_env!("KUMO_VERSION").unwrap_or(env!("CARGO_PKG_VERSION")),
                Arc::new(ProgramFile::current()),
            ),
            control: control.clone(),
            terminals: Arc::clone(&terminals),
            profiles,
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
            control,
            _lock: instance,
        })
    }

    pub fn endpoint(&self) -> &DaemonEndpoint {
        &self.endpoint
    }

    /// Serves until `shutdown` resolves or a client asks it to stop, then
    /// kills all terminals and removes the discovery file.
    pub async fn run(self, shutdown: impl Future<Output = ()>) -> anyhow::Result<()> {
        let (stopping, stopped) = tokio::sync::oneshot::channel::<()>();
        let control = self.control.clone();
        let signal = async move {
            tokio::select! {
                () = shutdown => {}
                () = control.stopped() => {}
            }
            let _ = stopping.send(());
        };
        let served = tokio::select! {
            biased;
            served = self.server.serve(signal) => served,
            // A client watching keeps its connection open: don't wait forever.
            () = async {
                if stopped.await.is_ok() {
                    tokio::time::sleep(STOP_GRACE).await;
                } else {
                    std::future::pending::<()>().await;
                }
            } => Ok(()),
        };
        self.terminals.close_all();
        if let Err(error) = self.discovery.remove() {
            tracing::warn!(%error, "failed to remove discovery file");
        }
        tracing::info!("kumod stopped");
        served.context("gRPC server failed")
    }
}
