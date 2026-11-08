use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, PoisonError};
use std::time::{Duration, Instant};

use kumo_domain::pipelines::{
    CiHost, CiProblem, CiProblemKind, CiTarget, HostTokens, PipelinesError, TokenFallback,
};
use kumo_domain::releases::{GitTag, GitTags, Release, ReleaseClient, ReleaseEdit, ReleaseRange};
use kumo_domain::workspace::{Repo, WorkspaceSnapshot};
use tokio::sync::watch;

use crate::pulls::{host_token, repo_at};

pub struct ReleasePorts {
    pub clients: Vec<Arc<dyn ReleaseClient>>,
    pub git: Arc<dyn GitTags>,
    pub tokens: Arc<dyn HostTokens>,
    pub fallback: Arc<dyn TokenFallback>,
}

impl std::fmt::Debug for ReleasePorts {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ReleasePorts")
            .field("clients", &self.clients.len())
            .finish_non_exhaustive()
    }
}

/// Releases and bare tags, newest version first.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct ReleaseList {
    pub releases: Vec<Release>,
    /// How many more there are beyond the limit.
    pub older: u32,
    /// Why the host's releases couldn't be read: the tags come alone.
    pub problem: Option<CiProblem>,
}

/// Listed when the caller doesn't say.
const DEFAULT_LIMIT: usize = 50;
/// Host releases read at once.
const HOST_LIMIT: usize = 100;

/// What [`ReleaseService::list`] remembers per repository.
type Cached = (Instant, Vec<Release>, Option<CiProblem>);

pub struct ReleaseService {
    ports: ReleasePorts,
    workspace: watch::Receiver<Arc<WorkspaceSnapshot>>,
    /// How long a list is reused.
    fresh: Duration,
    lists: Mutex<HashMap<PathBuf, Cached>>,
    /// Repositories whose tags were fetched since the daemon started.
    fetched: Mutex<HashSet<PathBuf>>,
}

impl std::fmt::Debug for ReleaseService {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ReleaseService").finish_non_exhaustive()
    }
}

/// The host side of a repository.
enum Host {
    /// No remote, or one Kumo doesn't know: tags without links.
    None,
    /// Known, but releases can't be read: tags with links, and why.
    Problem(Arc<dyn ReleaseClient>, CiTarget, CiProblem),
    /// Tags only (Bitbucket).
    TagsOnly(Arc<dyn ReleaseClient>, CiTarget),
    Releases(Arc<dyn ReleaseClient>, CiTarget, String),
}

impl ReleaseService {
    pub fn new(
        ports: ReleasePorts,
        workspace: watch::Receiver<Arc<WorkspaceSnapshot>>,
        fresh: Duration,
    ) -> Self {
        Self {
            ports,
            workspace,
            fresh,
            lists: Mutex::new(HashMap::new()),
            fetched: Mutex::new(HashSet::new()),
        }
    }

    /// Tags and releases of the repository at `repo_path` (its main
    /// checkout). Tags are fetched the first time and on `refresh`.
    pub async fn list(
        &self,
        repo_path: &Path,
        limit: usize,
        refresh: bool,
    ) -> Result<ReleaseList, PipelinesError> {
        let repo = self.repo(repo_path)?;
        let limit = if limit == 0 { DEFAULT_LIMIT } else { limit };
        let cached = lock(&self.lists)
            .get(&repo.path)
            .filter(|(at, ..)| !refresh && at.elapsed() < self.fresh)
            .map(|(_, releases, problem)| (releases.clone(), problem.clone()));
        let (releases, problem) = match cached {
            Some(hit) => hit,
            None => {
                let answer = self.read(&repo, refresh).await?;
                lock(&self.lists).insert(
                    repo.path.clone(),
                    (Instant::now(), answer.0.clone(), answer.1.clone()),
                );
                answer
            }
        };
        let older = releases.len().saturating_sub(limit);
        Ok(ReleaseList {
            releases: releases.into_iter().take(limit).collect(),
            older: u32::try_from(older).unwrap_or(u32::MAX),
            problem,
        })
    }

