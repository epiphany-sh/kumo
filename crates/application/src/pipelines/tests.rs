use std::collections::VecDeque;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use kumo_domain::pipelines::{
    BranchReader, CiClient, CiHost, CiJob, CiProblem, CiProblemKind, CiProvider, CiRun, CiState,
    CiTarget, HostTokens, LocalBranch, PipelinesError, PipelinesSnapshot, TokenFallback,
};
use kumo_domain::terminal::{LaunchSpec, TerminalId};
use kumo_domain::time::Timestamp;
use kumo_domain::workspace::{Remote, Repo, RepoState, WorkspaceSnapshot, Worktree};
use tokio::sync::watch;

use super::{PipelinesPorts, PipelinesService, PipelinesTiming, TerminalLauncher};

const WT: &str = "/work/wt/app/feat-x";

type Answer = Result<Option<CiRun>, CiProblem>;

/// A provider answering from a script (the last answer repeats).
#[derive(Default)]
struct Script {
    answers: Mutex<VecDeque<Answer>>,
    calls: AtomicUsize,
    targets: Mutex<Vec<CiTarget>>,
    reruns: Mutex<Vec<String>>,
}

impl Script {
    fn then(&self, answer: Answer) {
        self.answers.lock().unwrap().push_back(answer);
    }

    fn calls(&self) -> usize {
        self.calls.load(Ordering::SeqCst)
    }
}

impl CiClient for Script {
    fn provider(&self) -> CiProvider {
        CiProvider::GitHubActions
    }

    fn latest_run(&self, target: &CiTarget, token: &str) -> Answer {
        assert!(token == "ghp_saved" || token == "gho_cli", "{token}");
        self.calls.fetch_add(1, Ordering::SeqCst);
        self.targets.lock().unwrap().push(target.clone());
        let mut answers = self.answers.lock().unwrap();
        if answers.len() > 1 {
            answers.pop_front().unwrap()
        } else {
            answers.front().cloned().unwrap_or(Ok(None))
        }
    }

    fn rerun_failed(&self, _: &CiTarget, _: &str, run: &CiRun) -> Result<(), CiProblem> {
        self.reruns.lock().unwrap().push(run.id.clone());
        Ok(())
    }

    fn test(&self, _: &CiHost, token: &str) -> Result<String, CiProblem> {
        if token == "bad" {
            Err(CiProblem::new(
                CiProblemKind::Unauthorized,
                "HTTP 401 · Bad credentials",
            ))
        } else {
            Ok("Signed in as ana".into())
        }
    }
}

#[derive(Default)]
struct Tokens(Mutex<Vec<(String, String)>>);

impl HostTokens for Tokens {
    fn get(&self, host: &str) -> Result<Option<String>, PipelinesError> {
        Ok(self
            .0
            .lock()
            .unwrap()
            .iter()
            .find(|(h, _)| h == host)
            .map(|(_, t)| t.clone()))
    }
    fn set(&self, host: &str, token: &str) -> Result<(), PipelinesError> {
        self.delete(host)?;
        self.0.lock().unwrap().push((host.into(), token.into()));
        Ok(())
    }
    fn delete(&self, host: &str) -> Result<(), PipelinesError> {
        self.0.lock().unwrap().retain(|(h, _)| h != host);
        Ok(())
    }
}

/// A CLI that can be signed in to (`gh`).
#[derive(Default)]
struct Cli {
    signed_in: std::sync::atomic::AtomicBool,
    forgotten: AtomicUsize,
}

impl TokenFallback for Cli {
    fn token(&self, _: &CiHost) -> Option<String> {
        self.signed_in
            .load(Ordering::SeqCst)
            .then(|| "gho_cli".to_owned())
    }

    fn account(&self, _: &CiHost) -> Option<String> {
        Some("ana".into())
    }

    fn sign_in(&self, host: &CiHost) -> Option<LaunchSpec> {
        Some(LaunchSpec::new("gh").unwrap().with_args([
            "auth",
            "login",
            "--hostname",
            host.host.as_str(),
            "--web",
        ]))
    }

    fn forget(&self, _: &CiHost) {
        self.forgotten.fetch_add(1, Ordering::SeqCst);
    }
}

#[derive(Default)]
struct Terminals(Mutex<Vec<LaunchSpec>>);

impl TerminalLauncher for Terminals {
    fn launch(&self, spec: LaunchSpec) -> Result<TerminalId, String> {
        self.0.lock().unwrap().push(spec);
        Ok(TerminalId::generate())
    }
}

struct Branch(Mutex<LocalBranch>);

