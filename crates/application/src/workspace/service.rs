use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use kumo_domain::workspace::{
    BranchName, Branches, Git, Namespace, NamespaceId, NewWorktree, Remote, Repo, RepoFinder,
    RepoState, WorkspaceError, WorkspaceSnapshot, WorkspaceStore, Worktree, WorktreeLocation,
};
use tokio::sync::{Mutex, watch};

/// The adapters the service works with.
#[derive(Clone)]
pub struct WorkspacePorts {
    pub git: Arc<dyn Git>,
    pub store: Arc<dyn WorkspaceStore>,
    pub finder: Arc<dyn RepoFinder>,
    pub location: WorktreeLocation,
}

impl std::fmt::Debug for WorkspacePorts {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("WorkspacePorts")
            .field("location", &self.location)
            .finish_non_exhaustive()
    }
}

#[derive(Debug, Default)]
struct State {
    namespaces: Vec<Namespace>,
    repos: BTreeMap<PathBuf, RepoState>,
    version: u64,
}

/// Namespaces, repositories and worktrees. Every change publishes a new
/// [`WorkspaceSnapshot`] to [`watch`](Self::watch) subscribers.
///
/// Mutations are serialized (one lock); git and the store block, so they run
/// on Tokio's blocking pool.
#[derive(Debug)]
pub struct WorkspaceService {
    ports: WorkspacePorts,
    state: Mutex<State>,
    published: watch::Sender<Arc<WorkspaceSnapshot>>,
}

impl WorkspaceService {
    /// Loads namespaces and repositories from the store. Git state is read
    /// by [`refresh`](Self::refresh).
    pub async fn load(ports: WorkspacePorts) -> Result<Self, WorkspaceError> {
        let store = Arc::clone(&ports.store);
        let stored = blocking(move || store.load()).await?;
        let repos = stored
            .repos
            .into_iter()
            .map(|repo| {
                (
                    repo.path.clone(),
                    RepoState {
                        repo,
                        worktrees: Vec::new(),
                        error: None,
                    },
                )
            })
            .collect();
        let state = State {
            namespaces: stored.namespaces,
            repos,
            version: 0,
        };
        let (published, _) = watch::channel(Arc::new(snapshot_of(&state)));
        Ok(Self {
            ports,
            state: Mutex::new(state),
            published,
        })
    }

    /// The current snapshot, and every later one (intermediate ones may be
    /// skipped: last wins).
    pub fn watch(&self) -> watch::Receiver<Arc<WorkspaceSnapshot>> {
        self.published.subscribe()
    }

    /// Re-reads git for every repository in a namespace.
    pub async fn refresh(&self) {
        let mut state = self.state.lock().await;
        let paths = referenced(&state.namespaces);
        let reads = paths
            .into_iter()
            .filter_map(|path| state.repos.get(&path).map(|s| s.repo.clone()))
            .map(|repo| {
                let git = Arc::clone(&self.ports.git);
                tokio::task::spawn_blocking(move || read_repo(git.as_ref(), repo))
            });
        for read in futures::future::join_all(reads.collect::<Vec<_>>())
            .await
            .into_iter()
            .flatten()
        {
            state.repos.insert(read.repo.path.clone(), read);
        }
        self.publish(&mut state);
    }

    /// Creates (`id` None) or replaces a namespace. Paths may point anywhere
    /// inside a repository; unknown repositories are registered.
    pub async fn save_namespace(
        &self,
        id: Option<NamespaceId>,
        name: &str,
        repo_paths: Vec<PathBuf>,
        collapsed: bool,
        position: Option<usize>,
    ) -> Result<NamespaceId, WorkspaceError> {
        let mut state = self.state.lock().await;
        let mut repos = Vec::with_capacity(repo_paths.len());
        for path in repo_paths {
            repos.push(self.register(&mut state, path).await?);
        }
        let namespace = Namespace::new(
            id.unwrap_or_else(NamespaceId::generate),
            name,
            repos,
            collapsed,
        );
        // No position: existing namespaces keep theirs, new ones go last.
        let current = state.namespaces.iter().position(|n| n.id == namespace.id);
        let position = position.or(current).unwrap_or(state.namespaces.len());

        let store = Arc::clone(&self.ports.store);
        let saved = namespace.clone();
        blocking(move || store.save_namespace(&saved, position)).await?;

        state.namespaces.retain(|n| n.id != namespace.id);
        let at = position.min(state.namespaces.len());
        state.namespaces.insert(at, namespace.clone());
        self.publish(&mut state);
        Ok(namespace.id)
    }

