//! Profiles (the UI's workspaces) end to end: each one sees only its own
//! data, picked by the `kumo-profile` header.

mod common;

use std::collections::HashMap;
use std::path::Path;

use common::{TIMEOUT, TestDaemon, git_repo, save_namespace, test_config};
use kumo_grpc::client::KumoClient;
use kumo_proto::v1 as pb;
use tonic::Code;

async fn create(client: &mut KumoClient, name: &str) -> pb::Profile {
    client
        .profiles
        .create(pb::CreateProfileRequest {
            name: name.into(),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner()
}

async fn list(client: &mut KumoClient) -> Vec<pb::Profile> {
    client
        .profiles
        .list(pb::ListProfilesRequest {})
        .await
        .unwrap()
        .into_inner()
        .profiles
}

async fn namespaces(client: &mut KumoClient) -> Vec<String> {
    let mut stream = client
        .workspace
        .watch(pb::WatchWorkspaceRequest {})
        .await
        .unwrap()
        .into_inner();
    let snapshot = stream.message().await.unwrap().unwrap();
    snapshot.namespaces.into_iter().map(|n| n.name).collect()
}

async fn sources(client: &mut KumoClient) -> Vec<String> {
    let mut stream = client
        .tasks
        .watch(pb::WatchTasksRequest {})
        .await
        .unwrap()
        .into_inner();
    let update = stream.message().await.unwrap().unwrap();
    update.sources.into_iter().map(|s| s.name).collect()
}

async fn custom_agents(client: &mut KumoClient) -> Vec<String> {
    client
        .agents
        .list_providers(pb::ListProvidersRequest {})
        .await
        .unwrap()
        .into_inner()
        .providers
        .into_iter()
        .filter(|p| p.custom)
        .map(|p| p.name)
        .collect()
}

async fn hosts(client: &mut KumoClient) -> Vec<String> {
    client
        .pipelines
        .list_hosts(pb::ListHostsRequest {})
        .await
        .unwrap()
        .into_inner()
        .hosts
        .into_iter()
        .flat_map(|h| h.repos)
        .collect()
}

async fn save_vault(client: &mut KumoClient, name: &str, vault: &Path) {
    std::fs::create_dir_all(vault).unwrap();
    std::fs::write(vault.join("Inbox.md"), "- [ ] one\n").unwrap();
    client
        .tasks
        .save_source(pb::SaveSourceRequest {
            kind: pb::TaskSourceKind::Obsidian.into(),
            name: name.into(),
            options: HashMap::from([("vault".to_owned(), vault.display().to_string())]),
            enabled: true,
            ..Default::default()
        })
        .await
        .unwrap();
}

async fn save_custom_agent(client: &mut KumoClient, name: &str) {
    client
        .agents
        .save_provider(pb::SaveProviderRequest {
            name: name.into(),
            program: "true".into(),
            enabled: true,
            ..Default::default()
        })
        .await
        .unwrap();
}

#[tokio::test(flavor = "multi_thread")]
async fn a_new_data_folder_starts_with_the_default_profile() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let profiles = list(&mut client).await;
    assert_eq!(profiles.len(), 1);
    let first = &profiles[0];
    assert_eq!((first.id.as_str(), first.name.as_str()), ("default", ""));
    assert!(first.is_default);
    assert_eq!(first.worktrees_dir, "~/wt");
}

#[tokio::test(flavor = "multi_thread")]
async fn existing_data_shows_up_unchanged_as_the_default_profile() {
    let dir = tempfile::tempdir().unwrap();
    let repo = git_repo(&dir.path().join("home/dev/app"), None);
    let data = dir.path().join("data");

    // A daemon from before profiles: same folder, no registry.
    {
        let daemon = kumod::Daemon::start(test_config(dir.path())).await.unwrap();
        let endpoint = daemon.endpoint().clone();
        let (stop, stopped) = tokio::sync::oneshot::channel::<()>();
        let running = tokio::spawn(daemon.run(async {
            let _ = stopped.await;
        }));
        let mut client = KumoClient::connect(endpoint.addr, &endpoint.token)
            .await
            .unwrap();
        save_namespace(&mut client, "old", &[&repo]).await;
        stop.send(()).unwrap();
        running.await.unwrap().unwrap();
    }
    std::fs::remove_file(data.join("profiles.json")).unwrap();

    let daemon = kumod::Daemon::start(test_config(dir.path())).await.unwrap();
    let endpoint = daemon.endpoint().clone();
    let (_stop, stopped) = tokio::sync::oneshot::channel::<()>();
    tokio::spawn(daemon.run(async {
        let _ = stopped.await;
    }));
    let mut client = KumoClient::connect(endpoint.addr, &endpoint.token)
        .await
        .unwrap();

    assert_eq!(namespaces(&mut client).await, ["old"]);
    assert_eq!(
        namespaces(&mut client.with_profile(Some("default"))).await,
        ["old"]
    );
    let profiles = list(&mut client).await;
    assert_eq!(profiles.len(), 1);
    assert_eq!((profiles[0].namespaces, profiles[0].repos), (1, 1));
    assert!(data.join("kumo.db").exists(), "the data stays where it was");
    assert!(!data.join("profiles").exists());
}

#[tokio::test(flavor = "multi_thread")]
async fn each_profile_sees_only_its_own_data() {
    let daemon = TestDaemon::start().await;
    let mut first = daemon.client().await;
    let created = create(&mut first, "Workspace 1").await;
    assert_eq!(created.id, "workspace-1");
    assert_eq!(created.worktrees_dir, "~/wt/workspace-1");
    let mut second = first.with_profile(Some("workspace-1"));

    let repo_a = git_repo(
        &daemon.home().join("dev/a"),
        Some("git@github.com:team-a/a.git"),
    );
    let repo_b = git_repo(
        &daemon.home().join("dev/b"),
        Some("git@github.com:team-b/b.git"),
    );
    save_namespace(&mut first, "ns-a", &[&repo_a]).await;
    save_namespace(&mut second, "ns-b", &[&repo_b]).await;
    save_vault(&mut first, "Vault A", &daemon.home().join("vault-a")).await;
    save_vault(&mut second, "Vault B", &daemon.home().join("vault-b")).await;
    save_custom_agent(&mut first, "Agent A").await;
    save_custom_agent(&mut second, "Agent B").await;

    // Workspace: namespaces and repositories.
    assert_eq!(namespaces(&mut first).await, ["ns-a"]);
    assert_eq!(namespaces(&mut second).await, ["ns-b"]);
    // Tasks (and the docs they read through).
    assert_eq!(sources(&mut first).await, ["Vault A"]);
    assert_eq!(sources(&mut second).await, ["Vault B"]);
    // Agents.
    assert_eq!(custom_agents(&mut first).await, ["Agent A"]);
    assert_eq!(custom_agents(&mut second).await, ["Agent B"]);
    // Repository hosts (pipelines and pull requests follow the repos).
    assert_eq!(hosts(&mut first).await, ["team-a/a"]);
    assert_eq!(hosts(&mut second).await, ["team-b/b"]);

    // A profile's data lives in its own folder.
    let data = daemon.home().parent().unwrap().join("data");
    assert!(data.join("profiles/workspace-1/kumo.db").exists());
}

#[tokio::test(flavor = "multi_thread")]
async fn an_unknown_profile_is_not_found() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await.with_profile(Some("nope"));
    let error = client
        .workspace
        .watch(pb::WatchWorkspaceRequest {})
        .await
        .unwrap_err();
    assert_eq!(error.code(), Code::NotFound);
    assert!(error.message().contains("unknown workspace"), "{error:?}");
}

