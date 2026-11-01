use super::{Profile, ProfileError, ProfileId};

/// The registry of profiles and their data folders.
pub trait ProfileStore: Send + Sync + 'static {
    /// None before the first save (a data folder from before profiles).
    fn load(&self) -> Result<Option<Vec<Profile>>, ProfileError>;
    fn save(&self, profiles: &[Profile]) -> Result<(), ProfileError>;
    /// Deletes a profile's data folder. Never the default profile's, which
    /// is Kumo's data folder itself.
    fn remove_data(&self, id: &ProfileId) -> Result<(), ProfileError>;
}
