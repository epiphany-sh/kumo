use std::fmt;

use super::{SourceId, TaskError};
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
}

impl Task {
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
            id: TaskId::parse("s/1").unwrap(),
            key: String::new(),
            ticket: ticket.map(str::to_owned),
            title: title.to_owned(),
            status: TaskStatus::Todo,
            priority: Priority::None,
            due: None,
            url: None,
            context: String::new(),
            labels: vec![],
            updated: None,
        }
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
