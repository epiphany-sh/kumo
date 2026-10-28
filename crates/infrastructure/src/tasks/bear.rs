//! Bear: checkboxes in its notes, read (only read: Bear has no safe way to
//! change one line of a note) from its local database.

use std::path::{Path, PathBuf};

use kumo_domain::tasks::{
    Checkbox, Detected, SourceId, SourceKind, SourceOptions, Task, TaskConnector, TaskDetail,
    TaskError, TaskId, TaskSource, TaskStatus, parse_checkboxes, section_around,
};
use kumo_domain::time::Timestamp;
use rusqlite::{Connection, OpenFlags};

/// Core Data dates count from 2001-01-01.
const CORE_DATA_EPOCH: i64 = 978_307_200;

#[derive(Debug)]
pub struct BearConnector {
    home: PathBuf,
}

impl BearConnector {
    pub fn new(home: impl Into<PathBuf>) -> Self {
        Self { home: home.into() }
    }

    fn default_database(&self) -> PathBuf {
        self.home.join(
            "Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite",
        )
    }

    fn database(&self, source: &TaskSource) -> Result<PathBuf, TaskError> {
        match &source.options {
            SourceOptions::Bear { database } => {
                Ok(database.clone().unwrap_or_else(|| self.default_database()))
            }
            _ => Err(TaskError::Invalid("not a Bear source".into())),
        }
    }
}

impl TaskConnector for BearConnector {
    fn kind(&self) -> SourceKind {
        SourceKind::Bear
    }

    fn fetch(&self, source: &TaskSource, _secret: Option<&str>) -> Result<Vec<Task>, TaskError> {
        let database = self.database(source)?;
        let notes = read_notes(&database, None)?;
        Ok(notes
            .iter()
            .flat_map(|note| {
                parse_checkboxes(&note.text)
                    .into_iter()
                    .map(|b| to_task(&source.id, note, b))
                    .collect::<Vec<_>>()
            })
            .collect())
    }

    /// The checkbox with the section of the note it's in.
    fn detail(
        &self,
        source: &TaskSource,
        _secret: Option<&str>,
        id: &TaskId,
        _known: Option<&Task>,
    ) -> Result<TaskDetail, TaskError> {
        let database = self.database(source)?;
        let (note_id, checkbox) = id
            .external()
            .rsplit_once('#')
            .ok_or_else(|| TaskError::UnknownTask(id.to_string()))?;
        let note = read_notes(&database, Some(note_id))?
            .pop()
            .ok_or_else(|| TaskError::UnknownTask(id.to_string()))?;
        let found = parse_checkboxes(&note.text)
            .into_iter()
            .find(|b| b.id == checkbox)
            .ok_or_else(|| TaskError::UnknownTask(id.to_string()))?;
        let (line, description) = (found.line, section_around(&note.text, found.line));
        Ok(TaskDetail {
            description,
            location: format!("{} · line {}", note.title, line + 1),
            ..TaskDetail::basic(to_task(&source.id, &note, found))
        })
    }

    fn set_status(
        &self,
        _source: &TaskSource,
        _secret: Option<&str>,
        _task: &Task,
        status: TaskStatus,
    ) -> Result<(), TaskError> {
        Err(TaskError::Unsupported {
            kind: SourceKind::Bear,
            status,
        })
    }

    fn test(&self, source: &TaskSource, secret: Option<&str>) -> Result<String, TaskError> {
        let tasks = self.fetch(source, secret)?;
        let open = tasks
            .iter()
            .filter(|t| t.status != TaskStatus::Done)
            .count();
        Ok(format!("{open} open tasks, {} in total", tasks.len()))
    }

    fn watched_paths(&self, source: &TaskSource) -> Vec<PathBuf> {
        // The database and its WAL change together: watch their folder.
        self.database(source)
            .ok()
            .and_then(|db| db.parent().map(Path::to_owned))
            .into_iter()
            .collect()
    }

