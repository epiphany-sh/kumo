use std::io::Read;
use std::path::{Path, PathBuf};

use kumo_domain::changes::{ChangesError, FileContent, FileStore, RelativePath};

/// [`FileStore`] on the local disk. Resolves symlinks and refuses anything
/// that ends up outside the worktree.
#[derive(Debug, Default, Clone, Copy)]
pub struct LocalFileStore;

impl LocalFileStore {
    /// `path` under `worktree`, checked after resolving symlinks. For files
    /// that don't exist yet, the nearest existing ancestor is checked.
    fn inside(worktree: &Path, path: &RelativePath) -> Result<PathBuf, ChangesError> {
        let root = std::fs::canonicalize(worktree).map_err(|e| io_error(worktree, e))?;
        let target = path.under(&root);
        let mut existing = target.as_path();
        while !existing.exists() {
            existing = existing.parent().unwrap_or(&root);
        }
        let resolved = std::fs::canonicalize(existing).map_err(|e| io_error(existing, e))?;
        if !resolved.starts_with(&root) {
            return Err(ChangesError::InvalidPath(path.to_string()));
        }
        Ok(target)
    }

    /// The worktree's git folder isn't a file to move or delete.
    fn not_git_dir(path: &RelativePath) -> Result<(), ChangesError> {
        let first = path.as_path().components().next();
        // Case-insensitive: `.GIT` is the same folder on macOS and Windows.
        if first.is_some_and(|c| c.as_os_str().eq_ignore_ascii_case(".git")) {
            return Err(ChangesError::InvalidPath(path.to_string()));
        }
        Ok(())
    }
}

impl FileStore for LocalFileStore {
    fn read(
        &self,
        worktree: &Path,
        path: &RelativePath,
        max_bytes: usize,
    ) -> Result<FileContent, ChangesError> {
        let target = Self::inside(worktree, path)?;
        let file = std::fs::File::open(&target).map_err(|e| io_error(&target, e))?;
        let size = file.metadata().map_err(|e| io_error(&target, e))?.len();
        let mut bytes =
            Vec::with_capacity(usize::try_from(size).unwrap_or(max_bytes).min(max_bytes));
        file.take(max_bytes as u64)
            .read_to_end(&mut bytes)
            .map_err(|e| io_error(&target, e))?;
        let binary = bytes.iter().take(8000).any(|b| *b == 0);
        Ok(FileContent {
            truncated: (bytes.len() as u64) < size,
            bytes,
            binary,
            size,
        })
    }

    fn write(
        &self,
        worktree: &Path,
        path: &RelativePath,
        bytes: &[u8],
    ) -> Result<(), ChangesError> {
        let target = Self::inside(worktree, path)?;
        if let Some(parent) = target.parent() {
            std::fs::create_dir_all(parent).map_err(|e| io_error(parent, e))?;
        }
        std::fs::write(&target, bytes).map_err(|e| io_error(&target, e))
    }

    fn rename(
        &self,
        worktree: &Path,
        from: &RelativePath,
        to: &RelativePath,
    ) -> Result<(), ChangesError> {
        Self::not_git_dir(from)?;
        Self::not_git_dir(to)?;
        let source = Self::inside(worktree, from)?;
        let target = Self::inside(worktree, to)?;
        std::fs::symlink_metadata(&source).map_err(|e| io_error(&source, e))?;
        if target != source && target.starts_with(&source) {
            // A folder can't go inside itself.
            return Err(ChangesError::InvalidPath(to.to_string()));
        }
        // On case-insensitive disks `Foo.rs` → `foo.rs` finds the file
        // itself: that's a rename, not an overwrite.
        if let Ok(existing) = std::fs::symlink_metadata(&target)
            && !same_file(&source, &target, &existing)
        {
            return Err(ChangesError::Io(format!("{to} already exists")));
        }
        if let Some(parent) = target.parent() {
            std::fs::create_dir_all(parent).map_err(|e| io_error(parent, e))?;
        }
        std::fs::rename(&source, &target).map_err(|e| io_error(&source, e))
    }

    fn remove(&self, worktree: &Path, path: &RelativePath) -> Result<(), ChangesError> {
        Self::not_git_dir(path)?;
        let target = Self::inside(worktree, path)?;
        // A symlink goes away itself; what it points to stays.
        let meta = std::fs::symlink_metadata(&target).map_err(|e| io_error(&target, e))?;
        if meta.is_dir() {
            std::fs::remove_dir_all(&target)
        } else {
            std::fs::remove_file(&target)
        }
        .map_err(|e| io_error(&target, e))
    }
}

