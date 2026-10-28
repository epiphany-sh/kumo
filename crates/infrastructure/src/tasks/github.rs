//! GitHub Issues through the user's own `gh` CLI: its sign-in, its hosts;
//! Kumo never sees a GitHub token.
//!
//! The default query brings the open issues the user is involved in
//! (`involves:@me`: assigned, author, mentioned or commenting), so
//! "Everyone" shows teammates' issues too; "Mine" is the part assigned to
//! the user's login.

use std::io::Read;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex, PoisonError};
use std::time::{Duration, Instant};

use kumo_domain::agents::ProgramLocator;
use kumo_domain::tasks::{
    Comment, Detected, Person, Priority, SourceKind, SourceOptions, Task, TaskConnector,
    TaskDetail, TaskError, TaskId, TaskSource, TaskStatus, TaskType,
};
use serde_json::Value;

use super::dates::parse_timestamp;

const MAX_ISSUES: &str = "500";
const TIMEOUT: Duration = Duration::from_secs(60);
const SEARCH_FIELDS: &str = "number,title,state,url,repository,labels,updatedAt,isPullRequest,assignees,author,commentsCount";
const ISSUE_FIELDS: &str =
    "number,title,body,comments,labels,assignees,author,createdAt,updatedAt,url,state";

pub struct GitHubConnector {
    locator: Arc<dyn ProgramLocator>,
    /// The signed-in login, read on each sync (an account switch in `gh`
    /// shows on the next one).
    login: Mutex<Option<String>>,
}

impl std::fmt::Debug for GitHubConnector {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("GitHubConnector").finish_non_exhaustive()
    }
}

impl GitHubConnector {
    pub fn new(locator: Arc<dyn ProgramLocator>) -> Self {
        Self {
            locator,
            login: Mutex::new(None),
        }
    }

    /// Who `gh` is signed in as; `fresh` asks again instead of using the
    /// last answer.
    fn login(&self, fresh: bool) -> Result<String, TaskError> {
        let mut cached = self.login.lock().unwrap_or_else(PoisonError::into_inner);
        if let Some(login) = cached.as_ref().filter(|_| !fresh) {
            return Ok(login.clone());
        }
        let login = self
            .gh(&["api", "user", "--jq", ".login"])?
            .trim()
            .to_owned();
        if login.is_empty() {
            return Err(TaskError::Source("gh didn't say who you are".into()));
        }
        *cached = Some(login.clone());
        Ok(login)
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
        let me = self.login(true)?;
        let out = self.gh(&[
            "search",
            "issues",
            "--json",
            SEARCH_FIELDS,
            "--limit",
            MAX_ISSUES,
            "--",
            query,
        ])?;
        let issues: Vec<Value> = parse(&out)?;
        Ok(issues
            .iter()
            .filter_map(|issue| {
                let repo = issue.pointer("/repository/nameWithOwner")?.as_str()?;
                to_task(source, repo, issue, &me)
            })
            .collect())
    }

