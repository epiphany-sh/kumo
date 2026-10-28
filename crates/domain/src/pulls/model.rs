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
