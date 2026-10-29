//! Conversions between protobuf messages and domain types.

mod agents;
mod changes;
mod docs;
mod error;
mod pipelines;
mod pulls;
mod tasks;
mod terminal;
mod tests;
mod workspace;

pub use agents::{agent_context_from, agent_session_to, agents_snapshot_to, provider_to};
pub use changes::{commit_to, diff_scope_from, diff_to, worktree_changes_to};
pub use docs::{doc_list_to, doc_to};
pub use error::{
    agents_status_from, changes_status_from, pipelines_status_from, status_from, tasks_status_from,
    workspace_status_from,
};
pub use pipelines::{ci_problem_to, host_info_to, pipelines_snapshot_to};
pub use pulls::{branch_pull_request_to, pull_request_list_to, pull_request_to};
pub use tasks::{
    detected_to, source_options_from, source_to, task_detail_to, task_link_to, task_status_from,
    task_to, tasks_update_to,
};
pub use terminal::{launch_spec_from, size_from, terminal_info_to, terminal_output_to};
pub use tests::{test_run_to, tests_snapshot_to, tests_status_from};
pub use workspace::{candidate_to, snapshot_to, worktree_to};
