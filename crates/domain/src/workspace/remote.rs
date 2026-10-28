/// Where a repository is hosted, from its remote URL.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum GitHost {
    GitHub,
    GitLab,
    Bitbucket,
    Other,
}

/// A repository's `origin` (or first) remote.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Remote {
    pub url: String,
    pub host: GitHost,
    /// `owner/name` (GitLab subgroups included), when the URL has a path.
    pub full_name: Option<String>,
}

impl Remote {
    /// Understands `https://host/owner/name(.git)`, `ssh://user@host:port/…`
    /// and scp-like `user@host:owner/name.git`.
    pub fn parse(url: &str) -> Self {
        let url = url.trim();
        let (domain, path) = split_url(url);
        let domain = domain.to_ascii_lowercase();
        let host = if domain.contains("github") {
            GitHost::GitHub
        } else if domain.contains("gitlab") {
            GitHost::GitLab
        } else if domain.contains("bitbucket") {
            GitHost::Bitbucket
        } else {
            GitHost::Other
        };
        let full_name = path
            .map(|p| {
                p.trim_matches('/')
                    .trim_end_matches(".git")
                    .trim_matches('/')
                    .to_owned()
            })
            .filter(|p| !p.is_empty());
        Self {
            url: url.to_owned(),
            host,
            full_name,
        }
    }
}

impl Remote {
    /// The host's domain (`github.com`), lowercase; None for local paths.
    pub fn domain(&self) -> Option<String> {
        let (domain, _) = split_url(self.url.trim());
        (!domain.is_empty()).then(|| domain.to_ascii_lowercase())
    }
}

/// (host, path) of a remote URL.
fn split_url(url: &str) -> (&str, Option<&str>) {
    if let Some((_, rest)) = url.split_once("://") {
        let (authority, path) = rest
            .split_once('/')
            .map_or((rest, None), |(a, p)| (a, Some(p)));
        let host = authority.rsplit('@').next().unwrap_or(authority);
        let host = host.split(':').next().unwrap_or(host);
        return (host, path);
    }
    // scp-like: [user@]host:path
    if let Some((authority, path)) = url.split_once(':') {
        let host = authority.rsplit('@').next().unwrap_or(authority);
        return (host, Some(path));
    }
    ("", Some(url)) // local path remote
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_common_remote_forms() {
        let cases = [
            (
                "git@github.com:pricing/price-admin.git",
                GitHost::GitHub,
                "pricing/price-admin",
            ),
            (
                "https://github.com/pricing/price-admin",
                GitHost::GitHub,
                "pricing/price-admin",
            ),
            (
                "https://gitlab.com/group/sub/reader.git",
                GitHost::GitLab,
                "group/sub/reader",
            ),
            (
                "ssh://git@gitlab.acme.io:2222/platform/infra.git",
                GitHost::GitLab,
                "platform/infra",
            ),
            (
                "https://user@bitbucket.org/identity/users.git",
                GitHost::Bitbucket,
                "identity/users",
            ),
            ("git@git.acme.io:team/tool.git", GitHost::Other, "team/tool"),
        ];
        for (url, host, name) in cases {
            let remote = Remote::parse(url);
            assert_eq!(
                (remote.host, remote.full_name.as_deref()),
                (host, Some(name)),
                "{url}"
            );
        }
    }
}
