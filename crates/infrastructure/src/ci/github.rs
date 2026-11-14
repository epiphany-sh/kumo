//! GitHub Actions (github.com and Enterprise Server), REST API v3.

use std::collections::HashMap;
use std::sync::{Mutex, PoisonError};

use kumo_domain::pipelines::{
    CiClient, CiHost, CiJob, CiProblem, CiProvider, CiRun, CiState, CiTarget,
};
use serde_json::Value;

use super::http::{CiHttp, Header, enc};
use super::{first_line, id, ms_between, ts};

#[derive(Debug, Default)]
pub struct GitHubActions {
    http: CiHttp,
    /// Failure line per failed job id (annotations don't change).
    failures: Mutex<HashMap<String, Option<String>>>,
}

impl GitHubActions {
    fn headers(token: &str) -> [Header; 3] {
        [
            ("Authorization", format!("Bearer {token}")),
            ("Accept", "application/vnd.github+json".to_owned()),
            ("X-GitHub-Api-Version", "2022-11-28".to_owned()),
        ]
    }

    fn base(target: &CiTarget) -> String {
        format!("{}/repos/{}", target.host.api, target.repo)
    }

    /// The first useful annotation of a failed job (its check run).
    fn failure(&self, base: &str, job: &str, headers: &[Header]) -> Option<String> {
        if let Some(known) = self
            .failures
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .get(job)
        {
            return known.clone();
        }
        // Best effort: a failure here leaves the line empty, and is retried.
        let annotations = self
            .http
            .get_json(&format!("{base}/check-runs/{job}/annotations"), headers)
            .ok()?;
        let line = failure_line(&annotations);
        self.failures
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .insert(job.to_owned(), line.clone());
        line
    }
}

impl CiClient for GitHubActions {
    fn provider(&self) -> CiProvider {
        CiProvider::GitHubActions
    }

    fn latest_run(&self, target: &CiTarget, token: &str) -> Result<Option<CiRun>, CiProblem> {
        Ok(self.runs(target, token)?.into_iter().next())
    }

    fn runs(&self, target: &CiTarget, token: &str) -> Result<Vec<CiRun>, CiProblem> {
        let headers = Self::headers(token);
        let base = Self::base(target);
        let listed = self.http.get_json(
            &format!(
                "{base}/actions/runs?branch={}&per_page={RUNS_LISTED}",
                enc(&target.branch)
            ),
            &headers,
        )?;
        let mut runs = Vec::new();
        for run in latest_commit_runs(&listed) {
            let jobs = self.http.get_json(
                &format!("{base}/actions/runs/{}/jobs?per_page=100", id(&run["id"])),
                &headers,
            )?;
            let mut run = parse_run(run, &jobs);
            for job in run.jobs.iter_mut().filter(|j| j.state == CiState::Failed) {
                job.failure = self.failure(&base, &job.id, &headers);
            }
            runs.push(run);
        }
        Ok(runs)
    }

    fn rerun_failed(&self, target: &CiTarget, token: &str, run: &CiRun) -> Result<(), CiProblem> {
        let url = format!(
            "{}/actions/runs/{}/rerun-failed-jobs",
            Self::base(target),
            run.id
        );
        self.http.post(&url, &Self::headers(token), None).map(drop)
    }

    fn test(&self, host: &CiHost, token: &str) -> Result<String, CiProblem> {
        let user = self
            .http
            .get_json(&format!("{}/user", host.api), &Self::headers(token))?;
        Ok(format!(
            "Signed in as {}",
            user["login"].as_str().unwrap_or("?")
        ))
    }
}

/// Runs asked for per poll: enough for every workflow of a commit, and the
/// re-runs and cancelled ones around them.
const RUNS_LISTED: usize = 30;
/// Runs shown per commit (each costs a request for its jobs).
const RUNS_SHOWN: usize = 8;

/// A commit usually starts one run per workflow, and a pull request's
/// checks are only some of them. From the branch's runs, newest first: the
/// ones of the newest run's commit, one per workflow and event (the newest:
/// re-runs replace what they re-ran), the pull request's first.
fn latest_commit_runs(listed: &Value) -> Vec<&Value> {
    let all = listed["workflow_runs"]
        .as_array()
        .map_or(&[][..], Vec::as_slice);
    let Some(sha) = all.first().map(|run| &run["head_sha"]) else {
        return Vec::new();
    };
    let mut seen = Vec::new();
    let mut runs: Vec<&Value> = all
        .iter()
        .filter(|run| &run["head_sha"] == sha)
        .filter(|run| {
            let key = (&run["workflow_id"], &run["event"]);
            let new = !seen.contains(&key);
            seen.push(key);
            new
        })
        .take(RUNS_SHOWN)
        .collect();
    // Stable: each group keeps the newest first.
    runs.sort_by_key(|run| !for_pull_request(run));
    runs
}

