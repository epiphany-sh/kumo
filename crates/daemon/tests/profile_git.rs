//! Git inside a profile end to end: identity, SSH key, signing, and the
//! HTTPS token through `kumod git-credential`.
#![cfg(unix)]

mod common;

use std::path::Path;
use std::time::Duration;

use common::{Attached, TIMEOUT, TestDaemon, git, git_repo, save_namespace};
use kumo_grpc::client::KumoClient;
use kumo_proto::v1 as pb;
use tonic::Code;

async fn create(client: &mut KumoClient, name: &str) -> KumoClient {
    let id = client
        .profiles
        .create(pb::CreateProfileRequest {
            name: name.into(),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner()
        .id;
    client.with_profile(Some(&id))
}

async fn update(client: &mut KumoClient, request: pb::UpdateProfileRequest) {
    client.profiles.update(request).await.unwrap();
}

/// What `script` prints in a terminal of the client's profile.
async fn run(client: &mut KumoClient, cwd: &Path, script: &str) -> String {
    let id = client
        .terminals
        .open(pb::OpenRequest {
            program: "sh".into(),
            args: vec!["-c".into(), script.into()],
            cwd: cwd.display().to_string(),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner()
        .terminal_id;
    let mut attached = Attached::new(client, &id, true).await;
    attached.read_to_exit().await;
    attached.received.text().replace('\r', "")
}

/// Runs `script` until its output contains `expected` (the profile's
/// environment follows a change a moment later).
async fn run_until(client: &mut KumoClient, cwd: &Path, script: &str, expected: &str) -> String {
    tokio::time::timeout(TIMEOUT, async {
        loop {
            let out = run(client, cwd, script).await;
            if out.contains(expected) {
                return out;
            }
            tokio::time::sleep(Duration::from_millis(50)).await;
        }
    })
    .await
    .unwrap_or_else(|_| panic!("{script:?} never printed {expected:?}"))
}

#[tokio::test(flavor = "multi_thread")]
async fn the_default_profile_with_nothing_set_changes_nothing() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let out = run(&mut client, &daemon.home(), "env").await;
    for var in [
        "GIT_CONFIG_COUNT",
        "GIT_SSH_COMMAND",
        "GH_TOKEN",
        "KUMO_PROFILE",
    ] {
        assert!(!out.contains(&format!("{var}=")), "{var} in {out}");
    }
}

#[tokio::test(flavor = "multi_thread")]
async fn commits_carry_the_profiles_identity_and_amend_keeps_the_author() {
    let daemon = TestDaemon::start().await;
    let mut first = daemon.client().await;
    let mut one = create(&mut first, "Workspace 1").await;
    let repo = git_repo(&daemon.home().join("dev/app"), None);
    save_namespace(&mut one, "app", &[&repo]).await;
    update(
        &mut one,
        pb::UpdateProfileRequest {
            id: "workspace-1".into(),
            git_name: Some("User One".into()),
            git_email: Some("one@workspace-1.test".into()),
            ..Default::default()
        },
    )
    .await;
    run_until(
        &mut one,
        &repo,
        "git config user.email",
        "one@workspace-1.test",
    )
    .await;

    // Kumo's own commit.
    std::fs::write(repo.join("a.txt"), "a\n").unwrap();
    one.git
        .commit(pb::CommitRequest {
            worktree_path: repo.display().to_string(),
            message: "one".into(),
            all: true,
            amend: false,
        })
        .await
        .unwrap();
    let author = git(&repo, &["log", "-1", "--format=%an <%ae>|%cn <%ce>"]);
    assert_eq!(
        author.trim(),
        "User One <one@workspace-1.test>|User One <one@workspace-1.test>"
    );

    // Amending someone else's commit keeps them as the author.
    std::fs::write(repo.join("b.txt"), "b\n").unwrap();
    git(&repo, &["add", "b.txt"]);
    git(&repo, &["commit", "-q", "-m", "theirs"]);
    one.git
        .commit(pb::CommitRequest {
            worktree_path: repo.display().to_string(),
            message: "theirs, amended".into(),
            all: false,
            amend: true,
        })
        .await
        .unwrap();
    let author = git(&repo, &["log", "-1", "--format=%an|%cn"]);
    assert_eq!(author.trim(), "Kumo Test|User One");

    // Git outside Kumo is untouched.
    let config = git(&repo, &["config", "user.email"]);
    assert_eq!(config.trim(), "test@kumo.dev");
}

#[tokio::test(flavor = "multi_thread")]
async fn ssh_remotes_go_over_https_with_the_profiles_token() {
    let daemon = TestDaemon::start().await;
    let mut first = daemon.client().await;
    let mut one = create(&mut first, "Workspace 1").await;
    let repo = git_repo(
        &daemon.home().join("dev/app"),
        Some("git@github.com:team/app.git"),
    );
    save_namespace(&mut one, "app", &[&repo]).await;
    one.pipelines
        .save_host_token(pb::SaveHostTokenRequest {
            host: "github.com".into(),
            token: "token-1".into(),
        })
        .await
        .unwrap();

    // The SSH remote resolves to HTTPS...
    let url = run_until(
        &mut one,
        &repo,
        "git ls-remote --get-url origin",
        "https://github.com/",
    )
    .await;
    assert!(url.contains("https://github.com/team/app.git"), "{url}");
    // ...and git gets the profile's token from kumod git-credential.
    let fill = "printf 'protocol=https\\nhost=github.com\\n\\n' | GIT_TERMINAL_PROMPT=0 git credential fill";
    let credential = run(&mut one, &repo, fill).await;
    assert!(
        credential.contains("username=x-access-token"),
        "{credential}"
    );
    assert!(credential.contains("password=token-1"), "{credential}");

    // The default profile has no token there, and its git is as before.
    let url = run(&mut first, &repo, "git ls-remote --get-url origin").await;
    assert!(url.contains("git@github.com:team/app.git"), "{url}");

    // Only hosts of the profile's repositories.
    let other = one
        .profiles
        .git_credential(pb::GitCredentialRequest {
            host: "gitlab.com".into(),
        })
        .await
        .unwrap_err();
    assert_eq!(other.code(), Code::NotFound);
}

fn keygen(dir: &Path, name: &str) -> std::path::PathBuf {
    std::fs::create_dir_all(dir).unwrap();
    let key = dir.join(name);
    let made = std::process::Command::new("ssh-keygen")
        .args([
            "-q",
            "-t",
            "ed25519",
            "-N",
            "",
            "-C",
            "one@workspace-1",
            "-f",
        ])
        .arg(&key)
        .status()
        .unwrap();
    assert!(made.success());
    key
}

#[tokio::test(flavor = "multi_thread")]
async fn an_ssh_key_is_the_only_one_offered_and_signs_commits() {
    let daemon = TestDaemon::start().await;
    let mut first = daemon.client().await;
    let mut one = create(&mut first, "Workspace 1").await;
    let key = keygen(&daemon.home().join(".ssh"), "id_workspace_1");
    let repo = git_repo(
        &daemon.home().join("dev/app"),
        Some("git@github.com:team/app.git"),
    );
    save_namespace(&mut one, "app", &[&repo]).await;

    let keys = one
        .profiles
        .list_ssh_keys(pb::ListSshKeysRequest {})
        .await
        .unwrap()
        .into_inner()
        .keys;
    assert_eq!(keys.len(), 1);
    assert_eq!(keys[0].path, "~/.ssh/id_workspace_1");
    assert!(keys[0].fingerprint.starts_with("SHA256:"));

    one.pipelines
        .save_host_token(pb::SaveHostTokenRequest {
            host: "github.com".into(),
            token: "token-1".into(),
        })
        .await
        .unwrap();
    update(
        &mut one,
        pb::UpdateProfileRequest {
            id: "workspace-1".into(),
            ssh_key: Some(keys[0].path.clone()),
            sign_commits: Some(true),
            ..Default::default()
        },
    )
    .await;
    let env = run_until(&mut one, &repo, "env", "GIT_SSH_COMMAND=").await;
    assert!(
        env.contains(&format!(
            "GIT_SSH_COMMAND=ssh -i '{}' -o IdentitiesOnly=yes",
            key.display()
        )),
        "{env}"
    );
    // With a key, SSH remotes stay SSH.
    let url = run(&mut one, &repo, "git ls-remote --get-url origin").await;
    assert!(url.contains("git@github.com:team/app.git"), "{url}");

    std::fs::write(repo.join("a.txt"), "a\n").unwrap();
    one.git
        .commit(pb::CommitRequest {
            worktree_path: repo.display().to_string(),
            message: "signed".into(),
            all: true,
            amend: false,
        })
        .await
        .unwrap();
    let commit = git(&repo, &["cat-file", "commit", "HEAD"]);
    assert!(commit.contains("-----BEGIN SSH SIGNATURE-----"), "{commit}");
}

#[tokio::test(flavor = "multi_thread")]
async fn profile_settings_round_trip() {
    let daemon = TestDaemon::start().await;
    let mut first = daemon.client().await;
    let mut one = create(&mut first, "Workspace 1").await;
    let accounts = pb::GhAccounts {
        accounts: vec![pb::GhAccount {
            host: "github.com".into(),
            login: "user-1".into(),
        }],
    };
    let updated = one
        .profiles
        .update(pb::UpdateProfileRequest {
            id: "workspace-1".into(),
            ssh_key: Some("~/.ssh/id_workspace_1".into()),
            gh_accounts: Some(accounts),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(updated.ssh_key, "~/.ssh/id_workspace_1");
    assert!(!updated.sign_commits);
    assert_eq!(updated.gh_accounts[0].login, "user-1");

    let bad = one
        .profiles
        .update(pb::UpdateProfileRequest {
            id: "workspace-1".into(),
            ssh_key: Some("id_rsa".into()),
            ..Default::default()
        })
        .await
        .unwrap_err();
    assert_eq!(bad.code(), Code::InvalidArgument);
}

/// A `gh` in the daemon's `bin/` with two accounts on github.com: `active`
/// holds the active one, and `auth login` signs in `user-2`.
fn fake_gh(bin: &Path) {
    use std::os::unix::fs::PermissionsExt;
    let script = format!(
        r#"#!/bin/sh
d='{dir}'
active=$(/bin/cat "$d/active")
user=""
prev=""
for arg in "$@"; do
  [ "$prev" = "--user" ] && user="$arg"
  prev="$arg"
done
case "$2" in
  token) echo "token-of-${{user:-$active}}" ;;
  status) echo "  ✓ Logged in to github.com account $active (keyring)" ;;
  switch) echo "$user" > "$d/active" ;;
  login) echo user-2 > "$d/active" ;;
esac
"#,
        dir = bin.display()
    );
    let path = bin.join("gh");
    std::fs::write(&path, script).unwrap();
    std::fs::write(bin.join("active"), "user-1\n").unwrap();
    std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
}

#[tokio::test(flavor = "multi_thread")]
async fn signing_in_with_gh_adds_the_account_and_keeps_the_active_one() {
    let daemon = TestDaemon::start().await;
    fake_gh(&daemon.bin());
    let mut first = daemon.client().await;
    let mut one = create(&mut first, "Workspace 1").await;
    let repo = git_repo(
        &daemon.home().join("dev/app"),
        Some("git@github.com:team/app.git"),
    );
    save_namespace(&mut one, "app", &[&repo]).await;

    one.pipelines
        .sign_in_with_gh(pb::SignInWithGhRequest {
            host: "github.com".into(),
        })
        .await
        .unwrap();
    // The sign-in is checked every few seconds.
    let accounts = tokio::time::timeout(Duration::from_secs(20), async {
        loop {
            let profiles = first
                .profiles
                .list(pb::ListProfilesRequest {})
                .await
                .unwrap()
                .into_inner()
                .profiles;
            let accounts = profiles
                .into_iter()
                .find(|p| p.id == "workspace-1")
                .unwrap()
                .gh_accounts;
            if !accounts.is_empty() {
                return accounts;
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    })
    .await
    .expect("the account never reached the profile");
    assert_eq!(accounts[0].host, "github.com");
    assert_eq!(accounts[0].login, "user-2");
    let active = std::fs::read_to_string(daemon.bin().join("active")).unwrap();
    assert_eq!(active.trim(), "user-1", "gh's active account is back");

    // The profile's shells use its account; the default profile's don't.
    run_until(&mut one, &repo, "env", "GH_TOKEN=token-of-user-2").await;
    let env = run(&mut first, &repo, "env").await;
    assert!(!env.contains("GH_TOKEN="), "{env}");
}
