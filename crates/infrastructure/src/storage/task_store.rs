use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, MutexGuard, PoisonError};

use kumo_domain::tasks::{
    Priority, SourceId, SourceKind, SourceOptions, Task, TaskError, TaskId, TaskLink, TaskSource,
    TaskStatus, TaskStore,
};
use kumo_domain::time::Timestamp;
use rusqlite::{Connection, Row, params};

use super::migrations;

/// [`TaskStore`] on the same SQLite file as the workspace: the cache the
/// Tasks view is served from.
#[derive(Debug)]
pub struct SqliteTaskStore {
    conn: Mutex<Connection>,
}

impl SqliteTaskStore {
    pub fn open(path: &Path) -> Result<Self, TaskError> {
        Self::init(Connection::open(path).map_err(store_error)?)
    }

    pub fn in_memory() -> Result<Self, TaskError> {
        Self::init(Connection::open_in_memory().map_err(store_error)?)
    }

    fn init(mut conn: Connection) -> Result<Self, TaskError> {
        conn.execute_batch("PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL;")
            .map_err(store_error)?;
        migrations::migrate(&mut conn).map_err(store_error)?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    fn lock(&self) -> MutexGuard<'_, Connection> {
        self.conn.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

impl TaskStore for SqliteTaskStore {
    fn sources(&self) -> Result<Vec<TaskSource>, TaskError> {
        let conn = self.lock();
        let mut stmt = conn
            .prepare_cached(
                "SELECT id, kind, name, options, enabled FROM task_sources ORDER BY position",
            )
            .map_err(store_error)?;
        let rows = stmt
            .query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, String>(3)?,
                    row.get::<_, bool>(4)?,
                ))
            })
            .and_then(Iterator::collect::<Result<Vec<_>, _>>)
            .map_err(store_error)?;
        rows.into_iter()
            .filter_map(|(id, kind, name, options, enabled)| {
                // Rows written by a newer Kumo with kinds this one doesn't know.
                let kind = SourceKind::from_id(&kind)?;
                Some(source_from(id, kind, name, &options, enabled))
            })
            .collect()
    }

    fn save_source(&self, source: &TaskSource) -> Result<(), TaskError> {
        let options = serde_json::to_string(&source.options.to_map()).map_err(store_error)?;
        self.lock()
            .execute(
                "INSERT INTO task_sources (id, kind, name, options, enabled, position)
                 VALUES (?1, ?2, ?3, ?4, ?5, (SELECT COALESCE(MAX(position), 0) + 1 FROM task_sources))
                 ON CONFLICT(id) DO UPDATE SET name = excluded.name, options = excluded.options,
                     enabled = excluded.enabled",
                params![
                    source.id.as_str(),
                    source.kind().id(),
                    source.name,
                    options,
                    source.enabled
                ],
            )
            .map(drop)
            .map_err(store_error)
    }

    fn delete_source(&self, id: &SourceId) -> Result<(), TaskError> {
        self.lock()
            .execute("DELETE FROM task_sources WHERE id = ?1", [id.as_str()])
            .map(drop)
            .map_err(store_error)
    }

    fn tasks(&self, source: &SourceId) -> Result<Vec<Task>, TaskError> {
        let conn = self.lock();
        let mut stmt = conn
            .prepare_cached(
                "SELECT external_id, key, ticket, title, status, priority, due, url, context, labels, updated
                 FROM tasks WHERE source_id = ?1 ORDER BY position",
            )
            .map_err(store_error)?;
        stmt.query_map([source.as_str()], |row| task_from(source, row))
            .and_then(Iterator::collect)
            .map_err(store_error)
    }

    fn replace_tasks(&self, source: &SourceId, tasks: &[Task]) -> Result<(), TaskError> {
        let mut conn = self.lock();
        let tx = conn.transaction().map_err(store_error)?;
        tx.execute("DELETE FROM tasks WHERE source_id = ?1", [source.as_str()])
            .map_err(store_error)?;
        {
            let mut insert = tx
                .prepare_cached(
                    "INSERT OR REPLACE INTO tasks (source_id, external_id, key, ticket, title, status, priority,
                         due, url, context, labels, updated, position)
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)",
                )
                .map_err(store_error)?;
            for (position, task) in (0_i64..).zip(tasks) {
                let labels = serde_json::to_string(&task.labels).map_err(store_error)?;
                insert
                    .execute(params![
                        source.as_str(),
                        task.id.external(),
                        task.key,
                        task.ticket,
                        task.title,
                        status_code(task.status),
                        priority_code(task.priority),
                        task.due,
                        task.url,
                        task.context,
                        labels,
                        task.updated.map(|t| nanos_to_sql(t.as_unix_nanos())),
                        position,
                    ])
                    .map_err(store_error)?;
            }
        }
        tx.commit().map_err(store_error)
    }

    fn links(&self) -> Result<Vec<TaskLink>, TaskError> {
        let conn = self.lock();
        let mut stmt = conn
            .prepare_cached(
                "SELECT task_id, worktree, branch, created FROM task_links ORDER BY created",
            )
            .map_err(store_error)?;
        let rows = stmt
            .query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, i64>(3)?,
                ))
            })
            .and_then(Iterator::collect::<Result<Vec<_>, _>>)
            .map_err(store_error)?;
        Ok(rows
            .into_iter()
            .filter_map(|(task, worktree, branch, created)| {
                Some(TaskLink {
                    task: TaskId::parse(&task).ok()?,
                    worktree: PathBuf::from(worktree),
                    branch,
                    created: Timestamp::from_unix_nanos(nanos_from_sql(created)),
                })
            })
            .collect())
    }

    fn save_link(&self, link: &TaskLink) -> Result<(), TaskError> {
        self.lock()
            .execute(
                "INSERT INTO task_links (task_id, worktree, branch, created) VALUES (?1, ?2, ?3, ?4)
                 ON CONFLICT(task_id, worktree) DO UPDATE SET branch = excluded.branch",
                params![
                    link.task.as_str(),
                    link.worktree.to_string_lossy(),
                    link.branch,
                    nanos_to_sql(link.created.as_unix_nanos())
                ],
            )
            .map(drop)
            .map_err(store_error)
    }

    fn delete_link(&self, link: &TaskLink) -> Result<(), TaskError> {
        self.lock()
            .execute(
                "DELETE FROM task_links WHERE task_id = ?1 AND worktree = ?2",
                params![link.task.as_str(), link.worktree.to_string_lossy()],
            )
            .map(drop)
            .map_err(store_error)
    }
}

