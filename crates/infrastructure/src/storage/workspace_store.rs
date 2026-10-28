use std::path::{Path, PathBuf};
use std::sync::{Mutex, PoisonError};

use kumo_domain::workspace::{
    Namespace, NamespaceId, Remote, Repo, StoredWorkspace, WorkspaceError, WorkspaceStore,
};
use rusqlite::{Connection, OptionalExtension, params};

use super::migrations;

/// [`WorkspaceStore`] on a SQLite file.
#[derive(Debug)]
pub struct SqliteWorkspaceStore {
    conn: Mutex<Connection>,
}

impl SqliteWorkspaceStore {
    pub fn open(path: &Path) -> Result<Self, WorkspaceError> {
        if let Some(dir) = path.parent() {
            std::fs::create_dir_all(dir)
                .map_err(|e| store_error(format!("{}: {e}", dir.display())))?;
        }
        Self::init(Connection::open(path).map_err(store_error)?)
    }

    pub fn in_memory() -> Result<Self, WorkspaceError> {
        Self::init(Connection::open_in_memory().map_err(store_error)?)
    }

    fn init(mut conn: Connection) -> Result<Self, WorkspaceError> {
        conn.execute_batch("PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL;")
            .map_err(store_error)?;
        migrations::migrate(&mut conn).map_err(store_error)?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    fn conn(&self) -> std::sync::MutexGuard<'_, Connection> {
        self.conn.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

impl WorkspaceStore for SqliteWorkspaceStore {
    fn load(&self) -> Result<StoredWorkspace, WorkspaceError> {
        let conn = self.conn();
        let mut repos_stmt = conn
            .prepare("SELECT path, remote_url FROM repos ORDER BY path")
            .map_err(store_error)?;
        let repos = repos_stmt
            .query_map([], |row| {
                let path: String = row.get(0)?;
                let remote: Option<String> = row.get(1)?;
                Ok(Repo::new(
                    PathBuf::from(path),
                    remote.map(|url| Remote::parse(&url)),
                ))
            })
            .and_then(Iterator::collect)
            .map_err(store_error)?;

        let mut ns_stmt = conn
            .prepare("SELECT id, name, collapsed FROM namespaces ORDER BY position")
            .map_err(store_error)?;
        let rows: Vec<(String, String, bool)> = ns_stmt
            .query_map([], |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)))
            .and_then(Iterator::collect)
            .map_err(store_error)?;
        let mut members = conn
            .prepare(
                "SELECT repo_path FROM namespace_repos WHERE namespace_id = ?1 ORDER BY position",
            )
            .map_err(store_error)?;
        let mut namespaces = Vec::with_capacity(rows.len());
        for (id, name, collapsed) in rows {
            let paths: Vec<String> = members
                .query_map([&id], |row| row.get(0))
                .and_then(Iterator::collect)
                .map_err(store_error)?;
            let id = NamespaceId::parse(&id).ok_or_else(|| store_error("blank namespace id"))?;
            namespaces.push(Namespace::new(
                id,
                &name,
                paths.into_iter().map(PathBuf::from),
                collapsed,
            ));
        }
        Ok(StoredWorkspace { namespaces, repos })
    }

    fn save_namespace(&self, namespace: &Namespace, position: usize) -> Result<(), WorkspaceError> {
        let mut conn = self.conn();
        let tx = conn.transaction().map_err(store_error)?;
        // Remove it from the order, then shift the rest to make room.
        let old: Option<i64> = tx
            .query_row(
                "SELECT position FROM namespaces WHERE id = ?1",
                [namespace.id.as_str()],
                |r| r.get(0),
            )
            .optional()
            .map_err(store_error)?;
        if let Some(old) = old {
            tx.execute(
                "DELETE FROM namespaces WHERE id = ?1",
                [namespace.id.as_str()],
            )
            .map_err(store_error)?;
            tx.execute(
                "UPDATE namespaces SET position = position - 1 WHERE position > ?1",
                [old],
            )
            .map_err(store_error)?;
        }
        let count: i64 = tx
            .query_row("SELECT COUNT(*) FROM namespaces", [], |r| r.get(0))
            .map_err(store_error)?;
        let at = i64::try_from(position).unwrap_or(i64::MAX).min(count);
        tx.execute(
            "UPDATE namespaces SET position = position + 1 WHERE position >= ?1",
            [at],
        )
        .map_err(store_error)?;
        tx.execute(
            "INSERT INTO namespaces (id, name, collapsed, position) VALUES (?1, ?2, ?3, ?4)",
            params![
                namespace.id.as_str(),
                namespace.name,
                namespace.collapsed,
                at
            ],
        )
        .map_err(store_error)?;
        for (index, repo) in (0_i64..).zip(&namespace.repos) {
            tx.execute(
                "INSERT INTO namespace_repos (namespace_id, repo_path, position) VALUES (?1, ?2, ?3)",
                params![namespace.id.as_str(), path_text(repo), index],
            )
            .map_err(store_error)?;
        }
        tx.commit().map_err(store_error)
    }

