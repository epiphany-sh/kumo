use super::PromptStyle;

/// A coding-agent CLI Kumo knows how to run.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AgentPreset {
    pub id: &'static str,
    pub name: &'static str,
    /// Two-letter badge.
    pub short: &'static str,
    pub program: &'static str,
    pub prompt: PromptStyle,
    /// Arguments of the CLI's sign-in command; None runs the CLI itself
    /// (it asks to sign in on first use).
    pub login: Option<&'static [&'static str]>,
    pub install_hint: &'static str,
}

/// Known CLIs. Prompts go as arguments only where the CLI documents it
/// for interactive sessions; otherwise Kumo types the prompt in once the
/// agent first waits for input.
pub const PRESETS: &[AgentPreset] = &[
    AgentPreset {
        id: "claude",
        name: "Claude Code",
        short: "CC",
        program: "claude",
        prompt: PromptStyle::Argument(&["{prompt}"]),
        login: None,
        install_hint: "npm install -g @anthropic-ai/claude-code",
    },
    AgentPreset {
        id: "codex",
        name: "Codex CLI",
        short: "CX",
        program: "codex",
        prompt: PromptStyle::Argument(&["{prompt}"]),
        login: Some(&["login"]),
        install_hint: "npm install -g @openai/codex",
    },
    AgentPreset {
        id: "gemini",
        name: "Gemini CLI",
        short: "GM",
        program: "gemini",
        prompt: PromptStyle::Argument(&["-i", "{prompt}"]),
        login: None,
        install_hint: "npm install -g @google/gemini-cli",
    },
    AgentPreset {
        id: "copilot",
        name: "GitHub Copilot CLI",
        short: "GH",
        program: "copilot",
        prompt: PromptStyle::TypeIn,
        login: None,
        install_hint: "npm install -g @github/copilot",
    },
    AgentPreset {
        id: "grok",
        name: "Grok",
        short: "GK",
        program: "grok",
        prompt: PromptStyle::TypeIn,
        login: None,
        install_hint: "Install a Grok coding CLI (xAI's Grok Build or a community grok-cli) so `grok` is on your PATH",
    },
    AgentPreset {
        id: "opencode",
        name: "OpenCode",
        short: "OC",
        program: "opencode",
        prompt: PromptStyle::TypeIn,
        login: Some(&["auth", "login"]),
        install_hint: "npm install -g opencode-ai",
    },
    AgentPreset {
        id: "cursor",
        name: "Cursor Agent",
        short: "CU",
        program: "cursor-agent",
        prompt: PromptStyle::TypeIn,
        login: Some(&["login"]),
        install_hint: "curl https://cursor.com/install -fsS | bash",
    },
    AgentPreset {
        id: "aider",
        name: "Aider",
        short: "AD",
        program: "aider",
        prompt: PromptStyle::TypeIn,
        login: None,
        install_hint: "brew install aider",
    },
    AgentPreset {
        id: "qwen",
        name: "Qwen Code",
        short: "QW",
        program: "qwen",
        prompt: PromptStyle::TypeIn,
        login: None,
        install_hint: "npm install -g @qwen-code/qwen-code",
    },
    AgentPreset {
        id: "amp",
        name: "Amp",
        short: "AM",
        program: "amp",
        prompt: PromptStyle::TypeIn,
        login: None,
        install_hint: "npm install -g @sourcegraph/amp",
    },
];

impl AgentPreset {
    pub fn find(id: &str) -> Option<&'static AgentPreset> {
        PRESETS.iter().find(|p| p.id == id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ids_and_badges_are_unique() {
        for (i, a) in PRESETS.iter().enumerate() {
            for b in &PRESETS[i + 1..] {
                assert_ne!(a.id, b.id);
                assert_ne!(a.short, b.short);
            }
        }
    }
}