fn source_from(
    id: String,
    kind: SourceKind,
    name: String,
    options: &str,
    enabled: bool,
) -> Result<TaskSource, TaskError> {
    let map: BTreeMap<String, String> = serde_json::from_str(options).map_err(store_error)?;
    Ok(TaskSource {
        id: SourceId::parse(&id)?,
        name,
        options: SourceOptions::from_map(kind, &map)?,
        enabled,
    })
}

fn task_from(source: &SourceId, row: &Row<'_>) -> rusqlite::Result<Task> {
    let labels: String = row.get(9)?;
    Ok(Task {
        id: TaskId::new(source, &row.get::<_, String>(0)?),
        key: row.get(1)?,
        ticket: row.get(2)?,
        title: row.get(3)?,
        status: status_from(row.get(4)?),
        priority: priority_from(row.get(5)?),
        due: row.get(6)?,
        url: row.get(7)?,
        context: row.get(8)?,
        labels: serde_json::from_str(&labels).unwrap_or_default(),
        updated: row
            .get::<_, Option<i64>>(10)?
            .map(|n| Timestamp::from_unix_nanos(nanos_from_sql(n))),
    })
}

fn status_code(status: TaskStatus) -> i64 {
    match status {
        TaskStatus::Todo => 0,
        TaskStatus::Doing => 1,
        TaskStatus::Review => 2,
        TaskStatus::Done => 3,
    }
}

