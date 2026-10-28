use crate::pipelines::{CiProblem, CiProvider, CiTarget};

use super::{NewPullRequest, PullRequest};

/// One host's pull requests. Blocking: callers run it off the async
/// runtime. `target.branch` is ignored by [`list`](Self::list).
pub trait PullRequestClient: Send + Sync + 'static {
    fn provider(&self) -> CiProvider;

    /// Open pull requests, most recently updated first (at most `limit`).
    fn list(
        &self,
        target: &CiTarget,
        token: &str,
        limit: usize,
    ) -> Result<Vec<PullRequest>, CiProblem>;

    /// The branch's pull request: the open one, else the latest merged or
    /// closed one; None when it never had one.
    fn for_branch(&self, target: &CiTarget, token: &str) -> Result<Option<PullRequest>, CiProblem>;

    fn create(
        &self,
        target: &CiTarget,
        token: &str,
        new: &NewPullRequest,
    ) -> Result<PullRequest, CiProblem>;
}