impl BranchReader for Branch {
    fn read(&self, worktree: &Path) -> Result<LocalBranch, String> {
        assert_eq!(worktree, Path::new(WT));
        Ok(self.0.lock().unwrap().clone())
    }
}

fn pushed() -> LocalBranch {
    LocalBranch {
        name: Some("feat/x".into()),
        upstream: Some("origin/feat/x".into()),
        unpushed: 0,
    }
}

fn run(id: &str, state: CiState) -> CiRun {
    CiRun {
        id: id.into(),
        label: format!("run #{id}"),
        sha: "4e1b2c0d9a8f".into(),
        title: "feat: x".into(),
        state,
        created_at: None,
        finished_at: None,
        url: String::new(),
        jobs: vec![CiJob {
            id: "1".into(),
            name: "build".into(),
            state,
            duration_ms: None,
            started_at: None,
            failure: None,
            url: String::new(),
        }],
    }
}

struct Fixture {
    service: PipelinesService,
    script: Arc<Script>,
    tokens: Arc<Tokens>,
    branch: Arc<Branch>,
    cli: Arc<Cli>,
    terminals: Arc<Terminals>,
}

fn fixture(remote: &str) -> Fixture {
    let script = Arc::new(Script::default());
    let tokens = Arc::new(Tokens::default());
    tokens.set("github.com", "ghp_saved").unwrap();
    let branch = Arc::new(Branch(Mutex::new(pushed())));
    let repo = Repo::new(PathBuf::from("/work/dev/app"), Some(Remote::parse(remote)));
    let worktree = Worktree {
        path: PathBuf::from(WT),
        branch: Some("feat/x".into()),
        head: "4e1b2c0".into(),
        is_main: false,
        locked: false,
        status: Default::default(),
    };
    let snapshot = WorkspaceSnapshot {
        version: 1,
        namespaces: Vec::new(),
        repos: vec![RepoState {
            repo,
            worktrees: vec![worktree],
            error: None,
        }],
    };
    let (_tx, rx) = watch::channel(Arc::new(snapshot));
    std::mem::forget(_tx);
    let timing = PipelinesTiming {
        active: Duration::from_millis(30),
        idle: Duration::from_millis(300),
        retry: Duration::from_millis(40),
        max_retry: Duration::from_millis(300),
        refresh_timeout: Duration::from_secs(5),
        sign_in_check: Duration::from_millis(20),
        sign_in_wait: Duration::from_secs(5),
    };
    let cli = Arc::new(Cli::default());
    let terminals = Arc::new(Terminals::default());
    let ports = PipelinesPorts {
        clients: vec![Arc::clone(&script) as Arc<dyn CiClient>],
        tokens: Arc::clone(&tokens) as Arc<dyn HostTokens>,
        fallback: Arc::clone(&cli) as Arc<dyn TokenFallback>,
        branches: Arc::clone(&branch) as Arc<dyn BranchReader>,
        terminals: Arc::clone(&terminals) as Arc<dyn TerminalLauncher>,
    };
    Fixture {
        service: PipelinesService::new(ports, timing, rx),
        script,
        tokens,
        branch,
        cli,
        terminals,
    }
}

/// The next pushed snapshot.
async fn next(rx: &mut watch::Receiver<Option<Arc<PipelinesSnapshot>>>) -> Arc<PipelinesSnapshot> {
    tokio::time::timeout(Duration::from_secs(5), async {
        loop {
            rx.changed().await.unwrap();
            if let Some(s) = rx.borrow_and_update().clone() {
                return s;
            }
        }
    })
    .await
    .expect("no snapshot")
}

#[tokio::test(flavor = "multi_thread")]
async fn polls_fast_while_a_run_is_active_and_slow_once_it_finished() {
    let f = fixture("git@github.com:pricing/app.git");
    f.script.then(Ok(Some(run("1", CiState::Running))));
    f.script.then(Ok(Some(run("1", CiState::Running))));
    f.script.then(Ok(Some(run("1", CiState::Passed))));
    let mut rx = f.service.watch(Path::new(WT)).unwrap();
    let first = next(&mut rx).await;
    assert_eq!(first.provider, Some(CiProvider::GitHubActions));
    assert_eq!(
        (first.repo.as_str(), first.branch.as_str()),
        ("pricing/app", "feat/x")
    );
    assert_eq!(first.latest.as_ref().unwrap().state, CiState::Running);
    assert!(first.checked_at.is_some());
    assert_eq!(f.script.targets.lock().unwrap()[0].branch, "feat/x");

    // Every 30 ms while running, then every 300 ms.
    let passed = loop {
        let s = next(&mut rx).await;
        if s.latest.as_ref().unwrap().state == CiState::Passed {
            break s;
        }
    };
    assert!(passed.problem.is_none());
    let calls = f.script.calls();
    tokio::time::sleep(Duration::from_millis(150)).await;
    assert_eq!(
        f.script.calls(),
        calls,
        "no fast polling after the run finished"
    );
}

