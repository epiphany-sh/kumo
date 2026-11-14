//! The commands run in the terminals, next to the rest of the profile's
//! data in the same SQLite file.

use std::path::{Path, PathBuf};
use std::sync::{Mutex, PoisonError};
use std::time::Duration;

use kumo_domain::terminal::{
    CommandHistoryStore, CommandRun, HISTORY_LIMIT, HistoryEntry, HistoryError,
};
use kumo_domain::time::Timestamp;
use rusqlite::{Connection, params};

use super::migrations;

/// [`CommandHistoryStore`] on a SQLite file.
///
/// Opens the file for each call (one per command run, not per key): the
/// terminals that hold it may outlive their profile for a moment, and
/// Windows can't delete a profile's folder while a file in it is open.
#[derive(Debug)]
pub struct SqliteHistoryStore {
    db: Db,
    /// Most commands kept per repository.
    limit: usize,
}

#[derive(Debug)]
enum Db {
    File(PathBuf),
    Memory(Mutex<Connection>),
}

/// How long a call waits for another writer (the other stores share the
/// file).
const BUSY_WAIT: Duration = Duration::from_secs(2);

impl SqliteHistoryStore {
    /// Creates or migrates the database at `path`.
    pub fn open(path: &Path) -> Result<Self, HistoryError> {
        Self::prepare(&mut Connection::open(path).map_err(store_error)?)?;
        Ok(Self {
            db: Db::File(path.to_path_buf()),
            limit: HISTORY_LIMIT,
        })
    }

    pub fn in_memory() -> Result<Self, HistoryError> {
        let mut conn = Connection::open_in_memory().map_err(store_error)?;
        Self::prepare(&mut conn)?;
        Ok(Self {
            db: Db::Memory(Mutex::new(conn)),
            limit: HISTORY_LIMIT,
        })
    }

    fn prepare(conn: &mut Connection) -> Result<(), HistoryError> {
        conn.execute_batch("PRAGMA journal_mode = WAL;")
            .map_err(store_error)?;
        migrations::migrate(conn).map_err(store_error)
    }

    #[cfg(test)]
    fn with_limit(mut self, limit: usize) -> Self {
        self.limit = limit;
        self
    }

    fn with_conn<T>(
        &self,
        call: impl FnOnce(&mut Connection) -> rusqlite::Result<T>,
    ) -> Result<T, HistoryError> {
        match &self.db {
            Db::File(path) => {
                let mut conn = Connection::open(path).map_err(store_error)?;
                conn.busy_timeout(BUSY_WAIT).map_err(store_error)?;
                call(&mut conn).map_err(store_error)
            }
            Db::Memory(conn) => {
                call(&mut conn.lock().unwrap_or_else(PoisonError::into_inner)).map_err(store_error)
            }
        }
    }
}

/// The key a repository is kept under: its path, or '' outside one.
fn key(repo: Option<&Path>) -> String {
    repo.map(|r| r.display().to_string()).unwrap_or_default()
}

fn nanos(at: Timestamp) -> i64 {
    i64::try_from(at.as_unix_nanos()).unwrap_or(i64::MAX)
}

impl CommandHistoryStore for SqliteHistoryStore {
    fn record(&self, repo: Option<&Path>, run: &CommandRun) -> Result<(), HistoryError> {
        let repo = key(repo);
        let cwd = run.cwd.as_ref().map(|c| c.display().to_string());
        let limit = i64::try_from(self.limit).unwrap_or(i64::MAX);
        self.with_conn(|conn| {
            let tx = conn.transaction()?;
            tx.execute(
                "INSERT INTO command_history (repo, command, runs, last_run, last_exit, last_cwd)
                 VALUES (?1, ?2, 1, ?3, ?4, ?5)
                 ON CONFLICT (repo, command) DO UPDATE SET
                    runs = runs + 1,
                    last_run = MAX(last_run, excluded.last_run),
                    last_exit = excluded.last_exit,
                    last_cwd = excluded.last_cwd",
                params![repo, run.command, nanos(run.started_at), run.exit, cwd],
            )?;
            tx.execute(
                "DELETE FROM command_history WHERE repo = ?1 AND command IN (
                    SELECT command FROM command_history WHERE repo = ?1
                    ORDER BY last_run DESC LIMIT -1 OFFSET ?2)",
                params![repo, limit],
            )?;
            tx.commit()
        })
    }

    fn recent(&self, repo: Option<&Path>, limit: usize) -> Result<Vec<HistoryEntry>, HistoryError> {
        let repo = key(repo);
        let limit = i64::try_from(limit).unwrap_or(i64::MAX);
        self.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT command, runs, last_run, last_exit, last_cwd FROM command_history
                 WHERE repo = ?1 ORDER BY last_run DESC LIMIT ?2",
            )?;
            stmt.query_map(params![repo, limit], |row| {
                let last_run: i64 = row.get(2)?;
                let last_cwd: Option<String> = row.get(4)?;
                Ok(HistoryEntry {
                    command: row.get(0)?,
                    runs: row.get(1)?,
                    last_run: Timestamp::from_unix_nanos(u64::try_from(last_run).unwrap_or(0)),
                    last_exit: row.get(3)?,
                    last_cwd: last_cwd.map(PathBuf::from),
                })
            })?
            .collect()
        })
    }

    fn forget(&self, repo: Option<&Path>) -> Result<usize, HistoryError> {
        let repo = key(repo);
        self.with_conn(|conn| {
            conn.execute("DELETE FROM command_history WHERE repo = ?1", params![repo])
        })
    }

    fn forget_all(&self) -> Result<usize, HistoryError> {
        self.with_conn(|conn| conn.execute("DELETE FROM command_history", []))
    }
}

