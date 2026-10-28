//! The user's GitHub CLI (`gh`) for GitHub hosts with no token saved in
//! Kumo: its token, the account it's signed in as, and the command that
//! signs it in. Tokens are read when needed, kept a few minutes, never
//! logged.

use std::collections::HashMap;
use std::io::Read;
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex, PoisonError};
use std::time::{Duration, Instant};

use kumo_domain::agents::ProgramLocator;
use kumo_domain::pipelines::{CiHost, CiProvider, TokenFallback};
use kumo_domain::terminal::LaunchSpec;

/// How long a token is reused before asking gh again.
const KEEP: Duration = Duration::from_secs(300);
/// Signed out: asked again soon, the user may be signing in.
const KEEP_MISSING: Duration = Duration::from_secs(10);
const TIMEOUT: Duration = Duration::from_secs(5);

pub struct GhTokenFallback {
    locator: Arc<dyn ProgramLocator>,
    known: Mutex<HashMap<String, (Instant, Option<String>)>>,
}

impl std::fmt::Debug for GhTokenFallback {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("GhTokenFallback").finish_non_exhaustive()
    }
}

impl GhTokenFallback {
    pub fn new(locator: Arc<dyn ProgramLocator>) -> Self {
        Self {
            locator,
            known: Mutex::new(HashMap::new()),
        }
    }

    fn known(&self) -> std::sync::MutexGuard<'_, HashMap<String, (Instant, Option<String>)>> {
        self.known.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// Runs gh without prompts; (success, stdout + stderr). None when gh is
    /// missing or slow.
    fn gh(&self, args: &[&str]) -> Option<(bool, String)> {
        let program = self.locator.locate("gh")?;
        let mut child = Command::new(program)
            .args(args)
            .env("PATH", self.locator.search_path())
            .env("GH_PROMPT_DISABLED", "1")
            .env("NO_COLOR", "1")
            .current_dir(self.locator.home())
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .ok()?;
        let started = Instant::now();
        let status = loop {
            match child.try_wait().ok()? {
                Some(status) => break status,
                None if started.elapsed() > TIMEOUT => {
                    let _ = child.kill();
                    let _ = child.wait();
                    return None;
                }
                None => std::thread::sleep(Duration::from_millis(20)),
            }
        };
        let mut out = String::new();
        child.stdout.take()?.read_to_string(&mut out).ok()?;
        let _ = child.stderr.take()?.read_to_string(&mut out);
        Some((status.success(), out))
    }

    fn serves(host: &CiHost) -> bool {
        host.provider == CiProvider::GitHubActions
    }
}

impl TokenFallback for GhTokenFallback {
    fn token(&self, host: &CiHost) -> Option<String> {
        if !Self::serves(host) {
            return None;
        }
        if let Some((at, token)) = self.known().get(&host.host) {
            let keep = if token.is_some() { KEEP } else { KEEP_MISSING };
            if at.elapsed() < keep {
                return token.clone();
            }
        }
        let token = self
            .gh(&["auth", "token", "--hostname", &host.host])
            .filter(|(ok, _)| *ok)
            .map(|(_, out)| out.trim().to_owned())
            .filter(|t| !t.is_empty() && !t.contains(char::is_whitespace));
        self.known()
            .insert(host.host.clone(), (Instant::now(), token.clone()));
        token
    }

    fn account(&self, host: &CiHost) -> Option<String> {
        if !Self::serves(host) {
            return None;
        }
        // `gh auth status` masks the token: only the account is kept.
        let (_, out) = self.gh(&["auth", "status", "--active", "--hostname", &host.host])?;
        account_in(&out)
    }

    fn sign_in(&self, host: &CiHost) -> Option<LaunchSpec> {
        if !Self::serves(host) {
            return None;
        }
        let program = self.locator.locate("gh")?;
        LaunchSpec::new(program.display().to_string())
            .ok()
            .map(|spec| {
                spec.with_args(["auth", "login", "--hostname", host.host.as_str(), "--web"])
                    .with_cwd(Some(self.locator.home()))
                    .with_env([("PATH".to_owned(), self.locator.search_path())])
            })
    }

