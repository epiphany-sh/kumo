//! Bitbucket Cloud has tags but no releases.

use kumo_domain::pipelines::{CiProblem, CiProblemKind, CiProvider, CiTarget};
use kumo_domain::releases::{Release, ReleaseClient, ReleaseEdit};

use super::http::enc;

#[derive(Debug, Default)]
pub struct BitbucketReleases;

impl ReleaseClient for BitbucketReleases {
    fn provider(&self) -> CiProvider {
        CiProvider::BitbucketPipelines
    }

    fn has_releases(&self) -> bool {
        false
    }

    fn list(&self, _: &CiTarget, _: &str, _: usize) -> Result<Vec<Release>, CiProblem> {
        Ok(Vec::new())
    }

    fn edit(&self, _: &CiTarget, _: &str, _: &str, _: &ReleaseEdit) -> Result<Release, CiProblem> {
        Err(CiProblem::new(
            CiProblemKind::Unsupported,
            "Bitbucket has tags but no releases",
        ))
    }

    fn tag_url(&self, target: &CiTarget, tag: &str) -> String {
        format!("{}/{}/src/{}", target.host.web, target.repo, enc(tag))
    }
}
