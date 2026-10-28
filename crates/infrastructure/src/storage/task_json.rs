//! Tasks' nested fields and cached details as JSON in SQLite. The shapes
//! here are the storage format: fields are only ever added (with defaults),
//! so caches written by another version still read.

use std::collections::BTreeSet;

use kumo_domain::tasks::{
    Attachment, Comment, LinkKind, LinkedTask, Person, Points, Priority, Progress, SourceId,
    Sprint, SprintState, Task, TaskDetail, TaskId, TaskRef, TaskRelation, TaskStatus, TaskType,
    TimeTracking,
};
use kumo_domain::time::Timestamp;
use serde::{Deserialize, Serialize};

// ---- Codes ----

pub(super) fn status_code(status: TaskStatus) -> i64 {
    match status {
        TaskStatus::Todo => 0,
        TaskStatus::Doing => 1,
        TaskStatus::Review => 2,
        TaskStatus::Done => 3,
    }
}

pub(super) fn status_from(code: i64) -> TaskStatus {
    match code {
        1 => TaskStatus::Doing,
        2 => TaskStatus::Review,
        3 => TaskStatus::Done,
        _ => TaskStatus::Todo,
    }
}

pub(super) fn priority_code(priority: Priority) -> i64 {
    match priority {
        Priority::None => 0,
        Priority::Low => 1,
        Priority::Medium => 2,
        Priority::High => 3,
        Priority::Urgent => 4,
    }
}

pub(super) fn priority_from(code: i64) -> Priority {
    match code {
        1 => Priority::Low,
        2 => Priority::Medium,
        3 => Priority::High,
        4 => Priority::Urgent,
        _ => Priority::None,
    }
}

pub(super) fn type_code(kind: TaskType) -> i64 {
    match kind {
        TaskType::Unknown => 0,
        TaskType::Story => 1,
        TaskType::Bug => 2,
        TaskType::Task => 3,
        TaskType::Subtask => 4,
        TaskType::Epic => 5,
        TaskType::Issue => 6,
        TaskType::Todo => 7,
    }
}

pub(super) fn type_from(code: i64) -> TaskType {
    match code {
        1 => TaskType::Story,
        2 => TaskType::Bug,
        3 => TaskType::Task,
        4 => TaskType::Subtask,
        5 => TaskType::Epic,
        6 => TaskType::Issue,
        7 => TaskType::Todo,
        _ => TaskType::Unknown,
    }
}

fn relation_code(relation: TaskRelation) -> i64 {
    match relation {
        TaskRelation::Assigned => 1,
        TaskRelation::Reported => 2,
        TaskRelation::Watching => 3,
    }
}

fn relation_from(code: i64) -> Option<TaskRelation> {
    match code {
        1 => Some(TaskRelation::Assigned),
        2 => Some(TaskRelation::Reported),
        3 => Some(TaskRelation::Watching),
        _ => None,
    }
}

pub(super) fn relations_to(relations: &BTreeSet<TaskRelation>) -> Vec<i64> {
    relations.iter().map(|r| relation_code(*r)).collect()
}

pub(super) fn relations_from(codes: &[i64]) -> BTreeSet<TaskRelation> {
    codes.iter().filter_map(|c| relation_from(*c)).collect()
}

fn sprint_state_code(state: SprintState) -> i64 {
    match state {
        SprintState::Unknown => 0,
        SprintState::Closed => 1,
        SprintState::Active => 2,
        SprintState::Future => 3,
    }
}

fn sprint_state_from(code: i64) -> SprintState {
    match code {
        1 => SprintState::Closed,
        2 => SprintState::Active,
        3 => SprintState::Future,
        _ => SprintState::Unknown,
    }
}

fn link_kind_code(kind: LinkKind) -> i64 {
    match kind {
        LinkKind::Other => 0,
        LinkKind::Blocks => 1,
        LinkKind::BlockedBy => 2,
        LinkKind::Relates => 3,
        LinkKind::Duplicates => 4,
        LinkKind::DuplicatedBy => 5,
    }
}

fn link_kind_from(code: i64) -> LinkKind {
    match code {
        1 => LinkKind::Blocks,
        2 => LinkKind::BlockedBy,
        3 => LinkKind::Relates,
        4 => LinkKind::Duplicates,
        5 => LinkKind::DuplicatedBy,
        _ => LinkKind::Other,
    }
}

fn nanos(at: Option<Timestamp>) -> Option<u64> {
    at.map(Timestamp::as_unix_nanos)
}

fn at(nanos: Option<u64>) -> Option<Timestamp> {
    nanos.map(Timestamp::from_unix_nanos)
}

