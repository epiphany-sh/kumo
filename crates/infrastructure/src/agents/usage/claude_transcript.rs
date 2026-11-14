//! Claude Code started by hand in a terminal: Kumo didn't pass it the
//! status line, so its model and effort are read from its own files
//! (checked on Claude Code 2.1.325).
//!
//! `<config>/sessions/<pid>.json` names the process's session and its
//! `cwd`; `<config>/projects/<cwd as a folder name>/<session>.jsonl` is
//! the transcript, written from the first message on, where each
//! assistant message carries `message.model` and `effort`.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, PoisonError};

use kumo_domain::agents::{AgentSessionId, UsageReading, UsageTarget};
use serde_json::Value;

use super::lines::complete_lines;

#[derive(Debug)]
pub(super) struct ClaudeTranscripts {
    config_dir: PathBuf,
    tails: Mutex<HashMap<AgentSessionId, Tail>>,
}

/// How far a process's transcript has been read.
#[derive(Debug)]
struct Tail {
    /// Claude Code's session id: it changes on `/clear` or `/resume`.
    session: String,
    path: PathBuf,
    offset: u64,
}

impl ClaudeTranscripts {
    pub(super) fn new(config_dir: &Path) -> Self {
        Self {
            config_dir: config_dir.to_owned(),
            tails: Mutex::default(),
        }
    }

    /// What the transcript of `target.pid` added since the last call.
    pub(super) fn read(&self, target: &UsageTarget) -> Option<UsageReading> {
        let (session, cwd) = session_of(&self.config_dir, target.pid?)?;
        let mut tails = self.tails.lock().unwrap_or_else(PoisonError::into_inner);
        if tails
            .get(&target.session_id)
            .is_none_or(|t| t.session != session)
        {
            let path = transcript_path(&self.config_dir, &cwd, &session)?;
            tails.insert(
                target.session_id.clone(),
                Tail {
                    session,
                    path,
                    offset: 0,
                },
            );
        }
        let tail = tails.get_mut(&target.session_id)?;
        let (text, read) = complete_lines(&tail.path, tail.offset).ok()?;
        tail.offset += read;
        let reading = text.lines().fold(UsageReading::default(), |reading, line| {
            reading.merged(parse_line(line))
        });
        (!reading.is_empty()).then_some(reading)
    }

    pub(super) fn forget(&self, target: &UsageTarget) {
        self.tails
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .remove(&target.session_id);
    }
}

/// The session id and `cwd` Claude Code wrote for process `pid`.
fn session_of(config_dir: &Path, pid: u32) -> Option<(String, PathBuf)> {
    let path = config_dir.join("sessions").join(format!("{pid}.json"));
    let info: Value = serde_json::from_str(&std::fs::read_to_string(path).ok()?).ok()?;
    let session = info.get("sessionId")?.as_str()?.to_owned();
    let cwd = PathBuf::from(info.get("cwd")?.as_str()?);
    Some((session, cwd))
}

/// The transcript of `session`, in `cwd`'s project folder or, should that
/// be named otherwise, any.
fn transcript_path(config_dir: &Path, cwd: &Path, session: &str) -> Option<PathBuf> {
    let projects = config_dir.join("projects");
    let file = format!("{session}.jsonl");
    let path = projects.join(project_folder(cwd)).join(&file);
    if path.is_file() {
        return Some(path);
    }
    std::fs::read_dir(&projects)
        .ok()?
        .filter_map(|e| e.ok().map(|e| e.path().join(&file)))
        .find(|p| p.is_file())
}

/// `/Users/me/wt/a.b` → `-Users-me-wt-a-b`: every character but letters
/// and digits becomes `-`.
pub(super) fn project_folder(cwd: &Path) -> String {
    cwd.display()
        .to_string()
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '-' })
        .collect()
}

/// The model and effort of an assistant message; nothing for other lines.
pub(super) fn parse_line(line: &str) -> UsageReading {
    // Most lines aren't, and some are large.
    if !line.contains("\"assistant\"") {
        return UsageReading::default();
    }
    let Ok(item) = serde_json::from_str::<Value>(line) else {
        return UsageReading::default();
    };
    if item.get("type").and_then(Value::as_str) != Some("assistant") {
        return UsageReading::default();
    }
    UsageReading {
        // `<synthetic>`: a message Claude Code wrote itself (an error).
        model: item
            .pointer("/message/model")
            .and_then(Value::as_str)
            .filter(|m| !m.is_empty() && !m.starts_with('<'))
            .map(display_model),
        effort: item
            .get("effort")
            .and_then(Value::as_str)
            .filter(|e| !e.is_empty())
            .map(str::to_owned),
        ..UsageReading::default()
    }
}

