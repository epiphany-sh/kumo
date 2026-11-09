//! Kumo's settings for your agents and their test runs, next to the
//! providers in the same SQLite file.

use std::sync::PoisonError;

use kumo_domain::agent_defs::{
    AgentDefKey, AgentDefScope, AgentDefSettings, AgentDefStore, AgentDefTrigger, PlayEvent,
    PlayEventKind, PlayRecord,
};
use kumo_domain::agents::AgentError;
use rusqlite::params;
use serde_json::{Value, json};

use super::agent_store::{SqliteAgentStore, store_error};

fn scope_from(raw: &str) -> AgentDefScope {
    match raw {
        "project" => AgentDefScope::Project,
        _ => AgentDefScope::Personal,
    }
}

fn trigger_key(trigger: AgentDefTrigger) -> &'static str {
    match trigger {
        AgentDefTrigger::PullRequest => "pull_request",
        AgentDefTrigger::Schedule => "schedule",
    }
}

fn settings_json(settings: &AgentDefSettings) -> String {
    json!({
        "max_minutes": settings.max_minutes,
        "max_cost_usd": settings.max_cost_usd,
        "triggers": settings.triggers.iter().map(|t| trigger_key(*t)).collect::<Vec<_>>(),
    })
    .to_string()
}

fn settings_from(raw: &str) -> AgentDefSettings {
    let value: Value = serde_json::from_str(raw).unwrap_or_default();
    AgentDefSettings {
        max_minutes: value["max_minutes"]
            .as_u64()
            .and_then(|m| u32::try_from(m).ok()),
        max_cost_usd: value["max_cost_usd"].as_f64(),
        triggers: value["triggers"]
            .as_array()
            .into_iter()
            .flatten()
            .filter_map(|t| match t.as_str()? {
                "pull_request" => Some(AgentDefTrigger::PullRequest),
                "schedule" => Some(AgentDefTrigger::Schedule),
                _ => None,
            })
            .collect(),
    }
}

fn events_json(events: &[PlayEvent]) -> String {
    Value::Array(
        events
            .iter()
            .map(|e| match &e.kind {
                PlayEventKind::Line(line) => json!({ "t": e.at_ms, "line": line }),
                PlayEventKind::Exited(code) => json!({ "t": e.at_ms, "exited": code }),
            })
            .collect(),
    )
    .to_string()
}

fn events_from(raw: &str) -> Vec<PlayEvent> {
    let value: Value = serde_json::from_str(raw).unwrap_or_default();
    value
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|e| {
            let at_ms = e["t"].as_i64().unwrap_or(0);
            let kind = match (e["line"].as_str(), e["exited"].as_i64()) {
                (Some(line), _) => PlayEventKind::Line(line.to_owned()),
                (None, Some(code)) => PlayEventKind::Exited(i32::try_from(code).unwrap_or(-1)),
                _ => return None,
            };
            Some(PlayEvent { kind, at_ms })
        })
        .collect()
}

impl AgentDefStore for SqliteAgentStore {
    fn settings(&self) -> Result<Vec<(AgentDefKey, AgentDefSettings)>, AgentError> {
        let conn = self.conn.lock().unwrap_or_else(PoisonError::into_inner);
        let mut statement = conn
            .prepare("SELECT scope, repo_path, name, settings FROM agent_def_settings")
            .map_err(store_error)?;
        let rows = statement
            .query_map([], |row| {
                Ok((
                    AgentDefKey {
                        scope: scope_from(&row.get::<_, String>(0)?),
                        repo_path: row.get(1)?,
                        name: row.get(2)?,
                    },
                    settings_from(&row.get::<_, String>(3)?),
                ))
            })
            .map_err(store_error)?;
        rows.collect::<Result<_, _>>().map_err(store_error)
    }

    fn set_settings(
        &self,
        key: &AgentDefKey,
        settings: &AgentDefSettings,
    ) -> Result<(), AgentError> {
        let conn = self.conn.lock().unwrap_or_else(PoisonError::into_inner);
        conn.execute(
            "INSERT INTO agent_def_settings (scope, repo_path, name, settings) VALUES (?1, ?2, ?3, ?4)
             ON CONFLICT (scope, repo_path, name) DO UPDATE SET settings = excluded.settings",
            params![key.scope.key(), key.repo_path, key.name, settings_json(settings)],
        )
        .map_err(store_error)?;
        Ok(())
    }

    fn forget(&self, key: &AgentDefKey) -> Result<(), AgentError> {
        let conn = self.conn.lock().unwrap_or_else(PoisonError::into_inner);
        for table in ["agent_def_settings", "agent_def_plays"] {
            conn.execute(
                &format!("DELETE FROM {table} WHERE scope = ?1 AND repo_path = ?2 AND name = ?3"),
                params![key.scope.key(), key.repo_path, key.name],
            )
            .map_err(store_error)?;
        }
        Ok(())
    }

    fn rekey(&self, from: &AgentDefKey, to: &AgentDefKey) -> Result<(), AgentError> {
        if from == to {
            return Ok(());
        }
        let mut conn = self.conn.lock().unwrap_or_else(PoisonError::into_inner);
        let tx = conn.transaction().map_err(store_error)?;
        // What the new key had (an agent saved over) gives way.
        for table in ["agent_def_settings", "agent_def_plays"] {
            tx.execute(
                &format!("DELETE FROM {table} WHERE scope = ?1 AND repo_path = ?2 AND name = ?3"),
                params![to.scope.key(), to.repo_path, to.name],
            )
            .map_err(store_error)?;
            tx.execute(
                &format!(
                    "UPDATE {table} SET scope = ?4, repo_path = ?5, name = ?6
                     WHERE scope = ?1 AND repo_path = ?2 AND name = ?3"
                ),
                params![
                    from.scope.key(),
                    from.repo_path,
                    from.name,
                    to.scope.key(),
                    to.repo_path,
                    to.name
                ],
            )
            .map_err(store_error)?;
        }
        tx.commit().map_err(store_error)
    }