/// `pull_request` and `pull_request_target`: what the PR page lists.
fn for_pull_request(run: &Value) -> bool {
    run["event"]
        .as_str()
        .is_some_and(|event| event.starts_with("pull_request"))
}

/// `status` + `conclusion` of a run or job.
fn state_of(item: &Value) -> CiState {
    match item["status"].as_str().unwrap_or_default() {
        "in_progress" => CiState::Running,
        "completed" => match item["conclusion"].as_str().unwrap_or_default() {
            "success" | "neutral" => CiState::Passed,
            "cancelled" => CiState::Canceled,
            "skipped" | "stale" => CiState::Skipped,
            _ => CiState::Failed,
        },
        // queued, requested, waiting, pending.
        _ => CiState::Queued,
    }
}

pub(super) fn parse_run(run: &Value, jobs: &Value) -> CiRun {
    let state = state_of(run);
    let attempt = run["run_attempt"].as_u64().unwrap_or(1);
    let title = run["display_title"]
        .as_str()
        .and_then(first_line)
        .or_else(|| run["head_commit"]["message"].as_str().and_then(first_line))
        .unwrap_or_default();
    CiRun {
        id: id(&run["id"]),
        label: match attempt {
            1 => format!("run #{}", id(&run["run_number"])),
            n => format!("run #{} · attempt {n}", id(&run["run_number"])),
        },
        sha: run["head_sha"].as_str().unwrap_or_default().to_owned(),
        title,
        state,
        created_at: ts(&run["created_at"]),
        finished_at: if state.active() {
            None
        } else {
            ts(&run["updated_at"])
        },
        url: run["html_url"].as_str().unwrap_or_default().to_owned(),
        jobs: jobs["jobs"]
            .as_array()
            .into_iter()
            .flatten()
            .map(|job| {
                let started = ts(&job["started_at"]);
                CiJob {
                    id: id(&job["id"]),
                    name: job["name"].as_str().unwrap_or_default().to_owned(),
                    state: state_of(job),
                    duration_ms: ms_between(started, ts(&job["completed_at"])),
                    started_at: started,
                    failure: None,
                    url: job["html_url"].as_str().unwrap_or_default().to_owned(),
                }
            })
            .collect(),
        workflow: run["name"].as_str().unwrap_or_default().to_owned(),
        pull_request: for_pull_request(run),
    }
}

