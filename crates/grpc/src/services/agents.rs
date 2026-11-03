use std::path::PathBuf;
use std::pin::Pin;
use std::sync::Arc;

use futures::{Stream, StreamExt};
use kumo_application::agents::{AgentService, ProviderSettings};
use kumo_domain::agents::AgentSessionId;
use kumo_proto::v1 as pb;
use tokio_stream::wrappers::WatchStream;
use tonic::{Request, Response, Status};

use crate::mapping::{
    agent_context_from, agent_session_to, agents_snapshot_to, agents_status_from, provider_to,
    size_from, status_from, usage_report_to,
};
use crate::profile::{Profiles, services_of};

type SnapshotStream = Pin<Box<dyn Stream<Item = Result<pb::AgentsSnapshot, Status>> + Send>>;

/// `kumo.v1.Agents`.
#[derive(Debug, Clone)]
pub struct AgentsGrpc {
    profiles: Arc<Profiles>,
}

impl AgentsGrpc {
    pub fn new(profiles: Arc<Profiles>) -> Self {
        Self { profiles }
    }

    /// The agents service of the profile the call names.
    async fn service<T>(&self, request: &Request<T>) -> Result<Arc<AgentService>, Status> {
        Ok(Arc::clone(
            &services_of(&self.profiles, request).await?.agents,
        ))
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
        request: Request<pb::ListProvidersRequest>,
    ) -> Result<Response<pb::ListProvidersResponse>, Status> {
        let service = self.service(&request).await?;
        let providers = service.providers().await.map_err(agents_status_from)?;
        Ok(Response::new(pb::ListProvidersResponse {
            providers: providers.into_iter().map(provider_to).collect(),
        }))
    }

    async fn save_provider(
        &self,
        request: Request<pb::SaveProviderRequest>,
    ) -> Result<Response<pb::AgentProvider>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let view = service
            .save_provider(
                non_empty(r.id),
                ProviderSettings {
                    name: r.name,
                    program: r.program,
                    args: r.args,
                    enabled: r.enabled,
                    is_default: r.is_default,
                    read_usage: r.read_usage,
                },
            )
            .await
            .map_err(agents_status_from)?;
        Ok(Response::new(provider_to(view)))
    }

    async fn delete_provider(
        &self,
        request: Request<pb::DeleteProviderRequest>,
    ) -> Result<Response<pb::DeleteProviderResponse>, Status> {
        let service = self.service(&request).await?;
        service
            .delete_provider(&request.into_inner().id)
            .await
            .map_err(agents_status_from)?;
        Ok(Response::new(pb::DeleteProviderResponse {}))
    }

    async fn test_provider(
        &self,
        request: Request<pb::TestProviderRequest>,
    ) -> Result<Response<pb::TestProviderResponse>, Status> {
        let service = self.service(&request).await?;
        let version = service
            .test_provider(&request.into_inner().id)
            .await
            .map_err(agents_status_from)?;
        Ok(Response::new(pb::TestProviderResponse { version }))
    }

    async fn login_provider(
        &self,
        request: Request<pb::LoginProviderRequest>,
    ) -> Result<Response<pb::LoginProviderResponse>, Status> {
        let service = self.service(&request).await?;
        let terminal = service
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
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let size = size_from(r.cols, r.rows).map_err(status_from)?;
        let provider = non_empty(r.provider_id);
        let session = service
            .start(
                provider.as_deref(),
                &PathBuf::from(r.worktree_path),
                &r.prompt,
                &r.title,
                r.context.into_iter().map(agent_context_from).collect(),
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
        let service = self.service(&request).await?;
        service
            .stop(&session_id(&request.into_inner().id)?)
            .map_err(agents_status_from)?;
        Ok(Response::new(pb::StopAgentResponse {}))
    }

    async fn add_context(
        &self,
        request: Request<pb::AddAgentContextRequest>,
    ) -> Result<Response<pb::AgentSession>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let context = r
            .context
            .ok_or_else(|| Status::invalid_argument("context is missing"))?;
        let session = service
            .add_context(&session_id(&r.id)?, agent_context_from(context), &r.text)
            .await
            .map_err(agents_status_from)?;
        Ok(Response::new(agent_session_to(session)))
    }

    async fn dismiss(
        &self,
        request: Request<pb::DismissAgentRequest>,
    ) -> Result<Response<pb::DismissAgentResponse>, Status> {
        let service = self.service(&request).await?;
        service
            .dismiss(&session_id(&request.into_inner().id)?)
            .map_err(agents_status_from)?;
        Ok(Response::new(pb::DismissAgentResponse {}))
    }

    async fn usage(
        &self,
        request: Request<pb::UsageRequest>,
    ) -> Result<Response<pb::UsageReport>, Status> {
        let service = self.service(&request).await?;
        let report = service.usage().await.map_err(agents_status_from)?;
        Ok(Response::new(usage_report_to(report)))
    }

    async fn compact(
        &self,
        request: Request<pb::CompactAgentRequest>,
    ) -> Result<Response<pb::AgentSession>, Status> {
        let service = self.service(&request).await?;
        let session = service
            .compact(&session_id(&request.into_inner().id)?)
            .await
            .map_err(agents_status_from)?;
        Ok(Response::new(agent_session_to(session)))
    }

    type WatchStream = SnapshotStream;

    async fn watch(
        &self,
        request: Request<pb::WatchAgentsRequest>,
    ) -> Result<Response<Self::WatchStream>, Status> {
        let service = self.service(&request).await?;
        let snapshots =
            WatchStream::new(service.watch()).map(|snapshot| Ok(agents_snapshot_to(&snapshot)));
        Ok(Response::new(Box::pin(snapshots)))
    }
}
