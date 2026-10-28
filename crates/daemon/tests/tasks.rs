//! `Tasks` service end to end: a real Obsidian vault on disk (detected,
//! watched, written back), API sources' tokens, and the update stream.

mod common;

use std::collections::HashMap;
use std::path::Path;

use common::{TIMEOUT, TestDaemon};
use kumo_grpc::client::KumoClient;
use kumo_proto::v1 as pb;
use tokio_stream::StreamExt;
use tonic::Code;

/// What a client keeps from the update stream.
#[derive(Debug, Default)]
struct Board {
    sources: Vec<pb::TaskSource>,
    tasks: HashMap<String, Vec<pb::Task>>,
    links: Vec<pb::TaskLink>,
    updates: usize,
}

impl Board {
    fn apply(&mut self, update: pb::TasksUpdate) {
        self.tasks
            .retain(|id, _| update.sources.iter().any(|s| &s.id == id));
        for changed in update.changed {
            self.tasks.insert(changed.source_id, changed.tasks);
        }
        self.sources = update.sources;
        self.links = update.links;
        self.updates += 1;
    }

    fn titles(&self) -> Vec<(String, pb::TaskStatus)> {
        let mut all: Vec<_> = self
            .tasks
            .values()
            .flatten()
            .map(|t| (t.title.clone(), t.status()))
            .collect();
        all.sort();
        all
    }
}

struct Watch {
    stream: tonic::Streaming<pb::TasksUpdate>,
    board: Board,
}

impl Watch {
    async fn start(client: &mut KumoClient) -> Self {
        let stream = client
            .tasks
            .watch(pb::WatchTasksRequest {})
            .await
            .unwrap()
            .into_inner();
        Self {
            stream,
            board: Board::default(),
        }
    }

    async fn until(&mut self, what: &str, done: impl Fn(&Board) -> bool) -> &Board {
        let wait = async {
            while !done(&self.board) {
                let update = self.stream.next().await.unwrap().unwrap();
                self.board.apply(update);
            }
        };
        if tokio::time::timeout(TIMEOUT, wait).await.is_err() {
            panic!("timed out waiting for: {what}\n{:#?}", self.board);
        }
        &self.board
    }
}

fn write(path: &Path, text: &str) {
    std::fs::create_dir_all(path.parent().unwrap()).unwrap();
    std::fs::write(path, text).unwrap();
}

/// A vault in the test home, registered in Obsidian's settings so it can
/// be detected.
fn vault(daemon: &TestDaemon) -> std::path::PathBuf {
    let home = daemon.home();
    let vault = home.join("Notes");
    write(
        &vault.join("Inbox.md"),
        "- [ ] Call Ana ⏫\n- [x] Pay rent\n",
    );
    write(
        &vault.join("Work/Kumo.md"),
        "## Tasks\n- [ ] Ship tasks 📅 2026-11-02 #kumo\n",
    );
    let settings = serde_json_like(&vault);
    for dir in [
        "Library/Application Support/obsidian",
        "AppData/Roaming/obsidian",
        ".config/obsidian",
    ] {
        write(&home.join(dir).join("obsidian.json"), &settings);
    }
    vault
}

fn serde_json_like(vault: &Path) -> String {
    format!(
        r#"{{"vaults":{{"abc":{{"path":"{}","ts":1}}}}}}"#,
        vault.display().to_string().replace('\\', "\\\\")
    )
}

fn options(pairs: &[(&str, &str)]) -> HashMap<String, String> {
    pairs
        .iter()
        .map(|(k, v)| ((*k).to_owned(), (*v).to_owned()))
        .collect()
}

