use super::*;
use crate::test_server::{Request, TestServer};
use kumo_domain::tasks::{SourceId, TaskRelation};

const ME: &str = "5b10ac8d82e05b22cc7d4ef5";

fn fixture(json: &str) -> Value {
    serde_json::from_str(json).unwrap()
}

fn source_with(site: &str, jql: &str) -> TaskSource {
    TaskSource {
        id: SourceId::parse("ji").unwrap(),
        name: "Jira".into(),
        options: SourceOptions::Jira {
            site: site.into(),
            email: "ana@acme.com".into(),
            jql: jql.into(),
        },
        enabled: true,
    }
}

fn source(site: &str) -> TaskSource {
    source_with(site, "assignee = currentUser()")
}

/// A Jira site answering with the recorded fixtures; searches go to
/// `search`.
fn site(search: impl Fn(&Request) -> (u16, Value) + Send + Sync + 'static) -> TestServer {
    TestServer::start(move |r| {
        let path = r.path.split('?').next().unwrap_or_default();
        let (status, body) = match (r.method.as_str(), path) {
            ("GET", "/rest/api/3/myself") => {
                (200, fixture(include_str!("fixtures/jira_myself.json")))
            }
            ("GET", "/rest/api/3/field") => {
                (200, fixture(include_str!("fixtures/jira_fields.json")))
            }
            ("POST", "/rest/api/3/search/jql") => search(r),
            ("GET", "/rest/api/3/issue/PRC-11355") => {
                (200, fixture(include_str!("fixtures/jira_issue.json")))
            }
            ("GET", "/rest/api/3/issue/PRC-11355/comment") if r.path.contains("startAt=0&") => {
                (200, fixture(include_str!("fixtures/jira_comments_1.json")))
            }
            ("GET", "/rest/api/3/issue/PRC-11355/comment") if r.path.contains("startAt=4&") => {
                (200, fixture(include_str!("fixtures/jira_comments_2.json")))
            }
            _ => (
                404,
                json!({"errorMessages": ["Issue does not exist or you do not have permission to see it."]}),
            ),
        };
        (status, body.to_string())
    })
}

fn searches(server: &TestServer) -> Vec<String> {
    server
        .requests()
        .iter()
        .filter(|r| r.path == "/rest/api/3/search/jql")
        .map(|r| r.json()["jql"].as_str().unwrap_or_default().to_owned())
        .collect()
}

fn issue(key: &str, category: &str, status: &str) -> Value {
    json!({"key": key, "fields": {
        "summary": format!("Issue {key}"),
        "status": {"name": status, "statusCategory": {"key": category}},
        "priority": {"name": "High"},
        "duedate": "2026-11-05",
        "project": {"key": "PRC", "name": "Pricing"},
        "labels": ["backend"],
        "updated": "2026-10-27T10:00:00.000+0000"
    }})
}

fn ms(at: Option<kumo_domain::time::Timestamp>) -> u64 {
    at.map_or(0, |t| t.as_unix_nanos() / 1_000_000)
}

