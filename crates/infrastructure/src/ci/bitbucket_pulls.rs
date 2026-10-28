//! Bitbucket Cloud pull requests, API 2.0.

use base64::Engine;
use kumo_domain::pipelines::{CiProblem, CiProvider, CiState, CiTarget};
use kumo_domain::pulls::{NewPullRequest, PrState, PullRequest, PullRequestClient, ReviewState};
use kumo_domain::tasks::Person;
use serde_json::{Value, json};

use super::http::{CiHttp, Header, enc};
use super::ts;

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
}
