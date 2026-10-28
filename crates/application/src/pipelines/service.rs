use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, PoisonError};
use std::time::Duration;

use kumo_domain::pipelines::{
    BranchReader, CiClient, CiHost, CiProblem, CiProblemKind, CiRun, CiTarget, HostInfo,
    HostTokens, LocalBranch, PipelinesError, PipelinesSnapshot, TokenFallback,
};
use kumo_domain::terminal::{LaunchSpec, TerminalId};
use kumo_domain::time::Timestamp;
use kumo_domain::workspace::{Repo, WorkspaceSnapshot};
use tokio::sync::{Notify, watch};

use crate::terminal::TerminalService;

pub struct PipelinesPorts {
    pub clients: Vec<Arc<dyn CiClient>>,
    pub tokens: Arc<dyn HostTokens>,
    pub fallback: Arc<dyn TokenFallback>,
    pub branches: Arc<dyn BranchReader>,
    /// Where a CLI's sign-in runs (a terminal the user sees).
    pub terminals: Arc<dyn TerminalLauncher>,
}

/// Opens a terminal running `spec`.
pub trait TerminalLauncher: Send + Sync + 'static {
    fn launch(&self, spec: LaunchSpec) -> Result<TerminalId, String>;
}

impl TerminalLauncher for TerminalService {
    fn launch(&self, spec: LaunchSpec) -> Result<TerminalId, String> {
        self.open(spec).map_err(|e| e.to_string())
    }
}

impl std::fmt::Debug for PipelinesPorts {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("PipelinesPorts")
            .field("clients", &self.clients.len())
            .finish_non_exhaustive()
    }
}

/// How often providers are asked.
#[derive(Debug, Clone, Copy)]
pub struct PipelinesTiming {
    /// While a run is queued or running.
    pub active: Duration,
    /// Once it finished, and while the user has something to fix.
    pub idle: Duration,
    /// First retry after the host didn't answer; doubles up to `max_retry`.
    pub retry: Duration,
    pub max_retry: Duration,
    /// How long Refresh waits for the new answer.
    pub refresh_timeout: Duration,
    /// While a CLI sign-in runs: how often, and for how long, to look for it.
    pub sign_in_check: Duration,
    pub sign_in_wait: Duration,
}

impl Default for PipelinesTiming {
    fn default() -> Self {
        Self {
            active: Duration::from_secs(10),
            idle: Duration::from_secs(60),
            retry: Duration::from_secs(15),
            max_retry: Duration::from_secs(300),
            refresh_timeout: Duration::from_secs(30),
            sign_in_check: Duration::from_secs(3),
            sign_in_wait: Duration::from_secs(600),
        }
    }
}

/// What a watcher receives: None until the first answer.
type Latest = Option<Arc<PipelinesSnapshot>>;

pub struct PipelinesService {
    inner: Arc<Inner>,
}

impl std::fmt::Debug for PipelinesService {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("PipelinesService").finish_non_exhaustive()
    }
}

struct Inner {
    ports: PipelinesPorts,
    timing: PipelinesTiming,
    workspace: watch::Receiver<Arc<WorkspaceSnapshot>>,
    pollers: Mutex<HashMap<PathBuf, Arc<Poller>>>,
}

/// Polls one worktree's pipelines while someone watches them.
struct Poller {
    worktree: PathBuf,
    tx: watch::Sender<Latest>,
    wake: Notify,
    state: tokio::sync::Mutex<PollState>,
}

#[derive(Default)]
struct PollState {
    /// Shown, marked stale, while the host is rate limiting or unreachable.
    last_run: Option<CiRun>,
    checked_at: Option<Timestamp>,
    /// Consecutive unreachable answers, for the backoff.
    failures: u32,
    host: Option<String>,
}

impl PipelinesService {
    pub fn new(
        ports: PipelinesPorts,
        timing: PipelinesTiming,
        workspace: watch::Receiver<Arc<WorkspaceSnapshot>>,
    ) -> Self {
        Self {
            inner: Arc::new(Inner {
                ports,
                timing,
                workspace,
                pollers: Mutex::new(HashMap::new()),
            }),
        }
    }

    /// How many worktrees are being polled.
    #[cfg(test)]
    pub(super) fn polling(&self) -> usize {
        self.inner.lock().len()
    }

    /// The pipelines of `worktree`, pushed on every answer.
    pub fn watch(&self, worktree: &Path) -> Result<watch::Receiver<Latest>, PipelinesError> {
        let worktree = self.inner.worktree(worktree)?;
        Ok(self.inner.subscribe(&worktree))
    }

