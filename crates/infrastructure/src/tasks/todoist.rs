//! Todoist's API (v1), with a personal API token (Settings › Integrations
//! › Developer).

use std::path::PathBuf;

use kumo_domain::tasks::{
    Detected, Priority, SourceKind, SourceOptions, Task, TaskConnector, TaskError, TaskId,
    TaskSource, TaskStatus,
};
use kumo_domain::time::Timestamp;
use serde_json::{Value, json};

use super::dates::{date_part, parse_timestamp};
use super::http::Http;

const API: &str = "https://api.todoist.com/api/v1";

#[derive(Debug)]
pub struct TodoistConnector {
    http: Http,
    api: String,
}

impl Default for TodoistConnector {
    fn default() -> Self {
        Self::with_api(API)
    }
}

impl TodoistConnector {
    /// Against another server (tests).
    pub fn with_api(api: impl Into<String>) -> Self {
        Self {
            http: Http::new(SourceKind::Todoist),
            api: api.into(),
        }
    }

    fn sync(&self, token: Option<&str>, form: &[(&str, &str)]) -> Result<Value, TaskError> {
        let token = token.ok_or_else(|| TaskError::Auth("enter your Todoist API token".into()))?;
        self.http.post_form(
            &format!("{}/sync", self.api),
            &format!("Bearer {token}"),
            form,
        )
    }

    fn project(source: &TaskSource) -> Result<&str, TaskError> {
        match &source.options {
            SourceOptions::Todoist { project } => Ok(project.trim()),
            _ => Err(TaskError::Invalid("not a Todoist source".into())),
        }
    }
}

impl TaskConnector for TodoistConnector {
    fn kind(&self) -> SourceKind {
        SourceKind::Todoist
    }

