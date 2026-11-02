use std::pin::Pin;
use std::sync::Arc;

use futures::{Stream, StreamExt};
use kumo_domain::profiles::{MachineAccounts, ProfileChanges};
use kumo_proto::v1 as pb;
use tonic::{Request, Response, Status};

use crate::mapping::{
    gh_account_from, gh_account_to, profile_list_to, profile_status_from, profile_to, ssh_key_to,
};
use crate::profile::{Profiles, profile_of};

type ProfileListStream = Pin<Box<dyn Stream<Item = Result<pb::ProfileList, Status>> + Send>>;

/// `kumo.v1.Profiles`: the UI's workspaces.
#[derive(Clone)]
pub struct ProfilesGrpc {
    profiles: Arc<Profiles>,
    machine: Arc<dyn MachineAccounts>,
}

impl std::fmt::Debug for ProfilesGrpc {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ProfilesGrpc").finish_non_exhaustive()
    }
}

impl ProfilesGrpc {
    pub fn new(profiles: Arc<Profiles>, machine: Arc<dyn MachineAccounts>) -> Self {
        Self { profiles, machine }
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
            ssh_key: r.ssh_key,
            sign_commits: r.sign_commits,
            gh_accounts: r
                .gh_accounts
                .map(|list| list.accounts.into_iter().map(gh_account_from).collect()),
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

    async fn list_ssh_keys(
        &self,
        _request: Request<pb::ListSshKeysRequest>,
    ) -> Result<Response<pb::SshKeyList>, Status> {
        let machine = Arc::clone(&self.machine);
        let keys = tokio::task::spawn_blocking(move || machine.ssh_keys())
            .await
            .map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(pb::SshKeyList {
            keys: keys.into_iter().map(ssh_key_to).collect(),
        }))
    }

    async fn list_gh_accounts(
        &self,
        _request: Request<pb::ListGhAccountsRequest>,
    ) -> Result<Response<pb::GhAccountList>, Status> {
        let machine = Arc::clone(&self.machine);
        let accounts = tokio::task::spawn_blocking(move || machine.gh_accounts())
            .await
            .map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(pb::GhAccountList {
            accounts: accounts.iter().map(gh_account_to).collect(),
        }))
    }

    async fn git_credential(
        &self,
        request: Request<pb::GitCredentialRequest>,
    ) -> Result<Response<pb::GitCredentialResponse>, Status> {
        let profile = profile_of(request.metadata()).map(str::to_owned);
        let host = request.into_inner().host.trim().to_lowercase();
        // Never logged: the answer is a token.
        let credential = self
            .profiles
            .git_credential(profile.as_deref(), &host)
            .await
            .map_err(profile_status_from)?;
        Ok(Response::new(credential.map_or_else(
            pb::GitCredentialResponse::default,
            |c| pb::GitCredentialResponse {
                username: c.username,
                password: c.password,
            },
        )))
    }
}
