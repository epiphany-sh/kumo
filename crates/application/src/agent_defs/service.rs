use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, OnceLock, PoisonError};
use std::time::Duration;

use kumo_domain::agent_defs::{
    AgentDefFile, AgentDefFiles, AgentDefKey, AgentDefScope, AgentDefSettings, AgentDefStore,
    HeadlessRunner, PageReader, RunGit, agents_dir, check_agent_name,
};
use kumo_domain::agents::AgentError;

use super::play::LivePlay;
use super::sources::RunSources;
use crate::agents::AgentService;
use crate::workspace::WorkspaceService;

/// The provider your agents run with: only Claude Code has subagents.
pub(super) const CLAUDE: &str = "claude";

#[derive(Clone)]
pub struct AgentDefPorts {
    pub files: Arc<dyn AgentDefFiles>,
    pub store: Arc<dyn AgentDefStore>,
    pub headless: Arc<dyn HeadlessRunner>,
    pub pages: Arc<dyn PageReader>,
    pub git: Arc<dyn RunGit>,
    pub sources: Arc<dyn RunSources>,
}

impl std::fmt::Debug for AgentDefPorts {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("AgentDefPorts").finish_non_exhaustive()
    }
}

/// Where a profile keeps what your agents need.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AgentDefPlaces {
    /// Claude Code's folder for the profile (`CLAUDE_CONFIG_DIR`, or
    /// `~/.claude`): personal agents and skills.
    pub claude_dir: PathBuf,
    /// Claude Code's config file (`.claude.json`): its MCP servers.
    pub claude_config: PathBuf,
    /// The profile's folder: `runs/`, `scratch/`, `clones/`, `plays/`.
    pub data_dir: PathBuf,
}

/// Skills and MCP servers an agent can be given.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct AgentDefCapabilities {
    pub skills: Vec<String>,
    pub mcp_servers: Vec<String>,
    pub triggers_supported: bool,
}

/// Your agents: their files, Kumo's settings for them, their runs and their
/// test runs.
#[derive(Debug)]
pub struct AgentDefService {
    pub(super) ports: AgentDefPorts,
    pub(super) places: AgentDefPlaces,
    pub(super) agents: Arc<AgentService>,
    pub(super) workspace: Arc<WorkspaceService>,
    pub(super) plays: Mutex<HashMap<String, LivePlay>>,
    /// Whether the installed Claude Code takes `--max-budget-usd`.
    pub(super) budget_flag: OnceLock<bool>,
    /// How long a minute of the time limits lasts (shorter in tests).
    pub(super) minute: Duration,
}

impl AgentDefService {
    pub fn new(
        ports: AgentDefPorts,
        places: AgentDefPlaces,
        agents: Arc<AgentService>,
        workspace: Arc<WorkspaceService>,
    ) -> Self {
        Self {
            ports,
            places,
            agents,
            workspace,
            plays: Mutex::default(),
            budget_flag: OnceLock::new(),
            minute: Duration::from_secs(60),
        }
    }

    /// Time limits count minutes of `minute` (tests).
    #[must_use]
    pub fn with_minute(mut self, minute: Duration) -> Self {
        self.minute = minute;
        self
    }

    /// `minutes` of time limit.
    pub(super) fn minutes(&self, minutes: u32) -> Duration {
        self.minute * minutes
    }

    /// The workspace's repositories: main checkout and name.
    pub(super) fn repos(&self) -> Vec<(PathBuf, String)> {
        let snapshot = self.workspace.watch().borrow().clone();
        snapshot
            .repos
            .iter()
            .map(|r| (r.repo.path.clone(), r.repo.name.clone()))
            .collect()
    }

    /// The folder of `file`'s scope, its repository checked against the
    /// workspace.
    fn dir_of(&self, file: &AgentDefFile) -> Result<PathBuf, AgentError> {
        let repo = match file.scope {
            AgentDefScope::Personal => None,
            AgentDefScope::Project => {
                let wanted = file.repo_path.as_deref().ok_or_else(|| {
                    AgentError::Invalid("a project agent needs its repository".into())
                })?;
                let known = self.repos().into_iter().any(|(path, _)| path == wanted);
                if !known {
                    return Err(AgentError::Invalid(format!(
                        "{} isn't a repository of the workspace",
                        wanted.display()
                    )));
                }
                Some(wanted.to_owned())
            }
        };
        agents_dir(file.scope, &self.places.claude_dir, repo.as_deref())
            .ok_or_else(|| AgentError::Invalid("no folder for this agent".into()))
    }

