//! Jira Cloud's REST API, signed in with the account email and an API
//! token (id.atlassian.com › Security › API tokens).
//!
//! A sync reads, by default, the user's own issues (open or recently
//! updated) plus the recent ones of the projects those belong to, so
//! "Everyone" shows teammates' work next to the user's. A JQL in the
//! source's options replaces that scope. "Mine" is always what's assigned
//! to the user (their accountId, from `/myself`).

use std::cmp::Reverse;
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::{Arc, Mutex, PoisonError};

use base64::Engine;
use base64::engine::general_purpose::STANDARD as BASE64;
use kumo_domain::tasks::{
    Attachment, Comment, Detected, LinkKind, LinkedTask, Person, Points, Priority, Progress,
    SourceKind, SourceOptions, Sprint, SprintState, Task, TaskConnector, TaskDetail, TaskError,
    TaskId, TaskRef, TaskSource, TaskStatus, TaskType, TimeTracking,
};
use serde_json::{Value, json};

use super::adf;
use super::dates::{date_part, parse_timestamp};
use super::http::Http;

const PAGE: u64 = 100;
/// With the user's own JQL.
const MAX_ISSUES: usize = 2000;
/// Teammates' issues in the default scope.
const MAX_TEAM_ISSUES: usize = 500;
/// Projects in the default scope (keeps the JQL short).
const MAX_PROJECTS: usize = 20;
const MAX_CHILDREN: usize = 200;
const MAX_COMMENTS: usize = 1000;

/// The user's own issues: open, or done in the last two weeks.
const MINE_JQL: &str = "assignee = currentUser() AND (statusCategory != Done OR updated >= -14d) ORDER BY updated DESC";
/// Where the user works when nothing is assigned to them right now.
const RECENT_JQL: &str = "(assignee = currentUser() OR reporter = currentUser()) AND updated >= -90d ORDER BY updated DESC";

const BOARD_FIELDS: &[&str] = &[
    "summary",
    "status",
    "priority",
    "duedate",
    "project",
    "labels",
    "updated",
    "issuetype",
    "assignee",
    "parent",
    "subtasks",
    "comment",
    "issuelinks",
];
const DETAIL_FIELDS: &[&str] = &[
    "summary",
    "status",
    "priority",
    "duedate",
    "project",
    "labels",
    "created",
    "updated",
    "issuetype",
    "assignee",
    "reporter",
    "parent",
    "subtasks",
    "issuelinks",
    "description",
    "attachment",
    "components",
    "fixVersions",
    "timetracking",
];
const REF_FIELDS: &[&str] = &["summary", "status", "issuetype", "assignee"];

/// Fields that aren't built in: their ids change from site to site, so
/// they're found by name.
#[derive(Debug, Default)]
struct CustomFields {
    points: Vec<String>,
    sprint: Option<String>,
    acceptance: Vec<String>,
}

impl CustomFields {
    fn from_list(fields: &[Value]) -> Self {
        let mut found = Self::default();
        for field in fields {
            let (Some(id), Some(name)) = (
                field.get("id").and_then(Value::as_str),
                field.get("name").and_then(Value::as_str),
            ) else {
                continue;
            };
            let name = name.trim().to_lowercase();
            let custom = field
                .pointer("/schema/custom")
                .and_then(Value::as_str)
                .unwrap_or_default();
            if matches!(name.as_str(), "story points" | "story point estimate") {
                found.points.push(id.to_owned());
            } else if (name == "sprint" || custom.ends_with(":gh-sprint")) && found.sprint.is_none()
            {
                found.sprint = Some(id.to_owned());
            } else if matches!(
                name.as_str(),
                "acceptance criteria" | "criterios de aceptación" | "criterios de aceptacion"
            ) {
                found.acceptance.push(id.to_owned());
            }
        }
        found
    }

