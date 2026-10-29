//! Docs connectors, reading through task sources' accounts and folders.
//!
//! - [`ConfluenceDocs`]: Confluence Cloud, with a Jira source's account.
//! - [`VaultDocs`]: an Obsidian vault source's notes.

mod confluence;
mod vault;

pub use confluence::ConfluenceDocs;
pub use vault::VaultDocs;
