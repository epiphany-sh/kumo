//! `Workspace` service end to end: real git repositories, SQLite, gRPC.

mod common;

use std::path::Path;
use std::process::Command;
use std::time::Duration;

use common::{TIMEOUT, TestDaemon, git_repo, save_namespace, test_config};
use kumo_grpc::client::KumoClient;
use kumo_proto::v1 as pb;

/// Waits for a snapshot that satisfies `ready`.
async fn snapshot_where(
    client: &mut KumoClient,
    ready: impl Fn(&pb::WorkspaceSnapshot) -> bool,
) -> pb::WorkspaceSnapshot {
    let mut stream = client
        .workspace
        .watch(pb::WatchWorkspaceRequest {})
        .await
        .unwrap()
        .into_inner();
    tokio::time::timeout(TIMEOUT, async {
        loop {
            let snapshot = stream.message().await.unwrap().expect("watch ended");
            if ready(&snapshot) {
                return snapshot;
            }
        }
    })
    .await
    .expect("no matching snapshot")
}

fn repo<'a>(snapshot: &'a pb::WorkspaceSnapshot, path: &Path) -> &'a pb::Repository {
    let path = path.display().to_string();
    snapshot
        .repositories
        .iter()
        .find(|r| r.path == path)
        .expect("repo in snapshot")
}

#[tokio::test(flavor = "multi_thread")]
async fn namespace_registers_repositories_and_streams_them() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let root = git_repo(
        &daemon.home().join("dev/price-admin"),
        Some("git@github.com:pricing/price-admin.git"),
    );
    std::fs::create_dir_all(root.join("src")).unwrap();

    // Any folder inside the repository identifies it.
    let id = save_namespace(&mut client, " pricing ", &[&root.join("src")]).await;

    let snapshot = snapshot_where(&mut client, |s| {
        s.repositories.iter().any(|r| !r.worktrees.is_empty())
    })
    .await;
    assert_eq!(snapshot.namespaces.len(), 1);
    assert_eq!(
        (
            snapshot.namespaces[0].id.as_str(),
            snapshot.namespaces[0].name.as_str()
        ),
        (id.as_str(), "pricing")
    );
    assert_eq!(
        snapshot.namespaces[0].repo_paths,
        vec![root.display().to_string()]
    );
    let repo = repo(&snapshot, &root);
    assert_eq!(
        (repo.name.as_str(), repo.host()),
        ("price-admin", pb::GitHost::Github)
    );
    assert_eq!(repo.full_name, "pricing/price-admin");
    assert_eq!(repo.worktrees.len(), 1);
    assert!(repo.worktrees[0].is_main);
    assert_eq!(repo.worktrees[0].branch, "main");
}