    /// `gh issue view`: body and comments are Markdown already.
    fn detail(
        &self,
        source: &TaskSource,
        _secret: Option<&str>,
        id: &TaskId,
        _known: Option<&Task>,
    ) -> Result<TaskDetail, TaskError> {
        Self::query(source)?;
        let (repo, number) =
            issue_ref(id.external()).ok_or_else(|| TaskError::UnknownTask(id.to_string()))?;
        let me = self.login(false)?;
        let out = self.gh(&[
            "issue",
            "view",
            number,
            "--repo",
            repo,
            "--json",
            ISSUE_FIELDS,
        ])?;
        let issue: Value = parse(&out)?;
        issue_detail(source, repo, &issue, &me)
            .ok_or_else(|| TaskError::Source("gh answered an issue without a title".into()))
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
        Ok(format!("signed in as {}", self.login(true)?))
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

fn parse<T: serde::de::DeserializeOwned>(out: &str) -> Result<T, TaskError> {
    serde_json::from_str(out)
        .map_err(|e| TaskError::Source(format!("gh answered something unexpected: {e}")))
}

/// `owner/repo#18` → (`owner/repo`, `18`), refusing anything `gh` could read
/// as a flag or another host.
fn issue_ref(external: &str) -> Option<(&str, &str)> {
    let (repo, number) = external.rsplit_once('#')?;
    let (owner, name) = repo.split_once('/')?;
    let part = |p: &str| {
        !p.is_empty()
            && !p.starts_with(['-', '.'])
            && p.chars()
                .all(|c| c.is_ascii_alphanumeric() || matches!(c, '-' | '_' | '.'))
    };
    (part(owner) && part(name) && !number.is_empty() && number.chars().all(|c| c.is_ascii_digit()))
        .then_some((repo, number))
}

/// A GitHub user; `name` when `gh` sends one, else the login.
fn person(user: &Value, me: &str) -> Option<Person> {
    let login = user.get("login")?.as_str().filter(|l| !l.is_empty())?;
    let name = user
        .get("name")
        .and_then(Value::as_str)
        .filter(|n| !n.trim().is_empty())
        .unwrap_or(login);
    Some(Person::new(login, name, login.eq_ignore_ascii_case(me)))
}

/// An issue from `gh search issues` or `gh issue view` (same field names).
fn to_task(source: &TaskSource, repo: &str, issue: &Value, me: &str) -> Option<Task> {
    if issue.get("isPullRequest").and_then(Value::as_bool) == Some(true) {
        return None;
    }
    let number = issue.get("number")?.as_u64()?;
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
    let assignees: Vec<Person> = issue
        .get("assignees")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|a| person(a, me))
        .collect();
    // The card shows one: the user when they're among them.
    let assignee = assignees
        .iter()
        .find(|p| p.you)
        .or(assignees.first())
        .cloned();
    let comments = issue
        .get("commentsCount")
        .and_then(Value::as_u64)
        .or_else(|| {
            issue
                .get("comments")
                .and_then(Value::as_array)
                .map(|c| c.len() as u64)
        })
        .unwrap_or(0);
    let task = Task {
        key: format!("#{number}"),
        ticket: Some(number.to_string()),
        status: if closed {
            TaskStatus::Done
        } else {
            TaskStatus::Todo
        },
        priority: priority_from_labels(&labels),
        url: issue.get("url").and_then(Value::as_str).map(str::to_owned),
        context: repo.to_owned(),
        labels,
        updated: issue
            .get("updatedAt")
            .and_then(Value::as_str)
            .and_then(parse_timestamp),
        kind: TaskType::Issue,
        type_name: "Issue".into(),
        source_status: if closed { "Closed" } else { "Open" }.into(),
        comment_count: u32::try_from(comments).unwrap_or(u32::MAX),
        ..Task::new(
            TaskId::new(&source.id, &format!("{repo}#{number}")),
            issue.get("title")?.as_str()?.to_owned(),
        )
    };
    Some(task.assigned_to(assignee))
}

fn issue_detail(source: &TaskSource, repo: &str, issue: &Value, me: &str) -> Option<TaskDetail> {
    let task = to_task(source, repo, issue, me)?;
    let time = |v: &Value| {
        v.get("createdAt")
            .and_then(Value::as_str)
            .and_then(parse_timestamp)
    };
    let mut comments: Vec<Comment> = issue
        .get("comments")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .map(|c| Comment {
            author: c.get("author").and_then(|a| person(a, me)),
            created: time(c),
            body: c
                .get("body")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .replace("\r\n", "\n"),
        })
        .collect();
    comments.sort_by_key(|c| c.created);
    Some(TaskDetail {
        reporter: issue.get("author").and_then(|a| person(a, me)),
        created: time(issue),
        description: issue
            .get("body")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .replace("\r\n", "\n")
            .trim()
            .to_owned(),
        comments,
        ..TaskDetail::basic(task)
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

    /// A fake `gh` that logs its arguments and answers like the real one,
    /// with recorded answers from `fixtures/`.
    fn fake_gh(dir: &std::path::Path, signed_in: bool) -> GitHubConnector {
        let bin = dir.join("bin");
        std::fs::create_dir_all(&bin).unwrap();
        let log = dir.join("gh.log");
        let (search, issue) = (dir.join("search.json"), dir.join("issue.json"));
        std::fs::write(&search, include_str!("fixtures/github_search.json")).unwrap();
        std::fs::write(&issue, include_str!("fixtures/github_issue.json")).unwrap();
        let script = format!(
            "#!/bin/sh\necho \"$@\" >> '{log}'\n{auth}\ncase \"$1 $2\" in\n  'search issues') /bin/cat '{search}' ;;\n  'issue view') /bin/cat '{issue}' ;;\n  'api user') echo octo ;;\n  'issue close'|'issue reopen') ;;\n  *) echo \"unknown: $*\" >&2; exit 1 ;;\nesac\n",
            log = log.display(),
            auth = if signed_in {
                ""
            } else {
                "echo 'To get started with GitHub CLI, please run:  gh auth login' >&2; exit 4"
            },
            search = search.display(),
            issue = issue.display(),
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
                query: "is:open involves:@me".into(),
            },
            enabled: true,
        }
    }

    #[test]
    fn reads_issues_and_closes_them_through_gh() {
        let dir = tempfile::tempdir().unwrap();
        let connector = fake_gh(dir.path(), true);
        let tasks = connector.fetch(&source(), None).unwrap();
        assert_eq!(tasks.len(), 2, "pull requests are left out");
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
        assert!(
            log.contains(&format!(
                "search issues --json {SEARCH_FIELDS} --limit 500 -- is:open involves:@me"
            )),
            "{log}"
        );
        assert!(
            log.contains("issue close https://github.com/acme/shop/issues/18"),
            "{log}"
        );
    }

    #[test]
    fn marks_the_users_issues_and_who_has_the_rest() {
        let dir = tempfile::tempdir().unwrap();
        let connector = fake_gh(dir.path(), true);
        let tasks = connector.fetch(&source(), None).unwrap();
        let mine = &tasks[0];
        assert!(
            mine.mine,
            "assigned to Octo: the login matches ignoring case"
        );
        assert!(
            mine.relations
                .contains(&kumo_domain::tasks::TaskRelation::Assigned)
        );
        let me = mine.assignee.as_ref().unwrap();
        assert_eq!(
            (me.id.as_str(), me.initials.as_str(), me.you),
            ("Octo", "O", true)
        );
        assert_eq!(
            (
                mine.kind,
                mine.type_name.as_str(),
                mine.source_status.as_str()
            ),
            (TaskType::Issue, "Issue", "Open")
        );
        assert_eq!(mine.comment_count, 3);

        let theirs = &tasks[1];
        assert!(
            !theirs.mine,
            "authored by the user, assigned to someone else"
        );
        assert_eq!(theirs.assignee.as_ref().unwrap().name, "tomas");
        assert_eq!(theirs.id.external(), "pricing/zen-engine#7");
    }

    #[test]
    fn details_come_from_gh_issue_view() {
        let dir = tempfile::tempdir().unwrap();
        let connector = fake_gh(dir.path(), true);
        let id = TaskId::new(&source().id, "acme/shop#18");
        let detail = connector.detail(&source(), None, &id, None).unwrap();
        assert_eq!(detail.task.title, "Rounding error");
        assert_eq!(detail.task.id, id);
        assert_eq!(detail.task.labels, ["bug", "api"]);
        assert_eq!(detail.task.comment_count, 2);
        assert!(detail.task.mine);
        assert_eq!(detail.task.assignee.as_ref().unwrap().name, "Octo Cat");
        let reporter = detail.reporter.unwrap();
        assert_eq!(
            (reporter.name.as_str(), reporter.initials.as_str()),
            ("Nico Paz", "NP")
        );
        assert!(
            detail
                .description
                .starts_with("The pricing client gives up")
        );
        assert!(detail.description.contains("\n### Proposal\n- Retry"));
        assert!(!detail.description.contains('\r'));
        let comments: Vec<_> = detail
            .comments
            .iter()
            .map(|c| {
                (
                    c.author.as_ref().unwrap().id.as_str(),
                    c.author.as_ref().unwrap().you,
                )
            })
            .collect();
        assert_eq!(comments, [("octo", true), ("tomas", false)], "oldest first");
        assert!(detail.created.is_some());
        let log = std::fs::read_to_string(dir.path().join("gh.log")).unwrap();
        assert!(
            log.contains(&format!(
                "issue view 18 --repo acme/shop --json {ISSUE_FIELDS}"
            )),
            "{log}"
        );

        for bad in ["--repo#1", "acme/shop#x", "a/b/c#1", "acme/-x#1", "acme#1"] {
            let id = TaskId::new(&source().id, bad);
            assert!(
                matches!(
                    connector.detail(&source(), None, &id, None),
                    Err(TaskError::UnknownTask(_))
                ),
                "{bad}"
            );
        }
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
