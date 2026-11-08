//! GitLab releases, REST API v4.

use kumo_domain::pipelines::{CiProblem, CiProblemKind, CiProvider, CiTarget};
use kumo_domain::releases::{Release, ReleaseAsset, ReleaseClient, ReleaseEdit, ReleaseKind};
use serde_json::{Map, Value, json};

use super::http::{CiHttp, Header, enc};
use super::{needs, ts};

#[derive(Debug, Default)]
pub struct GitLabReleases {
    http: CiHttp,
}

impl GitLabReleases {
    fn headers(token: &str) -> [Header; 1] {
        [("PRIVATE-TOKEN", token.to_owned())]
    }

    fn releases_url(target: &CiTarget) -> String {
        format!(
            "{}/projects/{}/releases",
            target.host.api,
            enc(&target.repo)
        )
    }
}

impl ReleaseClient for GitLabReleases {
    fn provider(&self) -> CiProvider {
        CiProvider::GitLabCi
    }

    fn list(
        &self,
        target: &CiTarget,
        token: &str,
        limit: usize,
    ) -> Result<Vec<Release>, CiProblem> {
        let url = format!(
            "{}?per_page={}",
            Self::releases_url(target),
            limit.clamp(1, 100)
        );
        let list = self.http.get_json(&url, &Self::headers(token))?;
        Ok(list
            .as_array()
            .into_iter()
            .flatten()
            .map(parse_release)
            .collect())
    }

    /// GitLab has no pre-releases to publish: `publish` changes nothing.
    fn edit(
        &self,
        target: &CiTarget,
        token: &str,
        tag: &str,
        edit: &ReleaseEdit,
    ) -> Result<Release, CiProblem> {
        let headers = Self::headers(token);
        let one = format!("{}/{}", Self::releases_url(target), enc(tag));
        let exists = match self.http.get_json(&one, &headers) {
            Ok(_) => true,
            Err(p) if p.kind == CiProblemKind::NotFound => false,
            Err(p) => return Err(p),
        };
        let mut body = Map::new();
        if let Some(name) = &edit.name {
            body.insert("name".into(), json!(name));
        }
        if let Some(notes) = &edit.notes {
            body.insert("description".into(), json!(notes));
        }
        let answer = if exists {
            self.http.put(&one, &headers, Some(&Value::Object(body)))
        } else {
            body.insert("tag_name".into(), json!(tag));
            body.entry("name").or_insert_with(|| json!(tag));
            if !edit.sha.is_empty() {
                body.insert("ref".into(), json!(edit.sha));
            }
            self.http.post(
                &Self::releases_url(target),
                &headers,
                Some(&Value::Object(body)),
            )
        }
        .map_err(|p| needs(p, "api"))?;
        Ok(parse_release(&answer))
    }

    fn tag_url(&self, target: &CiTarget, tag: &str) -> String {
        format!("{}/{}/-/tags/{}", target.host.web, target.repo, enc(tag))
    }
}

fn parse_release(r: &Value) -> Release {
    let text = |v: &Value| v.as_str().unwrap_or_default().to_owned();
    let sources = r["assets"]["sources"]
        .as_array()
        .into_iter()
        .flatten()
        .map(|s| ReleaseAsset {
            name: format!(
                "Source code ({})",
                s["format"].as_str().unwrap_or("archive")
            ),
            size: 0,
        });
    let links = r["assets"]["links"]
        .as_array()
        .into_iter()
        .flatten()
        .map(|l| ReleaseAsset {
            name: text(&l["name"]),
            size: 0,
        });
    Release {
        tag: text(&r["tag_name"]),
        // Upcoming: released_at is in the future; GitLab's nearest thing
        // to a pre-release.
        kind: if r["upcoming_release"] == true {
            ReleaseKind::PreRelease
        } else {
            ReleaseKind::Release
        },
        name: text(&r["name"]),
        notes: text(&r["description"]),
        author: r["author"]["name"]
            .as_str()
            .filter(|n| !n.is_empty())
            .or(r["author"]["username"].as_str())
            .unwrap_or_default()
            .to_owned(),
        sha: text(&r["commit"]["id"]),
        time: ts(&r["released_at"]).or_else(|| ts(&r["created_at"])),
        url: text(&r["_links"]["self"]),
        checks: None,
        assets: links.chain(sources).collect(),
    }
}

