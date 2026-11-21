use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

use kumo_domain::todos::{Todo, TodoError, TodoId, TodoRun, TodoStatus, TodoStore};

use super::{StatusChange, TodoEdit, TodoService};

#[derive(Default)]
struct MemoryStore(Mutex<HashMap<TodoId, Todo>>);

impl TodoStore for MemoryStore {
    fn todos(&self) -> Result<Vec<Todo>, TodoError> {
        let mut all: Vec<Todo> = self.0.lock().unwrap().values().cloned().collect();
        all.sort_by_key(|t| std::cmp::Reverse(t.created));
        Ok(all)
    }
    fn save(&self, todo: &Todo) -> Result<(), TodoError> {
        self.0.lock().unwrap().insert(todo.id.clone(), todo.clone());
        Ok(())
    }
    fn delete(&self, id: &TodoId) -> Result<(), TodoError> {
        self.0.lock().unwrap().remove(id);
        Ok(())
    }
}

fn run() -> TodoRun {
    TodoRun {
        repo_path: "/code/repo-1".into(),
        worktree_path: "/wt/repo-1/fix-retry".into(),
        branch: "fix/retry".into(),
        agent_name: "Claude Code".into(),
        ..TodoRun::default()
    }
}

fn change(status: TodoStatus, by: &str) -> StatusChange {
    StatusChange {
        status,
        by: by.into(),
        note: String::new(),
        pr: None,
        clear_run: false,
    }
}

async fn service() -> (Arc<TodoService>, Arc<MemoryStore>) {
    let store = Arc::new(MemoryStore::default());
    (TodoService::load(store.clone()).await.unwrap(), store)
}

#[tokio::test]
async fn adds_newest_first_and_keeps_them() {
    let (todos, store) = service().await;
    todos.add("First", "", None).await.unwrap();
    let second = todos
        .add("Second", "notes", Some(PathBuf::from("/code/repo-1")))
        .await
        .unwrap();
    assert_eq!(todos.todos()[0].id, second.id);
    assert_eq!(store.todos().unwrap().len(), 2);
    assert!(todos.add("  ", "", None).await.is_err());
}

#[tokio::test]
async fn edits_only_what_is_given() {
    let (todos, _) = service().await;
    let t = todos
        .add("Title", "notes", Some("/code/repo-1".into()))
        .await
        .unwrap();
    let edited = todos
        .update(
            &t.id,
            TodoEdit {
                notes: Some("more".into()),
                repo_path: Some(None),
                ..TodoEdit::default()
            },
        )
        .await
        .unwrap();
    assert_eq!(edited.title, "Title");
    assert_eq!(edited.notes, "more");
    assert_eq!(edited.repo_path, None);
}

#[tokio::test]
async fn an_agent_reports_its_own_steps_but_never_pushes() {
    let (todos, _) = service().await;
    let t = todos.add("Retry", "", None).await.unwrap();
    // Not with an agent yet.
    assert!(
        todos
            .report(&t.id, "testing", "Claude Code", "")
            .await
            .is_err()
    );
    let attached = todos.attach(&t.id, run()).await.unwrap();
    assert_eq!(attached.status(), TodoStatus::Working);
    assert_eq!(attached.repo_path, Some(PathBuf::from("/code/repo-1")));

    let tested = todos
        .report(&t.id, "testing", "", "31 of 48")
        .await
        .unwrap();
    assert_eq!(tested.status(), TodoStatus::Testing);
    assert_eq!(tested.steps.last().unwrap().by, "Claude Code");
    assert_eq!(tested.steps.last().unwrap().note, "31 of 48");
    assert!(todos.report(&t.id, "pushed", "", "").await.is_err());
    assert!(todos.report(&t.id, "nope", "", "").await.is_err());
    todos
        .report(&t.id, "review", "", "48 tests pass")
        .await
        .unwrap();

    // The user approves; the agent can't move it back afterwards.
    todos
        .set_status(&t.id, change(TodoStatus::Pushed, "You"))
        .await
        .unwrap();
    assert!(todos.report(&t.id, "working", "", "").await.is_err());
}

#[tokio::test]
async fn a_pull_request_is_recorded_and_cleanup_forgets_the_run() {
    let (todos, _) = service().await;
    let t = todos.add("Retry", "", None).await.unwrap();
    todos.attach(&t.id, run()).await.unwrap();
    let pr = StatusChange {
        pr: Some((418, "https://example.test/pr/418".into())),
        ..change(TodoStatus::PullRequest, "Kumo")
    };
    let with_pr = todos.set_status(&t.id, pr).await.unwrap();
    assert_eq!(with_pr.run.as_ref().unwrap().pr_number, 418);
    todos
        .set_status(&t.id, change(TodoStatus::Merged, "Kumo"))
        .await
        .unwrap();

    let cleaned = todos
        .set_status(
            &t.id,
            StatusChange {
                clear_run: true,
                ..change(TodoStatus::Open, "You")
            },
        )
        .await
        .unwrap();
    assert!(cleaned.run.is_none());
    let done = todos
        .update(
            &t.id,
            TodoEdit {
                done: Some(true),
                ..TodoEdit::default()
            },
        )
        .await
        .unwrap();
    assert!(done.done);
}

#[tokio::test]
async fn watchers_see_changes_and_deletes() {
    let (todos, store) = service().await;
    let mut rx = todos.watch();
    let t = todos.add("Watch me", "", None).await.unwrap();
    assert!(rx.has_changed().unwrap());
    assert_eq!(rx.borrow_and_update().len(), 1);
    todos.delete(&t.id).await.unwrap();
    assert!(rx.borrow_and_update().is_empty());
    assert!(store.todos().unwrap().is_empty());
    assert!(todos.delete(&t.id).await.is_err());
}

#[tokio::test]
async fn loads_what_the_store_kept() {
    let store = Arc::new(MemoryStore::default());
    let first = TodoService::load(store.clone()).await.unwrap();
    first.add("Kept", "", None).await.unwrap();
    let again = TodoService::load(store).await.unwrap();
    assert_eq!(again.todos()[0].title, "Kept");
}
