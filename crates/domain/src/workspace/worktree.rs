use std::path::PathBuf;

use super::BranchName;

/// A checkout of a repository: the main one or a linked `git worktree`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Worktree {
    pub path: PathBuf,
    /// None when HEAD is detached.
    pub branch: Option<String>,
    pub head: String,
    pub is_main: bool,
    pub locked: bool,
    pub status: WorktreeStatus,
}

/// What removing a worktree did.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct WorktreeRemoval {
    /// False when it has changes and removing wasn't forced: it's untouched.
    pub removed: bool,
    /// Files with changes, when that's why it wasn't removed.
    pub changed_files: u32,
    /// Its branch was to go too but stays: why.
    pub branch_kept: Option<String>,
}

/// Working-copy state, from `git status`.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct WorktreeStatus {
    /// Staged, unstaged and untracked files.
    pub changed_files: u32,
    pub ahead: u32,
    pub behind: u32,
    /// e.g. `origin/main`; None if the branch was never pushed.
    pub upstream: Option<String>,
}

/// Branches of a repository.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Branches {
    /// Checked out in the main checkout; None if detached.
    pub current: Option<String>,
    pub local: Vec<String>,
    /// `remote/branch`, without `remote/HEAD` aliases.
    pub remote: Vec<String>,
}

/// What `git worktree add` needs.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NewWorktree {
    pub branch: BranchName,
    /// Create the branch (from [`base`](Self::base)) instead of checking out
    /// an existing one.
    pub create_branch: bool,
    /// Start point for a new branch; None is the repository's HEAD.
    pub base: Option<String>,
    pub path: PathBuf,
}