    pub async fn delete_namespace(&self, id: &NamespaceId) -> Result<(), WorkspaceError> {
        let mut state = self.state.lock().await;
        if !state.namespaces.iter().any(|n| &n.id == id) {
            return Err(WorkspaceError::NamespaceNotFound(id.to_string()));
        }
        let store = Arc::clone(&self.ports.store);
        let deleted = id.clone();
        blocking(move || store.delete_namespace(&deleted)).await?;
        state.namespaces.retain(|n| &n.id != id);
        self.publish(&mut state);
        Ok(())
    }

    /// `git worktree add`. Returns the new worktree as git reports it.
    pub async fn create_worktree(
        &self,
        repo_path: &Path,
        branch: &str,
        create_branch: bool,
        base: Option<String>,
        requested_path: &str,
    ) -> Result<Worktree, WorkspaceError> {
        let mut state = self.state.lock().await;
        let repo = state
            .repos
            .get(repo_path)
            .ok_or_else(|| WorkspaceError::RepoNotFound(repo_path.into()))?
            .repo
            .clone();
        let branch = BranchName::parse(branch)?;
        let path = self
            .ports
            .location
            .resolve(requested_path, &repo.name, &branch)?;
        let new = NewWorktree {
            branch,
            create_branch,
            base,
            path,
        };

        let git = Arc::clone(&self.ports.git);
        let (added, repo_path) = (new.clone(), repo.path.clone());
        blocking(move || git.add_worktree(&repo_path, &added)).await?;
        tracing::info!(repo = %repo.path.display(), worktree = %new.path.display(), "worktree created");

        let read = self.reread(&mut state, repo).await;
        let created = read
            .worktrees
            .iter()
            .find(|w| same_path(&w.path, &new.path))
            .cloned()
            .ok_or_else(|| WorkspaceError::WorktreeNotFound(new.path.clone()))?;
        self.publish(&mut state);
        Ok(created)
    }

    /// `git worktree remove`; the branch stays.
    pub async fn remove_worktree(
        &self,
        repo_path: &Path,
        worktree: &Path,
        force: bool,
    ) -> Result<(), WorkspaceError> {
        let mut state = self.state.lock().await;
        let repo_state = state
            .repos
            .get(repo_path)
            .ok_or_else(|| WorkspaceError::RepoNotFound(repo_path.into()))?;
        let target = repo_state
            .worktrees
            .iter()
            .find(|w| same_path(&w.path, worktree))
            .ok_or_else(|| WorkspaceError::WorktreeNotFound(worktree.into()))?;
        if target.is_main {
            return Err(WorkspaceError::CannotRemoveMainCheckout);
        }
        let repo = repo_state.repo.clone();
        let git = Arc::clone(&self.ports.git);
        let (repo_path, worktree_path) = (repo.path.clone(), target.path.clone());
        blocking(move || git.remove_worktree(&repo_path, &worktree_path, force)).await?;
        tracing::info!(repo = %repo.path.display(), worktree = %worktree.display(), "worktree removed");

        self.reread(&mut state, repo).await;
        self.publish(&mut state);
        Ok(())
    }

    /// Branches of a repository in the workspace.
    pub async fn branches(&self, repo_path: &Path) -> Result<Branches, WorkspaceError> {
        let repo = {
            let state = self.state.lock().await;
            state
                .repos
                .get(repo_path)
                .ok_or_else(|| WorkspaceError::RepoNotFound(repo_path.into()))?
                .repo
                .path
                .clone()
        };
        let git = Arc::clone(&self.ports.git);
        blocking(move || git.branches(&repo)).await
    }

    /// The canonical path of `path` if it is a worktree of a repository in
    /// the workspace.
    pub async fn known_worktree(&self, path: &Path) -> Option<PathBuf> {
        let state = self.state.lock().await;
        state
            .repos
            .values()
            .flat_map(|r| &r.worktrees)
            .find(|w| same_path(&w.path, path))
            .map(|w| w.path.clone())
    }

    /// Re-reads the repository that owns `worktree` (e.g. after a commit or
    /// files changing on disk). Publishes only if something changed.
    pub async fn refresh_worktree(&self, worktree: &Path) {
        let mut state = self.state.lock().await;
        let Some(owner) = state
            .repos
            .values()
            .find(|r| r.worktrees.iter().any(|w| same_path(&w.path, worktree)))
            .cloned()
        else {
            return;
        };
        let before = owner.clone();
        if *self.reread(&mut state, owner.repo).await != before {
            self.publish(&mut state);
        }
    }