#[test]
fn pages_through_the_search_and_maps_statuses() {
    let server = site(|r| {
        if r.json()["nextPageToken"].is_null() {
            (
                200,
                json!({"issues": [issue("PRC-1", "new", "To Do"), issue("PRC-2", "indeterminate", "In Progress")],
                       "nextPageToken": "p2", "isLast": false}),
            )
        } else {
            (
                200,
                json!({"issues": [issue("PRC-3", "indeterminate", "Code Review"), issue("PRC-4", "done", "Done")],
                       "isLast": true}),
            )
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
    assert_eq!(tasks[2].source_status, "Code Review");

    let requests: Vec<Request> = server
        .requests()
        .into_iter()
        .filter(|r| r.path == "/rest/api/3/search/jql")
        .collect();
    assert_eq!(requests.len(), 2);
    assert_eq!(requests[1].json()["nextPageToken"], "p2");
    assert_eq!(requests[0].json()["jql"], "assignee = currentUser()");
    let expected = format!("Basic {}", BASE64.encode("ana@acme.com:tok"));
    assert_eq!(requests[0].header("authorization"), Some(expected.as_str()));
}

#[test]
fn default_scope_adds_the_recent_issues_of_the_users_projects() {
    let server = site(|r| {
        let jql = r.json()["jql"].as_str().unwrap_or_default().to_owned();
        if jql == MINE_JQL {
            (200, fixture(include_str!("fixtures/jira_search_mine.json")))
        } else {
            (200, fixture(include_str!("fixtures/jira_search_team.json")))
        }
    });
    let connector = JiraConnector::default();
    let src = source_with(&server.url, "");
    let tasks = connector.fetch(&src, Some("tok")).unwrap();

    assert_eq!(
        searches(&server),
        [
            MINE_JQL.to_owned(),
            "project in (\"PRC\", \"OPS\") AND (sprint in openSprints() OR updated >= -14d) AND (statusCategory != Done OR updated >= -14d) ORDER BY updated DESC".to_owned(),
        ]
    );
    let fields = &server.requests()[2].json()["fields"];
    for custom in [
        "customfield_10016",
        "customfield_10028",
        "customfield_10020",
    ] {
        assert!(
            fields.as_array().unwrap().iter().any(|f| f == custom),
            "{custom} in {fields}"
        );
    }

    // One of each, newest first; mine from the assignee, whichever search
    // brought it.
    let summary: Vec<_> = tasks.iter().map(|t| (t.key.as_str(), t.mine)).collect();
    assert_eq!(
        summary,
        [
            ("PRC-398", true),
            ("PRC-10599", false),
            ("PRC-11355", true),
            ("PRC-11366", false),
            ("PRC-11354", true),
            ("OPS-7", true),
        ]
    );
    let by_key = |key: &str| tasks.iter().find(|t| t.key == key).unwrap();

    let story = by_key("PRC-11355");
    assert_eq!(
        (
            story.kind,
            story.type_name.as_str(),
            story.source_status.as_str()
        ),
        (TaskType::Story, "Story", "In Progress")
    );
    assert_eq!(story.status, TaskStatus::Doing);
    let me = story.assignee.as_ref().unwrap();
    assert_eq!(
        (
            me.id.as_str(),
            me.name.as_str(),
            me.initials.as_str(),
            me.you
        ),
        (ME, "Mauri Fernández", "MF", true)
    );
    assert!(story.relations.contains(&TaskRelation::Assigned));
    assert_eq!(story.points.map(Points::as_f64), Some(5.0));
    assert_eq!(story.subtasks, Progress { done: 1, total: 4 });
    assert_eq!(story.comment_count, 6);
    assert!(!story.blocked, "its blocker is done");
    let epic = story.parent.as_ref().unwrap();
    assert_eq!(
        (
            epic.key.as_str(),
            epic.title.as_str(),
            epic.kind,
            epic.status
        ),
        (
            "PRC-11300",
            "Migración a Graviton",
            TaskType::Epic,
            TaskStatus::Doing
        )
    );
    assert_eq!(epic.id.as_ref().unwrap().as_str(), "ji/PRC-11300");
    let sprint = story.sprint.as_ref().unwrap();
    assert_eq!(
        (sprint.name.as_str(), sprint.state),
        ("Pricing 2026.22", SprintState::Active)
    );
    assert_eq!(ms(sprint.start), 1_792_584_000_000);
    assert_eq!(ms(sprint.end), 1_793_793_600_000);

    let bug = by_key("PRC-398");
    assert_eq!((bug.kind, bug.priority), (TaskType::Bug, Priority::High));
    assert_eq!(
        bug.points.map(Points::as_f64),
        Some(2.0),
        "from the other points field"
    );
    assert_eq!(bug.sprint, None);

    let unassigned = by_key("PRC-10599");
    assert_eq!(unassigned.assignee, None);
    assert!(unassigned.relations.is_empty());
    assert_eq!(unassigned.due.as_deref(), Some("2026-10-26"));
    assert_eq!(
        unassigned
            .sprint
            .as_ref()
            .map(|s| (s.name.as_str(), s.state)),
        Some(("Pricing 2026.21", SprintState::Closed))
    );
    assert!(!unassigned.blocked, "duplicates isn't blocking");

    let sub = by_key("PRC-11354");
    assert_eq!(sub.kind, TaskType::Subtask);
    assert!(sub.blocked, "blocked by PRC-11355, in progress");
    assert_eq!(sub.parent.as_ref().unwrap().key, "PRC-11300");

    let theirs = by_key("PRC-11366");
    let nico = theirs.assignee.as_ref().unwrap();
    assert_eq!(
        (nico.name.as_str(), nico.initials.as_str(), nico.you),
        ("Nico", "N", false)
    );
    assert_eq!(
        theirs.sprint.as_ref().unwrap().state,
        SprintState::Active,
        "the active sprint wins over the next"
    );
    assert_eq!(by_key("OPS-7").status, TaskStatus::Review);

    // Fields are read once per site; who the user is, on every sync.
    connector.fetch(&src, Some("tok")).unwrap();
    let count = |path: &str| server.requests().iter().filter(|r| r.path == path).count();
    assert_eq!(count("/rest/api/3/field"), 1);
    assert_eq!(count("/rest/api/3/myself"), 2);
}

#[test]
fn a_custom_jql_is_everyone_and_mine_is_still_the_assignee() {
    let server = site(|_| (200, fixture(include_str!("fixtures/jira_search_team.json"))));
    let src = source_with(&server.url, "project = PRC ORDER BY rank");
    let tasks = JiraConnector::default().fetch(&src, Some("tok")).unwrap();
    assert_eq!(searches(&server), ["project = PRC ORDER BY rank"]);
    let keys: Vec<_> = tasks.iter().map(|t| (t.key.as_str(), t.mine)).collect();
    assert_eq!(
        keys,
        [
            ("PRC-10599", false),
            ("PRC-11354", true),
            ("PRC-11366", false),
            ("PRC-11355", true)
        ],
        "in Jira's order"
    );
}

#[test]
fn sources_saved_with_the_old_default_get_the_new_scope() {
    let server = site(|r| {
        if r.json()["jql"] == MINE_JQL {
            (200, fixture(include_str!("fixtures/jira_search_mine.json")))
        } else {
            (200, json!({"issues": [], "isLast": true}))
        }
    });
    let options = SourceOptions::from_map(
        SourceKind::Jira,
        &[
            ("site", server.url.as_str()),
            ("email", "ana@acme.com"),
            ("jql", SourceOptions::LEGACY_JIRA_JQL),
        ]
        .into_iter()
        .map(|(k, v)| (k.to_owned(), v.to_owned()))
        .collect(),
    )
    .unwrap();
    let src = TaskSource {
        options,
        ..source(&server.url)
    };
    JiraConnector::default().fetch(&src, Some("tok")).unwrap();
    let jqls = searches(&server);
    assert_eq!(jqls.len(), 2, "{jqls:?}");
    assert!(
        jqls[1].starts_with("project in (\"PRC\", \"OPS\")"),
        "{jqls:?}"
    );
}

#[test]
fn finds_projects_without_assigned_issues_and_without_sprints() {
    let server = site(|r| {
        let jql = r.json()["jql"].as_str().unwrap_or_default().to_owned();
        match jql.as_str() {
            MINE_JQL => (200, json!({"issues": [], "isLast": true})),
            RECENT_JQL => (
                200,
                json!({"issues": [{"key": "WEB-1", "fields": {"project": {"key": "WEB", "name": "Web"}}}], "isLast": true}),
            ),
            jql if jql.contains("openSprints") => (
                400,
                json!({"errorMessages": ["Field 'sprint' does not exist or this field cannot be viewed by anonymous users."]}),
            ),
            _ => (
                200,
                json!({"issues": [issue("WEB-2", "new", "To Do")], "isLast": true}),
            ),
        }
    });
    let tasks = JiraConnector::default()
        .fetch(&source_with(&server.url, ""), Some("tok"))
        .unwrap();
    assert_eq!(tasks.len(), 1);
    assert!(!tasks[0].mine);
    let jqls = searches(&server);
    assert_eq!(jqls.len(), 4, "{jqls:?}");
    assert_eq!(jqls[1], RECENT_JQL);
    assert_eq!(
        jqls[3],
        "project in (\"WEB\") AND (updated >= -14d) AND (statusCategory != Done OR updated >= -14d) ORDER BY updated DESC"
    );
}

#[test]
fn reads_the_whole_ticket() {
    let server = site(|_| (200, fixture(include_str!("fixtures/jira_children.json"))));
    let src = source(&server.url);
    let id = TaskId::new(&src.id, "PRC-11355");
    let detail = JiraConnector::default()
        .detail(&src, Some("tok"), &id, None)
        .unwrap();
    assert_eq!(
        searches(&server),
        ["parent = PRC-11355 ORDER BY created ASC"],
        "only the children are searched"
    );

    let issue_request = server
        .requests()
        .into_iter()
        .find(|r| r.path.starts_with("/rest/api/3/issue/PRC-11355?"))
        .unwrap();
    assert!(
        issue_request.path.contains("customfield_10050")
            && issue_request.path.contains("attachment"),
        "{}",
        issue_request.path
    );

    let task = &detail.task;
    assert_eq!(
        (task.id.as_str(), task.title.as_str()),
        ("ji/PRC-11355", "migraciones")
    );
    assert!(task.mine);
    assert_eq!(task.comment_count, 6);
    let reporter = detail.reporter.as_ref().unwrap();
    assert_eq!(
        (
            reporter.name.as_str(),
            reporter.initials.as_str(),
            reporter.you
        ),
        ("Ana Gómez", "AG", false)
    );
    assert_eq!(ms(detail.created), 1_791_994_800_000);
    assert_eq!(
        detail.description,
        "## Contexto\n\nEste ticket cubre las **migraciones de base**. @Ana Gómez confirmó la ventana.\n\n![graviton-rollout.png](graviton-rollout.png)"
    );
    assert_eq!(
        detail.acceptance_criteria,
        "- [x] Las migraciones corren en staging sin downtime\n- [ ] Los conteos de `price_history` coinciden antes y después"
    );

    let subtasks: Vec<_> = detail
        .subtasks
        .iter()
        .map(|s| {
            (
                s.key.as_str(),
                s.status,
                s.assignee.as_ref().map(|a| a.name.as_str()),
            )
        })
        .collect();
    assert_eq!(
        subtasks,
        [
            ("PRC-11356", TaskStatus::Done, Some("Mauri Fernández")),
            ("PRC-11357", TaskStatus::Doing, Some("Mauri Fernández")),
            ("PRC-11358", TaskStatus::Todo, Some("Ana Gómez")),
            ("PRC-11359", TaskStatus::Todo, None),
        ]
    );
    assert_eq!(detail.subtasks[0].kind, TaskType::Subtask);
    assert_eq!(
        detail.subtasks[0].id.as_ref().unwrap().as_str(),
        "ji/PRC-11356"
    );

    let links: Vec<_> = detail
        .links
        .iter()
        .map(|l| {
            (
                l.kind,
                l.relation.as_str(),
                l.task.key.as_str(),
                l.task.status,
            )
        })
        .collect();
    assert_eq!(
        links,
        [
            (
                LinkKind::BlockedBy,
                "is blocked by",
                "PRC-11340",
                TaskStatus::Done
            ),
            (
                LinkKind::Relates,
                "relates to",
                "PRC-11321",
                TaskStatus::Todo
            ),
            (LinkKind::Other, "clones", "PRC-11290", TaskStatus::Done),
        ]
    );
    assert_eq!(
        detail.links[0].task.url.as_deref(),
        Some(format!("{}/browse/PRC-11340", server.url).as_str())
    );

    let attachments: Vec<_> = detail
        .attachments
        .iter()
        .map(|a| (a.name.as_str(), a.kind.as_str(), a.size_bytes))
        .collect();
    assert_eq!(
        attachments,
        [
            ("graviton-rollout.png", "PNG image", 421_888),
            ("price_history_counts.csv", "CSV", 90_112),
            ("migracion-graviton.pdf", "PDF", 1_258_291),
            ("precios-hijas-2026-10-25.log", "Log", 2_516_582),
        ]
    );
    assert_eq!(
        detail.attachments[0].url.as_deref(),
        Some("https://acme.atlassian.net/rest/api/3/attachment/content/30001")
    );

    assert_eq!(detail.comments.len(), 6, "both pages");
    let first = &detail.comments[0];
    assert_eq!(first.author.as_ref().unwrap().name, "Ana Gómez");
    assert_eq!(
        first.body,
        "Te lo asigno para este sprint. La ventana es el **jueves 30 a las 22 h**."
    );
    assert_eq!(
        detail.comments[1].body,
        "Ojo que `price_history` tiene unos 40 M de filas."
    );
    assert!(detail.comments[2].author.as_ref().unwrap().you);
    assert_eq!(
        detail.comments[4].body,
        "@Mauri Fernández ¿llegamos con staging antes del jueves?"
    );
    assert!(
        detail
            .comments
            .windows(2)
            .all(|w| w[0].created <= w[1].created),
        "oldest first"
    );

    assert_eq!(detail.components, ["price-admin", "price-reader-v2"]);
    assert_eq!(detail.fix_versions, ["2026.11"]);
    assert_eq!(
        detail.time_tracking,
        Some(TimeTracking {
            estimate: "3d".into(),
            logged: "1d 4h".into(),
            remaining: "1d 6h".into(),
            estimate_seconds: 86_400,
            logged_seconds: 43_200,
            remaining_seconds: 50_400,
        })
    );
    assert_eq!(
        task.sprint.as_ref().map(|s| s.name.as_str()),
        Some("Pricing 2026.22")
    );
    assert_eq!(detail.location, "");
}

#[test]
fn refuses_ids_that_arent_issue_keys() {
    let server = site(|_| (200, json!({"issues": [], "isLast": true})));
    let src = source(&server.url);
    let connector = JiraConnector::default();
    for bad in ["../../admin", "PRC-1/comment", "prc", "PRC-x"] {
        let id = TaskId::new(&src.id, bad);
        assert!(
            matches!(
                connector.detail(&src, Some("tok"), &id, None),
                Err(TaskError::UnknownTask(_))
            ),
            "{bad}"
        );
    }
    assert!(server.requests().is_empty());
    let missing = connector.detail(&src, Some("tok"), &TaskId::new(&src.id, "PRC-9"), None);
    assert!(matches!(missing, Err(TaskError::Source(_))), "{missing:?}");
}

#[test]
fn names_attachments_and_links_readably() {
    assert_eq!(attachment_kind("image/jpeg", "a.jpg"), "JPEG image");
    assert_eq!(attachment_kind("image/svg+xml", "a.svg"), "SVG image");
    assert_eq!(attachment_kind("text/csv", "x"), "CSV");
    assert_eq!(
        attachment_kind("application/octet-stream", "dump.sql"),
        "SQL"
    );
    assert_eq!(attachment_kind("text/plain", "notes.txt"), "Text");
    assert_eq!(attachment_kind("text/plain", "README"), "Text");
    assert_eq!(attachment_kind("", "blob"), "File");
    assert_eq!(
        attachment_kind(
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "a.xlsx"
        ),
        "Spreadsheet"
    );
    assert_eq!(
        link_kind("Duplicate", true, "is duplicated by"),
        LinkKind::DuplicatedBy
    );
    assert_eq!(
        link_kind("Duplicate", false, "duplicates"),
        LinkKind::Duplicates
    );
    assert_eq!(link_kind("Blocks", false, "blocks"), LinkKind::Blocks);
    assert_eq!(
        link_kind("Bloquea", true, "is blocked by"),
        LinkKind::BlockedBy
    );
    assert_eq!(link_kind("Cloners", true, "is cloned by"), LinkKind::Other);
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
    let fields = CustomFields::default();
    let map = Mapping {
        source: &src,
        site: &server.url,
        me: ME,
        fields: &fields,
    };
    let mut task = to_task(&map, &issue("PRC-1", "new", "To Do")).unwrap();
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
    assert!(matches!(
        connector.fetch(&source(&server.url), Some("bad")),
        Err(TaskError::Auth(_))
    ));
}