    fn board(&self) -> Vec<String> {
        let mut fields: Vec<String> = BOARD_FIELDS.iter().map(|f| (*f).to_owned()).collect();
        fields.extend(self.points.iter().cloned());
        fields.extend(self.sprint.iter().cloned());
        fields
    }

    fn detail(&self) -> Vec<String> {
        let mut fields: Vec<String> = DETAIL_FIELDS.iter().map(|f| (*f).to_owned()).collect();
        fields.extend(self.points.iter().cloned());
        fields.extend(self.sprint.iter().cloned());
        fields.extend(self.acceptance.iter().cloned());
        fields
    }
}

#[derive(Debug)]
pub struct JiraConnector {
    http: Http,
    /// Per site: its custom fields (they don't change between syncs).
    fields: Mutex<HashMap<String, Arc<CustomFields>>>,
    /// Per site and email: the user's accountId, read again on each sync.
    me: Mutex<HashMap<(String, String), String>>,
}

impl Default for JiraConnector {
    fn default() -> Self {
        Self {
            http: Http::new(SourceKind::Jira),
            fields: Mutex::new(HashMap::new()),
            me: Mutex::new(HashMap::new()),
        }
    }
}

struct Account<'a> {
    site: &'a str,
    email: &'a str,
    jql: &'a str,
    auth: String,
}

/// What mapping an issue needs to know.
struct Mapping<'a> {
    source: &'a TaskSource,
    site: &'a str,
    /// The user's accountId.
    me: &'a str,
    fields: &'a CustomFields,
}

