//! Claude Code's usage, read through its status line
//! (https://code.claude.com/docs/en/statusline).
//!
//! Claude Code runs `statusLine.command` with the session's JSON on stdin
//! after every assistant message (debounced to 300 ms), after `/compact`,
//! and when a rate-limit window resets. Kumo starts each session with
//! `--settings <dir>/settings.json`, whose status line saves that JSON to
//! `<dir>/status.json` and then runs the user's own status line, if any,
//! so it still shows. `--settings` applies to that session only: the
//! user's settings files are never touched.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, PoisonError};
use std::time::{Duration, SystemTime};

use kumo_domain::agents::{
    AgentError, AgentSessionId, ContextReading, PlanReading, UsageReading, UsageSource,
    UsageTarget, UsageWindow,
};
use kumo_domain::time::Timestamp;
use serde_json::{Map, Value, json};

const SETTINGS: &str = "settings.json";
const STATUS: &str = "status.json";
/// A session folder untouched this long belongs to no session anymore.
const KEEP_FOR: Duration = Duration::from_secs(7 * 24 * 60 * 60);

/// [`UsageSource`] for Claude Code. One folder per session under `root`.
#[derive(Debug)]
pub struct ClaudeStatusLine {
    root: PathBuf,
    home: PathBuf,
    /// When each session's `status.json` was last read.
    seen: Mutex<HashMap<AgentSessionId, SystemTime>>,
}

impl ClaudeStatusLine {
    /// `root`: e.g. `<data_dir>/agents`. Folders nothing wrote to for
    /// [`KEEP_FOR`] are removed; recent ones stay, whatever ran them.
    pub fn new(root: &Path, home: &Path) -> Self {
        prune(root, SystemTime::now());
        Self {
            root: root.to_owned(),
            home: home.to_owned(),
            seen: Mutex::default(),
        }
    }

    fn dir(&self, id: &AgentSessionId) -> PathBuf {
        self.root.join(id.to_string())
    }
}

impl UsageSource for ClaudeStatusLine {
    fn provider_id(&self) -> &str {
        "claude"
    }

    fn launch_args(&self, target: &UsageTarget) -> Result<Vec<String>, AgentError> {
        // The hook is POSIX sh. On Windows, Claude Code runs status lines
        // through Git Bash or PowerShell, whichever it finds: no way to
        // know which, so nothing is read there.
        if cfg!(windows) {
            return Ok(Vec::new());
        }
        let dir = self.dir(&target.session_id);
        std::fs::create_dir_all(&dir).map_err(io_error)?;
        let theirs = user_status_line(&target.worktree, &self.home);
        let settings = settings_for(&dir, theirs);
        let path = dir.join(SETTINGS);
        std::fs::write(&path, settings.to_string()).map_err(io_error)?;
        Ok(vec!["--settings".into(), path.display().to_string()])
    }

    fn read(&self, target: &UsageTarget) -> Option<UsageReading> {
        let path = self.dir(&target.session_id).join(STATUS);
        let modified = std::fs::metadata(&path).and_then(|m| m.modified()).ok()?;
        {
            let mut seen = self.seen.lock().unwrap_or_else(PoisonError::into_inner);
            if seen.get(&target.session_id) == Some(&modified) {
                return None;
            }
            seen.insert(target.session_id.clone(), modified);
        }
        parse_status(&std::fs::read_to_string(path).ok()?)
    }

    fn forget(&self, target: &UsageTarget) {
        self.seen
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .remove(&target.session_id);
        let _ = std::fs::remove_dir_all(self.dir(&target.session_id));
    }
}

/// Removes the session folders under `root` last written before
/// `now - KEEP_FOR`. Every status update renames a file in its folder,
/// which touches the folder.
fn prune(root: &Path, now: SystemTime) {
    let Ok(entries) = std::fs::read_dir(root) else {
        return;
    };
    let Some(cutoff) = now.checked_sub(KEEP_FOR) else {
        return;
    };
    for entry in entries.flatten() {
        let old = entry
            .metadata()
            .and_then(|m| m.modified())
            .is_ok_and(|modified| modified < cutoff);
        if old && entry.file_type().is_ok_and(|t| t.is_dir()) {
            let _ = std::fs::remove_dir_all(entry.path());
        }
    }
}

