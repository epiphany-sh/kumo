//! `Pipelines` end to end, over real gRPC and a real repository. Never
//! reaches a CI provider: the branch is unpushed or there's no token.
#![cfg(unix)]

mod common;

use common::{TIMEOUT, TestDaemon, git, git_repo, save_namespace};
use kumo_proto::v1 as pb;

async fn next(stream: &mut tonic::Streaming<pb::PipelinesSnapshot>) -> pb::PipelinesSnapshot {
    tokio::time::timeout(TIMEOUT, stream.message())
        .await
        .expect("no snapshot")
        .unwrap()
        .expect("stream ended")
}

#[tokio::test(flavor = "multi_thread")]
async fn watches_the_branch_and_explains_what_is_missing() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let repo = git_repo(
        &daemon.home().join("dev/app"),
        Some("git@github.com:pricing/app.git"),
    );
    save_namespace(&mut client, "app", &[&repo]).await;
    let worktree = pb::WatchPipelinesRequest {
        worktree_path: repo.display().to_string(),
    };

    let mut stream = client
        .pipelines
        .watch(worktree.clone())
        .await
        .unwrap()
        .into_inner();
    let first = next(&mut stream).await;
    assert_eq!(first.provider(), pb::CiProvider::GithubActions);
    assert_eq!(
        (first.repo.as_str(), first.branch.as_str()),
        ("pricing/app", "main")
    );
    let problem = first.problem.unwrap();
    assert_eq!(
        (problem.kind(), problem.commits_waiting),
        (pb::CiProblemKind::NotPushed, 1)
    );

    // Pushed (as far as git knows), but no token for github.com.
    git(&repo, &["update-ref", "refs/remotes/origin/main", "HEAD"]);
    git(&repo, &["branch", "--set-upstream-to=origin/main"]);
    client
        .pipelines
        .refresh(pb::WorktreeRequest {
            worktree_path: repo.display().to_string(),
        })
        .await
        .unwrap();
    let after = next(&mut stream).await;
    assert_eq!(
        after.problem.unwrap().kind(),
        pb::CiProblemKind::NotConnected
    );
    assert!(after.latest.is_none());

    let hosts = client
        .pipelines
        .list_hosts(pb::ListHostsRequest {})
        .await
        .unwrap()
        .into_inner()
        .hosts;
    assert_eq!(hosts.len(), 1);
    assert_eq!(
        (hosts[0].host.as_str(), hosts[0].has_token, hosts[0].uses_gh),
        ("github.com", false, false)
    );
    assert_eq!(hosts[0].repos, ["pricing/app"]);
    // Tests never find the user's gh: nothing to sign in with.
    assert!(!hosts[0].gh_available);
    let no_gh = client
        .pipelines
        .sign_in_with_gh(pb::SignInWithGhRequest {
            host: "github.com".into(),
        })
        .await
        .unwrap_err();
    assert!(
        no_gh.message().contains("brew install gh"),
        "{}",
        no_gh.message()
    );
    let test = client
        .pipelines
        .test_host(pb::TestHostRequest {
            host: "github.com".into(),
            token: String::new(),
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(
        test.problem.unwrap().kind(),
        pb::CiProblemKind::NotConnected
    );
    // Removing a token that isn't there is fine.
    let info = client
        .pipelines
        .save_host_token(pb::SaveHostTokenRequest {
            host: "github.com".into(),
            token: String::new(),
        })
        .await
        .unwrap()
        .into_inner();
    assert!(!info.has_token);

    let unknown = client
        .pipelines
        .watch(pb::WatchPipelinesRequest {
            worktree_path: "/nowhere".into(),
        })
        .await
        .unwrap_err();
    assert_eq!(unknown.code(), tonic::Code::NotFound);
    let unknown_host = client
        .pipelines
        .save_host_token(pb::SaveHostTokenRequest {
            host: "gitlab.com".into(),
            token: "x".into(),
        })
        .await
        .unwrap_err();
    assert_eq!(unknown_host.code(), tonic::Code::NotFound);
}

#[tokio::test(flavor = "multi_thread")]
async fn a_repository_without_a_ci_host_is_unsupported() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let repo = git_repo(&daemon.home().join("dev/local"), None);
    save_namespace(&mut client, "local", &[&repo]).await;
    let mut stream = client
        .pipelines
        .watch(pb::WatchPipelinesRequest {
            worktree_path: repo.display().to_string(),
        })
        .await
        .unwrap()
        .into_inner();
    let first = next(&mut stream).await;
    assert_eq!(first.provider(), pb::CiProvider::None);
    assert_eq!(
        first.problem.unwrap().kind(),
        pb::CiProblemKind::Unsupported
    );
}