impl JiraConnector {
    fn account<'a>(source: &'a TaskSource, token: Option<&str>) -> Result<Account<'a>, TaskError> {
        let SourceOptions::Jira { site, email, jql } = &source.options else {
            return Err(TaskError::Invalid("not a Jira source".into()));
        };
        let token = token.ok_or_else(|| TaskError::Auth("enter your Jira API token".into()))?;
        Ok(Account {
            site,
            email,
            jql: jql.trim(),
            auth: format!("Basic {}", BASE64.encode(format!("{email}:{token}"))),
        })
    }

    fn get(&self, account: &Account<'_>, path: &str) -> Result<Value, TaskError> {
        self.http
            .get(&format!("{}{path}", account.site), &account.auth)
    }

    /// The user's accountId; `fresh` asks Jira instead of using the last
    /// answer.
    fn me(&self, account: &Account<'_>, fresh: bool) -> Result<String, TaskError> {
        let key = (account.site.to_owned(), account.email.to_owned());
        if !fresh
            && let Some(id) = self
                .me
                .lock()
                .unwrap_or_else(PoisonError::into_inner)
                .get(&key)
        {
            return Ok(id.clone());
        }
        let me = self.get(account, "/rest/api/3/myself")?;
        let id = me
            .get("accountId")
            .and_then(Value::as_str)
            .filter(|id| !id.is_empty())
            .ok_or_else(|| TaskError::Source("Jira didn't say who you are".into()))?
            .to_owned();
        self.me
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .insert(key, id.clone());
        Ok(id)
    }

    fn custom_fields(&self, account: &Account<'_>) -> Result<Arc<CustomFields>, TaskError> {
        if let Some(found) = self
            .fields
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .get(account.site)
        {
            return Ok(Arc::clone(found));
        }
        let list = self.get(account, "/rest/api/3/field")?;
        let found = Arc::new(CustomFields::from_list(
            list.as_array().map_or(&[][..], Vec::as_slice),
        ));
        self.fields
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .insert(account.site.to_owned(), Arc::clone(&found));
        Ok(found)
    }

    /// Up to `cap` issues matching `jql`, in Jira's order.
    fn search(
        &self,
        account: &Account<'_>,
        jql: &str,
        fields: &[String],
        cap: usize,
    ) -> Result<Vec<Value>, TaskError> {
        let url = format!("{}/rest/api/3/search/jql", account.site);
        let mut issues = Vec::new();
        let mut next: Option<String> = None;
        loop {
            let page = self.http.post_json(
                &url,
                &account.auth,
                &json!({"jql": jql, "fields": fields, "maxResults": PAGE.min(cap as u64), "nextPageToken": next}),
            )?;
            let found = page
                .get("issues")
                .and_then(Value::as_array)
                .ok_or_else(|| TaskError::Source("Jira answered a search without issues".into()))?;
            issues.extend(found.iter().cloned());
            next = page
                .get("nextPageToken")
                .and_then(Value::as_str)
                .map(str::to_owned);
            let last = page
                .get("isLast")
                .and_then(Value::as_bool)
                .unwrap_or(next.is_none());
            if last || next.is_none() || issues.len() >= cap {
                issues.truncate(cap);
                return Ok(issues);
            }
        }
    }

    /// The user's issues, then the recent ones of their projects.
    fn default_scope(
        &self,
        account: &Account<'_>,
        custom: &CustomFields,
    ) -> Result<Vec<Value>, TaskError> {
        let fields = custom.board();
        let mine = self.search(account, MINE_JQL, &fields, MAX_ISSUES)?;
        let mut projects = project_keys(&mine);
        if projects.is_empty() {
            let recent = self.search(account, RECENT_JQL, &["project".to_owned()], 50)?;
            projects = project_keys(&recent);
        }
        let team = if projects.is_empty() {
            vec![]
        } else {
            let sprints = custom.sprint.is_some();
            match self.search(
                account,
                &team_jql(&projects, sprints),
                &fields,
                MAX_TEAM_ISSUES,
            ) {
                // Projects without Jira Software have no sprints to ask about.
                Err(TaskError::Source(_)) if sprints => self.search(
                    account,
                    &team_jql(&projects, false),
                    &fields,
                    MAX_TEAM_ISSUES,
                )?,
                found => found?,
            }
        };
        let mut seen = HashSet::new();
        let mut all: Vec<Value> = mine
            .into_iter()
            .chain(team)
            .filter(|i| {
                i.get("key")
                    .and_then(Value::as_str)
                    .is_some_and(|k| seen.insert(k.to_owned()))
            })
            .collect();
        all.sort_by_key(|i| {
            Reverse(
                i.pointer("/fields/updated")
                    .and_then(Value::as_str)
                    .and_then(parse_timestamp),
            )
        });
        Ok(all)
    }

    /// Every comment of `key`, oldest first.
    fn comments(&self, account: &Account<'_>, key: &str) -> Result<Vec<Value>, TaskError> {
        let mut comments: Vec<Value> = Vec::new();
        loop {
            let page = self.get(
                account,
                &format!(
                    "/rest/api/3/issue/{key}/comment?startAt={}&maxResults=100&orderBy=created",
                    comments.len()
                ),
            )?;
            let found = page
                .get("comments")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default();
            let total = page
                .get("total")
                .and_then(Value::as_u64)
                .unwrap_or_default() as usize;
            let empty = found.is_empty();
            comments.extend(found);
            if empty || comments.len() >= total || comments.len() >= MAX_COMMENTS {
                break;
            }
        }
        comments.sort_by_key(|c| {
            c.get("created")
                .and_then(Value::as_str)
                .and_then(parse_timestamp)
        });
        Ok(comments)
    }
}

impl TaskConnector for JiraConnector {
    fn kind(&self) -> SourceKind {
        SourceKind::Jira
    }

    fn fetch(&self, source: &TaskSource, secret: Option<&str>) -> Result<Vec<Task>, TaskError> {
        let account = Self::account(source, secret)?;
        let me = self.me(&account, true)?;
        let custom = self.custom_fields(&account)?;
        let issues = if account.jql.is_empty() {
            self.default_scope(&account, &custom)?
        } else {
            self.search(&account, account.jql, &custom.board(), MAX_ISSUES)?
        };
        let map = Mapping {
            source,
            site: account.site,
            me: &me,
            fields: &custom,
        };
        Ok(issues.iter().filter_map(|i| to_task(&map, i)).collect())
    }

