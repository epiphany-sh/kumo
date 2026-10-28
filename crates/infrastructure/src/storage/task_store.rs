use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, MutexGuard, PoisonError};

use kumo_domain::tasks::{
    Points, Progress, SourceId, SourceKind, SourceOptions, Task, TaskDetail, TaskError, TaskId,
    TaskLink, TaskSource, TaskStore,
};
use kumo_domain::time::Timestamp;
use rusqlite::{Connection, OptionalExtension, Row, params};

use super::migrations;
use super::task_json::{
    PersonJson, SprintJson, TaskRefJson, detail_from_json, detail_to_json, priority_code,
    priority_from, relations_from, relations_to, status_code, status_from, type_code, type_from,
};

/// Details nobody opened for this long are dropped from the cache.
const DETAIL_KEPT_FOR_NANOS: u64 = 30 * 24 * 3600 * 1_000_000_000;

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
                "SELECT external_id, key, ticket, title, status, priority, due, url, context, labels, updated,
                     kind, type_name, source_status, assignee, relations, mine, points, subtasks_done,
                     subtasks_total, comment_count, parent, blocked, sprint
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
                         due, url, context, labels, updated, position, kind, type_name, source_status,
                         assignee, relations, mine, points, subtasks_done, subtasks_total, comment_count,
                         parent, blocked, sprint)
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17,
                         ?18, ?19, ?20, ?21, ?22, ?23, ?24, ?25, ?26)",
                )
                .map_err(store_error)?;
            for (position, task) in (0_i64..).zip(tasks) {
                let labels = serde_json::to_string(&task.labels).map_err(store_error)?;
                let assignee = task
                    .assignee
                    .as_ref()
                    .map(|p| serde_json::to_string(&PersonJson::to(p)))
                    .transpose()
                    .map_err(store_error)?;
                let parent = task
                    .parent
                    .as_ref()
                    .map(|r| serde_json::to_string(&TaskRefJson::to(r)))
                    .transpose()
                    .map_err(store_error)?;
                let sprint = task
                    .sprint
                    .as_ref()
                    .map(|s| serde_json::to_string(&SprintJson::to(s)))
                    .transpose()
                    .map_err(store_error)?;
                let relations =
                    serde_json::to_string(&relations_to(&task.relations)).map_err(store_error)?;
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
                        type_code(task.kind),
                        task.type_name,
                        task.source_status,
                        assignee,
                        relations,
                        task.mine,
                        task.points.map(Points::hundredths),
                        task.subtasks.done,
                        task.subtasks.total,
                        task.comment_count,
                        parent,
                        task.blocked,
                        sprint,
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

    fn detail(&self, id: &TaskId) -> Result<Option<TaskDetail>, TaskError> {
        let source = id.source();
        let row: Option<(String, i64)> = self
            .lock()
            .query_row(
                "SELECT detail, fetched FROM task_details WHERE source_id = ?1 AND external_id = ?2",
                params![source.as_str(), id.external()],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .optional()
            .map_err(store_error)?;
        Ok(row.and_then(|(json, fetched)| {
            let fetched = Timestamp::from_unix_nanos(nanos_from_sql(fetched));
            // Unreadable (written by another version): as if there were none.
            detail_from_json(&source, &json, fetched)
                .inspect_err(
                    |error| tracing::debug!(%error, task = %id, "dropping a cached task detail"),
                )
                .ok()
        }))
    }

    fn save_detail(&self, detail: &TaskDetail) -> Result<(), TaskError> {
        let json = detail_to_json(detail).map_err(store_error)?;
        let id = &detail.task.id;
        let fetched = detail.fetched.as_unix_nanos();
        let mut conn = self.lock();
        let tx = conn.transaction().map_err(store_error)?;
        tx.execute(
            "INSERT INTO task_details (source_id, external_id, detail, fetched) VALUES (?1, ?2, ?3, ?4)
             ON CONFLICT(source_id, external_id) DO UPDATE SET detail = excluded.detail,
                 fetched = excluded.fetched",
            params![
                id.source().as_str(),
                id.external(),
                json,
                nanos_to_sql(fetched)
            ],
        )
        .map_err(store_error)?;
        tx.execute(
            "DELETE FROM task_details WHERE fetched < ?1",
            [nanos_to_sql(fetched.saturating_sub(DETAIL_KEPT_FOR_NANOS))],
        )
        .map_err(store_error)?;
        tx.commit().map_err(store_error)
    }

    fn delete_details(&self, source: &SourceId) -> Result<(), TaskError> {
        self.lock()
            .execute(
                "DELETE FROM task_details WHERE source_id = ?1",
                [source.as_str()],
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
    let relations: String = row.get(15)?;
    let json = |at: usize| -> rusqlite::Result<Option<String>> { row.get(at) };
    Ok(Task {
        key: row.get(1)?,
        ticket: row.get(2)?,
        status: status_from(row.get(4)?),
        priority: priority_from(row.get(5)?),
        due: row.get(6)?,
        url: row.get(7)?,
        context: row.get(8)?,
        labels: serde_json::from_str(&labels).unwrap_or_default(),
        updated: row
            .get::<_, Option<i64>>(10)?
            .map(|n| Timestamp::from_unix_nanos(nanos_from_sql(n))),
        kind: type_from(row.get(11)?),
        type_name: row.get(12)?,
        source_status: row.get(13)?,
        assignee: json(14)?
            .and_then(|j| serde_json::from_str::<PersonJson>(&j).ok())
            .map(PersonJson::into_person),
        relations: relations_from(
            &serde_json::from_str::<Vec<i64>>(&relations).unwrap_or_default(),
        ),
        mine: row.get(16)?,
        points: row.get::<_, Option<u32>>(17)?.map(Points::from_hundredths),
        subtasks: Progress {
            done: row.get(18)?,
            total: row.get(19)?,
        },
        comment_count: row.get(20)?,
        parent: json(21)?
            .and_then(|j| serde_json::from_str::<TaskRefJson>(&j).ok())
            .map(TaskRefJson::into_ref),
        blocked: row.get(22)?,
        sprint: json(23)?
            .and_then(|j| serde_json::from_str::<SprintJson>(&j).ok())
            .map(SprintJson::into_sprint),
        ..Task::new(
            TaskId::new(source, &row.get::<_, String>(0)?),
            row.get::<_, String>(3)?,
        )
    })
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
    use kumo_domain::tasks::{
        Attachment, Comment, LinkKind, LinkedTask, Person, Priority, Sprint, SprintState, TaskRef,
        TaskStatus, TaskType, TimeTracking,
    };

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
        let parent = TaskRef {
            id: Some(TaskId::new(source, "PRC-1")),
            kind: TaskType::Epic,
            source_status: "In Progress".into(),
            status: TaskStatus::Doing,
            color: "violet".into(),
            url: Some("https://x/browse/PRC-1".into()),
            ..TaskRef::new("PRC-1", "Graviton")
        };
        Task {
            key: "Inbox".into(),
            ticket: Some("PRC-1".into()),
            status: TaskStatus::Review,
            priority: Priority::High,
            due: Some("2026-11-02".into()),
            url: Some("obsidian://open".into()),
            context: "notes".into(),
            labels: vec!["work".into(), "q4".into()],
            updated: Some(Timestamp::from_unix_nanos(1_700_000_000_000_000_000)),
            kind: TaskType::Story,
            type_name: "Story".into(),
            source_status: "Code Review".into(),
            points: Points::from_f64(2.5),
            subtasks: Progress { done: 2, total: 4 },
            comment_count: 6,
            parent: Some(parent),
            blocked: true,
            sprint: Some(Sprint {
                name: "Pricing 2026.22".into(),
                state: SprintState::Active,
                start: Some(Timestamp::from_unix_nanos(1)),
                end: None,
            }),
            ..Task::new(TaskId::new(source, external), title)
        }
        .assigned_to(Some(Person::new("acc-1", "Mauri", true)))
    }

    fn detail(task: Task, fetched: u64) -> TaskDetail {
        let theirs = Person::new("acc-2", "Ana Gómez", false);
        TaskDetail {
            reporter: Some(theirs.clone()),
            created: Some(Timestamp::from_unix_nanos(7)),
            description: "## Contexto\n- [x] uno".into(),
            acceptance_criteria: "- [ ] dos".into(),
            subtasks: vec![TaskRef {
                assignee: Some(theirs.clone()),
                ..TaskRef::new("PRC-2", "Sub")
            }],
            links: vec![LinkedTask {
                kind: LinkKind::BlockedBy,
                relation: "is blocked by".into(),
                task: TaskRef::new("PRC-3", "Blocker"),
            }],
            attachments: vec![Attachment {
                name: "a.png".into(),
                kind: "PNG image".into(),
                size_bytes: 412,
                url: Some("https://x/a.png".into()),
            }],
            comments: vec![Comment {
                author: Some(theirs),
                created: Some(Timestamp::from_unix_nanos(9)),
                body: "**ok**".into(),
            }],
            components: vec!["price-admin".into()],
            fix_versions: vec!["2026.11".into()],
            time_tracking: Some(TimeTracking {
                estimate: "3d".into(),
                estimate_seconds: 86_400,
                ..TimeTracking::default()
            }),
            location: "Weekly.md · line 3".into(),
            fetched: Timestamp::from_unix_nanos(fetched),
            stale: None,
            ..TaskDetail::basic(task)
        }
    }

    #[test]
    fn caches_details_until_their_source_goes() {
        let store = SqliteTaskStore::in_memory().unwrap();
        let a = source("a", "/vault");
        store.save_source(&a).unwrap();
        let now = Timestamp::now().as_unix_nanos();
        let first = detail(task(&a.id, "PRC-9", "Nine"), now);
        assert_eq!(store.detail(&first.task.id).unwrap(), None);
        store.save_detail(&first).unwrap();
        assert_eq!(store.detail(&first.task.id).unwrap(), Some(first.clone()));

        let again = TaskDetail {
            description: "changed".into(),
            ..first.clone()
        };
        store.save_detail(&again).unwrap();
        assert_eq!(store.detail(&first.task.id).unwrap(), Some(again));

        // Saving prunes details nobody opened in a month.
        let old = detail(task(&a.id, "PRC-8", "Old"), 1);
        store.save_detail(&old).unwrap();
        store.save_detail(&first).unwrap();
        assert_eq!(store.detail(&old.task.id).unwrap(), None);

        store.delete_details(&a.id).unwrap();
        assert_eq!(store.detail(&first.task.id).unwrap(), None);
        store.save_detail(&first).unwrap();
        store.delete_source(&a.id).unwrap();
        assert_eq!(
            store.detail(&first.task.id).unwrap(),
            None,
            "goes with its source"
        );
    }

    #[test]
    fn upgrades_a_cache_written_before_rich_cards() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("kumo.db");
        {
            let conn = Connection::open(&path).unwrap();
            // Schema step 3, as the previous version left it.
            let steps = migrations::steps();
            for step in &steps[..3] {
                conn.execute_batch(step).unwrap();
            }
            conn.pragma_update(None, "user_version", 3).unwrap();
            conn.execute_batch(
                "INSERT INTO task_sources VALUES ('a', 'obsidian', 'V', '{\"vault\":\"/v\"}', 1, 1);
                 INSERT INTO tasks VALUES ('a', 'n.md#1', 'n', NULL, 'Old one', 0, 0, NULL, NULL, '', '[]', NULL, 0);",
            )
            .unwrap();
        }
        let store = SqliteTaskStore::open(&path).unwrap();
        let tasks = store.tasks(&SourceId::parse("a").unwrap()).unwrap();
        assert_eq!(tasks.len(), 1);
        assert_eq!(tasks[0].title, "Old one");
        assert_eq!((tasks[0].kind, tasks[0].mine), (TaskType::Unknown, false));
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
