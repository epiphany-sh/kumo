//! GitHub pull requests through GraphQL: one request brings each pull
//! request with its review decision, requested reviewers and checks.

use kumo_domain::pipelines::{CiProblem, CiProblemKind, CiProvider, CiState, CiTarget};
use kumo_domain::pulls::{
    NewPullRequest, PrState, PullRequest, PullRequestClient, ReviewState, ReviewThread,
    ThreadAnswer,
};
use kumo_domain::tasks::Person;
use serde_json::{Value, json};

use super::http::{CiHttp, Header};
use super::{needs, ts};

const FIELDS: &str = "number title body url isDraft state createdAt updatedAt headRefName baseRefName reviewDecision \
    author { login ... on User { name } } \
    reviewRequests(first: 20) { nodes { requestedReviewer { ... on User { login name } ... on Team { slug name } } } } \
    latestReviews(first: 20) { nodes { author { login ... on User { name } } state } } \
    comments { totalCount } \
    reviewThreads(first: 100) { nodes { isResolved } } \
    commits(last: 1) { nodes { commit { statusCheckRollup { state contexts(first: 100) { nodes { \
      __typename ... on CheckRun { status conclusion } ... on StatusContext { state } } } } } } }";

#[derive(Debug, Default)]
pub struct GitHubPulls {
    http: CiHttp,
}

impl GitHubPulls {
    fn headers(token: &str) -> [Header; 2] {
        [
            ("Authorization", format!("Bearer {token}")),
            ("Accept", "application/vnd.github+json".to_owned()),
        ]
    }

    /// `https://api.github.com/graphql`; Enterprise: `https://host/api/graphql`.
    fn graphql_url(target: &CiTarget) -> String {
        let api = &target.host.api;
        match api.strip_suffix("/api/v3") {
            Some(web) => format!("{web}/api/graphql"),
            None => format!("{api}/graphql"),
        }
    }

    fn query(
        &self,
        target: &CiTarget,
        token: &str,
        query: &str,
        variables: Value,
    ) -> Result<Value, CiProblem> {
        let answer = self.http.post(
            &Self::graphql_url(target),
            &Self::headers(token),
            Some(&json!({ "query": query, "variables": variables })),
        )?;
        graphql_problem(&answer).map_or(Ok(answer), Err)
    }

    fn owner_name(target: &CiTarget) -> Result<(&str, &str), CiProblem> {
        target.repo.split_once('/').ok_or_else(|| {
            CiProblem::new(
                CiProblemKind::NotFound,
                format!("Not a GitHub repository: {}", target.repo),
            )
        })
    }
}

impl PullRequestClient for GitHubPulls {
    fn provider(&self) -> CiProvider {
        CiProvider::GitHubActions
    }

    fn list(
        &self,
        target: &CiTarget,
        token: &str,
        limit: usize,
    ) -> Result<Vec<PullRequest>, CiProblem> {
        let (owner, name) = Self::owner_name(target)?;
        let query = format!(
            "query($owner: String!, $name: String!, $n: Int!) {{ viewer {{ login }} repository(owner: $owner, name: $name) {{ \
             pullRequests(states: OPEN, first: $n, orderBy: {{ field: UPDATED_AT, direction: DESC }}) {{ nodes {{ {FIELDS} }} }} }} }}"
        );
        let answer = self.query(
            target,
            token,
            &query,
            json!({ "owner": owner, "name": name, "n": limit.min(100) }),
        )?;
        let viewer = answer["data"]["viewer"]["login"]
            .as_str()
            .unwrap_or_default();
        Ok(answer["data"]["repository"]["pullRequests"]["nodes"]
            .as_array()
            .into_iter()
            .flatten()
            .map(|pr| parse_pr(pr, viewer))
            .collect())
    }