    fn detect(&self) -> Vec<Detected> {
        if self.default_database().is_file() {
            vec![Detected {
                name: "Bear".into(),
                options: SourceOptions::Bear { database: None },
            }]
        } else {
            vec![]
        }
    }
}

fn to_task(source: &SourceId, note: &Note, b: Checkbox) -> Task {
    let updated = note.modified.and_then(|seconds| {
        let unix = (seconds + CORE_DATA_EPOCH as f64) * 1e9;
        (unix >= 0.0).then(|| Timestamp::from_unix_nanos(unix as u64))
    });
    Task {
        key: note.title.clone(),
        status: b.status,
        priority: b.priority,
        due: b.due,
        url: Some(format!("bear://x-callback-url/open-note?id={}", note.id)),
        labels: b.tags,
        updated,
        ..Task::new(
            TaskId::new(source, &format!("{}#{}", note.id, b.id)),
            b.title,
        )
    }
    .personal()
}

struct Note {
    id: String,
    title: String,
    text: String,
    /// Seconds since 2001-01-01.
    modified: Option<f64>,
}

/// Notes that aren't trashed, archived, deleted or encrypted (only `only`,
/// when given). Columns are checked first: Bear's schema is its own and
/// changes between versions.
fn read_notes(database: &Path, only: Option<&str>) -> Result<Vec<Note>, TaskError> {
    if !database.is_file() {
        return Err(TaskError::Unavailable(format!(
            "Bear's database isn't at {}: is Bear installed?",
            database.display()
        )));
    }
    let conn = Connection::open_with_flags(
        database,
        OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
    )
    .map_err(|e| denied_or_unavailable(&e))?;
    conn.busy_timeout(std::time::Duration::from_secs(2))
        .map_err(|e| denied_or_unavailable(&e))?;
    let columns: Vec<String> = conn
        .prepare("SELECT name FROM pragma_table_info('ZSFNOTE')")
        .and_then(|mut stmt| stmt.query_map([], |row| row.get(0))?.collect())
        .map_err(|e| denied_or_unavailable(&e))?;
    let has = |name: &str| columns.iter().any(|c| c == name);
    if !(has("ZTEXT") && has("ZTITLE") && has("ZUNIQUEIDENTIFIER")) {
        return Err(TaskError::Source(
            "this version of Bear stores notes differently: Kumo can't read them yet".into(),
        ));
    }
    let hidden = ["ZTRASHED", "ZARCHIVED", "ZPERMANENTLYDELETED", "ZENCRYPTED"]
        .into_iter()
        .filter(|c| has(c))
        .map(|c| format!(" AND COALESCE({c}, 0) = 0"))
        .collect::<String>();
    let modified = if has("ZMODIFICATIONDATE") {
        "ZMODIFICATIONDATE"
    } else {
        "NULL"
    };
    let one = if only.is_some() {
        " AND ZUNIQUEIDENTIFIER = ?1"
    } else {
        ""
    };
    let sql = format!(
        "SELECT ZUNIQUEIDENTIFIER, COALESCE(ZTITLE, ''), ZTEXT, {modified} FROM ZSFNOTE
         WHERE ZTEXT LIKE '%[%]%' AND ZUNIQUEIDENTIFIER IS NOT NULL{hidden}{one}
         ORDER BY {modified} DESC"
    );
    let params: Vec<&str> = only.into_iter().collect();
    conn.prepare(&sql)
        .and_then(|mut stmt| {
            stmt.query_map(rusqlite::params_from_iter(params), |row| {
                Ok(Note {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    text: row.get(2)?,
                    modified: row.get(3)?,
                })
            })?
            .collect()
        })
        .map_err(|e| denied_or_unavailable(&e))
}

