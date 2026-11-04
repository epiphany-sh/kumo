//! The user's GitHub CLI (`gh`) for GitHub hosts with no token saved in
//! Kumo: its token, the account it's signed in as, and the command that
//! signs it in. Tokens are read when needed, kept a few minutes, never
//! logged.

use std::collections::HashMap;
use std::io::Read;
use std::process::Stdio;
use std::sync::{Arc, Mutex, PoisonError};
use std::time::{Duration, Instant};

use kumo_domain::agents::ProgramLocator;
use kumo_domain::pipelines::{CiHost, CiProvider, TokenFallback};
use kumo_domain::profiles::GhAccount;
use kumo_domain::terminal::LaunchSpec;

/// How long a token is reused before asking gh again.
const KEEP: Duration = Duration::from_secs(300);
/// Signed out: asked again soon, the user may be signing in.
const KEEP_MISSING: Duration = Duration::from_secs(10);
const TIMEOUT: Duration = Duration::from_secs(5);

/// A profile's view of `gh`: the account it uses per host (else the active
/// one), with tokens kept apart per account.
pub struct GhTokenFallback {
    locator: Arc<dyn ProgramLocator>,
    /// Token per `(host, account)`; account empty for the active one.
    known: Mutex<HashMap<(String, String), Cached>>,
    /// The profile's account per host.
    accounts: Mutex<HashMap<String, String>>,
    /// Sign-ins in progress: what was active before, per host.
    pending: Mutex<HashMap<String, Active>>,
}

/// A token read at a moment; None when gh had none.
type Cached = (Instant, Option<String>);

/// The account `gh` had active on a host, and its token (to tell when a
/// sign-in replaced it). Never logged.
#[derive(Default)]
struct Active {
    login: Option<String>,
    token: Option<String>,
}

impl std::fmt::Debug for GhTokenFallback {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("GhTokenFallback")
            .field("accounts", &*lock(&self.accounts))
            .finish_non_exhaustive()
    }
}

fn lock<T>(mutex: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(PoisonError::into_inner)
}

impl GhTokenFallback {
    pub fn new(locator: Arc<dyn ProgramLocator>) -> Self {
        Self {
            locator,
            known: Mutex::default(),
            accounts: Mutex::default(),
            pending: Mutex::default(),
        }
    }

    /// Every account `gh` is signed in to, per host.
    pub fn signed_in_accounts(&self) -> Vec<GhAccount> {
        self.gh(&["auth", "status"])
            .map(|(_, out)| accounts_in(&out))
            .unwrap_or_default()
    }

    /// The profile's account on `host`, if it set one.
    fn account_on(&self, host: &str) -> Option<String> {
        lock(&self.accounts).get(host).cloned()
    }

    /// `gh auth token` for `login` (the active account when None).
    fn read_token(&self, host: &str, login: Option<&str>) -> Option<String> {
        let mut args = vec!["auth", "token", "--hostname", host];
        if let Some(login) = login {
            args.extend(["--user", login]);
        }
        self.gh(&args)
            .filter(|(ok, _)| *ok)
            .map(|(_, out)| out.trim().to_owned())
            .filter(|t| !t.is_empty() && !t.contains(char::is_whitespace))
    }

    fn active(&self, host: &str) -> Active {
        let login = self
            .gh(&["auth", "status", "--active", "--hostname", host])
            .and_then(|(_, out)| account_in(&out));
        Active {
            login,
            token: self.read_token(host, None),
        }
    }

    /// Runs gh without prompts; (success, stdout + stderr). None when gh is
    /// missing or slow.
    fn gh(&self, args: &[&str]) -> Option<(bool, String)> {
        let program = self.locator.locate("gh")?;
        let mut child = crate::platform::background(program)
            .args(args)
            .env("PATH", self.locator.search_path())
            .env("GH_PROMPT_DISABLED", "1")
            .env("NO_COLOR", "1")
            // The account comes from gh's own config, never from ours.
            .env_remove("GH_TOKEN")
            .env_remove("GH_ENTERPRISE_TOKEN")
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
        let login = self.account_on(&host.host);
        let key = (host.host.clone(), login.clone().unwrap_or_default());
        if let Some((at, token)) = lock(&self.known).get(&key) {
            let keep = if token.is_some() { KEEP } else { KEEP_MISSING };
            if at.elapsed() < keep {
                return token.clone();
            }
        }
        let token = self.read_token(&host.host, login.as_deref());
        lock(&self.known).insert(key, (Instant::now(), token.clone()));
        token
    }

