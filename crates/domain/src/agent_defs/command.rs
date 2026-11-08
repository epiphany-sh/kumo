//! The `claude` command lines Kumo runs for your agents. Pure, so they can
//! be checked as text.

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

/// `claude [--agents <json>] --agent <name> [--add-dir <dir>]
/// --append-system-prompt <text> [<prompt>]`: an agent in a terminal of its
/// own. With no prompt the user types; the context folder is then pointed at
/// in the system prompt instead.
pub fn run_args(
    name: &str,
    inline_json: &str,
    context_dir: Option<&Path>,
    prompt: &str,
) -> Vec<String> {
    let mut args = Vec::new();
    if !inline_json.trim().is_empty() {
        args.extend(["--agents".to_owned(), inline_json.to_owned()]);
    }
    args.extend(["--agent".to_owned(), name.to_owned()]);
    let prompt = prompt.trim();
    let mut system = role_sentence(name);
    if let Some(dir) = context_dir {
        args.extend(["--add-dir".to_owned(), dir.display().to_string()]);
        if prompt.is_empty() {
            system = format!("{system} {}", context_sentence(dir));
        }
    }
    args.extend(["--append-system-prompt".to_owned(), system]);
    if !prompt.is_empty() {
        args.push(match context_dir {
            Some(dir) => format!("{prompt}\n\n{}", context_sentence(dir)),
            None => prompt.to_owned(),
        });
    }
    args
}

/// What a headless test run takes.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct PlayCommand {
    pub name: String,
    pub inline_json: String,
    pub task: String,
    pub context_dir: Option<std::path::PathBuf>,
    pub max_turns: Option<u32>,
    /// Passed when the installed Claude Code has a budget flag.
    pub max_cost_usd: Option<f64>,
}

/// `claude -p --agents <json> --agent <name> --output-format stream-json
/// --verbose --append-system-prompt <text> [--max-turns N] [--max-budget-usd X]
/// [--add-dir <dir>] <task>`.
pub fn play_args(play: &PlayCommand, budget_flag: bool) -> Vec<String> {
    let mut args = vec!["-p".to_owned()];
    if !play.inline_json.trim().is_empty() {
        args.extend(["--agents".to_owned(), play.inline_json.clone()]);
    }
    args.extend([
        "--agent".to_owned(),
        play.name.clone(),
        "--output-format".to_owned(),
        "stream-json".to_owned(),
        "--verbose".to_owned(),
        "--append-system-prompt".to_owned(),
        role_sentence(&play.name),
    ]);
    if let Some(turns) = play.max_turns {
        args.extend(["--max-turns".to_owned(), turns.to_string()]);
    }
    if budget_flag && let Some(usd) = play.max_cost_usd.filter(|u| *u > 0.0) {
        args.extend(["--max-budget-usd".to_owned(), format!("{usd}")]);
    }
    let mut task = play.task.trim().to_owned();
    if let Some(dir) = &play.context_dir {
        args.extend(["--add-dir".to_owned(), dir.display().to_string()]);
        task = format!("{task}\n\n{}", context_sentence(dir));
    }
    // After `--`: a task starting with `-` is still the task.
    args.extend(["--".to_owned(), task]);
    args
}

/// `claude -p --output-format text --permission-mode plan -- <prompt>`: one
/// answer, changing nothing.
pub fn ask_args(prompt: &str) -> Vec<String> {
    [
        "-p",
        "--output-format",
        "text",
        "--permission-mode",
        "plan",
        "--",
        prompt.trim(),
    ]
    .map(str::to_owned)
    .to_vec()
}

/// A name for a run's folder or worktree that isn't taken: `<name>-<n>`,
/// from 1.
pub fn next_free(name: &str, taken: impl Fn(&str) -> bool) -> String {
    (1..)
        .map(|n| format!("{name}-{n}"))
        .find(|candidate| !taken(candidate))
        .unwrap_or_else(|| name.to_owned())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_run_by_name_with_a_prompt_and_context() {
        let dir = Path::new("/d/runs/rev-1");
        assert_eq!(
            run_args("rev", "", Some(dir), " Review #521 "),
            [
                "--agent",
                "rev",
                "--add-dir",
                "/d/runs/rev-1",
                "--append-system-prompt",
                &role_sentence("rev"),
                "Review #521\n\nWhat you were given for this run is in /d/runs/rev-1: start with context.md."
            ]
        );
    }

    #[test]
    fn inline_without_prompt_or_context() {
        assert_eq!(
            run_args("rev", "{\"rev\":{}}", None, ""),
            [
                "--agents",
                "{\"rev\":{}}",
                "--agent",
                "rev",
                "--append-system-prompt",
                &role_sentence("rev"),
            ]
        );
        let with_context = run_args("rev", "", Some(Path::new("/c")), "");
        assert_eq!(&with_context[2..4], ["--add-dir", "/c"]);
        assert_eq!(with_context[4], "--append-system-prompt");
        assert!(with_context[5].starts_with(&role_sentence("rev")));
        assert!(with_context[5].ends_with("start with context.md."));
        assert_eq!(
            with_context.len(),
            6,
            "no positional prompt: the user types"
        );
    }

    #[test]
    fn a_play_streams_json_within_its_limits() {
        let play = PlayCommand {
            name: "rev".into(),
            inline_json: "{}".into(),
            task: "-check it".into(),
            max_turns: Some(8),
            max_cost_usd: Some(0.5),
            ..Default::default()
        };
        assert_eq!(
            play_args(&play, true),
            [
                "-p",
                "--agents",
                "{}",
                "--agent",
                "rev",
                "--output-format",
                "stream-json",
                "--verbose",
                "--append-system-prompt",
                &role_sentence("rev"),
                "--max-turns",
                "8",
                "--max-budget-usd",
                "0.5",
                "--",
                "-check it"
            ]
        );
        assert!(!play_args(&play, false).contains(&"--max-budget-usd".to_owned()));
    }

    #[test]
    fn ask_plans_only_and_names_are_numbered() {
        assert_eq!(
            ask_args(" hi ")[..5],
            ["-p", "--output-format", "text", "--permission-mode", "plan"]
        );
        assert_eq!(ask_args(" hi ").last().unwrap(), "hi");
        assert_eq!(next_free("rev", |n| n == "rev-1" || n == "rev-2"), "rev-3");
    }
}
