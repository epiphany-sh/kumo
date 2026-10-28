use std::path::PathBuf;
use std::pin::Pin;
use std::sync::Arc;

use futures::{Stream, StreamExt};
use kumo_application::agents::AgentService;
use kumo_domain::agents::AgentSessionId;
use kumo_proto::v1 as pb;
use tokio_stream::wrappers::WatchStream;
use tonic::{Request, Response, Status};

use crate::mapping::{
    agent_session_to, agents_snapshot_to, agents_status_from, provider_to, size_from, status_from,
};

type SnapshotStream = Pin<Box<dyn Stream<Item = Result<pb::AgentsSnapshot, Status>> + Send>>;

/// `kumo.v1.Agents`.
#[derive(Debug, Clone)]
pub struct AgentsGrpc {
    service: Arc<AgentService>,
}

impl AgentsGrpc {
    pub fn new(service: Arc<AgentService>) -> Self {
        Self { service }
    }
}

fn session_id(raw: &str) -> Result<AgentSessionId, Status> {
    AgentSessionId::parse(raw).ok_or_else(|| Status::invalid_argument("agent session id is empty"))
}

fn non_empty(raw: String) -> Option<String> {
    Some(raw).filter(|s| !s.trim().is_empty())
}

#[tonic::async_trait]
impl pb::agents_server::Agents for AgentsGrpc {
    async fn list_providers(
        &self,
        _request: Request<pb::ListProvidersRequest>,
    ) -> Result<Response<pb::ListProvidersResponse>, Status> {
        let providers = self.service.providers().await.map_err(agents_status_from)?;
        Ok(Response::new(pb::ListProvidersResponse {
            providers: providers.into_iter().map(provider_to).collect(),
        }))
    }

    async fn save_provider(
        &self,
        request: Request<pb::SaveProviderRequest>,
    ) -> Result<Response<pb::AgentProvider>, Status> {
        let r = request.into_inner();
        let view = self
            .service
            .save_provider(
                non_empty(r.id),
                &r.name,
                &r.program,
                &r.args,
                r.enabled,
                r.is_default,
            )
            .await
            .map_err(agents_status_from)?;
        Ok(Response::new(provider_to(view)))
    }

    async fn delete_provider(
        &self,
        request: Request<pb::DeleteProviderRequest>,
    ) -> Result<Response<pb::DeleteProviderResponse>, Status> {
        self.service
            .delete_provider(&request.into_inner().id)
            .await
            .map_err(agents_status_from)?;
        Ok(Response::new(pb::DeleteProviderResponse {}))
    }

    async fn test_provider(
        &self,
        request: Request<pb::TestProviderRequest>,
    ) -> Result<Response<pb::TestProviderResponse>, Status> {
        let version = self
            .service
            .test_provider(&request.into_inner().id)
            .await
            .map_err(agents_status_from)?;
        Ok(Response::new(pb::TestProviderResponse { version }))
    }

    async fn login_provider(
        &self,
        request: Request<pb::LoginProviderRequest>,
    ) -> Result<Response<pb::LoginProviderResponse>, Status> {
        let terminal = self
            .service
            .login(&request.into_inner().id)
            .await
            .map_err(agents_status_from)?;
        Ok(Response::new(pb::LoginProviderResponse {
            terminal_id: terminal.to_string(),
        }))
    }

    async fn start(
        &self,
        request: Request<pb::StartAgentRequest>,
    ) -> Result<Response<pb::AgentSession>, Status> {
        let r = request.into_inner();
        let size = size_from(r.cols, r.rows).map_err(status_from)?;
        let provider = non_empty(r.provider_id);
        let session = self
            .service
            .start(
                provider.as_deref(),
                &PathBuf::from(r.worktree_path),
                &r.prompt,
                &r.title,
                size,
            )
            .await
            .map_err(agents_status_from)?;
        Ok(Response::new(agent_session_to(session)))
    }

    async fn stop(
        &self,
        request: Request<pb::StopAgentRequest>,
    ) -> Result<Response<pb::StopAgentResponse>, Status> {
        self.service
            .stop(&session_id(&request.into_inner().id)?)
            .map_err(agents_status_from)?;
        Ok(Response::new(pb::StopAgentResponse {}))
    }

    async fn dismiss(
        &self,
        request: Request<pb::DismissAgentRequest>,
    ) -> Result<Response<pb::DismissAgentResponse>, Status> {
        self.service
            .dismiss(&session_id(&request.into_inner().id)?)
            .map_err(agents_status_from)?;
        Ok(Response::new(pb::DismissAgentResponse {}))
    }

    type WatchStream = SnapshotStream;

    async fn watch(
        &self,
        _request: Request<pb::WatchAgentsRequest>,
    ) -> Result<Response<Self::WatchStream>, Status> {
        let snapshots = WatchStream::new(self.service.watch())
            .map(|snapshot| Ok(agents_snapshot_to(&snapshot)));
        Ok(Response::new(Box::pin(snapshots)))
    }
}
