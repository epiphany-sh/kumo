use std::path::PathBuf;

use crate::terminal::TerminalId;
use crate::time::Timestamp;

/// How a worktree runs its tests.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TestCommand {
    /// A shell command, e.g. `cargo test`.
    pub command: String,
    /// Why it was picked, e.g. "Makefile" or "Cargo.toml".
    pub origin: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TestState {
    Running,
    Passed,
    Failed,
    /// Stopped before it finished.
    Stopped,
}

/// One package, crate or file of tests.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SuiteResult {
    pub name: String,
    pub passed: bool,
    pub duration_ms: Option<u64>,
    /// Tests in it, when the runner says.
    pub tests: Option<u32>,
}

/// What a run's output says so far.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct TestSummary {
    pub passed: u32,
    pub failed: u32,
    pub skipped: u32,
    pub suites: Vec<SuiteResult>,
    /// Names of the failing tests.
    pub failures: Vec<String>,
    /// The latest line printed.
    pub last_line: String,
}

/// The latest test run of a worktree.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TestRun {
    pub worktree: PathBuf,
    pub command: String,
    pub terminal: TerminalId,
    pub state: TestState,
    pub exit_code: Option<i32>,
    pub started_at: Timestamp,
    pub finished_at: Option<Timestamp>,
    pub summary: TestSummary,
}

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum TestError {
    #[error("not a worktree of the workspace: {0}")]
    UnknownWorktree(PathBuf),
    #[error("no test command found; type the one this project uses")]
    NoCommand,
    #[error("no test run in {0}")]
    NoRun(PathBuf),
    #[error("couldn't start the tests: {0}")]
    Launch(String),
}