/// `existing` (metadata of the target) is `source` itself.
#[cfg(unix)]
fn same_file(source: &Path, _target: &Path, existing: &std::fs::Metadata) -> bool {
    use std::os::unix::fs::MetadataExt;
    std::fs::symlink_metadata(source)
        .is_ok_and(|s| s.dev() == existing.dev() && s.ino() == existing.ino())
}

/// Without inodes: the same path but for its case (Windows disks ignore case).
#[cfg(not(unix))]
fn same_file(source: &Path, target: &Path, _existing: &std::fs::Metadata) -> bool {
    source
        .to_string_lossy()
        .eq_ignore_ascii_case(&target.to_string_lossy())
}

fn io_error(path: &Path, error: std::io::Error) -> ChangesError {
    ChangesError::Io(format!("{}: {error}", path.display()))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rel(p: &str) -> RelativePath {
        RelativePath::parse(p).unwrap()
    }

    #[test]
    fn reads_and_writes_inside_the_worktree() {
        let dir = tempfile::tempdir().unwrap();
        let store = LocalFileStore;
        store
            .write(dir.path(), &rel("src/new.txt"), b"hello")
            .unwrap();
        let content = store.read(dir.path(), &rel("src/new.txt"), 1024).unwrap();
        assert_eq!(
            (content.bytes.as_slice(), content.size, content.truncated),
            (&b"hello"[..], 5, false)
        );
        assert!(
            store
                .read(dir.path(), &rel("src/new.txt"), 2)
                .unwrap()
                .truncated
        );
    }

    #[test]
    fn renames_moves_and_removes_files_and_folders() {
        let dir = tempfile::tempdir().unwrap();
        let store = LocalFileStore;
        store.write(dir.path(), &rel("src/a.rs"), b"a").unwrap();
        store.write(dir.path(), &rel("src/b.rs"), b"b").unwrap();

        store
            .rename(dir.path(), &rel("src/a.rs"), &rel("src/core/a2.rs"))
            .unwrap();
        assert!(!dir.path().join("src/a.rs").exists());
        assert_eq!(
            std::fs::read(dir.path().join("src/core/a2.rs")).unwrap(),
            b"a"
        );
        assert!(
            matches!(
                store.rename(dir.path(), &rel("src/b.rs"), &rel("src/core/a2.rs")),
                Err(ChangesError::Io(_))
            ),
            "never overwrites"
        );
        assert!(matches!(
            store.rename(dir.path(), &rel("src"), &rel("src/inner")),
            Err(ChangesError::InvalidPath(_))
        ));
        store.rename(dir.path(), &rel("src"), &rel("lib")).unwrap();
        assert!(dir.path().join("lib/core/a2.rs").exists());

        store.remove(dir.path(), &rel("lib/b.rs")).unwrap();
        assert!(!dir.path().join("lib/b.rs").exists());
        store.remove(dir.path(), &rel("lib")).unwrap();
        assert!(!dir.path().join("lib").exists());
        assert!(store.remove(dir.path(), &rel("lib")).is_err());
    }

    #[test]
    fn leaves_the_git_folder_alone() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join(".git")).unwrap();
        let store = LocalFileStore;
        assert!(matches!(
            store.remove(dir.path(), &rel(".git")),
            Err(ChangesError::InvalidPath(_))
        ));
        assert!(matches!(
            store.rename(dir.path(), &rel(".git"), &rel("git")),
            Err(ChangesError::InvalidPath(_))
        ));
        assert!(matches!(
            store.remove(dir.path(), &rel(".GIT")),
            Err(ChangesError::InvalidPath(_))
        ));
        assert!(dir.path().join(".git").exists());
    }

    #[cfg(unix)]
    #[test]
    fn refuses_symlinks_that_escape() {
        let outside = tempfile::tempdir().unwrap();
        std::fs::write(outside.path().join("secret"), "x").unwrap();
        let worktree = tempfile::tempdir().unwrap();
        std::os::unix::fs::symlink(outside.path(), worktree.path().join("link")).unwrap();
        let store = LocalFileStore;
        assert!(matches!(
            store.read(worktree.path(), &rel("link/secret"), 10),
            Err(ChangesError::InvalidPath(_))
        ));
        assert!(matches!(
            store.write(worktree.path(), &rel("link/new"), b"x"),
            Err(ChangesError::InvalidPath(_))
        ));
    }
}
