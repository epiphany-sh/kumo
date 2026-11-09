use std::path::Path;

use super::{AgentError, AgentPreset, split_args};

/// How a CLI receives the initial prompt.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PromptStyle {
    /// Extra arguments; `{prompt}` is replaced by the prompt.
    Argument(&'static [&'static str]),
    /// Typed into the terminal when the agent first waits for input.
    TypeIn,
}

/// A coding agent the user can run: a known CLI or a custom command.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AgentProvider {
    pub id: String,
    pub name: String,
    pub short: String,
    pub program: String,
    /// Shell-quoted extra arguments. For custom agents, `{prompt}` in them
    /// marks where the prompt goes.
    pub args: String,
    pub custom: bool,
    pub enabled: bool,
    pub is_default: bool,
    /// Read its plan limits and context window, where it reports them
    /// (for Claude Code, through its status line). On by default.
    pub read_usage: bool,
    pub preset: Option<&'static AgentPreset>,
}

impl AgentProvider {
    pub fn from_preset(preset: &'static AgentPreset) -> Self {
        Self {
            id: preset.id.to_owned(),
            name: preset.name.to_owned(),
            short: preset.short.to_owned(),
            program: preset.program.to_owned(),
            args: String::new(),
            custom: false,
            enabled: false,
            is_default: false,
            read_usage: true,
            preset: Some(preset),
        }
    }

    /// Two letters from the name, for custom agents.
    pub fn badge_for(name: &str) -> String {
        let letters: String = name
            .split_whitespace()
            .filter_map(|w| w.chars().next())
            .take(2)
            .collect();
        let badge = if letters.chars().count() == 2 {
            letters
        } else {
            name.chars().take(2).collect()
        };
        badge.to_uppercase()
    }

    pub fn takes_prompt_argument(&self) -> bool {
        match self.preset {
            Some(preset) => matches!(preset.prompt, PromptStyle::Argument(_)),
            None => self.args.contains("{prompt}"),
        }
    }

    /// Arguments to start a session. The prompt goes in when the CLI takes
    /// it as an argument; returns whether it did.
    pub fn launch_args(&self, prompt: &str) -> Result<(Vec<String>, bool), AgentError> {
        let mut args = split_args(&self.args)?;
        let has_prompt = !prompt.trim().is_empty();
        let prompt = never_an_option(prompt);
        let prompt = prompt.as_str();
        let mut used = false;
        if let Some(AgentPreset {
            prompt: PromptStyle::Argument(template),
            ..
        }) = self.preset
        {
            if has_prompt {
                args.extend(template.iter().map(|a| a.replace("{prompt}", prompt)));
                used = true;
            }
        } else if self.preset.is_none() && self.args.contains("{prompt}") {
            // Custom: substitute (or drop) the placeholder.
            args = args
                .into_iter()
                .filter(|a| has_prompt || a != "{prompt}")
                .map(|a| a.replace("{prompt}", prompt))
                .collect();
            used = has_prompt;
        }
        Ok((args, used))
    }

    /// Arguments that make it say when it's asking something.
    pub fn ask_notice(&self) -> &'static [&'static str] {
        self.preset.map_or(&[], |p| p.ask_notice)
    }

    /// It says when it's asking something without being told to.
    pub fn tells_state(&self) -> bool {
        self.preset.is_some_and(|p| p.tells_state)
    }

    /// Arguments of the sign-in flow.
    pub fn login_args(&self) -> Vec<String> {
        self.preset
            .and_then(|p| p.login)
            .map(|a| a.iter().map(|s| (*s).to_owned()).collect())
            .unwrap_or_default()
    }

    pub fn has_login(&self) -> bool {
        self.preset.is_some()
    }

    /// Kumo knows how to read its usage (whether or not it's turned on).
    pub fn usage_readable(&self) -> bool {
        self.preset.is_some_and(|p| p.reads_usage)
    }

    /// Its usage is read: readable and turned on.
    pub fn reads_usage(&self) -> bool {
        self.usage_readable() && self.read_usage
    }

    /// The command that compacts its context, if it has one.
    pub fn compact_command(&self) -> Option<&'static str> {
        self.preset.and_then(|p| p.compact_command)
    }

    pub fn validate(&self) -> Result<(), AgentError> {
        if self.name.trim().is_empty() {
            return Err(AgentError::Invalid("the agent needs a name".into()));
        }
        if self.program.trim().is_empty() {
            return Err(AgentError::Invalid("the agent needs a command".into()));
        }
        split_args(&self.args).map(drop)
    }
}

/// The prompt as an argument, which CLIs must read as text. They tell options
/// by a leading `-`, so one goes after a space. Not `--`: a custom command
/// puts `{prompt}` anywhere, and not every CLI takes it.
fn never_an_option(prompt: &str) -> String {
    if prompt.starts_with('-') {
        format!(" {prompt}")
    } else {
        prompt.to_owned()
    }
}

/// Whether Windows starts `program` through `cmd.exe`, which reads the command
/// line by rules of its own: quoting an argument doesn't protect it.
pub fn runs_through_cmd(program: &Path) -> bool {
    program
        .extension()
        .and_then(|e| e.to_str())
        .is_some_and(|e| e.eq_ignore_ascii_case("cmd") || e.eq_ignore_ascii_case("bat"))
}

