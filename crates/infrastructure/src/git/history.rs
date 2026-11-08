//! History for the Git view: main's log, every branch's commits not on main
//! yet, and what one commit changed.

use std::collections::HashSet;
use std::path::Path;

use kumo_domain::changes::{
    ChangeKind, ChangesError, CommitDetail, CommitFile, CommitInfo, DiffHunk, DiffLine,
    DiffLineKind,
};

use super::GitCli;

/// Branches read besides main: the most recently committed ones.
const MAX_BRANCHES: usize = 30;
/// Files a commit shows; the rest are left out.
const MAX_FILES: usize = 300;
/// Diff lines one file shows; beyond this it keeps its counts only.
const MAX_FILE_LINES: usize = 2_000;
/// `sha, short sha, subject, author, time, body`, one record each.
const LOG_FORMAT: &str = "--format=%H%x1f%h%x1f%s%x1f%an%x1f%at%x1f%b%x1e";

impl GitCli {
    fn git_args(&self, worktree: &Path, args: &[&str]) -> Result<String, ChangesError> {
        self.exec(worktree, args).map_err(ChangesError::Git)
    }

    /// `git log` of `range` (newest first), at most `limit`.
    pub(super) fn log_range(
        &self,
        worktree: &Path,
        range: &str,
        limit: usize,
    ) -> Result<Vec<CommitInfo>, ChangesError> {
        let raw = self.git_args(
            worktree,
            &["log", &format!("-n{limit}"), LOG_FORMAT, range, "--"],
        )?;
        Ok(parse_log(&raw))
    }

    /// Main (the worktree's HEAD) plus each other branch's commits not on
    /// it, newest first.
    pub(super) fn log_all_branches(
        &self,
        worktree: &Path,
        limit: usize,
    ) -> Result<Vec<CommitInfo>, ChangesError> {
        let mut commits = self.log_range(worktree, "HEAD", limit)?;
        let mut seen: HashSet<String> = commits.iter().map(|c| c.sha.clone()).collect();
        for (reference, name) in self.other_branches(worktree)? {
            let range = format!("HEAD..{reference}");
            // A branch git can't read (a broken ref) is left out.
            let Ok(only) = self.log_range(worktree, &range, limit) else {
                continue;
            };
            for mut commit in only {
                if seen.insert(commit.sha.clone()) {
                    commit.branch = Some(name.clone());
                    commits.push(commit);
                }
            }
        }
        commits.sort_by_key(|c| std::cmp::Reverse(c.time_unix));
        Ok(commits)
    }

    /// (ref to log, name to show) of the branches that aren't main, most
    /// recently committed first: local ones, and the remote's ones that have
    /// no local branch of the same name.
    fn other_branches(&self, worktree: &Path) -> Result<Vec<(String, String)>, ChangesError> {
        let head = self
            .exec(worktree, ["symbolic-ref", "--quiet", "--short", "HEAD"])
            .map(|s| s.trim().to_owned())
            .unwrap_or_default();
        let upstream = self
            .exec(
                worktree,
                ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
            )
            .map(|s| s.trim().to_owned())
            .unwrap_or_default();
        let raw = self.git_args(
            worktree,
            &[
                "for-each-ref",
                "--sort=-committerdate",
                "--format=%(refname)%1f%(refname:short)%1f%(symref)",
                "refs/heads",
                "refs/remotes",
            ],
        )?;
        Ok(pick_branches(&raw, &head, &upstream))
    }

