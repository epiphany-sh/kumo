//! Running one of your agents in a terminal of its own: where it works and
//! what it's given.

use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;

use kumo_domain::agent_defs::{
    AgentDefFile, ContextFile, RepoLink, WrittenContext, check_agent_name, context_index,
    file_name, next_free, pull_number, run_args, task_key,
};
use kumo_domain::agents::{AgentContext, AgentError, AgentSession, ContextKind};
use kumo_domain::terminal::TerminalSize;

use super::service::{AgentDefService, CLAUDE, blocking};
use crate::agents::AgentLaunch;

/// Run and scratch folders are removed after this long.
const KEEP_FOLDERS: Duration = Duration::from_secs(7 * 24 * 3600);

/// Where a run works.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RunWhere {
    /// A worktree of the workspace.
    Worktree(PathBuf),
    /// A new worktree of this repository (its main checkout), from its
    /// default branch.
    NewWorktree(PathBuf),
    /// A repository, branch or pull/merge request link.
    Link(String),
    /// Any existing folder.
    Folder(PathBuf),
    /// An empty folder Kumo makes.
    Scratch,
}

/// What a run is started with.
#[derive(Debug, Clone)]
pub struct RunStart {
    pub agent: AgentDefFile,
    /// Set when it isn't found by name where it runs.
    pub inline_json: String,
    pub place: RunWhere,
    pub prompt: String,
    pub context: Vec<AgentContext>,
    pub size: TerminalSize,
}

fn launch_error(error: String) -> AgentError {
    AgentError::Launch(error)
}

fn workspace_error(error: impl std::fmt::Display) -> AgentError {
    AgentError::Launch(error.to_string())
}

impl AgentDefService {
    /// Starts `start.agent` in its own terminal: the session shows with the
    /// others, stopped when its time limit is up.
    pub async fn run(self: &Arc<Self>, start: RunStart) -> Result<AgentSession, AgentError> {
        let name = start.agent.name.clone();
        check_agent_name(&name)?;
        let (files, data) = (Arc::clone(&self.ports.files), self.places.data_dir.clone());
        blocking(move || {
            files.sweep(&data.join("runs"), KEEP_FOLDERS);
            files.sweep(&data.join("scratch"), KEEP_FOLDERS);
            Ok(())
        })
        .await?;

        let (cwd, repo) = self.place(&name, &start.place).await?;
        let context_dir = if start.context.is_empty() {
            None
        } else {
            let runs = self.places.data_dir.join("runs");
            let files = Arc::clone(&self.ports.files);
            let dir = runs.join(next_free(&name, |n| files.exists(&runs.join(n))));
            self.write_context(&start.context, repo.as_deref(), &cwd, &dir)
                .await?;
            Some(dir)
        };
        let runs_before = self
            .agents
            .sessions()
            .iter()
            .filter(|s| s.agent_name.as_deref() == Some(name.as_str()))
            .count();
        let title = if start.prompt.trim().is_empty() {
            format!("Run {}", runs_before + 1)
        } else {
            String::new()
        };
        let args = run_args(
            &name,
            &start.inline_json,
            context_dir.as_deref(),
            &start.prompt,
        );
        self.agents
            .launch(AgentLaunch {
                provider_id: Some(CLAUDE.to_owned()),
                cwd,
                prompt: start.prompt.trim().to_owned(),
                title,
                context: start.context,
                size: start.size,
                args: Some(args),
                agent_name: Some(name),
                context_dir,
                time_limit: start
                    .agent
                    .settings
                    .max_minutes
                    .filter(|m| *m > 0)
                    .map(|m| self.minutes(m)),
            })
            .await
    }

