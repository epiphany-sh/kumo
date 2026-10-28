use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, PoisonError};
use std::time::{Duration, Instant};

use kumo_domain::pipelines::{
    BranchReader, CiHost, CiProblem, CiProblemKind, CiProvider, CiTarget, HostTokens,
    PipelinesError, TokenFallback,
};
use kumo_domain::pulls::{NewPullRequest, PullRequest, PullRequestClient};
use kumo_domain::workspace::{Repo, WorkspaceSnapshot};
use tokio::sync::watch;

pub struct PullRequestPorts {
    pub clients: Vec<Arc<dyn PullRequestClient>>,
    pub tokens: Arc<dyn HostTokens>,
    pub fallback: Arc<dyn TokenFallback>,
    pub branches: Arc<dyn BranchReader>,
}

impl std::fmt::Debug for PullRequestPorts {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("PullRequestPorts")
            .field("clients", &self.clients.len())
            .finish_non_exhaustive()
    }
}

/// A repository's open pull requests, or why they can't be read.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct PullRequestList {
    pub provider: Option<CiProvider>,
    pub pull_requests: Vec<PullRequest>,
    pub problem: Option<CiProblem>,
}

/// A worktree branch's pull request (None: it never had one).
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct BranchPullRequest {
    pub provider: Option<CiProvider>,
    pub pull_request: Option<PullRequest>,
    pub problem: Option<CiProblem>,
}

/// How many open pull requests a list brings.
const LIMIT: usize = 30;

pub struct PullRequestService {
    ports: PullRequestPorts,
    workspace: watch::Receiver<Arc<WorkspaceSnapshot>>,
    /// How long an answer is reused.
    fresh: Duration,
    lists: Mutex<HashMap<PathBuf, (Instant, PullRequestList)>>,
    branches: Mutex<HashMap<PathBuf, (Instant, BranchPullRequest)>>,
}

impl std::fmt::Debug for PullRequestService {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("PullRequestService").finish_non_exhaustive()
    }
}

impl PullRequestService {
    pub fn new(
        ports: PullRequestPorts,
        workspace: watch::Receiver<Arc<WorkspaceSnapshot>>,
        fresh: Duration,
    ) -> Self {
        Self {
            ports,
            workspace,
            fresh,
            lists: Mutex::new(HashMap::new()),
            branches: Mutex::new(HashMap::new()),
        }
    }

    /// Open pull requests of the repository at `repo_path` (its main checkout).
    pub async fn list(
        &self,
        repo_path: &Path,
        refresh: bool,
    ) -> Result<PullRequestList, PipelinesError> {
        let repo = self
            .repo(repo_path)
            .ok_or_else(|| PipelinesError::UnknownWorktree(repo_path.display().to_string()))?;
        if !refresh && let Some(hit) = fresh(&self.lists, &repo.path, self.fresh) {
            return Ok(hit);
        }
        let answer = match self.target(&repo, String::new()).await {
            Err(problem) => PullRequestList {
                provider: problem.0,
                problem: Some(problem.1),
                ..Default::default()
            },
            Ok((client, target, token)) => {
                let provider = Some(target.host.provider);
                match blocking(move || client.list(&target, &token, LIMIT)).await? {
                    Ok(pull_requests) => PullRequestList {
                        provider,
                        pull_requests,
                        problem: None,
                    },
                    Err(problem) => PullRequestList {
                        provider,
                        pull_requests: Vec::new(),
                        problem: Some(problem),
                    },
                }
            }
        };
        remember(&self.lists, repo.path.clone(), answer.clone());
        Ok(answer)
    }

    /// The pull request of `worktree`'s branch.
    pub async fn for_branch(
        &self,
        worktree: &Path,
        refresh: bool,
    ) -> Result<BranchPullRequest, PipelinesError> {
        let (repo, path) = self.worktree(worktree)?;
        if !refresh && let Some(hit) = fresh(&self.branches, &path, self.fresh) {
            return Ok(hit);
        }
        let answer = match self.branch_target(&repo, &path).await {
            Err(problem) => BranchPullRequest {
                provider: problem.0,
                problem: Some(problem.1),
                ..Default::default()
            },
            Ok((client, target, token)) => {
                let provider = Some(target.host.provider);
                match blocking(move || client.for_branch(&target, &token)).await? {
                    Ok(pull_request) => BranchPullRequest {
                        provider,
                        pull_request,
                        problem: None,
                    },
                    Err(problem) => BranchPullRequest {
                        provider,
                        pull_request: None,
                        problem: Some(problem),
                    },
                }
            }
        };
        remember(&self.branches, path, answer.clone());
        Ok(answer)
    }

    /// Opens a pull request from `worktree`'s branch (it must be pushed).
    pub async fn create(
        &self,
        worktree: &Path,
        title: &str,
        body: &str,
        base: &str,
        draft: bool,
    ) -> Result<PullRequest, PipelinesError> {
        if title.trim().is_empty() {
            return Err(PipelinesError::Invalid(
                "A pull request needs a title".into(),
            ));
        }
        let (repo, path) = self.worktree(worktree)?;
        let (client, target, token) = self
            .branch_target(&repo, &path)
            .await
            .map_err(|p| PipelinesError::Ci(p.1))?;
        let new = NewPullRequest {
            title: title.trim().to_owned(),
            body: body.to_owned(),
            branch: target.branch.clone(),
            base: base.trim().to_owned(),
            draft,
        };
        let created = blocking(move || client.create(&target, &token, &new))
            .await?
            .map_err(PipelinesError::Ci)?;
        lock(&self.lists).remove(&repo.path);
        lock(&self.branches).remove(&path);
        Ok(created)
    }

