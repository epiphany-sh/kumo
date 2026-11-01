use std::pin::Pin;
use std::sync::Arc;

use futures::{Stream, StreamExt};
use kumo_domain::profiles::ProfileChanges;
use kumo_proto::v1 as pb;
use tonic::{Request, Response, Status};

use crate::mapping::{profile_list_to, profile_status_from, profile_to};
use crate::profile::{Profiles, profile_of};

type ProfileListStream = Pin<Box<dyn Stream<Item = Result<pb::ProfileList, Status>> + Send>>;

/// `kumo.v1.Profiles`: the UI's workspaces.
#[derive(Debug, Clone)]
pub struct ProfilesGrpc {
    profiles: Arc<Profiles>,
}

impl ProfilesGrpc {
    pub fn new(profiles: Arc<Profiles>) -> Self {
        Self { profiles }
    }

    async fn view(&self, id: &str) -> Result<pb::Profile, Status> {
        self.profiles
            .list()
            .await
            .iter()
            .find(|v| v.profile.id.as_str() == id)
            .map(profile_to)
            .ok_or_else(|| Status::not_found(format!("unknown workspace: {id}")))
    }
}

#[tonic::async_trait]
impl pb::profiles_server::Profiles for ProfilesGrpc {
    type WatchStream = ProfileListStream;

    async fn list(
        &self,
        _request: Request<pb::ListProfilesRequest>,
    ) -> Result<Response<pb::ProfileList>, Status> {
        Ok(Response::new(profile_list_to(&self.profiles.list().await)))
    }

    async fn create(
        &self,
        request: Request<pb::CreateProfileRequest>,
    ) -> Result<Response<pb::Profile>, Status> {
        let r = request.into_inner();
        let created = self
            .profiles
            .create(&r.name, &r.color, Some(r.copy_agents_from.as_str()))
            .await
            .map_err(profile_status_from)?;
        Ok(Response::new(self.view(created.id.as_str()).await?))
    }

    async fn update(
        &self,
        request: Request<pb::UpdateProfileRequest>,
    ) -> Result<Response<pb::Profile>, Status> {
        let r = request.into_inner();
        let changes = ProfileChanges {
            name: r.name,
            color: r.color,
            position: r.position,
            worktrees_dir: r.worktrees_dir,
            git_name: r.git_name,
            git_email: r.git_email,
        };
        let updated = self
            .profiles
            .update(&r.id, changes)
            .await
            .map_err(profile_status_from)?;
        Ok(Response::new(self.view(updated.id.as_str()).await?))
    }

    async fn delete(
        &self,
        request: Request<pb::DeleteProfileRequest>,
    ) -> Result<Response<pb::DeleteProfileResponse>, Status> {
        self.profiles
            .delete(&request.into_inner().id)
            .await
            .map_err(profile_status_from)?;
        Ok(Response::new(pb::DeleteProfileResponse {}))
    }

    async fn watch(
        &self,
        request: Request<pb::WatchProfilesRequest>,
    ) -> Result<Response<Self::WatchStream>, Status> {
        // The window's profile is in use while it watches.
        let window = self
            .profiles
            .connect(profile_of(request.metadata()))
            .map_err(profile_status_from)?;
        let stream = self.profiles.watch().map(move |views| {
            let _window = &window;
            Ok(profile_list_to(&views))
        });
        Ok(Response::new(Box::pin(stream)))
    }
}
