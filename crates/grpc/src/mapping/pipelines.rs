use kumo_domain::pipelines::{
    CiJob, CiProblem, CiProblemKind, CiProvider, CiRun, CiState, HostInfo, PipelinesSnapshot,
};
use kumo_domain::time::Timestamp;
use kumo_proto::v1 as pb;

pub(crate) fn ms(at: Option<Timestamp>) -> i64 {
    at.map_or(0, |t| {
        i64::try_from(t.as_unix_nanos() / 1_000_000).unwrap_or(i64::MAX)
    })
}

pub fn ci_provider_to(provider: Option<CiProvider>) -> pb::CiProvider {
    match provider {
        None => pb::CiProvider::None,
        Some(CiProvider::GitHubActions) => pb::CiProvider::GithubActions,
        Some(CiProvider::GitLabCi) => pb::CiProvider::GitlabCi,
        Some(CiProvider::BitbucketPipelines) => pb::CiProvider::BitbucketPipelines,
    }
}

pub(crate) fn state_to(state: CiState) -> pb::CiState {
    match state {
        CiState::Queued => pb::CiState::Queued,
        CiState::Running => pb::CiState::Running,
        CiState::Passed => pb::CiState::Passed,
        CiState::Failed => pb::CiState::Failed,
        CiState::Canceled => pb::CiState::Canceled,
        CiState::Skipped => pb::CiState::Skipped,
    }
}

fn job_to(job: &CiJob) -> pb::CiJob {
    pb::CiJob {
        name: job.name.clone(),
        state: state_to(job.state).into(),
        duration_ms: job
            .duration_ms
            .map_or(0, |d| i64::try_from(d).unwrap_or(i64::MAX)),
        started_at: ms(job.started_at),
        failure: job.failure.clone().unwrap_or_default(),
        url: job.url.clone(),
    }
}

fn run_to(run: &CiRun) -> pb::CiRun {
    pb::CiRun {
        id: run.id.clone(),
        label: run.label.clone(),
        short_sha: run.short_sha().to_owned(),
        title: run.title.clone(),
        state: state_to(run.state).into(),
        created_at: ms(run.created_at),
        finished_at: ms(run.finished_at),
        url: run.url.clone(),
        jobs: run.jobs.iter().map(job_to).collect(),
    }
}

pub fn ci_problem_to(problem: &CiProblem) -> pb::CiProblem {
    pb::CiProblem {
        kind: match problem.kind {
            CiProblemKind::NotConnected => pb::CiProblemKind::NotConnected,
            CiProblemKind::Unauthorized => pb::CiProblemKind::Unauthorized,
            CiProblemKind::Forbidden => pb::CiProblemKind::Forbidden,
            CiProblemKind::NotFound => pb::CiProblemKind::NotFound,
            CiProblemKind::RateLimited => pb::CiProblemKind::RateLimited,
            CiProblemKind::Unreachable => pb::CiProblemKind::Unreachable,
            CiProblemKind::NotPushed => pb::CiProblemKind::NotPushed,
            CiProblemKind::Unsupported => pb::CiProblemKind::Unsupported,
        }
        .into(),
        detail: problem.detail.clone(),
        missing_scope: problem.missing_scope.clone(),
        retry_at: ms(problem.retry_at),
        commits_waiting: problem.commits_waiting,
    }
}

pub fn pipelines_snapshot_to(snapshot: &PipelinesSnapshot) -> pb::PipelinesSnapshot {
    pb::PipelinesSnapshot {
        provider: ci_provider_to(snapshot.provider).into(),
        repo: snapshot.repo.clone(),
        branch: snapshot.branch.clone(),
        latest: snapshot.latest.as_ref().map(run_to),
        problem: snapshot.problem.as_ref().map(ci_problem_to),
        checked_at: ms(snapshot.checked_at),
    }
}

pub fn host_info_to(info: HostInfo) -> pb::CiHostInfo {
    pb::CiHostInfo {
        host: info.host,
        provider: ci_provider_to(Some(info.provider)).into(),
        has_token: info.has_token,
        uses_gh: info.uses_fallback,
        repos: info.repos,
        gh_account: info.fallback_account.unwrap_or_default(),
        gh_available: info.fallback_available,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn snapshots_keep_times_in_milliseconds_and_unknowns_as_zero() {
        let run = CiRun {
            id: "11896352187".into(),
            label: "run #8812".into(),
            sha: "4e1b2c0d9a8f".into(),
            title: "feat: x".into(),
            state: CiState::Failed,
            created_at: Some(Timestamp::from_unix_nanos(1_761_660_191_000_000_000)),
            finished_at: None,
            url: "https://github.com/a/b/actions/runs/1".into(),
            jobs: vec![CiJob {
                id: "1".into(),
                name: "integration".into(),
                state: CiState::Failed,
                duration_ms: Some(82_000),
                started_at: None,
                failure: Some("bulk_test.go:88 · expected 3 rows, got 2".into()),
                url: String::new(),
            }],
        };
        let mut problem = CiProblem::new(
            CiProblemKind::Unreachable,
            "Timed out after 10 s · api.github.com",
        );
        problem.retry_at = Some(Timestamp::from_unix_nanos(1_761_660_221_000_000_000));
        let pb = pipelines_snapshot_to(&PipelinesSnapshot {
            provider: Some(CiProvider::GitHubActions),
            repo: "a/b".into(),
            branch: "feat/x".into(),
            latest: Some(run),
            problem: Some(problem),
            checked_at: None,
        });
        let (provider, checked_at) = (pb.provider(), pb.checked_at);
        let latest = pb.latest.unwrap();
        assert_eq!(
            (
                latest.short_sha.as_str(),
                latest.created_at,
                latest.finished_at
            ),
            ("4e1b2c0", 1_761_660_191_000, 0)
        );
        assert_eq!(latest.jobs[0].duration_ms, 82_000);
        assert_eq!(latest.jobs[0].state(), pb::CiState::Failed);
        let problem = pb.problem.unwrap();
        assert_eq!(
            (problem.kind(), problem.retry_at),
            (pb::CiProblemKind::Unreachable, 1_761_660_221_000)
        );
        assert_eq!((provider, checked_at), (pb::CiProvider::GithubActions, 0));
    }
}
