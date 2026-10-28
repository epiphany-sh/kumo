//! Pull request use cases: a repository's open pull requests, a worktree
//! branch's pull request, and opening one. Same hosts and tokens as
//! pipelines.

mod service;

pub use service::{BranchPullRequest, PullRequestList, PullRequestPorts, PullRequestService};

#[cfg(test)]
mod tests;