    fn forget(&self, host: &CiHost) {
        self.known().remove(&host.host);
    }
}

/// `ana` from `✓ Logged in to github.com account ana (keyring)` (older gh:
/// `… as ana (oauth_token)`).
fn account_in(status: &str) -> Option<String> {
    status.lines().find_map(|line| {
        let (_, rest) = line.split_once("Logged in to ")?;
        let mut words = rest.split_whitespace().skip(1);
        match words.next()? {
            "account" | "as" => words.next().map(str::to_owned),
            _ => None,
        }
    })
}

#[cfg(test)]
mod tests {
    use std::path::{Path, PathBuf};

    use kumo_domain::agents::AgentError;

    use super::*;

    #[test]
    fn reads_the_account_from_both_status_formats() {
        let new = "github.com\n  ✓ Logged in to github.com account MDellag (keyring)\n  - Active account: true\n  - Token: gho_************************************\n";
        assert_eq!(account_in(new).as_deref(), Some("MDellag"));
        let old = "github.com\n  ✓ Logged in to github.com as ana (oauth_token)\n";
        assert_eq!(account_in(old).as_deref(), Some("ana"));
        assert_eq!(
            account_in("You are not logged into any GitHub hosts. To log in, run: gh auth login"),
            None
        );
    }

    struct NoGh;

    impl ProgramLocator for NoGh {
        fn locate(&self, _: &str) -> Option<PathBuf> {
            None
        }
        fn search_path(&self) -> String {
            String::new()
        }
        fn version(&self, _: &Path) -> Result<String, AgentError> {
            Ok(String::new())
        }
        fn home(&self) -> PathBuf {
            PathBuf::from("/")
        }
    }

    struct FakeGh(PathBuf);

    impl ProgramLocator for FakeGh {
        fn locate(&self, program: &str) -> Option<PathBuf> {
            (program == "gh").then(|| self.0.clone())
        }
        fn search_path(&self) -> String {
            "/usr/bin:/bin".into()
        }
        fn version(&self, _: &Path) -> Result<String, AgentError> {
            Ok("gh version 2.101.0".into())
        }
        fn home(&self) -> PathBuf {
            PathBuf::from("/")
        }
    }

    fn github() -> CiHost {
        CiHost {
            provider: CiProvider::GitHubActions,
            host: "github.com".into(),
            api: "https://api.github.com".into(),
            web: "https://github.com".into(),
        }
    }

    #[test]
    fn without_gh_there_is_nothing_to_use_or_run() {
        let gh = GhTokenFallback::new(Arc::new(NoGh));
        assert_eq!(gh.token(&github()), None);
        assert!(gh.sign_in(&github()).is_none());
    }

    /// A stand-in `gh` that prints a token and an account.
    fn fake_gh(dir: &Path) -> PathBuf {
        use std::os::unix::fs::PermissionsExt;
        let path = dir.join("gh");
        std::fs::write(
            &path,
            "#!/bin/sh\ncase \"$2\" in\n  token) echo gho_fake ;;\n  status) echo '  ✓ Logged in to github.com account ana (keyring)' ;;\nesac\n",
        )
        .unwrap();
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
        path
    }

    #[cfg(unix)]
    #[test]
    fn reads_token_and_account_and_signs_in_on_the_web() {
        let dir = tempfile::tempdir().unwrap();
        let gh = GhTokenFallback::new(Arc::new(FakeGh(fake_gh(dir.path()))));
        assert_eq!(gh.token(&github()).as_deref(), Some("gho_fake"));
        assert_eq!(gh.account(&github()).as_deref(), Some("ana"));
        let spec = gh.sign_in(&github()).unwrap();
        assert_eq!(
            spec.args(),
            ["auth", "login", "--hostname", "github.com", "--web"]
        );
        let gitlab = CiHost {
            provider: CiProvider::GitLabCi,
            ..github()
        };
        assert_eq!(gh.token(&gitlab), None, "gh only signs in to GitHub");
        assert!(gh.sign_in(&gitlab).is_none());
    }
}