    /// What changed in `tag` since `since` (empty: since the first commit).
    pub async fn range(
        &self,
        repo_path: &Path,
        tag: &str,
        since: &str,
    ) -> Result<ReleaseRange, PipelinesError> {
        let repo = self.repo(repo_path)?;
        let (tag, since) = (tag.trim().to_owned(), since.trim().to_owned());
        if tag.is_empty() {
            return Err(PipelinesError::Invalid("Which tag?".into()));
        }
        if tag == since {
            return Err(PipelinesError::Invalid(format!(
                "{tag} can't be compared with itself"
            )));
        }
        let git = Arc::clone(&self.ports.git);
        blocking(move || {
            let since = (!since.is_empty()).then_some(since.as_str());
            git.range(&repo.path, &tag, since)
        })
        .await?
        .map_err(PipelinesError::Invalid)
    }

    /// Sets `tag`'s release name and/or notes; creates its release when it
    /// has none; `publish` makes a pre-release or draft the latest.
    pub async fn edit(
        &self,
        repo_path: &Path,
        tag: &str,
        mut edit: ReleaseEdit,
    ) -> Result<Release, PipelinesError> {
        let repo = self.repo(repo_path)?;
        let tag = tag.trim().to_owned();
        if tag.is_empty() {
            return Err(PipelinesError::Invalid("Which tag?".into()));
        }
        let (client, target, token) = match self.host(&repo).await {
            Host::Releases(client, target, token) => (client, target, token),
            Host::TagsOnly(client, target) => {
                let problem = client
                    .edit(&target, "", &tag, &edit)
                    .err()
                    .map_or_else(|| "This host has no releases".to_owned(), |p| p.detail);
                return Err(PipelinesError::Unsupported(problem));
            }
            Host::Problem(_, _, problem) => return Err(PipelinesError::Ci(problem)),
            Host::None => {
                return Err(PipelinesError::Unsupported(
                    "Kumo doesn't know this repository's host".into(),
                ));
            }
        };
        let tags = self.tags(&repo).await.unwrap_or_default();
        let local = tags.iter().find(|t| t.name == tag).cloned();
        if let Some(local) = &local {
            edit.sha.clone_from(&local.sha);
        }
        let mut release = blocking(move || client.edit(&target, &token, &tag, &edit))
            .await?
            .map_err(|p| match p.kind {
                CiProblemKind::Unsupported => PipelinesError::Unsupported(p.detail),
                _ => PipelinesError::Ci(p),
            })?;
        if let Some(local) = local {
            fill_from_tag(&mut release, &local);
        }
        lock(&self.lists).remove(&repo.path);
        Ok(release)
    }

    fn repo(&self, path: &Path) -> Result<Repo, PipelinesError> {
        repo_at(&self.workspace, path)
            .ok_or_else(|| PipelinesError::UnknownWorktree(path.display().to_string()))
    }