fn status_from(code: i64) -> TaskStatus {
    match code {
        1 => TaskStatus::Doing,
        2 => TaskStatus::Review,
        3 => TaskStatus::Done,
        _ => TaskStatus::Todo,
    }
}

fn priority_code(priority: Priority) -> i64 {
    match priority {
        Priority::None => 0,
        Priority::Low => 1,
        Priority::Medium => 2,
        Priority::High => 3,
        Priority::Urgent => 4,
    }
}

fn priority_from(code: i64) -> Priority {
    match code {
        1 => Priority::Low,
        2 => Priority::Medium,
        3 => Priority::High,
        4 => Priority::Urgent,
        _ => Priority::None,
    }
}

fn nanos_to_sql(nanos: u64) -> i64 {
    i64::try_from(nanos).unwrap_or(i64::MAX)
}

fn nanos_from_sql(nanos: i64) -> u64 {
    u64::try_from(nanos).unwrap_or(0)
}

fn store_error(error: impl std::fmt::Display) -> TaskError {
    TaskError::Store(error.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn source(id: &str, vault: &str) -> TaskSource {
        TaskSource {
            id: SourceId::parse(id).unwrap(),
            name: "Vault".into(),
            options: SourceOptions::Obsidian {
                vault: vault.into(),
            },
            enabled: true,
        }
    }

    fn task(source: &SourceId, external: &str, title: &str) -> Task {
        Task {
            id: TaskId::new(source, external),
            key: "Inbox".into(),
            ticket: Some("PRC-1".into()),
            title: title.into(),
            status: TaskStatus::Review,
            priority: Priority::High,
            due: Some("2026-11-02".into()),
            url: Some("obsidian://open".into()),
            context: "notes".into(),
            labels: vec!["work".into(), "q4".into()],
            updated: Some(Timestamp::from_unix_nanos(1_700_000_000_000_000_000)),
        }
    }

    #[test]
    fn round_trips_sources_tasks_and_links() {
        let store = SqliteTaskStore::in_memory().unwrap();
        let a = source("a", "/vault");
        store.save_source(&a).unwrap();
        store.save_source(&source("b", "/other")).unwrap();
        let renamed = TaskSource {
            name: "Notes".into(),
            ..a.clone()
        };
        store.save_source(&renamed).unwrap();
        let sources = store.sources().unwrap();
        assert_eq!(sources.len(), 2);
        assert_eq!(sources[0], renamed, "keeps its place when updated");

        let tasks = vec![task(&a.id, "n.md#1", "One"), task(&a.id, "n.md#2", "Two")];
        store.replace_tasks(&a.id, &tasks).unwrap();
        assert_eq!(store.tasks(&a.id).unwrap(), tasks);
        store.replace_tasks(&a.id, &tasks[1..]).unwrap();
        assert_eq!(store.tasks(&a.id).unwrap(), &tasks[1..]);

        let link = TaskLink {
            task: tasks[1].id.clone(),
            worktree: "/wt/x".into(),
            branch: "feat/x".into(),
            created: Timestamp::from_unix_nanos(5),
        };
        store.save_link(&link).unwrap();
        store
            .save_link(&TaskLink {
                branch: "feat/y".into(),
                ..link.clone()
            })
            .unwrap();
        assert_eq!(store.links().unwrap().len(), 1);
        assert_eq!(store.links().unwrap()[0].branch, "feat/y");
        store.delete_link(&link).unwrap();
        assert!(store.links().unwrap().is_empty());

        store.delete_source(&a.id).unwrap();
        assert!(store.tasks(&a.id).unwrap().is_empty(), "tasks go with it");
        assert_eq!(store.sources().unwrap().len(), 1);
    }
}
