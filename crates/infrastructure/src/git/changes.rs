//! [`GitChanges`] for [`GitCli`]: status, diffs and actions on a worktree.

use std::ffi::OsString;
use std::path::{Path, PathBuf};

use kumo_domain::changes::{
    ChangeKind, ChangesError, CommitInfo, CommitOptions, DiffLine, DiffLineKind, DiffScope,
    FileChange, FileDiff, FileList, GitChanges, RelativePath, WorktreeChanges,
};

use super::GitCli;

/// Enough context lines for git to print the whole file in one hunk.
const WHOLE_FILE: &str = "--unified=1000000";
/// Untracked files bigger than this are not opened to count their lines.
const MAX_COUNTED_BYTES: u64 = 1024 * 1024;

impl GitCli {
    fn git<I, S>(&self, worktree: &Path, args: I) -> Result<String, ChangesError>
    where
        I: IntoIterator<Item = S>,
        S: AsRef<std::ffi::OsStr>,
    {
        self.exec(worktree, args).map_err(ChangesError::Git)
    }

    /// `args -- paths`.
    fn git_paths(
        &self,
        worktree: &Path,
        args: &[&str],
        paths: &[RelativePath],
    ) -> Result<String, ChangesError> {
        let mut all: Vec<OsString> = args.iter().map(OsString::from).collect();
        all.push("--".into());
        all.extend(paths.iter().map(|p| OsString::from(p.to_string())));
        self.git(worktree, all)
    }

    fn has_head(&self, worktree: &Path) -> bool {
        self.exec(worktree, ["rev-parse", "--verify", "--quiet", "HEAD"])
            .is_ok()
    }

    /// The branch committed changes are measured against: the remote's
    /// default branch when known, else the usual names.
    fn base_ref(&self, worktree: &Path, branch: Option<&str>) -> Option<String> {
        let remote_head = self
            .exec(
                worktree,
                [
                    "symbolic-ref",
                    "--quiet",
                    "--short",
                    "refs/remotes/origin/HEAD",
                ],
            )
            .ok()
            .map(|s| s.trim().to_owned());
        let candidates = remote_head
            .into_iter()
            .chain(["origin/main", "origin/master", "main", "master"].map(String::from));
        candidates.filter(|c| Some(c.as_str()) != branch).find(|c| {
            self.exec(
                worktree,
                [
                    "rev-parse",
                    "--verify",
                    "--quiet",
                    &format!("{c}^{{commit}}"),
                ],
            )
            .is_ok()
        })
    }

    fn merge_base(&self, worktree: &Path, base: &str) -> Option<String> {
        self.exec(worktree, ["merge-base", "HEAD", base])
            .ok()
            .map(|s| s.trim().to_owned())
    }

    fn read_lines(
        &self,
        worktree: &Path,
        path: &RelativePath,
        kind: DiffLineKind,
    ) -> Result<FileDiff, ChangesError> {
        let bytes = std::fs::read(path.under(worktree))
            .map_err(|e| ChangesError::Io(format!("{path}: {e}")))?;
        Ok(lines_of(&bytes, kind))
    }
}

impl GitChanges for GitCli {
    fn status(&self, worktree: &Path) -> Result<WorktreeChanges, ChangesError> {
        let raw = self.git(
            worktree,
            [
                "status",
                "--porcelain=v2",
                "--branch",
                "--untracked-files=all",
                "-z",
            ],
        )?;
        let mut changes = parse_status(&raw);
        if self.has_head(worktree) {
            let numstat = self.git(worktree, ["diff", "-z", "--numstat", "HEAD"])?;
            apply_numstat(&mut changes.working, &numstat);
        }
        for change in changes
            .working
            .iter_mut()
            .filter(|c| c.unstaged == ChangeKind::Untracked)
        {
            count_untracked(worktree, change);
        }
        if let Some(base) = self.base_ref(worktree, changes.branch.as_deref())
            && let Some(merge_base) = self.merge_base(worktree, &base)
        {
            let names = self.git(
                worktree,
                ["diff", "-z", "--name-status", "-M", &merge_base, "HEAD"],
            )?;
            let mut committed = parse_name_status(&names);
            let numstat = self.git(
                worktree,
                ["diff", "-z", "--numstat", "-M", &merge_base, "HEAD"],
            )?;
            apply_numstat(&mut committed, &numstat);
            changes.committed = committed;
            changes.base = Some(base);
        }
        Ok(changes)
    }

