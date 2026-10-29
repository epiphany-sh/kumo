//! CI providers: one [`CiClient`](kumo_domain::pipelines::CiClient) per
//! kind of host, plus where tokens come from when none is saved.
//!
//! - [`GitHubActions`]: GitHub.com and GitHub Enterprise Server.
//! - [`GitLabCi`]: GitLab.com and self-managed GitLab.
//! - [`BitbucketPipelines`]: Bitbucket Cloud.
//! - [`GitHubPulls`], [`GitLabPulls`], [`BitbucketPulls`]: pull (merge)
//!   requests, with the same tokens.
//! - [`GhTokenFallback`]: the token of the user's `gh` sign-in.

mod bitbucket;
mod bitbucket_pulls;
mod gh;
mod github;
mod github_pulls;
mod gitlab;
mod gitlab_pulls;
pub(crate) mod http;

pub use bitbucket::BitbucketPipelines;
pub use bitbucket_pulls::BitbucketPulls;
pub use gh::GhTokenFallback;
pub use github::GitHubActions;
pub use github_pulls::GitHubPulls;
pub use gitlab::GitLabCi;
pub use gitlab_pulls::GitLabPulls;

use kumo_domain::time::Timestamp;
use serde_json::Value;

use crate::tasks::dates::parse_timestamp;

/// An RFC 3339 timestamp field.
fn ts(value: &Value) -> Option<Timestamp> {
    value.as_str().and_then(parse_timestamp)
}

/// Milliseconds from `start` to `end`, when both are known.
fn ms_between(start: Option<Timestamp>, end: Option<Timestamp>) -> Option<u64> {
    let (start, end) = (start?, end?);
    u64::try_from(end.since(start).as_millis()).ok()
}

/// A number or string id as a string.
fn id(value: &Value) -> String {
    match value {
        Value::Number(n) => n.to_string(),
        Value::String(s) => s.clone(),
        _ => String::new(),
    }
}

/// First non-empty line, trimmed and cut to 160 characters.
fn first_line(text: &str) -> Option<String> {
    let line = text.lines().map(str::trim).find(|l| !l.is_empty())?;
    Some(line.chars().take(160).collect())
}
