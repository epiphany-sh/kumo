//! The user's workspace: namespaces (sidebar groups) of git repositories and
//! the worktrees of each repository.
//!
//! A repository is identified by the absolute path of its main checkout, a
//! worktree by its path. Branch names are for display only: `main` exists
//! in every repository.

mod branch_name;
mod error;
mod location;
mod namespace;
mod ports;
mod remote;
mod repo;
mod snapshot;
mod worktree;

pub use branch_name::BranchName;
pub use error::WorkspaceError;
pub use location::WorktreeLocation;
pub use namespace::{Namespace, NamespaceId};
pub use ports::{Git, RepoFinder, StoredWorkspace, WorkspaceStore};
pub use remote::{GitHost, Remote};
pub use repo::Repo;
pub use snapshot::{RepoState, WorkspaceSnapshot};
pub use worktree::{Branches, NewWorktree, Worktree, WorktreeRemoval, WorktreeStatus};
