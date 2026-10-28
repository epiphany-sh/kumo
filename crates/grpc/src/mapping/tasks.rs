use std::collections::{BTreeMap, HashMap};

use kumo_application::tasks::{SourceView, TaskBoard};
use kumo_domain::tasks::{
    Attachment, Comment, Detected, LinkKind, LinkedTask, Person, Priority, SourceId, SourceKind,
    SourceOptions, Sprint, SprintState, Task, TaskDetail, TaskLink, TaskRef, TaskRelation,
    TaskStatus, TaskType, TimeTracking,
};
use kumo_domain::time::Timestamp;
use kumo_proto::v1 as pb;
use tonic::Status;

pub fn source_kind_to(kind: SourceKind) -> pb::TaskSourceKind {
    match kind {
        SourceKind::Obsidian => pb::TaskSourceKind::Obsidian,
        SourceKind::Bear => pb::TaskSourceKind::Bear,
        SourceKind::GitHub => pb::TaskSourceKind::Github,
        SourceKind::Jira => pb::TaskSourceKind::Jira,
        SourceKind::Todoist => pb::TaskSourceKind::Todoist,
    }
}

pub fn source_kind_from(raw: i32) -> Result<SourceKind, Status> {
    match pb::TaskSourceKind::try_from(raw) {
        Ok(pb::TaskSourceKind::Obsidian) => Ok(SourceKind::Obsidian),
        Ok(pb::TaskSourceKind::Bear) => Ok(SourceKind::Bear),
        Ok(pb::TaskSourceKind::Github) => Ok(SourceKind::GitHub),
        Ok(pb::TaskSourceKind::Jira) => Ok(SourceKind::Jira),
        Ok(pb::TaskSourceKind::Todoist) => Ok(SourceKind::Todoist),
        _ => Err(Status::invalid_argument("unknown kind of task source")),
    }
}

pub fn task_status_to(status: TaskStatus) -> pb::TaskStatus {
    match status {
        TaskStatus::Todo => pb::TaskStatus::Todo,
        TaskStatus::Doing => pb::TaskStatus::Doing,
        TaskStatus::Review => pb::TaskStatus::Review,
        TaskStatus::Done => pb::TaskStatus::Done,
    }
}

pub fn task_status_from(raw: i32) -> Result<TaskStatus, Status> {
    match pb::TaskStatus::try_from(raw) {
        Ok(pb::TaskStatus::Todo) => Ok(TaskStatus::Todo),
        Ok(pb::TaskStatus::Doing) => Ok(TaskStatus::Doing),
        Ok(pb::TaskStatus::Review) => Ok(TaskStatus::Review),
        Ok(pb::TaskStatus::Done) => Ok(TaskStatus::Done),
        Err(_) => Err(Status::invalid_argument("unknown task status")),
    }
}

fn priority_to(priority: Priority) -> pb::TaskPriority {
    match priority {
        Priority::None => pb::TaskPriority::None,
        Priority::Low => pb::TaskPriority::Low,
        Priority::Medium => pb::TaskPriority::Medium,
        Priority::High => pb::TaskPriority::High,
        Priority::Urgent => pb::TaskPriority::Urgent,
    }
}

pub fn source_options_from(
    kind: i32,
    options: HashMap<String, String>,
) -> Result<SourceOptions, kumo_domain::tasks::TaskError> {
    let kind = source_kind_from(kind)
        .map_err(|s| kumo_domain::tasks::TaskError::Invalid(s.message().to_owned()))?;
    SourceOptions::from_map(kind, &options.into_iter().collect::<BTreeMap<_, _>>())
}

pub fn source_to(view: &SourceView) -> pb::TaskSource {
    let source = &view.source;
    let kind = source.kind();
    pb::TaskSource {
        id: source.id.to_string(),
        kind: source_kind_to(kind).into(),
        name: source.name.clone(),
        options: source.options.to_map().into_iter().collect(),
        enabled: source.enabled,
        badge: kind.badge().to_owned(),
        needs_secret: kind.needs_secret(),
        has_secret: view.has_secret,
        writable: kind
            .writable()
            .iter()
            .map(|s| task_status_to(*s).into())
            .collect(),
        syncing: view.syncing,
        last_synced_unix_ms: view
            .last_synced
            .map_or(0, |t| t.as_unix_nanos() / 1_000_000),
        error: view.error.clone().unwrap_or_default(),
        task_count: u32::try_from(view.tasks.len()).unwrap_or(u32::MAX),
    }
}

