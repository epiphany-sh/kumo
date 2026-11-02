//! How git runs inside a profile, as environment variables for the
//! processes Kumo starts (its own git, shells, agents). Nothing is written
//! to `~/.gitconfig`, a repository's config or `~/.ssh/config`: outside Kumo
//! git works as before.

use std::collections::BTreeSet;
use std::path::{Path, PathBuf};
use std::sync::{Arc, PoisonError, RwLock};

use super::Profile;

/// Which credential the profile's git uses on each host, and how.
///
/// | The profile has | SSH remotes | HTTPS remotes |
/// |---|---|---|
/// | an SSH key | over SSH with that key | the profile's token |
/// | an account or token for the host, no key | rewritten to HTTPS, the profile's token | the profile's token |
/// | nothing | as without Kumo | as without Kumo |
#[derive(Clone, Default, PartialEq, Eq)]
pub struct GitSetup {
    /// Empty: the user's git config.
    pub name: String,
    pub email: String,
    /// The key, as an absolute path (private key or `.pub`).
    pub ssh_key: Option<PathBuf>,
    pub sign_commits: bool,
    /// Hosts of the profile's remotes with a token or a `gh` account.
    pub credential_hosts: BTreeSet<String>,
    /// What git runs to ask for those hosts' tokens (`kumod git-credential`),
    /// as a shell command.
    pub helper: String,
    /// `gh`'s tokens for the shells and agents of the profile, per host.
    pub gh_tokens: Vec<(String, String)>,
    /// Set for every profile but the default one, and for the default one
    /// once it uses anything: the credential helper reads it.
    pub profile: Option<String>,
}

/// Tokens never show in logs.
impl std::fmt::Debug for GitSetup {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let gh_hosts: Vec<&str> = self.gh_tokens.iter().map(|(h, _)| h.as_str()).collect();
        f.debug_struct("GitSetup")
            .field("name", &self.name)
            .field("email", &self.email)
            .field("ssh_key", &self.ssh_key)
            .field("sign_commits", &self.sign_commits)
            .field("credential_hosts", &self.credential_hosts)
            .field("gh_tokens_for", &gh_hosts)
            .field("profile", &self.profile)
            .finish_non_exhaustive()
    }
}

impl GitSetup {
    /// The setup of `profile`. `home` expands `~/` in its key.
    pub fn of(profile: &Profile, home: &Path) -> Self {
        let ssh_key = match profile.ssh_key.as_str() {
            "" => None,
            key => Some(match key.strip_prefix("~/") {
                Some(rest) => home.join(rest),
                None => PathBuf::from(key),
            }),
        };
        Self {
            name: profile.git_name.clone(),
            email: profile.git_email.clone(),
            ssh_key,
            sign_commits: profile.sign_commits,
            profile: (!profile.is_default()).then(|| profile.id.to_string()),
            ..Self::default()
        }
    }

    /// The git config it adds, in order (`insteadOf` takes several values).
    pub fn config(&self) -> Vec<(String, String)> {
        let mut config = Vec::new();
        if !self.name.is_empty() {
            config.push(("user.name".to_owned(), self.name.clone()));
        }
        if !self.email.is_empty() {
            config.push(("user.email".to_owned(), self.email.clone()));
        }
        match &self.ssh_key {
            Some(key) if self.sign_commits => {
                config.push(("gpg.format".to_owned(), "ssh".to_owned()));
                config.push((
                    "user.signingkey".to_owned(),
                    public_key(key).display().to_string(),
                ));
                config.push(("commit.gpgsign".to_owned(), "true".to_owned()));
            }
            Some(_) => {}
            // No key: SSH remotes of hosts with a token go over HTTPS.
            None => {
                for host in &self.credential_hosts {
                    let https = format!("url.https://{host}/.insteadOf");
                    config.push((https.clone(), format!("git@{host}:")));
                    config.push((https, format!("ssh://git@{host}/")));
                }
            }
        }
        if !self.helper.is_empty() {
            for host in &self.credential_hosts {
                let key = format!("credential.https://{host}.helper");
                // The empty value drops the user's helpers for the host:
                // only the profile's token is offered.
                config.push((key.clone(), String::new()));
                config.push((key, self.helper.clone()));
            }
        }
        config
    }

