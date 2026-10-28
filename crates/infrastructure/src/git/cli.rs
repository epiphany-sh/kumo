use std::ffi::OsStr;
use std::path::{Path, PathBuf};
use std::process::Command;

use kumo_domain::workspace::{
    Branches, Git, NewWorktree, WorkspaceError, Worktree, WorktreeStatus,
};

/// [`Git`] backed by the `git` binary on `PATH`.
#[derive(Debug, Clone)]
pub struct GitCli {
    program: PathBuf,
}

impl Default for GitCli {
    fn default() -> Self {
        Self {
            program: PathBuf::from("git"),
        }
    }
}

impl GitCli {
    /// Runs `git -C <dir> <args>` and returns stdout, or git's error text.
    pub(super) fn exec<I, S>(&self, dir: &Path, args: I) -> Result<String, String>
    where
        I: IntoIterator<Item = S>,
        S: AsRef<OsStr>,
    {
        let output = Command::new(&self.program)
            .arg("-C")
            .arg(dir)
            .args(args)
            // Stable, English, non-interactive output; ssh never prompts.
            .env("LC_ALL", "C")
            .env("GIT_TERMINAL_PROMPT", "0")
            .env("GIT_OPTIONAL_LOCKS", "0")
            .env("GIT_SSH_COMMAND", "ssh -o BatchMode=yes")
            .output()
            .map_err(|e| format!("can't run git: {e}"))?;
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            let stdout = String::from_utf8_lossy(&output.stdout);
            // Some commands (commit) explain themselves on stdout.
            let message = if stderr.trim().is_empty() {
                stdout
            } else {
                stderr
            };
            return Err(message.trim().to_owned());
        }
        Ok(String::from_utf8_lossy(&output.stdout).into_owned())
    }

    fn run<I, S>(&self, dir: &Path, args: I) -> Result<String, WorkspaceError>
    where
        I: IntoIterator<Item = S>,
        S: AsRef<OsStr>,
    {
        self.exec(dir, args).map_err(WorkspaceError::Git)
    }
}

impl Git for GitCli {
    fn main_checkout(&self, path: &Path) -> Result<PathBuf, WorkspaceError> {
        if !path.is_dir() {
            return Err(WorkspaceError::NotARepository(path.into()));
        }
        let list = self
            .run(path, ["worktree", "list", "--porcelain"])
            .map_err(|_| WorkspaceError::NotARepository(path.into()))?;
        let main = parse_worktrees(&list)
            .into_iter()
            .next()
            .ok_or_else(|| WorkspaceError::NotARepository(path.into()))?;
        Ok(canonical(main.path))
    }

    fn remote_url(&self, repo: &Path) -> Result<Option<String>, WorkspaceError> {
        let remotes = self.run(repo, ["remote"])?;
        let mut names: Vec<&str> = remotes
            .lines()
            .map(str::trim)
            .filter(|r| !r.is_empty())
            .collect();
        if names.is_empty() {
            return Ok(None);
        }
        if let Some(origin) = names.iter().position(|r| *r == "origin") {
            names.swap(0, origin);
        }
        let url = self.run(repo, ["remote", "get-url", names[0]])?;
        Ok(Some(url.trim().to_owned()).filter(|u| !u.is_empty()))
    }

    fn worktrees(&self, repo: &Path) -> Result<Vec<Worktree>, WorkspaceError> {
        let list = self.run(repo, ["worktree", "list", "--porcelain"])?;
        Ok(parse_worktrees(&list)
            .into_iter()
            .map(|w| Worktree {
                path: canonical(w.path),
                ..w
            })
            .collect())
    }

    fn status(&self, worktree: &Path) -> Result<WorktreeStatus, WorkspaceError> {
        let status = self.run(
            worktree,
            [
                "status",
                "--porcelain=v2",
                "--branch",
                "--untracked-files=normal",
            ],
        )?;
        Ok(parse_status(&status))
    }

    /// Git creates the missing parent folders itself, and leaves none
    /// behind when it fails (e.g. the branch already exists).
    fn add_worktree(&self, repo: &Path, worktree: &NewWorktree) -> Result<(), WorkspaceError> {
        let mut args: Vec<&OsStr> = vec![OsStr::new("worktree"), OsStr::new("add")];
        if worktree.create_branch {
            args.extend([
                OsStr::new("-b"),
                OsStr::new(worktree.branch.as_str()),
                worktree.path.as_os_str(),
            ]);
            if let Some(base) = &worktree.base {
                args.push(OsStr::new(base));
            }
        } else {
            args.extend([
                worktree.path.as_os_str(),
                OsStr::new(worktree.branch.as_str()),
            ]);
        }
        self.run(repo, args).map(drop)
    }

    fn remove_worktree(
        &self,
        repo: &Path,
        worktree: &Path,
        force: bool,
    ) -> Result<(), WorkspaceError> {
        let mut args = vec![OsStr::new("worktree"), OsStr::new("remove")];
        if force {
            args.push(OsStr::new("--force"));
        }
        args.push(worktree.as_os_str());
        self.run(repo, args).map(drop)
    }