fn unix_ms(at: Option<Timestamp>) -> u64 {
    at.map_or(0, |t| t.as_unix_nanos() / 1_000_000)
}

fn task_type_to(kind: TaskType) -> pb::TaskType {
    match kind {
        TaskType::Unknown => pb::TaskType::Unspecified,
        TaskType::Story => pb::TaskType::Story,
        TaskType::Bug => pb::TaskType::Bug,
        TaskType::Task => pb::TaskType::Task,
        TaskType::Subtask => pb::TaskType::Subtask,
        TaskType::Epic => pb::TaskType::Epic,
        TaskType::Issue => pb::TaskType::Issue,
        TaskType::Todo => pb::TaskType::Todo,
    }
}

fn relation_to(relation: TaskRelation) -> pb::TaskRelation {
    match relation {
        TaskRelation::Assigned => pb::TaskRelation::Assigned,
        TaskRelation::Reported => pb::TaskRelation::Reported,
        TaskRelation::Watching => pb::TaskRelation::Watching,
    }
}

fn person_to(person: &Person) -> pb::Person {
    pb::Person {
        id: person.id.clone(),
        name: person.name.clone(),
        initials: person.initials.clone(),
        you: person.you,
    }
}

fn sprint_to(sprint: &Sprint) -> pb::Sprint {
    pb::Sprint {
        name: sprint.name.clone(),
        state: match sprint.state {
            SprintState::Unknown => pb::SprintState::Unspecified,
            SprintState::Closed => pb::SprintState::Closed,
            SprintState::Active => pb::SprintState::Active,
            SprintState::Future => pb::SprintState::Future,
        }
        .into(),
        start_unix_ms: unix_ms(sprint.start),
        end_unix_ms: unix_ms(sprint.end),
    }
}

fn task_ref_to(r: &TaskRef) -> pb::TaskRef {
    pb::TaskRef {
        id: r.id.as_ref().map(ToString::to_string).unwrap_or_default(),
        key: r.key.clone(),
        title: r.title.clone(),
        r#type: task_type_to(r.kind).into(),
        source_status: r.source_status.clone(),
        status: task_status_to(r.status).into(),
        assignee: r.assignee.as_ref().map(person_to),
        color: r.color.clone(),
        url: r.url.clone().unwrap_or_default(),
    }
}

fn link_kind_to(kind: LinkKind) -> pb::LinkKind {
    match kind {
        LinkKind::Other => pb::LinkKind::Other,
        LinkKind::Blocks => pb::LinkKind::Blocks,
        LinkKind::BlockedBy => pb::LinkKind::BlockedBy,
        LinkKind::Relates => pb::LinkKind::Relates,
        LinkKind::Duplicates => pb::LinkKind::Duplicates,
        LinkKind::DuplicatedBy => pb::LinkKind::DuplicatedBy,
    }
}

fn linked_to(link: &LinkedTask) -> pb::LinkedTask {
    pb::LinkedTask {
        kind: link_kind_to(link.kind).into(),
        relation: link.relation.clone(),
        task: Some(task_ref_to(&link.task)),
    }
}

fn attachment_to(a: &Attachment) -> pb::TaskAttachment {
    pb::TaskAttachment {
        name: a.name.clone(),
        kind: a.kind.clone(),
        size_bytes: a.size_bytes,
        url: a.url.clone().unwrap_or_default(),
    }
}

fn comment_to(c: &Comment) -> pb::TaskComment {
    pb::TaskComment {
        author: c.author.as_ref().map(person_to),
        created_unix_ms: unix_ms(c.created),
        body: c.body.clone(),
    }
}

