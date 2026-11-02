//! A profile's CLI folders: `<profile dir>/cli/<provider>/`.

use std::path::{Path, PathBuf};

use kumo_domain::agents::{AgentError, CliHomes, cli_home};

/// [`CliHomes`] under one profile's folder. The default profile uses
/// [`kumo_domain::agents::SharedCliHomes`] instead.
#[derive(Debug, Clone)]
pub struct ProfileCliHomes {
    root: PathBuf,
}

impl ProfileCliHomes {
    /// `root`: `<profile dir>/cli`.
    pub fn new(root: &Path) -> Self {
        Self {
            root: root.to_owned(),
        }
    }

    /// The folder of `provider` (it may not exist yet).
    pub fn dir(&self, provider: &str) -> PathBuf {
        self.root.join(provider)
    }
}

impl CliHomes for ProfileCliHomes {
    fn env(&self, provider: &str) -> Result<Vec<(String, String)>, AgentError> {
        let Some(home) = cli_home(provider) else {
            return Ok(Vec::new());
        };
        let dir = self.dir(provider);
        // Codex refuses a CODEX_HOME that doesn't exist.
        std::fs::create_dir_all(&dir)
            .map_err(|e| AgentError::Launch(format!("can't create {}: {e}", dir.display())))?;
        Ok(vec![(home.variable.to_owned(), dir.display().to_string())])
    }

    fn own_sign_in(&self, provider: &str) -> bool {
        cli_home(provider).is_some()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn checked_clis_get_an_existing_folder_others_nothing() {
        let dir = tempfile::tempdir().unwrap();
        let homes = ProfileCliHomes::new(&dir.path().join("cli"));
        let env = homes.env("codex").unwrap();
        assert_eq!(env[0].0, "CODEX_HOME");
        assert!(Path::new(&env[0].1).is_dir());
        assert_eq!(homes.env("claude").unwrap()[0].0, "CLAUDE_CONFIG_DIR");
        assert!(homes.env("gemini").unwrap().is_empty());
        assert!(!homes.own_sign_in("my-agent"));
    }
}
