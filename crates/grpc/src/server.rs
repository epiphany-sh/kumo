//! The gRPC server: all services behind the bearer-token check, on a
//! loopback listener with `TCP_NODELAY`.

use std::future::Future;
use std::net::SocketAddr;
use std::sync::Arc;

use kumo_application::agents::AgentService;
use kumo_application::changes::ChangesService;
use kumo_application::daemon::HelloService;
use kumo_application::terminal::TerminalService;
use kumo_application::workspace::WorkspaceService;
use kumo_domain::daemon::{AuthToken, DaemonError, ListenAddress};
use kumo_proto::v1::agents_server::AgentsServer;
use kumo_proto::v1::core_server::CoreServer;
use kumo_proto::v1::git_server::GitServer;
use kumo_proto::v1::terminals_server::TerminalsServer;
use kumo_proto::v1::workspace_server::WorkspaceServer;
use tokio::net::TcpListener;
use tonic::transport::Server;
use tonic::transport::server::TcpIncoming;

use crate::auth::RequireBearer;
use crate::services::{AgentsGrpc, CoreGrpc, GitGrpc, TerminalsGrpc, WorkspaceGrpc};

/// Use cases the server exposes.
#[derive(Debug, Clone)]
pub struct Services {
    pub hello: HelloService,
    pub terminals: Arc<TerminalService>,
    pub workspace: Arc<WorkspaceService>,
    pub changes: Arc<ChangesService>,
    pub agents: Arc<AgentService>,
}

/// A bound, not yet serving, gRPC server.
#[derive(Debug)]
pub struct GrpcServer {
    listener: TcpListener,
    local_addr: SocketAddr,
    token: AuthToken,
    services: Services,
}

impl GrpcServer {
    /// Binds the listener. The address is loopback by construction.
    pub async fn bind(
        address: ListenAddress,
        token: AuthToken,
        services: Services,
    ) -> Result<Self, DaemonError> {
        let bind_error = |e: std::io::Error| DaemonError::Bind {
            addr: address.socket_addr(),
            reason: e.to_string(),
        };
        let listener = TcpListener::bind(address.socket_addr())
            .await
            .map_err(bind_error)?;
        let local_addr = listener.local_addr().map_err(bind_error)?;
        Ok(Self {
            listener,
            local_addr,
            token,
            services,
        })
    }

    pub fn local_addr(&self) -> SocketAddr {
        self.local_addr
    }

    /// Serves until `shutdown` resolves.
    pub async fn serve(
        self,
        shutdown: impl Future<Output = ()>,
    ) -> Result<(), tonic::transport::Error> {
        let auth = RequireBearer::new(self.token);
        let incoming = TcpIncoming::from(self.listener).with_nodelay(Some(true));
        Server::builder()
            .add_service(CoreServer::with_interceptor(
                CoreGrpc::new(self.services.hello),
                auth.clone(),
            ))
            .add_service(TerminalsServer::with_interceptor(
                TerminalsGrpc::new(self.services.terminals),
                auth.clone(),
            ))
            .add_service(WorkspaceServer::with_interceptor(
                WorkspaceGrpc::new(self.services.workspace),
                auth.clone(),
            ))
            .add_service(GitServer::with_interceptor(
                GitGrpc::new(self.services.changes),
                auth.clone(),
            ))
            .add_service(AgentsServer::with_interceptor(
                AgentsGrpc::new(self.services.agents),
                auth,
            ))
            .serve_with_incoming_shutdown(incoming, shutdown)
            .await
    }
}
