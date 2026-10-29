//! Docs: pages of the knowledge bases the user already connected for
//! tasks, read only. Confluence signs in with the Atlassian account of a
//! Jira source; Obsidian reads a vault source's notes.

mod model;
mod ports;

pub use model::{Doc, DocId, DocKind, DocSummary};
pub use ports::DocsConnector;