    fn for_branch(&self, target: &CiTarget, token: &str) -> Result<Option<PullRequest>, CiProblem> {
        let (owner, name) = Self::owner_name(target)?;
        let query = format!(
            "query($owner: String!, $name: String!, $branch: String!) {{ viewer {{ login }} repository(owner: $owner, name: $name) {{ \
             pullRequests(headRefName: $branch, first: 5, states: [OPEN, MERGED, CLOSED], orderBy: {{ field: UPDATED_AT, direction: DESC }}) \
             {{ nodes {{ {FIELDS} }} }} }} }}"
        );
        let answer = self.query(
            target,
            token,
            &query,
            json!({ "owner": owner, "name": name, "branch": target.branch }),
        )?;
        let viewer = answer["data"]["viewer"]["login"]
            .as_str()
            .unwrap_or_default();
        let prs: Vec<PullRequest> = answer["data"]["repository"]["pullRequests"]["nodes"]
            .as_array()
            .into_iter()
            .flatten()
            .map(|pr| parse_pr(pr, viewer))
            .collect();
        Ok(prs
            .iter()
            .find(|p| p.state == PrState::Open)
            .or(prs.first())
            .cloned())
    }

    fn create(
        &self,
        target: &CiTarget,
        token: &str,
        new: &NewPullRequest,
    ) -> Result<PullRequest, CiProblem> {
        let repo = format!("{}/repos/{}", target.host.api, target.repo);
        let base = if new.base.is_empty() {
            let info = self.http.get_json(&repo, &Self::headers(token))?;
            info["default_branch"].as_str().unwrap_or("main").to_owned()
        } else {
            new.base.clone()
        };
        let body = json!({ "title": new.title, "body": new.body, "head": new.branch, "base": base, "draft": new.draft });
        self.http
            .post(&format!("{repo}/pulls"), &Self::headers(token), Some(&body))?;
        self.for_branch(
            &CiTarget {
                branch: new.branch.clone(),
                ..target.clone()
            },
            token,
        )?
        .ok_or_else(|| {
            CiProblem::new(
                CiProblemKind::NotFound,
                "GitHub created the pull request but doesn't list it yet",
            )
        })
    }

    fn threads(
        &self,
        target: &CiTarget,
        token: &str,
        number: u64,
    ) -> Result<Vec<ReviewThread>, CiProblem> {
        let (owner, name) = Self::owner_name(target)?;
        let query = format!(
            "query($owner: String!, $name: String!, $n: Int!) {{ repository(owner: $owner, name: $name) {{ \
             pullRequest(number: $n) {{ reviewThreads(first: 100) {{ nodes {{ {THREAD_FIELDS} }} }} }} }} }}"
        );
        let answer = self.query(
            target,
            token,
            &query,
            json!({ "owner": owner, "name": name, "n": number }),
        )?;
        let pr = &answer["data"]["repository"]["pullRequest"];
        if pr.is_null() {
            return Err(CiProblem::new(
                CiProblemKind::NotFound,
                format!("No pull request #{number}"),
            ));
        }
        let mut threads: Vec<ReviewThread> = pr["reviewThreads"]["nodes"]
            .as_array()
            .into_iter()
            .flatten()
            .map(parse_thread)
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
        let id = &answer.thread_id;
        if !answer.reply.trim().is_empty() {
            self.mutate(
                target,
                token,
                "mutation($id: ID!, $body: String!) { addPullRequestReviewThreadReply(\
                 input: { pullRequestReviewThreadId: $id, body: $body }) { comment { id } } }",
                json!({ "id": id, "body": answer.reply }),
            )?;
        }
        if answer.resolve {
            let query = format!(
                "mutation($id: ID!) {{ resolveReviewThread(input: {{ threadId: $id }}) \
                 {{ thread {{ {THREAD_FIELDS} }} }} }}"
            );
            let resolved = self.mutate(target, token, &query, json!({ "id": id }))?;
            let thread = &resolved["data"]["resolveReviewThread"]["thread"];
            if thread.is_object() {
                return Ok(parse_thread(thread));
            }
        }
        self.threads(target, token, number)?
            .into_iter()
            .find(|t| &t.id == id)
            .ok_or_else(|| CiProblem::new(CiProblemKind::NotFound, "That thread is gone"))
    }
}

