//! `PullRequests` end to end, over real gRPC and a real repository. Never
//! reaches a host: there's no token, or the branch isn't pushed.
#![cfg(unix)]

mod common;

use common::{TestDaemon, git_repo, save_namespace};
use kumo_proto::v1 as pb;

#[tokio::test(flavor = "multi_thread")]
async fn says_what_is_missing_before_asking_the_host() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let repo = git_repo(
        &daemon.home().join("dev/app"),
        Some("git@github.com:pricing/app.git"),
    );
    save_namespace(&mut client, "app", &[&repo]).await;
    let path = repo.display().to_string();

    let list = client
        .pulls
        .list(pb::ListPullRequestsRequest {
            repo_path: path.clone(),
            refresh: false,
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(list.provider(), pb::CiProvider::GithubActions);
    assert!(list.pull_requests.is_empty());
    assert_eq!(
        list.problem.unwrap().kind(),
        pb::CiProblemKind::NotConnected
    );

    let branch = client
        .pulls
        .for_branch(pb::BranchPullRequestRequest {
            worktree_path: path.clone(),
            refresh: false,
        })
        .await
        .unwrap()
        .into_inner();
    let problem = branch.problem.unwrap();
    assert_eq!(
        (problem.kind(), problem.commits_waiting),
        (pb::CiProblemKind::NotPushed, 1)
    );

    let untitled = client
        .pulls
        .create(pb::CreatePullRequestRequest {
            worktree_path: path.clone(),
            title: " ".into(),
            ..Default::default()
        })
        .await
        .unwrap_err();
    assert_eq!(untitled.code(), tonic::Code::InvalidArgument);
    let unpushed = client
        .pulls
        .create(pb::CreatePullRequestRequest {
            worktree_path: path,
            title: "feat: x".into(),
            ..Default::default()
        })
        .await
        .unwrap_err();
    assert_eq!(unpushed.code(), tonic::Code::FailedPrecondition);
    let unknown = client
        .pulls
        .list(pb::ListPullRequestsRequest {
            repo_path: "/nowhere".into(),
            refresh: false,
        })
        .await
        .unwrap_err();
    assert_eq!(unknown.code(), tonic::Code::NotFound);
}
