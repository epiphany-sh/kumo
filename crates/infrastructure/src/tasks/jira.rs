//! Jira Cloud's REST API, signed in with the account email and an API
//! token (id.atlassian.com › Security › API tokens).

use std::path::PathBuf;

use base64::Engine;
use base64::engine::general_purpose::STANDARD as BASE64;
use kumo_domain::tasks::{
    Detected, Priority, SourceKind, SourceOptions, Task, TaskConnector, TaskError, TaskId,
    TaskSource, TaskStatus,
};
use serde_json::{Value, json};

use super::dates::{date_part, parse_timestamp};
use super::http::Http;

const PAGE: u64 = 100;
const MAX_ISSUES: usize = 2000;
const FIELDS: &[&str] = &[
    "summary", "status", "priority", "duedate", "project", "labels", "updated",
];

#[derive(Debug)]
pub struct JiraConnector {
    http: Http,
}

impl Default for JiraConnector {
    fn default() -> Self {
        Self {
            http: Http::new(SourceKind::Jira),
        }
    }
}

struct Account<'a> {
    site: &'a str,
    jql: &'a str,
    auth: String,
}

impl JiraConnector {
    fn account<'a>(source: &'a TaskSource, token: Option<&str>) -> Result<Account<'a>, TaskError> {
        let SourceOptions::Jira { site, email, jql } = &source.options else {
            return Err(TaskError::Invalid("not a Jira source".into()));
        };
        let token = token.ok_or_else(|| TaskError::Auth("enter your Jira API token".into()))?;
        Ok(Account {
            site,
            jql,
            auth: format!("Basic {}", BASE64.encode(format!("{email}:{token}"))),
        })
    }
}

impl TaskConnector for JiraConnector {
    fn kind(&self) -> SourceKind {
        SourceKind::Jira
    }