fn denied_or_unavailable(error: &rusqlite::Error) -> TaskError {
    let message = error.to_string();
    if message.contains("authorization denied") || message.contains("unable to open") {
        TaskError::Auth(
            "macOS didn't let Kumo read Bear's notes: allow it in System Settings › Privacy & Security".into(),
        )
    } else {
        TaskError::Unavailable(format!("can't read Bear's notes: {message}"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use kumo_domain::tasks::SourceId;

    fn bear_db(path: &Path) {
        let conn = Connection::open(path).unwrap();
        conn.execute_batch(
            "CREATE TABLE ZSFNOTE (Z_PK INTEGER PRIMARY KEY, ZTITLE TEXT, ZTEXT TEXT,
                 ZUNIQUEIDENTIFIER TEXT, ZTRASHED INTEGER, ZARCHIVED INTEGER, ZENCRYPTED INTEGER,
                 ZMODIFICATIONDATE REAL);
             INSERT INTO ZSFNOTE VALUES (1, 'Groceries', '# Groceries\n- [ ] Milk #home\n- [x] Bread', 'N-1', 0, 0, 0, 783000000);
             INSERT INTO ZSFNOTE VALUES (2, 'Trash', '- [ ] gone', 'N-2', 1, 0, 0, 783000001);
             INSERT INTO ZSFNOTE VALUES (3, 'Old', '- [ ] archived', 'N-3', 0, 1, 0, 783000002);
             INSERT INTO ZSFNOTE VALUES (4, 'Secret', '- [ ] locked', 'N-4', 0, 0, 1, 783000003);
             INSERT INTO ZSFNOTE VALUES (5, 'Plain', 'no tasks here', 'N-5', 0, 0, 0, 783000004);",
        )
        .unwrap();
    }

    #[test]
    fn reads_checkboxes_of_visible_notes() {
        let dir = tempfile::tempdir().unwrap();
        let db = dir.path().join("database.sqlite");
        bear_db(&db);
        let source = TaskSource {
            id: SourceId::parse("br").unwrap(),
            name: "Bear".into(),
            options: SourceOptions::Bear {
                database: Some(db.clone()),
            },
            enabled: true,
        };
        let connector = BearConnector::new(dir.path());
        let tasks = connector.fetch(&source, None).unwrap();
        let summary: Vec<_> = tasks
            .iter()
            .map(|t| (t.key.as_str(), t.title.as_str(), t.status))
            .collect();
        assert_eq!(
            summary,
            [
                ("Groceries", "Milk", TaskStatus::Todo),
                ("Groceries", "Bread", TaskStatus::Done)
            ]
        );
        assert_eq!(tasks[0].labels, ["home"]);
        assert_eq!(
            tasks[0].url.as_deref(),
            Some("bear://x-callback-url/open-note?id=N-1")
        );
        assert_eq!(
            tasks[0].updated.unwrap().as_unix_nanos() / 1_000_000_000,
            1_761_307_200
        );
        assert!(matches!(
            connector.set_status(&source, None, &tasks[0], TaskStatus::Done),
            Err(TaskError::Unsupported { .. })
        ));
        assert_eq!(connector.watched_paths(&source), [dir.path().to_owned()]);
        assert!(tasks.iter().all(|t| t.mine));

        let detail = connector.detail(&source, None, &tasks[1].id, None).unwrap();
        assert_eq!(detail.location, "Groceries · line 3");
        assert_eq!(
            detail.description,
            "# Groceries\n- [ ] Milk #home\n- [x] Bread"
        );
        assert_eq!(detail.task, tasks[1]);
        let trashed = TaskId::new(&source.id, "N-2#x");
        assert!(matches!(
            connector.detail(&source, None, &trashed, None),
            Err(TaskError::UnknownTask(_))
        ));
    }

    #[test]
    fn explains_a_missing_database() {
        let dir = tempfile::tempdir().unwrap();
        let connector = BearConnector::new(dir.path());
        let source = TaskSource {
            id: SourceId::parse("br").unwrap(),
            name: "Bear".into(),
            options: SourceOptions::Bear { database: None },
            enabled: true,
        };
        assert!(matches!(
            connector.fetch(&source, None),
            Err(TaskError::Unavailable(_))
        ));
        assert!(connector.detect().is_empty());
    }
}