    /// The issue with its comments; sub-tasks (or an epic's issues) with
    /// their assignees from one more search.
    fn detail(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        id: &TaskId,
        _known: Option<&Task>,
    ) -> Result<TaskDetail, TaskError> {
        let key = id.external();
        if !is_issue_key(key) {
            return Err(TaskError::UnknownTask(id.to_string()));
        }
        let account = Self::account(source, secret)?;
        let me = self.me(&account, false)?;
        let custom = self.custom_fields(&account)?;
        let issue = self.get(
            &account,
            &format!(
                "/rest/api/3/issue/{key}?fields={}",
                custom.detail().join(",")
            ),
        )?;
        let comments = self.comments(&account, key)?;
        let map = Mapping {
            source,
            site: account.site,
            me: &me,
            fields: &custom,
        };
        let mut detail = to_detail(&map, &issue, &comments)
            .ok_or_else(|| TaskError::Source(format!("Jira answered {key} without a summary")))?;
        if !detail.subtasks.is_empty() || detail.task.kind == TaskType::Epic {
            let fields: Vec<String> = REF_FIELDS.iter().map(|f| (*f).to_owned()).collect();
            let jql = format!("parent = {key} ORDER BY created ASC");
            match self.search(&account, &jql, &fields, MAX_CHILDREN) {
                Ok(children) => {
                    let children: Vec<TaskRef> =
                        children.iter().filter_map(|c| task_ref(&map, c)).collect();
                    merge_children(&mut detail.subtasks, children);
                }
                Err(error) => tracing::debug!(%error, "couldn't read the sub-tasks' assignees"),
            }
        }
        Ok(detail)
    }

    fn set_status(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        task: &Task,
        status: TaskStatus,
    ) -> Result<(), TaskError> {
        let account = Self::account(source, secret)?;
        let key = task
            .ticket
            .as_deref()
            .filter(|k| is_issue_key(k))
            .ok_or_else(|| TaskError::UnknownTask(task.id.to_string()))?;
        let url = format!("{}/rest/api/3/issue/{key}/transitions", account.site);
        let available = self.http.get(&url, &account.auth)?;
        let transitions = available
            .get("transitions")
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();
        let id = pick_transition(&transitions, status).ok_or_else(|| {
            TaskError::Source(format!(
                "your Jira workflow has no transition that takes {key} to {status} from here"
            ))
        })?;
        self.http
            .post_json(&url, &account.auth, &json!({"transition": {"id": id}}))
            .map(drop)
    }

    fn test(&self, source: &TaskSource, secret: Option<&str>) -> Result<String, TaskError> {
        let account = Self::account(source, secret)?;
        let me = self.get(&account, "/rest/api/3/myself")?;
        let name = me
            .get("displayName")
            .or_else(|| me.get("emailAddress"))
            .and_then(Value::as_str)
            .unwrap_or("you");
        Ok(format!("signed in as {name}"))
    }

    fn watched_paths(&self, _source: &TaskSource) -> Vec<PathBuf> {
        vec![]
    }

    fn detect(&self) -> Vec<Detected> {
        vec![]
    }
}

/// Distinct project keys, in the order the issues come.
fn project_keys(issues: &[Value]) -> Vec<String> {
    let mut keys: Vec<String> = Vec::new();
    for key in issues
        .iter()
        .filter_map(|i| i.pointer("/fields/project/key").and_then(Value::as_str))
    {
        let valid = !key.is_empty() && key.chars().all(|c| c.is_ascii_alphanumeric() || c == '_');
        if valid && !keys.iter().any(|k| k == key) && keys.len() < MAX_PROJECTS {
            keys.push(key.to_owned());
        }
    }
    keys
}