    /// Git repositories under `roots` (or the usual folders), with the
    /// repository each one belongs to. Not added to the workspace.
    pub async fn discover(&self, roots: Vec<PathBuf>) -> Vec<RepoState> {
        let finder = Arc::clone(&self.ports.finder);
        let found = blocking(move || {
            let roots = if roots.is_empty() {
                finder.default_roots()
            } else {
                roots
            };
            Ok(finder.find(&roots))
        })
        .await
        .unwrap_or_default();

        let reads = found.into_iter().map(|path| {
            let git = Arc::clone(&self.ports.git);
            tokio::task::spawn_blocking(move || {
                let main = git.main_checkout(&path).ok()?;
                let remote = git
                    .remote_url(&main)
                    .ok()
                    .flatten()
                    .map(|url| Remote::parse(&url));
                let worktrees = git.worktrees(&main).unwrap_or_default();
                Some(RepoState {
                    repo: Repo::new(main, remote),
                    worktrees,
                    error: None,
                })
            })
        });
        let mut candidates: Vec<RepoState> = Vec::new();
        for candidate in futures::future::join_all(reads.collect::<Vec<_>>())
            .await
            .into_iter()
            .flatten()
            .flatten()
        {
            if !candidates
                .iter()
                .any(|c| c.repo.path == candidate.repo.path)
            {
                candidates.push(candidate);
            }
        }
        candidates.sort_by(|a, b| a.repo.name.cmp(&b.repo.name));
        candidates
    }

    /// The main checkout of the repository at `path`, registering it (and
    /// reading git) if it is new.
    async fn register(&self, state: &mut State, path: PathBuf) -> Result<PathBuf, WorkspaceError> {
        if state.repos.contains_key(&path) {
            return Ok(path);
        }
        let git = Arc::clone(&self.ports.git);
        let repo = blocking(move || {
            let main = git.main_checkout(&path)?;
            let remote = git.remote_url(&main)?.map(|url| Remote::parse(&url));
            Ok(Repo::new(main, remote))
        })
        .await?;
        if state.repos.contains_key(&repo.path) {
            return Ok(repo.path);
        }
        let store = Arc::clone(&self.ports.store);
        let saved = repo.clone();
        blocking(move || store.save_repo(&saved)).await?;
        tracing::info!(repo = %repo.path.display(), "repository registered");
        let path = repo.path.clone();
        self.reread(state, repo).await;
        Ok(path)
    }

    async fn reread<'a>(&self, state: &'a mut State, repo: Repo) -> &'a RepoState {
        let git = Arc::clone(&self.ports.git);
        let path = repo.path.clone();
        let read = tokio::task::spawn_blocking(move || read_repo(git.as_ref(), repo))
            .await
            .unwrap_or_else(|e| unreachable_read(&path, &e));
        state.repos.insert(read.repo.path.clone(), read);
        &state.repos[&path]
    }

    fn publish(&self, state: &mut State) {
        state.version += 1;
        self.published.send_replace(Arc::new(snapshot_of(state)));
    }
}

/// Worktrees and their status. Errors are kept in the state, not raised: a
/// moved repository must not break the whole workspace.
fn read_repo(git: &dyn Git, repo: Repo) -> RepoState {
    match git.worktrees(&repo.path) {
        Ok(mut worktrees) => {
            for worktree in &mut worktrees {
                worktree.status = git.status(&worktree.path).unwrap_or_default();
            }
            RepoState {
                repo,
                worktrees,
                error: None,
            }
        }
        Err(error) => RepoState {
            repo,
            worktrees: Vec::new(),
            error: Some(error.to_string()),
        },
    }
}

fn unreachable_read(path: &Path, error: &tokio::task::JoinError) -> RepoState {
    let repo = Repo::new(path.to_path_buf(), None);
    RepoState {
        repo,
        worktrees: Vec::new(),
        error: Some(format!("git read panicked: {error}")),
    }
}

fn snapshot_of(state: &State) -> WorkspaceSnapshot {
    let repos = referenced(&state.namespaces)
        .iter()
        .filter_map(|path| state.repos.get(path).cloned())
        .collect();
    WorkspaceSnapshot {
        version: state.version,
        namespaces: state.namespaces.clone(),
        repos,
    }
}

/// Repositories referenced by namespaces, first-seen order, no duplicates.
fn referenced(namespaces: &[Namespace]) -> Vec<PathBuf> {
    let mut paths: Vec<PathBuf> = Vec::new();
    for path in namespaces.iter().flat_map(|n| &n.repos) {
        if !paths.contains(path) {
            paths.push(path.clone());
        }
    }
    paths
}

/// Paths as git prints them may differ from the requested ones by symlinks
/// (`/var` vs `/private/var` on macOS).
fn same_path(a: &Path, b: &Path) -> bool {
    a == b
        || std::fs::canonicalize(a)
            .ok()
            .zip(std::fs::canonicalize(b).ok())
            .is_some_and(|(a, b)| a == b)
}

async fn blocking<T: Send + 'static>(
    f: impl FnOnce() -> Result<T, WorkspaceError> + Send + 'static,
) -> Result<T, WorkspaceError> {
    tokio::task::spawn_blocking(f)
        .await
        .map_err(|e| WorkspaceError::Git(format!("blocking task failed: {e}")))?
}
