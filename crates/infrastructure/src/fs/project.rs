use std::fs;
use std::path::{Component, Path};

use kumo_domain::test_runs::ProjectReader;

/// Project files bigger than this aren't read (a Makefile or manifest is
/// far smaller).
const MAX_BYTES: u64 = 256 * 1024;

/// Reads small files at the top of worktrees, to find their test command.
#[derive(Debug, Default)]
pub struct LocalProjectReader;

impl ProjectReader for LocalProjectReader {
    fn read(&self, worktree: &Path, relative: &str) -> Option<String> {
        let relative = Path::new(relative);
        if !relative
            .components()
            .all(|c| matches!(c, Component::Normal(_)))
        {
            return None;
        }
        let path = worktree.join(relative);
        let meta = fs::metadata(&path).ok()?;
        if !meta.is_file() || meta.len() > MAX_BYTES {
            return None;
        }
        fs::read_to_string(path).ok()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_small_files_inside_the_worktree_only() {
        let dir = tempfile::tempdir().unwrap();
        fs::write(dir.path().join("Makefile"), "test:\n").unwrap();
        fs::create_dir(dir.path().join("sub")).unwrap();
        let reader = LocalProjectReader;
        assert_eq!(
            reader.read(dir.path(), "Makefile").as_deref(),
            Some("test:\n")
        );
        assert_eq!(reader.read(dir.path(), "sub"), None, "folders aren't files");
        assert_eq!(reader.read(dir.path(), "go.mod"), None);
        assert_eq!(reader.read(&dir.path().join("sub"), "../Makefile"), None);
    }
}