/// The recent issues of `projects`: in an open sprint or touched in the
/// last two weeks, and not done long ago.
fn team_jql(projects: &[String], sprints: bool) -> String {
    let projects = projects
        .iter()
        .map(|p| format!("\"{p}\""))
        .collect::<Vec<_>>()
        .join(", ");
    let recent = if sprints {
        "sprint in openSprints() OR updated >= -14d"
    } else {
        "updated >= -14d"
    };
    format!(
        "project in ({projects}) AND ({recent}) AND (statusCategory != Done OR updated >= -14d) ORDER BY updated DESC"
    )
}

fn text<'a>(value: &'a Value, pointer: &str) -> Option<&'a str> {
    value.pointer(pointer).and_then(Value::as_str)
}

fn person(user: &Value, me: &str) -> Option<Person> {
    let id = user.get("accountId").and_then(Value::as_str)?;
    let name = user
        .get("displayName")
        .and_then(Value::as_str)
        .unwrap_or(id);
    Some(Person::new(id, name, id == me))
}

fn issue_type(issuetype: Option<&Value>) -> TaskType {
    let Some(t) = issuetype else {
        return TaskType::Unknown;
    };
    let name = t
        .get("name")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_lowercase();
    let level = t.get("hierarchyLevel").and_then(Value::as_i64);
    if t.get("subtask").and_then(Value::as_bool) == Some(true)
        || level == Some(-1)
        || name.contains("sub-task")
        || name.contains("subtask")
    {
        TaskType::Subtask
    } else if level.is_some_and(|l| l >= 1) || name == "epic" {
        TaskType::Epic
    } else {
        match name.as_str() {
            "story" | "user story" => TaskType::Story,
            "bug" | "defect" => TaskType::Bug,
            _ => TaskType::Task,
        }
    }
}

fn status_of_fields(fields: &Value) -> TaskStatus {
    status_of(
        text(fields, "/status/statusCategory/key").unwrap_or("new"),
        text(fields, "/status/name").unwrap_or_default(),
    )
}

/// Another issue, as a parent, sub-task or link mentions it.
fn task_ref(map: &Mapping<'_>, issue: &Value) -> Option<TaskRef> {
    let key = issue.get("key")?.as_str()?;
    let fields = issue.get("fields").unwrap_or(&Value::Null);
    Some(TaskRef {
        id: Some(TaskId::new(&map.source.id, key)),
        kind: issue_type(fields.get("issuetype")),
        source_status: text(fields, "/status/name").unwrap_or_default().to_owned(),
        status: status_of_fields(fields),
        assignee: fields.get("assignee").and_then(|a| person(a, map.me)),
        url: Some(format!("{}/browse/{key}", map.site)),
        ..TaskRef::new(key, text(fields, "/summary").unwrap_or_default())
    })
}

fn links_of(map: &Mapping<'_>, fields: &Value) -> Vec<LinkedTask> {
    fields
        .get("issuelinks")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|link| {
            let (other, inward) = match (link.get("inwardIssue"), link.get("outwardIssue")) {
                (Some(issue), _) => (issue, true),
                (None, Some(issue)) => (issue, false),
                (None, None) => return None,
            };
            let wording = text(
                link,
                if inward {
                    "/type/inward"
                } else {
                    "/type/outward"
                },
            )
            .unwrap_or_default();
            Some(LinkedTask {
                kind: link_kind(
                    text(link, "/type/name").unwrap_or_default(),
                    inward,
                    wording,
                ),
                relation: wording.to_owned(),
                task: task_ref(map, other)?,
            })
        })
        .collect()
}

