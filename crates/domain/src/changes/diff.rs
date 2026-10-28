/// Which change a diff shows.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum DiffScope {
    /// Working tree (staged and not) vs HEAD.
    #[default]
    Working,
    /// HEAD vs the branch base.
    Committed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DiffLineKind {
    Context,
    Added,
    Deleted,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DiffLine {
    pub kind: DiffLineKind,
    pub text: String,
}

/// A whole file with its changes: unchanged lines are context.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct FileDiff {
    pub lines: Vec<DiffLine>,
    pub binary: bool,
}
