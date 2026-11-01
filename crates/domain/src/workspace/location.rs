use std::path::{Path, PathBuf};

use super::{BranchName, WorkspaceError};

/// Where new worktrees go: `~/wt/<repo>/<branch-slug>` unless the user
/// picks a path (absolute, or starting with `~`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WorktreeLocation {
    home: PathBuf,
    /// Where `<repo>/<branch>` folders go when no path is requested.
    root: PathBuf,
}

impl WorktreeLocation {
    pub const DEFAULT_ROOT: &'static str = "wt";

    /// Worktrees under `~/wt`.
    pub fn new(home: impl Into<PathBuf>) -> Self {
        let home = home.into();
        Self {
            root: home.join(Self::DEFAULT_ROOT),
            home,
        }
    }

    /// Worktrees under `root` (`~/…` or absolute) instead of `~/wt`.
    pub fn with_root(mut self, root: &str) -> Result<Self, WorkspaceError> {
        self.root = self.expand(root)?;
        Ok(self)
    }

    pub fn resolve(
        &self,
        requested: &str,
        repo_name: &str,
        branch: &BranchName,
    ) -> Result<PathBuf, WorkspaceError> {
        let requested = requested.trim();
        if requested.is_empty() {
            return Ok(self.root.join(repo_name).join(branch.slug()));
        }
        self.expand(requested)
    }

    /// `~`, `~/…` or an absolute path.
    fn expand(&self, requested: &str) -> Result<PathBuf, WorkspaceError> {
        let requested = requested.trim();
        if requested == "~" {
            return Ok(self.home.clone());
        }
        if let Some(rest) = requested.strip_prefix("~/") {
            return Ok(self.home.join(rest));
        }
        if Path::new(requested).is_absolute() {
            return Ok(PathBuf::from(requested));
        }
        Err(WorkspaceError::InvalidPath(requested.to_owned()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn branch(name: &str) -> BranchName {
        BranchName::parse(name).unwrap()
    }

    #[test]
    fn defaults_to_home_wt_repo_branch() {
        let location = WorktreeLocation::new("/home/me");
        let path = location
            .resolve("", "price-admin", &branch("feat/PRC-1"))
            .unwrap();
        assert_eq!(path, PathBuf::from("/home/me/wt/price-admin/feat-PRC-1"));
    }

    #[test]
    fn a_root_moves_the_default_folder_but_not_requested_paths() {
        let location = WorktreeLocation::new("/home/me")
            .with_root("~/wt/workspace-1")
            .unwrap();
        assert_eq!(
            location.resolve("", "api", &branch("main")).unwrap(),
            PathBuf::from("/home/me/wt/workspace-1/api/main")
        );
        assert_eq!(
            location.resolve("~/x", "api", &branch("main")).unwrap(),
            PathBuf::from("/home/me/x")
        );
        assert!(WorktreeLocation::new("/home/me").with_root("rel").is_err());
    }

    #[test]
    fn expands_home_and_keeps_absolute_paths() {
        let location = WorktreeLocation::new("/home/me");
        assert_eq!(
            location.resolve("~/wt/x/y", "x", &branch("y")).unwrap(),
            PathBuf::from("/home/me/wt/x/y")
        );
        // Absolute on every platform ("/tmp/w" has no drive on Windows).
        let absolute = std::env::temp_dir().join("w");
        assert_eq!(
            location
                .resolve(absolute.to_str().unwrap(), "x", &branch("y"))
                .unwrap(),
            absolute
        );
        assert!(
            location
                .resolve("relative/path", "x", &branch("y"))
                .is_err()
        );
    }
}
