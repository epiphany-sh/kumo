use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use kumo_domain::pipelines::{
    CiHost, CiProblem, CiProblemKind, CiProvider, CiTarget, HostTokens, PipelinesError,
    TokenFallback,
};
use kumo_domain::releases::{
    GitTag, GitTags, Release, ReleaseClient, ReleaseEdit, ReleaseKind, ReleaseRange,
};
use kumo_domain::time::Timestamp;
use kumo_domain::workspace::{Remote, Repo, RepoState, WorkspaceSnapshot};
use tokio::sync::watch;

use super::{ReleasePorts, ReleaseService};

const MAIN: &str = "/work/dev/app";

fn at(secs: u64) -> Option<Timestamp> {
    Some(Timestamp::from_unix_nanos(secs * 1_000_000_000))
}

fn tag(name: &str, sha: &str, secs: u64) -> GitTag {
    GitTag {
        name: name.into(),
        sha: sha.into(),
        time: at(secs),
        author: "Tomás".into(),
    }
}

fn release(tag: &str, kind: ReleaseKind, secs: u64) -> Release {
    Release {
        tag: tag.into(),
        kind,
        name: format!("{tag} name"),
        notes: String::new(),
        author: "mauri".into(),
        sha: String::new(),
        time: at(secs),
        url: format!("https://host/releases/{tag}"),
        checks: None,
        assets: Vec::new(),
    }
}

#[derive(Default)]
struct Git {
    fetches: AtomicUsize,
}

impl GitTags for Git {
    fn fetch_tags(&self, repo: &Path) -> Result<(), String> {
        assert_eq!(repo, Path::new(MAIN));
        self.fetches.fetch_add(1, Ordering::SeqCst);
        Err("offline".into())
    }
    fn tags(&self, _: &Path) -> Result<Vec<GitTag>, String> {
        Ok(vec![
            tag("v1.9.0-rc.1", "b41e9d0", 300),
            tag("v1.8.0", "7f3a2c1", 200),
            tag("v1.7.3", "3c09e1a", 100),
        ])
    }
    fn range(&self, _: &Path, tag: &str, since: Option<&str>) -> Result<ReleaseRange, String> {
        Ok(ReleaseRange {
            since: since.unwrap_or_default().into(),
            commits: if tag == "v1.8.0" { 17 } else { 1 },
            ..ReleaseRange::default()
        })
    }
}

struct Host {
    releases: bool,
    lists: AtomicUsize,
    edits: Mutex<Vec<(String, ReleaseEdit)>>,
}

impl Host {
    fn new(releases: bool) -> Self {
        Self {
            releases,
            lists: AtomicUsize::new(0),
            edits: Mutex::new(Vec::new()),
        }
    }
}

