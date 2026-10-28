//! GitHub Issues through the user's own `gh` CLI: its sign-in, its hosts;
//! Kumo never sees a GitHub token.

use std::io::Read;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::Arc;
use std::time::{Duration, Instant};

use kumo_domain::agents::ProgramLocator;
use kumo_domain::tasks::{
    Detected, Priority, SourceKind, SourceOptions, Task, TaskConnector, TaskError, TaskId,
    TaskSource, TaskStatus,
};
use serde_json::Value;

use super::dates::parse_timestamp;

const MAX_ISSUES: &str = "500";
const TIMEOUT: Duration = Duration::from_secs(60);

pub struct GitHubConnector {
    locator: Arc<dyn ProgramLocator>,
}

impl std::fmt::Debug for GitHubConnector {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("GitHubConnector").finish_non_exhaustive()
    }
}

impl GitHubConnector {
    pub fn new(locator: Arc<dyn ProgramLocator>) -> Self {
        Self { locator }
    }

    /// Runs `gh` with the user's PATH and without prompts; stdout on success.
    fn gh(&self, args: &[&str]) -> Result<String, TaskError> {
        let program = self.locator.locate("gh").ok_or_else(|| {
            TaskError::Unavailable(
                "the GitHub CLI (gh) isn't installed: get it from cli.github.com".into(),
            )
        })?;
        let mut child = Command::new(program)
            .args(args)
            .env("PATH", self.locator.search_path())
            .env("GH_PROMPT_DISABLED", "1")
            .env("GH_NO_UPDATE_NOTIFIER", "1")
            .env("NO_COLOR", "1")
            .current_dir(self.locator.home())
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| TaskError::Unavailable(format!("can't run gh: {e}")))?;
        let drain = |pipe: Option<Box<dyn Read + Send>>| {
            std::thread::spawn(move || {
                let mut out = String::new();
                if let Some(mut pipe) = pipe {
                    let _ = pipe.read_to_string(&mut out);
                }
                out
            })
        };
        let stdout = drain(
            child
                .stdout
                .take()
                .map(|p| Box::new(p) as Box<dyn Read + Send>),
        );
        let stderr = drain(
            child
                .stderr
                .take()
                .map(|p| Box::new(p) as Box<dyn Read + Send>),
        );
        let started = Instant::now();
        let status = loop {
            match child.try_wait() {
                Ok(Some(status)) => break status,
                Ok(None) if started.elapsed() > TIMEOUT => {
                    let _ = child.kill();
                    let _ = child.wait();
                    return Err(TaskError::Unavailable("gh took too long to answer".into()));
                }
                Ok(None) => std::thread::sleep(Duration::from_millis(20)),
                Err(e) => return Err(TaskError::Unavailable(format!("gh failed: {e}"))),
            }
        };
        let (stdout, stderr) = (
            stdout.join().unwrap_or_default(),
            stderr.join().unwrap_or_default(),
        );
        if status.success() {
            return Ok(stdout);
        }
        let message = stderr.trim();
        let lower = message.to_lowercase();
        if lower.contains("gh auth login")
            || lower.contains("not logged")
            || lower.contains("authentication")
        {
            Err(TaskError::Auth(
                "sign in to GitHub first: run `gh auth login` in a terminal".into(),
            ))
        } else if lower.contains("could not resolve")
            || lower.contains("connect")
            || lower.contains("timeout")
        {
            Err(TaskError::Unavailable(format!(
                "can't reach GitHub: {message}"
            )))
        } else {
            Err(TaskError::Source(format!("gh: {}", first_line(message))))
        }
    }

    fn query(source: &TaskSource) -> Result<&str, TaskError> {
        match &source.options {
            SourceOptions::GitHub { query } => Ok(query),
            _ => Err(TaskError::Invalid("not a GitHub source".into())),
        }
    }
}

impl TaskConnector for GitHubConnector {
    fn kind(&self) -> SourceKind {
        SourceKind::GitHub
    }

    fn fetch(&self, source: &TaskSource, _secret: Option<&str>) -> Result<Vec<Task>, TaskError> {
        let query = Self::query(source)?;
        let out = self.gh(&[
            "search",
            "issues",
            "--json",
            "number,title,state,url,repository,labels,updatedAt,isPullRequest",
            "--limit",
            MAX_ISSUES,
            "--",
            query,
        ])?;
        let issues: Vec<Value> = serde_json::from_str(&out)
            .map_err(|e| TaskError::Source(format!("gh answered something unexpected: {e}")))?;
        Ok(issues
            .iter()
            .filter_map(|issue| to_task(source, issue))
            .collect())
    }