/// Arguments for a program [`runs_through_cmd`], and the prompt to type in
/// instead when one came last (after `--`). What's left can't hold anything
/// `cmd.exe` acts on, or the agent doesn't start.
pub fn args_for_cmd(mut args: Vec<String>) -> Result<(Vec<String>, Option<String>), AgentError> {
    let mut prompt = None;
    if args.len() >= 2 && args[args.len() - 2] == "--" {
        prompt = args.pop();
        args.pop();
    }
    if args
        .iter()
        .any(|a| a.contains(['&', '|', '<', '>', '^', '%', '!', '\n', '\r']))
    {
        return Err(AgentError::Invalid(
            "this agent's arguments can't go through a .cmd launcher: \
             install its native executable or remove the special characters"
                .to_owned(),
        ));
    }
    Ok((args, prompt))
}

#[cfg(test)]
mod tests {
    use super::super::PRESETS;
    use super::*;

    #[test]
    fn a_prompt_is_never_read_as_an_option() {
        for preset in PRESETS {
            let provider = AgentProvider::from_preset(preset);
            let (args, used) = provider.launch_args("--flag=x and more").unwrap();
            if used {
                assert!(
                    args.iter().all(|a| !a.starts_with("--flag")),
                    "{}: {args:?}",
                    preset.id
                );
                assert!(args.iter().any(|a| a.contains("--flag=x and more")));
            }
        }
        let custom = AgentProvider {
            id: "c".into(),
            name: "My agent".into(),
            short: "MA".into(),
            program: "my-agent".into(),
            args: "{prompt} --fast".into(),
            custom: true,
            enabled: true,
            is_default: false,
            read_usage: true,
            preset: None,
        };
        assert_eq!(
            custom.launch_args("-x").unwrap().0,
            vec![" -x".to_owned(), "--fast".to_owned()]
        );
        let claude = AgentProvider::from_preset(AgentPreset::find("claude").unwrap());
        assert_eq!(
            claude.launch_args("a - b").unwrap().0,
            vec!["a - b"],
            "only a leading dash"
        );
    }

    #[test]
    fn only_batch_files_run_through_cmd() {
        for program in ["claude.cmd", r"C:\npm\claude.CMD", "x.bat"] {
            assert!(runs_through_cmd(Path::new(program)), "{program}");
        }
        for program in ["claude", "claude.exe", "/usr/bin/cmd"] {
            assert!(!runs_through_cmd(Path::new(program)), "{program}");
        }
    }

    #[test]
    fn a_cmd_launcher_gets_the_prompt_typed_and_nothing_it_would_act_on() {
        let args = |list: &[&str]| list.iter().map(|a| (*a).to_owned()).collect::<Vec<_>>();
        assert_eq!(
            args_for_cmd(args(&["--agent", "x", "--", "a & b"])).unwrap(),
            (args(&["--agent", "x"]), Some("a & b".to_owned()))
        );
        assert_eq!(
            args_for_cmd(args(&["--model", "opus"])).unwrap(),
            (args(&["--model", "opus"]), None)
        );
        for unsafe_arg in ["a&b", "a|b", "<a", "a>", "a^b", "%PATH%", "!x!", "a\nb"] {
            assert!(
                args_for_cmd(args(&["--x", unsafe_arg])).is_err(),
                "{unsafe_arg}"
            );
        }
    }

    #[test]
    fn known_cli_gets_the_prompt_as_documented() {
        let claude = AgentProvider {
            args: "--model opus".into(),
            ..AgentProvider::from_preset(AgentPreset::find("claude").unwrap())
        };
        assert_eq!(
            claude.launch_args("fix it").unwrap(),
            (vec!["--model".into(), "opus".into(), "fix it".into()], true)
        );
        assert_eq!(
            claude.launch_args("  ").unwrap(),
            (vec!["--model".into(), "opus".into()], false)
        );
        let gemini = AgentProvider::from_preset(AgentPreset::find("gemini").unwrap());
        assert_eq!(gemini.launch_args("x").unwrap().0, vec!["-i", "x"]);
        let copilot = AgentProvider::from_preset(AgentPreset::find("copilot").unwrap());
        assert_eq!(
            copilot.launch_args("x").unwrap(),
            (vec![], false),
            "typed in later"
        );
    }

    #[test]
    fn custom_agent_uses_its_placeholder() {
        let custom = AgentProvider {
            id: "c".into(),
            name: "My agent".into(),
            short: AgentProvider::badge_for("My agent"),
            program: "my-agent".into(),
            args: "--task {prompt} --fast".into(),
            custom: true,
            enabled: true,
            is_default: false,
            read_usage: true,
            preset: None,
        };
        assert_eq!(custom.short, "MA");
        assert_eq!(
            custom.launch_args("do x").unwrap(),
            (vec!["--task".into(), "do x".into(), "--fast".into()], true)
        );
        assert_eq!(custom.launch_args("").unwrap().0, vec!["--task", "--fast"]);
    }
}
