use std::collections::BTreeSet;
use std::fmt;

use super::{
    Person, Points, Progress, SourceId, Sprint, TaskError, TaskRef, TaskRelation, TaskType,
};
use crate::time::Timestamp;

/// Where a task stands, as Kumo's board shows it. Each source's own states
/// map onto these.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum TaskStatus {
    Todo,
    Doing,
    Review,
    Done,
}

impl fmt::Display for TaskStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(match self {
            TaskStatus::Todo => "to do",
            TaskStatus::Doing => "in progress",
            TaskStatus::Review => "in review",
            TaskStatus::Done => "done",
        })
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum Priority {
    #[default]
    None,
    Low,
    Medium,
    High,
    Urgent,
}

/// `<source id>/<id in the source>`: unique across sources.
#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct TaskId(String);

impl TaskId {
    pub fn new(source: &SourceId, external: &str) -> Self {
        Self(format!("{source}/{external}"))
    }

    pub fn parse(raw: &str) -> Result<Self, TaskError> {
        match raw.trim().split_once('/') {
            Some((source, external)) if !source.is_empty() && !external.is_empty() => {
                Ok(Self(raw.trim().to_owned()))
            }
            _ => Err(TaskError::UnknownTask(raw.to_owned())),
        }
    }

    pub fn source(&self) -> SourceId {
        let (source, _) = self.0.split_once('/').unwrap_or((&self.0, ""));
        SourceId::parse(source).unwrap_or_else(|_| unreachable!("checked on construction"))
    }

    /// The id the source itself knows the task by.
    pub fn external(&self) -> &str {
        self.0.split_once('/').map_or("", |(_, external)| external)
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for TaskId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// One task, whatever tool it lives in.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Task {
    pub id: TaskId,
    /// Short label shown on the card: an issue key (`PRC-412`, `#18`), a
    /// project or a note.
    pub key: String,
    /// The tracker's reference when it has one (`PRC-412`, `18`): goes in
    /// branch names.
    pub ticket: Option<String>,
    pub title: String,
    pub status: TaskStatus,
    pub priority: Priority,
    /// `YYYY-MM-DD`.
    pub due: Option<String>,
    /// Opens the task in its tool.
    pub url: Option<String>,
    /// Where it belongs: repository, project, folder.
    pub context: String,
    pub labels: Vec<String>,
    pub updated: Option<Timestamp>,

    pub kind: TaskType,
    /// The source's own name for the type ("Story", "Sub-task").
    pub type_name: String,
    /// The source's own status ("Code Review", "QA"); `status` is its column.
    pub source_status: String,
    pub assignee: Option<Person>,
    /// How the task relates to the user (assigned, later reported or
    /// watching too).
    pub relations: BTreeSet<TaskRelation>,
    /// The user's own: assigned to them, or from a personal source. What
    /// "Mine" shows.
    pub mine: bool,
    pub points: Option<Points>,
    pub subtasks: Progress,
    pub comment_count: u32,
    /// Epic, or parent of a sub-task.
    pub parent: Option<TaskRef>,
    /// An issue that blocks this one isn't done yet.
    pub blocked: bool,
    pub sprint: Option<Sprint>,
}

impl Task {
    /// A task with only its id and title; the rest empty.
    pub fn new(id: TaskId, title: impl Into<String>) -> Self {
        Self {
            id,
            key: String::new(),
            ticket: None,
            title: title.into(),
            status: TaskStatus::Todo,
            priority: Priority::None,
            due: None,
            url: None,
            context: String::new(),
            labels: vec![],
            updated: None,
            kind: TaskType::Unknown,
            type_name: String::new(),
            source_status: String::new(),
            assignee: None,
            relations: BTreeSet::new(),
            mine: false,
            points: None,
            subtasks: Progress::default(),
            comment_count: 0,
            parent: None,
            blocked: false,
            sprint: None,
        }
    }

    /// Marks a task of a personal source (notes, a to-do app): all of it is
    /// the user's.
    pub fn personal(mut self) -> Self {
        self.mine = true;
        self.kind = TaskType::Todo;
        self
    }

