//! Pull requests (GitLab: merge requests) of the workspace's repositories,
//! read from their host with the same tokens as pipelines.

mod model;
mod ports;

pub use model::{NewPullRequest, PrState, PullRequest, ReviewState};
pub use ports::PullRequestClient;