#[tokio::test(flavor = "multi_thread")]
async fn worktrees_are_created_tracked_and_removed() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let root = git_repo(&daemon.home().join("dev/kumo"), None);
    save_namespace(&mut client, "local", &[&root]).await;

    let created = client
        .workspace
        .create_worktree(pb::CreateWorktreeRequest {
            repo_path: root.display().to_string(),
            branch: "feat/PRC-1".into(),
            create_branch: true,
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner()
        .worktree
        .unwrap();
    let expected = std::fs::canonicalize(daemon.home().join("wt/kumo/feat-PRC-1")).unwrap();
    assert_eq!(
        created.path,
        expected.display().to_string(),
        "default location is ~/wt/<repo>/<branch>"
    );
    assert_eq!(created.branch, "feat/PRC-1");
    assert_eq!(
        created.status.as_ref().unwrap().upstream,
        "",
        "never pushed"
    );

    // Changes show up after a refresh.
    std::fs::write(expected.join("new.txt"), "x").unwrap();
    client
        .workspace
        .refresh(pb::RefreshWorkspaceRequest {})
        .await
        .unwrap();
    let snapshot = snapshot_where(&mut client, |s| {
        s.repositories.iter().any(|r| r.worktrees.len() == 2)
    })
    .await;
    let worktree = repo(&snapshot, &root)
        .worktrees
        .iter()
        .find(|w| w.path == created.path)
        .unwrap();
    assert_eq!(worktree.status.as_ref().unwrap().changed_files, 1);

    let remove = |force| pb::RemoveWorktreeRequest {
        repo_path: root.display().to_string(),
        worktree_path: created.path.clone(),
        force,
    };
    let dirty = client
        .workspace
        .remove_worktree(remove(false))
        .await
        .unwrap_err();
    assert_eq!(
        dirty.code(),
        tonic::Code::FailedPrecondition,
        "git refuses to drop changes: {}",
        dirty.message()
    );
    client
        .workspace
        .remove_worktree(remove(true))
        .await
        .unwrap();
    assert!(!expected.exists());

    let main = client
        .workspace
        .remove_worktree(pb::RemoveWorktreeRequest {
            repo_path: root.display().to_string(),
            worktree_path: root.display().to_string(),
            force: true,
        })
        .await
        .unwrap_err();
    assert_eq!(main.code(), tonic::Code::FailedPrecondition);
    let snapshot = snapshot_where(&mut client, |_| true).await;
    assert_eq!(repo(&snapshot, &root).worktrees.len(), 1);
}

#[tokio::test(flavor = "multi_thread")]
async fn existing_branch_and_explicit_path() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let root = git_repo(&daemon.home().join("dev/api"), None);
    Command::new("git")
        .arg("-C")
        .arg(&root)
        .args(["branch", "fix/old"])
        .output()
        .unwrap();
    save_namespace(&mut client, "api", &[&root]).await;

    let branches = client
        .workspace
        .list_branches(pb::ListBranchesRequest {
            repo_path: root.display().to_string(),
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(branches.current, "main");
    assert_eq!(branches.local, vec!["fix/old", "main"]);

    let created = client
        .workspace
        .create_worktree(pb::CreateWorktreeRequest {
            repo_path: root.display().to_string(),
            branch: "fix/old".into(),
            create_branch: false,
            path: "~/elsewhere/old".into(),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner()
        .worktree
        .unwrap();
    assert_eq!(
        created.path,
        std::fs::canonicalize(daemon.home().join("elsewhere/old"))
            .unwrap()
            .display()
            .to_string()
    );
    assert_eq!(created.branch, "fix/old");
}

#[tokio::test(flavor = "multi_thread")]
async fn rejects_invalid_input() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let not_repo = daemon.home().join("plain");
    std::fs::create_dir_all(&not_repo).unwrap();

    let error = client
        .workspace
        .save_namespace(pb::SaveNamespaceRequest {
            name: "x".into(),
            repo_paths: vec![not_repo.display().to_string()],
            ..Default::default()
        })
        .await
        .unwrap_err();
    assert_eq!(error.code(), tonic::Code::InvalidArgument);

    let root = git_repo(&daemon.home().join("dev/r"), None);
    save_namespace(&mut client, "r", &[&root]).await;
    let error = client
        .workspace
        .create_worktree(pb::CreateWorktreeRequest {
            repo_path: root.display().to_string(),
            branch: "bad name".into(),
            create_branch: true,
            ..Default::default()
        })
        .await
        .unwrap_err();
    assert_eq!(error.code(), tonic::Code::InvalidArgument);

    let error = client
        .workspace
        .create_worktree(pb::CreateWorktreeRequest {
            repo_path: "/nowhere".into(),
            branch: "x".into(),
            ..Default::default()
        })
        .await
        .unwrap_err();
    assert_eq!(error.code(), tonic::Code::NotFound);
}

#[tokio::test(flavor = "multi_thread")]
async fn discovers_repositories_on_disk() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let a = git_repo(
        &daemon.home().join("workspace/a"),
        Some("https://gitlab.com/team/a.git"),
    );
    let b = git_repo(&daemon.home().join("workspace/group/b"), None);
    std::fs::create_dir_all(daemon.home().join("workspace/not-a-repo")).unwrap();

    // No roots: the usual folders under home (~/workspace is one).
    let found = client
        .workspace
        .discover_repos(pb::DiscoverReposRequest::default())
        .await
        .unwrap()
        .into_inner()
        .candidates;
    let paths: Vec<_> = found.iter().map(|c| c.path.clone()).collect();
    assert_eq!(
        paths,
        vec![a.display().to_string(), b.display().to_string()]
    );
    assert_eq!(
        (found[0].host(), found[0].full_name.as_str()),
        (pb::GitHost::Gitlab, "team/a")
    );
    assert_eq!(
        (found[1].host(), found[1].worktree_count),
        (pb::GitHost::Local, 1)
    );
}

#[tokio::test(flavor = "multi_thread")]
async fn namespaces_survive_a_daemon_restart_and_delete_keeps_repos() {
    let dir = tempfile::tempdir().unwrap();
    let root = git_repo(&dir.path().join("home/dev/svc"), None);

    let base = dir.path().to_path_buf();
    let run = |stop: tokio::sync::oneshot::Receiver<()>| {
        let base = base.clone();
        async move {
            let daemon = kumod::Daemon::start(test_config(&base)).await.unwrap();
            let endpoint = daemon.endpoint().clone();
            let running = tokio::spawn(daemon.run(async {
                let _ = stop.await;
            }));
            (
                KumoClient::connect(endpoint.addr, &endpoint.token)
                    .await
                    .unwrap(),
                running,
            )
        }
    };

    let (stop, stopped) = tokio::sync::oneshot::channel();
    let (mut client, running) = run(stopped).await;
    let first = save_namespace(&mut client, "first", &[&root]).await;
    let second = save_namespace(&mut client, "second", &[&root]).await;
    stop.send(()).unwrap();
    running.await.unwrap().unwrap();

    let (stop, stopped) = tokio::sync::oneshot::channel();
    let (mut client, running) = run(stopped).await;
    let snapshot = snapshot_where(&mut client, |s| {
        s.repositories
            .first()
            .is_some_and(|r| !r.worktrees.is_empty())
    })
    .await;
    let ids: Vec<_> = snapshot.namespaces.iter().map(|n| n.id.clone()).collect();
    assert_eq!(ids, vec![first.clone(), second]);

    client
        .workspace
        .delete_namespace(pb::DeleteNamespaceRequest { id: first })
        .await
        .unwrap();
    let snapshot = snapshot_where(&mut client, |s| s.namespaces.len() == 1).await;
    assert_eq!(
        snapshot.repositories.len(),
        1,
        "still referenced by the other namespace"
    );
    assert!(
        root.join(".git").exists(),
        "deleting a namespace never touches the repository"
    );
    stop.send(()).unwrap();
    running.await.unwrap().unwrap();
    tokio::time::sleep(Duration::from_millis(10)).await;
}

#[tokio::test(flavor = "multi_thread")]
async fn a_failed_worktree_leaves_no_folders_behind() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let root = git_repo(&daemon.home().join("dev/svc"), None);
    Command::new("git")
        .arg("-C")
        .arg(&root)
        .args(["branch", "taken"])
        .output()
        .unwrap();
    save_namespace(&mut client, "svc", &[&root]).await;

    let error = client
        .workspace
        .create_worktree(pb::CreateWorktreeRequest {
            repo_path: root.display().to_string(),
            branch: "taken".into(),
            create_branch: true,
            ..Default::default()
        })
        .await
        .unwrap_err();
    assert_eq!(
        error.code(),
        tonic::Code::FailedPrecondition,
        "{}",
        error.message()
    );
    assert!(!daemon.home().join("wt").exists(), "nothing left in ~/wt");
}

#[tokio::test(flavor = "multi_thread")]
async fn worktrees_and_changes_made_outside_show_without_a_refresh() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let root = git_repo(&daemon.home().join("dev/engine"), None);
    save_namespace(&mut client, "engine", &[&root]).await;
    snapshot_where(&mut client, |s| {
        s.repositories.iter().any(|r| r.worktrees.len() == 1)
    })
    .await;

    // An agent in a terminal, next to the repository. Git gets plain paths:
    // it can't create Windows' canonical `\\?\C:\…` ones.
    let sibling = daemon.home().join("dev/engine-delete");
    let added = Command::new("git")
        .arg("-C")
        .arg(daemon.home().join("dev/engine"))
        .args(["worktree", "add", "-b", "feat/delete"])
        .arg(&sibling)
        .output()
        .unwrap();
    assert!(added.status.success(), "{added:?}");
    let sibling = std::fs::canonicalize(sibling)
        .unwrap()
        .display()
        .to_string();
    snapshot_where(&mut client, |s| {
        repo(s, &root).worktrees.iter().any(|w| w.path == sibling)
    })
    .await;

    std::fs::write(Path::new(&sibling).join("handler.go"), "package x").unwrap();
    let snapshot = snapshot_where(&mut client, |s| {
        repo(s, &root)
            .worktrees
            .iter()
            .any(|w| w.path == sibling && w.status.as_ref().unwrap().changed_files == 1)
    })
    .await;
    assert_eq!(repo(&snapshot, &root).worktrees.len(), 2);
}
