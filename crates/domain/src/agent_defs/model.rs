use std::path::{Path, PathBuf};

use crate::agents::AgentError;

/// Who can use an agent, and so where its file lives.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
pub enum AgentDefScope {
    /// The workspace's Claude Code folder: `<CLAUDE_CONFIG_DIR>/agents`.
    #[default]
    Personal,
    /// `<repo main checkout>/.claude/agents`.
    Project,
}

impl AgentDefScope {
    /// How the store keys it.
    pub fn key(self) -> &'static str {
        match self {
            Self::Personal => "personal",
            Self::Project => "project",
        }
    }
}

/// When an agent runs on its own. Saved; not run yet.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum AgentDefTrigger {
    PullRequest,
    Schedule,
}

/// Kumo's own settings for an agent: not subagent fields.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct AgentDefSettings {
    /// The daemon stops a run when it's up.
    pub max_minutes: Option<u32>,
    /// Headless runs only, where Claude Code takes a budget.
    pub max_cost_usd: Option<f64>,
    pub triggers: Vec<AgentDefTrigger>,
}

/// One agent wherever it's saved: what settings and test runs are kept
/// under.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct AgentDefKey {
    pub scope: AgentDefScope,
    /// Project agents: the repository's main checkout; empty for personal.
    pub repo_path: String,
    pub name: String,
}

impl AgentDefKey {
    pub fn new(scope: AgentDefScope, repo_path: Option<&Path>, name: &str) -> Self {
        Self {
            scope,
            repo_path: match scope {
                AgentDefScope::Personal => String::new(),
                AgentDefScope::Project => repo_path
                    .map(|p| p.display().to_string())
                    .unwrap_or_default(),
            },
            name: name.to_owned(),
        }
    }
}

/// An agent file: the Markdown as is, plus Kumo's settings for it.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct AgentDefFile {
    pub scope: AgentDefScope,
    /// Project agents: the repository's main checkout.
    pub repo_path: Option<PathBuf>,
    pub repo_name: String,
    /// The file's stem: what `claude --agent <name>` takes.
    pub name: String,
    pub markdown: String,
    pub settings: AgentDefSettings,
    pub file_path: PathBuf,
    pub modified_unix_ms: i64,
}

impl AgentDefFile {
    pub fn key(&self) -> AgentDefKey {
        AgentDefKey::new(self.scope, self.repo_path.as_deref(), &self.name)
    }
}

/// A file found in an agents folder.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FoundFile {
    /// Its stem.
    pub name: String,
    pub markdown: String,
    pub path: PathBuf,
    pub modified_unix_ms: i64,
}

/// Refuses anything Claude Code wouldn't take as a name (and so anything
/// that could leave the folder: `..`, `/`).
pub fn check_agent_name(name: &str) -> Result<(), AgentError> {
    let mut chars = name.chars();
    let ok = chars.next().is_some_and(|c| c.is_ascii_lowercase())
        && chars.all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-');
    if ok {
        Ok(())
    } else {
        Err(AgentError::Invalid(format!(
            "“{name}” isn’t an agent name: lowercase letters, digits and hyphens, starting with a letter"
        )))
    }
}

/// The agents folder of a scope: `<claude dir>/agents` or
/// `<repo>/.claude/agents`.
pub fn agents_dir(scope: AgentDefScope, claude_dir: &Path, repo: Option<&Path>) -> Option<PathBuf> {
    match scope {
        AgentDefScope::Personal => Some(claude_dir.join("agents")),
        AgentDefScope::Project => repo.map(|r| r.join(".claude").join("agents")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names_are_what_claude_code_takes() {
        for ok in ["a", "go-pr-reviewer", "x2", "a-b-c"] {
            assert!(check_agent_name(ok).is_ok(), "{ok}");
        }
        for bad in [
            "", "..", "a/b", "../x", "Upper", "2x", "-a", "a_b", "a b", "a.md",
        ] {
            assert!(check_agent_name(bad).is_err(), "{bad}");
        }
    }

    #[test]
    fn keys_ignore_the_repo_of_a_personal_agent() {
        let repo = Path::new("/w/app");
        assert_eq!(
            AgentDefKey::new(AgentDefScope::Personal, Some(repo), "x").repo_path,
            ""
        );
        assert_eq!(
            AgentDefKey::new(AgentDefScope::Project, Some(repo), "x").repo_path,
            "/w/app"
        );
        assert_eq!(
            agents_dir(AgentDefScope::Project, Path::new("/c"), Some(repo)).unwrap(),
            Path::new("/w/app/.claude/agents")
        );
        assert_eq!(
            agents_dir(AgentDefScope::Personal, Path::new("/c"), None).unwrap(),
            Path::new("/c/agents")
        );
    }
}
