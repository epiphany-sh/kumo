//! The CLIs your agents run on. An agent is one definition; each CLI says how
//! to start it and how to read how it ended. One file per CLI, so a change to
//! one can't reach the others.

mod claude;
mod codex;
mod copilot;
mod spec;

use std::path::{Path, PathBuf};

use super::{AgentFiles, PlayCommand};
use crate::agents::AgentError;

/// The CLI a run uses when the request doesn't name one.
pub const DEFAULT_CLI: &str = claude::PROVIDER_ID;

/// What Kumo needs to know about a CLI to run your agents on it. Pure: it
/// builds text, and starting the program is someone else's job.
pub trait AgentCli: Send + Sync + std::fmt::Debug {
    /// The provider it runs as (see [`AgentPreset`](crate::agents::AgentPreset)).
    fn provider_id(&self) -> &'static str;
    /// Its name, as messages say it.
    fn name(&self) -> &'static str;
    /// What a sentence calls whoever answers ("… didn't answer").
    fn speaker(&self) -> &'static str;
    /// The files a CLI reads the agent from when it can't take it on the
    /// command line, as (path in their folder, contents), for the agent to be
    /// known there as `id`, told about `context_dir`. None for most: the
    /// agent goes in the arguments. What these files say is the agent's
    /// limits, so they're written fresh for each run, never read back.
    fn agent_files(
        &self,
        _name: &str,
        _inline_json: &str,
        _id: &str,
        _context_dir: Option<&Path>,
    ) -> Result<Vec<(PathBuf, String)>, AgentError> {
        Ok(Vec::new())
    }
    /// An agent in a terminal of its own. With no prompt the user types.
    /// `inline_json` is the agent as `claude --agents` takes it; a CLI that
    /// can't run it refuses. `files`: where [`Self::agent_files`] were
    /// written, when there were any.
    fn run_args(
        &self,
        name: &str,
        inline_json: &str,
        context_dir: Option<&Path>,
        prompt: &str,
        files: Option<&AgentFiles>,
    ) -> Result<Vec<String>, AgentError>;
    /// Refuses an agent it can't run, before anything is made for it.
    fn check(&self, name: &str, inline_json: &str) -> Result<(), AgentError> {
        let files = self.agent_files(name, inline_json, name, None)?;
        let written = AgentFiles {
            dir: PathBuf::new(),
            id: name.to_owned(),
        };
        let files = (!files.is_empty()).then_some(&written);
        self.run_args(name, inline_json, None, "", files).map(drop)
    }
    /// A headless test run. `budget`: the installed CLI takes
    /// [`Self::budget_flag`].
    fn play_args(&self, play: &PlayCommand, budget: bool) -> Result<Vec<String>, AgentError>;
    /// One answer, changing nothing.
    fn ask_args(&self, prompt: &str) -> Vec<String>;
    /// The flag a headless run's spending cap goes in, if it has one. Whether
    /// the installed version takes it is asked once.
    fn budget_flag(&self) -> Option<&'static str>;
    /// This line of a headless run says how it ended.
    fn is_result_line(&self, line: &str) -> bool;
    /// A line for a run that ended without a result line (it refused a flag,
    /// it wasn't signed in): its error, as a failed result of this CLI's.
    fn failure_line(&self, code: i32, stderr: &str) -> String;
}

/// The CLI of a provider, when your agents can run on it. Empty: the default.
pub fn agent_cli(provider_id: &str) -> Option<&'static dyn AgentCli> {
    match provider_id {
        "" | claude::PROVIDER_ID => Some(&claude::ClaudeCode),
        codex::PROVIDER_ID => Some(&codex::Codex),
        copilot::PROVIDER_ID => Some(&copilot::Copilot),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn no_provider_means_the_default_and_others_cant_run_agents_yet() {
        let default = agent_cli("").unwrap();
        assert_eq!(default.provider_id(), DEFAULT_CLI);
        assert_eq!(agent_cli("claude").unwrap().provider_id(), "claude");
        assert_eq!(agent_cli("codex").unwrap().provider_id(), "codex");
        assert_eq!(agent_cli("copilot").unwrap().provider_id(), "copilot");
        assert!(agent_cli("my-own-cli").is_none());
        assert!(agent_cli("gemini").is_none());
    }

    #[test]
    fn a_provider_id_is_only_ever_matched_exactly() {
        for hostile in [
            "../claude",
            "../../bin/sh",
            "/bin/sh",
            "--yolo",
            "CLAUDE",
            "Claude",
            "claude ",
            " claude",
            "claude\n",
            "claude\0",
            "Codex",
            "codex ",
            "../codex",
            "Copilot",
            "copilot\n",
            "github-copilot",
            "claude;rm -rf /",
        ] {
            assert!(agent_cli(hostile).is_none(), "{hostile:?}");
        }
    }
}
