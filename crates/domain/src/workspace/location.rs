use std::path::{Path, PathBuf};

use super::{BranchName, WorkspaceError};

/// Where new worktrees go: `~/wt/<repo>/<branch-slug>` unless the user
/// picks a path (absolute, or starting with `~`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WorktreeLocation {
    home: PathBuf,
}

impl WorktreeLocation {
    pub const DEFAULT_ROOT: &'static str = "wt";

    pub fn new(home: impl Into<PathBuf>) -> Self {
        Self { home: home.into() }
    }

    pub fn resolve(
        &self,
        requested: &str,
        repo_name: &str,
        branch: &BranchName,
    ) -> Result<PathBuf, WorkspaceError> {
        let requested = requested.trim();
        if requested.is_empty() {
            return Ok(self
                .home
                .join(Self::DEFAULT_ROOT)
                .join(repo_name)
                .join(branch.slug()));
        }
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
    fn expands_home_and_keeps_absolute_paths() {
        let location = WorktreeLocation::new("/home/me");
        assert_eq!(
            location.resolve("~/wt/x/y", "x", &branch("y")).unwrap(),
            PathBuf::from("/home/me/wt/x/y")
        );
        assert_eq!(
            location.resolve("/tmp/w", "x", &branch("y")).unwrap(),
            PathBuf::from("/tmp/w")
        );
        assert!(
            location
                .resolve("relative/path", "x", &branch("y"))
                .is_err()
        );
    }
}