/// Jira's built-in link types by name; others by their wording.
fn link_kind(type_name: &str, inward: bool, wording: &str) -> LinkKind {
    match (type_name.to_lowercase().as_str(), inward) {
        ("blocks", true) => LinkKind::BlockedBy,
        ("blocks", false) => LinkKind::Blocks,
        ("duplicate", true) => LinkKind::DuplicatedBy,
        ("duplicate", false) => LinkKind::Duplicates,
        ("relates", _) => LinkKind::Relates,
        _ => match wording.to_lowercase().as_str() {
            "is blocked by" => LinkKind::BlockedBy,
            "blocks" => LinkKind::Blocks,
            "relates to" => LinkKind::Relates,
            "duplicates" => LinkKind::Duplicates,
            "is duplicated by" => LinkKind::DuplicatedBy,
            _ => LinkKind::Other,
        },
    }
}

/// The sprint a card shows: the active one, else the next, else the last
/// that closed.
fn sprint_of(value: &Value) -> Option<Sprint> {
    let sprints: Vec<Sprint> = value
        .as_array()?
        .iter()
        .filter_map(|s| {
            Some(Sprint {
                name: s.get("name")?.as_str()?.to_owned(),
                state: match s
                    .get("state")
                    .and_then(Value::as_str)
                    .map(str::to_lowercase)
                {
                    Some(state) if state == "active" => SprintState::Active,
                    Some(state) if state == "closed" => SprintState::Closed,
                    Some(state) if state == "future" => SprintState::Future,
                    _ => SprintState::Unknown,
                },
                start: text(s, "/startDate").and_then(parse_timestamp),
                end: text(s, "/endDate").and_then(parse_timestamp),
            })
        })
        .collect();
    let with = |state: SprintState| sprints.iter().filter(move |s| s.state == state);
    with(SprintState::Active)
        .next()
        .or_else(|| with(SprintState::Future).min_by_key(|s| s.start))
        .or_else(|| with(SprintState::Closed).max_by_key(|s| s.end))
        .or(sprints.last())
        .cloned()
}

fn to_task(map: &Mapping<'_>, issue: &Value) -> Option<Task> {
    let key = issue.get("key")?.as_str()?;
    let fields = issue.get("fields")?;
    let links = links_of(map, fields);
    let subtasks: Vec<&Value> = fields
        .get("subtasks")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .collect();
    let done = subtasks
        .iter()
        .filter(|s| text(s, "/fields/status/statusCategory/key") == Some("done"))
        .count();
    let count = |n: usize| u32::try_from(n).unwrap_or(u32::MAX);
    let task = Task {
        key: key.to_owned(),
        ticket: Some(key.to_owned()),
        status: status_of_fields(fields),
        priority: match text(fields, "/priority/name")
            .map(str::to_lowercase)
            .as_deref()
        {
            Some("highest" | "blocker" | "critical") => Priority::Urgent,
            Some("high" | "major") => Priority::High,
            Some("medium") => Priority::Medium,
            Some("low" | "lowest" | "minor" | "trivial") => Priority::Low,
            _ => Priority::None,
        },
        due: text(fields, "/duedate").and_then(date_part),
        url: Some(format!("{}/browse/{key}", map.site)),
        context: text(fields, "/project/name").unwrap_or_default().to_owned(),
        labels: fields
            .get("labels")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .filter_map(|l| l.as_str().map(str::to_owned))
            .collect(),
        updated: text(fields, "/updated").and_then(parse_timestamp),
        kind: issue_type(fields.get("issuetype")),
        type_name: text(fields, "/issuetype/name")
            .unwrap_or_default()
            .to_owned(),
        source_status: text(fields, "/status/name").unwrap_or_default().to_owned(),
        points: map
            .fields
            .points
            .iter()
            .find_map(|id| fields.get(id).and_then(Value::as_f64))
            .and_then(Points::from_f64),
        subtasks: Progress {
            done: count(done),
            total: count(subtasks.len()),
        },
        comment_count: fields
            .pointer("/comment/total")
            .and_then(Value::as_u64)
            .map_or(0, |n| u32::try_from(n).unwrap_or(u32::MAX)),
        parent: fields.get("parent").and_then(|p| task_ref(map, p)),
        blocked: links
            .iter()
            .any(|l| l.kind == LinkKind::BlockedBy && l.task.status != TaskStatus::Done),
        sprint: map
            .fields
            .sprint
            .as_ref()
            .and_then(|id| fields.get(id))
            .and_then(sprint_of),
        ..Task::new(TaskId::new(&map.source.id, key), text(fields, "/summary")?)
    };
    Some(task.assigned_to(fields.get("assignee").and_then(|a| person(a, map.me))))
}

