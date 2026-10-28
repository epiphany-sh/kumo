use std::path::PathBuf;
use std::sync::Arc;

use kumo_application::pulls::PullRequestService;
use kumo_proto::v1 as pb;
use tonic::{Request, Response, Status};

use crate::mapping::{
    branch_pull_request_to, pipelines_status_from, pull_request_list_to, pull_request_to,
};

/// `kumo.v1.PullRequests`.
#[derive(Debug, Clone)]
pub struct PullRequestsGrpc {
    service: Arc<PullRequestService>,
}

impl PullRequestsGrpc {
    pub fn new(service: Arc<PullRequestService>) -> Self {
        Self { service }
    }
}

#[tonic::async_trait]
impl pb::pull_requests_server::PullRequests for PullRequestsGrpc {
    async fn list(
        &self,
        request: Request<pb::ListPullRequestsRequest>,
    ) -> Result<Response<pb::PullRequestList>, Status> {
        let r = request.into_inner();
        let list = self
            .service
            .list(&PathBuf::from(r.repo_path), r.refresh)
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(pull_request_list_to(&list)))
    }

    async fn for_branch(
        &self,
        request: Request<pb::BranchPullRequestRequest>,
    ) -> Result<Response<pb::BranchPullRequest>, Status> {
        let r = request.into_inner();
        let branch = self
            .service
            .for_branch(&PathBuf::from(r.worktree_path), r.refresh)
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(branch_pull_request_to(&branch)))
    }

    async fn create(
        &self,
        request: Request<pb::CreatePullRequestRequest>,
    ) -> Result<Response<pb::PullRequest>, Status> {
        let r = request.into_inner();
        let created = self
            .service
            .create(
                &PathBuf::from(r.worktree_path),
                &r.title,
                &r.body,
                &r.base,
                r.draft,
            )
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(pull_request_to(&created)))
    }
}
