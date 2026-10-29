//! Task sources: one connector per kind of tool.
//!
//! - [`ObsidianConnector`]: checkboxes in a vault's notes.
//! - [`BearConnector`]: checkboxes in Bear's notes (read only).
//! - [`GitHubConnector`]: issues, through the user's `gh`.
//! - [`JiraConnector`]: Jira Cloud's REST API.
//! - [`TodoistConnector`]: Todoist's API.

pub(crate) mod adf;
mod bear;
pub(crate) mod dates;
mod github;
pub(crate) mod http;
mod jira;
pub(crate) mod obsidian;
mod todoist;

pub use bear::BearConnector;
pub use github::GitHubConnector;
pub use jira::JiraConnector;
pub use obsidian::ObsidianConnector;
pub use todoist::TodoistConnector;
