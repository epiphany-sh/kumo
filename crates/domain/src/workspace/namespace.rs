use std::fmt;
use std::path::PathBuf;

/// Identifier of a namespace.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct NamespaceId(String);

impl NamespaceId {
    pub fn generate() -> Self {
        Self(uuid::Uuid::new_v4().simple().to_string())
    }

    /// Ids come from the store or from clients; any non-blank string works.
    pub fn parse(raw: &str) -> Option<Self> {
        let raw = raw.trim();
        (!raw.is_empty()).then(|| Self(raw.to_owned()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for NamespaceId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// A user-defined group of repositories in the sidebar.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Namespace {
    pub id: NamespaceId,
    pub name: String,
    /// Repository paths, in sidebar order, without duplicates.
    pub repos: Vec<PathBuf>,
    pub collapsed: bool,
}

impl Namespace {
    /// A blank name becomes "untitled"; repeated repositories are dropped.
    pub fn new(
        id: NamespaceId,
        name: &str,
        repos: impl IntoIterator<Item = PathBuf>,
        collapsed: bool,
    ) -> Self {
        let name = match name.trim() {
            "" => "untitled".to_owned(),
            trimmed => trimmed.to_owned(),
        };
        let mut unique = Vec::new();
        for repo in repos {
            if !unique.contains(&repo) {
                unique.push(repo);
            }
        }
        Self {
            id,
            name,
            repos: unique,
            collapsed,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_name_and_repos() {
        let ns = Namespace::new(
            NamespaceId::generate(),
            "  ",
            [
                PathBuf::from("/a"),
                PathBuf::from("/b"),
                PathBuf::from("/a"),
            ],
            false,
        );
        assert_eq!(ns.name, "untitled");
        assert_eq!(ns.repos, vec![PathBuf::from("/a"), PathBuf::from("/b")]);
    }
}
