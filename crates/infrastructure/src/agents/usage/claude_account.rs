//! Claude's plan usage, asked of the account with Claude Code's own
//! sign-in: the same numbers as `/usage`, whether or not a session runs.
//!
//! Claude Code keeps its sign-in in the macOS keychain (item
//! `Claude Code-credentials`, or `…-<8 hex of sha256(folder)>` when
//! `CLAUDE_CONFIG_DIR` sets its folder), elsewhere in
//! `<folder>/.credentials.json`. Kumo only reads it. When it has expired,
//! `claude auth status` renews it, and Claude Code saves the new one
//! itself: Kumo never writes the user's sign-in.

use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::sync::Arc;

use kumo_domain::agents::{AccountProblem, AccountUsage, PlanReading, ProgramLocator, UsageWindow};
use kumo_domain::time::Timestamp;
use serde_json::Value;
use sha2::{Digest, Sha256};

use super::account::{AccountHttp, parse_rfc3339};

const USAGE_URL: &str = "https://api.anthropic.com/api/oauth/usage";
const OAUTH_BETA: &str = "oauth-2025-04-20";
const KEYCHAIN_SERVICE: &str = "Claude Code-credentials";
/// A sign-in this close to expiring is renewed before asking.
const RENEW_BEFORE_MS: u64 = 60_000;

/// [`AccountUsage`] for Claude Code's account.
pub struct ClaudeAccount {
    config_dir: PathBuf,
    /// `CLAUDE_CONFIG_DIR` points Claude Code at `config_dir` (a profile's
    /// own folder, or the user set it).
    own_dir: bool,
    locator: Arc<dyn ProgramLocator>,
    http: AccountHttp,
}

impl std::fmt::Debug for ClaudeAccount {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ClaudeAccount")
            .field("config_dir", &self.config_dir)
            .field("own_dir", &self.own_dir)
            .finish_non_exhaustive()
    }
}

/// What Claude Code keeps of its sign-in. Never logged.
struct SignIn {
    token: String,
    expires_at_ms: Option<u64>,
    /// "max", "pro".
    subscription: String,
    /// "default_claude_max_20x".
    tier: String,
}

impl ClaudeAccount {
    /// `config_dir`: Claude Code's folder (see
    /// [`super::claude_config_dir`]); `own_dir`: whether
    /// `CLAUDE_CONFIG_DIR` names it.
    pub fn new(config_dir: &Path, own_dir: bool, locator: Arc<dyn ProgramLocator>) -> Self {
        Self {
            config_dir: config_dir.to_owned(),
            own_dir,
            locator,
            http: AccountHttp::new("Claude"),
        }
    }

    fn sign_in(&self) -> Result<Option<SignIn>, AccountProblem> {
        let service = keychain_service(&self.config_dir, self.own_dir);
        let saved = match crate::platform::saved_secret(&service, None) {
            Ok(Some(secret)) => Some(secret),
            Ok(None) => None,
            Err(why) => {
                tracing::debug!(%why, "Claude Code's sign-in can't be read from the keychain");
                None
            }
        };
        let saved = saved
            .or_else(|| std::fs::read_to_string(self.config_dir.join(".credentials.json")).ok());
        let Some(saved) = saved else {
            return Ok(None);
        };
        parse_sign_in(&saved).map(Some).ok_or_else(|| {
            AccountProblem::Unavailable("Claude Code's sign-in is in a form Kumo can't read".into())
        })
    }

    /// Has Claude Code renew its sign-in (`claude auth status` does, and
    /// saves it). False when it says it isn't signed in.
    fn renew(&self) -> Result<bool, AccountProblem> {
        let program = self.locator.locate("claude").ok_or_else(|| {
            AccountProblem::Unavailable(
                "Claude Code isn't installed: its sign-in can't be renewed".into(),
            )
        })?;
        let mut command = crate::platform::background(&program);
        command
            .args(["auth", "status"])
            .env("PATH", self.locator.search_path())
            .current_dir(self.locator.home())
            .stdin(Stdio::null())
            .stderr(Stdio::null());
        if self.own_dir {
            command.env("CLAUDE_CONFIG_DIR", &self.config_dir);
        }
        let out = command.output().map_err(|e| {
            AccountProblem::Unavailable(format!("Claude Code couldn't renew its sign-in: {e}"))
        })?;
        let status: Value = serde_json::from_slice(&out.stdout).unwrap_or(Value::Null);
        Ok(status
            .get("loggedIn")
            .and_then(Value::as_bool)
            .unwrap_or(out.status.success()))
    }

