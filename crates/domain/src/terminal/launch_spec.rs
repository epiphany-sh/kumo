use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use super::{TerminalError, TerminalSize};

/// Value of `TERM` when the caller does not set one.
pub const DEFAULT_TERM: &str = "xterm-256color";

/// What to run in a new terminal and how.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LaunchSpec {
    program: String,
    args: Vec<String>,
    cwd: Option<PathBuf>,
    env: BTreeMap<String, String>,
    size: TerminalSize,
}

impl LaunchSpec {
    pub fn new(program: impl Into<String>) -> Result<Self, TerminalError> {
        let program = program.into();
        if program.trim().is_empty() {
            return Err(TerminalError::InvalidLaunchSpec(
                "program must not be empty".into(),
            ));
        }
        Ok(Self {
            program,
            args: Vec::new(),
            cwd: None,
            env: BTreeMap::new(),
            size: TerminalSize::DEFAULT,
        })
    }

    pub fn with_args(mut self, args: impl IntoIterator<Item = impl Into<String>>) -> Self {
        self.args = args.into_iter().map(Into::into).collect();
        self
    }

    /// `None` means the daemon's own working directory.
    pub fn with_cwd(mut self, cwd: Option<PathBuf>) -> Self {
        self.cwd = cwd;
        self
    }

    pub fn with_env(mut self, env: impl IntoIterator<Item = (String, String)>) -> Self {
        self.env = env.into_iter().collect();
        self
    }

    pub fn with_size(mut self, size: TerminalSize) -> Self {
        self.size = size;
        self
    }

    pub fn program(&self) -> &str {
        &self.program
    }

    pub fn args(&self) -> &[String] {
        &self.args
    }

    pub fn cwd(&self) -> Option<&Path> {
        self.cwd.as_deref()
    }

    pub fn size(&self) -> TerminalSize {
        self.size
    }

    /// Variables to add on top of the inherited environment. Always sets
    /// `TERM` (defaulting to [`DEFAULT_TERM`]).
    pub fn effective_env(&self) -> BTreeMap<String, String> {
        let mut env = self.env.clone();
        env.entry("TERM".to_owned())
            .or_insert_with(|| DEFAULT_TERM.to_owned());
        env
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_empty_program() {
        assert!(LaunchSpec::new(" ").is_err());
    }

    #[test]
    fn defaults_term_but_respects_caller() {
        let spec = LaunchSpec::new("sh").unwrap();
        assert_eq!(spec.effective_env()["TERM"], DEFAULT_TERM);

        let spec = spec.with_env([("TERM".to_owned(), "dumb".to_owned())]);
        assert_eq!(spec.effective_env()["TERM"], "dumb");
    }
}