    /// What `sha` changed: header, then names, counts and hunks.
    pub(super) fn show(&self, worktree: &Path, sha: &str) -> Result<CommitDetail, ChangesError> {
        if sha.is_empty() || sha.starts_with('-') || !sha.bytes().all(|b| b.is_ascii_alphanumeric())
        {
            return Err(ChangesError::Git(format!("not a commit: {sha}")));
        }
        let header = self.git_args(
            worktree,
            &[
                "show",
                "-s",
                "--format=%H%x1f%p%x1f%at%x1f%b",
                &format!("{sha}^{{commit}}"),
                "--",
            ],
        )?;
        let mut detail = parse_header(&header);
        // Merges are shown against their first parent; a root commit
        // against nothing.
        let diff = |what: &[&str]| -> Result<String, ChangesError> {
            let mut args = match detail.parents.first() {
                Some(parent) => vec!["diff", parent.as_str(), detail.sha.as_str()],
                None => vec!["show", "--format=", detail.sha.as_str()],
            };
            args.extend(["-M", "--no-color", "--no-ext-diff"]);
            args.extend(what);
            args.push("--");
            self.git_args(worktree, &args)
        };
        let names = diff(&["-z", "--name-status"])?;
        let counts = diff(&["-z", "--numstat"])?;
        let patch = diff(&["--unified=3", "--no-prefix"])?;
        detail.files = commit_files(&names, &counts, &patch);
        Ok(detail)
    }
}

/// See [`GitCli::other_branches`]: `refname, short name, symref` lines.
fn pick_branches(raw: &str, head: &str, upstream: &str) -> Vec<(String, String)> {
    let rows: Vec<(&str, &str)> = raw
        .lines()
        .filter_map(|line| {
            let mut f = line.split('\x1f');
            let (full, short, symref) = (f.next()?, f.next()?, f.next().unwrap_or_default());
            (symref.is_empty() && !full.ends_with("/HEAD")).then_some((full, short))
        })
        .collect();
    let locals: HashSet<&str> = rows
        .iter()
        .filter_map(|(full, _)| full.strip_prefix("refs/heads/"))
        .collect();
    let mut out = Vec::new();
    for (full, short) in rows {
        let name = if let Some(local) = full.strip_prefix("refs/heads/") {
            local
        } else if let Some(remote) = full.strip_prefix("refs/remotes/") {
            if remote == upstream {
                continue; // main's own remote
            }
            let Some((_, name)) = remote.split_once('/') else {
                continue;
            };
            if locals.contains(name) {
                continue; // the local branch stands for it
            }
            name
        } else {
            continue;
        };
        if name == head || out.iter().any(|(_, n): &(String, String)| n == name) {
            continue;
        }
        out.push((short.to_owned(), name.to_owned()));
        if out.len() == MAX_BRANCHES {
            break;
        }
    }
    out
}

pub(super) fn parse_log(raw: &str) -> Vec<CommitInfo> {
    raw.split('\x1e')
        .filter_map(|record| {
            let mut f = record.trim_start_matches('\n').split('\x1f');
            let sha = f.next().filter(|s| !s.is_empty())?.to_owned();
            let short_sha = f.next()?.to_owned();
            let subject = f.next()?.to_owned();
            let author = f.next()?.to_owned();
            let time_unix = f.next()?.trim().parse().unwrap_or(0);
            let body = f.next().unwrap_or_default();
            Some(CommitInfo {
                pr_ref: CommitInfo::pr_ref_of(&subject, body),
                sha,
                short_sha,
                subject,
                author,
                time_unix,
                branch: None,
            })
        })
        .collect()
}

/// `%H%x1f%p%x1f%at%x1f%b`.
fn parse_header(raw: &str) -> CommitDetail {
    let mut f = raw.splitn(4, '\x1f');
    let sha = f.next().unwrap_or_default().trim().to_owned();
    let parents = f
        .next()
        .unwrap_or_default()
        .split_whitespace()
        .map(str::to_owned)
        .collect();
    let time_unix = f.next().unwrap_or_default().trim().parse().unwrap_or(0);
    let body = f.next().unwrap_or_default().trim().to_owned();
    CommitDetail {
        sha,
        body,
        parents,
        time_unix,
        files: Vec::new(),
    }
}

