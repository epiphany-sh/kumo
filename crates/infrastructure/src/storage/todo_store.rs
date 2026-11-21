//! The user's TODOs, next to the rest of the profile's data in `kumo.db`.

use std::path::{Path, PathBuf};
use std::sync::{Mutex, PoisonError};

use kumo_domain::time::Timestamp;
use kumo_domain::todos::{Todo, TodoError, TodoId, TodoRun, TodoStatus, TodoStep, TodoStore};
use rusqlite::{Connection, params};
use serde_json::{Value, json};

use super::migrations;

/// [`TodoStore`] on a SQLite file.
#[derive(Debug)]
pub struct SqliteTodoStore {
    conn: Mutex<Connection>,
}

impl SqliteTodoStore {
    pub fn open(path: &Path) -> Result<Self, TodoError> {
        Self::init(Connection::open(path).map_err(store_error)?)
    }

    pub fn in_memory() -> Result<Self, TodoError> {
        Self::init(Connection::open_in_memory().map_err(store_error)?)
    }

    fn init(mut conn: Connection) -> Result<Self, TodoError> {
        conn.execute_batch("PRAGMA journal_mode = WAL;")
            .map_err(store_error)?;
        conn.busy_timeout(std::time::Duration::from_secs(2))
            .map_err(store_error)?;
        migrations::migrate(&mut conn).map_err(store_error)?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, Connection> {
        self.conn.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

impl TodoStore for SqliteTodoStore {
    fn todos(&self) -> Result<Vec<Todo>, TodoError> {
        let conn = self.lock();
        let mut stmt = conn
            .prepare("SELECT id, title, notes, repo_path, done, created, run, steps FROM todos ORDER BY created DESC")
            .map_err(store_error)?;
        let rows = stmt
            .query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, Option<String>>(3)?,
                    row.get::<_, bool>(4)?,
                    row.get::<_, i64>(5)?,
                    row.get::<_, Option<String>>(6)?,
                    row.get::<_, String>(7)?,
                ))
            })
            .map_err(store_error)?;
        let mut todos = Vec::new();
        for row in rows {
            let (id, title, notes, repo, done, created, run, steps) = row.map_err(store_error)?;
            // A row this build can't read is skipped, not fatal.
            let Ok(id) = TodoId::parse(&id) else { continue };
            todos.push(Todo {
                id,
                title,
                notes,
                repo_path: repo.filter(|r| !r.is_empty()).map(PathBuf::from),
                done,
                created: Timestamp::from_unix_nanos(u64::try_from(created).unwrap_or(0)),
                run: run.as_deref().and_then(run_from),
                steps: steps_from(&steps),
            });
        }
        Ok(todos)
    }

    fn save(&self, todo: &Todo) -> Result<(), TodoError> {
        let repo = todo.repo_path.as_ref().map(|p| p.display().to_string());
        let run = todo.run.as_ref().map(|r| run_to(r).to_string());
        let created = i64::try_from(todo.created.as_unix_nanos()).unwrap_or(i64::MAX);
        self.lock()
            .execute(
                "INSERT INTO todos (id, title, notes, repo_path, done, created, run, steps)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
                 ON CONFLICT (id) DO UPDATE SET
                    title = excluded.title, notes = excluded.notes, repo_path = excluded.repo_path,
                    done = excluded.done, run = excluded.run, steps = excluded.steps",
                params![
                    todo.id.as_str(),
                    todo.title,
                    todo.notes,
                    repo,
                    todo.done,
                    created,
                    run,
                    steps_to(&todo.steps).to_string()
                ],
            )
            .map_err(store_error)?;
        Ok(())
    }

    fn delete(&self, id: &TodoId) -> Result<(), TodoError> {
        self.lock()
            .execute("DELETE FROM todos WHERE id = ?1", params![id.as_str()])
            .map_err(store_error)?;
        Ok(())
    }
}

