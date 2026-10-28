/// Contents of a file in a worktree.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct FileContent {
    pub bytes: Vec<u8>,
    pub binary: bool,
    /// Only the first bytes were read.
    pub truncated: bool,
    pub size: u64,
}

/// Files of a worktree (tracked and untracked, not ignored).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct FileList {
    pub paths: Vec<String>,
    pub truncated: bool,
}
