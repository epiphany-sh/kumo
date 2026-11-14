use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use kumo_domain::pipelines::{
    BranchReader, CiHost, CiProblem, CiProblemKind, CiProvider, CiTarget, HostTokens, LocalBranch,
    PipelinesError, TokenFallback,
};
use kumo_domain::pulls::{
    NewPullRequest, PrState, PullRequest, PullRequestClient, ReviewState, ReviewThread,
    ThreadAnswer,
};
use kumo_domain::tasks::Person;
use kumo_domain::workspace::{Remote, Repo, RepoState, WorkspaceSnapshot, Worktree};
use tokio::sync::watch;

use super::{PullRequestPorts, PullRequestService};

const MAIN: &str = "/work/dev/app";
const WT: &str = "/work/wt/app/feat-x";

fn pr(number: u64, branch: &str) -> PullRequest {
    PullRequest {
        number,
        label: format!("#{number}"),
        title: format!("PR {number}"),
        author: Person::new("mauri", "Mauri", true),
        branch: branch.into(),
        base: "main".into(),
        draft: false,
        state: PrState::Open,
        review: ReviewState::None,
        review_requested_from_you: false,
        reviewers: Vec::new(),
        checks_passed: 0,
        checks_total: 0,
        checks_state: None,
        url: String::new(),
        created_at: None,
        updated_at: None,
        comment_count: 0,
        open_threads: None,
        body: String::new(),
    }
}

#[derive(Default)]
struct Host {
    lists: AtomicUsize,
    created: Mutex<Vec<NewPullRequest>>,
    answered: Mutex<Vec<(u64, ThreadAnswer)>>,
    fail: Mutex<Option<CiProblem>>,
}

fn thread(id: &str, resolved: bool) -> ReviewThread {
    ReviewThread {
        id: id.into(),
        author: "Lucía".into(),
        path: "src/a.rs".into(),
        line: Some(3),
        body: "Why?".into(),
        created_at: None,
        resolved,
    }
}

impl PullRequestClient for Host {
    fn provider(&self) -> CiProvider {
        CiProvider::GitHubActions
    }
    fn list(
        &self,
        target: &CiTarget,
        token: &str,
        _: usize,
    ) -> Result<Vec<PullRequest>, CiProblem> {
        assert_eq!((target.repo.as_str(), token), ("platform/app", "ghp"));
        self.lists.fetch_add(1, Ordering::SeqCst);
        match self.fail.lock().unwrap().clone() {
            Some(p) => Err(p),
            None => Ok(vec![pr(521, "feat/x"), pr(518, "fix/y")]),
        }
    }
    fn for_branch(&self, target: &CiTarget, _: &str) -> Result<Option<PullRequest>, CiProblem> {
        Ok((target.branch == "feat/x").then(|| pr(521, "feat/x")))
    }
    fn create(
        &self,
        target: &CiTarget,
        _: &str,
        new: &NewPullRequest,
    ) -> Result<PullRequest, CiProblem> {
        self.created.lock().unwrap().push(new.clone());
        Ok(pr(530, &target.branch))
    }
    fn threads(&self, _: &CiTarget, _: &str, number: u64) -> Result<Vec<ReviewThread>, CiProblem> {
        assert_eq!(number, 521);
        Ok(vec![thread("t1", true), thread("t2", false)])
    }
    fn answer_thread(
        &self,
        _: &CiTarget,
        _: &str,
        number: u64,
        answer: &ThreadAnswer,
    ) -> Result<ReviewThread, CiProblem> {
        if let Some(p) = self.fail.lock().unwrap().clone() {
            return Err(p);
        }
        self.answered.lock().unwrap().push((number, answer.clone()));
        Ok(thread(&answer.thread_id, answer.resolve))
    }
}

struct Tokens(Mutex<Option<String>>);

