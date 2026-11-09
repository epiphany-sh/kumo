//! GitLab merge requests, REST API v4.

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
pub struct GitLabPulls {
    http: CiHttp,
}

impl GitLabPulls {
    fn headers(token: &str) -> [Header; 1] {
        [("PRIVATE-TOKEN", token.to_owned())]
    }

    fn base(target: &CiTarget) -> String {
        format!("{}/projects/{}", target.host.api, enc(&target.repo))
    }

    fn me(&self, target: &CiTarget, token: &str) -> Result<String, CiProblem> {
        let user = self
            .http
            .get_json(&format!("{}/user", target.host.api), &Self::headers(token))?;
        Ok(user["username"].as_str().unwrap_or_default().to_owned())
    }

    /// The list leaves out the pipeline and approvals: one look per MR.
    fn complete(&self, target: &CiTarget, token: &str, mr: &Value, me: &str) -> PullRequest {
        let base = Self::base(target);
        let iid = mr["iid"].as_u64().unwrap_or_default();
        let detail = self
            .http
            .get_json(
                &format!("{base}/merge_requests/{iid}"),
                &Self::headers(token),
            )
            .unwrap_or_else(|_| mr.clone());
        let has_reviewers = mr["reviewers"].as_array().is_some_and(|r| !r.is_empty());
        let approvals = if has_reviewers {
            self.http
                .get_json(
                    &format!("{base}/merge_requests/{iid}/approvals"),
                    &Self::headers(token),
                )
                .ok()
        } else {
            None
        };
        parse_mr(&detail, approvals.as_ref(), me)
    }
}

impl PullRequestClient for GitLabPulls {
    fn provider(&self) -> CiProvider {
        CiProvider::GitLabCi
    }

    fn list(
        &self,
        target: &CiTarget,
        token: &str,
        limit: usize,
    ) -> Result<Vec<PullRequest>, CiProblem> {
        let me = self.me(target, token)?;
        let url = format!(
            "{}/merge_requests?state=opened&order_by=updated_at&sort=desc&per_page={}",
            Self::base(target),
            limit.min(50)
        );
        let list = self.http.get_json(&url, &Self::headers(token))?;
        Ok(list
            .as_array()
            .into_iter()
            .flatten()
            .take(limit)
            .map(|mr| self.complete(target, token, mr, &me))
            .collect())
    }

    fn for_branch(&self, target: &CiTarget, token: &str) -> Result<Option<PullRequest>, CiProblem> {
        let me = self.me(target, token)?;
        let url = format!(
            "{}/merge_requests?source_branch={}&state=all&order_by=updated_at&sort=desc&per_page=5",
            Self::base(target),
            enc(&target.branch)
        );
        let list = self.http.get_json(&url, &Self::headers(token))?;
        let mrs: Vec<&Value> = list.as_array().into_iter().flatten().collect();
        let pick = mrs.iter().find(|m| m["state"] == "opened").or(mrs.first());
        Ok(pick.map(|mr| self.complete(target, token, mr, &me)))
    }

    fn create(
        &self,
        target: &CiTarget,
        token: &str,
        new: &NewPullRequest,
    ) -> Result<PullRequest, CiProblem> {
        let base = Self::base(target);
        let into = if new.base.is_empty() {
            let project = self.http.get_json(&base, &Self::headers(token))?;
            project["default_branch"]
                .as_str()
                .unwrap_or("main")
                .to_owned()
        } else {
            new.base.clone()
        };
        let title = if new.draft {
            format!("Draft: {}", new.title)
        } else {
            new.title.clone()
        };
        let body = json!({ "source_branch": new.branch, "target_branch": into, "title": title, "description": new.body });
        let created = self.http.post(
            &format!("{base}/merge_requests"),
            &Self::headers(token),
            Some(&body),
        )?;
        let me = self.me(target, token).unwrap_or_default();
        Ok(parse_mr(&created, None, &me))
    }

    /// Resolvable discussions: the ones on the diff and the ones opened
    /// as threads.
    fn threads(
        &self,
        target: &CiTarget,
        token: &str,
        number: u64,
    ) -> Result<Vec<ReviewThread>, CiProblem> {
        let url = format!(
            "{}/merge_requests/{number}/discussions?per_page=100",
            Self::base(target)
        );
        let list = self.http.get_json(&url, &Self::headers(token))?;
        let mut threads: Vec<ReviewThread> = list
            .as_array()
            .into_iter()
            .flatten()
            .filter_map(parse_discussion)
            .collect();
        threads.sort_by_key(|t| t.created_at);
        Ok(threads)
    }