#[tokio::test(flavor = "multi_thread")]
async fn watchers_share_one_poller_that_stops_when_they_leave() {
    let f = fixture("git@github.com:pricing/app.git");
    f.script.then(Ok(Some(run("1", CiState::Running))));
    let mut a = f.service.watch(Path::new(WT)).unwrap();
    let mut b = f.service.watch(Path::new(WT)).unwrap();
    next(&mut a).await;
    tokio::time::sleep(Duration::from_millis(100)).await;
    let polled = f.script.calls();
    assert!(
        (3..=6).contains(&polled),
        "one poller every 30 ms, got {polled} calls"
    );
    assert!(
        b.borrow_and_update().is_some(),
        "the second watcher sees the same answers"
    );
    drop((a, b));
    tokio::time::sleep(Duration::from_millis(80)).await;
    let stopped = f.script.calls();
    tokio::time::sleep(Duration::from_millis(120)).await;
    assert_eq!(f.script.calls(), stopped, "nobody watches: no more polling");
    assert_eq!(f.service.polling(), 0);
}

#[tokio::test(flavor = "multi_thread")]
async fn local_problems_need_no_provider() {
    let f = fixture("git@github.com:pricing/app.git");
    *f.branch.0.lock().unwrap() = LocalBranch {
        name: Some("feat/x".into()),
        upstream: None,
        unpushed: 3,
    };
    let mut rx = f.service.watch(Path::new(WT)).unwrap();
    let s = next(&mut rx).await;
    let p = s.problem.as_ref().unwrap();
    assert_eq!((p.kind, p.commits_waiting), (CiProblemKind::NotPushed, 3));

    *f.branch.0.lock().unwrap() = pushed();
    f.tokens.delete("github.com").unwrap();
    f.service.refresh(Path::new(WT)).await.unwrap();
    assert_eq!(
        rx.borrow_and_update()
            .clone()
            .unwrap()
            .problem
            .as_ref()
            .unwrap()
            .kind,
        CiProblemKind::NotConnected
    );
    assert_eq!(f.script.calls(), 0);

    let local = fixture("/srv/git/app.git");
    let mut rx = local.service.watch(Path::new(WT)).unwrap();
    let s = next(&mut rx).await;
    assert_eq!(
        (s.provider, s.problem.as_ref().unwrap().kind),
        (None, CiProblemKind::Unsupported)
    );
    assert!(matches!(
        local.service.watch(Path::new("/elsewhere")),
        Err(PipelinesError::UnknownWorktree(_))
    ));
}

#[tokio::test(flavor = "multi_thread")]
async fn outages_keep_the_last_run_and_back_off() {
    let f = fixture("git@github.com:pricing/app.git");
    f.script.then(Ok(Some(run("7", CiState::Failed))));
    f.script.then(Err(CiProblem::new(
        CiProblemKind::Unreachable,
        "Timed out after 10 s · api.github.com",
    )));
    let mut rx = f.service.watch(Path::new(WT)).unwrap();
    let ok = next(&mut rx).await;
    f.service.refresh(Path::new(WT)).await.unwrap();
    let down = rx.borrow_and_update().clone().unwrap();
    let p = down.problem.as_ref().unwrap();
    assert_eq!(p.kind, CiProblemKind::Unreachable);
    assert!(p.retry_at.is_some_and(|at| at > Timestamp::now()));
    assert_eq!(
        down.latest.as_ref().unwrap().id,
        "7",
        "the last run stays, stale"
    );
    assert_eq!(
        down.checked_at, ok.checked_at,
        "the provider didn't answer since"
    );

    // 40 ms, 80 ms, 160 ms…: a handful of tries in 400 ms, not one per 30 ms.
    let before = f.script.calls();
    tokio::time::sleep(Duration::from_millis(400)).await;
    let tries = f.script.calls() - before;
    assert!((1..=5).contains(&tries), "backoff, got {tries} tries");
}

