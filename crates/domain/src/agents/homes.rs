//! Where each CLI keeps its sign-in, settings and sessions, so a profile
//! (a UI workspace) can give it a folder of its own.
//!
//! A CLI only gets one after checking that, with its variable pointing
//! elsewhere, its credential really is separate from the user's normal one.
//! If it kept its login in one keychain item whatever the folder, signing in
//! from a workspace would replace the user's login everywhere, their
//! terminal included. CLIs not checked yet (or that fail) get no variable:
//! they share the Mac's sign-in in every workspace.

/// A CLI's own folder variable, and what was checked about it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CliHome {
    pub provider: &'static str,
    pub variable: &'static str,
    /// The version the separation was checked on.
    pub checked_on: &'static str,
}

/// CLIs whose sign-in follows their folder variable.
///
/// - Claude Code 2.1.316: with `CLAUDE_CONFIG_DIR` set, the keychain item is
///   `Claude Code-credentials-<sha256(dir)[..8]>` instead of `Claude
///   Code-credentials`; `claude auth status` with a new folder is signed out.
/// - Codex CLI 0.157.0: `cli_auth_credentials_store` defaults to `file`,
///   `$CODEX_HOME/auth.json`; `codex login status` with a new folder is
///   signed out.
///
/// Not checked yet, so they share the Mac's sign-in: Gemini CLI
/// (`GEMINI_CLI_HOME`) and GitHub Copilot CLI (`COPILOT_HOME`). Custom agents
/// never get one.
pub const CLI_HOMES: &[CliHome] = &[
    CliHome {
        provider: "claude",
        variable: "CLAUDE_CONFIG_DIR",
        checked_on: "2.1.316",
    },
    CliHome {
        provider: "codex",
        variable: "CODEX_HOME",
        checked_on: "0.157.0",
    },
];

/// The folder variable of a provider, if its sign-in can be a profile's own.
pub fn cli_home(provider: &str) -> Option<&'static CliHome> {
    CLI_HOMES.iter().find(|h| h.provider == provider)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_checked_clis_get_a_folder() {
        assert_eq!(cli_home("claude").unwrap().variable, "CLAUDE_CONFIG_DIR");
        assert_eq!(cli_home("codex").unwrap().variable, "CODEX_HOME");
        assert!(cli_home("gemini").is_none());
        assert!(cli_home("copilot").is_none());
        assert!(cli_home("my-agent").is_none());
    }
}
