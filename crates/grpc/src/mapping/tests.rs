use kumo_application::test_runs::TestsSnapshot;
use kumo_domain::test_runs::{TestCommand, TestError, TestRun, TestState};
use kumo_proto::v1 as pb;
use tonic::Status;

pub fn test_run_to(run: &TestRun) -> pb::TestRun {
    let state = match run.state {
        TestState::Running => pb::TestRunState::Running,
        TestState::Passed => pb::TestRunState::Passed,
        TestState::Failed => pb::TestRunState::Failed,
        TestState::Stopped => pb::TestRunState::Stopped,
    };
    let summary = &run.summary;
    pb::TestRun {
        worktree_path: run.worktree.display().to_string(),
        command: run.command.clone(),
        terminal_id: run.terminal.to_string(),
        state: state.into(),
        exit_code: run.exit_code.unwrap_or(0),
        started_unix_ms: run.started_at.as_unix_nanos() / 1_000_000,
        finished_unix_ms: run.finished_at.map_or(0, |t| t.as_unix_nanos() / 1_000_000),
        passed: summary.passed,
        failed: summary.failed,
        skipped: summary.skipped,
        suites: summary
            .suites
            .iter()
            .map(|s| pb::TestSuite {
                name: s.name.clone(),
                passed: s.passed,
                duration_ms: s.duration_ms.unwrap_or(0),
                tests: s.tests.unwrap_or(0),
            })
            .collect(),
        failures: summary.failures.clone(),
        last_line: summary.last_line.clone(),
    }
}

/// The worktree's part of the snapshot.
pub fn tests_snapshot_to(
    command: Option<&TestCommand>,
    snapshot: &TestsSnapshot,
    worktree: &std::path::Path,
) -> pb::TestsSnapshot {
    pb::TestsSnapshot {
        command: command.map(|c| c.command.clone()).unwrap_or_default(),
        command_origin: command.map(|c| c.origin.clone()).unwrap_or_default(),
        run: snapshot.run_of(worktree).map(test_run_to),
    }
}

pub fn tests_status_from(error: TestError) -> Status {
    let message = error.to_string();
    match error {
        TestError::UnknownWorktree(_) | TestError::NoRun(_) => Status::not_found(message),
        TestError::NoCommand => Status::invalid_argument(message),
        TestError::Launch(_) => Status::failed_precondition(message),
    }
}
