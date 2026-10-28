//! Bitbucket Pipelines (Bitbucket Cloud), API 2.0.

use base64::Engine;
use kumo_domain::pipelines::{
    CiClient, CiHost, CiJob, CiProblem, CiProvider, CiRun, CiState, CiTarget,
};
use serde_json::{Value, json};

use super::http::{CiHttp, Header, enc};
use super::{id, ts};

#[derive(Debug, Default)]
pub struct BitbucketPipelines {
    http: CiHttp,
}

impl BitbucketPipelines {
    /// `email:api-token` (or `user:app-password`) signs in with Basic auth;
    /// a repository or workspace access token goes as a Bearer token.
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
}

impl CiClient for BitbucketPipelines {
    fn provider(&self) -> CiProvider {
        CiProvider::BitbucketPipelines
    }

    fn latest_run(&self, target: &CiTarget, token: &str) -> Result<Option<CiRun>, CiProblem> {
        let headers = Self::headers(token);
        let base = Self::base(target);
        let list = self.http.get_json(
            &format!(
                "{base}/pipelines/?target.branch={}&sort=-created_on&pagelen=1",
                enc(&target.branch)
            ),
            &headers,
        )?;
        let Some(pipeline) = list["values"].get(0) else {
            return Ok(None);
        };
        let uuid = pipeline["uuid"].as_str().unwrap_or_default();
        let steps = self.http.get_json(
            &format!("{base}/pipelines/{}/steps/?pagelen=100", enc(uuid)),
            &headers,
        )?;
        Ok(Some(parse_run(
            pipeline,
            &steps,
            &format!("{}/{}", target.host.web, target.repo),
        )))
    }

    /// Steps can't be re-run through the API: a new pipeline runs for the
    /// same commit.
    fn rerun_failed(&self, target: &CiTarget, token: &str, run: &CiRun) -> Result<(), CiProblem> {
        let body = json!({
            "target": {
                "type": "pipeline_ref_target",
                "ref_type": "branch",
                "ref_name": target.branch,
                "commit": { "type": "commit", "hash": run.sha },
            }
        });
        let url = format!("{}/pipelines/", Self::base(target));
        self.http
            .post(&url, &Self::headers(token), Some(&body))
            .map(drop)
    }

    fn test(&self, host: &CiHost, token: &str) -> Result<String, CiProblem> {
        let user = self
            .http
            .get_json(&format!("{}/user", host.api), &Self::headers(token))?;
        Ok(format!(
            "Signed in as {}",
            user["display_name"]
                .as_str()
                .or(user["username"].as_str())
                .unwrap_or("?")
        ))
    }
}

/// `state.name` + `state.result.name` (or `state.stage.name` while running).
fn state_of(item: &Value) -> CiState {
    let s = &item["state"];
    match s["name"].as_str().unwrap_or_default() {
        "IN_PROGRESS" => match s["stage"]["name"].as_str() {
            Some("PAUSED" | "HALTED") => CiState::Queued,
            _ => CiState::Running,
        },
        "COMPLETED" => match s["result"]["name"].as_str().unwrap_or_default() {
            "SUCCESSFUL" => CiState::Passed,
            "STOPPED" | "EXPIRED" => CiState::Canceled,
            "NOT_RUN" => CiState::Skipped,
            _ => CiState::Failed,
        },
        "NOT_RUN" => CiState::Skipped,
        // PENDING, READY.
        _ => CiState::Queued,
    }
}