#[cfg(test)]
mod tests {
    use kumo_domain::pipelines::CiHost;

    use super::*;
    use crate::test_server::TestServer;

    fn target(api: &str) -> CiTarget {
        CiTarget {
            host: CiHost {
                provider: CiProvider::GitLabCi,
                host: "gitlab.example.com".into(),
                api: api.into(),
                web: "https://gitlab.example.com".into(),
            },
            repo: "group-1/repo-1".into(),
            branch: String::new(),
        }
    }

    const BASE: &str = "/projects/group-1%2Frepo-1/releases";

    fn server(forbid: bool) -> TestServer {
        TestServer::start(move |r| {
            let release = r#"{"tag_name":"v0.1.0","name":"First","description":"Notes","author":{"name":"Nico","username":"nico"},
                "commit":{"id":"9d2e417"},"released_at":"2026-01-01T10:00:00Z","upcoming_release":false,
                "_links":{"self":"https://gitlab.example.com/group-1/repo-1/-/releases/v0.1.0"},
                "assets":{"sources":[{"format":"zip"},{"format":"tar.gz"}],"links":[]}}"#;
            match (r.method.as_str(), r.path.as_str()) {
                ("PUT" | "POST", _) if forbid => (403, r#"{"message":"403 Forbidden"}"#.into()),
                ("GET", p) if p == format!("{BASE}?per_page=50") => (
                    200,
                    format!(
                        r#"[{{"tag_name":"v0.2.0","name":"Next","upcoming_release":true,"author":{{"username":"mauri"}}}},{release}]"#
                    ),
                ),
                ("GET", p) if p == format!("{BASE}/v0.1.0") => (200, release.into()),
                ("PUT", p) if p == format!("{BASE}/v0.1.0") => {
                    (200, release.replace("Notes", "New"))
                }
                ("POST", p) if p == BASE => (
                    201,
                    r#"{"tag_name":"v0.0.9","name":"v0.0.9","description":"Hi"}"#.into(),
                ),
                _ => (404, r#"{"message":"404 Not found"}"#.into()),
            }
        })
    }

    #[test]
    fn lists_releases_with_upcoming_ones_as_pre_releases() {
        let server = server(false);
        let releases = GitLabReleases::default()
            .list(&target(&server.url), "t", 50)
            .unwrap();
        assert_eq!(
            releases
                .iter()
                .map(|r| (r.tag.as_str(), r.kind))
                .collect::<Vec<_>>(),
            [
                ("v0.2.0", ReleaseKind::PreRelease),
                ("v0.1.0", ReleaseKind::Release)
            ]
        );
        let first = &releases[1];
        assert_eq!(
            (
                first.author.as_str(),
                first.sha.as_str(),
                first.notes.as_str()
            ),
            ("Nico", "9d2e417", "Notes")
        );
        assert_eq!(
            first
                .assets
                .iter()
                .map(|a| a.name.as_str())
                .collect::<Vec<_>>(),
            ["Source code (zip)", "Source code (tar.gz)"]
        );
    }

    #[test]
    fn edits_a_release_or_creates_one_for_a_bare_tag() {
        let open = server(false);
        let client = GitLabReleases::default();
        let edit = ReleaseEdit {
            notes: Some("New".into()),
            publish: true,
            ..ReleaseEdit::default()
        };
        let edited = client
            .edit(&target(&open.url), "t", "v0.1.0", &edit)
            .unwrap();
        assert_eq!(edited.notes, "New");
        let put = open
            .requests()
            .into_iter()
            .find(|r| r.method == "PUT")
            .unwrap();
        assert_eq!(
            put.json(),
            json!({"description": "New"}),
            "publish sends nothing"
        );

        let created = client
            .edit(&target(&open.url), "t", "v0.0.9", &edit)
            .unwrap();
        assert_eq!(created.tag, "v0.0.9");
        let post = open
            .requests()
            .into_iter()
            .find(|r| r.method == "POST")
            .unwrap();
        assert_eq!(
            post.json(),
            json!({"tag_name": "v0.0.9", "name": "v0.0.9", "description": "New"})
        );

        let refused = server(true);
        let problem = client
            .edit(&target(&refused.url), "t", "v0.1.0", &edit)
            .unwrap_err();
        assert_eq!(
            (problem.kind, problem.missing_scope.as_str()),
            (CiProblemKind::Forbidden, "api")
        );
    }
}
