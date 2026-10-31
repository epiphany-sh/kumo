//! Codex CLI's usage, read from its session rollout files.
//!
//! Each session writes `<codex home>/sessions/YYYY/MM/DD/rollout-*.jsonl`
//! (checked on codex-cli 0.157). The first line is `session_meta` (the
//! session's `cwd` and start); `event_msg` lines of type `token_count`
//! carry the context window and the plan's rate limits. Rollouts left
//! untouched for days are compressed to `.jsonl.zst`: a running session's
//! is always plain.

use std::collections::{HashMap, HashSet};
use std::fs::File;
use std::io::{BufRead, BufReader, Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::sync::{Mutex, PoisonError};
use std::time::Duration;

use kumo_domain::agents::{
    AgentError, AgentSessionId, ContextReading, PlanReading, UsageReading, UsageSource,
    UsageTarget, UsageWindow,
};
use kumo_domain::time::Timestamp;
use serde_json::Value;

/// Day folders searched for a new session's rollout, newest first.
const DAYS_SEARCHED: usize = 3;
/// A rollout may start a little before Kumo noted the session's start.
const START_SLACK: Duration = Duration::from_secs(5);

/// Where Codex keeps its data: `$CODEX_HOME`, else `~/.codex`.
pub fn codex_home(home: &Path) -> PathBuf {
    std::env::var_os("CODEX_HOME")
        .filter(|v| !v.is_empty())
        .map_or_else(|| home.join(".codex"), PathBuf::from)
}

/// [`UsageSource`] for Codex CLI.
#[derive(Debug)]
pub struct CodexRollouts {
    sessions: PathBuf,
    tails: Mutex<HashMap<AgentSessionId, Tail>>,
}

/// How far a session's rollout has been read.
#[derive(Debug)]
struct Tail {
    path: PathBuf,
    offset: u64,
}

impl CodexRollouts {
    pub fn new(codex_home: &Path) -> Self {
        Self {
            sessions: codex_home.join("sessions"),
            tails: Mutex::default(),
        }
    }
}

impl UsageSource for CodexRollouts {
    fn provider_id(&self) -> &str {
        "codex"
    }

    fn launch_args(&self, _target: &UsageTarget) -> Result<Vec<String>, AgentError> {
        Ok(Vec::new())
    }

    fn read(&self, target: &UsageTarget) -> Option<UsageReading> {
        let mut tails = self.tails.lock().unwrap_or_else(PoisonError::into_inner);
        if !tails.contains_key(&target.session_id) {
            let taken: HashSet<PathBuf> = tails.values().map(|t| t.path.clone()).collect();
            let path = find_rollout(&self.sessions, &target.worktree, target.started_at, &taken)?;
            tails.insert(target.session_id.clone(), Tail { path, offset: 0 });
        }
        let tail = tails.get_mut(&target.session_id)?;
        let (reading, read) = read_from(&tail.path, tail.offset).ok()?;
        tail.offset += read;
        (!reading.is_empty()).then_some(reading)
    }

    fn forget(&self, target: &UsageTarget) {
        self.tails
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .remove(&target.session_id);
    }
}

/// The newest rollout of a session in `worktree` that started after
/// `started_at` (less [`START_SLACK`]), skipping those already taken by
/// other Kumo sessions.
pub fn find_rollout(
    sessions: &Path,
    worktree: &Path,
    started_at: Timestamp,
    taken: &HashSet<PathBuf>,
) -> Option<PathBuf> {
    let worktree = canonical(worktree);
    let earliest = started_at
        .as_unix_nanos()
        .saturating_sub(u64::try_from(START_SLACK.as_nanos()).unwrap_or(0));
    newest_days(sessions)
        .into_iter()
        .flat_map(|day| entries(&day))
        .filter(|path| {
            path.file_name()
                .and_then(|n| n.to_str())
                .is_some_and(|n| n.starts_with("rollout-") && n.ends_with(".jsonl"))
                && !taken.contains(path)
        })
        .filter_map(|path| {
            let (cwd, started) = session_meta(&first_line(&path)?)?;
            (canonical(&cwd) == worktree && started.as_unix_nanos() >= earliest)
                .then_some((started, path))
        })
        .max_by_key(|(started, _)| *started)
        .map(|(_, path)| path)
}

/// `sessions/YYYY/MM/DD` folders, newest first.
fn newest_days(sessions: &Path) -> Vec<PathBuf> {
    let mut days = Vec::new();
    for year in entries(sessions).into_iter().rev() {
        for month in entries(&year).into_iter().rev() {
            for day in entries(&month).into_iter().rev() {
                days.push(day);
                if days.len() == DAYS_SEARCHED {
                    return days;
                }
            }
        }
    }
    days
}

/// Sorted by name.
fn entries(dir: &Path) -> Vec<PathBuf> {
    let mut paths: Vec<PathBuf> = std::fs::read_dir(dir)
        .map(|it| it.filter_map(|e| e.ok().map(|e| e.path())).collect())
        .unwrap_or_default();
    paths.sort();
    paths
}

fn canonical(path: &Path) -> PathBuf {
    std::fs::canonicalize(path).unwrap_or_else(|_| path.to_owned())
}

fn first_line(path: &Path) -> Option<String> {
    let mut line = String::new();
    BufReader::new(File::open(path).ok()?)
        .read_line(&mut line)
        .ok()?;
    Some(line)
}

/// `cwd` and start of a `session_meta` line.
pub fn session_meta(line: &str) -> Option<(PathBuf, Timestamp)> {
    let meta: Value = serde_json::from_str(line).ok()?;
    if meta.get("type")?.as_str()? != "session_meta" {
        return None;
    }
    let payload = meta.get("payload")?;
    let cwd = PathBuf::from(payload.get("cwd")?.as_str()?);
    let started = parse_utc(payload.get("timestamp")?.as_str()?)?;
    Some((cwd, started))
}

/// What the complete lines from `offset` on report, and how many bytes
/// they took (a line still being written waits for the next read).
fn read_from(path: &Path, offset: u64) -> std::io::Result<(UsageReading, u64)> {
    let mut file = File::open(path)?;
    file.seek(SeekFrom::Start(offset))?;
    let mut bytes = Vec::new();
    file.read_to_end(&mut bytes)?;
    let complete = bytes.iter().rposition(|b| *b == b'\n').map_or(0, |i| i + 1);
    let reading = String::from_utf8_lossy(&bytes[..complete])
        .lines()
        .fold(UsageReading::default(), |reading, line| {
            reading.merged(parse_line(line))
        });
    Ok((reading, complete as u64))
}

/// What one rollout line reports: the model (`turn_context`) or the
/// context window and plan (`token_count`).
pub fn parse_line(line: &str) -> UsageReading {
    // Most lines are neither, and some are large.
    if !line.contains("\"token_count\"") && !line.contains("\"turn_context\"") {
        return UsageReading::default();
    }
    let Ok(item) = serde_json::from_str::<Value>(line) else {
        return UsageReading::default();
    };
    let Some(payload) = item.get("payload") else {
        return UsageReading::default();
    };
    match item.get("type").and_then(Value::as_str) {
        Some("turn_context") => UsageReading {
            model: payload
                .get("model")
                .and_then(Value::as_str)
                .filter(|m| !m.is_empty())
                .map(str::to_owned),
            ..UsageReading::default()
        },
        Some("event_msg") if payload.get("type").and_then(Value::as_str) == Some("token_count") => {
            UsageReading {
                model: None,
                context: payload.get("info").and_then(context_of),
                plan: payload.get("rate_limits").and_then(plan_of),
            }
        }
        _ => UsageReading::default(),
    }
}

/// `last_token_usage.total_tokens` over `model_context_window`: what
/// Codex's own `/status` shows as "used / window" (input, cached input
/// and output of the latest turn).
fn context_of(info: &Value) -> Option<ContextReading> {
    let max = info.get("model_context_window")?.as_u64()?;
    let tokens = info.pointer("/last_token_usage/total_tokens")?.as_u64()?;
    (max > 0).then_some(ContextReading { max, tokens })
}

/// Only the plan's own limits (`limit_id` "codex", or none on older
/// versions), as Codex's footer shows them: other buckets, such as a
/// model's reserve, are left out.
fn plan_of(limits: &Value) -> Option<PlanReading> {
    match limits.get("limit_id").and_then(Value::as_str) {
        None | Some("codex") => {}
        Some(_) => return None,
    }
    let windows: Vec<UsageWindow> = ["primary", "secondary"]
        .iter()
        .filter_map(|key| {
            let window = limits.get(*key)?;
            let used = window.get("used_percent")?.as_f64()?;
            let minutes = window.get("window_minutes")?.as_u64()?;
            let resets_at = window
                .get("resets_at")
                .and_then(Value::as_u64)
                .filter(|s| *s > 0)
                .map(|s| Timestamp::from_unix_nanos(s.saturating_mul(1_000_000_000)));
            Some(UsageWindow::percent_over_minutes(minutes, used, resets_at))
        })
        .collect();
    if windows.is_empty() {
        return None;
    }
    let plan = limits
        .get("plan_type")
        .and_then(Value::as_str)
        .map(plan_name)
        .unwrap_or_default();
    Some(PlanReading { plan, windows })
}

/// "plus" → "ChatGPT Plus".
fn plan_name(plan_type: &str) -> String {
    let mut chars = plan_type.chars();
    match chars.next() {
        Some(first) if plan_type != "unknown" => {
            format!("ChatGPT {}{}", first.to_uppercase(), chars.as_str())
        }
        _ => String::new(),
    }
}

/// `2026-09-26T00:05:25.622Z` (UTC, as Codex writes it).
pub fn parse_utc(raw: &str) -> Option<Timestamp> {
    let raw = raw.strip_suffix('Z')?;
    let (date, time) = raw.split_once('T')?;
    let mut date = date.splitn(3, '-').map(str::parse::<i64>);
    let (y, m, d) = (date.next()?.ok()?, date.next()?.ok()?, date.next()?.ok()?);
    let (hms, fraction) = time.split_once('.').unwrap_or((time, ""));
    let mut hms = hms.splitn(3, ':').map(str::parse::<i64>);
    let (hh, mm, ss) = (hms.next()?.ok()?, hms.next()?.ok()?, hms.next()?.ok()?);
    if !(1..=12).contains(&m) || !(1..=31).contains(&d) || hh > 23 || mm > 59 || ss > 60 {
        return None;
    }
    // Days from the civil date (Howard Hinnant's algorithm).
    let y = if m <= 2 { y - 1 } else { y };
    let era = y.div_euclid(400);
    let yoe = y - era * 400;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    let days = era * 146_097 + doe - 719_468;
    let secs = days * 86_400 + hh * 3_600 + mm * 60 + ss;
    let nanos = format!("{fraction:0<9}").get(..9)?.parse::<i64>().ok()?;
    let total = secs.checked_mul(1_000_000_000)?.checked_add(nanos)?;
    u64::try_from(total).ok().map(Timestamp::from_unix_nanos)
}

#[cfg(test)]
mod tests {
    use std::io::Write;

    use super::*;

    /// A `token_count` line as codex-cli 0.157 writes it.
    const TOKEN_COUNT: &str = r#"{"timestamp":"2026-09-26T00:14:16.737Z","ordinal":18,"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":45207,"cached_input_tokens":29056,"cache_write_input_tokens":0,"output_tokens":430,"reasoning_output_tokens":60,"total_tokens":45637},"last_token_usage":{"input_tokens":23823,"cached_input_tokens":21248,"cache_write_input_tokens":0,"output_tokens":260,"reasoning_output_tokens":15,"total_tokens":24083},"model_context_window":258400},"rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":25.0,"window_minutes":300,"resets_at":1790387720},"secondary":{"used_percent":4.0,"window_minutes":10080,"resets_at":1790974520},"credits":{"has_credits":false,"unlimited":false,"balance":"0"},"individual_limit":null,"spend_control_reached":null,"plan_type":"plus","rate_limit_reached_type":null}}}"#;

    fn secs(s: u64) -> Option<Timestamp> {
        Some(Timestamp::from_unix_nanos(s * 1_000_000_000))
    }

    fn meta(cwd: &Path, at: &str) -> String {
        serde_json::json!({
            "timestamp": at,
            "ordinal": 0,
            "type": "session_meta",
            "payload": {
                "session_id": "x",
                "id": "x",
                "timestamp": at,
                "cwd": cwd,
                "originator": "codex-tui",
                "cli_version": "0.157.0",
            },
        })
        .to_string()
    }

    #[test]
    fn reads_a_token_count_line() {
        let reading = parse_line(TOKEN_COUNT);
        assert_eq!(
            reading.context,
            Some(ContextReading {
                max: 258_400,
                tokens: 24_083
            })
        );
        let plan = reading.plan.unwrap();
        assert_eq!(plan.plan, "ChatGPT Plus");
        let windows: Vec<_> = plan
            .windows
            .iter()
            .map(|w| (w.label.as_str(), w.short.as_str(), w.left, w.resets_at))
            .collect();
        assert_eq!(
            windows,
            [
                ("5-hour session", "5h", 75.0, secs(1_790_387_720)),
                ("Weekly", "wk", 96.0, secs(1_790_974_520)),
            ]
        );
    }

    #[test]
    fn absent_and_null_fields_report_nothing() {
        // The first token_count of a session: no usage yet.
        let early = parse_line(
            r#"{"type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":null}}"#,
        );
        assert!(early.is_empty());
        // Only the weekly window, labelled from its length.
        let weekly = parse_line(
            r#"{"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":10},"model_context_window":null},"rate_limits":{"primary":{"used_percent":0.0,"window_minutes":10080,"resets_at":null},"secondary":null}}}"#,
        );
        assert_eq!(weekly.context, None);
        let plan = weekly.plan.unwrap();
        assert_eq!(plan.plan, "", "no plan_type");
        assert_eq!(
            (plan.windows.len(), plan.windows[0].label.as_str()),
            (1, "Weekly")
        );
        assert_eq!(plan.windows[0].resets_at, None);
        // Another bucket (a model's reserve) isn't the plan's.
        let reserve = parse_line(&TOKEN_COUNT.replace(
            r#""limit_id":"codex""#,
            r#""limit_id":"base_model_inference""#,
        ));
        assert!(reserve.plan.is_none() && reserve.context.is_some());
        let model = parse_line(
            r#"{"type":"turn_context","payload":{"cwd":"/x","model":"gpt-6-sol","effort":"high"}}"#,
        );
        assert_eq!(model.model.as_deref(), Some("gpt-6-sol"));
        assert!(parse_line(r#"{"type":"response_item","payload":{}}"#).is_empty());
        assert!(parse_line("{\"token_count\" broken").is_empty());
    }

    #[test]
    fn parses_codex_timestamps() {
        assert_eq!(
            parse_utc("1970-01-01T00:00:01Z"),
            Some(Timestamp::from_unix_nanos(1_000_000_000))
        );
        assert_eq!(
            parse_utc("2026-09-26T00:05:25.622Z"),
            Some(Timestamp::from_unix_nanos(1_790_381_125_622_000_000))
        );
        assert_eq!(parse_utc("2026-09-26T00:05:25"), None, "no zone");
        assert_eq!(parse_utc("garbage"), None);
    }

    fn write_rollout(sessions: &Path, day: &str, name: &str, lines: &[String]) -> PathBuf {
        let dir = sessions.join(day);
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join(name);
        std::fs::write(&path, lines.join("\n") + "\n").unwrap();
        path
    }

    #[test]
    fn matches_the_session_to_its_rollout_by_worktree_and_start() {
        let home = tempfile::tempdir().unwrap();
        let sessions = home.path().join("sessions");
        let wt = home.path().join("wt");
        let other = home.path().join("other");
        std::fs::create_dir_all(&wt).unwrap();
        std::fs::create_dir_all(&other).unwrap();
        let started = parse_utc("2026-10-30T12:00:00Z").unwrap();

        // Before the session (an earlier run), another worktree, compressed.
        write_rollout(
            &sessions,
            "2026/10/30",
            "rollout-a.jsonl",
            &[meta(&wt, "2026-10-30T11:00:00Z")],
        );
        write_rollout(
            &sessions,
            "2026/10/30",
            "rollout-b.jsonl",
            &[meta(&other, "2026-10-30T12:00:03Z")],
        );
        write_rollout(
            &sessions,
            "2026/10/30",
            "rollout-c.jsonl.zst",
            &[meta(&wt, "2026-10-30T12:00:04Z")],
        );
        let none = HashSet::new();
        assert_eq!(find_rollout(&sessions, &wt, started, &none), None);

        let first = write_rollout(
            &sessions,
            "2026/10/30",
            "rollout-d.jsonl",
            &[meta(&wt, "2026-10-30T12:00:02Z")],
        );
        // Past midnight, in the next day's folder: the newest wins.
        let second = write_rollout(
            &sessions,
            "2026/10/31",
            "rollout-e.jsonl",
            &[meta(&wt, "2026-10-30T12:30:00Z")],
        );
        assert_eq!(
            find_rollout(&sessions, &wt, started, &none),
            Some(second.clone())
        );
        // One taken by another Kumo session is skipped.
        let taken = HashSet::from([second]);
        assert_eq!(find_rollout(&sessions, &wt, started, &taken), Some(first));
        assert_eq!(
            find_rollout(&home.path().join("nope"), &wt, started, &none),
            None
        );
    }

    #[test]
    fn tails_the_rollout_and_keeps_the_last_reading() {
        let home = tempfile::tempdir().unwrap();
        let wt = home.path().join("wt");
        std::fs::create_dir_all(&wt).unwrap();
        let source = CodexRollouts::new(home.path());
        let target = UsageTarget {
            session_id: AgentSessionId::parse("s1").unwrap(),
            worktree: wt.clone(),
            started_at: parse_utc("2026-10-30T12:00:00Z").unwrap(),
        };
        assert_eq!(source.read(&target), None, "no rollout yet");

        let path = write_rollout(
            &home.path().join("sessions"),
            "2026/10/30",
            "rollout-x.jsonl",
            &[
                meta(&wt, "2026-10-30T12:00:01Z"),
                r#"{"type":"turn_context","payload":{"model":"gpt-6-sol"}}"#.into(),
                TOKEN_COUNT.into(),
            ],
        );
        let first = source.read(&target).unwrap();
        assert_eq!(first.model.as_deref(), Some("gpt-6-sol"));
        assert_eq!(first.context.unwrap().tokens, 24_083);
        assert_eq!(source.read(&target), None, "nothing new");

        // A line still being written waits until it's whole.
        let newer = TOKEN_COUNT.replace("24083", "30000");
        let (head, rest) = newer.split_at(40);
        let mut file = std::fs::OpenOptions::new()
            .append(true)
            .open(&path)
            .unwrap();
        file.write_all(head.as_bytes()).unwrap();
        assert_eq!(source.read(&target), None);
        writeln!(file, "{rest}").unwrap();
        let second = source.read(&target).unwrap();
        assert_eq!(
            (second.model, second.context.unwrap().tokens),
            (None, 30_000)
        );
    }
}
