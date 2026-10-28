//! GitHub pull requests through GraphQL: one request brings each pull
//! request with its review decision, requested reviewers and checks.

use kumo_domain::pipelines::{CiProblem, CiProblemKind, CiProvider, CiState, CiTarget};
use kumo_domain::pulls::{NewPullRequest, PrState, PullRequest, PullRequestClient, ReviewState};
use kumo_domain::tasks::Person;
use serde_json::{Value, json};

use super::http::{CiHttp, Header};
use super::ts;

const FIELDS: &str = "number title url isDraft state createdAt updatedAt headRefName baseRefName reviewDecision \
    author { login ... on User { name } } \
    reviewRequests(first: 20) { nodes { requestedReviewer { ... on User { login name } ... on Team { slug name } } } } \
    latestReviews(first: 20) { nodes { author { login ... on User { name } } state } } \
    comments { totalCount } \
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
            repo: "pricing/price-admin".into(),
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
                "feat/PRC-412-bulk-discounts",
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
            (200, r#"{"data":{"viewer":{"login":"ana"},"repository":null},"errors":[{"type":"NOT_FOUND","message":"Could not resolve to a Repository with the name 'pricing/nope'."}]}"#.to_owned())
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
            ("POST", "/repos/pricing/price-admin/pulls") => (201, r#"{"number":530}"#.to_owned()),
            ("GET", "/repos/pricing/price-admin") => {
                (200, r#"{"default_branch":"main"}"#.to_owned())
            }
            _ => (404, "{}".to_owned()),
        });
        let client = GitHubPulls::default();
        let mine = client
            .for_branch(&target(&server.url, "feat/PRC-412-bulk-discounts"), "t")
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
}