const THREAD_FIELDS: &str = "id isResolved path line originalLine \
    comments(first: 1) { nodes { author { login ... on User { name } } body createdAt } }";

impl GitHubPulls {
    /// A mutation; a refusal says which permission writing needs.
    fn mutate(
        &self,
        target: &CiTarget,
        token: &str,
        query: &str,
        variables: Value,
    ) -> Result<Value, CiProblem> {
        self.query(target, token, query, variables)
            .map_err(|p| needs(p, "Pull requests: Read and write"))
    }
}

fn parse_thread(node: &Value) -> ReviewThread {
    let first = &node["comments"]["nodes"][0];
    let author = &first["author"];
    let line = node["line"]
        .as_u64()
        .or(node["originalLine"].as_u64())
        .and_then(|l| u32::try_from(l).ok());
    ReviewThread {
        id: node["id"].as_str().unwrap_or_default().to_owned(),
        author: author["name"]
            .as_str()
            .filter(|n| !n.is_empty())
            .or(author["login"].as_str())
            .unwrap_or("ghost")
            .to_owned(),
        path: node["path"].as_str().unwrap_or_default().to_owned(),
        line,
        body: first["body"].as_str().unwrap_or_default().to_owned(),
        created_at: ts(&first["createdAt"]),
        resolved: node["isResolved"].as_bool().unwrap_or(false),
    }
}

/// GraphQL answers errors with HTTP 200: classified like REST's.
fn graphql_problem(answer: &Value) -> Option<CiProblem> {
    let error = answer["errors"].as_array()?.first()?;
    let message = error["message"].as_str().unwrap_or("GraphQL error");
    let kind = match error["type"].as_str().unwrap_or_default() {
        "NOT_FOUND" => CiProblemKind::NotFound,
        "FORBIDDEN" | "INSUFFICIENT_SCOPES" => CiProblemKind::Forbidden,
        "RATE_LIMITED" => CiProblemKind::RateLimited,
        _ if answer["data"].is_object() && !answer["data"]["repository"].is_null() => return None,
        _ => CiProblemKind::NotFound,
    };
    let mut problem = CiProblem::new(kind, format!("GraphQL · {message}"));
    if kind == CiProblemKind::Forbidden
        && let Some((_, rest)) = message.split_once("scopes: [")
    {
        problem.missing_scope = rest
            .split(']')
            .next()
            .unwrap_or_default()
            .replace(['\'', '"'], "");
    }
    Some(problem)
}

fn person(node: &Value, viewer: &str) -> Person {
    let login = node["login"]
        .as_str()
        .or(node["slug"].as_str())
        .unwrap_or("ghost");
    let name = node["name"]
        .as_str()
        .filter(|n| !n.is_empty())
        .unwrap_or(login);
    Person::new(
        login,
        name,
        !viewer.is_empty() && login.eq_ignore_ascii_case(viewer),
    )
}