#[tokio::test]
async fn obsidian_vault_end_to_end() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let vault = vault(&daemon);
    let mut watch = Watch::start(&mut client).await;
    watch.until("first update", |b| b.updates > 0).await;

    let detected = client
        .tasks
        .detect(pb::DetectSourcesRequest {})
        .await
        .unwrap()
        .into_inner()
        .sources;
    let found = detected
        .iter()
        .find(|d| d.kind() == pb::TaskSourceKind::Obsidian)
        .expect("vault detected");
    assert_eq!(found.name, "Notes");
    assert_eq!(found.options["vault"], vault.display().to_string());

    let tested = client
        .tasks
        .test_source(pb::TestSourceRequest {
            kind: found.kind,
            options: found.options.clone(),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(tested.message, "2 open tasks, 3 in total");

    let source = client
        .tasks
        .save_source(pb::SaveSourceRequest {
            kind: found.kind,
            name: String::new(),
            options: found.options.clone(),
            enabled: true,
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(source.name, "Obsidian");
    assert_eq!(source.badge, "OB");
    assert!(!source.needs_secret);

    let board = watch.until("vault read", |b| b.titles().len() == 3).await;
    let ship = board.tasks[&source.id]
        .iter()
        .find(|t| t.title == "Ship tasks")
        .unwrap()
        .clone();
    assert_eq!((ship.key.as_str(), ship.context.as_str()), ("Kumo", "Work"));
    assert_eq!(ship.due, "2026-11-02");
    assert_eq!(ship.labels, ["kumo"]);
    assert_eq!(ship.suggested_branch, "feat/ship-tasks");
    assert!(board.sources[0].last_synced_unix_ms > 0);
    // Notes are personal: every task is the user's, a plain to-do.
    assert!(board.tasks[&source.id].iter().all(|t| t.mine));
    assert_eq!(ship.r#type(), pb::TaskType::Todo);
    assert_eq!(ship.assignee, None);

    // The detail says where the checkbox is and what surrounds it.
    let detail = client
        .tasks
        .get_task(pb::GetTaskRequest {
            id: ship.id.clone(),
            refresh: false,
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(detail.location, "Work/Kumo.md · line 2");
    assert_eq!(
        detail.description,
        "## Tasks\n- [ ] Ship tasks 📅 2026-11-02 #kumo"
    );
    assert!(!detail.stale && detail.fetched_unix_ms > 0);
    let card = detail.task.unwrap();
    assert_eq!((card.id.as_str(), card.mine), (ship.id.as_str(), true));

    // Marking it done rewrites the checkbox in the note.
    let done = client
        .tasks
        .set_status(pb::SetTaskStatusRequest {
            task_id: ship.id.clone(),
            status: pb::TaskStatus::Done.into(),
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(done.status(), pb::TaskStatus::Done);
    assert_eq!(
        std::fs::read_to_string(vault.join("Work/Kumo.md")).unwrap(),
        "## Tasks\n- [x] Ship tasks 📅 2026-11-02 #kumo\n"
    );
    let cached = client
        .tasks
        .get_task(pb::GetTaskRequest {
            id: ship.id.clone(),
            refresh: false,
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(
        cached.task.unwrap().status(),
        pb::TaskStatus::Done,
        "the cached detail follows the status"
    );
    let refreshed = client
        .tasks
        .get_task(pb::GetTaskRequest {
            id: ship.id.clone(),
            refresh: true,
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(
        refreshed.description,
        "## Tasks\n- [x] Ship tasks 📅 2026-11-02 #kumo"
    );
    let gone = client
        .tasks
        .get_task(pb::GetTaskRequest {
            id: format!("{}/Work/Kumo.md#0000", source.id),
            refresh: false,
        })
        .await
        .unwrap_err();
    assert_eq!(gone.code(), Code::NotFound);

    // Editing a note elsewhere is pushed.
    write(
        &vault.join("Inbox.md"),
        "- [ ] Call Ana ⏫\n- [x] Pay rent\n- [ ] Buy milk\n",
    );
    watch
        .until("external edit pushed", |b| {
            b.titles().iter().any(|(t, _)| t == "Buy milk")
        })
        .await;

    // Review isn't a checkbox state.
    let review = client
        .tasks
        .set_status(pb::SetTaskStatusRequest {
            task_id: ship.id.clone(),
            status: pb::TaskStatus::Review.into(),
        })
        .await
        .unwrap_err();
    assert_eq!(review.code(), Code::FailedPrecondition);

    client
        .tasks
        .link(pb::LinkTaskRequest {
            task_id: ship.id.clone(),
            worktree_path: "/wt/kumo/feat-ship-tasks".into(),
            branch: "feat/ship-tasks".into(),
        })
        .await
        .unwrap();
    watch.until("link pushed", |b| b.links.len() == 1).await;

    client
        .tasks
        .delete_source(pb::DeleteSourceRequest {
            id: source.id.clone(),
        })
        .await
        .unwrap();
    let board = watch.until("source gone", |b| b.sources.is_empty()).await;
    assert!(board.tasks.is_empty() && board.links.is_empty());
}

#[tokio::test]
async fn api_sources_keep_their_token_and_report_failures() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let mut watch = Watch::start(&mut client).await;
    // Nothing listens there: the sync fails, the source says why.
    let jira = options(&[("site", "http://127.0.0.1:9"), ("email", "ana@acme.com")]);
    let save = |secret: &str| pb::SaveSourceRequest {
        kind: pb::TaskSourceKind::Jira.into(),
        name: "Acme".into(),
        options: jira.clone(),
        enabled: true,
        secret: secret.into(),
        ..Default::default()
    };

    let missing = client.tasks.save_source(save("")).await.unwrap_err();
    assert_eq!(missing.code(), Code::FailedPrecondition);
    assert!(
        missing.message().contains("API token"),
        "{}",
        missing.message()
    );

    let source = client
        .tasks
        .save_source(save("tok"))
        .await
        .unwrap()
        .into_inner();
    assert!(source.has_secret && source.needs_secret);
    assert!(
        !source.options.contains_key("jql"),
        "no JQL: the user's issues and their projects' recent ones"
    );
    let board = watch
        .until("sync error", |b| {
            b.sources.first().is_some_and(|s| !s.error.is_empty())
        })
        .await;
    assert!(
        board.sources[0].error.contains("can't reach Jira"),
        "{}",
        board.sources[0].error
    );

    // Nothing cached and the site unreachable: the detail can't be served.
    let detail = client
        .tasks
        .get_task(pb::GetTaskRequest {
            id: format!("{}/PRC-1", source.id),
            refresh: false,
        })
        .await
        .unwrap_err();
    assert_eq!(detail.code(), Code::Unavailable, "{}", detail.message());

    // Testing an edited source reuses its stored token.
    let tested = client
        .tasks
        .test_source(pb::TestSourceRequest {
            id: source.id.clone(),
            kind: pb::TaskSourceKind::Jira.into(),
            options: jira.clone(),
            secret: String::new(),
        })
        .await
        .unwrap_err();
    assert_eq!(tested.code(), Code::Unavailable);

    let insecure = client
        .tasks
        .save_source(pb::SaveSourceRequest {
            options: options(&[("site", "http://acme.atlassian.net"), ("email", "a@b.c")]),
            ..save("tok")
        })
        .await
        .unwrap_err();
    assert_eq!(insecure.code(), Code::InvalidArgument);

    let unknown_kind = client
        .tasks
        .save_source(pb::SaveSourceRequest {
            kind: 99,
            ..save("tok")
        })
        .await
        .unwrap_err();
    assert_eq!(unknown_kind.code(), Code::InvalidArgument);
}