    fn delete_namespace(&self, id: &NamespaceId) -> Result<(), WorkspaceError> {
        let mut conn = self.conn();
        let tx = conn.transaction().map_err(store_error)?;
        let old: Option<i64> = tx
            .query_row(
                "SELECT position FROM namespaces WHERE id = ?1",
                [id.as_str()],
                |r| r.get(0),
            )
            .optional()
            .map_err(store_error)?;
        if let Some(old) = old {
            tx.execute("DELETE FROM namespaces WHERE id = ?1", [id.as_str()])
                .map_err(store_error)?;
            tx.execute(
                "UPDATE namespaces SET position = position - 1 WHERE position > ?1",
                [old],
            )
            .map_err(store_error)?;
        }
        tx.commit().map_err(store_error)
    }

    fn save_repo(&self, repo: &Repo) -> Result<(), WorkspaceError> {
        self.conn()
            .execute(
                "INSERT INTO repos (path, remote_url) VALUES (?1, ?2)
                 ON CONFLICT(path) DO UPDATE SET remote_url = excluded.remote_url",
                params![
                    path_text(&repo.path),
                    repo.remote.as_ref().map(|r| r.url.as_str())
                ],
            )
            .map(drop)
            .map_err(store_error)
    }
}

fn path_text(path: &Path) -> String {
    path.to_string_lossy().into_owned()
}

fn store_error(error: impl std::fmt::Display) -> WorkspaceError {
    WorkspaceError::Store(error.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn repo(path: &str) -> Repo {
        Repo::new(
            PathBuf::from(path),
            Some(Remote::parse("git@github.com:o/x.git")),
        )
    }

    fn namespace(name: &str, repos: &[&str]) -> Namespace {
        Namespace::new(
            NamespaceId::generate(),
            name,
            repos.iter().map(PathBuf::from),
            false,
        )
    }

    #[test]
    fn round_trips_namespaces_in_order() {
        let store = SqliteWorkspaceStore::in_memory().unwrap();
        store.save_repo(&repo("/r/a")).unwrap();
        store.save_repo(&repo("/r/b")).unwrap();
        let first = namespace("pricing", &["/r/b", "/r/a"]);
        let second = namespace("identity", &["/r/a"]);
        store.save_namespace(&first, 0).unwrap();
        store.save_namespace(&second, 9).unwrap();

        let loaded = store.load().unwrap();
        assert_eq!(loaded.namespaces, vec![first.clone(), second.clone()]);
        assert_eq!(loaded.repos.len(), 2);
        assert_eq!(
            loaded.repos[0]
                .remote
                .as_ref()
                .unwrap()
                .full_name
                .as_deref(),
            Some("o/x")
        );

        // Re-saving moves it; deleting closes the gap.
        store.save_namespace(&second, 0).unwrap();
        assert_eq!(store.load().unwrap().namespaces[0].id, second.id);
        store.delete_namespace(&second.id).unwrap();
        assert_eq!(store.load().unwrap().namespaces, vec![first]);
    }

    #[test]
    fn persists_across_reopen() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("kumo.db");
        let ns = namespace("team", &["/r/a"]);
        {
            let store = SqliteWorkspaceStore::open(&path).unwrap();
            store.save_repo(&repo("/r/a")).unwrap();
            store.save_namespace(&ns, 0).unwrap();
        }
        assert_eq!(
            SqliteWorkspaceStore::open(&path)
                .unwrap()
                .load()
                .unwrap()
                .namespaces,
            vec![ns]
        );
    }
}
