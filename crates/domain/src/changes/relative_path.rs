use std::fmt;
use std::path::{Component, Path, PathBuf};

use super::ChangesError;

/// A path inside a worktree, relative to its root. Never absolute, never
/// climbing out with `..`: clients can't reach files outside the worktree.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct RelativePath(PathBuf);

impl RelativePath {
    pub fn parse(raw: &str) -> Result<Self, ChangesError> {
        let invalid = || ChangesError::InvalidPath(raw.to_owned());
        if raw.trim().is_empty() || raw.contains('\0') {
            return Err(invalid());
        }
        let mut clean = PathBuf::new();
        for component in Path::new(raw).components() {
            match component {
                Component::Normal(part) => clean.push(part),
                Component::CurDir => {}
                Component::ParentDir | Component::RootDir | Component::Prefix(_) => {
                    return Err(invalid());
                }
            }
        }
        if clean.as_os_str().is_empty() {
            return Err(invalid());
        }
        Ok(Self(clean))
    }

    pub fn as_path(&self) -> &Path {
        &self.0
    }

    /// The absolute path under `root` (symlinks are the file store's job).
    pub fn under(&self, root: &Path) -> PathBuf {
        root.join(&self.0)
    }
}

impl fmt::Display for RelativePath {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        // Git and the UI use forward slashes everywhere.
        let parts: Vec<_> = self
            .0
            .components()
            .map(|c| c.as_os_str().to_string_lossy())
            .collect();
        f.write_str(&parts.join("/"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_paths_inside() {
        assert_eq!(
            RelativePath::parse("src/main.rs").unwrap().to_string(),
            "src/main.rs"
        );
        assert_eq!(RelativePath::parse("./a/./b").unwrap().to_string(), "a/b");
    }

    #[test]
    fn rejects_escapes() {
        for raw in [
            "",
            " ",
            "../x",
            "a/../../x",
            "/etc/passwd",
            "a/..",
            "a\0b",
            ".",
        ] {
            assert!(RelativePath::parse(raw).is_err(), "{raw:?}");
        }
    }
}