/// Rich text (ADF) or plain text, as Markdown.
fn markdown(value: &Value) -> String {
    match value {
        Value::String(text) => text.replace("\r\n", "\n").trim().to_owned(),
        Value::Null => String::new(),
        doc => adf::to_markdown(doc),
    }
}

fn names(fields: &Value, key: &str) -> Vec<String> {
    fields
        .get(key)
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|v| v.get("name")?.as_str().map(str::to_owned))
        .collect()
}

fn to_detail(map: &Mapping<'_>, issue: &Value, comments: &[Value]) -> Option<TaskDetail> {
    let fields = issue.get("fields")?;
    let mut task = to_task(map, issue)?;
    task.comment_count = u32::try_from(comments.len()).unwrap_or(u32::MAX);
    let tracking = fields.get("timetracking").map(|t| {
        let seconds = |key: &str| t.get(key).and_then(Value::as_u64).unwrap_or(0);
        let words = |key: &str| text(t, &format!("/{key}")).unwrap_or_default().to_owned();
        TimeTracking {
            estimate: words("originalEstimate"),
            logged: words("timeSpent"),
            remaining: words("remainingEstimate"),
            estimate_seconds: seconds("originalEstimateSeconds"),
            logged_seconds: seconds("timeSpentSeconds"),
            remaining_seconds: seconds("remainingEstimateSeconds"),
        }
    });
    Some(TaskDetail {
        reporter: fields.get("reporter").and_then(|r| person(r, map.me)),
        created: text(fields, "/created").and_then(parse_timestamp),
        description: markdown(fields.get("description").unwrap_or(&Value::Null)),
        acceptance_criteria: map
            .fields
            .acceptance
            .iter()
            .filter_map(|id| fields.get(id))
            .map(markdown)
            .find(|text| !text.is_empty())
            .unwrap_or_default(),
        subtasks: fields
            .get("subtasks")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .filter_map(|s| task_ref(map, s))
            .collect(),
        links: links_of(map, fields),
        attachments: fields
            .get("attachment")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .filter_map(|a| {
                let name = a.get("filename")?.as_str()?;
                Some(Attachment {
                    name: name.to_owned(),
                    kind: attachment_kind(text(a, "/mimeType").unwrap_or_default(), name),
                    size_bytes: a.get("size").and_then(Value::as_u64).unwrap_or(0),
                    url: text(a, "/content").map(str::to_owned),
                })
            })
            .collect(),
        comments: comments
            .iter()
            .map(|c| Comment {
                author: c.get("author").and_then(|a| person(a, map.me)),
                created: text(c, "/created").and_then(parse_timestamp),
                body: markdown(c.get("body").unwrap_or(&Value::Null)),
            })
            .collect(),
        components: names(fields, "components"),
        fix_versions: names(fields, "fixVersions"),
        time_tracking: tracking.filter(|t| !t.is_empty()),
        ..TaskDetail::basic(task)
    })
}

/// Sub-tasks keep the issue's order and take what the search knows
/// (assignees); issues only the search found (an epic's) go after.
fn merge_children(subtasks: &mut Vec<TaskRef>, children: Vec<TaskRef>) {
    for child in children {
        match subtasks.iter_mut().find(|s| s.key == child.key) {
            Some(known) => *known = child,
            None => subtasks.push(child),
        }
    }
}

