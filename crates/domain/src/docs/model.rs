use std::fmt;
use std::path::PathBuf;

use crate::tasks::{SourceId, SourceKind, TaskError};

/// Where docs come from.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum DocKind {
    Confluence,
    Obsidian,
}

impl DocKind {
    /// The kind of task source whose account or folder it reads.
    pub fn from_source(kind: SourceKind) -> Option<Self> {
        match kind {
            SourceKind::Jira => Some(DocKind::Confluence),
            SourceKind::Obsidian => Some(DocKind::Obsidian),
            _ => None,
        }
    }

    pub fn source_kind(self) -> SourceKind {
        match self {
            DocKind::Confluence => SourceKind::Jira,
            DocKind::Obsidian => SourceKind::Obsidian,
        }
    }

    pub fn name(self) -> &'static str {
        match self {
            DocKind::Confluence => "Confluence",
            DocKind::Obsidian => "Obsidian",
        }
    }
}

impl fmt::Display for DocKind {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.name())
    }
}

/// `<source>/<external>`: the task source it reads through, and the id the
/// knowledge base knows the page by (a Confluence page id, a note's path).
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct DocId(String);

impl DocId {
    pub fn new(source: &SourceId, external: &str) -> Self {
        Self(format!("{source}/{external}"))
    }

    pub fn parse(raw: &str) -> Result<Self, TaskError> {
        let raw = raw.trim();
        match raw.split_once('/') {
            Some((source, external)) if SourceId::parse(source).is_ok() && !external.is_empty() => {
                Ok(Self(raw.to_owned()))
            }
            _ => Err(TaskError::Invalid(format!("unknown doc: {raw}"))),
        }
    }

    pub fn source(&self) -> SourceId {
        let (source, _) = self.0.split_once('/').unwrap_or((&self.0, ""));
        SourceId::parse(source).unwrap_or_else(|_| unreachable!("checked on construction"))
    }

    /// The id the knowledge base knows the page by.
    pub fn external(&self) -> &str {
        self.0.split_once('/').map_or("", |(_, external)| external)
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for DocId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// A page in a list: enough to pick it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DocSummary {
    pub id: DocId,
    pub title: String,
    /// The Confluence space, or the note's folder in the vault.
    pub place: String,
    /// Unix ms; None when unknown.
    pub updated_at: Option<i64>,
    /// Who last edited it, when the source says.
    pub author: Option<String>,
    /// Where it opens: the page on the site, `obsidian://` for a note.
    pub url: String,
    /// The text around a search match; empty outside a search.
    pub excerpt: String,
}

/// An entry of one level of a knowledge base: a space, a folder or a page.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DocNode {
    /// Opaque to clients, sent back as the parent of the level below.
    /// Unique in its level.
    pub key: String,
    pub title: String,
    /// The page, when it can be read; None for a space or a folder.
    pub doc: Option<DocSummary>,
    /// Entries under it; 0 when there's nothing to go into. 1 stands for
    /// "has children" when counting would cost a request per node.
    pub children: u32,
    /// A short tag next to the title ("archived"); usually empty.
    pub note: String,
}

impl DocNode {
    /// Folders and spaces first, then pages, each by title
    /// (case-insensitive).
    pub fn sort(nodes: &mut [DocNode]) {
        nodes.sort_by_cached_key(|n| (n.doc.is_some(), n.title.to_lowercase(), n.key.clone()));
    }
}

/// A whole page, as Markdown.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Doc {
    pub summary: DocSummary,
    pub markdown: String,
    /// Titles above the page: the space, then its ancestors.
    pub path: Vec<String>,
    /// The note itself, for a vault (an agent can read it from there).
    pub file: Option<PathBuf>,
}