/// The user's own `statusLine`, from the file that wins for the project:
/// project local, then shared project, then user settings.
pub fn user_status_line(project: &Path, home: &Path) -> Option<Map<String, Value>> {
    [
        project.join(".claude/settings.local.json"),
        project.join(".claude/settings.json"),
        home.join(".claude/settings.json"),
    ]
    .iter()
    .find_map(|file| {
        let settings: Value = serde_json::from_str(&std::fs::read_to_string(file).ok()?).ok()?;
        let line = settings.get("statusLine")?.as_object()?;
        line.get("command")
            .and_then(Value::as_str)
            .is_some_and(|c| !c.trim().is_empty())
            .then(|| line.clone())
    })
}

/// The session's settings: the user's status line (padding, refresh and
/// the rest kept) with its command wrapped by the hook, or Kumo's own.
pub fn settings_for(dir: &Path, theirs: Option<Map<String, Value>>) -> Value {
    let mut line = theirs.unwrap_or_default();
    let command = line
        .get("command")
        .and_then(Value::as_str)
        .map(str::to_owned);
    line.insert("type".into(), json!("command"));
    line.insert(
        "command".into(),
        json!(hook_command(dir, command.as_deref())),
    );
    json!({ "statusLine": line })
}

/// Saves stdin to `<dir>/status.json` (write, then rename, so a reader
/// never sees half of it), then prints a status line: the user's command
/// fed the same JSON, or a short one of Kumo's. Saving can't fail the
/// status line: its errors are ignored. stdin is read whole first, so a
/// user command that doesn't read it can't cut the saved copy short.
pub fn hook_command(dir: &Path, theirs: Option<&str>) -> String {
    let tmp = sh_quote(&dir.join(format!("{STATUS}.tmp")).display().to_string());
    let status = sh_quote(&dir.join(STATUS).display().to_string());
    let save = format!(
        "j=$(cat); {{ printf '%s\\n' \"$j\" > {tmp} && mv -f {tmp} {status}; }} 2>/dev/null; "
    );
    match theirs {
        // In a subshell of its own lines: `a; b` or a trailing comment
        // stay theirs.
        Some(command) => format!("{save}printf '%s\\n' \"$j\" | (\n{command}\n)"),
        None => format!("{save}printf '%s\\n' \"$j\" | {}", DEFAULT_LINE),
    }
}

/// `Opus · 59% context left`, or just the model early on. sed only (no
/// jq needed); `remaining_percentage` appears only in `context_window`.
const DEFAULT_LINE: &str = concat!(
    r#"sed -n -e 's/.*"display_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*"remaining_percentage"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1 · \2% context left/p' "#,
    r#"-e t -e 's/.*"display_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'"#,
);

/// Quotes for POSIX sh: `'…'`, with `'` as `'\''`.
pub fn sh_quote(raw: &str) -> String {
    format!("'{}'", raw.replace('\'', r"'\''"))
}

/// What a status line JSON says. Every field may be absent or null (early
/// in a session, right after `/compact`): what's missing is None.
pub fn parse_status(raw: &str) -> Option<UsageReading> {
    let status: Value = serde_json::from_str(raw).ok()?;
    let model = status
        .pointer("/model/display_name")
        .and_then(Value::as_str)
        .filter(|m| !m.trim().is_empty())
        .map(str::to_owned);
    Some(UsageReading {
        model,
        context: status.get("context_window").and_then(context_of),
        plan: status.get("rate_limits").and_then(plan_of),
    })
}

/// `current_usage` is null until the first API response and again right
/// after `/compact`: no reading then. Tokens are input only (with cache
/// reads and writes), as Claude Code's own `used_percentage` counts them.
fn context_of(window: &Value) -> Option<ContextReading> {
    let usage = window.get("current_usage").filter(|u| u.is_object())?;
    let max = window.get("context_window_size")?.as_u64()?;
    let tokens = match window.get("total_input_tokens").and_then(Value::as_u64) {
        Some(total) => total,
        None => [
            "input_tokens",
            "cache_creation_input_tokens",
            "cache_read_input_tokens",
        ]
        .iter()
        .filter_map(|k| usage.get(*k).and_then(Value::as_u64))
        .sum(),
    };
    (max > 0).then_some(ContextReading { max, tokens })
}

