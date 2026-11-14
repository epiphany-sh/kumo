//! Copilot CLI's model and effort, read from its session folders (checked
//! on Copilot CLI 1.0.108).
//!
//! Each session keeps `<copilot home>/session-state/<id>/`:
//! `workspace.yaml` (its `cwd` and `created_at`), `inuse.<pid>.lock` while
//! a process has it open and, from the first message on, `events.jsonl`.
//! There `session.model_change` (`newModel`, `reasoningEffort`) comes at
//! start and on `/model`; with the model `auto`, `session.auto_mode_resolved`
//! says which one it chose; `session.usage_record` names the model each
//! request used.

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::{Mutex, PoisonError};
use std::time::Duration;

use kumo_domain::agents::{AgentError, AgentSessionId, UsageReading, UsageSource, UsageTarget};
use kumo_domain::time::Timestamp;
use serde_json::Value;

use super::codex::parse_utc;
use super::lines::complete_lines;

/// A session may start a little before Kumo noted it.
const START_SLACK: Duration = Duration::from_secs(5);
const EVENTS: &str = "events.jsonl";

/// Copilot CLI's folder: `$COPILOT_HOME`, else `~/.copilot`.
pub fn copilot_home(home: &Path) -> PathBuf {
    std::env::var_os("COPILOT_HOME")
        .filter(|v| !v.is_empty())
        .map_or_else(|| home.join(".copilot"), PathBuf::from)
}

/// [`UsageSource`] for Copilot CLI. It reports no limits or context here
/// (its account does, see [`super::CopilotAccount`]): only what it runs on.
#[derive(Debug)]
pub struct CopilotEvents {
    state: PathBuf,
    tails: Mutex<HashMap<AgentSessionId, Tail>>,
}

#[derive(Debug)]
struct Tail {
    path: PathBuf,
    offset: u64,
}

impl CopilotEvents {
    /// `copilot_home`: see [`copilot_home`].
    pub fn new(copilot_home: &Path) -> Self {
        Self {
            state: copilot_home.join("session-state"),
            tails: Mutex::default(),
        }
    }
}

impl UsageSource for CopilotEvents {
    fn provider_id(&self) -> &str {
        "copilot"
    }

    fn launch_args(&self, _target: &UsageTarget) -> Result<Vec<String>, AgentError> {
        Ok(Vec::new())
    }

    fn read(&self, target: &UsageTarget) -> Option<UsageReading> {
        let mut tails = self.tails.lock().unwrap_or_else(PoisonError::into_inner);
        if !tails.contains_key(&target.session_id) {
            let taken: HashSet<PathBuf> = tails.values().map(|t| t.path.clone()).collect();
            let dir = find_session(&self.state, target, &taken)?;
            tails.insert(
                target.session_id.clone(),
                Tail {
                    path: dir.join(EVENTS),
                    offset: 0,
                },
            );
        }
        let tail = tails.get_mut(&target.session_id)?;
        // No events until the first message.
        let (text, read) = complete_lines(&tail.path, tail.offset).ok()?;
        tail.offset += read;
        let reading = text.lines().fold(UsageReading::default(), |reading, line| {
            reading.merged(parse_line(line))
        });
        (!reading.is_empty()).then_some(reading)
    }

    fn forget(&self, target: &UsageTarget) {
        self.tails
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .remove(&target.session_id);
    }
}

