use crate::workspace::{GitHost, Remote};

use super::CiProvider;

/// A repository host and where its API is.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct CiHost {
    pub provider: CiProvider,
    /// `github.com`, `gitlab.example.com`: tokens are kept per host.
    pub host: String,
    /// API base, without a trailing slash.
    pub api: String,
    /// Web base, for links.
    pub web: String,
}

impl CiHost {
    /// The CI of a repository's remote; None for hosts without a supported
    /// CI (and local remotes).
    pub fn for_remote(remote: &Remote) -> Option<Self> {
        let domain = remote.domain()?;
        let web = format!("https://{domain}");
        let (provider, api) = match remote.host {
            GitHost::GitHub if domain == "github.com" => (
                CiProvider::GitHubActions,
                "https://api.github.com".to_owned(),
            ),
            // GitHub Enterprise Server.
            GitHost::GitHub => (CiProvider::GitHubActions, format!("{web}/api/v3")),
            GitHost::GitLab => (CiProvider::GitLabCi, format!("{web}/api/v4")),
            // Bitbucket Server / Data Center has no Pipelines.
            GitHost::Bitbucket if domain == "bitbucket.org" => (
                CiProvider::BitbucketPipelines,
                "https://api.bitbucket.org/2.0".to_owned(),
            ),
            _ => return None,
        };
        Some(Self {
            provider,
            host: domain,
            api,
            web,
        })
    }
}

/// The pipelines of one branch of one repository.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CiTarget {
    pub host: CiHost,
    /// `owner/name` (GitLab: the full path, subgroups included).
    pub repo: String,
    pub branch: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn host(url: &str) -> Option<CiHost> {
        CiHost::for_remote(&Remote::parse(url))
    }

    #[test]
    fn finds_the_api_of_each_host() {
        let gh = host("git@github.com:pricing/price-admin.git").unwrap();
        assert_eq!(
            (gh.provider, gh.host.as_str(), gh.api.as_str()),
            (
                CiProvider::GitHubActions,
                "github.com",
                "https://api.github.com"
            )
        );
        let ghe = host("https://github.acme.dev/team/app.git").unwrap();
        assert_eq!(ghe.api, "https://github.acme.dev/api/v3");
        let gl = host("ssh://git@gitlab.fravega.com:2222/pricing/sub/app.git").unwrap();
        assert_eq!(
            (gl.provider, gl.host.as_str(), gl.api.as_str()),
            (
                CiProvider::GitLabCi,
                "gitlab.fravega.com",
                "https://gitlab.fravega.com/api/v4"
            )
        );
        let bb = host("git@bitbucket.org:team/repo.git").unwrap();
        assert_eq!(bb.api, "https://api.bitbucket.org/2.0");
        assert_eq!(host("https://bitbucket.acme.com/scm/team/repo.git"), None);
        assert_eq!(host("/srv/git/repo.git"), None);
        assert_eq!(host("https://gitea.acme.com/team/repo.git"), None);
    }
}
