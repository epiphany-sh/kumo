//! The `kumo-profile` header: which profile (workspace) a call acts on.

use std::sync::Arc;

use kumo_application::profiles::{ProfileService, ProfileServices};
use tonic::metadata::{AsciiMetadataValue, MetadataMap};
use tonic::service::Interceptor;
use tonic::{Request, Status};

use crate::mapping::profile_status_from;

pub const PROFILE_HEADER: &str = "kumo-profile";

/// The profile registry and the per-profile services, as the server uses it.
pub type Profiles = ProfileService<ProfileServices>;

/// The profile a call names; None when it names none (clients from before
/// profiles), which means the default profile.
pub fn profile_of(metadata: &MetadataMap) -> Option<&str> {
    metadata
        .get(PROFILE_HEADER)
        .and_then(|value| value.to_str().ok())
        .map(str::trim)
        .filter(|id| !id.is_empty())
}

/// The services of the profile `request` names.
pub(crate) async fn services_of<T>(
    profiles: &Profiles,
    request: &Request<T>,
) -> Result<Arc<ProfileServices>, Status> {
    profiles
        .resolve(profile_of(request.metadata()))
        .await
        .map_err(profile_status_from)
}

/// Client side: attaches `kumo-profile: <id>` to every call.
#[derive(Debug, Clone)]
pub struct AttachProfile {
    header: Option<AsciiMetadataValue>,
}

impl AttachProfile {
    /// None: no header (the default profile).
    pub fn new(profile: Option<&str>) -> Self {
        Self {
            header: profile.and_then(|id| AsciiMetadataValue::try_from(id).ok()),
        }
    }
}

impl Interceptor for AttachProfile {
    fn call(&mut self, mut request: Request<()>) -> Result<Request<()>, Status> {
        if let Some(header) = &self.header {
            request
                .metadata_mut()
                .insert(PROFILE_HEADER, header.clone());
        }
        Ok(request)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_the_header_and_treats_blank_as_none() {
        let request = AttachProfile::new(Some("workspace-1"))
            .call(Request::new(()))
            .unwrap();
        assert_eq!(profile_of(request.metadata()), Some("workspace-1"));

        let none = AttachProfile::new(None).call(Request::new(())).unwrap();
        assert_eq!(profile_of(none.metadata()), None);

        let mut blank = Request::new(());
        blank
            .metadata_mut()
            .insert(PROFILE_HEADER, AsciiMetadataValue::from_static(" "));
        assert_eq!(profile_of(blank.metadata()), None);
    }
}
