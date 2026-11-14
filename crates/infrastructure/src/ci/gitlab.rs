//! GitLab CI (gitlab.com and self-managed), REST API v4.

use std::collections::HashMap;
use std::sync::{Mutex, PoisonError};

use kumo_domain::pipelines::{
    CiClient, CiHost, CiJob, CiProblem, CiProvider, CiRun, CiState, CiTarget,
};
use serde_json::Value;

use super::http::{CiHttp, Header, enc};
use super::{first_line, id, ts};

#[derive(Debug, Default)]
pub struct GitLabCi {
    http: CiHttp,
    /// Failure line per failed job id (finished logs don't change).
    failures: Mutex<HashMap<String, Option<String>>>,
}

impl GitLabCi {
    fn headers(token: &str) -> [Header; 1] {
        [("PRIVATE-TOKEN", token.to_owned())]
    }

    /// The project by its full path (`group/sub/name` → `group%2Fsub%2Fname`).
    fn base(target: &CiTarget) -> String {
        format!("{}/projects/{}", target.host.api, enc(&target.repo))
    }

    fn failure(&self, base: &str, job: &str, headers: &[Header]) -> Option<String> {
        if let Some(known) = self
            .failures
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .get(job)
        {
            return known.clone();
        }
        let trace = self
            .http
            .get_text(&format!("{base}/jobs/{job}/trace"), headers)
            .ok()?;
        let line = failure_line(&trace);
        self.failures
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .insert(job.to_owned(), line.clone());
        line
    }
}

impl GitLabCi {
    /// The newest pipeline of the branch's open merge request, with the
    /// merge request's head commit. Best effort: without it the branch's
    /// own pipeline shows alone.
    fn request_pipeline(
        &self,
        base: &str,
        branch: &str,
        headers: &[Header],
    ) -> Option<(String, Value)> {
        let requests = self
            .http
            .get_json(
                &format!(
                    "{base}/merge_requests?source_branch={}&state=opened&order_by=updated_at&sort=desc&per_page=1",
                    enc(branch)
                ),
                headers,
            )
            .ok()?;
        let request = requests.get(0)?;
        let head = request["sha"].as_str()?.to_owned();
        let pipelines = self
            .http
            .get_json(
                &format!(
                    "{base}/merge_requests/{}/pipelines?per_page=20",
                    id(&request["iid"])
                ),
                headers,
            )
            .ok()?;
        // Newest first; the list can carry the branch's pipelines too.
        let pipeline = pipelines.as_array()?.iter().find(|p| {
            p["ref"]
                .as_str()
                .is_some_and(|r| r.starts_with("refs/merge-requests/"))
        })?;
        Some((head, pipeline.clone()))
    }
}

impl CiClient for GitLabCi {
    fn provider(&self) -> CiProvider {
        CiProvider::GitLabCi
    }

    fn latest_run(&self, target: &CiTarget, token: &str) -> Result<Option<CiRun>, CiProblem> {
        Ok(self.runs(target, token)?.into_iter().next())
    }

    /// The merge request's pipeline, then the branch's. A merge request
    /// pipeline hangs from the merge request's own ref, so asking for the
    /// branch's pipelines never lists it.
    fn runs(&self, target: &CiTarget, token: &str) -> Result<Vec<CiRun>, CiProblem> {
        let headers = Self::headers(token);
        let base = Self::base(target);
        let pipelines = self.http.get_json(
            &format!("{base}/pipelines?ref={}&per_page=1", enc(&target.branch)),
            &headers,
        )?;
        let of_branch = pipelines.get(0);
        let of_request = self.request_pipeline(&base, &target.branch, &headers);
        let mut picked: Vec<(&Value, bool)> = Vec::new();
        if let Some((_, pipeline)) = &of_request {
            picked.push((pipeline, true));
        }
        if let Some(pipeline) = of_branch {
            // Next to the merge request's, only the one of the same commit:
            // an older one is from before the merge request had pipelines.
            let same = |(head, request): &(String, Value)| {
                pipeline["sha"].as_str() == Some(head) && pipeline["id"] != request["id"]
            };
            if of_request.as_ref().is_none_or(same) {
                picked.push((pipeline, false));
            }
        }
        let mut runs = Vec::new();
        for (pipeline, for_request) in picked {
            let jobs = self.http.get_json(
                &format!("{base}/pipelines/{}/jobs?per_page=100", id(&pipeline["id"])),
                &headers,
            )?;
            let mut run = parse_run(pipeline, &jobs);
            run.pull_request = for_request;
            run.workflow = if for_request {
                "merge request".to_owned()
            } else {
                "branch".to_owned()
            };
            for job in run.jobs.iter_mut().filter(|j| j.state == CiState::Failed) {
                job.failure = self.failure(&base, &job.id, &headers);
            }
            runs.push(run);
        }
        Ok(runs)
    }