pub(super) fn parse_pr(pr: &Value, viewer: &str) -> PullRequest {
    let requested: Vec<Person> = pr["reviewRequests"]["nodes"]
        .as_array()
        .into_iter()
        .flatten()
        .map(|r| person(&r["requestedReviewer"], viewer))
        .collect();
    let mut reviewers = requested.clone();
    for review in pr["latestReviews"]["nodes"]
        .as_array()
        .into_iter()
        .flatten()
    {
        let p = person(&review["author"], viewer);
        if !reviewers.iter().any(|r| r.id == p.id) {
            reviewers.push(p);
        }
    }
    let review = match pr["reviewDecision"].as_str() {
        Some("APPROVED") => ReviewState::Approved,
        Some("CHANGES_REQUESTED") => ReviewState::ChangesRequested,
        Some("REVIEW_REQUIRED") => ReviewState::Required,
        _ if !requested.is_empty() => ReviewState::Required,
        _ => ReviewState::None,
    };
    let rollup = &pr["commits"]["nodes"][0]["commit"]["statusCheckRollup"];
    let contexts: Vec<&Value> = rollup["contexts"]["nodes"]
        .as_array()
        .into_iter()
        .flatten()
        .collect();
    let passed = contexts
        .iter()
        .filter(|c| {
            matches!(
                c["conclusion"].as_str(),
                Some("SUCCESS" | "NEUTRAL" | "SKIPPED")
            ) || c["state"].as_str() == Some("SUCCESS")
        })
        .count();
    PullRequest {
        number: pr["number"].as_u64().unwrap_or_default(),
        label: format!("#{}", pr["number"].as_u64().unwrap_or_default()),
        title: pr["title"].as_str().unwrap_or_default().to_owned(),
        author: person(&pr["author"], viewer),
        branch: pr["headRefName"].as_str().unwrap_or_default().to_owned(),
        base: pr["baseRefName"].as_str().unwrap_or_default().to_owned(),
        draft: pr["isDraft"].as_bool().unwrap_or(false),
        state: match pr["state"].as_str() {
            Some("MERGED") => PrState::Merged,
            Some("CLOSED") => PrState::Closed,
            _ => PrState::Open,
        },
        review,
        review_requested_from_you: requested.iter().any(|p| p.you),
        reviewers,
        checks_passed: u32::try_from(passed).unwrap_or(u32::MAX),
        checks_total: u32::try_from(contexts.len()).unwrap_or(u32::MAX),
        checks_state: match rollup["state"].as_str() {
            Some("SUCCESS") => Some(CiState::Passed),
            Some("FAILURE" | "ERROR") => Some(CiState::Failed),
            Some("PENDING" | "EXPECTED") => Some(CiState::Running),
            _ => None,
        },
        url: pr["url"].as_str().unwrap_or_default().to_owned(),
        created_at: ts(&pr["createdAt"]),
        updated_at: ts(&pr["updatedAt"]),
        comment_count: u32::try_from(pr["comments"]["totalCount"].as_u64().unwrap_or_default())
            .unwrap_or(u32::MAX),
        body: pr["body"].as_str().unwrap_or_default().to_owned(),
        open_threads: pr["reviewThreads"]["nodes"].as_array().map(|nodes| {
            let open = nodes.iter().filter(|t| t["isResolved"] == false).count();
            u32::try_from(open).unwrap_or(u32::MAX)
        }),
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
                provider: CiProvider::GitHubActions,
                host: "github.com".into(),
                api: api.into(),
                web: "https://github.com".into(),
            },
            repo: "platform/repo-a".into(),
            branch: branch.into(),
        }
    }

    #[test]
    fn reads_open_pull_requests_with_review_and_checks() {
        let server = TestServer::start(|r| {
            assert_eq!((r.method.as_str(), r.path.as_str()), ("POST", "/graphql"));
            assert!(
                r.json()["query"]
                    .as_str()
                    .unwrap()
                    .contains("pullRequests(states: OPEN")
            );
            (200, include_str!("fixtures/github_pulls.json").to_owned())
        });
        let prs = GitHubPulls::default()
            .list(&target(&server.url, ""), "gho_x", 30)
            .unwrap();
        assert_eq!(prs.len(), 2);
        let first = &prs[0];
        assert_eq!(
            (
                first.label.as_str(),
                first.title.as_str(),
                first.branch.as_str(),
                first.base.as_str()
            ),
            (
                "#521",
                "feat: bulk discounts by category",
                "feat/TSK-412-bulk-discounts",
                "main"
            )
        );
        assert!(first.draft);
        assert!(first.author.you, "the viewer opened it");
        assert_eq!(first.review, ReviewState::Required);
        assert!(!first.review_requested_from_you);
        assert_eq!(
            first
                .reviewers
                .iter()
                .map(|p| p.name.as_str())
                .collect::<Vec<_>>(),
            ["Lucía"]
        );
        assert_eq!(
            (first.checks_passed, first.checks_total, first.checks_state),
            (2, 3, Some(CiState::Running))
        );
        assert_eq!(first.comment_count, 4);
        let second = &prs[1];
        assert_eq!(
            (
                second.review,
                second.review_requested_from_you,
                second.author.you
            ),
            (ReviewState::ChangesRequested, true, false)
        );
        assert_eq!(
            (
                second.checks_passed,
                second.checks_total,
                second.checks_state
            ),
            (1, 2, Some(CiState::Failed))
        );
        assert_eq!(
            server.requests()[0].header("authorization"),
            Some("Bearer gho_x")
        );
    }

    #[test]
    fn graphql_errors_are_classified() {
        let server = TestServer::start(|_| {
            (200, r#"{"data":{"viewer":{"login":"ana"},"repository":null},"errors":[{"type":"NOT_FOUND","message":"Could not resolve to a Repository with the name 'platform/nope'."}]}"#.to_owned())
        });
        let problem = GitHubPulls::default()
            .list(&target(&server.url, ""), "t", 30)
            .unwrap_err();
        assert_eq!(problem.kind, CiProblemKind::NotFound);
        assert!(problem.detail.starts_with("GraphQL · Could not resolve"));
        let scopes = graphql_problem(&json!({"errors":[{"type":"INSUFFICIENT_SCOPES","message":"Your token has not been granted the required scopes to execute this query. The 'login' field requires one of the following scopes: ['read:user'], but your token has only been granted the: ['repo'] scopes."}]})).unwrap();
        assert_eq!(
            (scopes.kind, scopes.missing_scope.as_str()),
            (CiProblemKind::Forbidden, "read:user")
        );
        assert_eq!(
            GitHubPulls::graphql_url(&target("https://github.acme.dev/api/v3", "")),
            "https://github.acme.dev/api/graphql"
        );
    }

    #[test]
    fn the_branch_pull_request_prefers_the_open_one_and_create_returns_it() {
        let server = TestServer::start(|r| match (r.method.as_str(), r.path.as_str()) {
            ("POST", "/graphql") => (200, include_str!("fixtures/github_pulls.json").to_owned()),
            ("POST", "/repos/platform/repo-a/pulls") => (201, r#"{"number":530}"#.to_owned()),
            ("GET", "/repos/platform/repo-a") => {
                (200, r#"{"default_branch":"main"}"#.to_owned())
            }
            _ => (404, "{}".to_owned()),
        });
        let client = GitHubPulls::default();
        let mine = client
            .for_branch(&target(&server.url, "feat/TSK-412-bulk-discounts"), "t")
            .unwrap()
            .unwrap();
        assert_eq!(mine.label, "#521");
        let new = NewPullRequest {
            title: "feat: x".into(),
            body: "Body".into(),
            branch: "feat/x".into(),
            base: String::new(),
            draft: true,
        };
        client
            .create(&target(&server.url, "feat/x"), "t", &new)
            .unwrap();
        let post = server
            .requests()
            .into_iter()
            .find(|r| r.path.ends_with("/pulls"))
            .unwrap();
        assert_eq!(
            (
                post.json()["head"].as_str(),
                post.json()["base"].as_str(),
                post.json()["draft"].as_bool()
            ),
            (Some("feat/x"), Some("main"), Some(true))
        );
    }

    const THREADS: &str = r#"{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[
        {"id":"PRRT_2","isResolved":false,"path":"src/b.rs","line":null,"originalLine":42,
         "comments":{"nodes":[{"author":{"login":"tomas","name":""},"body":"Offset first?","createdAt":"2026-01-02T10:00:00Z"}]}},
        {"id":"PRRT_1","isResolved":true,"path":"src/a.rs","line":88,"originalLine":80,
         "comments":{"nodes":[{"author":{"login":"lucia","name":"Lucía"},"body":"Retry the batch?","createdAt":"2026-01-01T10:00:00Z"}]}}
    ]}}}}}"#;

    fn thread_server(forbid: bool) -> TestServer {
        TestServer::start(move |r| {
            let query = r.json()["query"].as_str().unwrap_or_default().to_owned();
            if forbid && query.starts_with("mutation") {
                return (200, r#"{"data":{"x":null},"errors":[{"type":"FORBIDDEN","message":"Resource not accessible by integration"}]}"#.to_owned());
            }
            if query.contains("addPullRequestReviewThreadReply") {
                (
                    200,
                    r#"{"data":{"addPullRequestReviewThreadReply":{"comment":{"id":"c"}}}}"#
                        .to_owned(),
                )
            } else if query.contains("resolveReviewThread") {
                (200, r#"{"data":{"resolveReviewThread":{"thread":{"id":"PRRT_2","isResolved":true,"path":"src/b.rs","line":42,"comments":{"nodes":[{"author":{"login":"tomas"},"body":"Offset first?","createdAt":"2026-01-02T10:00:00Z"}]}}}}}"#.to_owned())
            } else {
                (200, THREADS.to_owned())
            }
        })
    }

    #[test]
    fn reads_review_threads_oldest_first() {
        let server = thread_server(false);
        let threads = GitHubPulls::default()
            .threads(&target(&server.url, ""), "t", 521)
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
                ("PRRT_1", "Lucía", "src/a.rs", Some(88), true),
                ("PRRT_2", "tomas", "src/b.rs", Some(42), false),
            ]
        );
        assert_eq!(server.requests()[0].json()["variables"]["n"], 521);
    }

    #[test]
    fn answers_a_thread_with_a_reply_a_resolve_or_both() {
        let client = GitHubPulls::default();
        let answer = |reply: &str, resolve: bool| ThreadAnswer {
            thread_id: "PRRT_2".into(),
            reply: reply.into(),
            resolve,
        };
        let kinds = |server: &TestServer| -> Vec<String> {
            server
                .requests()
                .iter()
                .map(|r| {
                    let q = r.json()["query"].as_str().unwrap_or_default().to_owned();
                    if q.contains("addPullRequestReviewThreadReply") {
                        "reply".to_owned()
                    } else if q.contains("resolveReviewThread") {
                        "resolve".to_owned()
                    } else {
                        "read".to_owned()
                    }
                })
                .collect()
        };

        let server = thread_server(false);
        let both = client
            .answer_thread(&target(&server.url, ""), "t", 521, &answer("Done.", true))
            .unwrap();
        assert!(both.resolved);
        assert_eq!(kinds(&server), ["reply", "resolve"]);
        let reply = &server.requests()[0].json()["variables"];
        assert_eq!(
            (reply["id"].as_str(), reply["body"].as_str()),
            (Some("PRRT_2"), Some("Done."))
        );

        let server = thread_server(false);
        let replied = client
            .answer_thread(
                &target(&server.url, ""),
                "t",
                521,
                &answer("Why not?", false),
            )
            .unwrap();
        assert!(!replied.resolved);
        assert_eq!(kinds(&server), ["reply", "read"]);

        let server = thread_server(false);
        client
            .answer_thread(&target(&server.url, ""), "t", 521, &answer("", true))
            .unwrap();
        assert_eq!(kinds(&server), ["resolve"]);

        let server = thread_server(true);
        let refused = client
            .answer_thread(&target(&server.url, ""), "t", 521, &answer("x", true))
            .unwrap_err();
        assert_eq!(
            (refused.kind, refused.missing_scope.as_str()),
            (CiProblemKind::Forbidden, "Pull requests: Read and write")
        );
    }

    #[test]
    fn the_list_counts_open_threads_when_it_has_them() {
        let pr = json!({"number": 1, "reviewThreads": {"nodes": [{"isResolved": false}, {"isResolved": true}, {"isResolved": false}]}});
        assert_eq!(parse_pr(&pr, "").open_threads, Some(2));
        assert_eq!(parse_pr(&json!({"number": 1}), "").open_threads, None);
    }
}