impl HostTokens for Tokens {
    fn get(&self, _: &str) -> Result<Option<String>, PipelinesError> {
        Ok(self.0.lock().unwrap().clone())
    }
    fn set(&self, _: &str, t: &str) -> Result<(), PipelinesError> {
        *self.0.lock().unwrap() = Some(t.into());
        Ok(())
    }
    fn delete(&self, _: &str) -> Result<(), PipelinesError> {
        *self.0.lock().unwrap() = None;
        Ok(())
    }
}

struct NoCli;

impl TokenFallback for NoCli {
    fn token(&self, _: &CiHost) -> Option<String> {
        None
    }
}

struct Branch(Mutex<LocalBranch>);

impl BranchReader for Branch {
    fn read(&self, _: &Path) -> Result<LocalBranch, String> {
        Ok(self.0.lock().unwrap().clone())
    }
}

struct Fixture {
    service: PullRequestService,
    host: Arc<Host>,
    tokens: Arc<Tokens>,
    branch: Arc<Branch>,
}

fn fixture() -> Fixture {
    let host = Arc::new(Host::default());
    let tokens = Arc::new(Tokens(Mutex::new(Some("ghp".into()))));
    let branch = Arc::new(Branch(Mutex::new(LocalBranch {
        name: Some("feat/x".into()),
        upstream: Some("origin/feat/x".into()),
        unpushed: 0,
    })));
    let wt = |path: &str, main: bool| Worktree {
        path: PathBuf::from(path),
        branch: Some(if main { "main" } else { "feat/x" }.into()),
        head: "abc".into(),
        is_main: main,
        locked: false,
        status: Default::default(),
    };
    let snapshot = WorkspaceSnapshot {
        version: 1,
        namespaces: Vec::new(),
        repos: vec![RepoState {
            repo: Repo::new(
                PathBuf::from(MAIN),
                Some(Remote::parse("git@github.com:platform/app.git")),
            ),
            worktrees: vec![wt(MAIN, true), wt(WT, false)],
            error: None,
        }],
    };
    let (tx, rx) = watch::channel(Arc::new(snapshot));
    std::mem::forget(tx);
    let ports = PullRequestPorts {
        clients: vec![Arc::clone(&host) as Arc<dyn PullRequestClient>],
        tokens: Arc::clone(&tokens) as Arc<dyn HostTokens>,
        fallback: Arc::new(NoCli),
        branches: Arc::clone(&branch) as Arc<dyn BranchReader>,
    };
    Fixture {
        service: PullRequestService::new(ports, rx, Duration::from_secs(60)),
        host,
        tokens,
        branch,
    }
}

#[tokio::test]
async fn lists_a_repository_and_reuses_a_recent_answer() {
    let f = fixture();
    let list = f.service.list(Path::new(MAIN), false).await.unwrap();
    assert_eq!(list.provider, Some(CiProvider::GitHubActions));
    assert_eq!(
        list.pull_requests
            .iter()
            .map(|p| p.label.as_str())
            .collect::<Vec<_>>(),
        ["#521", "#518"]
    );
    f.service.list(Path::new(MAIN), false).await.unwrap();
    assert_eq!(f.host.lists.load(Ordering::SeqCst), 1, "cached");
    f.service.list(Path::new(MAIN), true).await.unwrap();
    assert_eq!(f.host.lists.load(Ordering::SeqCst), 2, "refresh asks again");
    assert!(matches!(
        f.service.list(Path::new("/elsewhere"), false).await,
        Err(PipelinesError::UnknownWorktree(_))
    ));
}

#[tokio::test]
async fn problems_come_back_with_the_list() {
    let f = fixture();
    *f.host.fail.lock().unwrap() = Some(CiProblem::new(
        CiProblemKind::Forbidden,
        "HTTP 403 · Resource not accessible",
    ));
    let list = f.service.list(Path::new(MAIN), true).await.unwrap();
    assert_eq!(
        (list.problem.unwrap().kind, list.pull_requests.len()),
        (CiProblemKind::Forbidden, 0)
    );
    f.tokens.delete("github.com").unwrap();
    let list = f.service.list(Path::new(MAIN), true).await.unwrap();
    assert_eq!(list.problem.unwrap().kind, CiProblemKind::NotConnected);
}

