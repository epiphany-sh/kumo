use std::fmt;

use super::WorkspaceError;

/// A branch name git accepts (the common rules of `git check-ref-format`).
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct BranchName(String);

impl BranchName {
    pub fn parse(raw: &str) -> Result<Self, WorkspaceError> {
        let name = raw.trim();
        let invalid = |reason| WorkspaceError::InvalidBranch {
            name: name.to_owned(),
            reason,
        };
        if name.is_empty() {
            return Err(invalid("empty"));
        }
        if name == "@" || name.starts_with('-') || name.starts_with('/') || name.ends_with('/') {
            return Err(invalid(
                "can't start with '-' or '/', end with '/', or be '@'",
            ));
        }
        if name.ends_with('.') || name.ends_with(".lock") {
            return Err(invalid("can't end with '.' or '.lock'"));
        }
        if name.contains("..") || name.contains("@{") || name.contains("//") {
            return Err(invalid("can't contain '..', '@{' or '//'"));
        }
        if name
            .chars()
            .any(|c| c.is_control() || c.is_whitespace() || "~^:?*[\\".contains(c))
        {
            return Err(invalid("can't contain spaces or any of ~^:?*[\\"));
        }
        if name.split('/').any(|part| part.starts_with('.')) {
            return Err(invalid("path components can't start with '.'"));
        }
        Ok(Self(name.to_owned()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }

    /// A single path component for folders: `feat/PRC-1` → `feat-PRC-1`.
    pub fn slug(&self) -> String {
        self.0.replace('/', "-")
    }
}

impl fmt::Display for BranchName {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_usual_branches() {
        for name in [
            "main",
            "feat/PRC-412-bulk-discounts",
            "fix/v1.2",
            "user/x_y",
        ] {
            assert!(BranchName::parse(name).is_ok(), "{name}");
        }
        assert_eq!(BranchName::parse("feat/a/b").unwrap().slug(), "feat-a-b");
    }

    #[test]
    fn rejects_what_git_rejects() {
        for name in [
            "", "-x", "a..b", "a b", "a~1", "x.lock", "x/", "/x", "a//b", "a/.b", "@", "a@{1}",
            "a:b",
        ] {
            assert!(BranchName::parse(name).is_err(), "{name:?}");
        }
    }
}