/// Present only on Pro/Max/Ultra (or behind a gateway's spend limit), and
/// only after the first response. Each window may be absent on its own;
/// Claude Code drops one once it resets. Which plan it is isn't said.
fn plan_of(limits: &Value) -> Option<PlanReading> {
    let limits = limits.as_object()?;
    let mut windows = Vec::new();
    for (key, minutes) in [("five_hour", 300), ("seven_day", 7 * 24 * 60)] {
        if let Some((used, resets_at)) = limits.get(key).and_then(used_and_reset) {
            windows.push(UsageWindow::percent_over_minutes(minutes, used, resets_at));
        }
    }
    // Behind a Claude apps gateway. Its dollar amounts are estimates that
    // lag the percentage: the percentage is what's shown.
    if let Some(spend) = limits.get("spend_limit")
        && let Some((used, resets_at)) = used_and_reset(spend)
    {
        let period = spend.get("period").and_then(Value::as_str);
        let label = match period {
            Some(period) => format!("Spend limit · {period}"),
            None => "Spend limit".to_owned(),
        };
        let short = match period {
            Some("monthly") => "mo",
            Some("weekly") => "wk",
            Some("daily") => "day",
            _ => "$",
        };
        windows.push(UsageWindow::percent_used(label, short, used, resets_at));
    }
    Some(PlanReading {
        plan: String::new(),
        windows,
    })
}

fn used_and_reset(window: &Value) -> Option<(f64, Option<Timestamp>)> {
    let used = window.get("used_percentage")?.as_f64()?;
    let resets_at = window
        .get("resets_at")
        .and_then(Value::as_u64)
        .filter(|s| *s > 0)
        .map(|s| Timestamp::from_unix_nanos(s.saturating_mul(1_000_000_000)));
    Some((used, resets_at))
}

fn io_error(error: std::io::Error) -> AgentError {
    AgentError::Launch(format!("can't prepare the usage reading: {error}"))
}

#[cfg(test)]
mod tests {
    use std::process::{Command, Stdio};

    use super::*;
    use kumo_domain::agents::UsageUnit;

