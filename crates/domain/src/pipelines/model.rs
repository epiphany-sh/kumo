use std::fmt;

use crate::time::Timestamp;

/// CI products Kumo reads pipelines from, one per kind of host.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum CiProvider {
    GitHubActions,
    GitLabCi,
    BitbucketPipelines,
}

impl CiProvider {
    /// The forge, for messages.
    pub fn host_name(self) -> &'static str {
        match self {
            Self::GitHubActions => "GitHub",
            Self::GitLabCi => "GitLab",
            Self::BitbucketPipelines => "Bitbucket",
        }
    }
}

impl fmt::Display for CiProvider {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(match self {
            Self::GitHubActions => "GitHub Actions",
            Self::GitLabCi => "GitLab CI",
            Self::BitbucketPipelines => "Bitbucket Pipelines",
        })
    }
}

/// State of a run or of one of its jobs.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum CiState {
    Queued,
    Running,
    Passed,
    Failed,
    Canceled,
    Skipped,
}

impl CiState {
    pub fn active(self) -> bool {
        matches!(self, Self::Queued | Self::Running)
    }
}

/// One job (GitHub, GitLab) or step (Bitbucket) of a run.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CiJob {
    pub id: String,
    pub name: String,
    pub state: CiState,
    pub duration_ms: Option<u64>,
    pub started_at: Option<Timestamp>,
    /// First useful line of the error (failed jobs, best effort).
    pub failure: Option<String>,
    pub url: String,
}

/// A pipeline run of the branch.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CiRun {
    pub id: String,
    /// `run #8812`, `pipeline #4417`.
    pub label: String,
    /// Full commit hash (Bitbucket re-runs need it).
    pub sha: String,
    /// Subject of the commit.
    pub title: String,
    pub state: CiState,
    pub created_at: Option<Timestamp>,
    pub finished_at: Option<Timestamp>,
    pub url: String,
    pub jobs: Vec<CiJob>,
}

impl CiRun {
    pub fn short_sha(&self) -> &str {
        self.sha.get(..7).unwrap_or(&self.sha)
    }

    /// Queued or running, or with a job that still is.
    pub fn active(&self) -> bool {
        self.state.active() || self.jobs.iter().any(|j| j.state.active())
    }
}

/// Why pipelines can't be shown, by what the user can do about it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum CiProblemKind {
    /// No token for the host.
    NotConnected,
    /// 401.
    Unauthorized,
    /// 403: the token lacks a permission.
    Forbidden,
    /// 404.
    NotFound,
    /// 429, or 403 with no requests left.
    RateLimited,
    /// Timeouts, DNS, 5xx.
    Unreachable,
    /// The branch has no upstream.
    NotPushed,
    /// No supported CI on the repository's host.
    Unsupported,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CiProblem {
    pub kind: CiProblemKind,
    /// The provider's answer, at most [`CiProblem::MAX_DETAIL`] characters.
    pub detail: String,
    pub missing_scope: String,
    pub retry_at: Option<Timestamp>,
    pub commits_waiting: u32,
}

impl CiProblem {
    pub const MAX_DETAIL: usize = 120;

    pub fn new(kind: CiProblemKind, detail: impl Into<String>) -> Self {
        Self {
            kind,
            detail: shorten(&detail.into(), Self::MAX_DETAIL),
            missing_scope: String::new(),
            retry_at: None,
            commits_waiting: 0,
        }
    }

    pub fn of(kind: CiProblemKind) -> Self {
        Self::new(kind, "")
    }

    /// Problems that leave the last run on screen, marked stale.
    pub fn keeps_last_run(&self) -> bool {
        matches!(
            self.kind,
            CiProblemKind::RateLimited | CiProblemKind::Unreachable
        )
    }
}

impl fmt::Display for CiProblem {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let what = match self.kind {
            CiProblemKind::NotConnected => "no token for this host",
            CiProblemKind::Unauthorized => "the token was rejected",
            CiProblemKind::Forbidden => "the token isn't allowed to do that",
            CiProblemKind::NotFound => "not found",
            CiProblemKind::RateLimited => "rate limited",
            CiProblemKind::Unreachable => "the host isn't answering",
            CiProblemKind::NotPushed => "the branch isn't pushed",
            CiProblemKind::Unsupported => "no supported CI on this host",
        };
        match (self.detail.is_empty(), self.missing_scope.is_empty()) {
            (true, true) => f.write_str(what),
            (false, true) => write!(f, "{what} ({})", self.detail),
            (true, false) => write!(f, "{what}: needs {}", self.missing_scope),
            (false, false) => write!(f, "{what} ({}): needs {}", self.detail, self.missing_scope),
        }
    }
}

/// `text` cut to `max` characters, with an ellipsis.
fn shorten(text: &str, max: usize) -> String {
    let text = text.trim();
    if text.chars().count() <= max {
        return text.to_owned();
    }
    let mut cut: String = text.chars().take(max - 1).collect();
    cut.truncate(cut.trim_end().len());
    cut.push('…');
    cut
}

/// What the pipelines of one worktree look like now.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct PipelinesSnapshot {
    pub provider: Option<CiProvider>,
    pub repo: String,
    pub branch: String,
    pub latest: Option<CiRun>,
    pub problem: Option<CiProblem>,
    /// When the provider last answered.
    pub checked_at: Option<Timestamp>,
}

/// A host of the workspace's repositories, for Settings.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HostInfo {
    pub host: String,
    pub provider: CiProvider,
    pub has_token: bool,
    /// No saved token, but a fallback (the gh CLI) has one.
    pub uses_fallback: bool,
    /// Who the fallback signs in as.
    pub fallback_account: Option<String>,
    /// The fallback's CLI is installed and can sign in to this host.
    pub fallback_available: bool,
    pub repos: Vec<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn details_are_cut_to_120_characters() {
        let long = "x".repeat(300);
        let p = CiProblem::new(CiProblemKind::Unreachable, long);
        assert_eq!(p.detail.chars().count(), CiProblem::MAX_DETAIL);
        assert!(p.detail.ends_with('…'));
        assert_eq!(
            CiProblem::new(CiProblemKind::Unauthorized, " HTTP 401 · Bad credentials ").detail,
            "HTTP 401 · Bad credentials"
        );
    }

    #[test]
    fn a_run_is_active_while_a_job_still_runs() {
        let job = |state| CiJob {
            id: "1".into(),
            name: "build".into(),
            state,
            duration_ms: None,
            started_at: None,
            failure: None,
            url: String::new(),
        };
        let mut run = CiRun {
            id: "1".into(),
            label: "run #1".into(),
            sha: "4e1b2c0aa".into(),
            title: String::new(),
            state: CiState::Failed,
            created_at: None,
            finished_at: None,
            url: String::new(),
            jobs: vec![job(CiState::Failed)],
        };
        assert!(!run.active());
        assert_eq!(run.short_sha(), "4e1b2c0");
        run.jobs.push(job(CiState::Running));
        assert!(run.active());
    }
}
