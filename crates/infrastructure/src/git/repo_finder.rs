use std::path::{Path, PathBuf};

use kumo_domain::workspace::RepoFinder;

/// Walks folders looking for git repositories (a `.git` folder or file).
#[derive(Debug, Clone)]
pub struct FsRepoFinder {
    home: PathBuf,
    max_depth: usize,
    max_results: usize,
}

impl FsRepoFinder {
    /// Folder names developers usually keep code in, under the home folder.
    const USUAL_ROOTS: [&'static str; 10] = [
        "workspace",
        "dev",
        "code",
        "src",
        "projects",
        "Developer",
        "repos",
        "git",
        "github",
        "work",
    ];
    const SKIPPED: [&'static str; 6] = [
        "node_modules",
        "target",
        "build",
        "dist",
        "vendor",
        "Library",
    ];

    pub fn new(home: impl Into<PathBuf>) -> Self {
        Self {
            home: home.into(),
            max_depth: 3,
            max_results: 500,
        }
    }

    fn walk(&self, dir: &Path, depth: usize, found: &mut Vec<PathBuf>) {
        if found.len() >= self.max_results {
            return;
        }
        if dir.join(".git").exists() {
            found.push(dir.to_path_buf());
            return; // Don't descend into repositories.
        }
        if depth == self.max_depth {
            return;
        }
        let Ok(entries) = std::fs::read_dir(dir) else {
            return;
        };
        let mut children: Vec<PathBuf> = entries
            .filter_map(Result::ok)
            .filter(|e| e.file_type().is_ok_and(|t| t.is_dir()))
            .map(|e| e.path())
            .filter(|p| {
                let name = p
                    .file_name()
                    .map(|n| n.to_string_lossy())
                    .unwrap_or_default();
                !name.starts_with('.') && !Self::SKIPPED.contains(&name.as_ref())
            })
            .collect();
        children.sort();
        for child in children {
            self.walk(&child, depth + 1, found);
        }
    }
}

impl RepoFinder for FsRepoFinder {
    fn default_roots(&self) -> Vec<PathBuf> {
        Self::USUAL_ROOTS
            .iter()
            .map(|r| self.home.join(r))
            .filter(|p| p.is_dir())
            .collect()
    }

    fn find(&self, roots: &[PathBuf]) -> Vec<PathBuf> {
        let mut found = Vec::new();
        for root in roots {
            self.walk(root, 0, &mut found);
        }
        found
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_repositories_without_descending_into_them() {
        let root = tempfile::tempdir().unwrap();
        for dir in [
            "a/.git",
            "group/b/.git",
            "a/nested/.git",
            "node_modules/c/.git",
            ".hidden/d/.git",
        ] {
            std::fs::create_dir_all(root.path().join(dir)).unwrap();
        }
        let found = FsRepoFinder::new(root.path()).find(&[root.path().to_path_buf()]);
        let names: Vec<_> = found
            .iter()
            .map(|p| p.strip_prefix(root.path()).unwrap().to_owned())
            .collect();
        assert_eq!(names, vec![PathBuf::from("a"), PathBuf::from("group/b")]);
    }
}
