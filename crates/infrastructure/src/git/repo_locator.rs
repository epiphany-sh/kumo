use std::path::{Path, PathBuf};

use kumo_domain::terminal::RepoLocator;

/// [`RepoLocator`] from the `.git` on disk, without running git: a `.git`
/// folder is a repository's main checkout; a `.git` file points to a
/// worktree's git folder, whose `commondir` is the repository's.
#[derive(Debug, Default, Clone, Copy)]
pub struct GitDirLocator;

impl RepoLocator for GitDirLocator {
    fn repo_of(&self, dir: &Path) -> Option<PathBuf> {
        let checkout = dir.ancestors().find(|d| d.join(".git").exists())?;
        let dot_git = checkout.join(".git");
        if dot_git.is_dir() {
            return checkout.canonicalize().ok();
        }
        // "gitdir: <path>", relative to the checkout or absolute.
        let text = std::fs::read_to_string(&dot_git).ok()?;
        let git_dir = checkout.join(text.strip_prefix("gitdir:")?.trim());
        let common = match std::fs::read_to_string(git_dir.join("commondir")) {
            Ok(common) => git_dir.join(common.trim()),
            // A submodule: a repository of its own.
            Err(_) => return checkout.canonicalize().ok(),
        };
        let common = common.canonicalize().ok()?;
        match common.file_name() {
            Some(name) if name == ".git" => common.parent().map(Path::to_path_buf),
            _ => checkout.canonicalize().ok(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_folder_in_a_checkout_or_in_one_of_its_worktrees_is_the_repository() {
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path().canonicalize().unwrap();
        let repo = root.join("app");
        std::fs::create_dir_all(repo.join(".git/worktrees/feat")).unwrap();
        std::fs::create_dir_all(repo.join("src/deep")).unwrap();
        std::fs::write(repo.join(".git/worktrees/feat/commondir"), "../..\n").unwrap();
        let worktree = root.join("wt/app/feat");
        std::fs::create_dir_all(worktree.join("crates")).unwrap();
        std::fs::write(
            worktree.join(".git"),
            format!("gitdir: {}\n", repo.join(".git/worktrees/feat").display()),
        )
        .unwrap();

        let locator = GitDirLocator;
        assert_eq!(locator.repo_of(&repo.join("src/deep")), Some(repo.clone()));
        assert_eq!(
            locator.repo_of(&worktree.join("crates")),
            Some(repo.clone())
        );
        assert_eq!(locator.repo_of(&root.join("wt")), None);
    }

    #[test]
    fn a_submodule_is_a_repository_of_its_own() {
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path().canonicalize().unwrap();
        std::fs::create_dir_all(root.join(".git/modules/lib")).unwrap();
        std::fs::create_dir_all(root.join("lib")).unwrap();
        std::fs::write(root.join("lib/.git"), "gitdir: ../.git/modules/lib\n").unwrap();
        assert_eq!(
            GitDirLocator.repo_of(&root.join("lib")),
            Some(root.join("lib"))
        );
    }
}