/// The session folder `target` runs in: the one its process holds open
/// when the pid is known, else the first one in its worktree created
/// since it started (less [`START_SLACK`]) that no other target took: a
/// session started there later can't take its place.
pub fn find_session(
    state: &Path,
    target: &UsageTarget,
    taken: &HashSet<PathBuf>,
) -> Option<PathBuf> {
    let dirs: Vec<PathBuf> = std::fs::read_dir(state)
        .ok()?
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|d| d.is_dir() && !taken.contains(&d.join(EVENTS)))
        .collect();
    if let Some(pid) = target.pid {
        let lock = format!("inuse.{pid}.lock");
        if let Some(dir) = dirs.iter().find(|d| d.join(&lock).is_file()) {
            return Some(dir.clone());
        }
    }
    let worktree = canonical(&target.worktree);
    let earliest = target
        .started_at
        .as_unix_nanos()
        .saturating_sub(u64::try_from(START_SLACK.as_nanos()).unwrap_or(0));
    dirs.into_iter()
        .filter_map(|dir| {
            let (cwd, created) =
                workspace(&std::fs::read_to_string(dir.join("workspace.yaml")).ok()?)?;
            (canonical(&cwd) == worktree && created.as_unix_nanos() >= earliest)
                .then_some((created, dir))
        })
        .min_by_key(|(created, _)| *created)
        .map(|(_, dir)| dir)
}

fn canonical(path: &Path) -> PathBuf {
    std::fs::canonicalize(path).unwrap_or_else(|_| path.to_owned())
}

/// `cwd` and `created_at` of a `workspace.yaml`: flat `key: value` lines.
pub fn workspace(yaml: &str) -> Option<(PathBuf, Timestamp)> {
    let value = |key: &str| {
        yaml.lines().find_map(|line| {
            let raw = line.strip_prefix(key)?.strip_prefix(':')?.trim();
            let unquoted = raw
                .strip_prefix('"')
                .and_then(|r| r.strip_suffix('"'))
                .or_else(|| raw.strip_prefix('\'').and_then(|r| r.strip_suffix('\'')))
                .unwrap_or(raw);
            Some(unquoted.to_owned())
        })
    };
    let cwd = PathBuf::from(value("cwd")?);
    let created = parse_utc(&value("created_at")?)?;
    Some((cwd, created))
}