    /// The SSH command for git, without the options a caller adds.
    pub fn ssh_command(&self) -> Option<String> {
        self.ssh_key.as_ref().map(|key| {
            format!(
                "ssh -i {} -o IdentitiesOnly=yes",
                shell_quote(&key.display().to_string())
            )
        })
    }

    /// The environment variables for the profile's processes. Empty for a
    /// default profile with nothing configured.
    pub fn env(&self) -> Vec<(String, String)> {
        let mut env = Vec::new();
        let config = self.config();
        if !config.is_empty() {
            env.push(("GIT_CONFIG_COUNT".to_owned(), config.len().to_string()));
            for (i, (key, value)) in config.into_iter().enumerate() {
                env.push((format!("GIT_CONFIG_KEY_{i}"), key));
                env.push((format!("GIT_CONFIG_VALUE_{i}"), value));
            }
        }
        if let Some(ssh) = self.ssh_command() {
            env.push(("GIT_SSH_COMMAND".to_owned(), ssh));
        }
        for (host, token) in &self.gh_tokens {
            let var = if host == "github.com" {
                "GH_TOKEN"
            } else {
                "GH_ENTERPRISE_TOKEN"
            };
            env.push((var.to_owned(), token.clone()));
        }
        let profile = self
            .profile
            .clone()
            .or_else(|| (!env.is_empty()).then(|| super::ProfileId::DEFAULT.to_owned()));
        if let Some(profile) = profile {
            env.push(("KUMO_PROFILE".to_owned(), profile));
        }
        env
    }
}

/// The `.pub` of a key (the key itself when it already is one).
fn public_key(key: &Path) -> PathBuf {
    if key.extension().is_some_and(|e| e == "pub") {
        key.to_owned()
    } else {
        let mut public = key.as_os_str().to_owned();
        public.push(".pub");
        PathBuf::from(public)
    }
}

/// `value` as one word for `sh`.
pub fn shell_quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', r"'\''"))
}

/// The environment a profile's processes get right now, shared by its git,
/// terminals and agents and replaced when the profile or its hosts change.
#[derive(Debug, Clone, Default)]
pub struct ProfileEnv(Arc<RwLock<Arc<GitSetup>>>);

impl ProfileEnv {
    pub fn get(&self) -> Arc<GitSetup> {
        Arc::clone(&self.0.read().unwrap_or_else(PoisonError::into_inner))
    }

