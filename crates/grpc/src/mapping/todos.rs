use std::path::PathBuf;

use kumo_domain::todos::{Todo, TodoError, TodoRun, TodoStatus, TodoStep};
use kumo_proto::v1 as pb;
use tonic::Status;

pub fn todo_status_to(status: TodoStatus) -> pb::TodoStatus {
    match status {
        TodoStatus::Open => pb::TodoStatus::Open,
        TodoStatus::Working => pb::TodoStatus::Working,
        TodoStatus::Testing => pb::TodoStatus::Testing,
        TodoStatus::Review => pb::TodoStatus::Review,
        TodoStatus::Pushed => pb::TodoStatus::Pushed,
        TodoStatus::PullRequest => pb::TodoStatus::Pr,
        TodoStatus::Merged => pb::TodoStatus::Merged,
    }
}

pub fn todo_status_from(status: pb::TodoStatus) -> TodoStatus {
    match status {
        pb::TodoStatus::Open => TodoStatus::Open,
        pb::TodoStatus::Working => TodoStatus::Working,
        pb::TodoStatus::Testing => TodoStatus::Testing,
        pb::TodoStatus::Review => TodoStatus::Review,
        pb::TodoStatus::Pushed => TodoStatus::Pushed,
        pb::TodoStatus::Pr => TodoStatus::PullRequest,
        pb::TodoStatus::Merged => TodoStatus::Merged,
    }
}

fn path(p: &std::path::Path) -> String {
    p.display().to_string()
}

pub fn todo_run_to(run: &TodoRun) -> pb::TodoRun {
    pb::TodoRun {
        repo_path: path(&run.repo_path),
        worktree_path: path(&run.worktree_path),
        branch: run.branch.clone(),
        base: run.base.clone(),
        provider_id: run.provider_id.clone(),
        agent_name: run.agent_name.clone(),
        model: run.model.clone(),
        effort: run.effort.clone(),
        session_id: run.session_id.clone(),
        pr_number: run.pr_number,
        pr_url: run.pr_url.clone(),
    }
}

pub fn todo_run_from(run: pb::TodoRun) -> TodoRun {
    TodoRun {
        repo_path: PathBuf::from(run.repo_path),
        worktree_path: PathBuf::from(run.worktree_path),
        branch: run.branch,
        base: run.base,
        provider_id: run.provider_id,
        agent_name: run.agent_name,
        model: run.model,
        effort: run.effort,
        session_id: run.session_id,
        pr_number: run.pr_number,
        pr_url: run.pr_url,
    }
}

fn millis(at: kumo_domain::time::Timestamp) -> u64 {
    at.as_unix_nanos() / 1_000_000
}

fn step_to(step: &TodoStep) -> pb::TodoStep {
    pb::TodoStep {
        status: todo_status_to(step.status) as i32,
        by: step.by.clone(),
        at_unix_ms: millis(step.at),
        note: step.note.clone(),
    }
}

pub fn todo_to(todo: &Todo) -> pb::Todo {
    pb::Todo {
        id: todo.id.to_string(),
        title: todo.title.clone(),
        notes: todo.notes.clone(),
        repo_path: todo.repo_path.as_deref().map(path).unwrap_or_default(),
        done: todo.done,
        created_unix_ms: millis(todo.created),
        status: todo_status_to(todo.status()) as i32,
        run: todo.run.as_ref().map(todo_run_to),
        steps: todo.steps.iter().map(step_to).collect(),
    }
}

pub fn todo_list_to(todos: &[Todo]) -> pb::TodoList {
    pb::TodoList {
        todos: todos.iter().map(todo_to).collect(),
    }
}

pub fn todos_status_from(error: TodoError) -> Status {
    let message = error.to_string();
    match error {
        TodoError::Unknown(_) => Status::not_found(message),
        TodoError::Invalid(_) => Status::invalid_argument(message),
        TodoError::Store(_) => Status::internal(message),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn statuses_round_trip() {
        for status in TodoStatus::ALL {
            assert_eq!(todo_status_from(todo_status_to(status)), status);
        }
    }

    #[test]
    fn a_todo_maps_with_its_run_and_steps() {
        let mut todo = Todo::new(
            "Retry",
            "n",
            None,
            kumo_domain::time::Timestamp::from_unix_nanos(5_000_000),
        )
        .unwrap();
        todo.run = Some(TodoRun {
            branch: "fix/retry".into(),
            worktree_path: "/wt/x".into(),
            pr_number: 3,
            ..TodoRun::default()
        });
        todo.steps.push(TodoStep {
            status: TodoStatus::Review,
            by: "Claude Code".into(),
            at: kumo_domain::time::Timestamp::from_unix_nanos(9_000_000),
            note: "ok".into(),
        });
        let pb = todo_to(&todo);
        assert_eq!(pb.status, pb::TodoStatus::Review as i32);
        assert!(pb.run.is_some());
        assert_eq!(pb.run.as_ref().unwrap().branch, "fix/retry");
        assert_eq!(pb.created_unix_ms, 5);
        assert_eq!(pb.steps[0].at_unix_ms, 9);
        assert_eq!(pb.repo_path, "");
        let back = todo_run_from(pb.run.unwrap());
        assert_eq!(back, todo.run.unwrap());
    }
}
