//! Conversions between protobuf messages and domain types.

mod agents;
mod changes;
mod error;
mod terminal;
mod workspace;

pub use agents::{agent_session_to, agents_snapshot_to, provider_to};
pub use changes::{commit_to, diff_scope_from, diff_to, worktree_changes_to};
pub use error::{agents_status_from, changes_status_from, status_from, workspace_status_from};
pub use terminal::{launch_spec_from, size_from, terminal_info_to, terminal_output_to};
pub use workspace::{candidate_to, snapshot_to, worktree_to};