    /// Every agent file: personal, then each repository's.
    pub async fn list(&self) -> Result<Vec<AgentDefFile>, AgentError> {
        let mut folders = vec![(
            AgentDefScope::Personal,
            None,
            String::new(),
            self.places.claude_dir.join("agents"),
        )];
        for (path, name) in self.repos() {
            let dir = path.join(".claude").join("agents");
            folders.push((AgentDefScope::Project, Some(path), name, dir));
        }
        let (files, store) = (Arc::clone(&self.ports.files), Arc::clone(&self.ports.store));
        blocking(move || {
            let settings: HashMap<AgentDefKey, AgentDefSettings> =
                store.settings()?.into_iter().collect();
            let mut out = Vec::new();
            for (scope, repo_path, repo_name, dir) in folders {
                let found = match files.list(&dir) {
                    Ok(found) => found,
                    Err(error) => {
                        tracing::warn!(dir = %dir.display(), %error, "agents folder skipped");
                        continue;
                    }
                };
                for file in found {
                    let mut agent = AgentDefFile {
                        scope,
                        repo_path: repo_path.clone(),
                        repo_name: repo_name.clone(),
                        name: file.name,
                        markdown: file.markdown,
                        settings: AgentDefSettings::default(),
                        file_path: file.path,
                        modified_unix_ms: file.modified_unix_ms,
                    };
                    agent.settings = settings.get(&agent.key()).cloned().unwrap_or_default();
                    out.push(agent);
                }
            }
            Ok(out)
        })
        .await
    }

    /// Writes `agent`'s file and settings. With `previous` under another
    /// name or scope, the old file goes once the new one is written, and
    /// its settings and test runs follow.
    pub async fn save(
        &self,
        agent: AgentDefFile,
        previous: Option<AgentDefFile>,
    ) -> Result<AgentDefFile, AgentError> {
        check_agent_name(&agent.name)?;
        if agent.markdown.trim().is_empty() {
            return Err(AgentError::Invalid("the agent's file is empty".into()));
        }
        let dir = self.dir_of(&agent)?;
        let old = match &previous {
            Some(previous) => {
                check_agent_name(&previous.name)?;
                Some((
                    self.dir_of(previous)?,
                    previous.key(),
                    previous.name.clone(),
                ))
            }
            None => None,
        };
        let (files, store) = (Arc::clone(&self.ports.files), Arc::clone(&self.ports.store));
        let mut saved = agent;
        blocking(move || {
            let written = files.write(&dir, &saved.name, &saved.markdown)?;
            let key = saved.key();
            if let Some((old_dir, old_key, old_name)) = old
                && old_key != key
            {
                files.remove(&old_dir, &old_name)?;
                store.rekey(&old_key, &key)?;
            }
            store.set_settings(&key, &saved.settings)?;
            saved.file_path = written.path;
            saved.modified_unix_ms = written.modified_unix_ms;
            saved.markdown = written.markdown;
            Ok(saved)
        })
        .await
    }

    /// Removes the file, its settings and its test runs.
    pub async fn delete(&self, agent: AgentDefFile) -> Result<(), AgentError> {
        check_agent_name(&agent.name)?;
        let dir = self.dir_of(&agent)?;
        let (files, store) = (Arc::clone(&self.ports.files), Arc::clone(&self.ports.store));
        blocking(move || {
            files.remove(&dir, &agent.name)?;
            store.forget(&agent.key())
        })
        .await
    }

    /// Skills (personal and each repository's) and MCP servers.
    pub async fn capabilities(&self) -> Result<AgentDefCapabilities, AgentError> {
        let repos: Vec<PathBuf> = self.repos().into_iter().map(|(p, _)| p).collect();
        let files = Arc::clone(&self.ports.files);
        let places = self.places.clone();
        blocking(move || {
            let mut skills = files.folders(&places.claude_dir.join("skills"));
            for repo in &repos {
                skills.extend(files.folders(&repo.join(".claude").join("skills")));
            }
            skills.sort();
            skills.dedup();
            Ok(AgentDefCapabilities {
                skills,
                mcp_servers: files.mcp_servers(&places.claude_config, &repos),
                triggers_supported: false,
            })
        })
        .await
    }

    /// The main checkout of the workspace repository `path` is in (a
    /// worktree or the checkout itself).
    pub(super) fn repo_of(&self, path: &Path) -> Option<PathBuf> {
        let snapshot = self.workspace.watch().borrow().clone();
        snapshot
            .repos
            .iter()
            .find(|r| r.repo.path == path || r.worktrees.iter().any(|w| w.path == path))
            .map(|r| r.repo.path.clone())
    }

    pub(super) fn plays_lock(&self) -> std::sync::MutexGuard<'_, HashMap<String, LivePlay>> {
        self.plays.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

pub(super) async fn blocking<T: Send + 'static>(
    f: impl FnOnce() -> Result<T, AgentError> + Send + 'static,
) -> Result<T, AgentError> {
    tokio::task::spawn_blocking(f)
        .await
        .map_err(|e| AgentError::Launch(format!("blocking task failed: {e}")))?
}