    fn set_status(
        &self,
        source: &TaskSource,
        _secret: Option<&str>,
        task: &Task,
        status: TaskStatus,
    ) -> Result<(), TaskError> {
        let action = match status {
            TaskStatus::Done => "close",
            TaskStatus::Todo => "reopen",
            status => {
                return Err(TaskError::Unsupported {
                    kind: source.kind(),
                    status,
                });
            }
        };
        let url = task
            .url
            .as_deref()
            .filter(|u| u.starts_with("https://"))
            .ok_or_else(|| TaskError::UnknownTask(task.id.to_string()))?;
        self.gh(&["issue", action, url]).map(drop)
    }

    fn test(&self, source: &TaskSource, _secret: Option<&str>) -> Result<String, TaskError> {
        Self::query(source)?;
        let login = self.gh(&["api", "user", "--jq", ".login"])?;
        Ok(format!("signed in as {}", login.trim()))
    }

    fn watched_paths(&self, _source: &TaskSource) -> Vec<PathBuf> {
        vec![]
    }

    fn detect(&self) -> Vec<Detected> {
        // Only when gh is installed and signed in: nothing to configure.
        match self.gh(&["auth", "status", "--active"]) {
            Ok(_) => vec![Detected {
                name: "GitHub".into(),
                options: SourceOptions::GitHub {
                    query: SourceOptions::GITHUB_QUERY.into(),
                },
            }],
            Err(_) => vec![],
        }
    }
}

fn to_task(source: &TaskSource, issue: &Value) -> Option<Task> {
    if issue.get("isPullRequest").and_then(Value::as_bool) == Some(true) {
        return None;
    }
    let number = issue.get("number")?.as_u64()?;
    let repo = issue
        .pointer("/repository/nameWithOwner")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let labels: Vec<String> = issue
        .get("labels")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|l| l.get("name")?.as_str().map(str::to_owned))
        .collect();
    let closed = issue
        .get("state")
        .and_then(Value::as_str)
        .is_some_and(|s| s.eq_ignore_ascii_case("closed"));
    Some(Task {
        id: TaskId::new(&source.id, &format!("{repo}#{number}")),
        key: format!("#{number}"),
        ticket: Some(number.to_string()),
        title: issue.get("title")?.as_str()?.to_owned(),
        status: if closed {
            TaskStatus::Done
        } else {
            TaskStatus::Todo
        },
        priority: priority_from_labels(&labels),
        due: None,
        url: issue.get("url").and_then(Value::as_str).map(str::to_owned),
        context: repo.to_owned(),
        labels,
        updated: issue
            .get("updatedAt")
            .and_then(Value::as_str)
            .and_then(parse_timestamp),
    })
}

/// GitHub has no priority field: teams use labels (`P1`, `priority: high`).
fn priority_from_labels(labels: &[String]) -> Priority {
    labels
        .iter()
        .map(|label| {
            let l = label.to_lowercase();
            let has = |words: &[&str]| {
                words.iter().any(|w| {
                    l.split(|c: char| !c.is_alphanumeric())
                        .any(|part| part == *w)
                })
            };
            if has(&["p0", "urgent", "critical", "blocker"]) {
                Priority::Urgent
            } else if has(&["p1", "high"]) {
                Priority::High
            } else if has(&["p2", "medium"]) {
                Priority::Medium
            } else if has(&["p3", "p4", "low"]) {
                Priority::Low
            } else {
                Priority::None
            }
        })
        .max()
        .unwrap_or_default()
}

fn first_line(s: &str) -> &str {
    s.lines().next().unwrap_or(s)
}

#[cfg(all(test, unix))]
mod tests {
    use std::os::unix::fs::PermissionsExt;

    use super::*;
    use crate::agents::ShellPathLocator;
    use kumo_domain::tasks::SourceId;