    fn answer_thread(
        &self,
        target: &CiTarget,
        token: &str,
        number: u64,
        answer: &ThreadAnswer,
    ) -> Result<ReviewThread, CiProblem> {
        let url = format!(
            "{}/merge_requests/{number}/discussions/{}",
            Self::base(target),
            enc(&answer.thread_id)
        );
        let headers = Self::headers(token);
        if !answer.reply.trim().is_empty() {
            self.http
                .post(
                    &format!("{url}/notes"),
                    &headers,
                    Some(&json!({ "body": answer.reply })),
                )
                .map_err(|p| needs(p, "api"))?;
        }
        let discussion = if answer.resolve {
            self.http
                .put(&format!("{url}?resolved=true"), &headers, None)
                .map_err(|p| needs(p, "api"))?
        } else {
            self.http.get_json(&url, &headers)?
        };
        parse_discussion(&discussion)
            .ok_or_else(|| CiProblem::new(CiProblemKind::NotFound, "That thread is gone"))
    }
}

/// A resolvable discussion as a thread; None for the rest (system notes,
/// plain comments).
fn parse_discussion(discussion: &Value) -> Option<ReviewThread> {
    let notes = discussion["notes"].as_array()?;
    let first = notes.first()?;
    if first["resolvable"] != true {
        return None;
    }
    let position = &first["position"];
    let path = position["new_path"]
        .as_str()
        .or(position["old_path"].as_str())
        .unwrap_or_default();
    let line = position["new_line"]
        .as_u64()
        .or(position["old_line"].as_u64())
        .and_then(|l| u32::try_from(l).ok());
    let author = &first["author"];
    Some(ReviewThread {
        id: discussion["id"].as_str().unwrap_or_default().to_owned(),
        author: author["name"]
            .as_str()
            .filter(|n| !n.is_empty())
            .or(author["username"].as_str())
            .unwrap_or("ghost")
            .to_owned(),
        path: path.to_owned(),
        line,
        body: first["body"].as_str().unwrap_or_default().to_owned(),
        created_at: ts(&first["created_at"]),
        resolved: notes
            .iter()
            .filter(|n| n["resolvable"] == true)
            .all(|n| n["resolved"] == true),
    })
}

fn person(user: &Value, me: &str) -> Person {
    let username = user["username"].as_str().unwrap_or("ghost");
    let name = user["name"]
        .as_str()
        .filter(|n| !n.is_empty())
        .unwrap_or(username);
    Person::new(username, name, !me.is_empty() && username == me)
}

/// [approvals] is `/merge_requests/:iid/approvals`, when read.
pub(super) fn parse_mr(mr: &Value, approvals: Option<&Value>, me: &str) -> PullRequest {
    let reviewers: Vec<Person> = mr["reviewers"]
        .as_array()
        .into_iter()
        .flatten()
        .map(|u| person(u, me))
        .collect();
    let approved = approvals.is_some_and(|a| {
        a["approved"].as_bool() == Some(true)
            || a["approved_by"].as_array().is_some_and(|b| !b.is_empty())
    });
    let review = match mr["detailed_merge_status"].as_str() {
        Some("requested_changes") => ReviewState::ChangesRequested,
        _ if approved => ReviewState::Approved,
        Some("not_approved") => ReviewState::Required,
        _ if !reviewers.is_empty() => ReviewState::Required,
        _ => ReviewState::None,
    };
    let pipeline = &mr["head_pipeline"];
    let checks_state = match pipeline["status"].as_str() {
        Some("success") => Some(CiState::Passed),
        Some("failed") => Some(CiState::Failed),
        Some("canceled" | "canceling") => Some(CiState::Canceled),
        Some("skipped" | "manual") => Some(CiState::Skipped),
        Some("running") => Some(CiState::Running),
        Some(_) => Some(CiState::Queued),
        None => None,
    };
    let iid = mr["iid"].as_u64().unwrap_or_default();
    let title = mr["title"].as_str().unwrap_or_default();
    let draft = mr["draft"]
        .as_bool()
        .or(mr["work_in_progress"].as_bool())
        .unwrap_or(false);
    PullRequest {
        number: iid,
        label: format!("!{iid}"),
        // GitLab marks drafts in the title too.
        title: title
            .strip_prefix("Draft: ")
            .filter(|_| draft)
            .unwrap_or(title)
            .to_owned(),
        author: person(&mr["author"], me),
        branch: mr["source_branch"].as_str().unwrap_or_default().to_owned(),
        base: mr["target_branch"].as_str().unwrap_or_default().to_owned(),
        draft,
        state: match mr["state"].as_str() {
            Some("merged") => PrState::Merged,
            Some("closed") => PrState::Closed,
            _ => PrState::Open,
        },
        review,
        review_requested_from_you: reviewers.iter().any(|p| p.you),
        reviewers,
        // GitLab reports a pipeline, not each check: one "check".
        checks_passed: u32::from(checks_state == Some(CiState::Passed)),
        checks_total: u32::from(checks_state.is_some()),
        checks_state,
        url: mr["web_url"].as_str().unwrap_or_default().to_owned(),
        created_at: ts(&mr["created_at"]),
        updated_at: ts(&mr["updated_at"]),
        comment_count: u32::try_from(mr["user_notes_count"].as_u64().unwrap_or_default())
            .unwrap_or(u32::MAX),
        // The list doesn't count unresolved discussions.
        open_threads: None,
        body: mr["description"].as_str().unwrap_or_default().to_owned(),
    }
}