/// A model id as Claude Code shows it: `claude-opus-5-5` → `Opus 5.5`,
/// `claude-sonnet-4-5-20250929` → `Sonnet 4.5`. Other ids stay as they
/// are.
pub(super) fn display_model(id: &str) -> String {
    let base = id.split('[').next().unwrap_or(id);
    let Some(rest) = base.strip_prefix("claude-") else {
        return id.to_owned();
    };
    let (mut names, mut version) = (Vec::new(), Vec::new());
    for part in rest.split('-') {
        let numeric = !part.is_empty() && part.chars().all(|c| c.is_ascii_digit());
        match (numeric, part.len()) {
            // A release date.
            (true, 8) => {}
            (true, _) => version.push(part),
            (false, _) => {
                let mut chars = part.chars();
                let Some(first) = chars.next() else {
                    return id.to_owned();
                };
                names.push(first.to_uppercase().chain(chars).collect::<String>());
            }
        }
    }
    if names.is_empty() {
        return id.to_owned();
    }
    let name = names.join(" ");
    if version.is_empty() {
        name
    } else {
        format!("{name} {}", version.join("."))
    }
}

#[cfg(test)]
mod tests {
    use kumo_domain::time::Timestamp;

    use super::*;

    const ASSISTANT: &str = r#"{"type":"assistant","effort":"high","message":{"model":"claude-opus-5-5","content":[]}}"#;

    #[test]
    fn model_ids_read_as_claude_code_names_them() {
        assert_eq!(display_model("claude-opus-5-5"), "Opus 5.5");
        assert_eq!(display_model("claude-sonnet-4-5-20250929"), "Sonnet 4.5");
        assert_eq!(display_model("claude-haiku-5-5[1m]"), "Haiku 5.5");
        assert_eq!(display_model("claude-fable-5-2"), "Fable 5.2");
        assert_eq!(display_model("gpt-6-sol"), "gpt-6-sol");
        assert_eq!(display_model("claude-5"), "claude-5");
    }

    #[test]
    fn only_assistant_messages_report() {
        let reading = parse_line(ASSISTANT);
        assert_eq!(reading.model.as_deref(), Some("Opus 5.5"));
        assert_eq!(reading.effort.as_deref(), Some("high"));
        assert!(parse_line(r#"{"type":"user","message":{"content":"assistant"}}"#).is_empty());
        let synthetic = parse_line(r#"{"type":"assistant","message":{"model":"<synthetic>"}}"#);
        assert!(synthetic.is_empty());
    }

    #[test]
    fn project_folders_are_named_after_the_cwd() {
        assert_eq!(
            project_folder(Path::new("/Users/me/wt/repo-1/feat.x")),
            "-Users-me-wt-repo-1-feat-x"
        );
    }

    #[test]
    fn follows_the_process_s_session_and_its_changes() {
        let config = tempfile::tempdir().unwrap();
        let cwd = Path::new("/work/repo-1");
        let sessions = config.path().join("sessions");
        let project = config.path().join("projects").join(project_folder(cwd));
        std::fs::create_dir_all(&sessions).unwrap();
        std::fs::create_dir_all(&project).unwrap();
        let name = |session: &str| {
            std::fs::write(
                sessions.join("42.json"),
                format!(r#"{{"pid":42,"sessionId":"{session}","cwd":"/work/repo-1"}}"#),
            )
            .unwrap();
        };
        let source = ClaudeTranscripts::new(config.path());
        let target = UsageTarget {
            session_id: AgentSessionId::parse("t1").unwrap(),
            worktree: cwd.to_owned(),
            started_at: Timestamp::now(),
            pid: Some(42),
        };
        assert_eq!(source.read(&target), None, "no session file yet");

        name("a");
        assert_eq!(source.read(&target), None, "no message yet");
        std::fs::write(project.join("a.jsonl"), format!("{ASSISTANT}\n")).unwrap();
        assert_eq!(
            source.read(&target).unwrap().model.as_deref(),
            Some("Opus 5.5")
        );
        assert_eq!(source.read(&target), None, "nothing new");

        // `/clear`: a new session, read from its start.
        name("b");
        std::fs::write(
            project.join("b.jsonl"),
            r#"{"type":"assistant","effort":"low","message":{"model":"claude-sonnet-5-5"}}"#
                .to_owned()
                + "\n",
        )
        .unwrap();
        let after = source.read(&target).unwrap();
        assert_eq!(after.model.as_deref(), Some("Sonnet 5.5"));
        assert_eq!(after.effort.as_deref(), Some("low"));
    }
}