#[tokio::test(flavor = "multi_thread")]
async fn token_problems_drop_the_run_and_saving_a_token_retries() {
    let f = fixture("git@github.com:pricing/app.git");
    f.script.then(Ok(Some(run("7", CiState::Passed))));
    let mut rx = f.service.watch(Path::new(WT)).unwrap();
    next(&mut rx).await;
    f.tokens.delete("github.com").unwrap();
    f.service.refresh(Path::new(WT)).await.unwrap();
    let s = rx.borrow_and_update().clone().unwrap();
    assert_eq!(
        (s.problem.as_ref().unwrap().kind, s.latest.is_none()),
        (CiProblemKind::NotConnected, true)
    );

    let info = f
        .service
        .save_host_token("github.com", " ghp_saved ")
        .await
        .unwrap();
    assert!(info.has_token);
    assert_eq!(info.repos, ["pricing/app"]);
    let s = next(&mut rx).await;
    assert!(
        s.problem.is_none(),
        "saving the token asks the provider again"
    );
    assert_eq!(s.latest.as_ref().unwrap().id, "7");
    assert!(matches!(
        f.service.save_host_token("gitlab.com", "x").await,
        Err(PipelinesError::UnknownHost(_))
    ));
}

#[tokio::test(flavor = "multi_thread")]
async fn reruns_the_failed_jobs_of_the_latest_run() {
    let f = fixture("git@github.com:pricing/app.git");
    f.script.then(Ok(Some(run("7", CiState::Failed))));
    let mut rx = f.service.watch(Path::new(WT)).unwrap();
    next(&mut rx).await;
    f.service.rerun_failed(Path::new(WT), "7").await.unwrap();
    assert_eq!(*f.script.reruns.lock().unwrap(), ["7"]);
    let stale = f
        .service
        .rerun_failed(Path::new(WT), "6")
        .await
        .unwrap_err();
    assert!(stale.to_string().contains("isn't the branch's latest"));
}

#[tokio::test(flavor = "multi_thread")]
async fn hosts_and_token_tests() {
    let f = fixture("git@github.com:pricing/app.git");
    let hosts = f.service.hosts().await;
    assert_eq!(hosts.len(), 1);
    assert_eq!(
        (
            hosts[0].host.as_str(),
            hosts[0].provider,
            hosts[0].has_token
        ),
        ("github.com", CiProvider::GitHubActions, true)
    );
    assert_eq!(
        f.service
            .test_host("github.com", "")
            .await
            .unwrap()
            .unwrap(),
        "Signed in as ana"
    );
    assert_eq!(
        f.service
            .test_host("github.com", "bad")
            .await
            .unwrap()
            .unwrap_err()
            .kind,
        CiProblemKind::Unauthorized
    );
    f.tokens.delete("github.com").unwrap();
    assert_eq!(
        f.service
            .test_host("github.com", "")
            .await
            .unwrap()
            .unwrap_err()
            .kind,
        CiProblemKind::NotConnected
    );
}

#[tokio::test(flavor = "multi_thread")]
async fn signing_in_with_the_cli_opens_its_login_and_retries_once_it_is_done() {
    let f = fixture("git@github.com:pricing/app.git");
    f.tokens.delete("github.com").unwrap();
    f.script.then(Ok(Some(run("7", CiState::Passed))));
    let mut rx = f.service.watch(Path::new(WT)).unwrap();
    assert_eq!(
        next(&mut rx).await.problem.as_ref().unwrap().kind,
        CiProblemKind::NotConnected
    );
    let before = f.service.hosts().await;
    assert_eq!(
        (
            before[0].uses_fallback,
            before[0].fallback_available,
            before[0].fallback_account.clone()
        ),
        (false, true, None)
    );

    f.service.sign_in_with_cli("github.com").await.unwrap();
    let spec = f.terminals.0.lock().unwrap()[0].clone();
    assert_eq!(spec.program(), "gh");
    assert_eq!(
        spec.args(),
        ["auth", "login", "--hostname", "github.com", "--web"]
    );
    assert!(
        f.cli.forgotten.load(Ordering::SeqCst) >= 1,
        "a remembered sign-out is dropped"
    );

    // The user finishes in the terminal: the pipelines come without a refresh.
    f.cli.signed_in.store(true, Ordering::SeqCst);
    let s = next(&mut rx).await;
    assert!(s.problem.is_none());
    assert_eq!(s.latest.as_ref().unwrap().id, "7");
    let after = f.service.hosts().await;
    assert_eq!(
        (
            after[0].has_token,
            after[0].uses_fallback,
            after[0].fallback_account.as_deref()
        ),
        (false, true, Some("ana"))
    );
    assert!(matches!(
        f.service.sign_in_with_cli("gitlab.com").await,
        Err(PipelinesError::UnknownHost(_))
    ));
}
