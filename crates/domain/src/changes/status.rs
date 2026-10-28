/// How a file changed.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash)]
pub enum ChangeKind {
    #[default]
    None,
    Modified,
    Added,
    Deleted,
    Renamed,
    Untracked,
    TypeChanged,
}

impl ChangeKind {
    /// From a `git status --porcelain=v2` / `--name-status` letter.
    pub fn from_git(letter: char) -> Self {
        match letter {
            'M' => Self::Modified,
            'A' | 'C' => Self::Added,
            'D' => Self::Deleted,
            'R' => Self::Renamed,
            'T' => Self::TypeChanged,
            '?' => Self::Untracked,
            _ => Self::None,
        }
    }
}

/// One changed file.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct FileChange {
    /// Relative to the worktree, forward slashes.
    pub path: String,
    /// Renames: the previous path.
    pub old_path: Option<String>,
    /// Index vs HEAD.
    pub staged: ChangeKind,
    /// Working tree vs index.
    pub unstaged: ChangeKind,
    pub conflict: bool,
    pub additions: u32,
    pub deletions: u32,
    pub binary: bool,
}

/// Everything that is changed in a worktree, uncommitted and committed.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct WorktreeChanges {
    /// None when HEAD is detached.
    pub branch: Option<String>,
    pub upstream: Option<String>,
    pub ahead: u32,
    pub behind: u32,
    /// Uncommitted, staged or not.
    pub working: Vec<FileChange>,
    /// The branch the committed changes are measured against.
    pub base: Option<String>,
    /// Committed on this branch since it left [`base`](Self::base).
    pub committed: Vec<FileChange>,
}
