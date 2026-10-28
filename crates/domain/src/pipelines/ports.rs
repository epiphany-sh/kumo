use std::path::Path;

use crate::terminal::LaunchSpec;

use super::{CiHost, CiProblem, CiProvider, CiRun, CiTarget, PipelinesError};

/// One CI provider's API. Blocking: callers run it off the async runtime.
/// Tokens never appear in what it returns.
pub trait CiClient: Send + Sync + 'static {
    fn provider(&self) -> CiProvider;

    /// The latest run of the branch, with its jobs; None when it has none.
    fn latest_run(&self, target: &CiTarget, token: &str) -> Result<Option<CiRun>, CiProblem>;

    /// Re-runs the failed jobs of `run` (or the whole run where the
    /// provider can't re-run single jobs).
    fn rerun_failed(&self, target: &CiTarget, token: &str, run: &CiRun) -> Result<(), CiProblem>;

    /// Checks the token: who it signs in as.
    fn test(&self, host: &CiHost, token: &str) -> Result<String, CiProblem>;
}

/// Tokens per host (`github.com`), in the keychain.
pub trait HostTokens: Send + Sync + 'static {
    fn get(&self, host: &str) -> Result<Option<String>, PipelinesError>;
    fn set(&self, host: &str, token: &str) -> Result<(), PipelinesError>;
    fn delete(&self, host: &str) -> Result<(), PipelinesError>;
}

/// A token from somewhere else when none is saved: a CLI the user signs in
/// to (the GitHub CLI).
pub trait TokenFallback: Send + Sync + 'static {
    fn token(&self, host: &CiHost) -> Option<String>;

    /// Who it signs in as on `host` (`ana`), when it can tell.
    fn account(&self, _host: &CiHost) -> Option<String> {
        None
    }

    /// The command that signs it in to `host`, to run in a terminal; None
    /// when it can't (the CLI isn't installed, or doesn't serve this host).
    fn sign_in(&self, _host: &CiHost) -> Option<LaunchSpec> {
        None
    }

    /// Drops what it remembers about `host` (it's being signed in).
    fn forget(&self, _host: &CiHost) {}
}

/// The branch checked out in a worktree, as git sees it locally.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct LocalBranch {
    /// None when HEAD is detached.
    pub name: Option<String>,
    /// `origin/feat/x`; None before the first push.
    pub upstream: Option<String>,
    /// Commits on no remote yet.
    pub unpushed: u32,
}

impl LocalBranch {
    /// The branch name on the remote: the upstream's, else the local one.
    pub fn remote_name(&self) -> Option<&str> {
        match &self.upstream {
            Some(upstream) => upstream.split_once('/').map(|(_, b)| b),
            None => self.name.as_deref(),
        }
    }
}

pub trait BranchReader: Send + Sync + 'static {
    fn read(&self, worktree: &Path) -> Result<LocalBranch, String>;
}
