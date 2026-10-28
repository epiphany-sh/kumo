use std::path::PathBuf;
use std::pin::Pin;
use std::sync::Arc;

use futures::{Stream, StreamExt};
use kumo_application::changes::ChangesService;
use kumo_domain::changes::CommitOptions;
use kumo_proto::v1 as pb;
use tokio_stream::wrappers::ReceiverStream;
use tonic::{Request, Response, Status};

use crate::mapping::{
    changes_status_from, commit_to, diff_scope_from, diff_to, worktree_changes_to,
};

type StatusStream = Pin<Box<dyn Stream<Item = Result<pb::WorktreeChanges, Status>> + Send>>;

/// `kumo.v1.Git`.
#[derive(Debug, Clone)]
pub struct GitGrpc {
    service: Arc<ChangesService>,
}

impl GitGrpc {
    pub fn new(service: Arc<ChangesService>) -> Self {
        Self { service }
    }
}

fn path(raw: String) -> PathBuf {
    PathBuf::from(raw)
}

fn done(
    result: Result<(), kumo_domain::changes::ChangesError>,
) -> Result<Response<pb::GitActionResponse>, Status> {
    result.map_err(changes_status_from)?;
    Ok(Response::new(pb::GitActionResponse {}))
}

#[tonic::async_trait]
impl pb::git_server::Git for GitGrpc {
    type WatchStatusStream = StatusStream;

    async fn watch_status(
        &self,
        request: Request<pb::WatchStatusRequest>,
    ) -> Result<Response<Self::WatchStatusStream>, Status> {
        let worktree = path(request.into_inner().worktree_path);
        let updates = self
            .service
            .watch_status(&worktree)
            .await
            .map_err(changes_status_from)?;
        let stream = ReceiverStream::new(updates)
            .map(|status| status.map(worktree_changes_to).map_err(changes_status_from));
        Ok(Response::new(Box::pin(stream)))
    }

    async fn list_files(
        &self,
        request: Request<pb::ListFilesRequest>,
    ) -> Result<Response<pb::ListFilesResponse>, Status> {
        let list = self
            .service
            .list_files(&path(request.into_inner().worktree_path))
            .await
            .map_err(changes_status_from)?;
        Ok(Response::new(pb::ListFilesResponse {
            paths: list.paths,
            truncated: list.truncated,
        }))
    }

    async fn read_file(
        &self,
        request: Request<pb::ReadFileRequest>,
    ) -> Result<Response<pb::ReadFileResponse>, Status> {
        let request = request.into_inner();
        let file = self
            .service
            .read_file(&path(request.worktree_path), &request.path)
            .await
            .map_err(changes_status_from)?;
        Ok(Response::new(pb::ReadFileResponse {
            content: file.bytes.into(),
            binary: file.binary,
            truncated: file.truncated,
            size: file.size,
        }))
    }

    async fn write_file(
        &self,
        request: Request<pb::WriteFileRequest>,
    ) -> Result<Response<pb::WriteFileResponse>, Status> {
        let request = request.into_inner();
        self.service
            .write_file(
                &path(request.worktree_path),
                &request.path,
                request.content.to_vec(),
            )
            .await
            .map_err(changes_status_from)?;
        Ok(Response::new(pb::WriteFileResponse {}))
    }

    async fn diff(
        &self,
        request: Request<pb::DiffRequest>,
    ) -> Result<Response<pb::DiffResponse>, Status> {
        let request = request.into_inner();
        let scope = diff_scope_from(request.scope());
        let diff = self
            .service
            .diff(&path(request.worktree_path), &request.path, scope)
            .await
            .map_err(changes_status_from)?;
        Ok(Response::new(diff_to(diff)))
    }

    async fn stage(
        &self,
        request: Request<pb::PathsRequest>,
    ) -> Result<Response<pb::GitActionResponse>, Status> {
        let request = request.into_inner();
        done(
            self.service
                .stage(&path(request.worktree_path), &request.paths)
                .await,
        )
    }

    async fn unstage(
        &self,
        request: Request<pb::PathsRequest>,
    ) -> Result<Response<pb::GitActionResponse>, Status> {
        let request = request.into_inner();
        done(
            self.service
                .unstage(&path(request.worktree_path), &request.paths)
                .await,
        )
    }

    async fn restore(
        &self,
        request: Request<pb::PathsRequest>,
    ) -> Result<Response<pb::GitActionResponse>, Status> {
        let request = request.into_inner();
        done(
            self.service
                .restore(&path(request.worktree_path), &request.paths)
                .await,
        )
    }

    async fn commit(
        &self,
        request: Request<pb::CommitRequest>,
    ) -> Result<Response<pb::CommitResponse>, Status> {
        let request = request.into_inner();
        let options = CommitOptions {
            message: request.message,
            all: request.all,
            amend: request.amend,
        };
        let commit = self
            .service
            .commit(&path(request.worktree_path), options)
            .await
            .map_err(changes_status_from)?;
        Ok(Response::new(pb::CommitResponse {
            sha: commit.sha,
            short_sha: commit.short_sha,
        }))
    }

    async fn push(
        &self,
        request: Request<pb::WorktreeRequest>,
    ) -> Result<Response<pb::GitActionResponse>, Status> {
        done(
            self.service
                .push(&path(request.into_inner().worktree_path))
                .await,
        )
    }

    async fn undo_last_commit(
        &self,
        request: Request<pb::WorktreeRequest>,
    ) -> Result<Response<pb::GitActionResponse>, Status> {
        done(
            self.service
                .undo_last_commit(&path(request.into_inner().worktree_path))
                .await,
        )
    }

    async fn log(
        &self,
        request: Request<pb::LogRequest>,
    ) -> Result<Response<pb::LogResponse>, Status> {
        let request = request.into_inner();
        let limit = if request.limit == 0 {
            50
        } else {
            request.limit as usize
        };
        let commits = self
            .service
            .log(&path(request.worktree_path), limit)
            .await
            .map_err(changes_status_from)?;
        Ok(Response::new(pb::LogResponse {
            commits: commits.into_iter().map(commit_to).collect(),
        }))
    }
}
