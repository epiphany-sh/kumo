use std::path::Path;
use std::sync::{Mutex, PoisonError};

use kumo_domain::agents::{
    AgentError, AgentStore, PlanUsage, PlanUsageStore, StoredProvider, UsageUnit, UsageWindow,
};
use kumo_domain::time::Timestamp;
use rusqlite::{Connection, params};
use serde_json::{Value, json};

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
            .prepare("SELECT id, name, program, args, custom, enabled, is_default, read_usage FROM agent_providers ORDER BY position")
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
                read_usage: row.get(7)?,
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
            "INSERT INTO agent_providers (id, name, program, args, custom, enabled, is_default, read_usage, position)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, (SELECT COALESCE(MAX(position), 0) + 1 FROM agent_providers))
             ON CONFLICT(id) DO UPDATE SET name = excluded.name, program = excluded.program, args = excluded.args,
                 custom = excluded.custom, enabled = excluded.enabled, is_default = excluded.is_default,
                 read_usage = excluded.read_usage",
            params![p.id, p.name, p.program, p.args, p.custom, p.enabled, p.is_default, p.read_usage],
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

/// The last plan reading per provider, so it shows while no session runs.
impl PlanUsageStore for SqliteAgentStore {
    fn load_plans(&self) -> Result<Vec<PlanUsage>, AgentError> {
        let conn = self.conn.lock().unwrap_or_else(PoisonError::into_inner);
        let mut stmt = conn
            .prepare("SELECT provider_id, plan, windows, read_at FROM agent_plan_usage")
            .map_err(store_error)?;
        let rows: Vec<(String, String, String, i64)> = stmt
            .query_map([], |row| {
                Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?))
            })
            .and_then(Iterator::collect)
            .map_err(store_error)?;
        Ok(rows
            .into_iter()
            .map(|(provider_id, plan, windows, read_at)| PlanUsage {
                provider_id,
                plan,
                windows: windows_from_json(&windows),
                problem: String::new(),
                read_at: Timestamp::from_unix_nanos(u64::try_from(read_at).unwrap_or(0)),
            })
            .collect())
    }

    fn save_plan(&self, plan: &PlanUsage) -> Result<(), AgentError> {
        let conn = self.conn.lock().unwrap_or_else(PoisonError::into_inner);
        conn.execute(
            "INSERT INTO agent_plan_usage (provider_id, plan, windows, read_at) VALUES (?1, ?2, ?3, ?4)
             ON CONFLICT(provider_id) DO UPDATE SET plan = excluded.plan, windows = excluded.windows,
                 read_at = excluded.read_at",
            params![
                plan.provider_id,
                plan.plan,
                windows_to_json(&plan.windows),
                i64::try_from(plan.read_at.as_unix_nanos()).unwrap_or(i64::MAX),
            ],
        )
        .map(drop)
        .map_err(store_error)
    }
}

fn windows_to_json(windows: &[UsageWindow]) -> String {
    let windows: Vec<Value> = windows
        .iter()
        .map(|w| {
            json!({
                "label": w.label,
                "short": w.short,
                "left": w.left,
                "of": w.of,
                "unit": match w.unit {
                    UsageUnit::Percent => "percent",
                    UsageUnit::Requests => "requests",
                    UsageUnit::Dollars => "dollars",
                },
                "resets_at": w.resets_at.map(Timestamp::as_unix_nanos),
            })
        })
        .collect();
    Value::Array(windows).to_string()
}

/// Windows that don't read back (an older shape) are dropped.
fn windows_from_json(raw: &str) -> Vec<UsageWindow> {
    let Ok(Value::Array(windows)) = serde_json::from_str::<Value>(raw) else {
        return Vec::new();
    };
    windows
        .iter()
        .filter_map(|w| {
            Some(UsageWindow {
                label: w.get("label")?.as_str()?.to_owned(),
                short: w.get("short")?.as_str()?.to_owned(),
                left: w.get("left")?.as_f64()?,
                of: w.get("of")?.as_f64()?,
                unit: match w.get("unit")?.as_str()? {
                    "percent" => UsageUnit::Percent,
                    "requests" => UsageUnit::Requests,
                    "dollars" => UsageUnit::Dollars,
                    _ => return None,
                },
                resets_at: w
                    .get("resets_at")
                    .and_then(Value::as_u64)
                    .map(Timestamp::from_unix_nanos),
            })
        })
        .collect()
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
            read_usage: true,
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

    #[test]
    fn keeps_the_usage_setting() {
        let store = SqliteAgentStore::in_memory().unwrap();
        store
            .save(&StoredProvider {
                read_usage: false,
                ..provider("claude", true)
            })
            .unwrap();
        assert!(!store.load().unwrap()[0].read_usage);
    }

    #[test]
    fn keeps_the_last_plan_reading_per_provider() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("kumo.db");
        let plan = |used: f64, at: u64| PlanUsage {
            provider_id: "claude".into(),
            plan: String::new(),
            windows: vec![UsageWindow::percent_over_minutes(
                300,
                used,
                Some(Timestamp::from_unix_nanos(1_738_425_600_000_000_000)),
            )],
            problem: String::new(),
            read_at: Timestamp::from_unix_nanos(at),
        };
        {
            let store = SqliteAgentStore::open(&path).unwrap();
            assert!(store.load_plans().unwrap().is_empty());
            store.save_plan(&plan(10.0, 1)).unwrap();
            store.save_plan(&plan(23.5, 2)).unwrap();
        }
        // Read back after a restart.
        let store = SqliteAgentStore::open(&path).unwrap();
        assert_eq!(store.load_plans().unwrap(), vec![plan(23.5, 2)]);
    }
}
