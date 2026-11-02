use super::{GhAccount, Profile, ProfileError, ProfileId};

/// The registry of profiles and their data folders.
pub trait ProfileStore: Send + Sync + 'static {
    /// None before the first save (a data folder from before profiles).
    fn load(&self) -> Result<Option<Vec<Profile>>, ProfileError>;
    fn save(&self, profiles: &[Profile]) -> Result<(), ProfileError>;
    /// Deletes a profile's data folder. Never the default profile's, which
    /// is Kumo's data folder itself.
    fn remove_data(&self, id: &ProfileId) -> Result<(), ProfileError>;
}

/// An SSH key in `~/.ssh`. Kumo knows where it is, never what it holds.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SshKey {
    /// `id_ed25519`.
    pub name: String,
    /// What a profile stores: `~/.ssh/id_ed25519`, or the `.pub` when only
    /// that is on disk (an agent holds the key).
    pub path: String,
    /// `SHA256:…`, as `ssh-keygen -l` shows it; empty if it can't tell.
    pub fingerprint: String,
    /// `ed25519`, `rsa`…
    pub kind: String,
    /// Only the `.pub` is on disk.
    pub agent_only: bool,
}

/// What the machine offers to pick from in a profile's settings. Blocking.
pub trait MachineAccounts: Send + Sync + 'static {
    fn ssh_keys(&self) -> Vec<SshKey>;
    /// Every account `gh` is signed in to, per host.
    fn gh_accounts(&self) -> Vec<GhAccount>;
}
