//! Bitbucket Cloud pull requests, API 2.0.

use base64::Engine;
use kumo_domain::pipelines::{CiProblem, CiProblemKind, CiProvider, CiState, CiTarget};
use kumo_domain::pulls::{
    NewPullRequest, PrState, PullRequest, PullRequestClient, ReviewState, ReviewThread,
    ThreadAnswer,
};
use kumo_domain::tasks::Person;
use serde_json::{Value, json};

use super::http::{CiHttp, Header, enc};
use super::{needs, ts};

#[derive(Debug, Default)]
pub struct BitbucketPulls {
    http: CiHttp,
}

impl BitbucketPulls {
    /// Same sign-in as pipelines: `email:token` as Basic, else Bearer.
    fn headers(token: &str) -> [Header; 1] {
        let auth = if token.contains(':') {
            format!(
                "Basic {}",
                base64::engine::general_purpose::STANDARD.encode(token)
            )
        } else {
            format!("Bearer {token}")
        };
        [("Authorization", auth)]
    }

    fn base(target: &CiTarget) -> String {
        format!("{}/repositories/{}", target.host.api, target.repo)
    }

    /// The signed-in account's id; empty with a repository access token.
    fn me(&self, target: &CiTarget, token: &str) -> String {
        self.http
            .get_json(&format!("{}/user", target.host.api), &Self::headers(token))
            .ok()
            .and_then(|u| {
                u["account_id"]
                    .as_str()
                    .or(u["uuid"].as_str())
                    .map(str::to_owned)
            })
            .unwrap_or_default()
    }

    /// The list leaves out reviewers' decisions and build statuses.
    fn complete(&self, target: &CiTarget, token: &str, pr: &Value, me: &str) -> PullRequest {
        let url = format!(
            "{}/pullrequests/{}",
            Self::base(target),
            pr["id"].as_u64().unwrap_or_default()
        );
        let detail = self
            .http
            .get_json(&url, &Self::headers(token))
            .unwrap_or_else(|_| pr.clone());
        let statuses = self
            .http
            .get_json(
                &format!("{url}/statuses?pagelen=100"),
                &Self::headers(token),
            )
            .ok();
        parse_pr(&detail, statuses.as_ref(), me)
    }
}

impl PullRequestClient for BitbucketPulls {
    fn provider(&self) -> CiProvider {
        CiProvider::BitbucketPipelines
    }

    fn list(
        &self,
        target: &CiTarget,
        token: &str,
        limit: usize,
    ) -> Result<Vec<PullRequest>, CiProblem> {
        let url = format!(
            "{}/pullrequests?state=OPEN&sort=-updated_on&pagelen={}",
            Self::base(target),
            limit.min(50)
        );
        let list = self.http.get_json(&url, &Self::headers(token))?;
        let me = self.me(target, token);
        Ok(list["values"]
            .as_array()
            .into_iter()
            .flatten()
            .take(limit)
            .map(|pr| self.complete(target, token, pr, &me))
            .collect())
    }

    fn for_branch(&self, target: &CiTarget, token: &str) -> Result<Option<PullRequest>, CiProblem> {
        let q = enc(&format!("source.branch.name=\"{}\"", target.branch));
        let url = format!(
            "{}/pullrequests?q={q}&state=OPEN&state=MERGED&state=DECLINED&sort=-updated_on&pagelen=5",
            Self::base(target)
        );
        let list = self.http.get_json(&url, &Self::headers(token))?;
        let prs: Vec<&Value> = list["values"].as_array().into_iter().flatten().collect();
        let pick = prs.iter().find(|p| p["state"] == "OPEN").or(prs.first());
        let me = self.me(target, token);
        Ok(pick.map(|pr| self.complete(target, token, pr, &me)))
    }

