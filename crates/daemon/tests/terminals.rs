//! `Terminals` service end to end, over real gRPC and real PTYs.
#![cfg(unix)]

mod common;

use common::{Attached, TestDaemon, open, wait_exited};
use kumo_proto::v1 as pb;

#[tokio::test(flavor = "multi_thread")]
async fn streams_output_and_exit_code() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let id = open(&mut client, "sh", &["-c", "printf hello; exit 3"]).await;

    let mut attached = Attached::new(&mut client, &id, true).await;
    assert_eq!(attached.read_to_exit().await, 3);
    assert!(attached.received.text().contains("hello"));
}

#[tokio::test(flavor = "multi_thread")]
async fn echoes_input() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let id = open(
        &mut client,
        "sh",
        &["-c", "stty -echo; printf READY; read line; echo got:$line"],
    )
    .await;

    let mut attached = Attached::new(&mut client, &id, true).await;
    attached.read_until("READY").await;
    attached.send(b"ping\n").await;
    attached.read_until("got:ping").await;
    assert_eq!(attached.read_to_exit().await, 0);
}

#[tokio::test(flavor = "multi_thread")]
async fn resize_reaches_the_process() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let id = open(
        &mut client,
        "sh",
        &["-c", "stty -echo; printf READY; read _; stty size"],
    )
    .await;

    let mut attached = Attached::new(&mut client, &id, true).await;
    attached.read_until("READY").await;
    attached.resize(100, 30).await;
    attached.send(b"\n").await;
    attached.read_until("30 100").await;
}

#[tokio::test(flavor = "multi_thread")]
async fn detach_and_reattach_replays_without_gaps_or_duplicates() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let script = "for i in 1 2 3 4 5 6; do echo n$i; sleep 0.05; done";
    let id = open(&mut client, "sh", &["-c", script]).await;

    // First client sees the beginning and goes away mid-run.
    let mut first = Attached::new(&mut client, &id, true).await;
    first.read_until("n2").await;
    let seen = first.received.batches.clone();
    drop(first);

    // The session keeps running without anyone attached.
    wait_exited(&mut client, &id).await;

    // A new client gets everything, in order, exactly once.
    let mut second = Attached::new(&mut client, &id, true).await;
    assert_eq!(second.read_to_exit().await, 0);
    let seqs = second.received.seqs();
    let expected: Vec<u64> = (1..=seqs.len() as u64).collect();
    assert_eq!(seqs, expected, "replay must be contiguous from 1");
    for n in 1..=6 {
        assert!(
            second.received.text().contains(&format!("n{n}")),
            "missing n{n}"
        );
    }
    // What the first client saw is a prefix of the replay.
    assert_eq!(&second.received.batches[..seen.len()], &seen[..]);
}

#[tokio::test(flavor = "multi_thread")]
async fn reattach_without_replay_only_gets_new_output() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let id = open(
        &mut client,
        "sh",
        &["-c", "stty -echo; printf READY; read l; echo after:$l"],
    )
    .await;

    let mut first = Attached::new(&mut client, &id, true).await;
    first.read_until("READY").await;
    let last_seen = *first.received.seqs().last().unwrap();
    drop(first);

    let mut second = Attached::new(&mut client, &id, false).await;
    second.send(b"x\n").await;
    second.read_until("after:x").await;
    assert!(!second.received.text().contains("READY"));
    assert!(second.received.seqs().iter().all(|seq| *seq > last_seen));
}

#[tokio::test(flavor = "multi_thread")]
async fn close_kills_and_forgets_the_terminal() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let id = open(&mut client, "sleep", &["30"]).await;

    let mut attached = Attached::new(&mut client, &id, true).await;
    client
        .terminals
        .close(pb::CloseRequest {
            terminal_id: id.clone(),
        })
        .await
        .unwrap();
    attached.read_to_exit().await;

    let list = client
        .terminals
        .list(pb::ListRequest {})
        .await
        .unwrap()
        .into_inner();
    assert!(list.terminals.iter().all(|t| t.terminal_id != id));

    let missing = client
        .terminals
        .close(pb::CloseRequest { terminal_id: id })
        .await
        .unwrap_err();
    assert_eq!(missing.code(), tonic::Code::NotFound);
}

#[tokio::test(flavor = "multi_thread")]
async fn unknown_program_fails_to_open() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let request = pb::OpenRequest {
        program: "kumo-definitely-not-a-program".into(),
        ..Default::default()
    };
    let error = client.terminals.open(request).await.unwrap_err();
    assert_eq!(error.code(), tonic::Code::FailedPrecondition);
}

#[tokio::test(flavor = "multi_thread")]
async fn list_reports_where_each_terminal_started() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let dir = tempfile::tempdir().unwrap();
    let cwd = dir.path().display().to_string();
    let response = client
        .terminals
        .open(pb::OpenRequest {
            program: "sleep".into(),
            args: vec!["30".into()],
            cwd: cwd.clone(),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner();
    let elsewhere = open(&mut client, "sleep", &["30"]).await;

    let list = client
        .terminals
        .list(pb::ListRequest {})
        .await
        .unwrap()
        .into_inner();
    let cwd_of = |id: &str| {
        list.terminals
            .iter()
            .find(|t| t.terminal_id == id)
            .map(|t| t.cwd.clone())
    };
    assert_eq!(cwd_of(&response.terminal_id), Some(cwd));
    assert_eq!(cwd_of(&elsewhere), Some(String::new()));
}