#[cfg(test)]
mod tests {
    use kumo_domain::pipelines::{CiHost, CiProblemKind};

    use super::*;
    use crate::test_server::TestServer;

    fn target(api: &str, branch: &str) -> CiTarget {
        CiTarget {
            host: CiHost {
                provider: CiProvider::GitLabCi,
                host: "gitlab.example.com".into(),
                api: api.into(),
                web: "https://gitlab.example.com".into(),
            },
            repo: "pricing/price-reader-v2".into(),
            branch: branch.into(),
        }
    }

    fn route(r: &crate::test_server::Request) -> (u16, String) {
        let p = "/projects/pricing%2Fprice-reader-v2";
        match (r.method.as_str(), r.path.as_str()) {
            ("GET", "/user") => (200, r#"{"username":"mauri","name":"Mauri"}"#.into()),
            ("GET", x) if x == format!("{p}/merge_requests?state=opened&order_by=updated_at&sort=desc&per_page=30") => (200, include_str!("fixtures/gitlab_mrs.json").into()),
            ("GET", x) if x.starts_with(&format!("{p}/merge_requests?source_branch=perf%2Fcache-warmup")) => (200, include_str!("fixtures/gitlab_mrs.json").into()),
            ("GET", x) if x == format!("{p}/merge_requests/231") => (200, include_str!("fixtures/gitlab_mr_231.json").into()),
            ("GET", x) if x == format!("{p}/merge_requests/231/approvals") => (200, r#"{"approved":true,"approved_by":[{"user":{"username":"tomas"}}]}"#.into()),
            ("GET", x) if x == format!("{p}/merge_requests/229") => (200, r#"{"iid":229,"title":"Draft: chore: bump pgx","state":"opened","draft":true,"source_branch":"chore/pgx","target_branch":"main","author":{"username":"nico","name":"Nico"},"reviewers":[],"web_url":"https://gitlab.example.com/pricing/price-reader-v2/-/merge_requests/229","user_notes_count":0,"head_pipeline":null}"#.into()),
            ("GET", x) if x == p => (200, r#"{"default_branch":"main"}"#.into()),
            ("POST", x) if x == format!("{p}/merge_requests") => (201, r#"{"iid":232,"title":"Draft: feat: x","draft":true,"state":"opened","source_branch":"feat/x","target_branch":"main","author":{"username":"mauri","name":"Mauri"},"reviewers":[],"web_url":"u"}"#.into()),
            _ => (404, r#"{"message":"404 Not Found"}"#.into()),
        }
    }

    #[test]
    fn reads_merge_requests_with_pipeline_and_approvals() {
        let server = TestServer::start(route);
        let mrs = GitLabPulls::default()
            .list(&target(&server.url, ""), "glpat", 30)
            .unwrap();
        assert_eq!(mrs.len(), 2);
        let mr = &mrs[0];
        assert_eq!(
            (mr.label.as_str(), mr.title.as_str(), mr.branch.as_str()),
            ("!231", "perf: warm cache on deploy", "perf/cache-warmup")
        );
        assert_eq!(
            (mr.review, mr.review_requested_from_you),
            (ReviewState::Approved, true)
        );
        assert_eq!(
            (mr.checks_passed, mr.checks_total, mr.checks_state),
            (1, 1, Some(CiState::Passed))
        );
        assert!(mr.author.you);
        let draft = &mrs[1];
        assert_eq!(
            (
                draft.title.as_str(),
                draft.draft,
                draft.checks_state,
                draft.review
            ),
            ("chore: bump pgx", true, None, ReviewState::None)
        );
    }

    #[test]
    fn branch_and_create() {
        let server = TestServer::start(route);
        let client = GitLabPulls::default();
        assert_eq!(
            client
                .for_branch(&target(&server.url, "perf/cache-warmup"), "t")
                .unwrap()
                .unwrap()
                .label,
            "!231"
        );
        let new = NewPullRequest {
            title: "feat: x".into(),
            body: "B".into(),
            branch: "feat/x".into(),
            base: String::new(),
            draft: true,
        };
        let created = client
            .create(&target(&server.url, "feat/x"), "t", &new)
            .unwrap();
        assert_eq!(
            (
                created.label.as_str(),
                created.title.as_str(),
                created.draft
            ),
            ("!232", "feat: x", true)
        );
        let post = server
            .requests()
            .into_iter()
            .find(|r| r.method == "POST")
            .unwrap();
        assert_eq!(
            (
                post.json()["title"].as_str(),
                post.json()["target_branch"].as_str()
            ),
            (Some("Draft: feat: x"), Some("main"))
        );
        let missing = client
            .list(
                &CiTarget {
                    repo: "nope/nope".into(),
                    ..target(&server.url, "")
                },
                "t",
                30,
            )
            .unwrap_err();
        assert_eq!(missing.kind, CiProblemKind::NotFound);
    }

    const DISCUSSIONS: &str = r#"[
        {"id":"d2","notes":[{"resolvable":true,"resolved":false,"author":{"username":"tomas","name":"Tomás"},
          "body":"Offset first?","created_at":"2026-01-02T10:00:00Z","position":{"new_path":"src/b.rs","new_line":42,"old_path":"src/b.rs","old_line":40}}]},
        {"id":"d0","notes":[{"system":true,"resolvable":false,"body":"added 1 commit","created_at":"2026-01-01T09:00:00Z"}]},
        {"id":"d1","notes":[{"resolvable":true,"resolved":true,"author":{"username":"lucia","name":"Lucía"},
          "body":"Retry?","created_at":"2026-01-01T10:00:00Z","position":{"old_path":"src/a.rs","old_line":7,"new_line":null}},
          {"resolvable":true,"resolved":true,"author":{"username":"mauri"},"body":"Done","created_at":"2026-01-01T11:00:00Z"}]}
    ]"#;

    fn discussions(forbid: bool) -> TestServer {
        TestServer::start(move |r| {
            let base = "/projects/pricing%2Fprice-reader-v2/merge_requests/231/discussions";
            let resolved = r#"{"id":"d2","notes":[{"resolvable":true,"resolved":true,"author":{"name":"Tomás"},"body":"Offset first?","position":{"new_path":"src/b.rs","new_line":42}}]}"#;
            let open = resolved.replace(r#""resolved":true"#, r#""resolved":false"#);
            match (r.method.as_str(), r.path.as_str()) {
                ("POST" | "PUT", _) if forbid => (403, r#"{"message":"403 Forbidden"}"#.into()),
                ("GET", x) if x == format!("{base}?per_page=100") => (200, DISCUSSIONS.into()),
                ("POST", x) if x == format!("{base}/d2/notes") => (201, r#"{"id":9}"#.into()),
                ("PUT", x) if x == format!("{base}/d2?resolved=true") => (200, resolved.into()),
                ("GET", x) if x == format!("{base}/d2") => (200, open),
                _ => (404, r#"{"message":"404 Not Found"}"#.into()),
            }
        })
    }

    #[test]
    fn reads_resolvable_discussions_as_threads() {
        let server = discussions(false);
        let threads = GitLabPulls::default()
            .threads(&target(&server.url, ""), "t", 231)
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
                ("d1", "Lucía", "src/a.rs", Some(7), true),
                ("d2", "Tomás", "src/b.rs", Some(42), false),
            ]
        );
    }

    #[test]
    fn answers_a_discussion() {
        let client = GitLabPulls::default();
        let answer = |reply: &str, resolve: bool| ThreadAnswer {
            thread_id: "d2".into(),
            reply: reply.into(),
            resolve,
        };
        let calls = |server: &TestServer| -> Vec<String> {
            server
                .requests()
                .iter()
                .map(|r| format!("{} {}", r.method, r.path.rsplit('/').next().unwrap()))
                .collect()
        };
        let server = discussions(false);
        let both = client
            .answer_thread(&target(&server.url, ""), "t", 231, &answer("Done.", true))
            .unwrap();
        assert!(both.resolved);
        assert_eq!(calls(&server), ["POST notes", "PUT d2?resolved=true"]);
        assert_eq!(server.requests()[0].json()["body"], "Done.");

        let server = discussions(false);
        let replied = client
            .answer_thread(&target(&server.url, ""), "t", 231, &answer("Why?", false))
            .unwrap();
        assert!(!replied.resolved);
        assert_eq!(calls(&server), ["POST notes", "GET d2"]);

        let server = discussions(false);
        client
            .answer_thread(&target(&server.url, ""), "t", 231, &answer("", true))
            .unwrap();
        assert_eq!(calls(&server), ["PUT d2?resolved=true"]);

        let server = discussions(true);
        let refused = client
            .answer_thread(&target(&server.url, ""), "t", 231, &answer("x", true))
            .unwrap_err();
        assert_eq!(
            (refused.kind, refused.missing_scope.as_str()),
            (CiProblemKind::Forbidden, "api")
        );
    }
}
