//! GitHub releases, REST API.

use kumo_domain::pipelines::{CiProblem, CiProvider, CiTarget};
use kumo_domain::releases::{Release, ReleaseAsset, ReleaseClient, ReleaseEdit, ReleaseKind};
use serde_json::{Map, Value, json};

use super::http::{CiHttp, Header, enc};
use super::{needs, ts};

/// What writing releases needs on a fine-grained token.
const WRITE: &str = "Contents: Read and write";

#[derive(Debug, Default)]
pub struct GitHubReleases {
    http: CiHttp,
}

impl GitHubReleases {
    fn headers(token: &str) -> [Header; 2] {
        [
            ("Authorization", format!("Bearer {token}")),
            ("Accept", "application/vnd.github+json".to_owned()),
        ]
    }

    fn releases_url(target: &CiTarget) -> String {
        format!("{}/repos/{}/releases", target.host.api, target.repo)
    }

    fn raw_list(&self, target: &CiTarget, token: &str, n: usize) -> Result<Vec<Value>, CiProblem> {
        let url = format!(
            "{}?per_page={}",
            Self::releases_url(target),
            n.clamp(1, 100)
        );
        let list = self.http.get_json(&url, &Self::headers(token))?;
        Ok(list.as_array().cloned().unwrap_or_default())
    }
}

impl ReleaseClient for GitHubReleases {
    fn provider(&self) -> CiProvider {
        CiProvider::GitHubActions
    }

    fn list(
        &self,
        target: &CiTarget,
        token: &str,
        limit: usize,
    ) -> Result<Vec<Release>, CiProblem> {
        Ok(self
            .raw_list(target, token, limit)?
            .iter()
            .map(parse_release)
            .collect())
    }

    fn edit(
        &self,
        target: &CiTarget,
        token: &str,
        tag: &str,
        edit: &ReleaseEdit,
    ) -> Result<Release, CiProblem> {
        let headers = Self::headers(token);
        // Drafts aren't found by tag: look in the list.
        let existing = self
            .raw_list(target, token, 100)?
            .into_iter()
            .find(|r| r["tag_name"] == tag);
        let mut body = Map::new();
        if let Some(name) = &edit.name {
            body.insert("name".into(), json!(name));
        }
        if let Some(notes) = &edit.notes {
            body.insert("body".into(), json!(notes));
        }
        let answer = match existing {
            Some(release) => {
                if edit.publish {
                    body.insert("prerelease".into(), json!(false));
                    body.insert("draft".into(), json!(false));
                    body.insert("make_latest".into(), json!("true"));
                }
                let url = format!(
                    "{}/{}",
                    Self::releases_url(target),
                    super::id(&release["id"])
                );
                self.http.patch(&url, &headers, &Value::Object(body))
            }
            None => {
                body.insert("tag_name".into(), json!(tag));
                body.entry("name").or_insert_with(|| json!(tag));
                // GitHub would make any new release Latest, an old tag's too.
                body.insert(
                    "make_latest".into(),
                    json!(if edit.publish { "true" } else { "false" }),
                );
                if !edit.sha.is_empty() {
                    body.insert("target_commitish".into(), json!(edit.sha));
                }
                self.http.post(
                    &Self::releases_url(target),
                    &headers,
                    Some(&Value::Object(body)),
                )
            }
        }
        .map_err(|p| needs(p, WRITE))?;
        Ok(parse_release(&answer))
    }

    fn tag_url(&self, target: &CiTarget, tag: &str) -> String {
        format!(
            "{}/{}/releases/tag/{}",
            target.host.web,
            target.repo,
            enc(tag)
        )
    }
}

fn parse_release(r: &Value) -> Release {
    let text = |v: &Value| v.as_str().unwrap_or_default().to_owned();
    Release {
        tag: text(&r["tag_name"]),
        kind: if r["draft"] == true {
            ReleaseKind::Draft
        } else if r["prerelease"] == true {
            ReleaseKind::PreRelease
        } else {
            ReleaseKind::Release
        },
        name: text(&r["name"]),
        notes: text(&r["body"]),
        author: text(&r["author"]["login"]),
        sha: String::new(),
        time: ts(&r["published_at"]).or_else(|| ts(&r["created_at"])),
        url: text(&r["html_url"]),
        checks: None,
        assets: r["assets"]
            .as_array()
            .into_iter()
            .flatten()
            .map(|a| ReleaseAsset {
                name: text(&a["name"]),
                size: a["size"].as_u64().unwrap_or(0),
            })
            .collect(),
    }
}

#[cfg(test)]
mod tests {
    use kumo_domain::pipelines::{CiHost, CiProblemKind};

    use super::*;
    use crate::test_server::TestServer;

    fn target(api: &str) -> CiTarget {
        CiTarget {
            host: CiHost {
                provider: CiProvider::GitHubActions,
                host: "github.com".into(),
                api: api.into(),
                web: "https://github.com".into(),
            },
            repo: "workspace-1/repo-1".into(),
            branch: String::new(),
        }
    }