#[tokio::test(flavor = "multi_thread")]
async fn update_renames_reorders_and_moves_new_worktrees() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    create(&mut client, "Workspace 1").await;
    let updated = client
        .profiles
        .update(pb::UpdateProfileRequest {
            id: "workspace-1".into(),
            name: Some("Workspace One".into()),
            position: Some(0),
            worktrees_dir: Some("~/code/one".into()),
            git_email: Some("me@workspace-1.test".into()),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(
        (updated.id.as_str(), updated.name.as_str(), updated.position),
        ("workspace-1", "Workspace One", 0)
    );
    assert_eq!(updated.git_email, "me@workspace-1.test");
    let order: Vec<_> = list(&mut client).await.into_iter().map(|p| p.id).collect();
    assert_eq!(order, ["workspace-1", "default"]);

    // New worktrees of that profile go to its folder.
    let mut one = client.with_profile(Some("workspace-1"));
    let repo = git_repo(&daemon.home().join("dev/app"), None);
    save_namespace(&mut one, "app", &[&repo]).await;
    let worktree = one
        .workspace
        .create_worktree(pb::CreateWorktreeRequest {
            repo_path: repo.display().to_string(),
            branch: "feat/x".into(),
            create_branch: true,
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner()
        .worktree
        .unwrap();
    // (git reports the real path: /private/var on macOS.)
    assert!(
        Path::new(&worktree.path).ends_with("home/code/one/app/feat-x"),
        "{}",
        worktree.path
    );

    let bad = client
        .profiles
        .update(pb::UpdateProfileRequest {
            id: "workspace-1".into(),
            color: Some("red".into()),
            ..Default::default()
        })
        .await
        .unwrap_err();
    assert_eq!(bad.code(), Code::InvalidArgument);
}

#[tokio::test(flavor = "multi_thread")]
async fn create_can_copy_agent_commands() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    save_custom_agent(&mut client, "Agent A").await;
    client
        .profiles
        .create(pb::CreateProfileRequest {
            name: "Workspace 2".into(),
            copy_agents_from: "default".into(),
            ..Default::default()
        })
        .await
        .unwrap();
    let mut second = client.with_profile(Some("workspace-2"));
    assert_eq!(custom_agents(&mut second).await, ["Agent A"]);
}

#[tokio::test(flavor = "multi_thread")]
async fn delete_refuses_the_default_and_profiles_in_use_and_removes_data() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let delete = |id: &str| pb::DeleteProfileRequest { id: id.into() };

    let default = client.profiles.delete(delete("default")).await.unwrap_err();
    assert_eq!(default.code(), Code::FailedPrecondition);

    create(&mut client, "Workspace 1").await;
    let mut one = client.with_profile(Some("workspace-1"));
    let repo = git_repo(&daemon.home().join("dev/app"), None);
    save_namespace(&mut one, "app", &[&repo]).await;
    let data = daemon
        .home()
        .parent()
        .unwrap()
        .join("data/profiles/workspace-1");
    assert!(data.exists());

    // A window showing it keeps it.
    let window = one
        .profiles
        .watch(pb::WatchProfilesRequest {})
        .await
        .unwrap()
        .into_inner();
    let in_use = client
        .profiles
        .delete(delete("workspace-1"))
        .await
        .unwrap_err();
    assert_eq!(in_use.code(), Code::FailedPrecondition);
    assert!(in_use.message().contains("open in a window"), "{in_use:?}");
    drop(window);

    // The stream ends on the server a moment after the client drops it.
    tokio::time::timeout(TIMEOUT, async {
        while client.profiles.delete(delete("workspace-1")).await.is_err() {
            tokio::time::sleep(std::time::Duration::from_millis(20)).await;
        }
    })
    .await
    .expect("still in use after the window closed");

    assert!(!data.exists());
    assert!(repo.join(".git").exists(), "repositories stay on disk");
    assert_eq!(list(&mut client).await.len(), 1);
    let gone = one
        .workspace
        .watch(pb::WatchWorkspaceRequest {})
        .await
        .unwrap_err();
    assert_eq!(gone.code(), Code::NotFound);
}

#[tokio::test(flavor = "multi_thread")]
async fn watch_streams_profile_changes() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let mut stream = client
        .profiles
        .watch(pb::WatchProfilesRequest {})
        .await
        .unwrap()
        .into_inner();
    assert_eq!(stream.message().await.unwrap().unwrap().profiles.len(), 1);

    create(&mut client, "Workspace 1").await;
    let next = tokio::time::timeout(TIMEOUT, stream.message())
        .await
        .unwrap()
        .unwrap()
        .unwrap();
    let names: Vec<_> = next.profiles.iter().map(|p| p.name.as_str()).collect();
    assert_eq!(names, ["", "Workspace 1"]);
}

