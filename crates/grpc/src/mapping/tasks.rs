use std::collections::{BTreeMap, HashMap};

use kumo_application::tasks::{SourceView, TaskBoard};
use kumo_domain::tasks::{
    Detected, Priority, SourceId, SourceKind, SourceOptions, Task, TaskLink, TaskStatus,
};
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
        updated_unix_ms: task.updated.map_or(0, |t| t.as_unix_nanos() / 1_000_000),
        suggested_branch: task.suggested_branch(),
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
