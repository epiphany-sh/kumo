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

#[cfg(test)]
mod tests {
    use super::*;

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