    fn save_play(
        &self,
        key: &AgentDefKey,
        play: &PlayRecord,
        keep: usize,
    ) -> Result<(), AgentError> {
        let conn = self.conn.lock().unwrap_or_else(PoisonError::into_inner);
        conn.execute(
            "INSERT INTO agent_def_plays (id, scope, repo_path, name, task, draft, started, events)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
             ON CONFLICT (id) DO UPDATE SET events = excluded.events",
            params![
                play.id,
                key.scope.key(),
                key.repo_path,
                key.name,
                play.task,
                play.draft,
                play.started_unix_ms,
                events_json(&play.events)
            ],
        )
        .map_err(store_error)?;
        conn.execute(
            "DELETE FROM agent_def_plays WHERE scope = ?1 AND repo_path = ?2 AND name = ?3 AND id NOT IN (
                SELECT id FROM agent_def_plays WHERE scope = ?1 AND repo_path = ?2 AND name = ?3
                ORDER BY started DESC, rowid DESC LIMIT ?4)",
            params![key.scope.key(), key.repo_path, key.name, i64::try_from(keep).unwrap_or(i64::MAX)],
        )
        .map_err(store_error)?;
        Ok(())
    }

    fn plays(&self, key: &AgentDefKey) -> Result<Vec<PlayRecord>, AgentError> {
        let conn = self.conn.lock().unwrap_or_else(PoisonError::into_inner);
        let mut statement = conn
            .prepare(
                "SELECT id, task, draft, started, events FROM agent_def_plays
                 WHERE scope = ?1 AND repo_path = ?2 AND name = ?3 ORDER BY started DESC, rowid DESC",
            )
            .map_err(store_error)?;
        let rows = statement
            .query_map(params![key.scope.key(), key.repo_path, key.name], |row| {
                Ok(PlayRecord {
                    id: row.get(0)?,
                    task: row.get(1)?,
                    draft: row.get(2)?,
                    started_unix_ms: row.get(3)?,
                    events: events_from(&row.get::<_, String>(4)?),
                    running: false,
                })
            })
            .map_err(store_error)?;
        rows.collect::<Result<_, _>>().map_err(store_error)
    }
}

/// Whether a key has settings (for tests).
#[cfg(test)]
fn has_settings(store: &SqliteAgentStore, key: &AgentDefKey) -> bool {
    use rusqlite::OptionalExtension;
    let conn = store.conn.lock().unwrap();
    conn.query_row(
        "SELECT 1 FROM agent_def_settings WHERE scope = ?1 AND repo_path = ?2 AND name = ?3",
        params![key.scope.key(), key.repo_path, key.name],
        |_| Ok(()),
    )
    .optional()
    .unwrap()
    .is_some()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn key(name: &str) -> AgentDefKey {
        AgentDefKey {
            scope: AgentDefScope::Project,
            repo_path: "/w/app".into(),
            name: name.into(),
        }
    }

    fn play(id: &str, started: i64) -> PlayRecord {
        let mut play = PlayRecord {
            id: id.into(),
            task: "Review".into(),
            draft: true,
            started_unix_ms: started,
            running: true,
            ..Default::default()
        };
        play.push_line("{\"type\":\"system\"}".into(), 5);
        play.exit(0, 9);
        play
    }

    #[test]
    fn settings_round_trip_and_follow_a_rename() {
        let store = SqliteAgentStore::in_memory().unwrap();
        let settings = AgentDefSettings {
            max_minutes: Some(10),
            max_cost_usd: Some(1.5),
            triggers: vec![AgentDefTrigger::PullRequest],
        };
        store.set_settings(&key("rev"), &settings).unwrap();
        store.set_settings(&key("rev"), &settings).unwrap();
        assert_eq!(store.settings().unwrap(), [(key("rev"), settings.clone())]);

        store.save_play(&key("rev"), &play("p1", 1), 10).unwrap();
        let moved = AgentDefKey {
            scope: AgentDefScope::Personal,
            repo_path: String::new(),
            name: "reviewer".into(),
        };
        store.rekey(&key("rev"), &moved).unwrap();
        assert!(!has_settings(&store, &key("rev")));
        assert_eq!(store.settings().unwrap(), [(moved.clone(), settings)]);
        assert_eq!(store.plays(&moved).unwrap().len(), 1);
        store.forget(&moved).unwrap();
        assert!(store.settings().unwrap().is_empty());
        assert!(store.plays(&moved).unwrap().is_empty());
    }

    #[test]
    fn keeps_the_newest_test_runs_with_their_lines() {
        let store = SqliteAgentStore::in_memory().unwrap();
        for i in 0..12 {
            store
                .save_play(&key("rev"), &play(&format!("p{i}"), i), 10)
                .unwrap();
        }
        let plays = store.plays(&key("rev")).unwrap();
        assert_eq!(plays.len(), 10);
        assert_eq!(plays[0].id, "p11");
        assert_eq!(plays[9].id, "p2");
        assert_eq!(plays[0].events, play("p11", 11).events);
        assert!(store.plays(&key("other")).unwrap().is_empty());
    }
}