async fn host_token(client: &mut KumoClient, host: &str) -> bool {
    client
        .pipelines
        .list_hosts(pb::ListHostsRequest {})
        .await
        .unwrap()
        .into_inner()
        .hosts
        .into_iter()
        .any(|h| h.host == host && h.has_token)
}

async fn delete_when_closed(client: &mut KumoClient, id: &str) {
    tokio::time::timeout(TIMEOUT, async {
        while client
            .profiles
            .delete(pb::DeleteProfileRequest { id: id.into() })
            .await
            .is_err()
        {
            tokio::time::sleep(std::time::Duration::from_millis(20)).await;
        }
    })
    .await
    .expect("profile not deleted");
}

#[tokio::test(flavor = "multi_thread")]
async fn host_tokens_are_per_profile_and_go_with_it() {
    let daemon = TestDaemon::start().await;
    let mut first = daemon.client().await;
    create(&mut first, "Workspace 1").await;
    let mut second = first.with_profile(Some("workspace-1"));
    let remote = Some("git@github.com:team/app.git");
    let repo_a = git_repo(&daemon.home().join("dev/a"), remote);
    let repo_b = git_repo(&daemon.home().join("dev/b"), remote);
    save_namespace(&mut first, "a", &[&repo_a]).await;
    save_namespace(&mut second, "b", &[&repo_b]).await;

    second
        .pipelines
        .save_host_token(pb::SaveHostTokenRequest {
            host: "github.com".into(),
            token: "token-1".into(),
        })
        .await
        .unwrap();
    assert!(host_token(&mut second, "github.com").await);
    assert!(!host_token(&mut first, "github.com").await);

    // Deleting the profile deletes its tokens: one made again with the same
    // name (and id) starts without them.
    delete_when_closed(&mut first, "workspace-1").await;
    assert_eq!(create(&mut first, "Workspace 1").await.id, "workspace-1");
    save_namespace(&mut second, "b", &[&repo_b]).await;
    assert!(!host_token(&mut second, "github.com").await);
}

