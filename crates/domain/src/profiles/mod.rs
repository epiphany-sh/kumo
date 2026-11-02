//! Profiles: the "workspaces" of the UI. Each one has its own accounts,
//! tokens, namespaces and agents; switching profiles switches everything
//! the app shows and uses.
//!
//! The engine calls them profiles because [`crate::workspace`] already
//! means namespaces, repositories and worktrees.

mod error;
mod git;
mod id;
mod ports;
mod profile;

pub use error::ProfileError;
pub use git::{GitSetup, ProfileEnv, shell_quote};
pub use id::ProfileId;
pub use ports::{MachineAccounts, ProfileStore, SshKey};
pub use profile::{GhAccount, Profile, ProfileActivity, ProfileChanges};
