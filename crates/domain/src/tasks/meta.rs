//! What a card says about a task beyond its title: type, people, sprint,
//! parent, progress.

use super::{TaskId, TaskStatus};
use crate::time::Timestamp;

/// The kind of ticket, as the board draws it.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum TaskType {
    /// The source didn't say.
    #[default]
    Unknown,
    Story,
    Bug,
    Task,
    Subtask,
    Epic,
    /// A GitHub issue.
    Issue,
    /// A note checkbox or a to-do (Obsidian, Bear, Todoist).
    Todo,
}

/// How a task relates to the user. Only `Assigned` is filled today; the
/// others leave room for "reported by me" and "watching".
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum TaskRelation {
    Assigned,
    Reported,
    Watching,
}

/// Someone in the source: an assignee, a reporter, a comment's author.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Person {
    /// The source's id (Jira accountId, GitHub login).
    pub id: String,
    pub name: String,
    /// "AG"; one letter for one-word names.
    pub initials: String,
    /// The signed-in user.
    pub you: bool,
}

impl Person {
    pub fn new(id: impl Into<String>, name: impl Into<String>, you: bool) -> Self {
        let name = name.into();
        Self {
            id: id.into(),
            initials: initials(&name),
            name,
            you,
        }
    }
}

/// First letters of the first and last words ("Ana Gómez" → "AG").
fn initials(name: &str) -> String {
    let words: Vec<&str> = name.split_whitespace().collect();
    let first = |word: &&str| word.chars().find(|c| c.is_alphanumeric());
    let letters: Vec<char> = match words.as_slice() {
        [] => vec![],
        [one] => first(one).into_iter().collect(),
        [head, .., last] => first(head).into_iter().chain(first(last)).collect(),
    };
    letters.into_iter().flat_map(char::to_uppercase).collect()
}

/// Story points, kept in hundredths so tasks stay comparable (`Eq`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct Points(u32);

impl Points {
    /// `None` for zero, negative or nonsense values: "no estimate".
    pub fn from_f64(points: f64) -> Option<Self> {
        let hundredths = (points * 100.0).round();
        (points.is_finite() && hundredths >= 1.0 && hundredths <= f64::from(u32::MAX))
            .then_some(Self(hundredths as u32))
    }

    pub fn as_f64(self) -> f64 {
        f64::from(self.0) / 100.0
    }

    /// As stored: hundredths of a point.
    pub const fn from_hundredths(hundredths: u32) -> Self {
        Self(hundredths)
    }

    pub const fn hundredths(self) -> u32 {
        self.0
    }
}

/// Sub-tasks done out of all of them.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash)]
pub struct Progress {
    pub done: u32,
    pub total: u32,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash)]
pub enum SprintState {
    #[default]
    Unknown,
    Closed,
    Active,
    Future,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Sprint {
    pub name: String,
    pub state: SprintState,
    pub start: Option<Timestamp>,
    pub end: Option<Timestamp>,
}

/// Another ticket, as a card or a detail mentions it (parent, sub-task,
/// linked issue).
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct TaskRef {
    /// Kumo's id, when the ticket can be opened through its source.
    pub id: Option<TaskId>,
    pub key: String,
    pub title: String,
    pub kind: TaskType,
    pub source_status: String,
    pub status: TaskStatus,
    pub assignee: Option<Person>,
    /// Epics: a palette name ("violet", "teal"…); empty = by key.
    pub color: String,
    pub url: Option<String>,
}

impl TaskRef {
    pub fn new(key: impl Into<String>, title: impl Into<String>) -> Self {
        Self {
            id: None,
            key: key.into(),
            title: title.into(),
            kind: TaskType::Unknown,
            source_status: String::new(),
            status: TaskStatus::Todo,
            assignee: None,
            color: String::new(),
            url: None,
        }
    }
}