    fn list_files(&self, worktree: &Path, limit: usize) -> Result<FileList, ChangesError> {
        let raw = self.git(
            worktree,
            [
                "ls-files",
                "-z",
                "--cached",
                "--others",
                "--exclude-standard",
                "--deduplicate",
            ],
        )?;
        let mut paths: Vec<String> = raw
            .split('\0')
            .filter(|p| !p.is_empty())
            .map(str::to_owned)
            .collect();
        let truncated = paths.len() > limit;
        paths.truncate(limit);
        Ok(FileList { paths, truncated })
    }

    fn diff(
        &self,
        worktree: &Path,
        path: &RelativePath,
        scope: DiffScope,
    ) -> Result<FileDiff, ChangesError> {
        let file = path.to_string();
        match scope {
            DiffScope::Working => {
                if !self.has_head(worktree) {
                    return self.read_lines(worktree, path, DiffLineKind::Added);
                }
                let diff = self.git(
                    worktree,
                    [
                        "diff",
                        "--no-color",
                        "--no-ext-diff",
                        WHOLE_FILE,
                        "HEAD",
                        "--",
                        &file,
                    ],
                )?;
                if !diff.trim().is_empty() {
                    return Ok(parse_unified(&diff));
                }
                let untracked = self.git(
                    worktree,
                    ["ls-files", "--others", "--exclude-standard", "--", &file],
                )?;
                let kind = if untracked.trim().is_empty() {
                    DiffLineKind::Context
                } else {
                    DiffLineKind::Added
                };
                self.read_lines(worktree, path, kind)
            }
            DiffScope::Committed => {
                let status = self.git(worktree, ["status", "--porcelain=v2", "--branch", "-z"])?;
                let branch = parse_status(&status).branch;
                let merge_base = self
                    .base_ref(worktree, branch.as_deref())
                    .and_then(|base| self.merge_base(worktree, &base))
                    .ok_or_else(|| {
                        ChangesError::Git("this branch has no base to compare with".into())
                    })?;
                let diff = self.git(
                    worktree,
                    [
                        "diff",
                        "--no-color",
                        "--no-ext-diff",
                        WHOLE_FILE,
                        &merge_base,
                        "HEAD",
                        "--",
                        &file,
                    ],
                )?;
                if !diff.trim().is_empty() {
                    return Ok(parse_unified(&diff));
                }
                let shown = self.git(worktree, ["show", &format!("HEAD:{file}")])?;
                Ok(lines_of(shown.as_bytes(), DiffLineKind::Context))
            }
        }
    }

    fn stage(&self, worktree: &Path, paths: &[RelativePath]) -> Result<(), ChangesError> {
        self.git_paths(worktree, &["add", "-A"], paths).map(drop)
    }

    fn unstage(&self, worktree: &Path, paths: &[RelativePath]) -> Result<(), ChangesError> {
        if self.has_head(worktree) {
            self.git_paths(worktree, &["restore", "--staged"], paths)
                .map(drop)
        } else {
            self.git_paths(worktree, &["rm", "--cached", "-q", "-r"], paths)
                .map(drop)
        }
    }

    fn restore(&self, worktree: &Path, paths: &[RelativePath]) -> Result<(), ChangesError> {
        self.git_paths(
            worktree,
            &["restore", "--source=HEAD", "--staged", "--worktree"],
            paths,
        )
        .map(drop)
    }

    fn commit(&self, worktree: &Path, options: &CommitOptions) -> Result<CommitInfo, ChangesError> {
        let message = options.message.trim();
        if message.is_empty() && !options.amend {
            return Err(ChangesError::EmptyMessage);
        }
        if options.all {
            self.git(worktree, ["add", "-A"])?;
        }
        let mut args = vec!["commit", "-q"];
        if options.amend {
            args.push("--amend");
        }
        if message.is_empty() {
            args.push("--no-edit");
        } else {
            args.extend(["-m", message]);
        }
        self.git(worktree, args)?;
        self.log(worktree, 1)?
            .into_iter()
            .next()
            .ok_or_else(|| ChangesError::Git("commit not found".into()))
    }

