//! `Git` service end to end: status, watch, diffs, files, staging,
//! commits, push and history on real repositories.

mod common;

use std::path::{Path, PathBuf};

use common::{TIMEOUT, TestDaemon, git, git_repo, save_namespace};
use kumo_grpc::client::KumoClient;
use kumo_proto::v1 as pb;

/// A repo in the workspace plus a worktree on `feat/x` with one commit
/// (README changed, `src/lib.rs` added) on top of `main`.
async fn feature_worktree(daemon: &TestDaemon, client: &mut KumoClient) -> PathBuf {
    let repo = git_repo(&daemon.home().join("dev/app"), None);
    save_namespace(client, "app", &[&repo]).await;
    let worktree = client
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
    let path = PathBuf::from(worktree.path);
    std::fs::write(path.join("README.md"), "hello\nworld\n").unwrap();
    std::fs::create_dir_all(path.join("src")).unwrap();
    std::fs::write(path.join("src/lib.rs"), "pub fn a() {}\n").unwrap();
    git(&path, &["add", "-A"]);
    git(&path, &["commit", "-q", "-m", "feat: first"]);
    path
}

fn request(worktree: &Path) -> String {
    worktree.display().to_string()
}

async fn status(client: &mut KumoClient, worktree: &Path) -> pb::WorktreeChanges {
    let mut stream = client
        .git
        .watch_status(pb::WatchStatusRequest {
            worktree_path: request(worktree),
        })
        .await
        .unwrap()
        .into_inner();
    stream.message().await.unwrap().unwrap()
}

fn find<'a>(changes: &'a [pb::FileChange], path: &str) -> &'a pb::FileChange {
    changes
        .iter()
        .find(|c| c.path == path)
        .unwrap_or_else(|| panic!("{path} not in {changes:?}"))
}

#[tokio::test(flavor = "multi_thread")]
async fn status_separates_working_and_committed_changes() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = feature_worktree(&daemon, &mut client).await;
    std::fs::write(wt.join("README.md"), "hello\nthere\nworld\n").unwrap(); // unstaged
    std::fs::write(wt.join("staged.txt"), "a\nb\n").unwrap();
    git(&wt, &["add", "staged.txt"]);
    std::fs::write(wt.join("notes.md"), "1\n2\n3\n").unwrap(); // untracked

    let s = status(&mut client, &wt).await;
    assert_eq!((s.branch.as_str(), s.base.as_str()), ("feat/x", "main"));

    let readme = find(&s.working, "README.md");
    assert_eq!(
        (readme.unstaged(), readme.additions, readme.deletions),
        (pb::ChangeKind::Modified, 1, 0)
    );
    assert_eq!(
        find(&s.working, "staged.txt").staged(),
        pb::ChangeKind::Added
    );
    let notes = find(&s.working, "notes.md");
    assert_eq!(
        (notes.unstaged(), notes.additions),
        (pb::ChangeKind::Untracked, 3)
    );

    assert_eq!(
        find(&s.committed, "src/lib.rs").staged(),
        pb::ChangeKind::Added
    );
    assert_eq!(
        find(&s.committed, "README.md").staged(),
        pb::ChangeKind::Modified
    );
}

#[tokio::test(flavor = "multi_thread")]
async fn watch_pushes_status_when_files_change() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = feature_worktree(&daemon, &mut client).await;
    let mut stream = client
        .git
        .watch_status(pb::WatchStatusRequest {
            worktree_path: request(&wt),
        })
        .await
        .unwrap()
        .into_inner();
    let first = stream.message().await.unwrap().unwrap();
    assert!(first.working.is_empty());

    // An agent (or anyone) edits a file: the new status arrives on its own.
    std::fs::write(wt.join("new.txt"), "x\n").unwrap();
    let next = tokio::time::timeout(TIMEOUT, stream.message())
        .await
        .expect("no push")
        .unwrap()
        .unwrap();
    assert_eq!(
        find(&next.working, "new.txt").unstaged(),
        pb::ChangeKind::Untracked
    );
}

#[tokio::test(flavor = "multi_thread")]
async fn diffs_show_the_whole_file() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = feature_worktree(&daemon, &mut client).await;
    std::fs::write(wt.join("README.md"), "hello\nthere\nworld\n").unwrap();
    std::fs::write(wt.join("untracked.txt"), "a\nb\n").unwrap();

    let diff = |path: &str, scope: pb::DiffScope| pb::DiffRequest {
        worktree_path: request(&wt),
        path: path.into(),
        scope: scope.into(),
    };
    let lines = |d: pb::DiffResponse| {
        d.lines
            .into_iter()
            .map(|l| (l.kind(), l.text))
            .collect::<Vec<_>>()
    };
    use pb::DiffLineKind::{Added, Context};

    let working = client
        .git
        .diff(diff("README.md", pb::DiffScope::Working))
        .await
        .unwrap()
        .into_inner();
    assert_eq!(
        lines(working),
        vec![
            (Context, "hello".into()),
            (Added, "there".into()),
            (Context, "world".into())
        ]
    );

    let untracked = client
        .git
        .diff(diff("untracked.txt", pb::DiffScope::Working))
        .await
        .unwrap()
        .into_inner();
    assert_eq!(
        lines(untracked),
        vec![(Added, "a".into()), (Added, "b".into())]
    );

    let committed = client
        .git
        .diff(diff("README.md", pb::DiffScope::Committed))
        .await
        .unwrap()
        .into_inner();
    assert_eq!(
        lines(committed),
        vec![(Context, "hello".into()), (Added, "world".into())]
    );

    let unchanged = client
        .git
        .diff(diff("src/lib.rs", pb::DiffScope::Working))
        .await
        .unwrap()
        .into_inner();
    assert_eq!(lines(unchanged), vec![(Context, "pub fn a() {}".into())]);
}

