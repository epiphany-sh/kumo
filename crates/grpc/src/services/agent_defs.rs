use std::path::PathBuf;
use std::pin::Pin;
use std::sync::Arc;

use futures::{Stream, StreamExt};
use kumo_application::agent_defs::{AgentDefService, PlayStart, RunStart, RunWhere};
use kumo_proto::v1 as pb;
use tokio_stream::wrappers::ReceiverStream;
use tonic::{Request, Response, Status};

use crate::mapping::{
    agent_context_from, agent_def_from, agent_def_to, agent_session_to, agents_status_from,
    capabilities_to, play_event_to, play_record_to, size_from, status_from,
};
use crate::profile::{Profiles, services_of};

type PlayStream = Pin<Box<dyn Stream<Item = Result<pb::PlayEvent, Status>> + Send>>;

/// `kumo.v1.AgentDefs`.
#[derive(Debug, Clone)]
pub struct AgentDefsGrpc {
    profiles: Arc<Profiles>,
}

impl AgentDefsGrpc {
    pub fn new(profiles: Arc<Profiles>) -> Self {
        Self { profiles }
    }

    /// The agent definitions service of the profile the call names.
    async fn service<T>(&self, request: &Request<T>) -> Result<Arc<AgentDefService>, Status> {
        Ok(Arc::clone(
            &services_of(&self.profiles, request).await?.agent_defs,
        ))
    }
}

fn agent_of(
    agent: Option<pb::AgentDefFile>,
) -> Result<kumo_domain::agent_defs::AgentDefFile, Status> {
    agent
        .map(agent_def_from)
        .ok_or_else(|| Status::invalid_argument("agent is required"))
}

fn place_from(place: Option<pb::run_agent_def_request::Where>) -> Result<RunWhere, Status> {
    use pb::run_agent_def_request::Where;
    Ok(match place {
        Some(Where::WorktreePath(path)) => RunWhere::Worktree(PathBuf::from(path)),
        Some(Where::NewWorktreeRepo(repo)) => RunWhere::NewWorktree(PathBuf::from(repo)),
        Some(Where::LinkUrl(url)) => RunWhere::Link(url),
        Some(Where::Folder(folder)) => RunWhere::Folder(PathBuf::from(folder)),
        Some(Where::Scratch(true)) => RunWhere::Scratch,
        Some(Where::Scratch(false)) | None => {
            return Err(Status::invalid_argument("say where it runs"));
        }
    })
}

#[tonic::async_trait]
impl pb::agent_defs_server::AgentDefs for AgentDefsGrpc {
    async fn list(
        &self,
        request: Request<pb::ListAgentDefsRequest>,
    ) -> Result<Response<pb::AgentDefList>, Status> {
        let service = self.service(&request).await?;
        let agents = service.list().await.map_err(agents_status_from)?;
        Ok(Response::new(pb::AgentDefList {
            agents: agents.into_iter().map(agent_def_to).collect(),
        }))
    }

    async fn save(
        &self,
        request: Request<pb::SaveAgentDefRequest>,
    ) -> Result<Response<pb::AgentDefFile>, Status> {
        let service = self.service(&request).await?;
        let request = request.into_inner();
        let saved = service
            .save(
                agent_of(request.agent)?,
                request.previous.map(agent_def_from),
            )
            .await
            .map_err(agents_status_from)?;
        Ok(Response::new(agent_def_to(saved)))
    }

    async fn delete(
        &self,
        request: Request<pb::DeleteAgentDefRequest>,
    ) -> Result<Response<pb::DeleteAgentDefResponse>, Status> {
        let service = self.service(&request).await?;
        service
            .delete(agent_of(request.into_inner().agent)?)
            .await
            .map_err(agents_status_from)?;
        Ok(Response::new(pb::DeleteAgentDefResponse {}))
    }

    async fn run(
        &self,
        request: Request<pb::RunAgentDefRequest>,
    ) -> Result<Response<pb::AgentSession>, Status> {
        let service = self.service(&request).await?;
        let request = request.into_inner();
        let size = size_from(request.cols, request.rows).map_err(status_from)?;
        let session = service
            .run(RunStart {
                provider_id: request.provider_id,
                agent: agent_of(request.agent)?,
                inline_json: request.inline_json,
                place: place_from(request.r#where)?,
                prompt: request.prompt,
                context: request
                    .context
                    .into_iter()
                    .map(agent_context_from)
                    .collect(),
                size,
            })
            .await
            .map_err(agents_status_from)?;
        Ok(Response::new(agent_session_to(session)))
    }

    type PlayStream = PlayStream;

    async fn play(
        &self,
        request: Request<pb::PlayRequest>,
    ) -> Result<Response<Self::PlayStream>, Status> {
        let service = self.service(&request).await?;
        let request = request.into_inner();
        let owner = agent_of(request.agent)?;
        let (id, events) = service
            .play(PlayStart {
                provider_id: request.provider_id,
                name: request.name,
                inline_json: request.inline_json,
                task: request.task,
                worktree: PathBuf::from(request.worktree_path),
                throwaway: request.throwaway,
                context: request
                    .context
                    .into_iter()
                    .map(agent_context_from)
                    .collect(),
                max_turns: request.max_turns,
                max_minutes: request.max_minutes,
                max_cost_usd: request.max_cost_usd,
                owner,
                draft: request.draft,
            })
            .await
            .map_err(agents_status_from)?;
        let stream = ReceiverStream::new(events).map(move |event| Ok(play_event_to(&id, event)));
        Ok(Response::new(Box::pin(stream)))
    }

    async fn stop_play(
        &self,
        request: Request<pb::StopPlayRequest>,
    ) -> Result<Response<pb::StopPlayResponse>, Status> {
        let service = self.service(&request).await?;
        service.stop_play(&request.into_inner().play_id);
        Ok(Response::new(pb::StopPlayResponse {}))
    }

    async fn list_plays(
        &self,
        request: Request<pb::ListPlaysRequest>,
    ) -> Result<Response<pb::PlayList>, Status> {
        let service = self.service(&request).await?;
        let agent = agent_of(request.into_inner().agent)?;
        let plays = service.plays(&agent).await.map_err(agents_status_from)?;
        Ok(Response::new(pb::PlayList {
            plays: plays.into_iter().map(play_record_to).collect(),
        }))
    }

    async fn ask(
        &self,
        request: Request<pb::AskRequest>,
    ) -> Result<Response<pb::AskResponse>, Status> {
        let service = self.service(&request).await?;
        let request = request.into_inner();
        let cwd = (!request.cwd.is_empty()).then(|| PathBuf::from(request.cwd));
        let text = service
            .ask(&request.prompt, cwd, &request.provider_id)
            .await
            .map_err(agents_status_from)?;
        Ok(Response::new(pb::AskResponse { text }))
    }

    async fn capabilities(
        &self,
        request: Request<pb::AgentDefCapabilitiesRequest>,
    ) -> Result<Response<pb::AgentDefCapabilities>, Status> {
        let service = self.service(&request).await?;
        let capabilities = service.capabilities().await.map_err(agents_status_from)?;
        Ok(Response::new(capabilities_to(capabilities)))
    }
}