    fn account(&self, host: &CiHost) -> Option<String> {
        if !Self::serves(host) {
            return None;
        }
        if let Some(login) = self.account_on(&host.host) {
            return self.token(host).map(|_| login);
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
        let spec = LaunchSpec::new(program.display().to_string()).ok()?;
        // Signing in makes the new account gh's active one; what was active
        // comes back once it's done.
        let before = self.active(&host.host);
        lock(&self.pending).insert(host.host.clone(), before);
        Some(
            spec.with_args(["auth", "login", "--hostname", host.host.as_str(), "--web"])
                .with_cwd(Some(self.locator.home()))
                .with_env([
                    ("PATH".to_owned(), self.locator.search_path()),
                    // gh won't sign in while a token is set (the profile's
                    // shells get one): empty means unset to gh.
                    ("GH_TOKEN".to_owned(), String::new()),
                    ("GH_ENTERPRISE_TOKEN".to_owned(), String::new()),
                ]),
        )
    }

    fn forget(&self, host: &CiHost) {
        lock(&self.known).retain(|(h, _), _| *h != host.host);
    }

    fn use_accounts(&self, accounts: &[GhAccount]) {
        let accounts: HashMap<String, String> = accounts
            .iter()
            .map(|a| (a.host.clone(), a.login.clone()))
            .collect();
        *lock(&self.accounts) = accounts;
    }

    fn signed_in(&self, host: &CiHost) -> Option<String> {
        if !Self::serves(host) {
            return None;
        }
        let Some(before_token) = lock(&self.pending)
            .get(&host.host)
            .map(|before| before.token.clone())
        else {
            self.forget(host);
            self.token(host)?;
            return Some(self.account(host).unwrap_or_default());
        };
        let now = self.active(&host.host);
        let login = now
            .login
            .filter(|_| now.token.is_some() && now.token != before_token)?;
        let before = lock(&self.pending).remove(&host.host).unwrap_or_default();
        if let Some(previous) = before.login.filter(|previous| *previous != login) {
            let switched = self.gh(&[
                "auth",
                "switch",
                "--hostname",
                &host.host,
                "--user",
                &previous,
            ]);
            if !switched.is_some_and(|(ok, _)| ok) {
                tracing::warn!(host = %host.host, "couldn't make the previous gh account active again");
            }
        }
        lock(&self.accounts).insert(host.host.clone(), login.clone());
        self.forget(host);
        Some(login)
    }
}

/// Every `(host, account)` in `gh auth status`.
fn accounts_in(status: &str) -> Vec<GhAccount> {
    let mut accounts: Vec<GhAccount> = status
        .lines()
        .filter_map(|line| {
            let (_, rest) = line.split_once("Logged in to ")?;
            let mut words = rest.split_whitespace();
            let host = words.next()?;
            match words.next()? {
                "account" | "as" => words.next().map(|login| GhAccount::new(host, login)),
                _ => None,
            }
        })
        .collect();
    accounts.sort();
    accounts.dedup();
    accounts
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
        fn script(&self, command: &str) -> (String, Vec<String>) {
            crate::platform::script(command)
        }
    }

    #[cfg(unix)]
    struct FakeGh(PathBuf);

    #[cfg(unix)]
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
        fn script(&self, command: &str) -> (String, Vec<String>) {
            crate::platform::script(command)
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

    #[cfg(unix)]
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

    #[test]
    fn lists_every_signed_in_account() {
        let status = "github.com\n  ✓ Logged in to github.com account user-1 (keyring)\n  - Active account: true\n  ✓ Logged in to github.com account user-2 (keyring)\n  - Active account: false\nghe.workspace-2.test\n  ✓ Logged in to ghe.workspace-2.test account user-3 (keyring)\n";
        assert_eq!(
            accounts_in(status),
            [
                GhAccount::new("ghe.workspace-2.test", "user-3"),
                GhAccount::new("github.com", "user-1"),
                GhAccount::new("github.com", "user-2"),
            ]
        );
    }

    #[cfg(unix)]
    /// A `gh` with two accounts on github.com. `state` holds the active one;
    /// `log` gets every command.
    fn multi_gh(dir: &Path) -> PathBuf {
        use std::os::unix::fs::PermissionsExt;
        let path = dir.join("gh");
        let script = format!(
            r#"#!/bin/sh
d='{dir}'
echo "$*" >> "$d/log"
active=$(cat "$d/active")
user=""
prev=""
for arg in "$@"; do
  [ "$prev" = "--user" ] && user="$arg"
  prev="$arg"
done
case "$2" in
  token) echo "token-of-${{user:-$active}}" ;;
  status) echo "  ✓ Logged in to github.com account $active (keyring)" ;;
  switch) echo "$user" > "$d/active" ;;
esac
"#,
            dir = dir.display()
        );
        std::fs::write(&path, script).unwrap();
        std::fs::write(dir.join("active"), "user-1\n").unwrap();
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
        path
    }

    #[cfg(unix)]
    #[test]
    fn each_profile_uses_its_own_account_whichever_is_active() {
        let dir = tempfile::tempdir().unwrap();
        let program = multi_gh(dir.path());
        let one = GhTokenFallback::new(Arc::new(FakeGh(program.clone())));
        let two = GhTokenFallback::new(Arc::new(FakeGh(program)));
        one.use_accounts(&[GhAccount::new("github.com", "user-1")]);
        two.use_accounts(&[GhAccount::new("github.com", "user-2")]);
        assert_eq!(one.token(&github()).as_deref(), Some("token-of-user-1"));
        assert_eq!(two.token(&github()).as_deref(), Some("token-of-user-2"));
        assert_eq!(two.account(&github()).as_deref(), Some("user-2"));

        // Switching gh's active account in a terminal changes nothing.
        std::fs::write(dir.path().join("active"), "user-2\n").unwrap();
        one.forget(&github());
        assert_eq!(one.token(&github()).as_deref(), Some("token-of-user-1"));
    }

    #[cfg(unix)]
    #[test]
    fn signing_in_keeps_the_account_that_was_active() {
        let dir = tempfile::tempdir().unwrap();
        let gh = GhTokenFallback::new(Arc::new(FakeGh(multi_gh(dir.path()))));
        gh.sign_in(&github()).unwrap();
        // Not done yet: user-1 is still the active account.
        assert_eq!(gh.signed_in(&github()), None);

        // `gh auth login` as user-2 makes it active...
        std::fs::write(dir.path().join("active"), "user-2\n").unwrap();
        assert_eq!(gh.signed_in(&github()).as_deref(), Some("user-2"));
        // ...and user-1 is active again, while this profile uses user-2.
        let active = std::fs::read_to_string(dir.path().join("active")).unwrap();
        assert_eq!(active.trim(), "user-1");
        assert_eq!(gh.token(&github()).as_deref(), Some("token-of-user-2"));
    }
}