#[tokio::test]
async fn a_branch_has_its_pull_request_once_pushed() {
    let f = fixture();
    let mine = f.service.for_branch(Path::new(WT), false).await.unwrap();
    assert_eq!(mine.pull_request.unwrap().label, "#521");
    *f.branch.0.lock().unwrap() = LocalBranch {
        name: Some("feat/y".into()),
        upstream: None,
        unpushed: 2,
    };
    let local = f.service.for_branch(Path::new(WT), true).await.unwrap();
    let problem = local.problem.unwrap();
    assert_eq!(
        (problem.kind, problem.commits_waiting),
        (CiProblemKind::NotPushed, 2)
    );
}

#[tokio::test]
async fn creating_opens_it_from_the_branch_and_forgets_cached_answers() {
    let f = fixture();
    f.service.list(Path::new(MAIN), false).await.unwrap();
    let created = f
        .service
        .create(Path::new(WT), " feat: x ", "Body", "", true)
        .await
        .unwrap();
    assert_eq!(created.label, "#530");
    let new = f.host.created.lock().unwrap()[0].clone();
    assert_eq!(
        (new.title.as_str(), new.branch.as_str(), new.draft),
        ("feat: x", "feat/x", true)
    );
    f.service.list(Path::new(MAIN), false).await.unwrap();
    assert_eq!(
        f.host.lists.load(Ordering::SeqCst),
        2,
        "the list is read again after creating"
    );
    assert!(matches!(
        f.service.create(Path::new(WT), "  ", "", "", false).await,
        Err(PipelinesError::Invalid(_))
    ));
    *f.branch.0.lock().unwrap() = LocalBranch {
        name: Some("feat/y".into()),
        upstream: None,
        unpushed: 1,
    };
    let err = f
        .service
        .create(Path::new(WT), "t", "", "", false)
        .await
        .unwrap_err();
    assert!(matches!(err, PipelinesError::Ci(p) if p.kind == CiProblemKind::NotPushed));
}

#[tokio::test]
async fn threads_are_read_and_answered_on_the_repository() {
    let f = fixture();
    let threads = f.service.threads(Path::new(MAIN), 521).await.unwrap();
    assert_eq!(
        threads
            .iter()
            .map(|t| (t.id.as_str(), t.resolved))
            .collect::<Vec<_>>(),
        [("t1", true), ("t2", false)]
    );
    f.service.list(Path::new(MAIN), false).await.unwrap();
    let answer = ThreadAnswer {
        thread_id: "t2".into(),
        reply: "Done in a91c4e2".into(),
        resolve: true,
    };
    let answered = f
        .service
        .answer_thread(Path::new(MAIN), 521, answer.clone())
        .await
        .unwrap();
    assert!(answered.resolved);
    assert_eq!(f.host.answered.lock().unwrap()[0], (521, answer));
    f.service.list(Path::new(MAIN), false).await.unwrap();
    assert_eq!(
        f.host.lists.load(Ordering::SeqCst),
        2,
        "open thread counts are read again"
    );

    let nothing = ThreadAnswer {
        thread_id: "t2".into(),
        reply: " ".into(),
        resolve: false,
    };
    assert!(matches!(
        f.service.answer_thread(Path::new(MAIN), 521, nothing).await,
        Err(PipelinesError::Invalid(_))
    ));
    *f.host.fail.lock().unwrap() = Some(CiProblem::new(CiProblemKind::Forbidden, "HTTP 403"));
    let err = f
        .service
        .answer_thread(
            Path::new(MAIN),
            521,
            ThreadAnswer {
                thread_id: "t2".into(),
                reply: String::new(),
                resolve: true,
            },
        )
        .await
        .unwrap_err();
    assert!(matches!(err, PipelinesError::Ci(p) if p.kind == CiProblemKind::Forbidden));
    f.tokens.delete("github.com").unwrap();
    assert!(matches!(
        f.service.threads(Path::new(MAIN), 521).await,
        Err(PipelinesError::Ci(p)) if p.kind == CiProblemKind::NotConnected
    ));
}