    fn push(&self, worktree: &Path) -> Result<(), ChangesError> {
        let remote = self
            .exec(
                worktree,
                ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
            )
            .ok()
            .and_then(|u| {
                u.trim()
                    .split_once('/')
                    .map(|(remote, _)| remote.to_owned())
            })
            .unwrap_or_else(|| "origin".to_owned());
        self.git(worktree, ["push", "-q", "--set-upstream", &remote, "HEAD"])
            .map(drop)
    }

    fn undo_last_commit(&self, worktree: &Path) -> Result<(), ChangesError> {
        self.git(worktree, ["reset", "-q", "--soft", "HEAD~1"])
            .map(drop)
    }

    fn log(&self, worktree: &Path, limit: usize) -> Result<Vec<CommitInfo>, ChangesError> {
        if !self.has_head(worktree) {
            return Ok(Vec::new());
        }
        let raw = self.git(
            worktree,
            [
                "log",
                &format!("-n{limit}"),
                "--format=%H%x1f%h%x1f%s%x1f%an%x1f%at%x1e",
            ],
        )?;
        Ok(parse_log(&raw))
    }

    fn watched_paths(&self, worktree: &Path) -> Result<Vec<PathBuf>, ChangesError> {
        let git_dir = PathBuf::from(
            self.git(worktree, ["rev-parse", "--absolute-git-dir"])?
                .trim(),
        );
        let mut paths = vec![worktree.to_path_buf()];
        if !git_dir.starts_with(worktree) {
            paths.push(git_dir); // linked worktree: its index and HEAD live there
        }
        Ok(paths)
    }
}

// ---------------------------------------------------------------------------
// Parsers
// ---------------------------------------------------------------------------

fn kind(c: char) -> ChangeKind {
    if c == '.' {
        ChangeKind::None
    } else {
        ChangeKind::from_git(c)
    }
}

/// `git status --porcelain=v2 --branch -z`.
fn parse_status(raw: &str) -> WorktreeChanges {
    let mut changes = WorktreeChanges::default();
    let mut tokens = raw.split('\0').filter(|t| !t.is_empty());
    while let Some(token) = tokens.next() {
        if let Some(header) = token.strip_prefix("# ") {
            let (key, value) = header.split_once(' ').unwrap_or((header, ""));
            match key {
                "branch.head" if value != "(detached)" => changes.branch = Some(value.to_owned()),
                "branch.upstream" => changes.upstream = Some(value.to_owned()),
                "branch.ab" => {
                    for part in value.split_whitespace() {
                        if let Some(n) = part.strip_prefix('+') {
                            changes.ahead = n.parse().unwrap_or(0);
                        } else if let Some(n) = part.strip_prefix('-') {
                            changes.behind = n.parse().unwrap_or(0);
                        }
                    }
                }
                _ => {}
            }
            continue;
        }
        let xy = |token: &str| -> (ChangeKind, ChangeKind) {
            let mut chars = token.split(' ').nth(1).unwrap_or("..").chars();
            (
                kind(chars.next().unwrap_or('.')),
                kind(chars.next().unwrap_or('.')),
            )
        };
        let change = match token.chars().next() {
            Some('1') => {
                let (staged, unstaged) = xy(token);
                token.splitn(9, ' ').nth(8).map(|path| FileChange {
                    path: path.to_owned(),
                    staged,
                    unstaged,
                    ..Default::default()
                })
            }
            Some('2') => {
                let (staged, unstaged) = xy(token);
                let old_path = tokens.next().map(str::to_owned);
                token.splitn(10, ' ').nth(9).map(|path| FileChange {
                    path: path.to_owned(),
                    old_path,
                    staged,
                    unstaged,
                    ..Default::default()
                })
            }
            Some('u') => token.splitn(11, ' ').nth(10).map(|path| FileChange {
                path: path.to_owned(),
                staged: ChangeKind::Modified,
                unstaged: ChangeKind::Modified,
                conflict: true,
                ..Default::default()
            }),
            Some('?') => Some(FileChange {
                path: token[2..].to_owned(),
                unstaged: ChangeKind::Untracked,
                ..Default::default()
            }),
            _ => None,
        };
        changes.working.extend(change);
    }
    changes
}

