use std::path::{Path, PathBuf};

use super::Remote;

/// A git repository the user added to the workspace.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Repo {
    /// Absolute, canonical path of the main checkout: the identity.
    pub path: PathBuf,
    pub name: String,
    pub remote: Option<Remote>,
}

impl Repo {
    pub fn new(path: PathBuf, remote: Option<Remote>) -> Self {
        let name = Self::name_for(&path);
        Self { path, name, remote }
    }

    /// The folder name, like git hosts and the sidebar show it.
    pub fn name_for(path: &Path) -> String {
        path.file_name().map_or_else(
            || path.display().to_string(),
            |n| n.to_string_lossy().into_owned(),
        )
    }
}
