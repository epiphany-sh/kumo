//! What the command lines of your agents share, whatever CLI they run on.
//! Pure, so they can be checked as text.

use std::path::Path;

/// What the first message adds when the run was given context.
pub fn context_sentence(dir: &Path) -> String {
    format!(
        "What you were given for this run is in {}: start with context.md.",
        dir.display()
    )
}

/// Keeps a run on its agent's job. A loose request ("analyze this repo") went
/// by the words about one time in four without it, and never in 15 runs with
/// it (Haiku): what's typed outweighs the role otherwise.
pub fn role_sentence(name: &str) -> String {
    format!(
        "You are running as the agent `{name}`. Read every request through that role: \
         \"analyze this repo\" means do your job on this repo, not a general review. \
         If a request is clearly outside your role, say so instead of doing it."
    )
}

/// What a headless test run takes.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct PlayCommand {
    pub name: String,
    pub inline_json: String,
    pub task: String,
    pub context_dir: Option<std::path::PathBuf>,
    pub max_turns: Option<u32>,
    /// Passed when the installed CLI has a budget flag.
    pub max_cost_usd: Option<f64>,
}

/// A name for a run's folder or worktree that isn't taken: `<name>-<n>`,
/// from 1.
pub fn next_free(name: &str, taken: impl Fn(&str) -> bool) -> String {
    (1..)
        .map(|n| format!("{name}-{n}"))
        .find(|candidate| !taken(candidate))
        .unwrap_or_else(|| name.to_owned())
}