    /// The folder a run works in, and the workspace repository it belongs
    /// to (for its context), if any.
    async fn place(
        &self,
        name: &str,
        place: &RunWhere,
    ) -> Result<(PathBuf, Option<PathBuf>), AgentError> {
        match place {
            RunWhere::Worktree(path) => {
                let path = self
                    .workspace
                    .known_worktree(path)
                    .await
                    .ok_or_else(|| AgentError::UnknownWorktree(path.clone()))?;
                let repo = self.repo_of(&path);
                Ok((path, repo))
            }
            RunWhere::NewWorktree(repo) => {
                if !self.repos().iter().any(|(path, _)| path == repo) {
                    return Err(AgentError::Invalid(format!(
                        "{} isn't a repository of the workspace",
                        repo.display()
                    )));
                }
                let path = self.new_worktree(repo, name).await?;
                Ok((path, Some(repo.clone())))
            }
            RunWhere::Link(url) => self.linked(url).await,
            RunWhere::Folder(path) => {
                if !self.ports.files.exists(path) {
                    return Err(AgentError::Invalid(format!(
                        "{} doesn't exist",
                        path.display()
                    )));
                }
                let repo = self.repo_of(path);
                Ok((path.clone(), repo))
            }
            RunWhere::Scratch => {
                let scratch = self.places.data_dir.join("scratch");
                let files = Arc::clone(&self.ports.files);
                let dir = scratch.join(next_free(name, |n| files.exists(&scratch.join(n))));
                files.create_dir(&dir)?;
                Ok((dir, None))
            }
        }
    }

    /// `<name>-<n>` on a new branch of the same name, from the default
    /// branch (origin's when there is one).
    async fn new_worktree(&self, repo: &Path, name: &str) -> Result<PathBuf, AgentError> {
        let branches = self
            .workspace
            .branches(repo)
            .await
            .map_err(workspace_error)?;
        let git = Arc::clone(&self.ports.git);
        let at = repo.to_owned();
        let default = blocking(move || git.default_branch(&at).map_err(launch_error)).await?;
        let origin = format!("origin/{default}");
        let base = if branches.remote.contains(&origin) {
            origin
        } else {
            default
        };
        let taken: HashSet<&String> = branches.local.iter().collect();
        let branch = next_free(name, |b| taken.contains(&b.to_owned()));
        let worktree = self
            .workspace
            .create_worktree(repo, &branch, true, Some(base), "")
            .await
            .map_err(workspace_error)?;
        Ok(worktree.path)
    }

    /// A link's folder: the workspace's repository when it has it (on the
    /// pull request's or the branch's worktree), else a clone of Kumo's.
    async fn linked(&self, url: &str) -> Result<(PathBuf, Option<PathBuf>), AgentError> {
        let link = RepoLink::parse(url).ok_or_else(|| {
            AgentError::Invalid(format!(
                "“{url}” isn't a repository, branch or pull request link"
            ))
        })?;
        let snapshot = self.workspace.watch().borrow().clone();
        let known = snapshot.repos.iter().find(|r| {
            r.repo
                .remote
                .as_ref()
                .is_some_and(|remote| link.same_repo(&remote.url))
        });
        let Some(state) = known else {
            return Ok((self.cloned(&link).await?, None));
        };
        let repo = state.repo.path.clone();
        let on_branch = |branch: &str| {
            state
                .worktrees
                .iter()
                .find(|w| w.branch.as_deref() == Some(branch))
                .map(|w| w.path.clone())
        };
        let fetch = |reference: String| {
            let (git, at) = (Arc::clone(&self.ports.git), repo.clone());
            blocking(move || git.fetch(&at, &reference).map_err(launch_error))
        };
        if let Some(number) = link.number {
            let head = self
                .ports
                .sources
                .pull_request(&repo, number)
                .await
                .ok()
                .map(|pr| pr.head);
            let sha = fetch(link.head_ref().unwrap_or_default()).await?;
            // A branch of that name is this pull request's only if it's at
            // its head: a fork's may be called `main`, a local one be behind.
            let at_head = |branch: &str| {
                state
                    .worktrees
                    .iter()
                    .find(|w| {
                        w.branch.as_deref() == Some(branch)
                            && !w.head.is_empty()
                            && sha.starts_with(&w.head)
                    })
                    .map(|w| w.path.clone())
            };
            let fallback = format!("pr-{number}");
            if let Some(path) = head
                .as_deref()
                .and_then(at_head)
                .or_else(|| at_head(&fallback))
            {
                return Ok((path, Some(repo)));
            }
            let branches = self
                .workspace
                .branches(&repo)
                .await
                .map_err(workspace_error)?;
            let taken = |name: &str| branches.local.iter().any(|b| b == name);
            let name = head.filter(|h| !taken(h)).unwrap_or(fallback);
            let name = if taken(&name) {
                next_free(&name, taken)
            } else {
                name
            };
            let worktree = self
                .workspace
                .create_worktree(&repo, &name, true, Some(sha), "")
                .await
                .map_err(workspace_error)?;
            return Ok((worktree.path, Some(repo)));
        }
        let (branch, reference) = match link.branch.as_str() {
            "" => return Ok((repo.clone(), Some(repo))),
            branch => {
                if let Some(path) = on_branch(branch) {
                    return Ok((path, Some(repo)));
                }
                (branch.to_owned(), branch.to_owned())
            }
        };
        let sha = fetch(reference).await?;
        let branches = self
            .workspace
            .branches(&repo)
            .await
            .map_err(workspace_error)?;
        let exists = branches.local.contains(&branch);
        let worktree = self
            .workspace
            .create_worktree(&repo, &branch, !exists, (!exists).then_some(sha), "")
            .await
            .map_err(workspace_error)?;
        Ok((worktree.path, Some(repo)))
    }

