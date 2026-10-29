//! `Tests` service end to end: the command found from the worktree's
//! files, run on a real PTY with fake tools on a PATH of their own.
#![cfg(unix)]

mod common;

use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

use common::{Attached, TIMEOUT, TestDaemon, git_repo, save_namespace};
use kumo_grpc::client::KumoClient;
use kumo_proto::v1 as pb;

fn tool(bin: &Path, name: &str, body: &str) {
    let path = bin.join(name);
    std::fs::write(&path, format!("#!/bin/sh\n{body}\n")).unwrap();
    std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
}

async fn worktree(daemon: &TestDaemon, client: &mut KumoClient) -> PathBuf {
    let repo = git_repo(&daemon.home().join("dev/app"), None);
    save_namespace(client, "app", &[&repo]).await;
    repo
}

async fn watch(client: &mut KumoClient, wt: &Path) -> tonic::Streaming<pb::TestsSnapshot> {
    client
        .tests
        .watch(pb::WatchTestsRequest {
            worktree_path: wt.display().to_string(),
        })
        .await
        .unwrap()
        .into_inner()
}

async fn snapshot_where(
    stream: &mut tonic::Streaming<pb::TestsSnapshot>,
    ready: impl Fn(&pb::TestsSnapshot) -> bool,
) -> pb::TestsSnapshot {
    tokio::time::timeout(TIMEOUT, async {
        loop {
            let snapshot = stream.message().await.unwrap().expect("watch ended");
            if ready(&snapshot) {
                return snapshot;
            }
        }
    })
    .await
    .expect("timed out waiting for the tests")
}

fn run(wt: &Path, command: &str) -> pb::RunTestsRequest {
    pb::RunTestsRequest {
        worktree_path: wt.display().to_string(),
        command: command.into(),
        ..Default::default()
    }
}

fn state_is(state: pb::TestRunState) -> impl Fn(&pb::TestsSnapshot) -> bool {
    move |s| s.run.as_ref().is_some_and(|r| r.state() == state)
}

#[tokio::test(flavor = "multi_thread")]
async fn runs_the_makefile_target_and_reads_its_results() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = worktree(&daemon, &mut client).await;
    std::fs::write(
        wt.join("Makefile"),
        "build:\n\ttrue\ntest: build\n\tcargo test\n",
    )
    .unwrap();
    std::fs::write(wt.join("Cargo.toml"), "[workspace]\n").unwrap();
    tool(
        &daemon.bin(),
        "make",
        "echo \"make $* in $(pwd)\"\n\
         echo '     Running unittests src/lib.rs (target/debug/deps/app-1a2b)'\n\
         echo 'test result: ok. 41 passed; 0 failed; 2 ignored; 0 measured; 0 filtered out; finished in 0.20s'",
    );

    let mut stream = watch(&mut client, &wt).await;
    let first = stream.message().await.unwrap().unwrap();
    assert_eq!(
        (first.command.as_str(), first.command_origin.as_str()),
        ("make test", "Makefile")
    );
    assert!(first.run.is_none());

    let started = client.tests.run(run(&wt, "")).await.unwrap().into_inner();
    assert_eq!(started.command, "make test");
    let passed = snapshot_where(&mut stream, state_is(pb::TestRunState::Passed))
        .await
        .run
        .unwrap();
    assert_eq!(
        (
            passed.passed,
            passed.failed,
            passed.skipped,
            passed.exit_code
        ),
        (41, 0, 2, 0)
    );
    assert_eq!(passed.suites[0].name, "app");
    assert!(passed.finished_unix_ms >= passed.started_unix_ms);

    let mut terminal = Attached::new(&mut client, &started.terminal_id, true).await;
    terminal
        .read_until(&format!("make test in {}", wt.display()))
        .await;
}

#[tokio::test(flavor = "multi_thread")]
async fn a_typed_command_fails_and_a_long_one_stops() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = worktree(&daemon, &mut client).await;
    let mut stream = watch(&mut client, &wt).await;
    assert_eq!(
        stream.message().await.unwrap().unwrap().command,
        "",
        "nothing to go by"
    );
    let refused = client.tests.run(run(&wt, "")).await.unwrap_err();
    assert_eq!(refused.code(), tonic::Code::InvalidArgument);

    client
        .tests
        .run(run(
            &wt,
            "echo '--- FAIL: TestBulk (0.00s)'; echo 'FAIL\tacme/discount\t0.4s'; exit 1",
        ))
        .await
        .unwrap();
    let failed = snapshot_where(&mut stream, state_is(pb::TestRunState::Failed))
        .await
        .run
        .unwrap();
    assert_eq!(failed.exit_code, 1);
    assert_eq!(failed.failures, ["TestBulk"]);
    assert_eq!(
        (failed.suites[0].name.as_str(), failed.suites[0].passed),
        ("acme/discount", false)
    );

    client
        .tests
        .run(run(&wt, "echo waiting; read line"))
        .await
        .unwrap();
    snapshot_where(&mut stream, |s| {
        s.run
            .as_ref()
            .is_some_and(|r| r.state() == pb::TestRunState::Running && r.last_line == "waiting")
    })
    .await;
    client
        .tests
        .stop(pb::StopTestsRequest {
            worktree_path: wt.display().to_string(),
        })
        .await
        .unwrap();
    snapshot_where(&mut stream, state_is(pb::TestRunState::Stopped)).await;

    let outside = client
        .tests
        .run(run(Path::new("/tmp"), "true"))
        .await
        .unwrap_err();
    assert_eq!(outside.code(), tonic::Code::NotFound);
}