// ---- Shapes ----

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(default)]
pub(super) struct PersonJson {
    id: String,
    name: String,
    initials: String,
    you: bool,
}

impl PersonJson {
    pub(super) fn to(p: &Person) -> Self {
        Self {
            id: p.id.clone(),
            name: p.name.clone(),
            initials: p.initials.clone(),
            you: p.you,
        }
    }

    pub(super) fn into_person(self) -> Person {
        Person {
            id: self.id,
            name: self.name,
            initials: self.initials,
            you: self.you,
        }
    }
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(default)]
pub(super) struct SprintJson {
    name: String,
    state: i64,
    start: Option<u64>,
    end: Option<u64>,
}

impl SprintJson {
    pub(super) fn to(s: &Sprint) -> Self {
        Self {
            name: s.name.clone(),
            state: sprint_state_code(s.state),
            start: nanos(s.start),
            end: nanos(s.end),
        }
    }

    pub(super) fn into_sprint(self) -> Sprint {
        Sprint {
            name: self.name,
            state: sprint_state_from(self.state),
            start: at(self.start),
            end: at(self.end),
        }
    }
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(default)]
pub(super) struct TaskRefJson {
    id: Option<String>,
    key: String,
    title: String,
    kind: i64,
    source_status: String,
    status: i64,
    assignee: Option<PersonJson>,
    color: String,
    url: Option<String>,
}

impl TaskRefJson {
    pub(super) fn to(r: &TaskRef) -> Self {
        Self {
            id: r.id.as_ref().map(ToString::to_string),
            key: r.key.clone(),
            title: r.title.clone(),
            kind: type_code(r.kind),
            source_status: r.source_status.clone(),
            status: status_code(r.status),
            assignee: r.assignee.as_ref().map(PersonJson::to),
            color: r.color.clone(),
            url: r.url.clone(),
        }
    }

    pub(super) fn into_ref(self) -> TaskRef {
        TaskRef {
            id: self.id.and_then(|id| TaskId::parse(&id).ok()),
            key: self.key,
            title: self.title,
            kind: type_from(self.kind),
            source_status: self.source_status,
            status: status_from(self.status),
            assignee: self.assignee.map(PersonJson::into_person),
            color: self.color,
            url: self.url,
        }
    }
}

/// A whole task (the board keeps its fields in columns; a detail carries
/// its own copy).
#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(default)]
struct TaskJson {
    external: String,
    key: String,
    ticket: Option<String>,
    title: String,
    status: i64,
    priority: i64,
    due: Option<String>,
    url: Option<String>,
    context: String,
    labels: Vec<String>,
    updated: Option<u64>,
    kind: i64,
    type_name: String,
    source_status: String,
    assignee: Option<PersonJson>,
    relations: Vec<i64>,
    mine: bool,
    points: Option<u32>,
    subtasks_done: u32,
    subtasks_total: u32,
    comment_count: u32,
    parent: Option<TaskRefJson>,
    blocked: bool,
    sprint: Option<SprintJson>,
}

impl TaskJson {
    fn to(t: &Task) -> Self {
        Self {
            external: t.id.external().to_owned(),
            key: t.key.clone(),
            ticket: t.ticket.clone(),
            title: t.title.clone(),
            status: status_code(t.status),
            priority: priority_code(t.priority),
            due: t.due.clone(),
            url: t.url.clone(),
            context: t.context.clone(),
            labels: t.labels.clone(),
            updated: nanos(t.updated),
            kind: type_code(t.kind),
            type_name: t.type_name.clone(),
            source_status: t.source_status.clone(),
            assignee: t.assignee.as_ref().map(PersonJson::to),
            relations: relations_to(&t.relations),
            mine: t.mine,
            points: t.points.map(Points::hundredths),
            subtasks_done: t.subtasks.done,
            subtasks_total: t.subtasks.total,
            comment_count: t.comment_count,
            parent: t.parent.as_ref().map(TaskRefJson::to),
            blocked: t.blocked,
            sprint: t.sprint.as_ref().map(SprintJson::to),
        }
    }