/// What the attachments list says a file is ("PNG image", "CSV").
fn attachment_kind(mime: &str, name: &str) -> String {
    let mime = mime.to_lowercase();
    let extension = name
        .rsplit_once('.')
        .map(|(_, e)| e.to_lowercase())
        .unwrap_or_default();
    if let Some(image) = mime.strip_prefix("image/") {
        let format = match image {
            "jpeg" | "pjpeg" => "JPEG".to_owned(),
            "svg+xml" => "SVG".to_owned(),
            other => other
                .split(['+', ';'])
                .next()
                .unwrap_or(other)
                .to_uppercase(),
        };
        return format!("{format} image");
    }
    let known = match mime.split(';').next().unwrap_or_default().trim() {
        "text/csv" => Some("CSV"),
        "application/pdf" => Some("PDF"),
        "application/json" => Some("JSON"),
        "application/zip" | "application/x-zip-compressed" => Some("ZIP archive"),
        m if m.starts_with("video/") => Some("Video"),
        m if m.starts_with("audio/") => Some("Audio"),
        m if m.contains("spreadsheet") || m.contains("ms-excel") => Some("Spreadsheet"),
        m if m.contains("wordprocessing") || m == "application/msword" => Some("Document"),
        m if m.contains("presentation") || m.contains("powerpoint") => Some("Presentation"),
        _ => None,
    };
    if let Some(kind) = known {
        return kind.to_owned();
    }
    match extension.as_str() {
        "log" => "Log".to_owned(),
        "csv" => "CSV".to_owned(),
        "pdf" => "PDF".to_owned(),
        "md" => "Markdown".to_owned(),
        "json" => "JSON".to_owned(),
        "txt" => "Text".to_owned(),
        "" if mime.starts_with("text/") => "Text".to_owned(),
        "" => "File".to_owned(),
        other => other.to_uppercase(),
    }
}

/// Jira's three status categories, with "review" statuses split out.
fn status_of(category: &str, name: &str) -> TaskStatus {
    match category {
        "done" => TaskStatus::Done,
        "indeterminate" if is_review(name) => TaskStatus::Review,
        "indeterminate" => TaskStatus::Doing,
        _ => TaskStatus::Todo,
    }
}

fn is_review(name: &str) -> bool {
    let name = name.to_lowercase();
    name.contains("review") || name.contains("qa") || name.contains("testing")
}

/// The transition that best takes an issue to `status`.
fn pick_transition(transitions: &[Value], status: TaskStatus) -> Option<String> {
    let candidates = transitions.iter().filter_map(|t| {
        let id = t.get("id")?.as_str()?.to_owned();
        let name = t
            .get("name")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_lowercase();
        let to = t
            .pointer("/to/name")
            .and_then(Value::as_str)
            .unwrap_or_default();
        let category = t
            .pointer("/to/statusCategory/key")
            .and_then(Value::as_str)
            .unwrap_or_default();
        let fits =
            status_of(category, to) == status || (status == TaskStatus::Review && is_review(&name));
        // Prefer the plain path: not "cancel", "won't do", "reject".
        let detour = ["cancel", "won't", "wont", "reject", "decline", "duplicate"]
            .iter()
            .any(|w| name.contains(w) || to.to_lowercase().contains(w));
        let preferred = match status {
            TaskStatus::Doing => {
                name.contains("progress") || to.to_lowercase().contains("progress")
            }
            TaskStatus::Done => name.contains("done") || to.eq_ignore_ascii_case("done"),
            _ => false,
        };
        fits.then_some((detour, !preferred, id))
    });
    candidates.min().map(|(_, _, id)| id)
}

/// `PRC-412`: project key, dash, number.
fn is_issue_key(key: &str) -> bool {
    key.split_once('-').is_some_and(|(project, number)| {
        !project.is_empty()
            && project
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '_')
            && !number.is_empty()
            && number.chars().all(|c| c.is_ascii_digit())
    })
}

#[cfg(test)]
#[path = "jira_tests.rs"]
mod tests;
