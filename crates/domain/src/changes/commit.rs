/// A commit in the history.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommitInfo {
    pub sha: String,
    pub short_sha: String,
    pub subject: String,
    pub author: String,
    pub time_unix: u64,
}

/// How to commit.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommitOptions {
    pub message: String,
    /// Stage every change first.
    pub all: bool,
    pub amend: bool,
}