    /// Tags (fetched first when asked to, or never before) and the host's
    /// releases, merged.
    async fn read(
        &self,
        repo: &Repo,
        refresh: bool,
    ) -> Result<(Vec<Release>, Option<CiProblem>), PipelinesError> {
        let first = lock(&self.fetched).insert(repo.path.clone());
        if (refresh || first) && repo.remote.is_some() {
            let (git, path) = (Arc::clone(&self.ports.git), repo.path.clone());
            // Offline, or no access: the tags already here still list.
            if let Err(error) = blocking(move || git.fetch_tags(&path)).await? {
                tracing::debug!(repo = %repo.path.display(), %error, "tags not fetched");
            }
        }
        let tags = self.tags(repo).await?;
        let (releases, problem) = match self.host(repo).await {
            Host::None => (merge(&tags, Vec::new(), |_| String::new()), None),
            Host::Problem(client, target, problem) => (
                merge(&tags, Vec::new(), |t| client.tag_url(&target, t)),
                Some(problem),
            ),
            Host::TagsOnly(client, target) => (
                merge(&tags, Vec::new(), |t| client.tag_url(&target, t)),
                None,
            ),
            Host::Releases(client, target, token) => {
                let (c, t) = (Arc::clone(&client), target.clone());
                match blocking(move || c.list(&t, &token, HOST_LIMIT)).await? {
                    Ok(found) => (merge(&tags, found, |t| client.tag_url(&target, t)), None),
                    Err(problem) => (
                        merge(&tags, Vec::new(), |t| client.tag_url(&target, t)),
                        Some(problem),
                    ),
                }
            }
        };
        Ok((releases, problem))
    }

    async fn tags(&self, repo: &Repo) -> Result<Vec<GitTag>, PipelinesError> {
        let (git, path) = (Arc::clone(&self.ports.git), repo.path.clone());
        blocking(move || git.tags(&path))
            .await?
            .map_err(|e| PipelinesError::Invalid(format!("Can't read tags: {e}")))
    }

    async fn host(&self, repo: &Repo) -> Host {
        let Some(remote) = repo.remote.as_ref() else {
            return Host::None;
        };
        let Some(host) = CiHost::for_remote(remote) else {
            return Host::None;
        };
        let Some(client) = self
            .ports
            .clients
            .iter()
            .find(|c| c.provider() == host.provider)
            .cloned()
        else {
            return Host::None;
        };
        let target = CiTarget {
            repo: remote.full_name.clone().unwrap_or_default(),
            branch: String::new(),
            host: host.clone(),
        };
        if !client.has_releases() {
            return Host::TagsOnly(client, target);
        }
        match host_token(&self.ports.tokens, &self.ports.fallback, &host).await {
            Some(token) => Host::Releases(client, target, token),
            None => Host::Problem(client, target, CiProblem::of(CiProblemKind::NotConnected)),
        }
    }
}

/// Tags in git's version order, each with its release when the host has
/// one; releases whose tag git doesn't have (drafts, tags not fetched)
/// first, newest first.
fn merge(
    tags: &[GitTag],
    releases: Vec<Release>,
    tag_url: impl Fn(&str) -> String,
) -> Vec<Release> {
    let names: HashSet<&str> = tags.iter().map(|t| t.name.as_str()).collect();
    let (mut untagged, tagged): (Vec<Release>, Vec<Release>) = releases
        .into_iter()
        .partition(|r| !names.contains(r.tag.as_str()));
    untagged.sort_by_key(|r| std::cmp::Reverse(r.time));
    let mut by_tag: HashMap<String, Release> =
        tagged.into_iter().map(|r| (r.tag.clone(), r)).collect();
    let mut out = untagged;
    for tag in tags {
        match by_tag.remove(&tag.name) {
            Some(mut release) => {
                fill_from_tag(&mut release, tag);
                out.push(release);
            }
            None => out.push(Release::of_tag(tag, tag_url(&tag.name))),
        }
    }
    out
}

/// What git knows better than the host: the commit, and what's missing.
fn fill_from_tag(release: &mut Release, tag: &GitTag) {
    release.sha.clone_from(&tag.sha);
    if release.time.is_none() {
        release.time = tag.time;
    }
    if release.author.is_empty() {
        release.author.clone_from(&tag.author);
    }
}

fn lock<T>(m: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    m.lock().unwrap_or_else(PoisonError::into_inner)
}

async fn blocking<T: Send + 'static>(
    f: impl FnOnce() -> T + Send + 'static,
) -> Result<T, PipelinesError> {
    tokio::task::spawn_blocking(f)
        .await
        .map_err(|e| PipelinesError::Invalid(format!("blocking task failed: {e}")))
}
