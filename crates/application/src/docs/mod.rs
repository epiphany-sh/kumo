//! Docs use cases: list, search and read pages of the knowledge bases
//! behind the task sources (Confluence through Jira's account, Obsidian
//! vaults). Nothing to configure apart from those sources.

mod service;

pub use service::{DocGroup, DocSource, DocsPorts, DocsService};

#[cfg(test)]
mod tests;
