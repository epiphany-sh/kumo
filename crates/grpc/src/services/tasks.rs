use std::collections::HashMap;
use std::path::PathBuf;
use std::pin::Pin;
use std::sync::Arc;

use futures::{Stream, StreamExt, future};
use kumo_application::tasks::TaskService;
use kumo_domain::tasks::{SourceId, TaskId};
use kumo_proto::v1 as pb;
use tokio_stream::wrappers::WatchStream;
use tonic::{Request, Response, Status};

use crate::mapping::{
    detected_to, source_options_from, source_to, task_detail_to, task_link_to, task_status_from,
    task_to, tasks_status_from, tasks_update_to,
};

type UpdateStream = Pin<Box<dyn Stream<Item = Result<pb::TasksUpdate, Status>> + Send>>;

/// `kumo.v1.Tasks`.
#[derive(Debug, Clone)]
pub struct TasksGrpc {
    service: Arc<TaskService>,
}

impl TasksGrpc {
    pub fn new(service: Arc<TaskService>) -> Self {
        Self { service }
    }
}

fn source_id(raw: &str) -> Result<SourceId, Status> {
    SourceId::parse(raw).map_err(tasks_status_from)
}

/// Empty means "none" (a new source, the stored token).
fn optional(raw: String) -> Option<String> {
    Some(raw).filter(|s| !s.trim().is_empty())
}

#[tonic::async_trait]
impl pb::tasks_server::Tasks for TasksGrpc {
    type WatchStream = UpdateStream;

    async fn watch(
        &self,
        _request: Request<pb::WatchTasksRequest>,
    ) -> Result<Response<Self::WatchStream>, Status> {
        let updates = WatchStream::new(self.service.watch()).scan(HashMap::new(), |sent, board| {
            future::ready(Some(Ok(tasks_update_to(&board, sent))))
        });
        Ok(Response::new(Box::pin(updates)))
    }

    async fn detect(
        &self,
        _request: Request<pb::DetectSourcesRequest>,
    ) -> Result<Response<pb::DetectSourcesResponse>, Status> {
        let detected = self.service.detect().await.map_err(tasks_status_from)?;
        Ok(Response::new(pb::DetectSourcesResponse {
            sources: detected.into_iter().map(detected_to).collect(),
        }))
    }

    async fn test_source(
        &self,
        request: Request<pb::TestSourceRequest>,
    ) -> Result<Response<pb::TestSourceResponse>, Status> {
        let r = request.into_inner();
        let id = optional(r.id).map(|id| source_id(&id)).transpose()?;
        let options = source_options_from(r.kind, r.options).map_err(tasks_status_from)?;
        let message = self
            .service
            .test_source(id, options, optional(r.secret))
            .await
            .map_err(tasks_status_from)?;
        Ok(Response::new(pb::TestSourceResponse { message }))
    }

    async fn save_source(
        &self,
        request: Request<pb::SaveSourceRequest>,
    ) -> Result<Response<pb::TaskSource>, Status> {
        let r = request.into_inner();
        let id = optional(r.id).map(|id| source_id(&id)).transpose()?;
        let options = source_options_from(r.kind, r.options).map_err(tasks_status_from)?;
        let view = self
            .service
            .save_source(id, &r.name, options, r.enabled, optional(r.secret))
            .await
            .map_err(tasks_status_from)?;
        Ok(Response::new(source_to(&view)))
    }

    async fn delete_source(
        &self,
        request: Request<pb::DeleteSourceRequest>,
    ) -> Result<Response<pb::DeleteSourceResponse>, Status> {
        let id = source_id(&request.into_inner().id)?;
        self.service
            .delete_source(&id)
            .await
            .map_err(tasks_status_from)?;
        Ok(Response::new(pb::DeleteSourceResponse {}))
    }

    async fn sync(
        &self,
        request: Request<pb::SyncTasksRequest>,
    ) -> Result<Response<pb::SyncTasksResponse>, Status> {
        let id = optional(request.into_inner().source_id)
            .map(|id| source_id(&id))
            .transpose()?;
        self.service.sync(id.as_ref()).map_err(tasks_status_from)?;
        Ok(Response::new(pb::SyncTasksResponse {}))
    }

    async fn set_status(
        &self,
        request: Request<pb::SetTaskStatusRequest>,
    ) -> Result<Response<pb::Task>, Status> {
        let r = request.into_inner();
        let id = TaskId::parse(&r.task_id).map_err(tasks_status_from)?;
        let status = task_status_from(r.status)?;
        let task = self
            .service
            .set_status(&id, status)
            .await
            .map_err(tasks_status_from)?;
        Ok(Response::new(task_to(&task)))
    }

    async fn link(
        &self,
        request: Request<pb::LinkTaskRequest>,
    ) -> Result<Response<pb::TaskLink>, Status> {
        let r = request.into_inner();
        let id = TaskId::parse(&r.task_id).map_err(tasks_status_from)?;
        if r.worktree_path.trim().is_empty() {
            return Err(Status::invalid_argument("worktree path is empty"));
        }
        let link = self
            .service
            .link(id, PathBuf::from(r.worktree_path), r.branch)
            .await
            .map_err(tasks_status_from)?;
        Ok(Response::new(task_link_to(&link)))
    }

    async fn get_task(
        &self,
        request: Request<pb::GetTaskRequest>,
    ) -> Result<Response<pb::TaskDetail>, Status> {
        let r = request.into_inner();
        let id = TaskId::parse(&r.id).map_err(tasks_status_from)?;
        let detail = self
            .service
            .get_task(&id, r.refresh)
            .await
            .map_err(tasks_status_from)?;
        Ok(Response::new(task_detail_to(&detail)))
    }

    async fn unlink(
        &self,
        request: Request<pb::UnlinkTaskRequest>,
    ) -> Result<Response<pb::UnlinkTaskResponse>, Status> {
        let r = request.into_inner();
        let id = TaskId::parse(&r.task_id).map_err(tasks_status_from)?;
        self.service
            .unlink(&id, &PathBuf::from(r.worktree_path))
            .await
            .map_err(tasks_status_from)?;
        Ok(Response::new(pb::UnlinkTaskResponse {}))
    }
}