#[cfg(unix)]
#[tokio::test(flavor = "multi_thread")]
async fn terminals_belong_to_the_profile_that_opened_them() {
    let daemon = TestDaemon::start().await;
    let mut first = daemon.client().await;
    create(&mut first, "Workspace 1").await;
    let mut second = first.with_profile(Some("workspace-1"));
    let mine = common::open(&mut first, "sleep", &["30"]).await;
    let theirs = common::open(&mut second, "sleep", &["30"]).await;

    let ids = |list: pb::ListResponse| -> Vec<String> {
        list.terminals.into_iter().map(|t| t.terminal_id).collect()
    };
    let listed = first.terminals.list(pb::ListRequest {}).await.unwrap();
    assert_eq!(ids(listed.into_inner()), std::slice::from_ref(&mine));
    let listed = second.terminals.list(pb::ListRequest {}).await.unwrap();
    assert_eq!(ids(listed.into_inner()), std::slice::from_ref(&theirs));

    // Another profile's terminal can't be closed or attached to.
    let closed = first
        .terminals
        .close(pb::CloseRequest {
            terminal_id: theirs.clone(),
        })
        .await
        .unwrap_err();
    assert_eq!(closed.code(), Code::NotFound);
    let attach = pb::TerminalInput {
        kind: Some(pb::terminal_input::Kind::Attach(pb::AttachTo {
            terminal_id: theirs.clone(),
            replay_scrollback: true,
        })),
    };
    let attached = first
        .terminals
        .attach(tokio_stream::iter([attach]))
        .await
        .unwrap_err();
    assert_eq!(attached.code(), Code::NotFound);

    // Each profile counts its own.
    let open: HashMap<String, u32> = list(&mut first)
        .await
        .into_iter()
        .map(|p| (p.id, p.terminals_open))
        .collect();
    assert_eq!(open["default"], 1);
    assert_eq!(open["workspace-1"], 1);

    // Deleting a profile closes its terminals, and only those.
    delete_when_closed(&mut first, "workspace-1").await;
    let listed = first.terminals.list(pb::ListRequest {}).await.unwrap();
    assert_eq!(ids(listed.into_inner()), [mine]);
}