/// Files from `--name-status -z`, `--numstat -z` and the patch: git lists
/// them in the same order in all three, so they're matched by position.
fn commit_files(names: &str, counts: &str, patch: &str) -> Vec<CommitFile> {
    let mut files = parse_names(names);
    for (file, (added, deleted, binary)) in files.iter_mut().zip(parse_counts(counts)) {
        file.added = added;
        file.deleted = deleted;
        file.binary = binary;
    }
    for (file, hunks) in files.iter_mut().zip(split_patch(patch)) {
        if file.binary {
            continue;
        }
        if file.added as usize + file.deleted as usize > MAX_FILE_LINES {
            file.cut = true;
            continue;
        }
        file.hunks = parse_hunks(hunks);
    }
    files.truncate(MAX_FILES);
    files
}

/// `--name-status -z`: `M\0path\0`, `R100\0old\0new\0`.
fn parse_names(raw: &str) -> Vec<CommitFile> {
    let mut files = Vec::new();
    // `git show --format=` starts with a newline.
    let mut tokens = raw
        .split('\0')
        .map(|t| t.trim_start_matches('\n'))
        .filter(|t| !t.is_empty());
    while let Some(status) = tokens.next() {
        let letter = status.chars().next().unwrap_or('M');
        let (old_path, path) = if matches!(letter, 'R' | 'C') {
            (tokens.next().map(str::to_owned), tokens.next())
        } else {
            (None, tokens.next())
        };
        let Some(path) = path else { break };
        files.push(CommitFile {
            path: path.to_owned(),
            old_path: old_path.filter(|_| letter == 'R'),
            kind: match ChangeKind::from_git(letter) {
                ChangeKind::None => ChangeKind::Modified,
                kind => kind,
            },
            ..CommitFile::default()
        });
    }
    files
}

/// `--numstat -z`: (added, deleted, binary) per file; `-` means binary.
fn parse_counts(raw: &str) -> Vec<(u32, u32, bool)> {
    let mut out = Vec::new();
    let mut tokens = raw.split('\0');
    while let Some(token) = tokens.next() {
        let mut fields = token.trim_start_matches('\n').splitn(3, '\t');
        let (Some(added), Some(deleted), Some(path)) =
            (fields.next(), fields.next(), fields.next())
        else {
            continue;
        };
        if path.is_empty() {
            // A rename: old and new path follow as tokens of their own.
            tokens.next();
            tokens.next();
        }
        out.push((
            added.parse().unwrap_or(0),
            deleted.parse().unwrap_or(0),
            added == "-",
        ));
    }
    out
}

/// The patch's lines after each `diff --git` header, one slice per file.
fn split_patch(patch: &str) -> Vec<Vec<&str>> {
    let mut files: Vec<Vec<&str>> = Vec::new();
    for line in patch.lines() {
        if line.starts_with("diff --git ") {
            files.push(Vec::new());
        } else if let Some(file) = files.last_mut() {
            file.push(line);
        }
    }
    files
}

/// `@@ -a,b +c,d @@ section` headers and their ` `, `+`, `-` lines.
fn parse_hunks(lines: Vec<&str>) -> Vec<DiffHunk> {
    let mut hunks: Vec<DiffHunk> = Vec::new();
    for line in lines {
        if let Some(header) = line.strip_prefix("@@ ") {
            let (ranges, section) = header.split_once(" @@").unwrap_or((header, ""));
            let mut parts = ranges.split_whitespace();
            let start = |p: Option<&str>, sign: char| -> u32 {
                p.and_then(|p| p.strip_prefix(sign))
                    .and_then(|p| p.split(',').next())
                    .and_then(|n| n.parse().ok())
                    .unwrap_or(0)
            };
            hunks.push(DiffHunk {
                old_start: start(parts.next(), '-'),
                new_start: start(parts.next(), '+'),
                section: section.trim().to_owned(),
                lines: Vec::new(),
            });
            continue;
        }
        let Some(hunk) = hunks.last_mut() else {
            continue; // `index`, `---`, `+++`, rename lines
        };
        let (kind, text) = match line.chars().next() {
            Some('+') => (DiffLineKind::Added, &line[1..]),
            Some('-') => (DiffLineKind::Deleted, &line[1..]),
            Some(' ') => (DiffLineKind::Context, &line[1..]),
            None => (DiffLineKind::Context, ""),
            Some(_) => continue, // "\ No newline at end of file"
        };
        hunk.lines.push(DiffLine {
            kind,
            text: text.to_owned(),
        });
    }
    hunks
}