    pub fn set(&self, setup: GitSetup) {
        *self.0.write().unwrap_or_else(PoisonError::into_inner) = Arc::new(setup);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::profiles::{ProfileChanges, ProfileId};
    use crate::time::Timestamp;

    fn profile(id: &str, changes: ProfileChanges) -> Profile {
        let mut p = Profile::new(
            ProfileId::parse(id).unwrap(),
            "Workspace",
            "",
            1,
            Timestamp::from_unix_nanos(1),
        )
        .unwrap();
        p.apply(changes).unwrap();
        p
    }

    /// An absolute key path on the platform running the tests.
    const KEY: &str = if cfg!(windows) {
        r"C:\keys\id_one"
    } else {
        "/keys/id_one"
    };

    fn hosts(setup: GitSetup) -> GitSetup {
        GitSetup {
            credential_hosts: ["github.com".to_owned()].into(),
            helper: "!'/bin/kumod' git-credential".into(),
            ..setup
        }
    }

    fn var<'a>(env: &'a [(String, String)], name: &str) -> Option<&'a str> {
        env.iter().find(|(k, _)| k == name).map(|(_, v)| v.as_str())
    }

    #[test]
    fn the_default_profile_with_nothing_set_adds_nothing() {
        let setup = GitSetup::of(
            &Profile::first(Timestamp::from_unix_nanos(1)),
            Path::new("/h"),
        );
        assert!(setup.env().is_empty());
    }

    #[test]
    fn another_profile_always_names_itself() {
        let setup = GitSetup::of(
            &profile("workspace-1", ProfileChanges::default()),
            Path::new("/h"),
        );
        assert_eq!(
            setup.env(),
            [("KUMO_PROFILE".to_owned(), "workspace-1".to_owned())]
        );
    }

    #[test]
    fn identity_goes_in_as_config_not_as_author_variables() {
        let p = profile(
            "workspace-1",
            ProfileChanges {
                git_name: Some("User One".into()),
                git_email: Some("one@workspace-1.test".into()),
                ..ProfileChanges::default()
            },
        );
        let env = GitSetup::of(&p, Path::new("/h")).env();
        assert_eq!(var(&env, "GIT_CONFIG_COUNT"), Some("2"));
        assert_eq!(var(&env, "GIT_CONFIG_KEY_0"), Some("user.name"));
        assert_eq!(
            var(&env, "GIT_CONFIG_VALUE_1"),
            Some("one@workspace-1.test")
        );
        assert!(env.iter().all(|(k, _)| !k.starts_with("GIT_AUTHOR")));
    }

    #[test]
    fn without_a_key_ssh_remotes_of_hosts_with_a_token_go_over_https() {
        let setup = hosts(GitSetup::of(
            &profile("workspace-1", ProfileChanges::default()),
            Path::new("/h"),
        ));
        assert_eq!(
            setup.config(),
            [
                ("url.https://github.com/.insteadOf", "git@github.com:"),
                ("url.https://github.com/.insteadOf", "ssh://git@github.com/"),
                ("credential.https://github.com.helper", ""),
                (
                    "credential.https://github.com.helper",
                    "!'/bin/kumod' git-credential"
                ),
            ]
            .map(|(k, v)| (k.to_owned(), v.to_owned()))
        );
        assert_eq!(setup.ssh_command(), None);
    }

    #[test]
    fn with_a_key_ssh_stays_ssh_and_only_that_key_is_offered() {
        let p = profile(
            "workspace-1",
            ProfileChanges {
                ssh_key: Some("~/.ssh/id_workspace 1".into()),
                ..ProfileChanges::default()
            },
        );
        let setup = hosts(GitSetup::of(&p, Path::new("/h")));
        // `~/` expands with the platform's separator.
        let key = Path::new("/h").join(".ssh/id_workspace 1");
        assert_eq!(
            setup.ssh_command(),
            Some(format!(
                "ssh -i {} -o IdentitiesOnly=yes",
                shell_quote(&key.display().to_string())
            ))
        );
        assert!(setup.config().iter().all(|(k, _)| !k.contains("insteadOf")));
        // HTTPS remotes still get the profile's token.
        assert!(
            setup
                .config()
                .iter()
                .any(|(k, _)| k == "credential.https://github.com.helper")
        );
    }

    #[test]
    fn signing_uses_the_public_half_of_the_key() {
        let p = profile(
            "workspace-1",
            ProfileChanges {
                ssh_key: Some(KEY.into()),
                sign_commits: Some(true),
                ..ProfileChanges::default()
            },
        );
        let config = GitSetup::of(&p, Path::new("/h")).config();
        assert!(config.contains(&("gpg.format".into(), "ssh".into())));
        assert!(config.contains(&("user.signingkey".into(), format!("{KEY}.pub"))));
        assert!(config.contains(&("commit.gpgsign".into(), "true".into())));

        // Without a key there's nothing to sign with.
        let p = profile(
            "workspace-1",
            ProfileChanges {
                sign_commits: Some(true),
                ..ProfileChanges::default()
            },
        );
        assert!(GitSetup::of(&p, Path::new("/h")).config().is_empty());
    }

    #[test]
    fn gh_tokens_go_to_gh_by_host_kind() {
        let setup = GitSetup {
            gh_tokens: vec![
                ("github.com".into(), "t1".into()),
                ("ghe.workspace-1.test".into(), "t2".into()),
            ],
            ..GitSetup::default()
        };
        let env = setup.env();
        assert_eq!(var(&env, "GH_TOKEN"), Some("t1"));
        assert_eq!(var(&env, "GH_ENTERPRISE_TOKEN"), Some("t2"));
        // The default profile names itself once it sets anything.
        assert_eq!(var(&env, "KUMO_PROFILE"), Some("default"));
    }
}