/// `bulk_test.go:88 · expected 3 rows, got 2` from a check run's
/// annotations; the generic "Process completed with exit code 1." only
/// when there's nothing better.
pub(super) fn failure_line(annotations: &Value) -> Option<String> {
    let failures: Vec<&Value> = annotations
        .as_array()?
        .iter()
        .filter(|a| a["annotation_level"] == "failure")
        .collect();
    let generic = |a: &&Value| {
        a["message"]
            .as_str()
            .is_some_and(|m| m.starts_with("Process completed with exit code"))
    };
    let best = failures
        .iter()
        .find(|a| !generic(a))
        .or_else(|| failures.first())?;
    let message = first_line(best["message"].as_str().unwrap_or_default())?;
    let path = best["path"].as_str().unwrap_or_default();
    if path.is_empty() || path == ".github" {
        return Some(message);
    }
    let file = path.rsplit('/').next().unwrap_or(path);
    Some(match best["start_line"].as_u64() {
        Some(line) => format!("{file}:{line} · {message}"),
        None => format!("{file} · {message}"),
    })
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;
    use std::sync::atomic::{AtomicUsize, Ordering};

    use kumo_domain::pipelines::CiProblemKind;

    use super::*;
    use crate::test_server::TestServer;

    fn fixture(name: &str) -> Value {
        serde_json::from_str(match name {
            "runs" => include_str!("fixtures/github_runs.json"),
            "jobs" => include_str!("fixtures/github_jobs.json"),
            _ => include_str!("fixtures/github_annotations.json"),
        })
        .unwrap()
    }

    #[test]
    fn parses_a_run_and_its_jobs() {
        let run = parse_run(&fixture("runs")["workflow_runs"][0], &fixture("jobs"));
        assert_eq!(run.id, "11896352187");
        assert_eq!(run.label, "run #8812 · attempt 2");
        assert_eq!(run.short_sha(), "4e1b2c0");
        assert_eq!(run.title, "feat: BulkDiscount aggregate");
        assert_eq!(run.state, CiState::Failed);
        assert!(run.finished_at.is_some());
        let states: Vec<_> = run
            .jobs
            .iter()
            .map(|j| (j.name.as_str(), j.state))
            .collect();
        assert_eq!(
            states,
            [
                ("build", CiState::Passed),
                ("integration · testcontainers", CiState::Failed),
                ("golangci-lint", CiState::Running),
                ("deploy · staging", CiState::Skipped),
            ]
        );
        assert_eq!(run.jobs[0].duration_ms, Some(72_000));
        assert_eq!(run.jobs[2].duration_ms, None);
        assert!(run.jobs[2].started_at.is_some());
        assert!(run.active(), "a job is still running");
        assert_eq!((run.workflow.as_str(), run.pull_request), ("CI", false));
    }

    #[test]
    fn a_commit_shows_each_workflow_once_and_the_pull_requests_first() {
        let run = |id: u64, workflow: u64, event: &str, sha: &str| serde_json::json!({ "id": id, "workflow_id": workflow, "event": event, "head_sha": sha });
        // Newest first, as GitHub lists them.
        let listed = serde_json::json!({ "workflow_runs": [
            run(9, 1, "push", "bbb"),
            run(8, 2, "pull_request", "bbb"),
            run(7, 3, "pull_request_target", "bbb"),
            run(6, 2, "pull_request", "bbb"),
            run(5, 2, "push", "bbb"),
            run(4, 2, "pull_request", "aaa"),
        ]});
        let ids: Vec<u64> = latest_commit_runs(&listed)
            .iter()
            .map(|r| r["id"].as_u64().unwrap())
            .collect();
        assert_eq!(
            ids,
            [8, 7, 9, 5],
            "the PR's checks, then the rest; not the run a re-run replaced, nor older commits"
        );
        assert!(latest_commit_runs(&serde_json::json!({ "workflow_runs": [] })).is_empty());
        assert!(latest_commit_runs(&serde_json::json!({})).is_empty());
    }

    #[test]
    fn every_run_of_the_commit_comes_with_its_jobs() {
        let server = TestServer::start(|r| {
            match r.path.as_str() {
            p if p.contains("/actions/runs?") => (
                200,
                serde_json::json!({ "workflow_runs": [
                    { "id": 2, "name": "deploy", "workflow_id": 20, "event": "push", "head_sha": "bbb", "status": "in_progress", "run_number": 4 },
                    { "id": 1, "name": "ci", "workflow_id": 10, "event": "pull_request", "head_sha": "bbb", "status": "completed", "conclusion": "success", "run_number": 31 },
                ]})
                .to_string(),
            ),
            p if p.contains("/actions/runs/1/jobs") => (
                200,
                r#"{"jobs":[{"id":11,"name":"test","status":"completed","conclusion":"success"},{"id":12,"name":"lint","status":"completed","conclusion":"success"}]}"#.to_owned(),
            ),
            p if p.contains("/actions/runs/2/jobs") => (
                200,
                r#"{"jobs":[{"id":21,"name":"staging","status":"in_progress"}]}"#.to_owned(),
            ),
            _ => (404, r#"{"message":"Not Found"}"#.to_owned()),
        }
        });
        let client = GitHubActions::default();
        let runs = client.runs(&target(&server.url), "t").unwrap();
        let seen: Vec<_> = runs
            .iter()
            .map(|r| (r.workflow.as_str(), r.pull_request, r.jobs.len()))
            .collect();
        assert_eq!(seen, [("ci", true, 2), ("deploy", false, 1)]);
        assert_eq!(
            client
                .latest_run(&target(&server.url), "t")
                .unwrap()
                .unwrap()
                .id,
            "1",
            "the pull request's run is the one on top"
        );
    }

    #[test]
    fn the_failure_line_skips_the_generic_exit_code() {
        assert_eq!(
            failure_line(&fixture("annotations")).as_deref(),
            Some("bulk_test.go:88 · expected 3 rows, got 2")
        );
        let only_generic = serde_json::json!([{ "path": ".github", "annotation_level": "failure", "message": "Process completed with exit code 2." }]);
        assert_eq!(
            failure_line(&only_generic).as_deref(),
            Some("Process completed with exit code 2.")
        );
        assert_eq!(failure_line(&serde_json::json!([])), None);
    }

    fn target(api: &str) -> CiTarget {
        CiTarget {
            host: CiHost {
                provider: CiProvider::GitHubActions,
                host: "github.com".into(),
                api: api.into(),
                web: "https://github.com".into(),
            },
            repo: "platform/repo-a".into(),
            branch: "feat/TSK-412-bulk-discounts".into(),
        }
    }

    #[test]
    fn polls_with_etags_and_reruns_failed_jobs() {
        let annotations = Arc::new(AtomicUsize::new(0));
        let seen = Arc::clone(&annotations);
        let server = TestServer::with_headers(move |r| {
            let etag = |tag: &str| vec![("ETag".to_owned(), tag.to_owned())];
            match (r.method.as_str(), r.path.as_str()) {
                ("GET", p) if p.starts_with("/repos/platform/repo-a/actions/runs?") => {
                    assert_eq!(
                        p,
                        "/repos/platform/repo-a/actions/runs?branch=feat%2FTSK-412-bulk-discounts&per_page=30"
                    );
                    if r.header("if-none-match") == Some("\"runs-1\"") {
                        (304, etag("\"runs-1\""), String::new())
                    } else {
                        (
                            200,
                            etag("\"runs-1\""),
                            include_str!("fixtures/github_runs.json").to_owned(),
                        )
                    }
                }
                ("GET", p) if p.contains("/jobs") => (
                    200,
                    Vec::new(),
                    include_str!("fixtures/github_jobs.json").to_owned(),
                ),
                ("GET", p) if p.ends_with("/check-runs/33190011002/annotations") => {
                    seen.fetch_add(1, Ordering::SeqCst);
                    (
                        200,
                        Vec::new(),
                        include_str!("fixtures/github_annotations.json").to_owned(),
                    )
                }
                ("POST", "/repos/platform/repo-a/actions/runs/11896352187/rerun-failed-jobs") => {
                    (201, Vec::new(), String::new())
                }
                _ => (404, Vec::new(), r#"{"message":"Not Found"}"#.to_owned()),
            }
        });
        let client = GitHubActions::default();
        let target = target(&server.url);
        let first = client.latest_run(&target, "ghp_secret").unwrap().unwrap();
        let second = client.latest_run(&target, "ghp_secret").unwrap().unwrap();
        assert_eq!(first, second, "a 304 reuses the last answer");
        assert_eq!(
            first.jobs[1].failure.as_deref(),
            Some("bulk_test.go:88 · expected 3 rows, got 2")
        );
        assert_eq!(
            annotations.load(Ordering::SeqCst),
            1,
            "annotations are read once per job"
        );

        client.rerun_failed(&target, "ghp_secret", &first).unwrap();
        let requests = server.requests();
        assert_eq!(
            requests[0].header("authorization"),
            Some("Bearer ghp_secret")
        );
        assert_eq!(requests[3].header("if-none-match"), Some("\"runs-1\""));
        assert!(requests.iter().any(|r| r.method == "POST"));
    }

    #[test]
    fn problems_come_classified_and_without_the_token() {
        let server = TestServer::with_headers(|_| {
            (
                403,
                vec![(
                    "X-Accepted-GitHub-Permissions".to_owned(),
                    "actions=read".to_owned(),
                )],
                r#"{"message":"Resource not accessible by personal access token"}"#.to_owned(),
            )
        });
        let problem = GitHubActions::default()
            .latest_run(&target(&server.url), "ghp_secret")
            .unwrap_err();
        assert_eq!(problem.kind, CiProblemKind::Forbidden);
        assert_eq!(problem.missing_scope, "actions:read");
        assert!(!format!("{problem:?}").contains("ghp_secret"));

        let gone = GitHubActions::default()
            .latest_run(&target("http://127.0.0.1:1"), "ghp_secret")
            .unwrap_err();
        assert_eq!(gone.kind, CiProblemKind::Unreachable);
        assert!(!gone.detail.contains("ghp_secret"));
    }

    #[test]
    fn a_branch_without_runs_has_none() {
        let server =
            TestServer::start(|_| (200, r#"{"total_count":0,"workflow_runs":[]}"#.to_owned()));
        assert_eq!(
            GitHubActions::default()
                .latest_run(&target(&server.url), "t")
                .unwrap(),
            None
        );
    }
}
