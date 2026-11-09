//! [`RunGit`] for [`GitCli`]: what runs of your agents need from git.

use std::path::Path;

use kumo_domain::agent_defs::RunGit;

use super::GitCli;

/// The longest diff a run is given.
const MAX_DIFF: usize = 2 * 1024 * 1024;

impl RunGit for GitCli {
    fn clone_repo(&self, url: &str, dest: &Path) -> Result<(), String> {
        let parent = dest.parent().ok_or("no folder to clone into")?;
        std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        let dest = dest.display().to_string();
        self.exec(parent, ["clone", "-q", "--", url, &dest])
            .map(drop)
    }

    fn fetch(&self, repo: &Path, reference: &str) -> Result<String, String> {
        if reference.starts_with('-') {
            return Err(format!("not a ref: {reference}"));
        }
        self.exec(
            repo,
            [
                "fetch",
                "-q",
                "--no-recurse-submodules",
                "origin",
                reference,
            ],
        )?;
        Ok(self
            .exec(repo, ["rev-parse", "FETCH_HEAD"])?
            .trim()
            .to_owned())
    }

    fn update_branch(&self, repo: &Path, branch: &str) -> Result<(), String> {
        if branch.starts_with('-') {
            return Err(format!("not a branch: {branch}"));
        }
        let refspec = format!("+refs/heads/{branch}:refs/remotes/origin/{branch}");
        self.exec(
            repo,
            ["fetch", "-q", "--no-recurse-submodules", "origin", &refspec],
        )
        .map(drop)
    }

    fn origin_url(&self, repo: &Path) -> Result<String, String> {
        // Not `remote get-url`: that one rewrites it by `insteadOf`.
        Ok(self
            .exec(repo, ["config", "--get", "remote.origin.url"])?
            .trim()
            .to_owned())
    }

    fn diff(&self, repo: &Path, base: &str, head: &str) -> Result<String, String> {
        let range = format!("{base}...{head}");
        if range.starts_with('-') {
            return Err(format!("not a range: {range}"));
        }
        let mut diff = self.exec(repo, ["diff", "--no-color", "--no-ext-diff", &range])?;
        if diff.len() > MAX_DIFF {
            let mut cut = MAX_DIFF;
            while !diff.is_char_boundary(cut) {
                cut -= 1;
            }
            diff.truncate(cut);
            diff.push_str("\n… the diff goes on: it was cut here.\n");
        }
        Ok(diff)
    }

    fn add_detached(&self, repo: &Path, path: &Path, rev: &str) -> Result<(), String> {
        let path = path.display().to_string();
        self.exec(repo, ["worktree", "add", "--detach", "-q", &path, rev])
            .map(drop)
    }

    fn remove_worktree(&self, repo: &Path, path: &Path) -> Result<(), String> {
        let shown = path.display().to_string();
        let removed = self.exec(repo, ["worktree", "remove", "--force", &shown]);
        if removed.is_err() && path.exists() {
            std::fs::remove_dir_all(path).map_err(|e| e.to_string())?;
        }
        self.exec(repo, ["worktree", "prune"]).map(drop)
    }

    fn default_branch(&self, repo: &Path) -> Result<String, String> {
        let head = self.exec(
            repo,
            ["symbolic-ref", "--short", "refs/remotes/origin/HEAD"],
        );
        match head {
            Ok(head) => Ok(head.trim().trim_start_matches("origin/").to_owned()),
            // No origin HEAD (a local repo): the branch checked out.
            Err(_) => Ok(self
                .exec(repo, ["rev-parse", "--abbrev-ref", "HEAD"])?
                .trim()
                .to_owned()),
        }
    }
}

#[cfg(test)]
mod tests {
    use std::process::Command;

    use super::*;

    fn git(dir: &Path, args: &[&str]) {
        let out = Command::new("git")
            .args(args)
            .current_dir(dir)
            .env("GIT_AUTHOR_NAME", "T")
            .env("GIT_AUTHOR_EMAIL", "t@example.com")
            .env("GIT_COMMITTER_NAME", "T")
            .env("GIT_COMMITTER_EMAIL", "t@example.com")
            .output()
            .unwrap();
        assert!(
            out.status.success(),
            "git {args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
    }

    #[test]
    fn clones_fetches_a_pull_head_diffs_and_cleans_up() {
        let dir = tempfile::tempdir().unwrap();
        let origin = dir.path().join("origin");
        std::fs::create_dir(&origin).unwrap();
        git(&origin, &["init", "-q", "-b", "main"]);
        std::fs::write(origin.join("a.txt"), "one\n").unwrap();
        git(&origin, &["add", "."]);
        git(&origin, &["commit", "-q", "-m", "one"]);
        git(&origin, &["checkout", "-q", "-b", "feat"]);
        std::fs::write(origin.join("a.txt"), "two\n").unwrap();
        git(&origin, &["commit", "-q", "-am", "two"]);
        // Where a host keeps pull request 7's head.
        git(&origin, &["update-ref", "refs/pull/7/head", "feat"]);
        git(&origin, &["checkout", "-q", "main"]);

        let cli = GitCli::default();
        let clone = dir.path().join("clones/app");
        cli.clone_repo(&origin.display().to_string(), &clone)
            .unwrap();
        // The throwaway worktree checks out too.
        git(&clone, &["config", "core.autocrlf", "false"]);
        assert_eq!(cli.default_branch(&clone).unwrap(), "main");
        let head = cli.fetch(&clone, "refs/pull/7/head").unwrap();
        assert_eq!(head.len(), 40);
        let diff = cli.diff(&clone, "origin/main", &head).unwrap();
        assert!(diff.contains("-one\n+two"), "{diff}");

        let throwaway = dir.path().join("play-1");
        cli.add_detached(&clone, &throwaway, &head).unwrap();
        assert_eq!(
            std::fs::read_to_string(throwaway.join("a.txt")).unwrap(),
            "two\n"
        );
        std::fs::write(throwaway.join("b.txt"), "changed").unwrap();
        cli.remove_worktree(&clone, &throwaway).unwrap();
        assert!(!throwaway.exists());
        assert!(cli.fetch(&clone, "--upload-pack=x").is_err());
    }
}
