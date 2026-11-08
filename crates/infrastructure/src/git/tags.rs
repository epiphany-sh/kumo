//! [`GitTags`] for [`GitCli`]: tags and what changed between them.

use std::path::Path;

use kumo_domain::releases::{GitTag, GitTags, MergedPr, ReleaseRange};
use kumo_domain::time::Timestamp;

use super::GitCli;

/// Commits read for a range's pull requests; a first release of a big
/// repository stops here.
const MAX_RANGE_COMMITS: usize = 5_000;

impl GitCli {
    /// `refs/tags/<tag>`, once git knows it as a commit.
    fn tag_ref(&self, repo: &Path, tag: &str) -> Result<String, String> {
        let reference = format!("refs/tags/{tag}");
        self.exec(
            repo,
            [
                "rev-parse",
                "--verify",
                "--quiet",
                &format!("{reference}^{{commit}}"),
            ],
        )
        .map_err(|_| format!("there's no tag {tag}"))?;
        Ok(reference)
    }
}

impl GitTags for GitCli {
    fn fetch_tags(&self, repo: &Path) -> Result<(), String> {
        self.exec(repo, ["fetch", "-q", "--tags", "--no-recurse-submodules"])
            .map(drop)
    }

    fn tags(&self, repo: &Path) -> Result<Vec<GitTag>, String> {
        let raw = self.exec(
            repo,
            [
                // A pre-release goes under its final version.
                "-c",
                "versionsort.suffix=-",
                "for-each-ref",
                "refs/tags",
                "--sort=-v:refname",
                "--format=%(refname:strip=2)%1f%(objectname)%1f%(*objectname)%1f%(creatordate:unix)%1f%(taggername)%1f%(authorname)",
            ],
        )?;
        Ok(parse_tags(&raw))
    }

    fn range(&self, repo: &Path, tag: &str, since: Option<&str>) -> Result<ReleaseRange, String> {
        let to = self.tag_ref(repo, tag)?;
        let from = since
            .filter(|s| !s.is_empty())
            .map(|s| self.tag_ref(repo, s))
            .transpose()?;
        // `a..b` is what b has that a hasn't; `a...b` diffs from their
        // merge base: the same when a is an ancestor.
        let (revs, diff_from) = match &from {
            Some(from) => (format!("{from}..{to}"), format!("{from}...{to}")),
            None => {
                let empty = self.exec(repo, ["hash-object", "-t", "tree", "--stdin"])?;
                (to.clone(), format!("{}..{to}", empty.trim()))
            }
        };
        let count = self.exec(repo, ["rev-list", "--count", &revs, "--"])?;
        let stat = self.exec(repo, ["diff", "--shortstat", &diff_from, "--"])?;
        let log = self.exec(
            repo,
            [
                "log",
                &format!("-n{MAX_RANGE_COMMITS}"),
                "--format=%s%x1f%an%x1f%b%x1e",
                &revs,
                "--",
            ],
        )?;
        let (files, added, deleted) = parse_shortstat(&stat);
        Ok(ReleaseRange {
            since: since.unwrap_or_default().to_owned(),
            commits: count.trim().parse().unwrap_or(0),
            added,
            deleted,
            files,
            prs: merged_prs(&log),
        })
    }
}

/// `name, object, peeled object, date, tagger, author` per line.
fn parse_tags(raw: &str) -> Vec<GitTag> {
    raw.lines()
        .filter_map(|line| {
            let mut f = line.split('\x1f');
            let name = f.next().filter(|n| !n.is_empty())?.to_owned();
            let object = f.next()?;
            let peeled = f.next().unwrap_or_default();
            let time = f
                .next()
                .and_then(|t| t.trim().parse::<u64>().ok())
                .filter(|t| *t > 0)
                .map(|t| Timestamp::from_unix_nanos(t * 1_000_000_000));
            let tagger = f.next().unwrap_or_default();
            let author = f.next().unwrap_or_default();
            Some(GitTag {
                name,
                sha: if peeled.is_empty() { object } else { peeled }.to_owned(),
                time,
                author: if tagger.is_empty() { author } else { tagger }.to_owned(),
            })
        })
        .collect()
}

