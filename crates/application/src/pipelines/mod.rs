//! Pipeline use cases: watch the CI runs of a worktree's branch (one poller
//! per watched worktree, shared by its watchers), refresh, re-run failed
//! jobs, and the hosts' tokens.

mod service;

pub use service::{PipelinesPorts, PipelinesService, PipelinesTiming, TerminalLauncher};

#[cfg(test)]
mod tests;