    fn into_task(self, source: &SourceId) -> Task {
        Task {
            key: self.key,
            ticket: self.ticket,
            status: status_from(self.status),
            priority: priority_from(self.priority),
            due: self.due,
            url: self.url,
            context: self.context,
            labels: self.labels,
            updated: at(self.updated),
            kind: type_from(self.kind),
            type_name: self.type_name,
            source_status: self.source_status,
            assignee: self.assignee.map(PersonJson::into_person),
            relations: relations_from(&self.relations),
            mine: self.mine,
            points: self.points.map(Points::from_hundredths),
            subtasks: Progress {
                done: self.subtasks_done,
                total: self.subtasks_total,
            },
            comment_count: self.comment_count,
            parent: self.parent.map(TaskRefJson::into_ref),
            blocked: self.blocked,
            sprint: self.sprint.map(SprintJson::into_sprint),
            ..Task::new(TaskId::new(source, &self.external), self.title)
        }
    }
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(default)]
struct LinkJson {
    kind: i64,
    relation: String,
    task: TaskRefJson,
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(default)]
struct AttachmentJson {
    name: String,
    kind: String,
    size: u64,
    url: Option<String>,
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(default)]
struct CommentJson {
    author: Option<PersonJson>,
    created: Option<u64>,
    body: String,
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(default)]
struct TimeJson {
    estimate: String,
    logged: String,
    remaining: String,
    estimate_seconds: u64,
    logged_seconds: u64,
    remaining_seconds: u64,
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(default)]
struct DetailJson {
    task: TaskJson,
    reporter: Option<PersonJson>,
    created: Option<u64>,
    description: String,
    acceptance_criteria: String,
    subtasks: Vec<TaskRefJson>,
    links: Vec<LinkJson>,
    attachments: Vec<AttachmentJson>,
    comments: Vec<CommentJson>,
    components: Vec<String>,
    fix_versions: Vec<String>,
    time_tracking: Option<TimeJson>,
    location: String,
}

/// The detail without its fetch time and staleness (kept in columns, or
/// decided when it's served).
pub(super) fn detail_to_json(d: &TaskDetail) -> serde_json::Result<String> {
    serde_json::to_string(&DetailJson {
        task: TaskJson::to(&d.task),
        reporter: d.reporter.as_ref().map(PersonJson::to),
        created: nanos(d.created),
        description: d.description.clone(),
        acceptance_criteria: d.acceptance_criteria.clone(),
        subtasks: d.subtasks.iter().map(TaskRefJson::to).collect(),
        links: d
            .links
            .iter()
            .map(|l| LinkJson {
                kind: link_kind_code(l.kind),
                relation: l.relation.clone(),
                task: TaskRefJson::to(&l.task),
            })
            .collect(),
        attachments: d
            .attachments
            .iter()
            .map(|a| AttachmentJson {
                name: a.name.clone(),
                kind: a.kind.clone(),
                size: a.size_bytes,
                url: a.url.clone(),
            })
            .collect(),
        comments: d
            .comments
            .iter()
            .map(|c| CommentJson {
                author: c.author.as_ref().map(PersonJson::to),
                created: nanos(c.created),
                body: c.body.clone(),
            })
            .collect(),
        components: d.components.clone(),
        fix_versions: d.fix_versions.clone(),
        time_tracking: d.time_tracking.as_ref().map(|t| TimeJson {
            estimate: t.estimate.clone(),
            logged: t.logged.clone(),
            remaining: t.remaining.clone(),
            estimate_seconds: t.estimate_seconds,
            logged_seconds: t.logged_seconds,
            remaining_seconds: t.remaining_seconds,
        }),
        location: d.location.clone(),
    })
}

pub(super) fn detail_from_json(
    source: &SourceId,
    json: &str,
    fetched: Timestamp,
) -> serde_json::Result<TaskDetail> {
    let d: DetailJson = serde_json::from_str(json)?;
    Ok(TaskDetail {
        task: d.task.into_task(source),
        reporter: d.reporter.map(PersonJson::into_person),
        created: at(d.created),
        description: d.description,
        acceptance_criteria: d.acceptance_criteria,
        subtasks: d.subtasks.into_iter().map(TaskRefJson::into_ref).collect(),
        links: d
            .links
            .into_iter()
            .map(|l| LinkedTask {
                kind: link_kind_from(l.kind),
                relation: l.relation,
                task: l.task.into_ref(),
            })
            .collect(),
        attachments: d
            .attachments
            .into_iter()
            .map(|a| Attachment {
                name: a.name,
                kind: a.kind,
                size_bytes: a.size,
                url: a.url,
            })
            .collect(),
        comments: d
            .comments
            .into_iter()
            .map(|c| Comment {
                author: c.author.map(PersonJson::into_person),
                created: at(c.created),
                body: c.body,
            })
            .collect(),
        components: d.components,
        fix_versions: d.fix_versions,
        time_tracking: d.time_tracking.map(|t| TimeTracking {
            estimate: t.estimate,
            logged: t.logged,
            remaining: t.remaining,
            estimate_seconds: t.estimate_seconds,
            logged_seconds: t.logged_seconds,
            remaining_seconds: t.remaining_seconds,
        }),
        location: d.location,
        fetched,
        stale: None,
    })
}
