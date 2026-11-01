//! Authenticated client for the daemon API.

use std::net::SocketAddr;

use kumo_domain::daemon::{ApiVersion, AuthToken};
use kumo_proto::v1 as pb;
use kumo_proto::v1::agents_client::AgentsClient;
use kumo_proto::v1::core_client::CoreClient;
use kumo_proto::v1::docs_client::DocsClient;
use kumo_proto::v1::git_client::GitClient;
use kumo_proto::v1::pipelines_client::PipelinesClient;
use kumo_proto::v1::profiles_client::ProfilesClient;
use kumo_proto::v1::pull_requests_client::PullRequestsClient;
use kumo_proto::v1::tasks_client::TasksClient;
use kumo_proto::v1::terminals_client::TerminalsClient;
use kumo_proto::v1::tests_client::TestsClient;
use kumo_proto::v1::workspace_client::WorkspaceClient;
use tonic::service::Interceptor;
use tonic::service::interceptor::InterceptedService;
use tonic::transport::{Channel, Endpoint};
use tonic::{Request, Status};

use crate::auth::AttachBearer;
use crate::profile::AttachProfile;

pub type AuthChannel = InterceptedService<Channel, ClientHeaders>;

/// What every call carries: the bearer token and, if picked, the profile.
#[derive(Debug, Clone)]
pub struct ClientHeaders {
    bearer: AttachBearer,
    profile: AttachProfile,
}

impl Interceptor for ClientHeaders {
    fn call(&mut self, request: Request<()>) -> Result<Request<()>, Status> {
        self.profile.call(self.bearer.call(request)?)
    }
}

/// One HTTP/2 connection to the daemon, shared by all service clients.
#[derive(Debug, Clone)]
pub struct KumoClient {
    pub core: CoreClient<AuthChannel>,
    pub profiles: ProfilesClient<AuthChannel>,
    pub terminals: TerminalsClient<AuthChannel>,
    pub workspace: WorkspaceClient<AuthChannel>,
    pub git: GitClient<AuthChannel>,
    pub agents: AgentsClient<AuthChannel>,
    pub tasks: TasksClient<AuthChannel>,
    pub pipelines: PipelinesClient<AuthChannel>,
    pub pulls: PullRequestsClient<AuthChannel>,
    pub docs: DocsClient<AuthChannel>,
    pub tests: TestsClient<AuthChannel>,
    channel: Channel,
    bearer: AttachBearer,
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
        Ok(Self::over(channel, AttachBearer::new(token), None))
    }

    /// The same connection, with every call acting on profile `id` (the
    /// UI's workspace). None: the default profile.
    pub fn with_profile(&self, id: Option<&str>) -> Self {
        Self::over(self.channel.clone(), self.bearer.clone(), id)
    }

    fn over(channel: Channel, bearer: AttachBearer, profile: Option<&str>) -> Self {
        let auth = ClientHeaders {
            bearer: bearer.clone(),
            profile: AttachProfile::new(profile),
        };
        Self {
            core: CoreClient::with_interceptor(channel.clone(), auth.clone()),
            profiles: ProfilesClient::with_interceptor(channel.clone(), auth.clone()),
            terminals: TerminalsClient::with_interceptor(channel.clone(), auth.clone()),
            workspace: WorkspaceClient::with_interceptor(channel.clone(), auth.clone()),
            git: GitClient::with_interceptor(channel.clone(), auth.clone()),
            agents: AgentsClient::with_interceptor(channel.clone(), auth.clone()),
            tasks: TasksClient::with_interceptor(channel.clone(), auth.clone()),
            pipelines: PipelinesClient::with_interceptor(channel.clone(), auth.clone()),
            pulls: PullRequestsClient::with_interceptor(channel.clone(), auth.clone()),
            docs: DocsClient::with_interceptor(channel.clone(), auth.clone()),
            tests: TestsClient::with_interceptor(channel.clone(), auth),
            channel,
            bearer,
        }
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
