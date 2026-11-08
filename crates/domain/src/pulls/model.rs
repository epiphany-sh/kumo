use crate::pipelines::CiState;
use crate::tasks::Person;
use crate::time::Timestamp;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum PrState {
    Open,
    Merged,
    Closed,
}

/// Where the review stands, as the host decides it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ReviewState {
    /// No review asked for or given.
    None,
    /// Reviewers were asked; nobody approved yet.
    Required,
    ChangesRequested,
    Approved,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PullRequest {
    pub number: u64,
    /// `#521` (GitHub, Bitbucket), `!231` (GitLab).
    pub label: String,
    pub title: String,
    pub author: Person,
    pub branch: String,
    pub base: String,
    pub draft: bool,
    pub state: PrState,
    pub review: ReviewState,
    pub review_requested_from_you: bool,
    pub reviewers: Vec<Person>,
    /// Checks on the latest commit; 0 of 0 when none ran.
    pub checks_passed: u32,
    pub checks_total: u32,
    pub checks_state: Option<CiState>,
    pub url: String,
    pub created_at: Option<Timestamp>,
    pub updated_at: Option<Timestamp>,
    pub comment_count: u32,
    /// Unresolved review threads; None when the host's list doesn't say.
    pub open_threads: Option<u32>,
}

/// A review thread (GitLab: a resolvable discussion; Bitbucket: a
/// top-level inline comment) on a pull request.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReviewThread {
    /// The host's id for it, what answering it needs.
    pub id: String,
    /// Who wrote its first comment.
    pub author: String,
    pub path: String,
    /// None: not on a line (a file or outdated comment).
    pub line: Option<u32>,
    /// Its first comment.
    pub body: String,
    pub created_at: Option<Timestamp>,
    pub resolved: bool,
}

/// What to do with a review thread: reply (when not empty), then resolve.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ThreadAnswer {
    pub thread_id: String,
    pub reply: String,
    pub resolve: bool,
}

/// What opening a pull request needs.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NewPullRequest {
    pub title: String,
    pub body: String,
    pub branch: String,
    /// Empty: the repository's default branch.
    pub base: String,
    pub draft: bool,
}