    fn fetch(&self, source: &TaskSource, secret: Option<&str>) -> Result<Vec<Task>, TaskError> {
        let account = Self::account(source, secret)?;
        let url = format!("{}/rest/api/3/search/jql", account.site);
        let mut tasks = Vec::new();
        let mut next: Option<String> = None;
        loop {
            let page = self.http.post_json(
                &url,
                &account.auth,
                &json!({"jql": account.jql, "fields": FIELDS, "maxResults": PAGE, "nextPageToken": next}),
            )?;
            let issues = page
                .get("issues")
                .and_then(Value::as_array)
                .ok_or_else(|| TaskError::Source("Jira answered a search without issues".into()))?;
            tasks.extend(
                issues
                    .iter()
                    .filter_map(|i| to_task(source, account.site, i)),
            );
            next = page
                .get("nextPageToken")
                .and_then(Value::as_str)
                .map(str::to_owned);
            let last = page
                .get("isLast")
                .and_then(Value::as_bool)
                .unwrap_or(next.is_none());
            if last || next.is_none() || tasks.len() >= MAX_ISSUES {
                return Ok(tasks);
            }
        }
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
        let me = self.http.get(
            &format!("{}/rest/api/3/myself", account.site),
            &account.auth,
        )?;
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

fn to_task(source: &TaskSource, site: &str, issue: &Value) -> Option<Task> {
    let key = issue.get("key")?.as_str()?;
    let fields = issue.get("fields")?;
    let text = |pointer: &str| fields.pointer(pointer).and_then(Value::as_str);
    Some(Task {
        id: TaskId::new(&source.id, key),
        key: key.to_owned(),
        ticket: Some(key.to_owned()),
        title: text("/summary")?.to_owned(),
        status: status_of(
            text("/status/statusCategory/key").unwrap_or("new"),
            text("/status/name").unwrap_or_default(),
        ),
        priority: match text("/priority/name").map(str::to_lowercase).as_deref() {
            Some("highest" | "blocker" | "critical") => Priority::Urgent,
            Some("high" | "major") => Priority::High,
            Some("medium") => Priority::Medium,
            Some("low" | "lowest" | "minor" | "trivial") => Priority::Low,
            _ => Priority::None,
        },
        due: text("/duedate").and_then(date_part),
        url: Some(format!("{site}/browse/{key}")),
        context: text("/project/name").unwrap_or_default().to_owned(),
        labels: fields
            .get("labels")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .filter_map(|l| l.as_str().map(str::to_owned))
            .collect(),
        updated: text("/updated").and_then(parse_timestamp),
    })
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
mod tests {
    use super::super::test_server::TestServer;
    use super::*;
    use kumo_domain::tasks::SourceId;

    fn source(site: &str) -> TaskSource {
        TaskSource {
            id: SourceId::parse("ji").unwrap(),
            name: "Jira".into(),
            options: SourceOptions::Jira {
                site: site.into(),
                email: "ana@acme.com".into(),
                jql: "assignee = currentUser()".into(),
            },
            enabled: true,
        }
    }

    fn issue(key: &str, category: &str, status: &str) -> Value {
        json!({"key": key, "fields": {
            "summary": format!("Issue {key}"),
            "status": {"name": status, "statusCategory": {"key": category}},
            "priority": {"name": "High"},
            "duedate": "2026-11-05",
            "project": {"name": "Pricing"},
            "labels": ["backend"],
            "updated": "2026-10-27T10:00:00.000+0000"
        }})
    }

    #[test]
    fn pages_through_the_search_and_maps_statuses() {
        let server = TestServer::start(|r| {
            match (r.method.as_str(), r.path.as_str()) {
            ("POST", "/rest/api/3/search/jql") if r.json()["nextPageToken"].is_null() => (
                200,
                json!({"issues": [issue("PRC-1", "new", "To Do"), issue("PRC-2", "indeterminate", "In Progress")],
                       "nextPageToken": "p2", "isLast": false})
                .to_string(),
            ),
            ("POST", "/rest/api/3/search/jql") => (
                200,
                json!({"issues": [issue("PRC-3", "indeterminate", "Code Review"), issue("PRC-4", "done", "Done")],
                       "isLast": true})
                .to_string(),
            ),
            _ => (404, "{}".into()),
        }
        });
        let tasks = JiraConnector::default()
            .fetch(&source(&server.url), Some("tok"))
            .unwrap();
        let statuses: Vec<_> = tasks.iter().map(|t| (t.key.as_str(), t.status)).collect();
        assert_eq!(
            statuses,
            [
                ("PRC-1", TaskStatus::Todo),
                ("PRC-2", TaskStatus::Doing),
                ("PRC-3", TaskStatus::Review),
                ("PRC-4", TaskStatus::Done)
            ]
        );
        let t = &tasks[0];
        assert_eq!(
            (t.priority, t.due.as_deref(), t.context.as_str()),
            (Priority::High, Some("2026-11-05"), "Pricing")
        );
        assert_eq!(
            t.url.as_deref(),
            Some(format!("{}/browse/PRC-1", server.url).as_str())
        );
        assert_eq!(t.suggested_branch(), "feat/PRC-1-issue-prc-1");

        let requests = server.requests();
        assert_eq!(requests.len(), 2);
        assert_eq!(requests[1].json()["nextPageToken"], "p2");
        assert_eq!(requests[0].json()["jql"], "assignee = currentUser()");
        let expected = format!("Basic {}", BASE64.encode("ana@acme.com:tok"));
        assert_eq!(requests[0].header("authorization"), Some(expected.as_str()));
    }

    #[test]
    fn moves_issues_with_the_matching_transition() {
        let server = TestServer::start(|r| {
            match (r.method.as_str(), r.path.as_str()) {
            ("GET", "/rest/api/3/issue/PRC-1/transitions") => (
                200,
                json!({"transitions": [
                    {"id": "11", "name": "Back to do", "to": {"name": "To Do", "statusCategory": {"key": "new"}}},
                    {"id": "21", "name": "Start", "to": {"name": "In Progress", "statusCategory": {"key": "indeterminate"}}},
                    {"id": "31", "name": "Send to review", "to": {"name": "In Review", "statusCategory": {"key": "indeterminate"}}},
                    {"id": "41", "name": "Won't do", "to": {"name": "Closed", "statusCategory": {"key": "done"}}},
                    {"id": "51", "name": "Done", "to": {"name": "Done", "statusCategory": {"key": "done"}}}
                ]})
                .to_string(),
            ),
            ("POST", "/rest/api/3/issue/PRC-1/transitions") => (204, String::new()),
            _ => (404, json!({"errorMessages": ["Issue does not exist"]}).to_string()),
        }
        });
        let connector = JiraConnector::default();
        let src = source(&server.url);
        let mut task = to_task(&src, &server.url, &issue("PRC-1", "new", "To Do")).unwrap();
        for status in [
            TaskStatus::Doing,
            TaskStatus::Review,
            TaskStatus::Done,
            TaskStatus::Todo,
        ] {
            connector
                .set_status(&src, Some("tok"), &task, status)
                .unwrap();
        }
        let chosen: Vec<_> = server
            .requests()
            .iter()
            .filter(|r| r.method == "POST")
            .map(|r| r.json()["transition"]["id"].as_str().unwrap().to_owned())
            .collect();
        assert_eq!(chosen, ["21", "31", "51", "11"]);

        task.ticket = Some("PRC-9".into());
        let missing = connector.set_status(&src, Some("tok"), &task, TaskStatus::Done);
        assert_eq!(
            missing,
            Err(TaskError::Source("Jira: Issue does not exist".into()))
        );
        task.ticket = Some("../../admin".into());
        assert!(matches!(
            connector.set_status(&src, Some("tok"), &task, TaskStatus::Done),
            Err(TaskError::UnknownTask(_))
        ));
    }

    #[test]
    fn explains_rejected_credentials() {
        let server = TestServer::start(|_| (401, String::new()));
        let connector = JiraConnector::default();
        assert!(matches!(
            connector.test(&source(&server.url), Some("bad")),
            Err(TaskError::Auth(_))
        ));
        assert!(matches!(
            connector.fetch(&source(&server.url), None),
            Err(TaskError::Auth(_))
        ));
    }
}