    /// Records who it's assigned to; `mine` when it's the user.
    pub fn assigned_to(mut self, assignee: Option<Person>) -> Self {
        let you = assignee.as_ref().is_some_and(|p| p.you);
        if you {
            self.relations.insert(TaskRelation::Assigned);
        } else {
            self.relations.remove(&TaskRelation::Assigned);
        }
        self.mine = you;
        self.assignee = assignee;
        self
    }

    /// Branch to work on it: `feat/PRC-412-bulk-discounts`.
    pub fn suggested_branch(&self) -> String {
        const MAX_WORDS: usize = 6;
        let words: Vec<String> = self
            .title
            .split(|c: char| !c.is_alphanumeric())
            .filter(|w| !w.is_empty())
            .take(MAX_WORDS)
            .map(|w| w.to_lowercase())
            .collect();
        let ticket = self
            .ticket
            .as_deref()
            .map(|t| t.trim_start_matches('#'))
            .filter(|t| !t.is_empty() && t.chars().all(|c| c.is_ascii_alphanumeric() || c == '-'));
        let slug = ticket
            .into_iter()
            .map(str::to_owned)
            .chain(words)
            .collect::<Vec<_>>()
            .join("-");
        let ascii: String = slug
            .chars()
            .map(|c| {
                if c.is_ascii_alphanumeric() || c == '-' {
                    c
                } else {
                    '-'
                }
            })
            .collect();
        let tidy = ascii
            .split('-')
            .filter(|p| !p.is_empty())
            .collect::<Vec<_>>()
            .join("-");
        if tidy.is_empty() {
            "feat/task".to_owned()
        } else {
            format!("feat/{tidy}")
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::workspace::BranchName;

    fn task(ticket: Option<&str>, title: &str) -> Task {
        Task {
            ticket: ticket.map(str::to_owned),
            ..Task::new(TaskId::parse("s/1").unwrap(), title)
        }
    }

    #[test]
    fn initials_and_points() {
        let initials = |name: &str| Person::new("x", name, false).initials;
        assert_eq!(initials("Ana Gómez"), "AG");
        assert_eq!(initials("Mauri"), "M");
        assert_eq!(initials("  lucía de la  torre "), "LT");
        assert_eq!(initials("octo-cat"), "O");
        assert_eq!(initials(""), "");
        assert_eq!(Points::from_f64(2.5).map(Points::as_f64), Some(2.5));
        assert_eq!(Points::from_f64(0.0), None);
        assert_eq!(Points::from_f64(f64::NAN), None);
    }

    #[test]
    fn assignment_decides_mine() {
        let id = TaskId::parse("s/1").unwrap();
        let mine = Task::new(id.clone(), "x").assigned_to(Some(Person::new("1", "Ana", true)));
        assert!(mine.mine);
        assert!(mine.relations.contains(&TaskRelation::Assigned));
        let theirs = mine.assigned_to(Some(Person::new("2", "Tomás", false)));
        assert!(!theirs.mine && theirs.relations.is_empty());
        let personal = Task::new(id, "x").personal();
        assert!(personal.mine && personal.kind == TaskType::Todo);
    }

    #[test]
    fn task_ids_split_into_source_and_external() {
        let id = TaskId::parse("abc/notes/today.md#1f").unwrap();
        assert_eq!(id.source().as_str(), "abc");
        assert_eq!(id.external(), "notes/today.md#1f");
        assert!(TaskId::parse("abc").is_err());
        assert!(TaskId::parse("/x").is_err());
    }

    #[test]
    fn suggests_valid_branches() {
        let cases = [
            (
                Some("PRC-412"),
                "Bulk discounts by category",
                "feat/PRC-412-bulk-discounts-by-category",
            ),
            (
                Some("#18"),
                "Fix: rounding (installments)",
                "feat/18-fix-rounding-installments",
            ),
            (
                None,
                "Revisar el copy del banner ✨",
                "feat/revisar-el-copy-del-banner",
            ),
            (None, "¿?", "feat/task"),
        ];
        for (ticket, title, expected) in cases {
            let branch = task(ticket, title).suggested_branch();
            assert_eq!(branch, expected);
            assert!(BranchName::parse(&branch).is_ok(), "{branch}");
        }
    }
}
