//! Ports implemented by the infrastructure layer. They block.

use std::path::{Path, PathBuf};
use std::time::Duration;

use super::{AgentDefKey, AgentDefSettings, FoundFile, PlayRecord};
use crate::agents::AgentError;

/// The agent files and the folders runs work in.
pub trait AgentDefFiles: Send + Sync + 'static {
    /// The `*.md` files directly in `dir` (none when it doesn't exist).
    /// Unreadable ones are skipped and logged.
    fn list(&self, dir: &Path) -> Result<Vec<FoundFile>, AgentError>;
    /// Writes `<dir>/<name>.md` atomically, creating `dir`.
    fn write(&self, dir: &Path, name: &str, markdown: &str) -> Result<FoundFile, AgentError>;
    /// Removes `<dir>/<name>.md`; fine when it's gone already.
    fn remove(&self, dir: &Path, name: &str) -> Result<(), AgentError>;
    /// The folders directly in `dir` (skills).
    fn folders(&self, dir: &Path) -> Vec<String>;
    /// MCP server names: `mcpServers` of Claude Code's config file
    /// (`config`, top level and the projects in `repos`), and each repo's
    /// `.mcp.json`.
    fn mcp_servers(&self, config: &Path, repos: &[PathBuf]) -> Vec<String>;
    /// Creates `dir` (and its parents).
    fn create_dir(&self, dir: &Path) -> Result<(), AgentError>;
    /// Writes a file, creating its folder.
    fn write_file(&self, path: &Path, text: &str) -> Result<(), AgentError>;
    fn exists(&self, path: &Path) -> bool;
    /// Removes `dir` and everything in it; fine when it's gone.
    fn remove_dir(&self, dir: &Path);
    /// Removes the folders in `dir` last changed longer than `age` ago.
    fn sweep(&self, dir: &Path, age: Duration) -> usize;
}

/// Kumo's settings for each agent and its last test runs.
pub trait AgentDefStore: Send + Sync + 'static {
    fn settings(&self) -> Result<Vec<(AgentDefKey, AgentDefSettings)>, AgentError>;
    fn set_settings(
        &self,
        key: &AgentDefKey,
        settings: &AgentDefSettings,
    ) -> Result<(), AgentError>;
    /// Forgets its settings and its test runs.
    fn forget(&self, key: &AgentDefKey) -> Result<(), AgentError>;
    /// Moves settings and test runs to another key (a rename or a move).
    fn rekey(&self, from: &AgentDefKey, to: &AgentDefKey) -> Result<(), AgentError>;
    /// Saves a test run, keeping the newest `keep` of the agent.
    fn save_play(
        &self,
        key: &AgentDefKey,
        play: &PlayRecord,
        keep: usize,
    ) -> Result<(), AgentError>;
    /// Newest first.
    fn plays(&self, key: &AgentDefKey) -> Result<Vec<PlayRecord>, AgentError>;
}

/// What a headless program is started with.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HeadlessSpec {
    pub program: PathBuf,
    pub args: Vec<String>,
    pub cwd: PathBuf,
    pub env: Vec<(String, String)>,
}

/// Stops a headless program from another thread.
pub trait HeadlessKiller: Send + Sync {
    fn kill(&self);
}

/// A headless program running: its stdout lines and how to stop it.
pub struct HeadlessProcess {
    /// Blocks for the next stdout line; None at the end.
    pub lines: Box<dyn Iterator<Item = String> + Send>,
    pub killer: Box<dyn HeadlessKiller>,
    /// Blocks until it exits: its code (or -1), and the end of stderr.
    pub wait: Box<dyn FnOnce() -> (i32, String) + Send>,
}

impl std::fmt::Debug for HeadlessProcess {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("HeadlessProcess").finish_non_exhaustive()
    }
}

/// Runs a program with no terminal, its output read as lines.
pub trait HeadlessRunner: Send + Sync + 'static {
    fn start(&self, spec: &HeadlessSpec) -> Result<HeadlessProcess, AgentError>;
    /// Whether `program --help` mentions `flag`.
    /// Whether `program --help` lists `flag`; None when it couldn't tell.
    fn has_flag(&self, program: &Path, flag: &str, env: &[(String, String)]) -> Option<bool>;
}

/// A web page, read once as text.
pub trait PageReader: Send + Sync + 'static {
    fn read(&self, url: &str) -> Result<String, String>;
}

/// What git does for runs: clone a linked repository, bring a pull
/// request's head, diff it, and throwaway worktrees.
pub trait RunGit: Send + Sync + 'static {
    /// `git clone <url> <dest>`.
    fn clone_repo(&self, url: &str, dest: &Path) -> Result<(), String>;
    /// Fetches `reference` from origin; the commit it points at.
    fn fetch(&self, repo: &Path, reference: &str) -> Result<String, String>;
    /// Brings `origin/<branch>` up to date with the host.
    fn update_branch(&self, repo: &Path, branch: &str) -> Result<(), String>;
    /// The URL of origin, as configured.
    fn origin_url(&self, repo: &Path) -> Result<String, String>;
    /// `git diff <base>...<head>`.
    fn diff(&self, repo: &Path, base: &str, head: &str) -> Result<String, String>;
    /// `git worktree add --detach <path> <rev>`.
    fn add_detached(&self, repo: &Path, path: &Path, rev: &str) -> Result<(), String>;
    /// Removes a worktree, changes and all.
    fn remove_worktree(&self, repo: &Path, path: &Path) -> Result<(), String>;
    /// The branch origin's HEAD points at (main, master…).
    fn default_branch(&self, repo: &Path) -> Result<String, String>;
}