fn time_tracking_to(t: &TimeTracking) -> pb::TimeTracking {
    pb::TimeTracking {
        estimate: t.estimate.clone(),
        logged: t.logged.clone(),
        remaining: t.remaining.clone(),
        estimate_seconds: t.estimate_seconds,
        logged_seconds: t.logged_seconds,
        remaining_seconds: t.remaining_seconds,
    }
}

pub fn task_detail_to(detail: &TaskDetail) -> pb::TaskDetail {
    pb::TaskDetail {
        task: Some(task_to(&detail.task)),
        reporter: detail.reporter.as_ref().map(person_to),
        created_unix_ms: unix_ms(detail.created),
        description: detail.description.clone(),
        acceptance_criteria: detail.acceptance_criteria.clone(),
        subtasks: detail.subtasks.iter().map(task_ref_to).collect(),
        links: detail.links.iter().map(linked_to).collect(),
        attachments: detail.attachments.iter().map(attachment_to).collect(),
        comments: detail.comments.iter().map(comment_to).collect(),
        components: detail.components.clone(),
        fix_versions: detail.fix_versions.clone(),
        time_tracking: detail.time_tracking.as_ref().map(time_tracking_to),
        fetched_unix_ms: unix_ms(Some(detail.fetched)),
        stale: detail.stale.is_some(),
        stale_reason: detail.stale.clone().unwrap_or_default(),
        location: detail.location.clone(),
    }
}

pub fn task_to(task: &Task) -> pb::Task {
    pb::Task {
        id: task.id.to_string(),
        source_id: task.id.source().to_string(),
        key: task.key.clone(),
        title: task.title.clone(),
        status: task_status_to(task.status).into(),
        priority: priority_to(task.priority).into(),
        due: task.due.clone().unwrap_or_default(),
        url: task.url.clone().unwrap_or_default(),
        context: task.context.clone(),
        labels: task.labels.clone(),
        updated_unix_ms: unix_ms(task.updated),
        suggested_branch: task.suggested_branch(),
        r#type: task_type_to(task.kind).into(),
        type_name: task.type_name.clone(),
        source_status: task.source_status.clone(),
        assignee: task.assignee.as_ref().map(person_to),
        relations: task
            .relations
            .iter()
            .map(|r| relation_to(*r).into())
            .collect(),
        mine: task.mine,
        points: task.points.map_or(0.0, |p| p.as_f64()),
        subtasks_done: task.subtasks.done,
        subtasks_total: task.subtasks.total,
        comment_count: task.comment_count,
        parent: task.parent.as_ref().map(task_ref_to),
        blocked: task.blocked,
        sprint: task.sprint.as_ref().map(sprint_to),
    }
}

pub fn task_link_to(link: &TaskLink) -> pb::TaskLink {
    pb::TaskLink {
        task_id: link.task.to_string(),
        worktree_path: link.worktree.display().to_string(),
        branch: link.branch.clone(),
        created_unix_ms: link.created.as_unix_nanos() / 1_000_000,
    }
}

pub fn detected_to(detected: Detected) -> pb::DetectedSource {
    pb::DetectedSource {
        kind: source_kind_to(detected.options.kind()).into(),
        name: detected.name,
        options: detected.options.to_map().into_iter().collect(),
    }
}

/// The board as an update for a client that has the task lists in `sent`
/// (source → version); records what this one carries.
pub fn tasks_update_to(board: &TaskBoard, sent: &mut HashMap<SourceId, u64>) -> pb::TasksUpdate {
    sent.retain(|id, _| board.source(id).is_some());
    let changed = board
        .sources
        .iter()
        .filter(|view| {
            sent.insert(view.source.id.clone(), view.tasks_version) != Some(view.tasks_version)
        })
        .map(|view| pb::SourceTasks {
            source_id: view.source.id.to_string(),
            version: view.tasks_version,
            tasks: view.tasks.iter().map(task_to).collect(),
        })
        .collect();
    pb::TasksUpdate {
        version: board.version,
        sources: board.sources.iter().map(source_to).collect(),
        changed,
        links: board.links.iter().map(task_link_to).collect(),
    }
}