    /// The full example from the status line docs.
    const DOCS_EXAMPLE: &str = r#"{
      "cwd": "/current/working/directory",
      "session_id": "abc123...",
      "model": { "id": "claude-opus-5-5", "display_name": "Opus" },
      "workspace": { "current_dir": "/current/working/directory", "project_dir": "/original/project/directory", "added_dirs": [] },
      "version": "2.1.90",
      "cost": { "total_cost_usd": 0.01234, "total_duration_ms": 45000 },
      "context_window": {
        "total_input_tokens": 15500,
        "total_output_tokens": 1200,
        "context_window_size": 200000,
        "used_percentage": 8,
        "remaining_percentage": 92,
        "current_usage": {
          "input_tokens": 8500,
          "output_tokens": 1200,
          "cache_creation_input_tokens": 5000,
          "cache_read_input_tokens": 2000
        }
      },
      "exceeds_200k_tokens": false,
      "rate_limits": {
        "five_hour": { "used_percentage": 23.5, "resets_at": 1738425600 },
        "seven_day": { "used_percentage": 41.2, "resets_at": 1738857600 },
        "spend_limit": {
          "used_percentage": 62.8,
          "resets_at": 1740787200,
          "used_usd": 314.12,
          "limit_usd": 500,
          "period": "monthly"
        }
      }
    }"#;

    fn secs(s: u64) -> Option<Timestamp> {
        Some(Timestamp::from_unix_nanos(s * 1_000_000_000))
    }

    #[test]
    fn reads_the_documented_example() {
        let reading = parse_status(DOCS_EXAMPLE).unwrap();
        assert_eq!(reading.model.as_deref(), Some("Opus"));
        assert_eq!(
            reading.context,
            Some(ContextReading {
                max: 200_000,
                tokens: 15_500
            })
        );
        let plan = reading.plan.unwrap();
        assert_eq!(plan.plan, "", "Pro or Max isn't said");
        let windows: Vec<_> = plan
            .windows
            .iter()
            .map(|w| (w.label.as_str(), w.short.as_str(), w.left, w.resets_at))
            .collect();
        assert_eq!(
            windows,
            [
                ("5-hour session", "5h", 76.5, secs(1_738_425_600)),
                ("Weekly", "wk", 100.0 - 41.2, secs(1_738_857_600)),
                (
                    "Spend limit · monthly",
                    "mo",
                    100.0 - 62.8,
                    secs(1_740_787_200)
                ),
            ]
        );
        assert!(plan.windows.iter().all(|w| w.unit == UsageUnit::Percent));
    }

    #[test]
    fn early_in_a_session_and_after_compact_nothing_is_made_up() {
        // Before the first API response: nulls, no rate limits.
        let early = parse_status(
            r#"{"model":{"display_name":"Sonnet"},"context_window":{"total_input_tokens":0,
                "context_window_size":200000,"used_percentage":null,"remaining_percentage":null,
                "current_usage":null}}"#,
        )
        .unwrap();
        assert_eq!(
            early,
            UsageReading {
                model: Some("Sonnet".into()),
                context: None,
                plan: None,
            }
        );
        // An API key user: no rate_limits at all; one window may be absent.
        let partial = parse_status(
            r#"{"context_window":{"context_window_size":1000000,"current_usage":{"input_tokens":10,
                "cache_read_input_tokens":5}},"rate_limits":{"seven_day":{"used_percentage":3}}}"#,
        )
        .unwrap();
        assert_eq!(partial.model, None);
        assert_eq!(
            partial.context,
            Some(ContextReading {
                max: 1_000_000,
                tokens: 15
            })
        );
        let windows = partial.plan.unwrap().windows;
        assert_eq!(windows.len(), 1);
        assert_eq!(
            (windows[0].short.as_str(), windows[0].resets_at),
            ("wk", None)
        );
        assert_eq!(parse_status("not json"), None);
        assert_eq!(parse_status("{}"), Some(UsageReading::default()));
    }

    #[test]
    fn quotes_paths_for_the_shell() {
        assert_eq!(sh_quote("/a b/c"), "'/a b/c'");
        assert_eq!(sh_quote("it's"), r"'it'\''s'");
        let hook = hook_command(
            Path::new("/Users/me/Application Support/kumo/agents/x"),
            None,
        );
        assert!(
            hook.contains(
                "> '/Users/me/Application Support/kumo/agents/x/status.json.tmp' && mv -f"
            ),
            "{hook}"
        );
    }

    /// Runs `command` in sh with `input` on stdin, as Claude Code does.
    fn run(command: &str, input: &str) -> String {
        use std::io::Write;
        let mut child = Command::new("sh")
            .arg("-c")
            .arg(command)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        child
            .stdin
            .take()
            .unwrap()
            .write_all(input.as_bytes())
            .unwrap();
        let out = child.wait_with_output().unwrap();
        assert!(
            out.stderr.is_empty(),
            "{}",
            String::from_utf8_lossy(&out.stderr)
        );
        String::from_utf8(out.stdout).unwrap()
    }

    #[cfg(unix)]
    #[test]
    fn the_hook_saves_the_json_and_passes_it_to_the_user_s_status_line() {
        let base = tempfile::tempdir().unwrap();
        let dir = base.path().join("it's a dir");
        std::fs::create_dir_all(&dir).unwrap();
        let compact = r#"{"model":{"display_name":"Opus"},"context_window":{"remaining_percentage":59,"used_percentage":41},"rate_limits":{"five_hour":{"used_percentage":12}}}"#;

        // Theirs: several commands and a trailing comment, reading stdin.
        let theirs = "printf 'mine: '; grep -o '\"Opus\"' # the model";
        let printed = run(&hook_command(&dir, Some(theirs)), compact);
        assert_eq!(printed, "mine: \"Opus\"\n");
        let saved = std::fs::read_to_string(dir.join(STATUS)).unwrap();
        assert_eq!(saved.trim_end(), compact);
        assert!(!dir.join("status.json.tmp").exists());

        // Theirs ignores stdin: the saved copy is still whole.
        std::fs::remove_file(dir.join(STATUS)).unwrap();
        let big = format!(r#"{{"pad":"{}"}}"#, "x".repeat(256 * 1024));
        assert_eq!(run(&hook_command(&dir, Some("echo hi")), &big), "hi\n");
        assert_eq!(
            std::fs::read_to_string(dir.join(STATUS))
                .unwrap()
                .trim_end(),
            big
        );

        // Kumo's own line.
        assert_eq!(
            run(&hook_command(&dir, None), compact),
            "Opus · 59% context left\n"
        );
        assert_eq!(
            run(
                &hook_command(&dir, None),
                r#"{"model":{"display_name":"Opus"}}"#
            ),
            "Opus\n"
        );

        // Saving fails (the folder is gone): the status line still shows.
        let gone = base.path().join("gone");
        assert_eq!(
            run(
                &hook_command(&gone, Some("cat >/dev/null; echo ok")),
                compact
            ),
            "ok\n"
        );
    }

    #[test]
    fn keeps_the_user_s_status_line_from_the_winning_settings_file() {
        let home = tempfile::tempdir().unwrap();
        let project = tempfile::tempdir().unwrap();
        assert_eq!(user_status_line(project.path(), home.path()), None);

        std::fs::create_dir_all(home.path().join(".claude")).unwrap();
        std::fs::write(
            home.path().join(".claude/settings.json"),
            r#"{"statusLine":{"type":"command","command":"~/.claude/statusline.sh","padding":2}}"#,
        )
        .unwrap();
        let theirs = user_status_line(project.path(), home.path()).unwrap();
        assert_eq!(theirs["command"], "~/.claude/statusline.sh");

        std::fs::create_dir_all(project.path().join(".claude")).unwrap();
        std::fs::write(
            project.path().join(".claude/settings.json"),
            r#"{"statusLine":{"type":"command","command":"project-line"}}"#,
        )
        .unwrap();
        assert_eq!(
            user_status_line(project.path(), home.path()).unwrap()["command"],
            "project-line"
        );

        let dir = Path::new("/data/agents/s1");
        let settings = settings_for(dir, Some(theirs));
        assert_eq!(settings["statusLine"]["padding"], 2, "the rest is kept");
        let command = settings["statusLine"]["command"].as_str().unwrap();
        assert!(
            command.ends_with("| (\n~/.claude/statusline.sh\n)"),
            "{command}"
        );
        let own = settings_for(dir, None);
        assert_eq!(own["statusLine"]["type"], "command");
        assert!(
            own["statusLine"]["command"]
                .as_str()
                .unwrap()
                .contains("sed -n")
        );
    }

    #[test]
    fn only_folders_untouched_for_a_week_are_pruned() {
        let root = tempfile::tempdir().unwrap();
        std::fs::create_dir(root.path().join("s1")).unwrap();
        std::fs::write(root.path().join("s1").join(STATUS), "{}").unwrap();
        std::fs::write(root.path().join("stray-file"), "").unwrap();

        // Starting again now (a quick restart): everything stays.
        let home = tempfile::tempdir().unwrap();
        ClaudeStatusLine::new(root.path(), home.path());
        prune(
            root.path(),
            SystemTime::now() + Duration::from_secs(6 * 24 * 60 * 60),
        );
        assert!(root.path().join("s1").join(STATUS).exists());

        // Eight days later: the folder goes, anything else stays.
        prune(
            root.path(),
            SystemTime::now() + Duration::from_secs(8 * 24 * 60 * 60),
        );
        assert!(!root.path().join("s1").exists());
        assert!(root.path().join("stray-file").exists());
        prune(&root.path().join("missing"), SystemTime::now());
    }

    #[cfg(unix)]
    #[test]
    fn a_session_is_read_once_per_update_and_cleaned_up() {
        let data = tempfile::tempdir().unwrap();
        let home = tempfile::tempdir().unwrap();
        let source = ClaudeStatusLine::new(&data.path().join("agents"), home.path());
        let target = UsageTarget {
            session_id: AgentSessionId::parse("s1").unwrap(),
            worktree: home.path().to_owned(),
            started_at: Timestamp::now(),
        };
        let args = source.launch_args(&target).unwrap();
        assert_eq!(args[0], "--settings");
        let settings: Value =
            serde_json::from_str(&std::fs::read_to_string(&args[1]).unwrap()).unwrap();
        let hook = settings["statusLine"]["command"].as_str().unwrap();
        assert_eq!(source.read(&target), None, "nothing reported yet");

        run(hook, DOCS_EXAMPLE);
        assert_eq!(source.read(&target).unwrap().model.as_deref(), Some("Opus"));
        assert_eq!(source.read(&target), None, "unchanged since");

        source.forget(&target);
        assert!(!data.path().join("agents/s1").exists());
    }
}