/// `web` is the repository's page (`https://bitbucket.org/team/repo`).
pub(super) fn parse_run(pipeline: &Value, steps: &Value, web: &str) -> CiRun {
    let state = state_of(pipeline);
    let url = format!("{web}/pipelines/results/{}", id(&pipeline["build_number"]));
    CiRun {
        id: pipeline["uuid"].as_str().unwrap_or_default().to_owned(),
        label: format!("pipeline #{}", id(&pipeline["build_number"])),
        sha: pipeline["target"]["commit"]["hash"]
            .as_str()
            .unwrap_or_default()
            .to_owned(),
        title: pipeline["target"]["commit"]["message"]
            .as_str()
            .and_then(|m| m.lines().next())
            .unwrap_or_default()
            .trim()
            .to_owned(),
        state,
        created_at: ts(&pipeline["created_on"]),
        finished_at: if state.active() {
            None
        } else {
            ts(&pipeline["completed_on"])
        },
        jobs: steps["values"]
            .as_array()
            .into_iter()
            .flatten()
            .map(|step| {
                let state = state_of(step);
                let uuid = step["uuid"].as_str().unwrap_or_default();
                CiJob {
                    id: uuid.to_owned(),
                    name: step["name"].as_str().unwrap_or_default().to_owned(),
                    state,
                    duration_ms: step["duration_in_seconds"]
                        .as_u64()
                        .filter(|_| !state.active())
                        .map(|s| s * 1000),
                    started_at: ts(&step["started_on"]),
                    failure: None,
                    url: format!("{url}/steps/{}", enc(uuid)),
                }
            })
            .collect(),
        url,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_server::TestServer;

    #[test]
    fn parses_a_pipeline_and_its_steps() {
        let pipelines: Value =
            serde_json::from_str(include_str!("fixtures/bitbucket_pipelines.json")).unwrap();
        let steps: Value =
            serde_json::from_str(include_str!("fixtures/bitbucket_steps.json")).unwrap();
        let run = parse_run(
            &pipelines["values"][0],
            &steps,
            "https://bitbucket.org/fravega-identity/users-api",
        );
        assert_eq!(run.id, "{6b1e0a52-3a4f-4f0e-9a9c-2b5d0f1e7c11}");
        assert_eq!(run.label, "pipeline #132");
        assert_eq!(run.short_sha(), "c0ffee1");
        assert_eq!(run.state, CiState::Failed);
        assert_eq!(
            run.url,
            "https://bitbucket.org/fravega-identity/users-api/pipelines/results/132"
        );
        let states: Vec<_> = run
            .jobs
            .iter()
            .map(|j| (j.name.as_str(), j.state, j.duration_ms))
            .collect();
        assert_eq!(
            states,
            [
                ("Build and test", CiState::Failed, Some(300_000)),
                ("Deploy to staging", CiState::Skipped, None)
            ]
        );
        assert!(run.finished_at.is_some());
    }

    #[test]
    fn rerun_starts_a_pipeline_for_the_same_commit() {
        let server = TestServer::start(|r| match (r.method.as_str(), r.path.as_str()) {
            (
                "GET",
                "/repositories/team/users-api/pipelines/?target.branch=feat%2Faudit-log&sort=-created_on&pagelen=1",
            ) => (
                200,
                include_str!("fixtures/bitbucket_pipelines.json").to_owned(),
            ),
            (
                "GET",
                "/repositories/team/users-api/pipelines/%7B6b1e0a52-3a4f-4f0e-9a9c-2b5d0f1e7c11%7D/steps/?pagelen=100",
            ) => (
                200,
                include_str!("fixtures/bitbucket_steps.json").to_owned(),
            ),
            ("POST", "/repositories/team/users-api/pipelines/") => {
                (201, r#"{"type":"pipeline","build_number":133}"#.to_owned())
            }
            _ => (
                404,
                r#"{"type":"error","error":{"message":"Not found"}}"#.to_owned(),
            ),
        });
        let target = CiTarget {
            host: CiHost {
                provider: CiProvider::BitbucketPipelines,
                host: "bitbucket.org".into(),
                api: server.url.clone(),
                web: "https://bitbucket.org".into(),
            },
            repo: "team/users-api".into(),
            branch: "feat/audit-log".into(),
        };
        let client = BitbucketPipelines::default();
        let run = client
            .latest_run(&target, "ana@acme.com:ATATT-secret")
            .unwrap()
            .unwrap();
        client
            .rerun_failed(&target, "ana@acme.com:ATATT-secret", &run)
            .unwrap();
        let requests = server.requests();
        assert!(
            requests[0]
                .header("authorization")
                .unwrap()
                .starts_with("Basic ")
        );
        let post = requests.last().unwrap();
        assert_eq!(
            post.json()["target"]["commit"]["hash"],
            "c0ffee1234567890abcdef1234567890abcdef12"
        );
        assert_eq!(post.json()["target"]["ref_name"], "feat/audit-log");
        assert_eq!(
            BitbucketPipelines::headers("repo-token")[0].1,
            "Bearer repo-token"
        );
    }
}