    fn rerun_failed(&self, target: &CiTarget, token: &str, run: &CiRun) -> Result<(), CiProblem> {
        let url = format!("{}/pipelines/{}/retry", Self::base(target), run.id);
        self.http.post(&url, &Self::headers(token), None).map(drop)
    }

    fn test(&self, host: &CiHost, token: &str) -> Result<String, CiProblem> {
        let user = self
            .http
            .get_json(&format!("{}/user", host.api), &Self::headers(token))?;
        Ok(format!(
            "Signed in as {}",
            user["username"].as_str().unwrap_or("?")
        ))
    }
}

fn state_of(status: &str) -> CiState {
    match status {
        "running" => CiState::Running,
        "success" => CiState::Passed,
        "failed" => CiState::Failed,
        "canceled" | "canceling" => CiState::Canceled,
        // Manual jobs only run when someone starts them.
        "skipped" | "manual" => CiState::Skipped,
        // created, waiting_for_resource, preparing, pending, scheduled.
        _ => CiState::Queued,
    }
}

pub(super) fn parse_run(pipeline: &Value, jobs: &Value) -> CiRun {
    let state = state_of(pipeline["status"].as_str().unwrap_or_default());
    // Jobs come newest first: pipeline order is by id.
    let mut list: Vec<&Value> = jobs.as_array().into_iter().flatten().collect();
    list.sort_by_key(|j| j["id"].as_u64().unwrap_or_default());
    let number = pipeline
        .get("iid")
        .filter(|v| !v.is_null())
        .unwrap_or(&pipeline["id"]);
    CiRun {
        id: id(&pipeline["id"]),
        label: format!("pipeline #{}", id(number)),
        sha: pipeline["sha"].as_str().unwrap_or_default().to_owned(),
        title: list
            .iter()
            .find_map(|j| j["commit"]["title"].as_str().and_then(first_line))
            .unwrap_or_default(),
        state,
        created_at: ts(&pipeline["created_at"]),
        finished_at: if state.active() {
            None
        } else {
            ts(&pipeline["finished_at"]).or_else(|| ts(&pipeline["updated_at"]))
        },
        url: pipeline["web_url"].as_str().unwrap_or_default().to_owned(),
        jobs: list
            .into_iter()
            .map(|job| {
                let state = state_of(job["status"].as_str().unwrap_or_default());
                CiJob {
                    id: id(&job["id"]),
                    name: job["name"].as_str().unwrap_or_default().to_owned(),
                    state,
                    // Running jobs report the time so far: only finished ones count.
                    duration_ms: job["duration"]
                        .as_f64()
                        .filter(|_| !state.active())
                        .map(|s| (s * 1000.0).round() as u64),
                    started_at: ts(&job["started_at"]),
                    failure: None,
                    url: job["web_url"].as_str().unwrap_or_default().to_owned(),
                }
            })
            .collect(),
        workflow: String::new(),
        pull_request: false,
    }
}