/// What one event says about the model and effort.
pub fn parse_line(line: &str) -> UsageReading {
    // Most events are messages and tool calls, some large.
    if !line.contains("\"session.") {
        return UsageReading::default();
    }
    let Ok(event) = serde_json::from_str::<Value>(line) else {
        return UsageReading::default();
    };
    let Some(data) = event.get("data") else {
        return UsageReading::default();
    };
    let text = |v: Option<&Value>| {
        v.and_then(Value::as_str)
            .filter(|s| !s.is_empty())
            .map(str::to_owned)
    };
    match event.get("type").and_then(Value::as_str) {
        // The effort goes with the model: none (null) is none.
        Some("session.model_change") => UsageReading {
            model: text(data.get("newModel")).map(|m| if m == "auto" { "Auto".into() } else { m }),
            effort: Some(text(data.get("reasoningEffort")).unwrap_or_default()),
            ..UsageReading::default()
        },
        Some("session.auto_mode_resolved") => UsageReading {
            model: text(data.get("chosenModel")).map(|m| format!("Auto · {m}")),
            ..UsageReading::default()
        },
        _ => UsageReading::default(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn at(rfc3339: &str) -> Timestamp {
        parse_utc(rfc3339).unwrap()
    }

    fn session(state: &Path, name: &str, cwd: &Path, created: &str) -> PathBuf {
        let dir = state.join(name);
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(
            dir.join("workspace.yaml"),
            format!(
                "id: {name}\ncwd: {}\nbranch: main\ncreated_at: {created}\n",
                cwd.display()
            ),
        )
        .unwrap();
        dir
    }

    fn target(id: &str, worktree: &Path, started: &str, pid: Option<u32>) -> UsageTarget {
        UsageTarget {
            session_id: AgentSessionId::parse(id).unwrap(),
            worktree: worktree.to_owned(),
            started_at: at(started),
            pid,
        }
    }

    #[test]
    fn reads_workspace_files() {
        let (cwd, created) = workspace(
            "id: x\ncwd: \"/work/repo 1\"\ngit_root: /work\ncreated_at: 2026-11-14T15:12:56.087Z\n",
        )
        .unwrap();
        assert_eq!(cwd, PathBuf::from("/work/repo 1"));
        assert_eq!(created, at("2026-11-14T15:12:56.087Z"));
    }

    #[test]
    fn model_changes_bring_their_effort() {
        let change = parse_line(
            r#"{"type":"session.model_change","data":{"source":"startup","newModel":"gpt-6-sol","reasoningEffort":"high"}}"#,
        );
        assert_eq!(change.model.as_deref(), Some("gpt-6-sol"));
        assert_eq!(change.effort.as_deref(), Some("high"));
        // Auto has no effort, then says what it chose.
        let auto = parse_line(
            r#"{"type":"session.model_change","data":{"newModel":"auto","reasoningEffort":null}}"#,
        );
        assert_eq!(
            (auto.model.as_deref(), auto.effort.as_deref()),
            (Some("Auto"), Some(""))
        );
        let chosen = parse_line(
            r#"{"type":"session.auto_mode_resolved","data":{"chosenModel":"gpt-6-luna"}}"#,
        );
        assert_eq!(chosen.model.as_deref(), Some("Auto · gpt-6-luna"));
        assert!(parse_line(r#"{"type":"assistant.message","data":{"model":"x"}}"#).is_empty());
    }

    #[test]
    fn finds_the_session_by_its_process_or_by_worktree_and_start() {
        let state = tempfile::tempdir().unwrap();
        let worktree = tempfile::tempdir().unwrap();
        let other = tempfile::tempdir().unwrap();
        let old = session(state.path(), "old", worktree.path(), "2026-11-14T10:00:00Z");
        let later = session(
            state.path(),
            "later",
            worktree.path(),
            "2026-11-14T12:30:00Z",
        );
        let mine = session(
            state.path(),
            "mine",
            worktree.path(),
            "2026-11-14T12:00:01Z",
        );
        session(
            state.path(),
            "elsewhere",
            other.path(),
            "2026-11-14T12:00:02Z",
        );
        let none = HashSet::new();

        let started = target("t1", worktree.path(), "2026-11-14T12:00:00Z", None);
        assert_eq!(
            find_session(state.path(), &started, &none),
            Some(mine.clone())
        );
        let taken = HashSet::from([mine.join(EVENTS)]);
        assert_eq!(
            find_session(state.path(), &started, &taken),
            Some(later.clone())
        );
        let both = HashSet::from([mine.join(EVENTS), later.join(EVENTS)]);
        assert_eq!(find_session(state.path(), &started, &both), None);

        // Started by hand on a resumed session: its lock tells.
        std::fs::write(old.join("inuse.42.lock"), "42").unwrap();
        let resumed = target("t2", worktree.path(), "2026-11-14T12:00:00Z", Some(42));
        assert_eq!(find_session(state.path(), &resumed, &none), Some(old));
    }

    #[test]
    fn tails_the_events_once_they_exist() {
        let home = tempfile::tempdir().unwrap();
        let worktree = tempfile::tempdir().unwrap();
        let dir = session(
            &home.path().join("session-state"),
            "s",
            worktree.path(),
            "2026-11-14T12:00:01Z",
        );
        let source = CopilotEvents::new(home.path());
        let t = target("t1", worktree.path(), "2026-11-14T12:00:00Z", None);
        assert_eq!(source.read(&t), None, "no message yet");
        std::fs::write(
            dir.join(EVENTS),
            concat!(
                r#"{"type":"session.start","data":{}}"#,
                "\n",
                r#"{"type":"session.model_change","data":{"newModel":"gpt-6-sol","reasoningEffort":"medium"}}"#,
                "\n"
            ),
        )
        .unwrap();
        let first = source.read(&t).unwrap();
        assert_eq!(
            (first.model.as_deref(), first.effort.as_deref()),
            (Some("gpt-6-sol"), Some("medium"))
        );
        assert_eq!(source.read(&t), None, "nothing new");
    }
}
