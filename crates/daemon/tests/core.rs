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
