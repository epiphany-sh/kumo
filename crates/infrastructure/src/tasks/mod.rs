//! Task sources: one connector per kind of tool.
//!
//! - [`ObsidianConnector`]: checkboxes in a vault's notes.
//! - [`BearConnector`]: checkboxes in Bear's notes (read only).
//! - [`GitHubConnector`]: issues, through the user's `gh`.
//! - [`JiraConnector`]: Jira Cloud's REST API.
//! - [`TodoistConnector`]: Todoist's API.

mod bear;
mod dates;
mod github;
mod http;
mod jira;
mod obsidian;
#[cfg(test)]
mod test_server;
mod todoist;

pub use bear::BearConnector;
pub use github::GitHubConnector;
pub use jira::JiraConnector;
pub use obsidian::ObsidianConnector;
pub use todoist::TodoistConnector;
