//! The CLIs your agents run on. An agent is one definition; each CLI says how
//! to start it and how to read how it ended. One file per CLI, so a change to
//! one can't reach the others.

mod claude;

use std::path::Path;

use super::PlayCommand;

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
    /// An agent in a terminal of its own. With no prompt the user types.
    fn run_args(
        &self,
        name: &str,
        inline_json: &str,
        context_dir: Option<&Path>,
        prompt: &str,
    ) -> Vec<String>;
    /// A headless test run. `budget`: the installed CLI takes
    /// [`Self::budget_flag`].
    fn play_args(&self, play: &PlayCommand, budget: bool) -> Vec<String>;
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
        assert!(agent_cli("my-own-cli").is_none());
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
            "claude;rm -rf /",
        ] {
            assert!(agent_cli(hostile).is_none(), "{hostile:?}");
        }
    }
}