#[tokio::test(flavor = "multi_thread")]
async fn files_are_listed_read_and_written_inside_the_worktree_only() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = feature_worktree(&daemon, &mut client).await;
    std::fs::write(wt.join(".gitignore"), "target/\n").unwrap();
    std::fs::create_dir_all(wt.join("target")).unwrap();
    std::fs::write(wt.join("target/out.bin"), "x").unwrap();

    let list = client
        .git
        .list_files(pb::ListFilesRequest {
            worktree_path: request(&wt),
        })
        .await
        .unwrap()
        .into_inner();
    assert!(
        list.paths.contains(&"src/lib.rs".to_owned())
            && list.paths.contains(&".gitignore".to_owned())
    );
    assert!(
        !list.paths.iter().any(|p| p.starts_with("target/")),
        "ignored files are not listed"
    );

    client
        .git
        .write_file(pb::WriteFileRequest {
            worktree_path: request(&wt),
            path: "src/new.rs".into(),
            content: b"fn b() {}\n".to_vec().into(),
        })
        .await
        .unwrap();
    let read = client
        .git
        .read_file(pb::ReadFileRequest {
            worktree_path: request(&wt),
            path: "src/new.rs".into(),
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(
        (read.content.as_ref(), read.binary),
        (&b"fn b() {}\n"[..], false)
    );

    for path in ["../outside.txt", "/etc/hosts"] {
        let error = client
            .git
            .read_file(pb::ReadFileRequest {
                worktree_path: request(&wt),
                path: path.into(),
            })
            .await
            .unwrap_err();
        assert_eq!(error.code(), tonic::Code::InvalidArgument, "{path}");
    }
    let unknown = client
        .git
        .list_files(pb::ListFilesRequest {
            worktree_path: "/tmp".into(),
        })
        .await
        .unwrap_err();
    assert_eq!(
        unknown.code(),
        tonic::Code::NotFound,
        "only worktrees in the workspace"
    );
}

#[tokio::test(flavor = "multi_thread")]
async fn stage_commit_undo_and_log() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = feature_worktree(&daemon, &mut client).await;
    std::fs::write(wt.join("a.txt"), "a\n").unwrap();
    std::fs::write(wt.join("b.txt"), "b\n").unwrap();
    let paths = |p: &[&str]| pb::PathsRequest {
        worktree_path: request(&wt),
        paths: p.iter().map(|s| (*s).to_owned()).collect(),
    };

    client.git.stage(paths(&["a.txt", "b.txt"])).await.unwrap();
    client.git.unstage(paths(&["b.txt"])).await.unwrap();
    let s = status(&mut client, &wt).await;
    assert_eq!(find(&s.working, "a.txt").staged(), pb::ChangeKind::Added);
    assert_eq!(
        find(&s.working, "b.txt").unstaged(),
        pb::ChangeKind::Untracked
    );

    let empty = client
        .git
        .commit(pb::CommitRequest {
            worktree_path: request(&wt),
            message: "  ".into(),
            ..Default::default()
        })
        .await
        .unwrap_err();
    assert_eq!(empty.code(), tonic::Code::InvalidArgument);

    let commit = client
        .git
        .commit(pb::CommitRequest {
            worktree_path: request(&wt),
            message: "feat: a".into(),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner();
    let log = client
        .git
        .log(pb::LogRequest {
            worktree_path: request(&wt),
            limit: 10,
        })
        .await
        .unwrap()
        .into_inner()
        .commits;
    assert_eq!(
        (log[0].short_sha.as_str(), log[0].subject.as_str()),
        (commit.short_sha.as_str(), "feat: a")
    );
    assert_eq!(
        log.iter().map(|c| c.subject.as_str()).collect::<Vec<_>>(),
        vec!["feat: a", "feat: first", "init"]
    );

    client
        .git
        .undo_last_commit(pb::WorktreeRequest {
            worktree_path: request(&wt),
        })
        .await
        .unwrap();
    let s = status(&mut client, &wt).await;
    assert_eq!(
        find(&s.working, "a.txt").staged(),
        pb::ChangeKind::Added,
        "undo keeps the changes staged"
    );

    // "Commit all" stages everything first.
    client
        .git
        .commit(pb::CommitRequest {
            worktree_path: request(&wt),
            message: "feat: all".into(),
            all: true,
            ..Default::default()
        })
        .await
        .unwrap();
    assert!(status(&mut client, &wt).await.working.is_empty());
}

#[tokio::test(flavor = "multi_thread")]
async fn push_sets_the_upstream_and_restore_discards_changes() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let remote = daemon.home().join("remote.git");
    std::process::Command::new("git")
        .args(["init", "-q", "--bare"])
        .arg(&remote)
        .output()
        .unwrap();
    let wt = feature_worktree(&daemon, &mut client).await;
    git(
        &wt,
        &["remote", "add", "origin", &remote.display().to_string()],
    );

    client
        .git
        .push(pb::WorktreeRequest {
            worktree_path: request(&wt),
        })
        .await
        .unwrap();
    let s = status(&mut client, &wt).await;
    assert_eq!((s.upstream.as_str(), s.ahead), ("origin/feat/x", 0));

    std::fs::write(wt.join("README.md"), "oops\n").unwrap();
    client
        .git
        .restore(pb::PathsRequest {
            worktree_path: request(&wt),
            paths: vec!["README.md".into()],
        })
        .await
        .unwrap();
    assert_eq!(
        std::fs::read_to_string(wt.join("README.md")).unwrap(),
        "hello\nworld\n"
    );
}
