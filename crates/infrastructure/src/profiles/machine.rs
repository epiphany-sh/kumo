//! The SSH keys and `gh` accounts on this machine, to pick from in a
//! profile's settings. Keys are listed by their `.pub`: the private half is
//! never opened.

use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::sync::Arc;

use kumo_domain::agents::ProgramLocator;
use kumo_domain::profiles::{GhAccount, MachineAccounts, SshKey};

use crate::ci::GhTokenFallback;

/// [`MachineAccounts`] from `~/.ssh` and the user's `gh`.
pub struct LocalMachineAccounts {
    home: PathBuf,
    locator: Arc<dyn ProgramLocator>,
    gh: GhTokenFallback,
}

impl std::fmt::Debug for LocalMachineAccounts {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("LocalMachineAccounts")
            .field("home", &self.home)
            .finish_non_exhaustive()
    }
}

impl LocalMachineAccounts {
    pub fn new(home: &Path, locator: Arc<dyn ProgramLocator>) -> Self {
        Self {
            home: home.to_owned(),
            gh: GhTokenFallback::new(Arc::clone(&locator)),
            locator,
        }
    }

    /// `(fingerprint, kind)` from `ssh-keygen -l`, which reads the `.pub`.
    fn describe(&self, public: &Path) -> Option<(String, String)> {
        let program = self
            .locator
            .locate("ssh-keygen")
            .unwrap_or_else(|| PathBuf::from("ssh-keygen"));
        let output = crate::platform::background(program)
            .arg("-l")
            .arg("-f")
            .arg(public)
            .stdin(Stdio::null())
            .stderr(Stdio::null())
            .output()
            .ok()
            .filter(|o| o.status.success())?;
        fingerprint_in(&String::from_utf8_lossy(&output.stdout))
    }
}

impl MachineAccounts for LocalMachineAccounts {
    fn ssh_keys(&self) -> Vec<SshKey> {
        let dir = self.home.join(".ssh");
        let Ok(entries) = std::fs::read_dir(&dir) else {
            return Vec::new();
        };
        let mut keys: Vec<SshKey> = entries
            .filter_map(Result::ok)
            .filter_map(|entry| {
                let file = entry.file_name().into_string().ok()?;
                let name = file.strip_suffix(".pub")?.to_owned();
                let public = entry.path();
                if !public.is_file() {
                    return None;
                }
                let agent_only = !dir.join(&name).is_file();
                let shown = if agent_only { &file } else { &name };
                let (fingerprint, kind) = self.describe(&public).unwrap_or_default();
                Some(SshKey {
                    path: format!("~/.ssh/{shown}"),
                    name,
                    fingerprint,
                    kind,
                    agent_only,
                })
            })
            .collect();
        keys.sort_by(|a, b| a.name.cmp(&b.name));
        keys
    }

    fn gh_accounts(&self) -> Vec<GhAccount> {
        self.gh.signed_in_accounts()
    }
}

/// `SHA256:abc` and `ed25519` from `256 SHA256:abc me@host (ED25519)`.
fn fingerprint_in(line: &str) -> Option<(String, String)> {
    let line = line.lines().next()?.trim();
    let fingerprint = line.split_whitespace().nth(1)?.to_owned();
    let kind = line
        .rsplit_once('(')
        .and_then(|(_, rest)| rest.strip_suffix(')'))
        .unwrap_or_default()
        .to_lowercase();
    Some((fingerprint, kind))
}

#[cfg(test)]
mod tests {
    use kumo_domain::agents::AgentError;

    use super::*;

    struct Path_;

    impl ProgramLocator for Path_ {
        fn locate(&self, program: &str) -> Option<PathBuf> {
            which(program)
        }
        fn search_path(&self) -> String {
            "/usr/bin:/bin".into()
        }
        fn version(&self, _: &Path) -> Result<String, AgentError> {
            Ok(String::new())
        }
        fn home(&self) -> PathBuf {
            PathBuf::from("/")
        }
    }

    fn which(program: &str) -> Option<PathBuf> {
        ["/usr/bin", "/bin", "/opt/homebrew/bin", "/usr/local/bin"]
            .iter()
            .map(|dir| Path::new(dir).join(program))
            .find(|p| p.is_file())
    }

    #[test]
    fn reads_fingerprint_and_kind() {
        assert_eq!(
            fingerprint_in("256 SHA256:AbC/123 one@workspace-1 (ED25519)\n"),
            Some(("SHA256:AbC/123".into(), "ed25519".into()))
        );
        assert_eq!(fingerprint_in(""), None);
    }

    #[test]
    fn lists_key_pairs_and_lone_public_keys_never_their_contents() {
        let Some(keygen) = which("ssh-keygen") else {
            return;
        };
        let home = tempfile::tempdir().unwrap();
        let ssh = home.path().join(".ssh");
        std::fs::create_dir(&ssh).unwrap();
        let made = std::process::Command::new(keygen)
            .args([
                "-q",
                "-t",
                "ed25519",
                "-N",
                "",
                "-C",
                "one@workspace-1",
                "-f",
            ])
            .arg(ssh.join("id_workspace_1"))
            .status()
            .unwrap();
        assert!(made.success());
        // An agent holds this one: only its .pub is on disk.
        std::fs::copy(ssh.join("id_workspace_1.pub"), ssh.join("agent_key.pub")).unwrap();
        std::fs::write(ssh.join("config"), "Host *\n").unwrap();

        let keys = LocalMachineAccounts::new(home.path(), Arc::new(Path_)).ssh_keys();
        assert_eq!(keys.len(), 2, "{keys:?}");
        assert_eq!(keys[0].name, "agent_key");
        assert_eq!(keys[0].path, "~/.ssh/agent_key.pub");
        assert!(keys[0].agent_only);
        assert_eq!(keys[1].path, "~/.ssh/id_workspace_1");
        assert!(!keys[1].agent_only);
        assert!(keys[1].fingerprint.starts_with("SHA256:"));
        assert_eq!(keys[1].kind, "ed25519");
        let shown = format!("{keys:?}");
        assert!(!shown.contains("PRIVATE KEY") && !shown.contains("AAAA"));
    }
}
