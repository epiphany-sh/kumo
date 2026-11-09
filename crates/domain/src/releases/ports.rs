//! Ports implemented by the infrastructure layer. Blocking: callers run
//! them off the async runtime.

use std::path::Path;

use crate::pipelines::{CiProblem, CiProvider, CiTarget};

use super::{GitTag, Release, ReleaseEdit, ReleaseRange};

/// One host's releases. `target.branch` is ignored.
pub trait ReleaseClient: Send + Sync + 'static {
    fn provider(&self) -> CiProvider;

    /// Whether the host has releases at all (Bitbucket: tags only). When
    /// not, [`list`](Self::list) and [`edit`](Self::edit) aren't called.
    fn has_releases(&self) -> bool {
        true
    }

    /// The host's releases (not bare tags), at most `limit`.
    fn list(&self, target: &CiTarget, token: &str, limit: usize)
    -> Result<Vec<Release>, CiProblem>;

    /// Changes `tag`'s release, or creates it when the tag has none.
    fn edit(
        &self,
        target: &CiTarget,
        token: &str,
        tag: &str,
        edit: &ReleaseEdit,
    ) -> Result<Release, CiProblem>;

    /// The tag's page on the host.
    fn tag_url(&self, target: &CiTarget, tag: &str) -> String;
}

/// Tags and history between them, through git, on a repository's main
/// checkout. Errors are git's message.
pub trait GitTags: Send + Sync + 'static {
    /// Brings in the remote's tags.
    fn fetch_tags(&self, repo: &Path) -> Result<(), String>;

    /// Newest version first.
    fn tags(&self, repo: &Path) -> Result<Vec<GitTag>, String>;

    /// What changed in `tag` since `since` (None: since the first commit).
    /// When `since` isn't an ancestor of `tag`, from their merge base.
    fn range(&self, repo: &Path, tag: &str, since: Option<&str>) -> Result<ReleaseRange, String>;
}