    /// `<data>/clones/<host>/<path>`, cloned the first time; a pull
    /// request or branch gets a detached worktree of it next to it.
    async fn cloned(&self, link: &RepoLink) -> Result<PathBuf, AgentError> {
        let root = self.places.data_dir.join("clones").join(&link.host);
        let clone = root.join(&link.path);
        let target = match (link.number, link.branch.as_str()) {
            (Some(number), _) => {
                Some((link.head_ref().unwrap_or_default(), format!("pr-{number}")))
            }
            (None, "") => None,
            (None, branch) => Some((
                branch.to_owned(),
                file_name(branch, "x").trim_end_matches(".x").to_owned(),
            )),
        };
        let (git, files) = (Arc::clone(&self.ports.git), Arc::clone(&self.ports.files));
        let url = format!("https://{}/{}.git", link.host, link.path);
        blocking(move || {
            if !files.exists(&clone) {
                git.clone_repo(&url, &clone).map_err(launch_error)?;
            }
            let Some((reference, suffix)) = target else {
                return Ok(clone);
            };
            let sha = git.fetch(&clone, &reference).map_err(launch_error)?;
            let named = |suffix: &str| PathBuf::from(format!("{}@{suffix}", clone.display()));
            // Never over one from before: it may hold an agent's work.
            let mut worktree = named(&suffix);
            if files.exists(&worktree) {
                worktree = named(&next_free(&suffix, |n| files.exists(&named(n))));
            }
            git.add_detached(&clone, &worktree, &sha)
                .map_err(launch_error)?;
            Ok(worktree)
        })
        .await
    }

    /// Writes each item into `dir`, then `context.md` listing them. What
    /// can't be read is said in its line: the run still starts.
    pub(super) async fn write_context(
        &self,
        items: &[AgentContext],
        repo: Option<&Path>,
        cwd: &Path,
        dir: &Path,
    ) -> Result<(), AgentError> {
        let mut written = Vec::new();
        for item in items {
            written.push(self.read_item(item, repo, cwd).await);
        }
        // Two items can't write the same file.
        let mut names = HashSet::new();
        for w in &mut written {
            for f in &mut w.files {
                let original = f.name.clone();
                let (stem, ext) = original.rsplit_once('.').unwrap_or((&original, "txt"));
                let mut n = 2;
                while !names.insert(f.name.clone()) {
                    f.name = format!("{stem}-{n}.{ext}");
                    n += 1;
                }
            }
        }
        let files = Arc::clone(&self.ports.files);
        let dir = dir.to_owned();
        blocking(move || {
            files.create_dir(&dir)?;
            for f in written.iter().flat_map(|w| &w.files) {
                files.write_file(&dir.join(&f.name), &f.text)?;
            }
            files.write_file(&dir.join("context.md"), &context_index(&written))
        })
        .await
    }