    /// A fake `gh` that logs its arguments and answers like the real one.
    fn fake_gh(dir: &std::path::Path, signed_in: bool) -> GitHubConnector {
        let bin = dir.join("bin");
        std::fs::create_dir_all(&bin).unwrap();
        let log = dir.join("gh.log");
        let issues = serde_json::json!([
            {"number": 18, "title": "Rounding error", "state": "open", "url": "https://github.com/acme/shop/issues/18",
             "repository": {"name": "shop", "nameWithOwner": "acme/shop"}, "labels": [{"name": "bug"}, {"name": "priority: high"}],
             "updatedAt": "2026-10-27T10:00:00Z", "isPullRequest": false},
            {"number": 19, "title": "A PR", "state": "open", "url": "https://github.com/acme/shop/pull/19",
             "repository": {"name": "shop", "nameWithOwner": "acme/shop"}, "labels": [], "updatedAt": "2026-10-27T10:00:00Z", "isPullRequest": true}
        ]);
        let script = format!(
            "#!/bin/sh\necho \"$@\" >> '{log}'\n{auth}\ncase \"$1 $2\" in\n  'search issues') echo '{issues}' ;;\n  'api user') echo octo ;;\n  'issue close'|'issue reopen') ;;\n  *) echo \"unknown: $*\" >&2; exit 1 ;;\nesac\n",
            log = log.display(),
            auth = if signed_in {
                ""
            } else {
                "echo 'To get started with GitHub CLI, please run:  gh auth login' >&2; exit 4"
            },
            issues = issues,
        );
        let gh = bin.join("gh");
        std::fs::write(&gh, script).unwrap();
        std::fs::set_permissions(&gh, std::fs::Permissions::from_mode(0o755)).unwrap();
        GitHubConnector::new(Arc::new(ShellPathLocator::with_path(
            dir,
            bin.display().to_string(),
        )))
    }

    fn source() -> TaskSource {
        TaskSource {
            id: SourceId::parse("gh").unwrap(),
            name: "GitHub".into(),
            options: SourceOptions::GitHub {
                query: "is:open assignee:@me".into(),
            },
            enabled: true,
        }
    }

    #[test]
    fn reads_issues_and_closes_them_through_gh() {
        let dir = tempfile::tempdir().unwrap();
        let connector = fake_gh(dir.path(), true);
        let tasks = connector.fetch(&source(), None).unwrap();
        assert_eq!(tasks.len(), 1, "pull requests are left out");
        let t = &tasks[0];
        assert_eq!(
            (t.key.as_str(), t.ticket.as_deref(), t.context.as_str()),
            ("#18", Some("18"), "acme/shop")
        );
        assert_eq!(t.id.external(), "acme/shop#18");
        assert_eq!(t.priority, Priority::High);
        assert_eq!(t.status, TaskStatus::Todo);
        assert_eq!(t.suggested_branch(), "feat/18-rounding-error");

        connector
            .set_status(&source(), None, t, TaskStatus::Done)
            .unwrap();
        assert!(matches!(
            connector.set_status(&source(), None, t, TaskStatus::Review),
            Err(TaskError::Unsupported { .. })
        ));
        assert_eq!(
            connector.test(&source(), None).unwrap(),
            "signed in as octo"
        );
        let log = std::fs::read_to_string(dir.path().join("gh.log")).unwrap();
        assert!(log.contains("search issues --json number,title,state,url,repository,labels,updatedAt,isPullRequest --limit 500 -- is:open assignee:@me"), "{log}");
        assert!(
            log.contains("issue close https://github.com/acme/shop/issues/18"),
            "{log}"
        );
    }

    #[test]
    fn asks_to_sign_in_when_gh_is_signed_out() {
        let dir = tempfile::tempdir().unwrap();
        let connector = fake_gh(dir.path(), false);
        assert!(matches!(
            connector.fetch(&source(), None),
            Err(TaskError::Auth(_))
        ));
        assert!(connector.detect().is_empty());
    }

    #[test]
    fn reads_priority_from_labels() {
        let labels = |l: &[&str]| l.iter().map(|s| (*s).to_owned()).collect::<Vec<_>>();
        assert_eq!(priority_from_labels(&labels(&["P0"])), Priority::Urgent);
        assert_eq!(
            priority_from_labels(&labels(&["bug", "prio/low", "P2"])),
            Priority::Medium
        );
        assert_eq!(
            priority_from_labels(&labels(&["highlight"])),
            Priority::None
        );
    }
}