    fn ask(&self, sign_in: &SignIn) -> Result<PlanReading, AccountProblem> {
        let auth = format!("Bearer {}", sign_in.token);
        let answer = self.http.get(
            USAGE_URL,
            &[("Authorization", &auth), ("anthropic-beta", OAUTH_BETA)],
        )?;
        Ok(PlanReading {
            plan: plan_name(&sign_in.subscription, &sign_in.tier),
            windows: windows_of(&answer),
        })
    }
}

impl AccountUsage for ClaudeAccount {
    fn provider_id(&self) -> &str {
        "claude"
    }

    fn read(&self) -> Result<PlanReading, AccountProblem> {
        let signed_out = || AccountProblem::SignedOut("Claude Code isn't signed in".into());
        let mut sign_in = self.sign_in()?;
        let now_ms = Timestamp::now().as_unix_nanos() / 1_000_000;
        let stale = sign_in.as_ref().is_none_or(|s| {
            s.expires_at_ms
                .is_some_and(|at| at <= now_ms + RENEW_BEFORE_MS)
        });
        if stale {
            if !self.renew()? {
                return Err(signed_out());
            }
            sign_in = self.sign_in()?;
        }
        let sign_in = sign_in.ok_or_else(signed_out)?;
        match self.ask(&sign_in) {
            // Turned down before it expired (renewed elsewhere): once more.
            Err(AccountProblem::SignedOut(_)) if !stale && self.renew()? => {
                let renewed = self.sign_in()?.ok_or_else(signed_out)?;
                self.ask(&renewed)
            }
            answer => answer,
        }
    }
}

/// The keychain item Claude Code keeps its sign-in in.
fn keychain_service(config_dir: &Path, own_dir: bool) -> String {
    if !own_dir {
        return KEYCHAIN_SERVICE.to_owned();
    }
    let digest = Sha256::digest(config_dir.display().to_string().as_bytes());
    format!("{KEYCHAIN_SERVICE}-{}", &hex::encode(digest)[..8])
}

fn parse_sign_in(saved: &str) -> Option<SignIn> {
    let saved: Value = serde_json::from_str(saved).ok()?;
    let oauth = saved.get("claudeAiOauth")?;
    let text = |key: &str| {
        oauth
            .get(key)
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_owned()
    };
    let token = text("accessToken");
    (!token.is_empty()).then(|| SignIn {
        token,
        expires_at_ms: oauth.get("expiresAt").and_then(Value::as_u64),
        subscription: text("subscriptionType"),
        tier: text("rateLimitTier"),
    })
}

/// "max" + "default_claude_max_20x" → "Claude Max 20x".
fn plan_name(subscription: &str, tier: &str) -> String {
    let mut chars = subscription.chars();
    let Some(first) = chars.next() else {
        return String::new();
    };
    let name = format!("Claude {}{}", first.to_uppercase(), chars.as_str());
    match tier.rsplit('_').next() {
        Some(multiple)
            if multiple.ends_with('x') && multiple[..multiple.len() - 1].parse::<u32>().is_ok() =>
        {
            format!("{name} {multiple}")
        }
        _ => name,
    }
}

/// The windows the answer has numbers for: the 5-hour session, the week,
/// and the weekly limits of single models.
fn windows_of(answer: &Value) -> Vec<UsageWindow> {
    let window = |key: &str| {
        let window = answer.get(key)?;
        let used = window.get("utilization")?.as_f64()?;
        let resets_at = window
            .get("resets_at")
            .and_then(Value::as_str)
            .and_then(parse_rfc3339);
        Some((used, resets_at))
    };
    let mut windows = Vec::new();
    if let Some((used, resets_at)) = window("five_hour") {
        windows.push(UsageWindow::percent_over_minutes(300, used, resets_at));
    }
    if let Some((used, resets_at)) = window("seven_day") {
        windows.push(UsageWindow::percent_over_minutes(10_080, used, resets_at));
    }
    for (key, model) in [("seven_day_opus", "Opus"), ("seven_day_sonnet", "Sonnet")] {
        if let Some((used, resets_at)) = window(key) {
            windows.push(model_week(model, used, resets_at));
        }
    }
    // Newer answers list each model's weekly limit by its name.
    let scoped = answer
        .get("limits")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter(|l| l.get("kind").and_then(Value::as_str) == Some("weekly_scoped"))
        .filter(|l| l.get("is_active").and_then(Value::as_bool) == Some(true));
    for limit in scoped {
        let model = limit
            .pointer("/scope/model/display_name")
            .and_then(Value::as_str);
        let used = limit.get("percent").and_then(Value::as_f64);
        let (Some(model), Some(used)) = (model, used) else {
            continue;
        };
        let resets_at = limit
            .get("resets_at")
            .and_then(Value::as_str)
            .and_then(parse_rfc3339);
        let window = model_week(model, used, resets_at);
        if !windows.iter().any(|w| w.label == window.label) {
            windows.push(window);
        }
    }
    windows
}

