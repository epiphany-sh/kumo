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
