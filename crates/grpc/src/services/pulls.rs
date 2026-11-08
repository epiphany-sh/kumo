use std::path::PathBuf;
use std::sync::Arc;

use kumo_application::pulls::PullRequestService;
use kumo_domain::pulls::ThreadAnswer;
use kumo_proto::v1 as pb;
use tonic::{Request, Response, Status};

use crate::mapping::{
    branch_pull_request_to, pipelines_status_from, pull_request_list_to, pull_request_to,
    review_thread_to,
};
use crate::profile::{Profiles, services_of};

/// `kumo.v1.PullRequests`.
#[derive(Debug, Clone)]
pub struct PullRequestsGrpc {
    profiles: Arc<Profiles>,
}

impl PullRequestsGrpc {
    pub fn new(profiles: Arc<Profiles>) -> Self {
        Self { profiles }
    }

    /// The pulls service of the profile the call names.
    async fn service<T>(&self, request: &Request<T>) -> Result<Arc<PullRequestService>, Status> {
        Ok(Arc::clone(
            &services_of(&self.profiles, request).await?.pulls,
        ))
    }
}

#[tonic::async_trait]
impl pb::pull_requests_server::PullRequests for PullRequestsGrpc {
    async fn list(
        &self,
        request: Request<pb::ListPullRequestsRequest>,
    ) -> Result<Response<pb::PullRequestList>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let list = service
            .list(&PathBuf::from(r.repo_path), r.refresh)
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(pull_request_list_to(&list)))
    }

    async fn for_branch(
        &self,
        request: Request<pb::BranchPullRequestRequest>,
    ) -> Result<Response<pb::BranchPullRequest>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let branch = service
            .for_branch(&PathBuf::from(r.worktree_path), r.refresh)
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(branch_pull_request_to(&branch)))
    }

    async fn create(
        &self,
        request: Request<pb::CreatePullRequestRequest>,
    ) -> Result<Response<pb::PullRequest>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let created = service
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

    async fn threads(
        &self,
        request: Request<pb::PullRequestThreadsRequest>,
    ) -> Result<Response<pb::ThreadList>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let threads = service
            .threads(&PathBuf::from(r.repo_path), r.number)
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(pb::ThreadList {
            threads: threads.iter().map(review_thread_to).collect(),
        }))
    }

    async fn answer_thread(
        &self,
        request: Request<pb::AnswerThreadRequest>,
    ) -> Result<Response<pb::ReviewThread>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let answer = ThreadAnswer {
            thread_id: r.thread_id,
            reply: r.reply,
            resolve: r.resolve,
        };
        let thread = service
            .answer_thread(&PathBuf::from(r.repo_path), r.number, answer)
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(review_thread_to(&thread)))
    }
}