    fn repos(&self) -> Vec<(Repo, Vec<PathBuf>)> {
        self.workspace
            .borrow()
            .repos
            .iter()
            .map(|r| {
                (
                    r.repo.clone(),
                    r.worktrees.iter().map(|w| w.path.clone()).collect(),
                )
            })
            .collect()
    }

    fn repo(&self, path: &Path) -> Option<Repo> {
        let canonical = std::fs::canonicalize(path).ok();
        self.repos().into_iter().map(|(r, _)| r).find(|r| {
            r.path == path
                || canonical
                    .as_ref()
                    .is_some_and(|c| std::fs::canonicalize(&r.path).is_ok_and(|p| &p == c))
        })
    }

    fn worktree(&self, path: &Path) -> Result<(Repo, PathBuf), PipelinesError> {
        let canonical = std::fs::canonicalize(path).ok();
        self.repos()
            .into_iter()
            .find_map(|(repo, worktrees)| {
                worktrees
                    .into_iter()
                    .find(|w| {
                        w == path
                            || canonical
                                .as_ref()
                                .is_some_and(|c| std::fs::canonicalize(w).is_ok_and(|p| &p == c))
                    })
                    .map(|w| (repo, w))
            })
            .ok_or_else(|| PipelinesError::UnknownWorktree(path.display().to_string()))
    }

    /// Client, target and token for `repo`; on failure, the provider (if any)
    /// and the problem to show.
    async fn target(
        &self,
        repo: &Repo,
        branch: String,
    ) -> Result<(Arc<dyn PullRequestClient>, CiTarget, String), (Option<CiProvider>, CiProblem)>
    {
        let problem = |p: Option<CiProvider>, kind| (p, CiProblem::of(kind));
        let remote = repo
            .remote
            .as_ref()
            .ok_or_else(|| problem(None, CiProblemKind::Unsupported))?;
        let host =
            CiHost::for_remote(remote).ok_or_else(|| problem(None, CiProblemKind::Unsupported))?;
        let provider = Some(host.provider);
        let client = self
            .ports
            .clients
            .iter()
            .find(|c| c.provider() == host.provider)
            .cloned()
            .ok_or_else(|| problem(provider, CiProblemKind::Unsupported))?;
        let token = self
            .token(&host)
            .await
            .ok_or_else(|| problem(provider, CiProblemKind::NotConnected))?;
        let target = CiTarget {
            repo: remote.full_name.clone().unwrap_or_default(),
            branch,
            host,
        };
        Ok((client, target, token))
    }

    /// The target of a worktree's branch on the remote: not pushed yet is
    /// a problem of its own.
    async fn branch_target(
        &self,
        repo: &Repo,
        worktree: &Path,
    ) -> Result<(Arc<dyn PullRequestClient>, CiTarget, String), (Option<CiProvider>, CiProblem)>
    {
        let provider = repo
            .remote
            .as_ref()
            .and_then(CiHost::for_remote)
            .map(|h| h.provider);
        let (branches, path) = (Arc::clone(&self.ports.branches), worktree.to_owned());
        let local = tokio::task::spawn_blocking(move || branches.read(&path))
            .await
            .ok()
            .and_then(Result::ok)
            .unwrap_or_default();
        let Some(branch) = local.upstream.as_ref().and(local.remote_name()) else {
            let mut problem = CiProblem::of(CiProblemKind::NotPushed);
            problem.commits_waiting = local.unpushed;
            return Err((provider, problem));
        };
        self.target(repo, branch.to_owned()).await
    }

    /// The saved token, else the fallback's (gh). Never logged.
    async fn token(&self, host: &CiHost) -> Option<String> {
        let (tokens, fallback, h) = (
            Arc::clone(&self.ports.tokens),
            Arc::clone(&self.ports.fallback),
            host.clone(),
        );
        tokio::task::spawn_blocking(move || match tokens.get(&h.host) {
            Ok(Some(token)) => Some(token),
            _ => fallback.token(&h),
        })
        .await
        .ok()
        .flatten()
    }
}

fn lock<T>(m: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    m.lock().unwrap_or_else(PoisonError::into_inner)
}

fn fresh<T: Clone>(
    cache: &Mutex<HashMap<PathBuf, (Instant, T)>>,
    key: &Path,
    max: Duration,
) -> Option<T> {
    lock(cache)
        .get(key)
        .filter(|(at, _)| at.elapsed() < max)
        .map(|(_, v)| v.clone())
}

fn remember<T>(cache: &Mutex<HashMap<PathBuf, (Instant, T)>>, key: PathBuf, value: T) {
    lock(cache).insert(key, (Instant::now(), value));
}

async fn blocking<T: Send + 'static>(
    f: impl FnOnce() -> T + Send + 'static,
) -> Result<T, PipelinesError> {
    tokio::task::spawn_blocking(f)
        .await
        .map_err(|e| PipelinesError::Invalid(format!("blocking task failed: {e}")))
}