    const RELEASES: &str = r#"[
        {"id":3,"tag_name":"v1.9.0","name":"","body":null,"draft":true,"prerelease":false,"author":{"login":"mauri"},
         "html_url":"https://github.com/workspace-1/repo-1/releases/tag/untagged-1","published_at":null,"created_at":"2026-01-03T10:00:00Z","assets":[]},
        {"id":2,"tag_name":"v1.9.0-rc.1","name":"RC","body":"Try it","draft":false,"prerelease":true,"author":{"login":"mauri"},
         "html_url":"https://github.com/workspace-1/repo-1/releases/tag/v1.9.0-rc.1","published_at":"2026-01-02T10:00:00Z","assets":[]},
        {"id":1,"tag_name":"v1.8.0","name":"Bulk discounts","body":"Highlights","draft":false,"prerelease":false,"author":{"login":"lucia"},
         "html_url":"https://github.com/workspace-1/repo-1/releases/tag/v1.8.0","published_at":"2026-01-01T10:00:00Z",
         "assets":[{"name":"app.zip","size":1400000}]}
    ]"#;

    fn server(forbid: bool) -> TestServer {
        TestServer::start(move |r| {
            match (r.method.as_str(), r.path.as_str()) {
            ("PATCH" | "POST", _) if forbid => (403, r#"{"message":"Resource not accessible by personal access token"}"#.into()),
            ("GET", p) if p.starts_with("/repos/workspace-1/repo-1/releases?per_page=") => (200, RELEASES.into()),
            ("PATCH", "/repos/workspace-1/repo-1/releases/2") => (200, r#"{"id":2,"tag_name":"v1.9.0-rc.1","name":"RC","body":"New notes","draft":false,"prerelease":false}"#.into()),
            ("POST", "/repos/workspace-1/repo-1/releases") => (201, r#"{"id":4,"tag_name":"v1.7.3","name":"v1.7.3","body":"Notes","draft":false,"prerelease":false}"#.into()),
            _ => (404, r#"{"message":"Not Found"}"#.into()),
        }
        })
    }

    #[test]
    fn lists_releases_pre_releases_and_drafts() {
        let server = server(false);
        let releases = GitHubReleases::default()
            .list(&target(&server.url), "t", 50)
            .unwrap();
        let rows: Vec<_> = releases
            .iter()
            .map(|r| (r.tag.as_str(), r.kind, r.name.as_str(), r.author.as_str()))
            .collect();
        assert_eq!(
            rows,
            [
                ("v1.9.0", ReleaseKind::Draft, "", "mauri"),
                ("v1.9.0-rc.1", ReleaseKind::PreRelease, "RC", "mauri"),
                ("v1.8.0", ReleaseKind::Release, "Bulk discounts", "lucia"),
            ]
        );
        assert!(releases[0].time.is_some(), "a draft has its creation time");
        assert_eq!(
            releases[2].assets,
            [ReleaseAsset {
                name: "app.zip".into(),
                size: 1_400_000
            }]
        );
        assert_eq!(
            server.requests()[0].path,
            "/repos/workspace-1/repo-1/releases?per_page=50"
        );
    }

    #[test]
    fn edits_an_existing_release_and_publishes_it() {
        let server = server(false);
        let edit = ReleaseEdit {
            notes: Some("New notes".into()),
            publish: true,
            ..ReleaseEdit::default()
        };
        let release = GitHubReleases::default()
            .edit(&target(&server.url), "t", "v1.9.0-rc.1", &edit)
            .unwrap();
        assert_eq!(
            (release.kind, release.notes.as_str()),
            (ReleaseKind::Release, "New notes")
        );
        let patch = server
            .requests()
            .into_iter()
            .find(|r| r.method == "PATCH")
            .unwrap();
        assert_eq!(
            patch.json(),
            json!({"body": "New notes", "prerelease": false, "draft": false, "make_latest": "true"})
        );
    }

    #[test]
    fn a_bare_tag_gets_its_release_created() {
        let server = server(false);
        let edit = ReleaseEdit {
            notes: Some("Notes".into()),
            sha: "3c09e1a".into(),
            ..ReleaseEdit::default()
        };
        let release = GitHubReleases::default()
            .edit(&target(&server.url), "t", "v1.7.3", &edit)
            .unwrap();
        assert_eq!(release.tag, "v1.7.3");
        let post = server
            .requests()
            .into_iter()
            .find(|r| r.method == "POST")
            .unwrap();
        assert_eq!(
            post.json(),
            json!({"tag_name": "v1.7.3", "name": "v1.7.3", "body": "Notes", "target_commitish": "3c09e1a", "make_latest": "false"})
        );
    }

    #[test]
    fn a_refusal_names_the_permission() {
        let server = server(true);
        let problem = GitHubReleases::default()
            .edit(&target(&server.url), "t", "v1.8.0", &ReleaseEdit::default())
            .unwrap_err();
        assert_eq!(
            (problem.kind, problem.missing_scope.as_str()),
            (CiProblemKind::Forbidden, WRITE)
        );
        assert_eq!(
            GitHubReleases::default().tag_url(&target(""), "v1.8.0"),
            "https://github.com/workspace-1/repo-1/releases/tag/v1.8.0"
        );
    }
}
