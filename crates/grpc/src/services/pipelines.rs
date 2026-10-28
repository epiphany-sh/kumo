use std::path::PathBuf;
use std::pin::Pin;
use std::sync::Arc;

use futures::{Stream, StreamExt, future};
use kumo_application::pipelines::PipelinesService;
use kumo_proto::v1 as pb;
use tokio_stream::wrappers::WatchStream;
use tonic::{Request, Response, Status};

use crate::mapping::{ci_problem_to, host_info_to, pipelines_snapshot_to, pipelines_status_from};

type SnapshotStream = Pin<Box<dyn Stream<Item = Result<pb::PipelinesSnapshot, Status>> + Send>>;

/// `kumo.v1.Pipelines`.
#[derive(Debug, Clone)]
pub struct PipelinesGrpc {
    service: Arc<PipelinesService>,
}

impl PipelinesGrpc {
    pub fn new(service: Arc<PipelinesService>) -> Self {
        Self { service }
    }
}

#[tonic::async_trait]
impl pb::pipelines_server::Pipelines for PipelinesGrpc {
    type WatchStream = SnapshotStream;

    async fn watch(
        &self,
        request: Request<pb::WatchPipelinesRequest>,
    ) -> Result<Response<Self::WatchStream>, Status> {
        let worktree = PathBuf::from(request.into_inner().worktree_path);
        let updates = self
            .service
            .watch(&worktree)
            .map_err(pipelines_status_from)?;
        // Nothing until the first answer: the UI shows "loading" meanwhile.
        let stream = WatchStream::new(updates)
            .filter_map(|latest| future::ready(latest.map(|s| Ok(pipelines_snapshot_to(&s)))));
        Ok(Response::new(Box::pin(stream)))
    }

    async fn refresh(
        &self,
        request: Request<pb::WorktreeRequest>,
    ) -> Result<Response<pb::PipelinesActionResponse>, Status> {
        let worktree = PathBuf::from(request.into_inner().worktree_path);
        self.service
            .refresh(&worktree)
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(pb::PipelinesActionResponse {}))
    }

    async fn rerun_failed(
        &self,
        request: Request<pb::RerunFailedRequest>,
    ) -> Result<Response<pb::PipelinesActionResponse>, Status> {
        let r = request.into_inner();
        self.service
            .rerun_failed(&PathBuf::from(r.worktree_path), &r.run_id)
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(pb::PipelinesActionResponse {}))
    }

    async fn list_hosts(
        &self,
        _request: Request<pb::ListHostsRequest>,
    ) -> Result<Response<pb::ListHostsResponse>, Status> {
        let hosts = self.service.hosts().await;
        Ok(Response::new(pb::ListHostsResponse {
            hosts: hosts.into_iter().map(host_info_to).collect(),
        }))
    }

    async fn save_host_token(
        &self,
        request: Request<pb::SaveHostTokenRequest>,
    ) -> Result<Response<pb::CiHostInfo>, Status> {
        let r = request.into_inner();
        let info = self
            .service
            .save_host_token(&r.host, &r.token)
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(host_info_to(info)))
    }

    async fn sign_in_with_gh(
        &self,
        request: Request<pb::SignInWithGhRequest>,
    ) -> Result<Response<pb::SignInWithGhResponse>, Status> {
        let terminal = self
            .service
            .sign_in_with_cli(&request.into_inner().host)
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(pb::SignInWithGhResponse {
            terminal_id: terminal.to_string(),
        }))
    }

    async fn test_host(
        &self,
        request: Request<pb::TestHostRequest>,
    ) -> Result<Response<pb::TestHostResponse>, Status> {
        let r = request.into_inner();
        let answer = self
            .service
            .test_host(&r.host, &r.token)
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(match answer {
            Ok(message) => pb::TestHostResponse {
                message,
                problem: None,
            },
            Err(problem) => pb::TestHostResponse {
                message: String::new(),
                problem: Some(ci_problem_to(&problem)),
            },
        }))
    }
}