    fn create(
        &self,
        target: &CiTarget,
        token: &str,
        new: &NewPullRequest,
    ) -> Result<PullRequest, CiProblem> {
        let mut body = json!({
            "title": new.title,
            "description": new.body,
            "source": { "branch": { "name": new.branch } },
            "draft": new.draft,
        });
        // Without a destination Bitbucket uses the repository's main branch.
        if !new.base.is_empty() {
            body["destination"] = json!({ "branch": { "name": new.base } });
        }
        let created = self.http.post(
            &format!("{}/pullrequests", Self::base(target)),
            &Self::headers(token),
            Some(&body),
        )?;
        Ok(parse_pr(&created, None, &self.me(target, token)))
    }

    /// Top-level inline comments: what Bitbucket resolves.
    fn threads(
        &self,
        target: &CiTarget,
        token: &str,
        number: u64,
    ) -> Result<Vec<ReviewThread>, CiProblem> {
        let mut url = format!(
            "{}/pullrequests/{number}/comments?pagelen=100",
            Self::base(target)
        );
        let mut threads = Vec::new();
        // A few pages at most: hundreds of inline threads is plenty.
        for _ in 0..5 {
            let page = self.http.get_json(&url, &Self::headers(token))?;
            threads.extend(
                page["values"]
                    .as_array()
                    .into_iter()
                    .flatten()
                    .filter_map(parse_comment),
            );
            match page["next"].as_str() {
                Some(next) => next.clone_into(&mut url),
                None => break,
            }
        }
        threads.sort_by_key(|t: &ReviewThread| t.created_at);
        Ok(threads)
    }

    fn answer_thread(
        &self,
        target: &CiTarget,
        token: &str,
        number: u64,
        answer: &ThreadAnswer,
    ) -> Result<ReviewThread, CiProblem> {
        let comments = format!("{}/pullrequests/{number}/comments", Self::base(target));
        let id: u64 = answer
            .thread_id
            .parse()
            .map_err(|_| CiProblem::new(CiProblemKind::NotFound, "Not a Bitbucket comment id"))?;
        let headers = Self::headers(token);
        if !answer.reply.trim().is_empty() {
            let body = json!({ "content": { "raw": answer.reply }, "parent": { "id": id } });
            self.http
                .post(&comments, &headers, Some(&body))
                .map_err(|p| needs(p, "pullrequest:write"))?;
        }
        if answer.resolve {
            self.http
                .post(&format!("{comments}/{id}/resolve"), &headers, None)
                .map_err(|p| needs(p, "pullrequest:write"))?;
        }
        let comment = self.http.get_json(&format!("{comments}/{id}"), &headers)?;
        parse_comment(&comment)
            .ok_or_else(|| CiProblem::new(CiProblemKind::NotFound, "That thread is gone"))
    }
}

/// A top-level inline comment as a thread; None for replies, general
/// comments and deleted ones.
fn parse_comment(comment: &Value) -> Option<ReviewThread> {
    let inline = comment.get("inline").filter(|i| i.is_object())?;
    if comment.get("parent").is_some_and(|p| !p.is_null()) || comment["deleted"] == true {
        return None;
    }
    let line = inline["to"]
        .as_u64()
        .or(inline["from"].as_u64())
        .and_then(|l| u32::try_from(l).ok());
    Some(ReviewThread {
        id: super::id(&comment["id"]),
        author: comment["user"]["display_name"]
            .as_str()
            .or(comment["user"]["nickname"].as_str())
            .unwrap_or("Someone")
            .to_owned(),
        path: inline["path"].as_str().unwrap_or_default().to_owned(),
        line,
        body: comment["content"]["raw"]
            .as_str()
            .unwrap_or_default()
            .to_owned(),
        created_at: ts(&comment["created_on"]),
        resolved: comment.get("resolution").is_some_and(|r| !r.is_null()),
    })
}

fn person(user: &Value, me: &str) -> Person {
    let id = user["account_id"]
        .as_str()
        .or(user["uuid"].as_str())
        .unwrap_or_default();
    let name = user["display_name"]
        .as_str()
        .or(user["nickname"].as_str())
        .unwrap_or("Someone");
    let you = !me.is_empty()
        && (user["account_id"].as_str() == Some(me) || user["uuid"].as_str() == Some(me));
    Person::new(id, name, you)
}