impl ReleaseClient for Host {
    fn provider(&self) -> CiProvider {
        CiProvider::GitHubActions
    }
    fn has_releases(&self) -> bool {
        self.releases
    }
    fn list(&self, target: &CiTarget, token: &str, _: usize) -> Result<Vec<Release>, CiProblem> {
        assert_eq!((target.repo.as_str(), token), ("platform/app", "ghp"));
        self.lists.fetch_add(1, Ordering::SeqCst);
        Ok(vec![
            release("v2.0.0", ReleaseKind::Draft, 400),
            release("v1.9.0-rc.1", ReleaseKind::PreRelease, 310),
            Release {
                time: None,
                ..release("v1.8.0", ReleaseKind::Release, 0)
            },
        ])
    }
    fn edit(
        &self,
        _: &CiTarget,
        _: &str,
        tag: &str,
        edit: &ReleaseEdit,
    ) -> Result<Release, CiProblem> {
        if !self.releases {
            return Err(CiProblem::new(
                CiProblemKind::Unsupported,
                "Bitbucket has tags but no releases",
            ));
        }
        self.edits.lock().unwrap().push((tag.into(), edit.clone()));
        let mut r = release(tag, ReleaseKind::Release, 500);
        r.notes = edit.notes.clone().unwrap_or_default();
        Ok(r)
    }
    fn tag_url(&self, _: &CiTarget, tag: &str) -> String {
        format!("https://host/tags/{tag}")
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

struct Fixture {
    service: ReleaseService,
    git: Arc<Git>,
    host: Arc<Host>,
    tokens: Arc<Tokens>,
}

fn fixture(releases: bool) -> Fixture {
    let git = Arc::new(Git::default());
    let host = Arc::new(Host::new(releases));
    let tokens = Arc::new(Tokens(Mutex::new(Some("ghp".into()))));
    let snapshot = WorkspaceSnapshot {
        version: 1,
        namespaces: Vec::new(),
        repos: vec![RepoState {
            repo: Repo::new(
                PathBuf::from(MAIN),
                Some(Remote::parse("git@github.com:platform/app.git")),
            ),
            worktrees: Vec::new(),
            error: None,
        }],
    };
    let (tx, rx) = watch::channel(Arc::new(snapshot));
    std::mem::forget(tx);
    let ports = ReleasePorts {
        clients: vec![Arc::clone(&host) as Arc<dyn ReleaseClient>],
        git: Arc::clone(&git) as Arc<dyn GitTags>,
        tokens: Arc::clone(&tokens) as Arc<dyn HostTokens>,
        fallback: Arc::new(NoCli),
    };
    Fixture {
        service: ReleaseService::new(ports, rx, Duration::from_secs(60)),
        git,
        host,
        tokens,
    }
}

#[tokio::test]
async fn tags_take_their_release_and_untagged_drafts_go_first() {
    let f = fixture(true);
    let list = f.service.list(Path::new(MAIN), 0, false).await.unwrap();
    let rows: Vec<_> = list
        .releases
        .iter()
        .map(|r| (r.tag.as_str(), r.kind, r.sha.as_str(), r.url.as_str()))
        .collect();
    assert_eq!(
        rows,
        [
            (
                "v2.0.0",
                ReleaseKind::Draft,
                "",
                "https://host/releases/v2.0.0"
            ),
            (
                "v1.9.0-rc.1",
                ReleaseKind::PreRelease,
                "b41e9d0",
                "https://host/releases/v1.9.0-rc.1"
            ),
            (
                "v1.8.0",
                ReleaseKind::Release,
                "7f3a2c1",
                "https://host/releases/v1.8.0"
            ),
            (
                "v1.7.3",
                ReleaseKind::TagOnly,
                "3c09e1a",
                "https://host/tags/v1.7.3"
            ),
        ]
    );
    assert_eq!(list.releases[2].time, at(200), "no publish time: the tag's");
    assert_eq!(list.releases[3].author, "Tomás");
    assert_eq!((list.older, list.problem), (0, None));
    assert_eq!(
        f.git.fetches.load(Ordering::SeqCst),
        1,
        "fetched the first time"
    );

    let short = f.service.list(Path::new(MAIN), 2, false).await.unwrap();
    assert_eq!((short.releases.len(), short.older), (2, 2));
    assert_eq!(f.host.lists.load(Ordering::SeqCst), 1, "cached");
    assert_eq!(f.git.fetches.load(Ordering::SeqCst), 1);

    f.service.list(Path::new(MAIN), 0, true).await.unwrap();
    assert_eq!(
        (
            f.host.lists.load(Ordering::SeqCst),
            f.git.fetches.load(Ordering::SeqCst)
        ),
        (2, 2),
        "refresh fetches and asks again"
    );
    assert!(matches!(
        f.service.list(Path::new("/elsewhere"), 0, false).await,
        Err(PipelinesError::UnknownWorktree(_))
    ));
}

#[tokio::test]
async fn without_a_token_tags_still_list_with_the_problem() {
    let f = fixture(true);
    f.tokens.delete("github.com").unwrap();
    let list = f.service.list(Path::new(MAIN), 0, false).await.unwrap();
    assert_eq!(list.problem.unwrap().kind, CiProblemKind::NotConnected);
    assert!(list.releases.iter().all(|r| r.kind == ReleaseKind::TagOnly));
    assert_eq!(list.releases.len(), 3);
}

#[tokio::test]
async fn a_host_without_releases_lists_tags_and_refuses_edits() {
    let f = fixture(false);
    f.tokens.delete("github.com").unwrap();
    let list = f.service.list(Path::new(MAIN), 0, false).await.unwrap();
    assert_eq!(list.problem, None, "no token needed for tags");
    assert_eq!(f.host.lists.load(Ordering::SeqCst), 0);
    let err = f
        .service
        .edit(Path::new(MAIN), "v1.8.0", ReleaseEdit::default())
        .await
        .unwrap_err();
    assert!(matches!(err, PipelinesError::Unsupported(m) if m.contains("no releases")));
}

#[tokio::test]
async fn editing_sends_the_tagged_commit_and_lists_again() {
    let f = fixture(true);
    f.service.list(Path::new(MAIN), 0, false).await.unwrap();
    let edit = ReleaseEdit {
        notes: Some("## Fixes".into()),
        ..ReleaseEdit::default()
    };
    let release = f
        .service
        .edit(Path::new(MAIN), " v1.7.3 ", edit)
        .await
        .unwrap();
    assert_eq!(
        (release.sha.as_str(), release.notes.as_str()),
        ("3c09e1a", "## Fixes")
    );
    let (tag, sent) = f.host.edits.lock().unwrap()[0].clone();
    assert_eq!((tag.as_str(), sent.sha.as_str()), ("v1.7.3", "3c09e1a"));
    f.service.list(Path::new(MAIN), 0, false).await.unwrap();
    assert_eq!(
        f.host.lists.load(Ordering::SeqCst),
        2,
        "the list is read again"
    );
}

#[tokio::test]
async fn ranges_need_two_different_tags() {
    let f = fixture(true);
    let range = f
        .service
        .range(Path::new(MAIN), "v1.8.0", "v1.7.3")
        .await
        .unwrap();
    assert_eq!((range.since.as_str(), range.commits), ("v1.7.3", 17));
    let first = f
        .service
        .range(Path::new(MAIN), "v1.7.3", "")
        .await
        .unwrap();
    assert_eq!(first.since, "");
    assert!(matches!(
        f.service.range(Path::new(MAIN), "v1.8.0", "v1.8.0").await,
        Err(PipelinesError::Invalid(_))
    ));
}