/// The first line that looks like the failure in the end of a job log,
/// past GitLab's own section markers and colors.
pub(super) fn failure_line(trace: &str) -> Option<String> {
    let clean = strip_ansi(trace);
    let lines: Vec<&str> = clean
        .split(['\n', '\r'])
        .map(str::trim)
        .filter(|l| !l.is_empty() && !l.starts_with("section_"))
        .collect();
    let tail = &lines[lines.len().saturating_sub(80)..];
    let boilerplate = |l: &str| {
        l.starts_with("ERROR: Job failed")
            || l.starts_with("make: ***")
            || l.starts_with("Cleaning up")
            || l.starts_with("Uploading artifacts")
    };
    let looks_failed = |l: &str| {
        let lower = l.to_ascii_lowercase();
        [
            "fail",
            "error",
            "panic",
            "fatal",
            "exception",
            "assert",
            "expected",
        ]
        .iter()
        .any(|w| lower.contains(w))
    };
    tail.iter()
        .find(|l| !boilerplate(l) && looks_failed(l) && *l != &"FAIL")
        .or_else(|| tail.iter().rev().find(|l| !boilerplate(l)))
        .map(|l| l.chars().take(160).collect())
}

fn strip_ansi(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut chars = text.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '\u{1b}' && chars.peek() == Some(&'[') {
            chars.next();
            for c in chars.by_ref() {
                if c.is_ascii_alphabetic() {
                    break;
                }
            }
        } else {
            out.push(c);
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use kumo_domain::pipelines::CiProblemKind;

    use super::*;
    use crate::test_server::TestServer;

    fn fixture(name: &str) -> Value {
        serde_json::from_str(match name {
            "pipelines" => include_str!("fixtures/gitlab_pipelines.json"),
            _ => include_str!("fixtures/gitlab_jobs.json"),
        })
        .unwrap()
    }

    #[test]
    fn parses_a_pipeline_and_its_jobs() {
        let run = parse_run(&fixture("pipelines")[0], &fixture("jobs"));
        assert_eq!(run.id, "991204417");
        assert_eq!(run.label, "pipeline #4417");
        assert_eq!(run.short_sha(), "9a7c3e1");
        assert_eq!(run.title, "fix: rounding in bulk discounts");
        assert_eq!(run.state, CiState::Running);
        assert_eq!(run.finished_at, None);
        let states: Vec<_> = run
            .jobs
            .iter()
            .map(|j| (j.name.as_str(), j.state, j.duration_ms))
            .collect();
        assert_eq!(
            states,
            [
                ("build", CiState::Passed, Some(72_000)),
                ("unit", CiState::Failed, Some(160_400)),
                ("integration", CiState::Running, None),
                ("deploy:staging", CiState::Skipped, None),
            ]
        );
    }

    #[test]
    fn finds_the_failure_in_the_log() {
        assert_eq!(
            failure_line(include_str!("fixtures/gitlab_trace.txt")).as_deref(),
            Some("--- FAIL: TestRoundBulk (0.00s)")
        );
        assert_eq!(
            failure_line("step 1\nstep 2\nERROR: Job failed: exit code 2").as_deref(),
            Some("step 2")
        );
    }

    fn target(api: &str) -> CiTarget {
        CiTarget {
            host: CiHost {
                provider: CiProvider::GitLabCi,
                host: "gitlab.example.com".into(),
                api: api.into(),
                web: "https://gitlab.example.com".into(),
            },
            repo: "pricing/price-admin".into(),
            branch: "feat/PRC-412-bulk-discounts".into(),
        }
    }

    #[test]
    fn reads_the_pipeline_its_failure_and_retries_it() {
        let server = TestServer::start(|r| match (r.method.as_str(), r.path.as_str()) {
            (
                "GET",
                "/projects/pricing%2Fprice-admin/pipelines?ref=feat%2FPRC-412-bulk-discounts&per_page=1",
            ) => (
                200,
                include_str!("fixtures/gitlab_pipelines.json").to_owned(),
            ),
            ("GET", "/projects/pricing%2Fprice-admin/pipelines/991204417/jobs?per_page=100") => {
                (200, include_str!("fixtures/gitlab_jobs.json").to_owned())
            }
            ("GET", "/projects/pricing%2Fprice-admin/jobs/7710021/trace") => {
                (200, include_str!("fixtures/gitlab_trace.txt").to_owned())
            }
            ("POST", "/projects/pricing%2Fprice-admin/pipelines/991204417/retry") => {
                (201, r#"{"id":991204417,"status":"pending"}"#.to_owned())
            }
            _ => (404, r#"{"message":"404 Not Found"}"#.to_owned()),
        });
        let client = GitLabCi::default();
        let run = client
            .latest_run(&target(&server.url), "glpat-secret")
            .unwrap()
            .unwrap();
        assert_eq!(
            run.jobs[1].failure.as_deref(),
            Some("--- FAIL: TestRoundBulk (0.00s)")
        );
        client
            .rerun_failed(&target(&server.url), "glpat-secret", &run)
            .unwrap();
        assert!(
            !run.pull_request,
            "no merge request: the branch's pipeline alone"
        );
        let requests = server.requests();
        assert_eq!(requests[0].header("private-token"), Some("glpat-secret"));
        assert_eq!(requests.last().unwrap().method, "POST");
    }

    #[test]
    fn the_merge_requests_pipeline_comes_first_then_the_branchs() {
        let p = "/projects/pricing%2Fprice-admin";
        let jobs = |name: &str| format!(r#"[{{"id":1,"name":"{name}","status":"success"}}]"#);
        let route = move |branch_sha: &'static str| {
            move |r: &crate::test_server::Request| {
                match r.path.as_str() {
                x if x.starts_with(&format!("{p}/pipelines?ref=")) => (
                    200,
                    format!(r#"[{{"id":70,"iid":7,"sha":"{branch_sha}","ref":"feat/PRC-412-bulk-discounts","status":"success"}}]"#),
                ),
                x if x.starts_with(&format!("{p}/merge_requests?source_branch=feat%2FPRC-412-bulk-discounts&state=opened")) => {
                    (200, r#"[{"iid":231,"sha":"bbb"}]"#.to_owned())
                }
                x if x == format!("{p}/merge_requests/231/pipelines?per_page=20") => (
                    200,
                    // A merged-results pipeline runs on its own commit.
                    r#"[{"id":70,"sha":"bbb","ref":"feat/PRC-412-bulk-discounts","status":"success"},
                        {"id":81,"iid":8,"sha":"merged","ref":"refs/merge-requests/231/head","status":"running"},
                        {"id":60,"sha":"aaa","ref":"refs/merge-requests/231/head","status":"failed"}]"#
                        .to_owned(),
                ),
                x if x == format!("{p}/pipelines/81/jobs?per_page=100") => (200, jobs("test")),
                x if x == format!("{p}/pipelines/70/jobs?per_page=100") => (200, jobs("deploy")),
                _ => (404, r#"{"message":"404 Not Found"}"#.to_owned()),
            }
            }
        };
        let server = TestServer::start(route("bbb"));
        let runs = GitLabCi::default()
            .runs(&target(&server.url), "glpat-secret")
            .unwrap();
        let seen: Vec<_> = runs
            .iter()
            .map(|r| (r.id.as_str(), r.pull_request, r.jobs[0].name.as_str()))
            .collect();
        assert_eq!(seen, [("81", true, "test"), ("70", false, "deploy")]);
        assert_eq!(runs[0].state, CiState::Running);

        let server = TestServer::start(route("aaa"));
        let runs = GitLabCi::default()
            .runs(&target(&server.url), "glpat-secret")
            .unwrap();
        assert_eq!(runs.len(), 1, "the branch's pipeline is of an older commit");
        assert_eq!(runs[0].id, "81");
    }

    #[test]
    fn a_token_without_read_api_is_forbidden_with_the_scope() {
        let server = TestServer::start(|_| {
            (
                403,
                r#"{"error":"insufficient_scope","error_description":"The request requires higher privileges than provided by the access token.","scope":"read_api"}"#.to_owned(),
            )
        });
        let problem = GitLabCi::default()
            .latest_run(&target(&server.url), "glpat-secret")
            .unwrap_err();
        assert_eq!(
            (problem.kind, problem.missing_scope.as_str()),
            (CiProblemKind::Forbidden, "read_api")
        );
    }
}