#[cfg(test)]
mod tests {
    use std::process::Command;

    use kumo_domain::changes::GitChanges;

    use super::*;

    fn git(dir: &Path, args: &[&str]) -> String {
        let out = Command::new("git")
            .arg("-C")
            .arg(dir)
            .args(args)
            .output()
            .unwrap();
        assert!(
            out.status.success(),
            "git {args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        String::from_utf8_lossy(&out.stdout).trim().to_owned()
    }

    /// Commits with increasing dates, so the order is deterministic.
    fn commit(dir: &Path, n: u32, message: &str) {
        let date = format!("{} +0000", 1_700_000_000 + n * 60);
        let out = Command::new("git")
            .arg("-C")
            .arg(dir)
            .args(["commit", "-q", "--allow-empty", "-m", message])
            .env("GIT_AUTHOR_DATE", &date)
            .env("GIT_COMMITTER_DATE", &date)
            .output()
            .unwrap();
        assert!(
            out.status.success(),
            "{}",
            String::from_utf8_lossy(&out.stderr)
        );
    }

    fn repo() -> tempfile::TempDir {
        let dir = tempfile::tempdir().unwrap();
        git(dir.path(), &["init", "-q", "-b", "main"]);
        git(dir.path(), &["config", "user.email", "t@kumo.dev"]);
        git(dir.path(), &["config", "user.name", "Ana"]);
        git(dir.path(), &["config", "commit.gpgsign", "false"]);
        dir
    }

    fn write(dir: &Path, path: &str, text: &[u8]) {
        let file = dir.join(path);
        std::fs::create_dir_all(file.parent().unwrap()).unwrap();
        std::fs::write(file, text).unwrap();
    }

    #[test]
    fn all_branches_adds_what_is_not_on_main() {
        let dir = repo();
        let d = dir.path();
        commit(d, 1, "chore: start");
        git(d, &["switch", "-q", "-c", "feat/merged"]);
        commit(d, 2, "feat: merged work");
        git(d, &["switch", "-q", "main"]);
        let date = format!("{} +0000", 1_700_000_000 + 3 * 60);
        let out = Command::new("git")
            .arg("-C")
            .arg(d)
            .args([
                "merge",
                "-q",
                "--no-ff",
                "feat/merged",
                "-m",
                "Merge pull request #7 from acme/feat/merged",
            ])
            .env("GIT_AUTHOR_DATE", &date)
            .env("GIT_COMMITTER_DATE", &date)
            .output()
            .unwrap();
        assert!(out.status.success());
        commit(d, 4, "fix: squashed (#8)");
        git(d, &["switch", "-q", "-c", "feat/open"]);
        commit(d, 5, "feat: open one");
        commit(d, 6, "feat: open two");
        git(d, &["switch", "-q", "main"]);

        let cli = GitCli::default();
        let main = cli.log(d, 50, false).unwrap();
        assert_eq!(
            main.iter().map(|c| c.subject.as_str()).collect::<Vec<_>>(),
            [
                "fix: squashed (#8)",
                "Merge pull request #7 from acme/feat/merged",
                "feat: merged work",
                "chore: start"
            ]
        );
        assert!(main.iter().all(|c| c.branch.is_none()));
        assert_eq!(main[0].pr_ref.as_deref(), Some("#8"));
        assert_eq!(main[1].pr_ref.as_deref(), Some("#7"));

        let all = cli.log(d, 50, true).unwrap();
        let rows: Vec<_> = all
            .iter()
            .map(|c| (c.subject.as_str(), c.branch.as_deref()))
            .collect();
        assert_eq!(
            rows,
            [
                ("feat: open two", Some("feat/open")),
                ("feat: open one", Some("feat/open")),
                ("fix: squashed (#8)", None),
                ("Merge pull request #7 from acme/feat/merged", None),
                ("feat: merged work", None),
                ("chore: start", None),
            ],
            "the merged branch adds nothing"
        );
    }

    #[test]
    fn remote_branches_count_unless_a_local_one_stands_for_them() {
        let raw = "refs/heads/main\x1fmain\x1f\n\
                   refs/heads/feat/a\x1ffeat/a\x1f\n\
                   refs/remotes/origin/HEAD\x1forigin\x1frefs/remotes/origin/main\n\
                   refs/remotes/origin/main\x1forigin/main\x1f\n\
                   refs/remotes/origin/feat/a\x1forigin/feat/a\x1f\n\
                   refs/remotes/origin/feat/b\x1forigin/feat/b\x1f\n";
        assert_eq!(
            pick_branches(raw, "main", "origin/main"),
            [
                ("feat/a".to_owned(), "feat/a".to_owned()),
                ("origin/feat/b".to_owned(), "feat/b".to_owned())
            ]
        );
    }

    #[test]
    fn a_commit_that_adds_modifies_deletes_and_renames() {
        let dir = repo();
        let d = dir.path();
        let body: String = (1..=20).map(|i| format!("line {i}\n")).collect();
        write(d, "src/keep.rs", b"fn main() {\n    one();\n}\n");
        write(d, "old.txt", body.as_bytes());
        write(d, "gone.txt", b"bye\n");
        write(d, "logo.png", &[0, 1, 2, 3, 0, 5]);
        git(d, &["add", "-A"]);
        commit(d, 1, "chore: start");

        write(d, "src/keep.rs", b"fn main() {\n    two();\n}\n");
        std::fs::remove_file(d.join("old.txt")).unwrap();
        write(
            d,
            "docs/new.txt",
            body.replace("line 20", "line twenty").as_bytes(),
        );
        git(d, &["rm", "-q", "gone.txt"]);
        write(d, "added.md", b"# Hi\n");
        write(d, "logo.png", &[0, 9, 9, 9, 0, 5]);
        git(d, &["add", "-A"]);
        commit(d, 2, "feat: everything\n\nThe body.\n\nPRC-1");

        let cli = GitCli::default();
        let sha = git(d, &["rev-parse", "HEAD"]);
        let parent = git(d, &["rev-parse", "--short", "HEAD~1"]);
        let detail = cli.show_commit(d, &sha[..10]).unwrap();
        assert_eq!(detail.sha, sha);
        assert_eq!(detail.body, "The body.\n\nPRC-1");
        assert_eq!(detail.parents, std::slice::from_ref(&parent));
        assert_eq!(detail.time_unix, 1_700_000_120);
        let mut rows: Vec<_> = detail
            .files
            .iter()
            .map(|f| {
                (
                    f.path.as_str(),
                    f.old_path.as_deref(),
                    f.kind,
                    f.added,
                    f.deleted,
                    f.binary,
                )
            })
            .collect();
        rows.sort_by_key(|r| r.0);
        assert_eq!(
            rows,
            [
                ("added.md", None, ChangeKind::Added, 1, 0, false),
                (
                    "docs/new.txt",
                    Some("old.txt"),
                    ChangeKind::Renamed,
                    1,
                    1,
                    false
                ),
                ("gone.txt", None, ChangeKind::Deleted, 0, 1, false),
                ("logo.png", None, ChangeKind::Modified, 0, 0, true),
                ("src/keep.rs", None, ChangeKind::Modified, 1, 1, false),
            ]
        );
        let keep = detail
            .files
            .iter()
            .find(|f| f.path == "src/keep.rs")
            .unwrap();
        assert_eq!(keep.hunks.len(), 1);
        let hunk = &keep.hunks[0];
        assert_eq!((hunk.old_start, hunk.new_start), (1, 1));
        assert_eq!(
            hunk.lines
                .iter()
                .map(|l| (l.kind, l.text.as_str()))
                .collect::<Vec<_>>(),
            [
                (DiffLineKind::Context, "fn main() {"),
                (DiffLineKind::Deleted, "    one();"),
                (DiffLineKind::Added, "    two();"),
                (DiffLineKind::Context, "}"),
            ]
        );
        let renamed = detail
            .files
            .iter()
            .find(|f| f.path == "docs/new.txt")
            .unwrap();
        assert_eq!(
            (renamed.hunks[0].old_start, renamed.hunks[0].new_start),
            (17, 17)
        );
        let png = detail.files.iter().find(|f| f.path == "logo.png").unwrap();
        assert!(png.hunks.is_empty());

        // The first commit: everything added, against nothing.
        let first = cli.show_commit(d, &parent).unwrap();
        assert!(first.parents.is_empty());
        assert_eq!(first.files.len(), 4);
        assert!(first.files.iter().all(|f| f.kind == ChangeKind::Added));

        assert!(cli.show_commit(d, "--output=x").is_err());
        assert!(cli.show_commit(d, "deadbeef").is_err());
    }

    #[test]
    fn a_merge_shows_what_it_brought_into_its_first_parent() {
        let dir = repo();
        let d = dir.path();
        write(d, "a.txt", b"a\n");
        git(d, &["add", "-A"]);
        commit(d, 1, "chore: start");
        git(d, &["switch", "-q", "-c", "feat/x"]);
        write(d, "b.txt", b"b\nb\n");
        git(d, &["add", "-A"]);
        commit(d, 2, "feat: b");
        git(d, &["switch", "-q", "main"]);
        write(d, "c.txt", b"c\n");
        git(d, &["add", "-A"]);
        commit(d, 3, "feat: c");
        git(
            d,
            &[
                "merge",
                "-q",
                "--no-ff",
                "feat/x",
                "-m",
                "Merge pull request #9 from x",
            ],
        );

        let detail = GitCli::default().show_commit(d, "HEAD").unwrap();
        assert_eq!(detail.parents.len(), 2);
        assert_eq!(
            detail
                .files
                .iter()
                .map(|f| (f.path.as_str(), f.added))
                .collect::<Vec<_>>(),
            [("b.txt", 2)]
        );
    }

    #[test]
    fn hunk_headers_keep_numbers_and_section() {
        let hunks = parse_hunks(vec![
            "index 1..2 100644",
            "--- a/x.go",
            "+++ b/x.go",
            "@@ -72,3 +72,4 @@ func (r *Repository) UpsertBulk(ctx context.Context) error {",
            " keep",
            "-old",
            "+new",
            "+more",
            "\\ No newline at end of file",
            "@@ -1 +1 @@",
            "-a",
            "+b",
        ]);
        assert_eq!(hunks.len(), 2);
        assert_eq!(
            (
                hunks[0].old_start,
                hunks[0].new_start,
                hunks[0].section.as_str()
            ),
            (
                72,
                72,
                "func (r *Repository) UpsertBulk(ctx context.Context) error {"
            )
        );
        assert_eq!(hunks[0].lines.len(), 4);
        assert_eq!(
            (
                hunks[1].old_start,
                hunks[1].new_start,
                hunks[1].section.as_str()
            ),
            (1, 1, "")
        );
    }

    #[test]
    fn a_huge_file_keeps_its_counts_without_hunks() {
        let names = "M\0big.txt\0";
        let counts = "2500\t10\tbig.txt\0";
        let patch = "diff --git big.txt big.txt\n@@ -1 +1 @@\n-a\n+b\n";
        let files = commit_files(names, counts, patch);
        assert_eq!(
            (files[0].added, files[0].deleted, files[0].cut),
            (2500, 10, true)
        );
        assert!(files[0].hunks.is_empty());
    }
}
