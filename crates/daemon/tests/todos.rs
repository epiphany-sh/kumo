//! `Todos` service end to end: added and edited over gRPC, kept in the
//! profile's database, handed to an agent, moved by the agent's own reports
//! (`kumod todo`) and by the user, and streamed to watchers.

mod common;

use common::{TIMEOUT, TestDaemon};
use kumo_grpc::services::AGENT_REPORT;
use kumo_proto::v1 as pb;
use tokio_stream::StreamExt;
use tonic::Code;

fn status(todo: &pb::Todo) -> pb::TodoStatus {
    pb::TodoStatus::try_from(todo.status).unwrap()
}

fn report(id: &str, status: pb::TodoStatus, note: &str) -> pb::SetTodoStatusRequest {
    pb::SetTodoStatusRequest {
        id: id.to_owned(),
        status: status as i32,
        by: AGENT_REPORT.to_owned(),
        note: note.to_owned(),
        ..pb::SetTodoStatusRequest::default()
    }
}

#[tokio::test]
async fn a_todo_goes_from_added_to_merged() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let mut watch = client
        .todos
        .watch(pb::WatchTodosRequest {})
        .await
        .unwrap()
        .into_inner();
    let first = tokio::time::timeout(TIMEOUT, watch.next())
        .await
        .unwrap()
        .unwrap()
        .unwrap();
    assert!(first.todos.is_empty());

    let todo = client
        .todos
        .add(pb::AddTodoRequest {
            title: " Retry on rate limits ".into(),
            notes: "Back off".into(),
            repo_path: String::new(),
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(todo.title, "Retry on rate limits");
    assert_eq!(status(&todo), pb::TodoStatus::Open);
    let seen = tokio::time::timeout(TIMEOUT, watch.next())
        .await
        .unwrap()
        .unwrap()
        .unwrap();
    assert_eq!(seen.todos.len(), 1);

    // Blank titles and statuses before an agent are refused.
    let blank = client
        .todos
        .add(pb::AddTodoRequest {
            title: "  ".into(),
            ..Default::default()
        })
        .await;
    assert_eq!(blank.unwrap_err().code(), Code::InvalidArgument);
    let early = client
        .todos
        .set_status(report(&todo.id, pb::TodoStatus::Testing, ""))
        .await;
    assert_eq!(early.unwrap_err().code(), Code::InvalidArgument);

    let attached = client
        .todos
        .attach(pb::AttachTodoRequest {
            id: todo.id.clone(),
            run: Some(pb::TodoRun {
                repo_path: "/code/repo-1".into(),
                worktree_path: "/wt/repo-1/retry".into(),
                branch: "fix/retry".into(),
                agent_name: "Claude Code".into(),
                model: "opus".into(),
                effort: "high".into(),
                ..Default::default()
            }),
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(status(&attached), pb::TodoStatus::Working);
    assert_eq!(attached.repo_path, "/code/repo-1");

    // The agent's own reports, signed with its name.
    let tested = client
        .todos
        .set_status(report(&todo.id, pb::TodoStatus::Testing, "31 of 48"))
        .await
        .unwrap()
        .into_inner();
    assert_eq!(tested.steps.last().unwrap().by, "Claude Code");
    assert_eq!(tested.steps.last().unwrap().note, "31 of 48");
    let pushed = client
        .todos
        .set_status(report(&todo.id, pb::TodoStatus::Pushed, ""))
        .await;
    assert_eq!(pushed.unwrap_err().code(), Code::InvalidArgument);
    client
        .todos
        .set_status(report(&todo.id, pb::TodoStatus::Review, "48 pass"))
        .await
        .unwrap();

    // The user approves, Kumo records the pull request and its merge.
    let by = |status: pb::TodoStatus, who: &str| pb::SetTodoStatusRequest {
        id: todo.id.clone(),
        status: status as i32,
        by: who.into(),
        ..Default::default()
    };
    client
        .todos
        .set_status(by(pb::TodoStatus::Pushed, "You"))
        .await
        .unwrap();
    let with_pr = client
        .todos
        .set_status(pb::SetTodoStatusRequest {
            pr_number: 418,
            pr_url: "https://example.test/418".into(),
            ..by(pb::TodoStatus::Pr, "Kumo")
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(with_pr.run.unwrap().pr_number, 418);
    let merged = client
        .todos
        .set_status(by(pb::TodoStatus::Merged, "Kumo"))
        .await
        .unwrap()
        .into_inner();
    assert_eq!(merged.steps.len(), 6);

    // Cleaned up: the run is forgotten and it's checked off.
    client
        .todos
        .set_status(pb::SetTodoStatusRequest {
            clear_run: true,
            ..by(pb::TodoStatus::Open, "You")
        })
        .await
        .unwrap();
    let done = client
        .todos
        .update(pb::UpdateTodoRequest {
            id: todo.id.clone(),
            title: todo.title.clone(),
            notes: todo.notes.clone(),
            repo_path: "/code/repo-1".into(),
            done: true,
        })
        .await
        .unwrap()
        .into_inner();
    assert!(done.done && done.run.is_none());

    client
        .todos
        .delete(pb::DeleteTodoRequest {
            id: todo.id.clone(),
        })
        .await
        .unwrap();
    let missing = client
        .todos
        .delete(pb::DeleteTodoRequest { id: todo.id })
        .await;
    assert_eq!(missing.unwrap_err().code(), Code::NotFound);
}

#[tokio::test]
async fn todos_belong_to_their_workspace() {
    let daemon = TestDaemon::start().await;
    let mut default = daemon.client().await;
    default
        .todos
        .add(pb::AddTodoRequest {
            title: "Only here".into(),
            ..Default::default()
        })
        .await
        .unwrap();
    let other = default
        .profiles
        .create(pb::CreateProfileRequest {
            name: "Workspace 2".into(),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner();
    let mut second = daemon.client().await.with_profile(Some(&other.id));
    let mut watch = second
        .todos
        .watch(pb::WatchTodosRequest {})
        .await
        .unwrap()
        .into_inner();
    let list = tokio::time::timeout(TIMEOUT, watch.next())
        .await
        .unwrap()
        .unwrap()
        .unwrap();
    assert!(list.todos.is_empty());
}
