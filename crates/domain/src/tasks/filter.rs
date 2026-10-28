use std::collections::HashSet;

use super::{SourceId, Task, TaskStatus};

/// What the board shows: free text over key, title, context and labels,
/// narrowed by source and status.
#[derive(Debug, Clone, Default)]
pub struct TaskFilter {
    /// Lowercase words; every one must match.
    words: Vec<String>,
    sources: HashSet<SourceId>,
    statuses: HashSet<TaskStatus>,
}

impl TaskFilter {
    pub fn new(text: &str) -> Self {
        Self {
            words: text.split_whitespace().map(str::to_lowercase).collect(),
            ..Self::default()
        }
    }

    pub fn in_sources(mut self, sources: impl IntoIterator<Item = SourceId>) -> Self {
        self.sources.extend(sources);
        self
    }

    pub fn with_status(mut self, statuses: impl IntoIterator<Item = TaskStatus>) -> Self {
        self.statuses.extend(statuses);
        self
    }

    pub fn matches(&self, task: &Task) -> bool {
        if !self.sources.is_empty() && !self.sources.contains(&task.id.source()) {
            return false;
        }
        if !self.statuses.is_empty() && !self.statuses.contains(&task.status) {
            return false;
        }
        self.words.iter().all(|word| {
            [&task.key, &task.title, &task.context]
                .into_iter()
                .chain(&task.labels)
                .any(|field| contains_ignore_case(field, word))
        })
    }

    pub fn apply<'a>(&'a self, tasks: &'a [Task]) -> impl Iterator<Item = &'a Task> + 'a {
        tasks.iter().filter(|t| self.matches(t))
    }
}

/// `needle` is already lowercase. Avoids allocating for ASCII haystacks.
fn contains_ignore_case(haystack: &str, needle: &str) -> bool {
    if haystack.is_ascii() && needle.is_ascii() {
        let (h, n) = (haystack.as_bytes(), needle.as_bytes());
        n.is_empty() || h.windows(n.len()).any(|w| w.eq_ignore_ascii_case(n))
    } else {
        haystack.to_lowercase().contains(needle)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tasks::TaskId;

    fn task(id: &str, title: &str, status: TaskStatus, labels: &[&str]) -> Task {
        Task {
            key: "PRC-1".into(),
            status,
            context: "pricing".into(),
            labels: labels.iter().map(|l| (*l).to_owned()).collect(),
            ..Task::new(TaskId::parse(id).unwrap(), title)
        }
    }

    #[test]
    fn every_word_must_match_some_field() {
        let tasks = [
            task("a/1", "Bulk Discounts", TaskStatus::Todo, &["backend"]),
            task("a/2", "Rounding error", TaskStatus::Done, &[]),
            task(
                "b/3",
                "Descuentos en cuotas",
                TaskStatus::Todo,
                &["Atención"],
            ),
        ];
        let ids = |f: &TaskFilter| {
            f.apply(&tasks)
                .map(|t| t.id.to_string())
                .collect::<Vec<_>>()
        };
        assert_eq!(ids(&TaskFilter::new("discounts BACKEND")), ["a/1"]);
        assert_eq!(ids(&TaskFilter::new("pricing")).len(), 3);
        assert_eq!(ids(&TaskFilter::new("atención")), ["b/3"]);
        assert_eq!(
            ids(&TaskFilter::new("").with_status([TaskStatus::Done])),
            ["a/2"]
        );
        let only_b = TaskFilter::new("").in_sources([SourceId::parse("b").unwrap()]);
        assert_eq!(ids(&only_b), ["b/3"]);
    }
}