/// `git diff -z --name-status`: committed changes (all "staged").
fn parse_name_status(raw: &str) -> Vec<FileChange> {
    let mut changes = Vec::new();
    let mut tokens = raw.split('\0').filter(|t| !t.is_empty());
    while let Some(status) = tokens.next() {
        let letter = status.chars().next().unwrap_or('M');
        let (old_path, path) = if matches!(letter, 'R' | 'C') {
            (tokens.next().map(str::to_owned), tokens.next())
        } else {
            (None, tokens.next())
        };
        if let Some(path) = path {
            changes.push(FileChange {
                path: path.to_owned(),
                old_path,
                staged: ChangeKind::from_git(letter),
                ..Default::default()
            });
        }
    }
    changes
}

/// Adds line counts from `git diff -z --numstat` (`-` means binary).
fn apply_numstat(changes: &mut [FileChange], raw: &str) {
    let mut tokens = raw.split('\0');
    while let Some(token) = tokens.next() {
        let mut fields = token.splitn(3, '\t');
        let (Some(added), Some(deleted), Some(path)) =
            (fields.next(), fields.next(), fields.next())
        else {
            continue;
        };
        // Renames: empty path, then old and new as separate tokens.
        let path = if path.is_empty() {
            tokens.next();
            tokens.next().unwrap_or_default()
        } else {
            path
        };
        if let Some(change) = changes.iter_mut().find(|c| c.path == path) {
            change.binary = added == "-";
            change.additions = added.parse().unwrap_or(0);
            change.deletions = deleted.parse().unwrap_or(0);
        }
    }
}

fn count_untracked(worktree: &Path, change: &mut FileChange) {
    let path = worktree.join(&change.path);
    if std::fs::metadata(&path).is_ok_and(|m| m.len() <= MAX_COUNTED_BYTES)
        && let Ok(bytes) = std::fs::read(&path)
    {
        let diff = lines_of(&bytes, DiffLineKind::Added);
        change.binary = diff.binary;
        change.additions = u32::try_from(diff.lines.len()).unwrap_or(u32::MAX);
    }
}

/// A file's lines, all of one kind. Binary files have none.
fn lines_of(bytes: &[u8], kind: DiffLineKind) -> FileDiff {
    if bytes.iter().take(8000).any(|b| *b == 0) {
        return FileDiff {
            lines: Vec::new(),
            binary: true,
        };
    }
    let text = String::from_utf8_lossy(bytes);
    let lines = text
        .lines()
        .map(|l| DiffLine {
            kind,
            text: l.to_owned(),
        })
        .collect();
    FileDiff {
        lines,
        binary: false,
    }
}

/// A unified diff (whole-file context) into lines.
fn parse_unified(raw: &str) -> FileDiff {
    let mut lines = Vec::new();
    let mut in_hunk = false;
    for line in raw.lines() {
        if line.starts_with("@@") {
            in_hunk = true;
            continue;
        }
        if !in_hunk {
            if line.starts_with("Binary files") {
                return FileDiff {
                    lines: Vec::new(),
                    binary: true,
                };
            }
            continue;
        }
        let (kind, text) = match line.chars().next() {
            Some('+') => (DiffLineKind::Added, &line[1..]),
            Some('-') => (DiffLineKind::Deleted, &line[1..]),
            Some(' ') => (DiffLineKind::Context, &line[1..]),
            Some('\\') => continue, // "\ No newline at end of file"
            None => (DiffLineKind::Context, ""),
            Some(_) => continue,
        };
        lines.push(DiffLine {
            kind,
            text: text.to_owned(),
        });
    }
    FileDiff {
        lines,
        binary: false,
    }
}