    /// Asks the provider now; returns once the answer was pushed.
    pub async fn refresh(&self, worktree: &Path) -> Result<(), PipelinesError> {
        let worktree = self.inner.worktree(worktree)?;
        // Watching keeps a poller alive for as long as this waits.
        let mut rx = self.inner.subscribe(&worktree);
        rx.borrow_and_update();
        if let Some(poller) = self.inner.poller(&worktree) {
            poller.wake.notify_one();
        }
        let _ = tokio::time::timeout(self.inner.timing.refresh_timeout, rx.changed()).await;
        Ok(())
    }

    /// Re-runs the failed jobs of run `run_id` of the worktree's branch.
    pub async fn rerun_failed(&self, worktree: &Path, run_id: &str) -> Result<(), PipelinesError> {
        let worktree = self.inner.worktree(worktree)?;
        let (client, target, token) = self.inner.context(&worktree).await?;
        let known = match self.inner.poller(&worktree) {
            Some(p) => p.state.lock().await.last_run.clone(),
            None => None,
        };
        let run = match known.filter(|r| r.id == run_id) {
            Some(run) => run,
            None => {
                let (c, t, k) = (Arc::clone(&client), target.clone(), token.clone());
                blocking(move || c.latest_run(&t, &k))
                    .await?
                    .map_err(PipelinesError::Ci)?
                    .filter(|r| r.id == run_id)
                    .ok_or_else(|| {
                        PipelinesError::Invalid(format!(
                            "run {run_id} isn't the branch's latest any more"
                        ))
                    })?
            }
        };
        blocking(move || client.rerun_failed(&target, &token, &run))
            .await?
            .map_err(PipelinesError::Ci)?;
        self.refresh(&worktree).await
    }

    /// Hosts of the workspace's repositories with a supported CI.
    pub async fn hosts(&self) -> Vec<HostInfo> {
        let mut hosts: Vec<(CiHost, Vec<String>)> = Vec::new();
        for repo in self.inner.repos() {
            let Some(remote) = &repo.remote else { continue };
            let Some(host) = CiHost::for_remote(remote) else {
                continue;
            };
            let name = remote
                .full_name
                .clone()
                .unwrap_or_else(|| repo.name.clone());
            match hosts.iter_mut().find(|(h, _)| h.host == host.host) {
                Some((_, repos)) => repos.push(name),
                None => hosts.push((host, vec![name])),
            }
        }
        let mut out = Vec::new();
        for (host, mut repos) in hosts {
            repos.sort();
            repos.dedup();
            out.push(self.inner.info(host, repos).await);
        }
        out
    }

    /// Saves `host`'s token (an empty one removes it) and asks its
    /// providers again.
    pub async fn save_host_token(
        &self,
        host: &str,
        token: &str,
    ) -> Result<HostInfo, PipelinesError> {
        let known = self
            .hosts()
            .await
            .into_iter()
            .find(|h| h.host == host)
            .ok_or_else(|| PipelinesError::UnknownHost(host.to_owned()))?;
        let tokens = Arc::clone(&self.inner.ports.tokens);
        let (h, t) = (host.to_owned(), token.trim().to_owned());
        blocking(move || {
            if t.is_empty() {
                tokens.delete(&h)
            } else {
                tokens.set(&h, &t)
            }
        })
        .await??;
        self.inner.wake_host(host).await;
        Ok(self
            .hosts()
            .await
            .into_iter()
            .find(|h| h.host == host)
            .unwrap_or(known))
    }

    /// Opens a terminal running the CLI's own sign-in to `host` (`gh auth
    /// login`); once it's signed in, the host's pipelines are asked again.
    /// Kumo never sees the credentials typed there.
    pub async fn sign_in_with_cli(&self, host: &str) -> Result<TerminalId, PipelinesError> {
        let ci = self.inner.ci_host(host)?;
        let fallback = Arc::clone(&self.inner.ports.fallback);
        let target = ci.clone();
        let spec = blocking(move || fallback.sign_in(&target))
            .await?
            .ok_or_else(|| {
                PipelinesError::Invalid(format!(
                    "Install the GitHub CLI first to sign in to {host} with it: brew install gh"
                ))
            })?;
        self.inner.ports.fallback.forget(&ci);
        let terminal = self
            .inner
            .ports
            .terminals
            .launch(spec)
            .map_err(PipelinesError::Invalid)?;
        tokio::spawn(Arc::clone(&self.inner).await_sign_in(ci));
        Ok(terminal)
    }

