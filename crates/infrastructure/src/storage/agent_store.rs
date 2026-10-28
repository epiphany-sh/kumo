use std::path::Path;
use std::sync::{Mutex, PoisonError};

use kumo_domain::agents::{AgentError, AgentStore, StoredProvider};
use rusqlite::{Connection, params};

use super::migrations;

/// [`AgentStore`] on the same SQLite file as the workspace.
#[derive(Debug)]
pub struct SqliteAgentStore {
    conn: Mutex<Connection>,
}

impl SqliteAgentStore {
    pub fn open(path: &Path) -> Result<Self, AgentError> {
        Self::init(Connection::open(path).map_err(store_error)?)
    }

    pub fn in_memory() -> Result<Self, AgentError> {
        Self::init(Connection::open_in_memory().map_err(store_error)?)
    }

    fn init(mut conn: Connection) -> Result<Self, AgentError> {
        conn.execute_batch("PRAGMA journal_mode = WAL;")
            .map_err(store_error)?;
        migrations::migrate(&mut conn).map_err(store_error)?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }
}

impl AgentStore for SqliteAgentStore {
    fn load(&self) -> Result<Vec<StoredProvider>, AgentError> {
        let conn = self.conn.lock().unwrap_or_else(PoisonError::into_inner);
        let mut stmt = conn
            .prepare("SELECT id, name, program, args, custom, enabled, is_default FROM agent_providers ORDER BY position")
            .map_err(store_error)?;
        stmt.query_map([], |row| {
            Ok(StoredProvider {
                id: row.get(0)?,
                name: row.get(1)?,
                program: row.get(2)?,
                args: row.get(3)?,
                custom: row.get(4)?,
                enabled: row.get(5)?,
                is_default: row.get(6)?,
            })
        })
        .and_then(Iterator::collect)
        .map_err(store_error)
    }

    /// Upsert; only one provider can be the default.
    fn save(&self, p: &StoredProvider) -> Result<(), AgentError> {
        let mut conn = self.conn.lock().unwrap_or_else(PoisonError::into_inner);
        let tx = conn.transaction().map_err(store_error)?;
        if p.is_default {
            tx.execute(
                "UPDATE agent_providers SET is_default = 0 WHERE id <> ?1",
                [&p.id],
            )
            .map_err(store_error)?;
        }
        tx.execute(
            "INSERT INTO agent_providers (id, name, program, args, custom, enabled, is_default, position)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, (SELECT COALESCE(MAX(position), 0) + 1 FROM agent_providers))
             ON CONFLICT(id) DO UPDATE SET name = excluded.name, program = excluded.program, args = excluded.args,
                 custom = excluded.custom, enabled = excluded.enabled, is_default = excluded.is_default",
            params![p.id, p.name, p.program, p.args, p.custom, p.enabled, p.is_default],
        )
        .map_err(store_error)?;
        tx.commit().map_err(store_error)
    }

    fn delete(&self, id: &str) -> Result<(), AgentError> {
        let conn = self.conn.lock().unwrap_or_else(PoisonError::into_inner);
        conn.execute("DELETE FROM agent_providers WHERE id = ?1", [id])
            .map(drop)
            .map_err(store_error)
    }
}

fn store_error(error: impl std::fmt::Display) -> AgentError {
    AgentError::Store(error.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn provider(id: &str, default: bool) -> StoredProvider {
        StoredProvider {
            id: id.into(),
            name: id.into(),
            program: id.into(),
            args: "--x".into(),
            custom: false,
            enabled: true,
            is_default: default,
        }
    }

    #[test]
    fn saves_in_order_with_a_single_default() {
        let store = SqliteAgentStore::in_memory().unwrap();
        store.save(&provider("claude", true)).unwrap();
        store.save(&provider("codex", false)).unwrap();
        store.save(&provider("codex", true)).unwrap();
        let loaded = store.load().unwrap();
        assert_eq!(
            loaded
                .iter()
                .map(|p| (p.id.as_str(), p.is_default))
                .collect::<Vec<_>>(),
            vec![("claude", false), ("codex", true)]
        );
        store.delete("claude").unwrap();
        assert_eq!(store.load().unwrap().len(), 1);
    }
}
