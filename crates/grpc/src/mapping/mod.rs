//! Conversions between protobuf messages and domain types.

mod changes;
mod error;
mod terminal;
mod workspace;

pub use changes::{commit_to, diff_scope_from, diff_to, worktree_changes_to};
pub use error::{changes_status_from, status_from, workspace_status_from};
pub use terminal::{launch_spec_from, size_from, terminal_info_to, terminal_output_to};
pub use workspace::{candidate_to, snapshot_to, worktree_to};
