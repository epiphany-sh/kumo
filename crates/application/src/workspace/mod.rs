//! Workspace use cases: namespaces of repositories and their worktrees.

mod presence;
mod schedule;
mod service;
mod sync;
#[cfg(test)]
mod tests;

pub use presence::ClientLease;
pub use schedule::Presence;
pub use service::{WorkspacePorts, WorkspaceService};