    /// A full sync: open tasks with their projects, in one request.
    fn fetch(&self, source: &TaskSource, secret: Option<&str>) -> Result<Vec<Task>, TaskError> {
        let only = Self::project(source)?;
        let data = self.sync(
            secret,
            &[
                ("sync_token", "*"),
                ("resource_types", r#"["items","projects"]"#),
            ],
        )?;
        let projects: Vec<(&str, &str)> = list(&data, "projects")
            .filter_map(|p| Some((p.get("id")?.as_str()?, p.get("name")?.as_str()?)))
            .collect();
        let project_name = |id: &str| projects.iter().find(|(p, _)| *p == id).map(|(_, n)| *n);
        if !only.is_empty() && !projects.iter().any(|(_, n)| n.eq_ignore_ascii_case(only)) {
            return Err(TaskError::Invalid(format!(
                "there's no Todoist project named “{only}”"
            )));
        }
        Ok(list(&data, "items")
            .filter(|item| !flag(item, "is_deleted"))
            .filter_map(|item| {
                let project = item
                    .get("project_id")
                    .and_then(Value::as_str)
                    .and_then(project_name)
                    .unwrap_or_default();
                if !only.is_empty() && !project.eq_ignore_ascii_case(only) {
                    return None;
                }
                to_task(source, item, project)
            })
            .collect())
    }

    fn set_status(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        task: &Task,
        status: TaskStatus,
    ) -> Result<(), TaskError> {
        let command = match status {
            TaskStatus::Done => "item_close",
            TaskStatus::Todo => "item_uncomplete",
            status => {
                return Err(TaskError::Unsupported {
                    kind: source.kind(),
                    status,
                });
            }
        };
        let uuid = format!(
            "kumo-{}-{}",
            task.id.external(),
            Timestamp::now().as_unix_nanos()
        );
        let commands = json!([{"type": command, "uuid": uuid, "args": {"id": task.id.external()}}]);
        let answer = self.sync(secret, &[("commands", &commands.to_string())])?;
        match answer.pointer(&format!("/sync_status/{uuid}")) {
            Some(Value::String(ok)) if ok == "ok" => Ok(()),
            Some(error) => Err(TaskError::Source(format!(
                "Todoist refused: {}",
                error
                    .get("error")
                    .and_then(Value::as_str)
                    .unwrap_or("unknown error")
            ))),
            None => Err(TaskError::Source(
                "Todoist didn't confirm the change".into(),
            )),
        }
    }

    fn test(&self, source: &TaskSource, secret: Option<&str>) -> Result<String, TaskError> {
        Self::project(source)?;
        let data = self.sync(
            secret,
            &[("sync_token", "*"), ("resource_types", r#"["user"]"#)],
        )?;
        let user = data
            .get("user")
            .ok_or_else(|| TaskError::Source("Todoist didn't say who you are".into()))?;
        let name = user
            .get("full_name")
            .or_else(|| user.get("email"))
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

fn list<'a>(data: &'a Value, key: &str) -> impl Iterator<Item = &'a Value> {
    data.get(key)
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
}

fn flag(item: &Value, key: &str) -> bool {
    item.get(key).and_then(Value::as_bool).unwrap_or(false)
}

fn to_task(source: &TaskSource, item: &Value, project: &str) -> Option<Task> {
    let id = item.get("id")?.as_str()?;
    Some(Task {
        id: TaskId::new(&source.id, id),
        key: project.to_owned(),
        ticket: None,
        title: item.get("content")?.as_str()?.to_owned(),
        status: if flag(item, "checked") {
            TaskStatus::Done
        } else {
            TaskStatus::Todo
        },
        // Todoist counts up: 4 is the red "P1".
        priority: match item.get("priority").and_then(Value::as_u64) {
            Some(4) => Priority::Urgent,
            Some(3) => Priority::High,
            Some(2) => Priority::Medium,
            _ => Priority::None,
        },
        due: item
            .pointer("/due/date")
            .and_then(Value::as_str)
            .and_then(date_part),
        url: Some(format!("https://app.todoist.com/app/task/{id}")),
        context: String::new(),
        labels: list(item, "labels")
            .filter_map(|l| l.as_str().map(str::to_owned))
            .collect(),
        updated: item
            .get("updated_at")
            .or_else(|| item.get("added_at"))
            .and_then(Value::as_str)
            .and_then(parse_timestamp),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_server::TestServer;
    use kumo_domain::tasks::SourceId;

    fn source(project: &str) -> TaskSource {
        TaskSource {
            id: SourceId::parse("td").unwrap(),
            name: "Todoist".into(),
            options: SourceOptions::Todoist {
                project: project.into(),
            },
            enabled: true,
        }
    }

    fn server() -> TestServer {
        TestServer::start(|r| {
            if r.header("authorization") != Some("Bearer tok") {
                return (401, String::new());
            }
            if let Some(commands) = r.form("commands") {
                let commands: Value = serde_json::from_str(&commands).unwrap();
                let uuid = commands[0]["uuid"].as_str().unwrap().to_owned();
                let status = if commands[0]["args"]["id"] == "missing" {
                    json!({"error": "Item not found"})
                } else {
                    json!("ok")
                };
                return (200, json!({"sync_status": {uuid: status}}).to_string());
            }
            match r.form("resource_types").as_deref() {
                Some(r#"["user"]"#) => (200, json!({"user": {"full_name": "Ana", "email": "ana@x.y"}}).to_string()),
                _ => (
                    200,
                    json!({
                        "sync_token": "abc", "full_sync": true,
                        "projects": [{"id": "p1", "name": "Inbox"}, {"id": "p2", "name": "Home"}],
                        "items": [
                            {"id": "t1", "content": "Rotate Kafka credentials", "project_id": "p1", "priority": 4,
                             "due": {"date": "2026-10-28", "is_recurring": false}, "labels": ["ops"], "checked": false,
                             "is_deleted": false, "updated_at": "2026-10-27T10:00:00.000000Z"},
                            {"id": "t2", "content": "Water plants", "project_id": "p2", "priority": 1, "checked": false},
                            {"id": "t3", "content": "Gone", "project_id": "p2", "is_deleted": true}
                        ]
                    })
                    .to_string(),
                ),
            }
        })
    }

    #[test]
    fn reads_open_tasks_with_their_projects() {
        let server = server();
        let connector = TodoistConnector::with_api(&server.url);
        let tasks = connector.fetch(&source(""), Some("tok")).unwrap();
        let summary: Vec<_> = tasks
            .iter()
            .map(|t| (t.key.as_str(), t.title.as_str(), t.priority))
            .collect();
        assert_eq!(
            summary,
            [
                ("Inbox", "Rotate Kafka credentials", Priority::Urgent),
                ("Home", "Water plants", Priority::None)
            ]
        );
        assert_eq!(tasks[0].due.as_deref(), Some("2026-10-28"));
        assert_eq!(
            tasks[0].url.as_deref(),
            Some("https://app.todoist.com/app/task/t1")
        );

        let home = connector.fetch(&source("home"), Some("tok")).unwrap();
        assert_eq!(home.len(), 1);
        assert!(matches!(
            connector.fetch(&source("Work"), Some("tok")),
            Err(TaskError::Invalid(_))
        ));
        assert!(matches!(
            connector.fetch(&source(""), Some("bad")),
            Err(TaskError::Auth(_))
        ));
        assert_eq!(
            connector.test(&source(""), Some("tok")).unwrap(),
            "signed in as Ana"
        );
    }

    #[test]
    fn completes_and_reopens_with_sync_commands() {
        let server = server();
        let connector = TodoistConnector::with_api(&server.url);
        let mut task = connector.fetch(&source(""), Some("tok")).unwrap().remove(0);
        connector
            .set_status(&source(""), Some("tok"), &task, TaskStatus::Done)
            .unwrap();
        connector
            .set_status(&source(""), Some("tok"), &task, TaskStatus::Todo)
            .unwrap();
        let sent: Vec<String> = server
            .requests()
            .iter()
            .filter_map(|r| r.form("commands"))
            .map(|c| {
                serde_json::from_str::<Value>(&c).unwrap()[0]["type"]
                    .as_str()
                    .unwrap()
                    .to_owned()
            })
            .collect();
        assert_eq!(sent, ["item_close", "item_uncomplete"]);

        task.id = TaskId::new(&source("").id, "missing");
        assert_eq!(
            connector.set_status(&source(""), Some("tok"), &task, TaskStatus::Done),
            Err(TaskError::Source("Todoist refused: Item not found".into()))
        );
    }
}
