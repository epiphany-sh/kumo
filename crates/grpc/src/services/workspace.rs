use std::path::PathBuf;
use std::pin::Pin;
use std::sync::Arc;

use futures::{Stream, StreamExt};
use kumo_application::workspace::WorkspaceService;
use kumo_domain::workspace::NamespaceId;
use kumo_proto::v1 as pb;
use tokio_stream::wrappers::WatchStream;
use tonic::{Request, Response, Status};

use crate::mapping::{candidate_to, snapshot_to, workspace_status_from, worktree_to};
use crate::profile::{Profiles, services_of};

type SnapshotStream = Pin<Box<dyn Stream<Item = Result<pb::WorkspaceSnapshot, Status>> + Send>>;

/// `kumo.v1.Workspace`.
#[derive(Debug, Clone)]
pub struct WorkspaceGrpc {
    profiles: Arc<Profiles>,
}

impl WorkspaceGrpc {
    pub fn new(profiles: Arc<Profiles>) -> Self {
        Self { profiles }
    }

    /// The workspace service of the profile the call names.
    async fn service<T>(&self, request: &Request<T>) -> Result<Arc<WorkspaceService>, Status> {
        Ok(Arc::clone(
            &services_of(&self.profiles, request).await?.workspace,
        ))
    }
}

#[tonic::async_trait]
impl pb::workspace_server::Workspace for WorkspaceGrpc {
    type WatchStream = SnapshotStream;

    async fn watch(
        &self,
        request: Request<pb::WatchWorkspaceRequest>,
    ) -> Result<Response<Self::WatchStream>, Status> {
        let service = self.service(&request).await?;
        let snapshots =
            WatchStream::new(service.watch()).map(|snapshot| Ok(snapshot_to(&snapshot)));
        Ok(Response::new(Box::pin(snapshots)))
    }

    async fn refresh(
        &self,
        request: Request<pb::RefreshWorkspaceRequest>,
    ) -> Result<Response<pb::RefreshWorkspaceResponse>, Status> {
        let service = self.service(&request).await?;
        service.refresh().await;
        Ok(Response::new(pb::RefreshWorkspaceResponse {}))
    }

    async fn discover_repos(
        &self,
        request: Request<pb::DiscoverReposRequest>,
    ) -> Result<Response<pb::DiscoverReposResponse>, Status> {
        let service = self.service(&request).await?;
        let roots = request
            .into_inner()
            .roots
            .into_iter()
            .map(PathBuf::from)
            .collect();
        let candidates = service
            .discover(roots)
            .await
            .iter()
            .map(candidate_to)
            .collect();
        Ok(Response::new(pb::DiscoverReposResponse { candidates }))
    }

    async fn save_namespace(
        &self,
        request: Request<pb::SaveNamespaceRequest>,
    ) -> Result<Response<pb::SaveNamespaceResponse>, Status> {
        let service = self.service(&request).await?;
        let request = request.into_inner();
        let id = service
            .save_namespace(
                NamespaceId::parse(&request.id),
                &request.name,
                request.repo_paths.into_iter().map(PathBuf::from).collect(),
                request.collapsed,
                request.position.map(|p| p as usize),
            )
            .await
            .map_err(workspace_status_from)?;
        Ok(Response::new(pb::SaveNamespaceResponse {
            id: id.to_string(),
        }))
    }

    async fn delete_namespace(
        &self,
        request: Request<pb::DeleteNamespaceRequest>,
    ) -> Result<Response<pb::DeleteNamespaceResponse>, Status> {
        let service = self.service(&request).await?;
        let id = NamespaceId::parse(&request.into_inner().id)
            .ok_or_else(|| Status::invalid_argument("namespace id is empty"))?;
        service
            .delete_namespace(&id)
            .await
            .map_err(workspace_status_from)?;
        Ok(Response::new(pb::DeleteNamespaceResponse {}))
    }

    async fn create_worktree(
        &self,
        request: Request<pb::CreateWorktreeRequest>,
    ) -> Result<Response<pb::CreateWorktreeResponse>, Status> {
        let service = self.service(&request).await?;
        let request = request.into_inner();
        let base = Some(request.base).filter(|b| !b.trim().is_empty());
        let worktree = service
            .create_worktree(
                PathBuf::from(request.repo_path).as_path(),
                &request.branch,
                request.create_branch,
                base,
                &request.path,
            )
            .await
            .map_err(workspace_status_from)?;
        Ok(Response::new(pb::CreateWorktreeResponse {
            worktree: Some(worktree_to(&worktree)),
        }))
    }

    async fn remove_worktree(
        &self,
        request: Request<pb::RemoveWorktreeRequest>,
    ) -> Result<Response<pb::RemoveWorktreeResponse>, Status> {
        let service = self.service(&request).await?;
        let request = request.into_inner();
        let removal = service
            .remove_worktree(
                PathBuf::from(request.repo_path).as_path(),
                PathBuf::from(request.worktree_path).as_path(),
                request.force,
                request.delete_branch,
            )
            .await
            .map_err(workspace_status_from)?;
        Ok(Response::new(pb::RemoveWorktreeResponse {
            removed: removal.removed,
            changed_files: removal.changed_files,
            branch_kept: removal.branch_kept.unwrap_or_default(),
        }))
    }

    async fn list_branches(
        &self,
        request: Request<pb::ListBranchesRequest>,
    ) -> Result<Response<pb::ListBranchesResponse>, Status> {
        let service = self.service(&request).await?;
        let path = PathBuf::from(request.into_inner().repo_path);
        let branches = service
            .branches(&path)
            .await
            .map_err(workspace_status_from)?;
        Ok(Response::new(pb::ListBranchesResponse {
            current: branches.current.unwrap_or_default(),
            local: branches.local,
            remote: branches.remote,
        }))
    }
}
