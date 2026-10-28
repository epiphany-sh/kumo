use kumo_domain::changes::{
    ChangeKind, CommitInfo, DiffLineKind, DiffScope, FileChange, FileDiff, WorktreeChanges,
};
use kumo_proto::v1 as pb;

pub fn worktree_changes_to(changes: WorktreeChanges) -> pb::WorktreeChanges {
    pb::WorktreeChanges {
        branch: changes.branch.unwrap_or_default(),
        upstream: changes.upstream.unwrap_or_default(),
        ahead: changes.ahead,
        behind: changes.behind,
        working: changes.working.into_iter().map(file_change_to).collect(),
        base: changes.base.unwrap_or_default(),
        committed: changes.committed.into_iter().map(file_change_to).collect(),
    }
}

fn file_change_to(change: FileChange) -> pb::FileChange {
    pb::FileChange {
        path: change.path,
        old_path: change.old_path.unwrap_or_default(),
        staged: change_kind_to(change.staged).into(),
        unstaged: change_kind_to(change.unstaged).into(),
        conflict: change.conflict,
        additions: change.additions,
        deletions: change.deletions,
        binary: change.binary,
    }
}

fn change_kind_to(kind: ChangeKind) -> pb::ChangeKind {
    match kind {
        ChangeKind::None => pb::ChangeKind::None,
        ChangeKind::Modified => pb::ChangeKind::Modified,
        ChangeKind::Added => pb::ChangeKind::Added,
        ChangeKind::Deleted => pb::ChangeKind::Deleted,
        ChangeKind::Renamed => pb::ChangeKind::Renamed,
        ChangeKind::Untracked => pb::ChangeKind::Untracked,
        ChangeKind::TypeChanged => pb::ChangeKind::TypeChanged,
    }
}

pub fn diff_scope_from(scope: pb::DiffScope) -> DiffScope {
    match scope {
        pb::DiffScope::Working => DiffScope::Working,
        pb::DiffScope::Committed => DiffScope::Committed,
    }
}

pub fn diff_to(diff: FileDiff) -> pb::DiffResponse {
    pb::DiffResponse {
        binary: diff.binary,
        lines: diff
            .lines
            .into_iter()
            .map(|line| pb::DiffLine {
                kind: match line.kind {
                    DiffLineKind::Context => pb::DiffLineKind::Context,
                    DiffLineKind::Added => pb::DiffLineKind::Added,
                    DiffLineKind::Deleted => pb::DiffLineKind::Deleted,
                }
                .into(),
                text: line.text,
            })
            .collect(),
    }
}

pub fn commit_to(commit: CommitInfo) -> pb::Commit {
    pb::Commit {
        sha: commit.sha,
        short_sha: commit.short_sha,
        subject: commit.subject,
        author: commit.author,
        time_unix: commit.time_unix,
    }
}