/// [statuses] is `/pullrequests/{id}/statuses`, when read.
pub(super) fn parse_pr(pr: &Value, statuses: Option<&Value>, me: &str) -> PullRequest {
    let participants: Vec<&Value> = pr["participants"]
        .as_array()
        .into_iter()
        .flatten()
        .collect();
    let mut reviewers: Vec<Person> = pr["reviewers"]
        .as_array()
        .into_iter()
        .flatten()
        .map(|u| person(u, me))
        .collect();
    for p in participants.iter().filter(|p| p["role"] == "REVIEWER") {
        let who = person(&p["user"], me);
        if !reviewers.iter().any(|r| r.id == who.id) {
            reviewers.push(who);
        }
    }
    let review = if participants
        .iter()
        .any(|p| p["state"] == "changes_requested")
    {
        ReviewState::ChangesRequested
    } else if participants.iter().any(|p| p["approved"] == true) {
        ReviewState::Approved
    } else if !reviewers.is_empty() {
        ReviewState::Required
    } else {
        ReviewState::None
    };
    let builds: Vec<&str> = statuses
        .map(|s| {
            s["values"]
                .as_array()
                .into_iter()
                .flatten()
                .filter_map(|v| v["state"].as_str())
                .collect()
        })
        .unwrap_or_default();
    let checks_state = if builds.is_empty() {
        None
    } else if builds.contains(&"FAILED") {
        Some(CiState::Failed)
    } else if builds.contains(&"INPROGRESS") {
        Some(CiState::Running)
    } else if builds.iter().all(|s| *s == "STOPPED") {
        Some(CiState::Canceled)
    } else {
        Some(CiState::Passed)
    };
    let id = pr["id"].as_u64().unwrap_or_default();
    PullRequest {
        number: id,
        label: format!("#{id}"),
        title: pr["title"].as_str().unwrap_or_default().to_owned(),
        author: person(&pr["author"], me),
        branch: pr["source"]["branch"]["name"]
            .as_str()
            .unwrap_or_default()
            .to_owned(),
        base: pr["destination"]["branch"]["name"]
            .as_str()
            .unwrap_or_default()
            .to_owned(),
        draft: pr["draft"].as_bool().unwrap_or(false),
        state: match pr["state"].as_str() {
            Some("MERGED") => PrState::Merged,
            Some("DECLINED" | "SUPERSEDED") => PrState::Closed,
            _ => PrState::Open,
        },
        review,
        review_requested_from_you: reviewers.iter().any(|p| p.you),
        reviewers,
        checks_passed: u32::try_from(builds.iter().filter(|s| **s == "SUCCESSFUL").count())
            .unwrap_or(u32::MAX),
        checks_total: u32::try_from(builds.len()).unwrap_or(u32::MAX),
        checks_state,
        url: pr["links"]["html"]["href"]
            .as_str()
            .unwrap_or_default()
            .to_owned(),
        created_at: ts(&pr["created_on"]),
        updated_at: ts(&pr["updated_on"]),
        comment_count: u32::try_from(pr["comment_count"].as_u64().unwrap_or_default())
            .unwrap_or(u32::MAX),
        // The list doesn't count unresolved comments.
        open_threads: None,
    }
}

#[cfg(test)]
mod tests {
    use kumo_domain::pipelines::CiHost;

    use super::*;
    use crate::test_server::TestServer;

    fn target(api: &str, branch: &str) -> CiTarget {
        CiTarget {
            host: CiHost {
                provider: CiProvider::BitbucketPipelines,
                host: "bitbucket.org".into(),
                api: api.into(),
                web: "https://bitbucket.org".into(),
            },
            repo: "fravega-identity/users-api".into(),
            branch: branch.into(),
        }
    }