fn parse_log(raw: &str) -> Vec<CommitInfo> {
    raw.split('\x1e')
        .filter_map(|record| {
            let mut f = record.trim_start_matches('\n').split('\x1f');
            Some(CommitInfo {
                sha: f.next().filter(|s| !s.is_empty())?.to_owned(),
                short_sha: f.next()?.to_owned(),
                subject: f.next()?.to_owned(),
                author: f.next()?.to_owned(),
                time_unix: f.next()?.trim().parse().unwrap_or(0),
            })
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_status_entries_and_tracking() {
        let raw = "# branch.oid abc\0# branch.head feat/x\0# branch.upstream origin/feat/x\0# branch.ab +2 -1\0\
                   1 .M N... 100644 100644 100644 a b src/a.rs\0\
                   1 A. N... 000000 100644 100644 0 b new file.rs\0\
                   2 R. N... 100644 100644 100644 a b R100 src/new.rs\0src/old.rs\0\
                   u UU N... 100644 100644 100644 100644 a b c conflict.txt\0\
                   ? notes.md\0";
        let s = parse_status(raw);
        assert_eq!(
            (
                s.branch.as_deref(),
                s.upstream.as_deref(),
                s.ahead,
                s.behind
            ),
            (Some("feat/x"), Some("origin/feat/x"), 2, 1)
        );
        let summary: Vec<_> = s
            .working
            .iter()
            .map(|c| (c.path.as_str(), c.staged, c.unstaged, c.conflict))
            .collect();
        assert_eq!(
            summary,
            vec![
                ("src/a.rs", ChangeKind::None, ChangeKind::Modified, false),
                ("new file.rs", ChangeKind::Added, ChangeKind::None, false),
                ("src/new.rs", ChangeKind::Renamed, ChangeKind::None, false),
                (
                    "conflict.txt",
                    ChangeKind::Modified,
                    ChangeKind::Modified,
                    true
                ),
                ("notes.md", ChangeKind::None, ChangeKind::Untracked, false),
            ]
        );
        assert_eq!(s.working[2].old_path.as_deref(), Some("src/old.rs"));
    }

    #[test]
    fn detached_head_has_no_branch() {
        assert_eq!(parse_status("# branch.head (detached)\0").branch, None);
    }

    #[test]
    fn numstat_counts_including_renames_and_binaries() {
        let mut changes = vec![
            FileChange {
                path: "a.rs".into(),
                ..Default::default()
            },
            FileChange {
                path: "new.rs".into(),
                ..Default::default()
            },
            FileChange {
                path: "img.png".into(),
                ..Default::default()
            },
        ];
        apply_numstat(
            &mut changes,
            concat!(
                "3\t1\ta.rs\0",
                "2\t0\t\0old.rs\0new.rs\0",
                "-\t-\timg.png\0"
            ),
        );
        assert_eq!((changes[0].additions, changes[0].deletions), (3, 1));
        assert_eq!(changes[1].additions, 2);
        assert!(changes[2].binary);
    }

    #[test]
    fn name_status_with_renames() {
        let changes = parse_name_status("M\0a.rs\0R090\0old.rs\0new.rs\0A\0b.rs\0");
        let paths: Vec<_> = changes
            .iter()
            .map(|c| (c.path.as_str(), c.staged))
            .collect();
        assert_eq!(
            paths,
            vec![
                ("a.rs", ChangeKind::Modified),
                ("new.rs", ChangeKind::Renamed),
                ("b.rs", ChangeKind::Added)
            ]
        );
    }

    #[test]
    fn unified_diff_becomes_whole_file_lines() {
        let raw = "diff --git a/x b/x\nindex 1..2 100644\n--- a/x\n+++ b/x\n@@ -1,3 +1,3 @@\n keep\n-old\n+new\n same\n\\ No newline at end of file\n";
        let kinds: Vec<_> = parse_unified(raw)
            .lines
            .iter()
            .map(|l| (l.kind, l.text.clone()))
            .collect();
        assert_eq!(
            kinds,
            vec![
                (DiffLineKind::Context, "keep".into()),
                (DiffLineKind::Deleted, "old".into()),
                (DiffLineKind::Added, "new".into()),
                (DiffLineKind::Context, "same".into()),
            ]
        );
        assert!(parse_unified("Binary files a/x and b/x differ\n").binary);
    }

    #[test]
    fn parses_log_records() {
        let raw = "abc\x1fab\x1ffeat: x\x1fAna\x1f1700000000\x1e\ndef\x1fde\x1ffix: y\x1fBo\x1f1700000001\x1e\n";
        let log = parse_log(raw);
        assert_eq!(log.len(), 2);
        assert_eq!(
            (
                log[1].short_sha.as_str(),
                log[1].subject.as_str(),
                log[1].time_unix
            ),
            ("de", "fix: y", 1_700_000_001)
        );
    }
}