fn store_error(error: impl std::fmt::Display) -> HistoryError {
    HistoryError::Storage(error.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn run(command: &str, at: u64, exit: Option<i32>) -> CommandRun {
        CommandRun {
            command: command.into(),
            cwd: Some("/w/app/src".into()),
            exit,
            started_at: Timestamp::from_unix_nanos(at),
            took: None,
        }
    }

    #[test]
    fn the_same_line_again_is_one_more_run_of_it() {
        let store = SqliteHistoryStore::in_memory().unwrap();
        let repo = Some(Path::new("/w/app"));
        store
            .record(repo, &run("cargo test", 1, Some(101)))
            .unwrap();
        store.record(repo, &run("git status", 2, Some(0))).unwrap();
        store.record(repo, &run("cargo test", 3, Some(0))).unwrap();

        let recent = store.recent(repo, 10).unwrap();
        assert_eq!(recent.len(), 2);
        assert_eq!(recent[0].command, "cargo test");
        assert_eq!(recent[0].runs, 2);
        assert_eq!(recent[0].last_exit, Some(0));
        assert_eq!(recent[0].last_run, Timestamp::from_unix_nanos(3));
        assert_eq!(recent[0].last_cwd, Some("/w/app/src".into()));
        assert_eq!(recent[1].command, "git status");
    }

    #[test]
    fn each_repository_and_the_rest_keep_their_own() {
        let store = SqliteHistoryStore::in_memory().unwrap();
        store
            .record(Some(Path::new("/w/app")), &run("make", 1, None))
            .unwrap();
        store.record(None, &run("brew update", 2, None)).unwrap();

        assert_eq!(
            store.recent(Some(Path::new("/w/app")), 10).unwrap().len(),
            1
        );
        assert_eq!(store.recent(None, 10).unwrap()[0].command, "brew update");
        assert!(
            store
                .recent(Some(Path::new("/w/other")), 10)
                .unwrap()
                .is_empty()
        );

        assert_eq!(store.forget(Some(Path::new("/w/app"))).unwrap(), 1);
        assert!(
            store
                .recent(Some(Path::new("/w/app")), 10)
                .unwrap()
                .is_empty()
        );
        assert_eq!(store.forget_all().unwrap(), 1);
    }

    #[test]
    fn only_the_last_run_ones_are_kept() {
        let store = SqliteHistoryStore::in_memory().unwrap().with_limit(3);
        for i in 0..4 {
            store
                .record(None, &run(&format!("echo {i}"), i, None))
                .unwrap();
        }
        let recent = store.recent(None, 10).unwrap();
        assert_eq!(recent.len(), 3);
        assert!(!recent.iter().any(|e| e.command == "echo 0"));
    }

    #[test]
    fn opens_a_database_from_before_the_history() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("kumo.db");
        {
            let conn = Connection::open(&path).unwrap();
            for step in &migrations::steps()[..7] {
                conn.execute_batch(step).unwrap();
            }
            conn.pragma_update(None, "user_version", 7).unwrap();
        }
        let store = SqliteHistoryStore::open(&path).unwrap();
        store.record(None, &run("ls", 1, Some(0))).unwrap();
        assert_eq!(store.recent(None, 1).unwrap().len(), 1);
        // Nothing stays open between calls: the folder can go (Windows).
        std::fs::remove_dir_all(dir.path()).unwrap();
        drop(store);
    }
}