    const PR: &str = r#"{"id":44,"title":"feat: audit log","state":"OPEN","draft":false,
        "author":{"display_name":"Valentina","account_id":"v-1"},
        "source":{"branch":{"name":"feat/audit-log"}},"destination":{"branch":{"name":"main"}},
        "reviewers":[{"display_name":"Mauri","account_id":"me-1"}],
        "participants":[{"role":"REVIEWER","approved":false,"state":"changes_requested","user":{"display_name":"Nico","account_id":"n-1"}}],
        "comment_count":2,"links":{"html":{"href":"https://bitbucket.org/fravega-identity/users-api/pull-requests/44"}},
        "created_on":"2026-10-27T10:00:00.000000+00:00","updated_on":"2026-10-28T10:00:00.000000+00:00"}"#;

    #[test]
    fn reads_pull_requests_with_reviewers_and_builds() {
        let server = TestServer::start(|r| match (r.method.as_str(), r.path.as_str()) {
            ("GET", "/user") => (
                200,
                r#"{"account_id":"me-1","display_name":"Mauri"}"#.into(),
            ),
            (
                "GET",
                "/repositories/fravega-identity/users-api/pullrequests?state=OPEN&sort=-updated_on&pagelen=30",
            ) => (200, format!(r#"{{"values":[{PR}]}}"#)),
            ("GET", "/repositories/fravega-identity/users-api/pullrequests/44") => (200, PR.into()),
            (
                "GET",
                "/repositories/fravega-identity/users-api/pullrequests/44/statuses?pagelen=100",
            ) => (
                200,
                r#"{"values":[{"state":"SUCCESSFUL"},{"state":"INPROGRESS"}]}"#.into(),
            ),
            ("POST", "/repositories/fravega-identity/users-api/pullrequests") => (201, PR.into()),
            _ => (
                404,
                r#"{"type":"error","error":{"message":"Not found"}}"#.into(),
            ),
        });
        let client = BitbucketPulls::default();
        let prs = client
            .list(&target(&server.url, ""), "ana@acme.com:ATATT", 30)
            .unwrap();
        let pr = &prs[0];
        assert_eq!(
            (pr.label.as_str(), pr.branch.as_str(), pr.base.as_str()),
            ("#44", "feat/audit-log", "main")
        );
        assert_eq!(
            (pr.review, pr.review_requested_from_you),
            (ReviewState::ChangesRequested, true)
        );
        assert_eq!(
            pr.reviewers
                .iter()
                .map(|p| p.name.as_str())
                .collect::<Vec<_>>(),
            ["Mauri", "Nico"]
        );
        assert_eq!(
            (pr.checks_passed, pr.checks_total, pr.checks_state),
            (1, 2, Some(CiState::Running))
        );
        let new = NewPullRequest {
            title: "t".into(),
            body: "b".into(),
            branch: "feat/audit-log".into(),
            base: String::new(),
            draft: false,
        };
        client
            .create(&target(&server.url, "feat/audit-log"), "t", &new)
            .unwrap();
        let post = server
            .requests()
            .into_iter()
            .find(|r| r.method == "POST")
            .unwrap();
        assert!(
            post.json().get("destination").is_none(),
            "no base: Bitbucket's main branch"
        );
    }

    const COMMENTS: &str = r#"{"values":[
        {"id":12,"inline":{"path":"src/b.rs","to":42,"from":null},"user":{"display_name":"Tomás"},
         "content":{"raw":"Offset first?"},"created_on":"2026-01-02T10:00:00Z","deleted":false},
        {"id":13,"parent":{"id":12},"inline":{"path":"src/b.rs","to":42},"user":{"display_name":"Mauri"},
         "content":{"raw":"Yes"},"created_on":"2026-01-02T11:00:00Z"},
        {"id":10,"user":{"display_name":"Nico"},"content":{"raw":"LGTM"},"created_on":"2026-01-01T09:00:00Z"},
        {"id":11,"inline":{"path":"src/a.rs","to":null,"from":7},"user":{"display_name":"Lucía"},
         "content":{"raw":"Retry?"},"created_on":"2026-01-01T10:00:00Z",
         "resolution":{"type":"comment_resolution","created_on":"2026-01-01T12:00:00Z"}}
    ]}"#;

    fn comments(forbid: bool) -> TestServer {
        TestServer::start(move |r| {
            let base = "/repositories/workspace-1/repo-1/pullrequests/7/comments";
            let one = r#"{"id":12,"inline":{"path":"src/b.rs","to":42},"user":{"display_name":"Tomás"},"content":{"raw":"Offset first?"},"resolution":{"type":"comment_resolution"}}"#;
            match (r.method.as_str(), r.path.as_str()) {
                ("POST", _) if forbid => (
                    403,
                    r#"{"type":"error","error":{"message":"Forbidden"}}"#.into(),
                ),
                ("GET", x) if x == format!("{base}?pagelen=100") => (200, COMMENTS.into()),
                ("POST", x) if x == base => (201, r#"{"id":14}"#.into()),
                ("POST", x) if x == format!("{base}/12/resolve") => {
                    (200, r#"{"type":"comment_resolution"}"#.into())
                }
                ("GET", x) if x == format!("{base}/12") => (200, one.into()),
                _ => (
                    404,
                    r#"{"type":"error","error":{"message":"Not found"}}"#.into(),
                ),
            }
        })
    }

    fn repo_target(api: &str) -> CiTarget {
        CiTarget {
            repo: "workspace-1/repo-1".into(),
            ..target(api, "")
        }
    }

    #[test]
    fn reads_top_level_inline_comments_as_threads() {
        let server = comments(false);
        let threads = BitbucketPulls::default()
            .threads(&repo_target(&server.url), "t", 7)
            .unwrap();
        let rows: Vec<_> = threads
            .iter()
            .map(|t| {
                (
                    t.id.as_str(),
                    t.author.as_str(),
                    t.path.as_str(),
                    t.line,
                    t.resolved,
                )
            })
            .collect();
        assert_eq!(
            rows,
            [
                ("11", "Lucía", "src/a.rs", Some(7), true),
                ("12", "Tomás", "src/b.rs", Some(42), false),
            ]
        );
    }

    #[test]
    fn answers_a_comment_with_a_reply_and_a_resolve() {
        let client = BitbucketPulls::default();
        let answer = |reply: &str, resolve: bool| ThreadAnswer {
            thread_id: "12".into(),
            reply: reply.into(),
            resolve,
        };
        let calls = |server: &TestServer| -> Vec<String> {
            server
                .requests()
                .iter()
                .map(|r| {
                    format!(
                        "{} {}",
                        r.method,
                        r.path.rsplit("/pullrequests/7/").next().unwrap()
                    )
                })
                .collect()
        };
        let server = comments(false);
        let both = client
            .answer_thread(&repo_target(&server.url), "t", 7, &answer("Done.", true))
            .unwrap();
        assert!(both.resolved);
        assert_eq!(
            calls(&server),
            [
                "POST comments",
                "POST comments/12/resolve",
                "GET comments/12"
            ]
        );
        let reply = server.requests()[0].json();
        assert_eq!(
            (
                reply["content"]["raw"].as_str(),
                reply["parent"]["id"].as_u64()
            ),
            (Some("Done."), Some(12))
        );

        let server = comments(false);
        client
            .answer_thread(&repo_target(&server.url), "t", 7, &answer("Why?", false))
            .unwrap();
        assert_eq!(calls(&server), ["POST comments", "GET comments/12"]);

        let server = comments(false);
        client
            .answer_thread(&repo_target(&server.url), "t", 7, &answer("", true))
            .unwrap();
        assert_eq!(
            calls(&server),
            ["POST comments/12/resolve", "GET comments/12"]
        );

        let server = comments(true);
        let refused = client
            .answer_thread(&repo_target(&server.url), "t", 7, &answer("x", true))
            .unwrap_err();
        assert_eq!(
            (refused.kind, refused.missing_scope.as_str()),
            (
                kumo_domain::pipelines::CiProblemKind::Forbidden,
                "pullrequest:write"
            )
        );
    }
}