/// ` 3 files changed, 12 insertions(+), 1 deletion(-)`: (files, added,
/// deleted).
fn parse_shortstat(raw: &str) -> (u32, u32, u32) {
    let mut out = (0, 0, 0);
    for part in raw.split(',') {
        let mut words = part.split_whitespace();
        let (Some(n), Some(what)) = (words.next(), words.next()) else {
            continue;
        };
        let n = n.parse().unwrap_or(0);
        if what.starts_with("file") {
            out.0 = n;
        } else if what.starts_with("insertion") {
            out.1 = n;
        } else if what.starts_with("deletion") {
            out.2 = n;
        }
    }
    out
}

/// Pull requests named by the range's commits, newest first, each once.
fn merged_prs(log: &str) -> Vec<MergedPr> {
    let mut prs: Vec<MergedPr> = Vec::new();
    for record in log.split('\x1e') {
        let mut f = record.trim_start_matches('\n').splitn(3, '\x1f');
        let (Some(subject), Some(author)) = (f.next(), f.next()) else {
            continue;
        };
        let body = f.next().unwrap_or_default();
        if let Some(pr) = MergedPr::from_commit(subject, author, body)
            && !prs.iter().any(|p| p.reference == pr.reference)
        {
            prs.push(pr);
        }
    }
    prs
}

#[cfg(test)]
mod tests {
    use std::process::Command;

    use super::*;

