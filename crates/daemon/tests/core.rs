//! `Core` service and authentication.

mod common;

use common::TestDaemon;
use kumo_domain::daemon::{ApiVersion, AuthToken};
use kumo_grpc::client::KumoClient;
use kumo_proto::v1 as pb;

#[tokio::test(flavor = "multi_thread")]
async fn hello_reports_api_version() {
    let daemon = TestDaemon::start().await;
    let reply = daemon.client().await.hello("test").await.unwrap();
    assert_eq!(reply.server_api_version, ApiVersion::CURRENT.get());
    assert!(reply.server_time_unix_nanos > 0);
    assert!(!reply.outdated, "nothing replaced the test binary");
}

#[tokio::test(flavor = "multi_thread")]
async fn invalid_token_is_rejected() {
    let daemon = TestDaemon::start().await;
    let wrong = AuthToken::from_bytes([0; AuthToken::BYTES]);
    let mut client = KumoClient::connect(daemon.endpoint.addr, &wrong)
        .await
        .unwrap();

    let hello = client.hello("intruder").await.unwrap_err();
    assert_eq!(hello.code(), tonic::Code::Unauthenticated);

    let list = client.terminals.list(pb::ListRequest {}).await.unwrap_err();
    assert_eq!(list.code(), tonic::Code::Unauthenticated);
}

#[tokio::test(flavor = "multi_thread")]
async fn second_instance_refuses_to_start() {
    let data_dir = tempfile::tempdir().unwrap();
    let config = common::test_config(data_dir.path());
    let first = kumod::Daemon::start(config.clone()).await.unwrap();
    let (stop, stopped) = tokio::sync::oneshot::channel::<()>();
    let running = tokio::spawn(first.run(async {
        let _ = stopped.await;
    }));

    let second = kumod::Daemon::start(config).await.unwrap_err();
    assert!(second.to_string().contains("already running"), "{second}");

    stop.send(()).unwrap();
    running.await.unwrap().unwrap();
    assert!(
        !data_dir.path().join("daemon.json").exists(),
        "discovery file not removed"
    );
}

// Needs a running terminal (`/bin/sh`), like the other terminal tests.
#[cfg(unix)]
#[tokio::test(flavor = "multi_thread")]
async fn shutdown_stops_an_idle_daemon_and_refuses_a_busy_one() {
    let data_dir = tempfile::tempdir().unwrap();
    let daemon = kumod::Daemon::start(common::test_config(data_dir.path()))
        .await
        .unwrap();
    let endpoint = daemon.endpoint().clone();
    let running = tokio::spawn(daemon.run(std::future::pending()));
    let mut client = KumoClient::connect(endpoint.addr, &endpoint.token)
        .await
        .unwrap();

    let discovery = data_dir.path().join("data/daemon.json");
    assert!(discovery.exists());

    let terminal = common::open(&mut client, "/bin/sh", &["-c", "sleep 30"]).await;
    let busy = client
        .core
        .shutdown(pb::ShutdownRequest { if_idle: true })
        .await
        .unwrap_err();
    assert_eq!(busy.code(), tonic::Code::FailedPrecondition, "{busy:?}");

    client
        .terminals
        .close(pb::CloseRequest {
            terminal_id: terminal,
        })
        .await
        .unwrap();
    client
        .core
        .shutdown(pb::ShutdownRequest { if_idle: true })
        .await
        .unwrap();
    tokio::time::timeout(common::TIMEOUT, running)
        .await
        .expect("stopped although a client is still connected")
        .unwrap()
        .unwrap();
    assert!(!discovery.exists(), "a stopped daemon is not advertised");
}