    async fn read_item(
        &self,
        item: &AgentContext,
        repo: Option<&Path>,
        cwd: &Path,
    ) -> WrittenContext {
        let mut out = WrittenContext {
            item: item.clone(),
            files: Vec::new(),
            problem: None,
        };
        let result: Result<Vec<ContextFile>, String> = match item.kind {
            ContextKind::Task => {
                let key = task_key(&item.title);
                self.ports
                    .sources
                    .ticket(&item.id, key)
                    .await
                    .map(|(key, text)| {
                        vec![ContextFile {
                            name: file_name(&key, "md"),
                            text,
                        }]
                    })
            }
            ContextKind::Doc if !item.id.is_empty() => {
                self.ports.sources.doc(&item.id).await.map(|text| {
                    vec![ContextFile {
                        name: file_name(&item.title, "md"),
                        text,
                    }]
                })
            }
            ContextKind::Doc | ContextKind::Link if !item.url.is_empty() => {
                let (pages, url) = (Arc::clone(&self.ports.pages), item.url.clone());
                let read = blocking(move || Ok(pages.read(&url)))
                    .await
                    .unwrap_or_else(|e| Err(e.to_string()));
                read.map(|text| {
                    vec![ContextFile {
                        name: file_name(&item.title, "txt"),
                        text,
                    }]
                })
            }
            ContextKind::Doc | ContextKind::Link => Err("it has no link".to_owned()),
            ContextKind::PullRequest => self.pull_files(item, repo, cwd).await,
            ContextKind::Files => {
                // Nothing copied: where they are.
                let path = Path::new(&item.title);
                let absolute = if path.is_absolute() {
                    path.to_owned()
                } else {
                    cwd.join(path)
                };
                out.item.url = absolute.display().to_string();
                Ok(Vec::new())
            }
            ContextKind::Code => Ok(Vec::new()),
        };
        match result {
            Ok(files) => out.files = files,
            Err(problem) => out.problem = Some(problem),
        }
        out
    }

    /// `pr-<n>.md` (title, description, open threads) and `pr-<n>.diff`
    /// (base...head).
    async fn pull_files(
        &self,
        item: &AgentContext,
        repo: Option<&Path>,
        cwd: &Path,
    ) -> Result<Vec<ContextFile>, String> {
        let number = pull_number(item).ok_or("it has no pull request number")?;
        let link = RepoLink::parse(&item.url);
        let snapshot = self.workspace.watch().borrow().clone();
        let linked_repo = link.as_ref().and_then(|link| {
            snapshot
                .repos
                .iter()
                .find(|r| {
                    r.repo
                        .remote
                        .as_ref()
                        .is_some_and(|remote| link.same_repo(&remote.url))
                })
                .map(|r| r.repo.path.clone())
        });
        // A link says whose pull request it is: never the same number of
        // the repository this runs in.
        let repo = match (&link, linked_repo) {
            (_, Some(linked)) => linked,
            (None, None) => repo
                .map(Path::to_owned)
                .ok_or("its repository isn't in the workspace")?,
            (Some(link), None) => {
                let (git, at) = (Arc::clone(&self.ports.git), cwd.to_owned());
                let origin = blocking(move || git.origin_url(&at).map_err(launch_error))
                    .await
                    .unwrap_or_default();
                if !link.same_repo(&origin) {
                    return Err("its repository isn't in the workspace".to_owned());
                }
                cwd.to_owned()
            }
        };
        let mut files = Vec::new();
        let pr = self.ports.sources.pull_request(&repo, number).await;
        let base = match &pr {
            Ok(pr) => {
                files.push(ContextFile {
                    name: format!("pr-{number}.md"),
                    text: pr.markdown.clone(),
                });
                pr.base.clone()
            }
            Err(_) => String::new(),
        };
        let merge_request = link
            .as_ref()
            .map_or(item.title.starts_with('!'), |l| l.merge_request);
        let reference = if merge_request {
            format!("refs/merge-requests/{number}/head")
        } else {
            format!("refs/pull/{number}/head")
        };
        let git = Arc::clone(&self.ports.git);
        let diff = blocking(move || {
            let sha = git.fetch(&repo, &reference).map_err(launch_error)?;
            let base = if base.is_empty() {
                git.default_branch(&repo).map_err(launch_error)?
            } else {
                base
            };
            git.diff(&repo, &format!("origin/{base}"), &sha)
                .map_err(launch_error)
        })
        .await;
        match (diff, pr) {
            (Ok(diff), _) => files.push(ContextFile {
                name: format!("pr-{number}.diff"),
                text: diff,
            }),
            (Err(e), Ok(_)) => tracing::warn!(number, error = %e, "pull request diff not written"),
            (Err(e), Err(pr)) => return Err(format!("{pr}; its diff: {e}")),
        }
        Ok(files)
    }
}