    fn git(dir: &Path, args: &[&str], n: u32) {
        let date = format!("{} +0000", 1_700_000_000 + n * 60);
        let out = Command::new("git")
            .arg("-C")
            .arg(dir)
            .args(args)
            .env("GIT_AUTHOR_DATE", &date)
            .env("GIT_COMMITTER_DATE", &date)
            .env("GIT_AUTHOR_NAME", "Ana")
            .env("GIT_COMMITTER_NAME", "Ana")
            .output()
            .unwrap();
        assert!(
            out.status.success(),
            "git {args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
    }

    fn write(dir: &Path, path: &str, text: &str) {
        std::fs::write(dir.join(path), text).unwrap();
        git(dir, &["add", "-A"], 0);
    }

    /// v1.0.0 → a merge commit (#2) and a squash (#3) → v1.1.0; a side
    /// tag v0.9.0-hotfix off the first commit.
    fn fixture() -> tempfile::TempDir {
        let dir = tempfile::tempdir().unwrap();
        let d = dir.path();
        git(d, &["init", "-q", "-b", "main"], 0);
        git(d, &["config", "user.email", "t@kumo.dev"], 0);
        git(d, &["config", "user.name", "Ana"], 0);
        git(d, &["config", "commit.gpgsign", "false"], 0);
        git(d, &["config", "tag.gpgsign", "false"], 0);
        write(d, "a.txt", "a\n");
        git(d, &["commit", "-q", "-m", "chore: start"], 1);
        git(d, &["tag", "-a", "v1.0.0", "-m", "First"], 2);
        git(d, &["switch", "-q", "-c", "side"], 2);
        write(d, "side.txt", "s\n");
        git(d, &["commit", "-q", "-m", "fix: side"], 3);
        git(d, &["tag", "v0.9.0-hotfix"], 3);
        git(d, &["switch", "-q", "main"], 3);
        git(d, &["switch", "-q", "-c", "feat/PRC-7-thing"], 4);
        write(d, "b.txt", "b\nb\n");
        git(d, &["commit", "-q", "-m", "feat: thing"], 5);
        git(d, &["switch", "-q", "main"], 5);
        git(
            d,
            &[
                "merge",
                "-q",
                "--no-ff",
                "feat/PRC-7-thing",
                "-m",
                "Merge pull request #2 from acme/feat/PRC-7-thing\n\nfeat: the thing",
            ],
            6,
        );
        write(d, "a.txt", "a\nmore\n");
        git(d, &["commit", "-q", "-m", "fix: more (#3)"], 7);
        git(d, &["tag", "v1.1.0"], 8);
        git(d, &["tag", "v1.10.0-rc.1"], 9);
        dir
    }

    #[test]
    fn a_pre_release_goes_under_its_final_version() {
        let dir = fixture();
        git(dir.path(), &["tag", "v1.10.0"], 10);
        let tags = GitCli::default().tags(dir.path()).unwrap();
        let names: Vec<_> = tags.iter().take(3).map(|t| t.name.as_str()).collect();
        assert_eq!(names, ["v1.10.0", "v1.10.0-rc.1", "v1.1.0"]);
    }

    #[test]
    fn tags_newest_version_first_with_their_commits() {
        let dir = fixture();
        let tags = GitCli::default().tags(dir.path()).unwrap();
        let names: Vec<_> = tags.iter().map(|t| t.name.as_str()).collect();
        assert_eq!(names, ["v1.10.0-rc.1", "v1.1.0", "v1.0.0", "v0.9.0-hotfix"]);
        let annotated = &tags[2];
        let first = Command::new("git")
            .arg("-C")
            .arg(dir.path())
            .args(["rev-list", "-n1", "v1.0.0"])
            .output()
            .unwrap();
        assert_eq!(annotated.sha, String::from_utf8_lossy(&first.stdout).trim());
        assert_eq!(annotated.author, "Ana");
        assert_eq!(
            annotated.time.map(|t| t.as_unix_nanos() / 1_000_000_000),
            Some(1_700_000_120)
        );
    }

    #[test]
    fn a_range_across_a_merge_and_a_squash() {
        let dir = fixture();
        let range = GitCli::default()
            .range(dir.path(), "v1.1.0", Some("v1.0.0"))
            .unwrap();
        assert_eq!(range.since, "v1.0.0");
        assert_eq!(
            (range.commits, range.files, range.added, range.deleted),
            (3, 2, 3, 0)
        );
        let prs: Vec<_> = range
            .prs
            .iter()
            .map(|p| (p.reference.as_str(), p.title.as_str(), p.ticket.as_deref()))
            .collect();
        assert_eq!(
            prs,
            [
                ("#3", "fix: more", None),
                ("#2", "feat: the thing", Some("PRC-7"))
            ]
        );
    }

    #[test]
    fn a_range_since_the_first_commit_and_from_a_side_tag() {
        let dir = fixture();
        let cli = GitCli::default();
        let all = cli.range(dir.path(), "v1.1.0", None).unwrap();
        assert_eq!(
            (all.since.as_str(), all.commits, all.files, all.added),
            ("", 4, 2, 4)
        );

        // v0.9.0-hotfix isn't an ancestor of v1.1.0: counted from where
        // they split (its own commit isn't subtracted from the diff).
        let side = cli
            .range(dir.path(), "v1.1.0", Some("v0.9.0-hotfix"))
            .unwrap();
        assert_eq!((side.commits, side.files, side.added), (3, 2, 3));

        assert!(
            cli.range(dir.path(), "v9", None)
                .unwrap_err()
                .contains("no tag v9")
        );
        assert!(cli.range(dir.path(), "v1.1.0", Some("--all")).is_err());
    }

    #[test]
    fn shortstat_counts() {
        assert_eq!(
            parse_shortstat(" 3 files changed, 12 insertions(+), 1 deletion(-)\n"),
            (3, 12, 1)
        );
        assert_eq!(
            parse_shortstat(" 1 file changed, 2 deletions(-)"),
            (1, 0, 2)
        );
        assert_eq!(parse_shortstat(""), (0, 0, 0));
    }
}