    fn branches(&self, repo: &Path) -> Result<Branches, WorkspaceError> {
        let refs = self.run(
            repo,
            [
                "for-each-ref",
                "--format=%(refname)",
                "refs/heads",
                "refs/remotes",
            ],
        )?;
        let current = self
            .run(repo, ["symbolic-ref", "--quiet", "--short", "HEAD"])
            .ok();
        Ok(parse_branches(&refs, current.as_deref()))
    }
}

/// Splits `git for-each-ref` output into local and remote branches.
fn parse_branches(refs: &str, current: Option<&str>) -> Branches {
    let mut branches = Branches {
        current: current
            .map(str::trim)
            .filter(|c| !c.is_empty())
            .map(str::to_owned),
        ..Branches::default()
    };
    for line in refs.lines().map(str::trim) {
        if let Some(local) = line.strip_prefix("refs/heads/") {
            branches.local.push(local.to_owned());
        } else if let Some(remote) = line.strip_prefix("refs/remotes/")
            && !remote.ends_with("/HEAD")
        {
            branches.remote.push(remote.to_owned());
        }
    }
    branches
}

fn canonical(path: PathBuf) -> PathBuf {
    std::fs::canonicalize(&path).unwrap_or(path)
}

/// Parses `git worktree list --porcelain`: blocks separated by blank lines,
/// the main checkout first. Bare entries are skipped.
fn parse_worktrees(porcelain: &str) -> Vec<Worktree> {
    let mut worktrees = Vec::new();
    for (index, block) in porcelain
        .split("\n\n")
        .filter(|b| !b.trim().is_empty())
        .enumerate()
    {
        let mut worktree = Worktree {
            path: PathBuf::new(),
            branch: None,
            head: String::new(),
            is_main: index == 0,
            locked: false,
            status: WorktreeStatus::default(),
        };
        let mut bare = false;
        for line in block.lines() {
            let (key, value) = line.split_once(' ').unwrap_or((line, ""));
            match key {
                "worktree" => worktree.path = PathBuf::from(value),
                "HEAD" => worktree.head = value.to_owned(),
                "branch" => {
                    worktree.branch = Some(value.trim_start_matches("refs/heads/").to_owned())
                }
                "locked" => worktree.locked = true,
                "bare" => bare = true,
                _ => {}
            }
        }
        if !bare && !worktree.path.as_os_str().is_empty() {
            worktrees.push(worktree);
        }
    }
    worktrees
}

/// Parses `git status --porcelain=v2 --branch`.
fn parse_status(porcelain: &str) -> WorktreeStatus {
    let mut status = WorktreeStatus::default();
    for line in porcelain.lines() {
        if let Some(upstream) = line.strip_prefix("# branch.upstream ") {
            status.upstream = Some(upstream.trim().to_owned());
        } else if let Some(ab) = line.strip_prefix("# branch.ab ") {
            for part in ab.split_whitespace() {
                if let Some(n) = part.strip_prefix('+') {
                    status.ahead = n.parse().unwrap_or(0);
                } else if let Some(n) = part.strip_prefix('-') {
                    status.behind = n.parse().unwrap_or(0);
                }
            }
        } else if !line.starts_with('#') && !line.trim().is_empty() {
            status.changed_files += 1;
        }
    }
    status
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_worktree_list() {
        let porcelain = "worktree /r/main\nHEAD abc\nbranch refs/heads/main\n\n\
                         worktree /wt/feat\nHEAD def\nbranch refs/heads/feat/x\nlocked reason\n\n\
                         worktree /wt/detached\nHEAD 123\ndetached\n";
        let list = parse_worktrees(porcelain);
        assert_eq!(list.len(), 3);
        assert!(list[0].is_main && !list[1].is_main);
        assert_eq!(list[1].branch.as_deref(), Some("feat/x"));
        assert!(list[1].locked);
        assert_eq!(list[2].branch, None);
    }

    #[test]
    fn parses_status_counts_and_tracking() {
        let porcelain = "# branch.oid abc\n# branch.head main\n# branch.upstream origin/main\n# branch.ab +2 -1\n\
                         1 .M N... 100644 100644 100644 a b src/x.rs\n? new.txt\n";
        let status = parse_status(porcelain);
        assert_eq!(
            status,
            WorktreeStatus {
                changed_files: 2,
                ahead: 2,
                behind: 1,
                upstream: Some("origin/main".into())
            }
        );
    }

    #[test]
    fn splits_local_and_remote_branches() {
        let refs = "refs/heads/main\nrefs/heads/feat/x\nrefs/remotes/origin/HEAD\nrefs/remotes/origin/main\n";
        let branches = parse_branches(refs, Some("main\n"));
        assert_eq!(branches.current.as_deref(), Some("main"));
        assert_eq!(branches.local, vec!["main", "feat/x"]);
        assert_eq!(branches.remote, vec!["origin/main"]);
    }

    #[test]
    fn never_pushed_branch_has_no_upstream() {
        assert_eq!(
            parse_status("# branch.oid abc\n# branch.head feat\n").upstream,
            None
        );
    }
}
