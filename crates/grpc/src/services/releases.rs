use std::path::PathBuf;
use std::sync::Arc;

use kumo_application::releases::ReleaseService;
use kumo_domain::releases::ReleaseEdit;
use kumo_proto::v1 as pb;
use tonic::{Request, Response, Status};

use crate::mapping::{pipelines_status_from, release_list_to, release_range_to, release_to};
use crate::profile::{Profiles, services_of};

/// `kumo.v1.Releases`.
#[derive(Debug, Clone)]
pub struct ReleasesGrpc {
    profiles: Arc<Profiles>,
}

impl ReleasesGrpc {
    pub fn new(profiles: Arc<Profiles>) -> Self {
        Self { profiles }
    }

    /// The releases service of the profile the call names.
    async fn service<T>(&self, request: &Request<T>) -> Result<Arc<ReleaseService>, Status> {
        Ok(Arc::clone(
            &services_of(&self.profiles, request).await?.releases,
        ))
    }
}

#[tonic::async_trait]
impl pb::releases_server::Releases for ReleasesGrpc {
    async fn list(
        &self,
        request: Request<pb::ListReleasesRequest>,
    ) -> Result<Response<pb::ReleaseList>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let list = service
            .list(&PathBuf::from(r.repo_path), r.limit as usize, r.refresh)
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(release_list_to(&list)))
    }

    async fn range(
        &self,
        request: Request<pb::ReleaseRangeRequest>,
    ) -> Result<Response<pb::ReleaseRange>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let range = service
            .range(&PathBuf::from(r.repo_path), &r.tag, &r.since)
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(release_range_to(&range)))
    }

    async fn edit(
        &self,
        request: Request<pb::EditReleaseRequest>,
    ) -> Result<Response<pb::Release>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let edit = ReleaseEdit {
            name: r.name,
            notes: r.notes,
            publish: r.publish,
            sha: String::new(),
        };
        let release = service
            .edit(&PathBuf::from(r.repo_path), &r.tag, edit)
            .await
            .map_err(pipelines_status_from)?;
        Ok(Response::new(release_to(&release)))
    }
}