fn run_to(run: &TodoRun) -> Value {
    json!({
        "repo": run.repo_path.display().to_string(),
        "worktree": run.worktree_path.display().to_string(),
        "branch": run.branch,
        "base": run.base,
        "provider": run.provider_id,
        "agent": run.agent_name,
        "model": run.model,
        "effort": run.effort,
        "session": run.session_id,
        "pr": run.pr_number,
        "pr_url": run.pr_url,
    })
}

fn run_from(raw: &str) -> Option<TodoRun> {
    let v: Value = serde_json::from_str(raw).ok()?;
    let s = |k: &str| {
        v.get(k)
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_owned()
    };
    Some(TodoRun {
        repo_path: s("repo").into(),
        worktree_path: s("worktree").into(),
        branch: s("branch"),
        base: s("base"),
        provider_id: s("provider"),
        agent_name: s("agent"),
        model: s("model"),
        effort: s("effort"),
        session_id: s("session"),
        pr_number: v.get("pr").and_then(Value::as_u64).unwrap_or(0),
        pr_url: s("pr_url"),
    })
}

fn steps_to(steps: &[TodoStep]) -> Value {
    Value::Array(
        steps
            .iter()
            .map(|s| json!({ "status": s.status.word(), "by": s.by, "at": s.at.as_unix_nanos(), "note": s.note }))
            .collect(),
    )
}

fn steps_from(raw: &str) -> Vec<TodoStep> {
    let Ok(Value::Array(items)) = serde_json::from_str::<Value>(raw) else {
        return Vec::new();
    };
    items
        .iter()
        .filter_map(|v| {
            Some(TodoStep {
                status: TodoStatus::from_word(v.get("status")?.as_str()?)?,
                by: v
                    .get("by")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_owned(),
                at: Timestamp::from_unix_nanos(v.get("at").and_then(Value::as_u64).unwrap_or(0)),
                note: v
                    .get("note")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_owned(),
            })
        })
        .collect()
}

fn store_error(e: rusqlite::Error) -> TodoError {
    TodoError::Store(e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn todo(title: &str, at: u64) -> Todo {
        let mut t = Todo::new(
            title,
            "notes",
            Some("/code/repo-1".into()),
            Timestamp::from_unix_nanos(at),
        )
        .unwrap();
        t.run = Some(TodoRun {
            worktree_path: "/wt/repo-1/x".into(),
            branch: "fix/x".into(),
            agent_name: "Codex CLI".into(),
            model: "gpt-x".into(),
            effort: "high".into(),
            pr_number: 7,
            ..TodoRun::default()
        });
        t.steps = vec![TodoStep {
            status: TodoStatus::Testing,
            by: "Codex CLI".into(),
            at: Timestamp::from_unix_nanos(9),
            note: "12 of 48".into(),
        }];
        t
    }

    #[test]
    fn round_trips_newest_first() {
        let store = SqliteTodoStore::in_memory().unwrap();
        let old = todo("Old", 1);
        let new = todo("New", 2);
        store.save(&old).unwrap();
        store.save(&new).unwrap();
        let all = store.todos().unwrap();
        assert_eq!(all, vec![new.clone(), old.clone()]);

        let mut changed = old.clone();
        changed.done = true;
        changed.run = None;
        changed.steps.clear();
        store.save(&changed).unwrap();
        assert_eq!(store.todos().unwrap()[1], changed);

        store.delete(&new.id).unwrap();
        assert_eq!(store.todos().unwrap(), vec![changed]);
    }

    #[test]
    fn opens_a_database_from_before_todos() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("kumo.db");
        {
            let conn = Connection::open(&path).unwrap();
            conn.execute_batch(&migrations::steps()[..8].join(";\n"))
                .unwrap();
            conn.pragma_update(None, "user_version", 8).unwrap();
        }
        let store = SqliteTodoStore::open(&path).unwrap();
        store.save(&todo("Fresh", 1)).unwrap();
        assert_eq!(store.todos().unwrap().len(), 1);
    }
}
