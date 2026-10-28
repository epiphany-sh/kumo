//! Authenticated client for the daemon API.

use std::net::SocketAddr;

use kumo_domain::daemon::{ApiVersion, AuthToken};
use kumo_proto::v1 as pb;
use kumo_proto::v1::core_client::CoreClient;
use kumo_proto::v1::terminals_client::TerminalsClient;
use tonic::Status;
use tonic::service::interceptor::InterceptedService;
use tonic::transport::{Channel, Endpoint};

use crate::auth::AttachBearer;

pub type AuthChannel = InterceptedService<Channel, AttachBearer>;

/// One HTTP/2 connection to the daemon, shared by all service clients.
#[derive(Debug, Clone)]
pub struct KumoClient {
    pub core: CoreClient<AuthChannel>,
    pub terminals: TerminalsClient<AuthChannel>,
}

impl KumoClient {
    pub async fn connect(
        addr: SocketAddr,
        token: &AuthToken,
    ) -> Result<Self, tonic::transport::Error> {
        let channel = Endpoint::from_shared(format!("http://{addr}"))?
            .tcp_nodelay(true)
            .connect()
            .await?;
        let auth = AttachBearer::new(token);
        Ok(Self {
            core: CoreClient::with_interceptor(channel.clone(), auth.clone()),
            terminals: TerminalsClient::with_interceptor(channel, auth),
        })
    }

    /// Handshake; fails if the daemon speaks a different API version.
    pub async fn hello(&mut self, client_name: &str) -> Result<pb::HelloResponse, Status> {
        let response = self
            .core
            .hello(pb::HelloRequest {
                client_api_version: ApiVersion::CURRENT.get(),
                client_name: client_name.to_owned(),
            })
            .await?
            .into_inner();
        if !ApiVersion::new(response.server_api_version).is_compatible_with(ApiVersion::CURRENT) {
            return Err(Status::failed_precondition(format!(
                "daemon API {} is incompatible with client API {}",
                ApiVersion::new(response.server_api_version),
                ApiVersion::CURRENT
            )));
        }
        Ok(response)
    }
}
