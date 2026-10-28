//! The checked-out branch as git sees it locally, for pipelines.

use std::path::Path;

use kumo_domain::pipelines::{BranchReader, LocalBranch};

use super::GitCli;

impl BranchReader for GitCli {
    fn read(&self, worktree: &Path) -> Result<LocalBranch, String> {
        let text = |args: &[&str]| -> Option<String> {
            let out = self.exec(worktree, args).ok()?;
            let out = out.trim();
            (!out.is_empty()).then(|| out.to_owned())
        };
        // Fails outside a repository: nothing else to read then.
        self.exec(worktree, ["rev-parse", "--git-dir"])?;
        Ok(LocalBranch {
            name: text(&["symbolic-ref", "--quiet", "--short", "HEAD"]),
            upstream: text(&["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"]),
            unpushed: text(&["rev-list", "--count", "HEAD", "--not", "--remotes"])
                .and_then(|n| n.parse().ok())
                .unwrap_or(0),
        })
    }
}

#[cfg(test)]
mod tests {
    use std::process::Command;

    use super::*;

    fn git(dir: &Path, args: &[&str]) {
        let ok = Command::new("git")
            .arg("-C")
            .arg(dir)
            .args(args)
            .output()
            .unwrap()
            .status
            .success();
        assert!(ok, "git {args:?}");
    }

    #[test]
    fn reads_the_upstream_and_what_was_never_pushed() {
        let dir = tempfile::tempdir().unwrap();
        let (remote, work) = (dir.path().join("remote.git"), dir.path().join("work"));
        git(
            dir.path(),
            &["init", "-q", "--bare", remote.to_str().unwrap()],
        );
        git(
            dir.path(),
            &["init", "-q", "-b", "main", work.to_str().unwrap()],
        );
        for args in [
            &["config", "user.email", "t@kumo.dev"][..],
            &["config", "user.name", "T"],
            &["commit", "-q", "--allow-empty", "-m", "one"],
            &["remote", "add", "origin", remote.to_str().unwrap()],
            &["switch", "-q", "-c", "feat/x"],
            &["commit", "-q", "--allow-empty", "-m", "two"],
        ] {
            git(&work, args);
        }
        let local = GitCli::default().read(&work).unwrap();
        assert_eq!(
            local,
            LocalBranch {
                name: Some("feat/x".into()),
                upstream: None,
                unpushed: 2
            }
        );
        assert_eq!(local.remote_name(), Some("feat/x"));

        git(
            &work,
            &["push", "-q", "-u", "origin", "feat/x:feat/remote-x"],
        );
        git(&work, &["commit", "-q", "--allow-empty", "-m", "three"]);
        let pushed = GitCli::default().read(&work).unwrap();
        assert_eq!(pushed.upstream.as_deref(), Some("origin/feat/remote-x"));
        assert_eq!(
            (pushed.unpushed, pushed.remote_name()),
            (1, Some("feat/remote-x"))
        );
        assert!(
            GitCli::default().read(dir.path()).is_err(),
            "not a repository"
        );
    }
}