    /// Checks `token`, or the host's saved one when empty: who it signs in as,
    /// or what's wrong with it.
    pub async fn test_host(
        &self,
        host: &str,
        token: &str,
    ) -> Result<Result<String, CiProblem>, PipelinesError> {
        let ci = self.inner.ci_host(host)?;
        let token = match token.trim() {
            "" => self.inner.token(&ci).await,
            t => Some(t.to_owned()),
        };
        let Some(token) = token else {
            return Ok(Err(CiProblem::of(CiProblemKind::NotConnected)));
        };
        let client = self.inner.client(&ci)?;
        blocking(move || client.test(&ci, &token)).await
    }
}

impl Inner {
    fn lock(&self) -> std::sync::MutexGuard<'_, HashMap<PathBuf, Arc<Poller>>> {
        self.pollers.lock().unwrap_or_else(PoisonError::into_inner)
    }

    fn repos(&self) -> Vec<Repo> {
        self.workspace
            .borrow()
            .repos
            .iter()
            .map(|r| r.repo.clone())
            .collect()
    }

    /// The canonical path of a worktree of the workspace.
    fn worktree(&self, path: &Path) -> Result<PathBuf, PipelinesError> {
        self.find(path)
            .map(|(_, w)| w)
            .ok_or_else(|| PipelinesError::UnknownWorktree(path.display().to_string()))
    }

    /// The repository owning `path`, and the worktree's own path.
    fn find(&self, path: &Path) -> Option<(Repo, PathBuf)> {
        let snapshot = self.workspace.borrow();
        let found = |same: &dyn Fn(&Path) -> bool| {
            snapshot.repos.iter().find_map(|r| {
                r.worktrees
                    .iter()
                    .find(|w| same(&w.path))
                    .map(|w| (r.repo.clone(), w.path.clone()))
            })
        };
        found(&|w| w == path).or_else(|| {
            let canonical = std::fs::canonicalize(path).ok()?;
            found(&|w| std::fs::canonicalize(w).is_ok_and(|w| w == canonical))
        })
    }

    /// The workspace's host called `host`.
    fn ci_host(&self, host: &str) -> Result<CiHost, PipelinesError> {
        self.repos()
            .iter()
            .filter_map(|r| CiHost::for_remote(r.remote.as_ref()?))
            .find(|h| h.host == host)
            .ok_or_else(|| PipelinesError::UnknownHost(host.to_owned()))
    }

    /// Waits for a CLI sign-in to `host` to finish, then asks its
    /// providers again (gives up after a while).
    async fn await_sign_in(self: Arc<Self>, host: CiHost) {
        let started = tokio::time::Instant::now();
        while started.elapsed() < self.timing.sign_in_wait {
            tokio::time::sleep(self.timing.sign_in_check).await;
            let (fallback, h) = (Arc::clone(&self.ports.fallback), host.clone());
            let signed_in = tokio::task::spawn_blocking(move || {
                fallback.forget(&h);
                fallback.token(&h).is_some()
            })
            .await
            .unwrap_or(false);
            if signed_in {
                self.wake_host(&host.host).await;
                return;
            }
        }
    }

    fn poller(&self, worktree: &Path) -> Option<Arc<Poller>> {
        self.lock().get(worktree).cloned()
    }

    /// A watcher of `worktree`, starting its poller if it had none.
    fn subscribe(self: &Arc<Self>, worktree: &Path) -> watch::Receiver<Latest> {
        let mut pollers = self.lock();
        if let Some(poller) = pollers.get(worktree) {
            return poller.tx.subscribe();
        }
        let (tx, rx) = watch::channel(None);
        let poller = Arc::new(Poller {
            worktree: worktree.to_owned(),
            tx,
            wake: Notify::new(),
            state: tokio::sync::Mutex::new(PollState::default()),
        });
        pollers.insert(worktree.to_owned(), Arc::clone(&poller));
        tokio::spawn(Arc::clone(&poller).run(Arc::clone(self)));
        rx
    }

    /// Forgets `poller` if nobody watches it any more.
    fn release(&self, poller: &Arc<Poller>) -> bool {
        let mut pollers = self.lock();
        if poller.tx.receiver_count() > 0 {
            return false;
        }
        if pollers
            .get(&poller.worktree)
            .is_some_and(|p| Arc::ptr_eq(p, poller))
        {
            pollers.remove(&poller.worktree);
        }
        true
    }

    async fn wake_host(&self, host: &str) {
        let pollers: Vec<Arc<Poller>> = self.lock().values().cloned().collect();
        for poller in pollers {
            if poller.state.lock().await.host.as_deref() == Some(host) {
                poller.wake.notify_one();
            }
        }
    }

    fn client(&self, host: &CiHost) -> Result<Arc<dyn CiClient>, PipelinesError> {
        self.ports
            .clients
            .iter()
            .find(|c| c.provider() == host.provider)
            .cloned()
            .ok_or_else(|| PipelinesError::Ci(CiProblem::of(CiProblemKind::Unsupported)))
    }

    /// The saved token, else the fallback's. Never logged.
    async fn token(&self, host: &CiHost) -> Option<String> {
        let (tokens, fallback, h) = (
            Arc::clone(&self.ports.tokens),
            Arc::clone(&self.ports.fallback),
            host.clone(),
        );
        let found = tokio::task::spawn_blocking(move || match tokens.get(&h.host) {
            Ok(Some(token)) => Some(token),
            Ok(None) => fallback.token(&h),
            Err(error) => {
                tracing::warn!(host = %h.host, %error, "can't read the host's token");
                fallback.token(&h)
            }
        });
        found.await.ok().flatten()
    }

    async fn info(&self, host: CiHost, repos: Vec<String>) -> HostInfo {
        let (tokens, fallback, h) = (
            Arc::clone(&self.ports.tokens),
            Arc::clone(&self.ports.fallback),
            host.clone(),
        );
        let (has_token, uses_fallback, fallback_account, fallback_available) =
            tokio::task::spawn_blocking(move || {
                let saved = matches!(tokens.get(&h.host), Ok(Some(_)));
                let signed_in = fallback.token(&h).is_some();
                let account = if signed_in {
                    fallback.account(&h)
                } else {
                    None
                };
                (
                    saved,
                    !saved && signed_in,
                    account,
                    fallback.sign_in(&h).is_some(),
                )
            })
            .await
            .unwrap_or_default();
        HostInfo {
            host: host.host,
            provider: host.provider,
            has_token,
            uses_fallback,
            fallback_account,
            fallback_available,
            repos,
        }
    }

    /// Client, target and token to act on `worktree`'s pipelines.
    async fn context(
        &self,
        worktree: &Path,
    ) -> Result<(Arc<dyn CiClient>, CiTarget, String), PipelinesError> {
        let problem = |kind| PipelinesError::Ci(CiProblem::of(kind));
        let (repo, path) = self
            .find(worktree)
            .ok_or_else(|| PipelinesError::UnknownWorktree(worktree.display().to_string()))?;
        let remote = repo
            .remote
            .as_ref()
            .ok_or_else(|| problem(CiProblemKind::Unsupported))?;
        let host = CiHost::for_remote(remote).ok_or_else(|| problem(CiProblemKind::Unsupported))?;
        let local = self
            .branch(&path)
            .await
            .map_err(|_| problem(CiProblemKind::NotPushed))?;
        let branch = local
            .upstream
            .as_ref()
            .and(local.remote_name())
            .ok_or_else(|| problem(CiProblemKind::NotPushed))?;
        let token = self
            .token(&host)
            .await
            .ok_or_else(|| problem(CiProblemKind::NotConnected))?;
        let client = self.client(&host)?;
        Ok((
            client,
            CiTarget {
                repo: remote.full_name.clone().unwrap_or_default(),
                branch: branch.to_owned(),
                host,
            },
            token,
        ))
    }

    async fn branch(&self, worktree: &Path) -> Result<LocalBranch, String> {
        let (branches, path) = (Arc::clone(&self.ports.branches), worktree.to_owned());
        tokio::task::spawn_blocking(move || branches.read(&path))
            .await
            .map_err(|e| e.to_string())?
    }

    /// One look at the provider: the snapshot to push and when to look next.
    async fn check(&self, worktree: &Path, st: &mut PollState) -> (PipelinesSnapshot, Duration) {
        let t = self.timing;
        let now = Timestamp::now();
        let mut snapshot = PipelinesSnapshot::default();
        let fail = |snapshot: &mut PipelinesSnapshot, problem: CiProblem, delay: Duration| {
            snapshot.problem = Some(problem);
            (snapshot.clone(), delay)
        };
        let Some((repo, path)) = self.find(worktree) else {
            return fail(
                &mut snapshot,
                CiProblem::of(CiProblemKind::Unsupported),
                t.idle,
            );
        };
        let remote = repo.remote.as_ref();
        snapshot.repo = remote.and_then(|r| r.full_name.clone()).unwrap_or_default();
        let Some(host) = remote.and_then(CiHost::for_remote) else {
            return fail(
                &mut snapshot,
                CiProblem::of(CiProblemKind::Unsupported),
                t.max_retry,
            );
        };
        snapshot.provider = Some(host.provider);
        st.host = Some(host.host.clone());
        let local = match self.branch(&path).await {
            Ok(local) => local,
            Err(error) => {
                return fail(
                    &mut snapshot,
                    CiProblem::new(CiProblemKind::NotFound, error),
                    t.idle,
                );
            }
        };
        snapshot.branch = local.name.clone().unwrap_or_default();
        let (Some(_), Some(branch)) = (&local.upstream, local.remote_name()) else {
            st.last_run = None;
            let mut problem = CiProblem::of(CiProblemKind::NotPushed);
            problem.commits_waiting = local.unpushed;
            return fail(&mut snapshot, problem, t.idle);
        };
        let Some(token) = self.token(&host).await else {
            st.last_run = None;
            return fail(
                &mut snapshot,
                CiProblem::of(CiProblemKind::NotConnected),
                t.idle,
            );
        };
        let client = match self.client(&host) {
            Ok(client) => client,
            Err(_) => {
                return fail(
                    &mut snapshot,
                    CiProblem::of(CiProblemKind::Unsupported),
                    t.max_retry,
                );
            }
        };
        let target = CiTarget {
            repo: snapshot.repo.clone(),
            branch: branch.to_owned(),
            host,
        };
        let answer = blocking(move || client.latest_run(&target, &token)).await;
        let answer = answer
            .unwrap_or_else(|e| Err(CiProblem::new(CiProblemKind::Unreachable, e.to_string())));
        match answer {
            Ok(run) => {
                st.failures = 0;
                st.checked_at = Some(now);
                let delay = if run.as_ref().is_some_and(CiRun::active) {
                    t.active
                } else {
                    t.idle
                };
                st.last_run = run.clone();
                snapshot.latest = run;
                snapshot.checked_at = Some(now);
                (snapshot, delay)
            }
            Err(mut problem) if problem.keeps_last_run() => {
                st.failures += 1;
                let delay = match problem.retry_at {
                    Some(at) if problem.kind == CiProblemKind::RateLimited => {
                        Duration::from_nanos(at.as_unix_nanos().saturating_sub(now.as_unix_nanos()))
                            .clamp(t.active, Duration::from_secs(3600))
                    }
                    _ => backoff(t, st.failures),
                };
                problem.retry_at = Some(Timestamp::from_unix_nanos(
                    now.as_unix_nanos() + u64::try_from(delay.as_nanos()).unwrap_or(u64::MAX),
                ));
                snapshot.latest = st.last_run.clone();
                snapshot.checked_at = st.checked_at;
                fail(&mut snapshot, problem, delay)
            }
            Err(problem) => {
                // The provider answered: it's the token or the repository.
                st.failures = 0;
                st.last_run = None;
                st.checked_at = Some(now);
                snapshot.checked_at = Some(now);
                fail(&mut snapshot, problem, t.idle * 2)
            }
        }
    }
}

/// 15 s, 30 s, 1 min… up to `max_retry`.
fn backoff(t: PipelinesTiming, failures: u32) -> Duration {
    t.retry
        .saturating_mul(1 << failures.saturating_sub(1).min(10))
        .min(t.max_retry)
}

impl Poller {
    async fn run(self: Arc<Self>, inner: Arc<Inner>) {
        loop {
            let delay = {
                let mut st = self.state.lock().await;
                let (snapshot, delay) = inner.check(&self.worktree, &mut st).await;
                self.tx.send_replace(Some(Arc::new(snapshot)));
                delay
            };
            tokio::select! {
                () = tokio::time::sleep(delay) => {}
                () = self.wake.notified() => {}
                () = self.tx.closed() => {
                    if inner.release(&self) {
                        return;
                    }
                }
            }
        }
    }
}

async fn blocking<T: Send + 'static>(
    f: impl FnOnce() -> T + Send + 'static,
) -> Result<T, PipelinesError> {
    tokio::task::spawn_blocking(f)
        .await
        .map_err(|e| PipelinesError::Invalid(format!("blocking task failed: {e}")))
}