fn model_week(model: &str, used: f64, resets_at: Option<Timestamp>) -> UsageWindow {
    UsageWindow::percent_used(format!("Weekly · {model}"), "wk", used, resets_at)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Trimmed from an answer of 2026-11 (the names Claude doesn't
    /// document are left out).
    const ANSWER: &str = r#"{"five_hour":{"utilization":23.0,"resets_at":"2026-11-11T05:00:00.511+00:00"},"seven_day":{"utilization":5.0,"resets_at":"2026-11-15T08:00:00.073663+00:00","limit_dollars":null},"seven_day_opus":null,"seven_day_sonnet":null,"extra_usage":{"is_enabled":false},"limits":[{"kind":"weekly_all","group":"weekly","percent":5,"resets_at":"2026-11-15T08:00:00.073663+00:00","scope":null,"is_active":true},{"kind":"weekly_scoped","group":"weekly","percent":12,"resets_at":"2026-11-15T08:00:00.073806+00:00","scope":{"model":{"id":null,"display_name":"Fable"},"surface":null},"is_active":true},{"kind":"weekly_scoped","group":"weekly","percent":0,"resets_at":"2026-11-15T08:00:00.073806+00:00","scope":{"model":{"id":null,"display_name":"Other"},"surface":null},"is_active":false}]}"#;

    #[test]
    fn reads_the_session_the_week_and_each_models_week() {
        let windows = windows_of(&serde_json::from_str(ANSWER).unwrap());
        let seen: Vec<_> = windows
            .iter()
            .map(|w| (w.label.as_str(), w.short.as_str(), w.left))
            .collect();
        assert_eq!(
            seen,
            [
                ("5-hour session", "5h", 77.0),
                ("Weekly", "wk", 95.0),
                ("Weekly · Fable", "wk", 88.0),
            ]
        );
        assert_eq!(
            windows[0].resets_at,
            parse_rfc3339("2026-11-11T05:00:00.511Z")
        );
    }

    #[test]
    fn a_window_with_no_numbers_is_left_out() {
        let answer = serde_json::json!({"five_hour": null, "seven_day": {"utilization": 1.0}});
        let windows = windows_of(&answer);
        assert_eq!(windows.len(), 1);
        assert_eq!(
            (windows[0].label.as_str(), windows[0].resets_at),
            ("Weekly", None)
        );
    }

    #[test]
    fn names_the_plan_after_the_subscription_and_its_tier() {
        assert_eq!(plan_name("max", "default_claude_max_20x"), "Claude Max 20x");
        assert_eq!(plan_name("max", "default_claude_max_5x"), "Claude Max 5x");
        assert_eq!(plan_name("pro", "default_claude_ai"), "Claude Pro");
        assert_eq!(plan_name("", ""), "");
    }

    #[test]
    fn a_folder_of_its_own_keys_the_keychain_item_by_its_hash() {
        assert_eq!(
            keychain_service(Path::new("/x"), false),
            "Claude Code-credentials"
        );
        // As Claude Code names it: the first 8 hex of the folder's sha256.
        assert_eq!(
            keychain_service(Path::new("/Users/someone/.claude-work"), true),
            "Claude Code-credentials-18cc900a"
        );
    }

    #[test]
    fn reads_the_sign_in_as_claude_code_saves_it() {
        let saved = r#"{"claudeAiOauth":{"accessToken":"t0k","refreshToken":"r","expiresAt":1794372489969,"scopes":["user:inference"],"subscriptionType":"max","rateLimitTier":"default_claude_max_20x"}}"#;
        let sign_in = parse_sign_in(saved).unwrap();
        assert_eq!(sign_in.token, "t0k");
        assert_eq!(sign_in.expires_at_ms, Some(1_794_372_489_969));
        assert_eq!(
            plan_name(&sign_in.subscription, &sign_in.tier),
            "Claude Max 20x"
        );
        assert!(parse_sign_in(r#"{"claudeAiOauth":{}}"#).is_none());
        assert!(parse_sign_in("garbage").is_none());
    }
}
