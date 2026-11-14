//! Copilot's plan usage, asked of the GitHub account with the sign-in
//! Copilot CLI uses: its premium requests (or credits) left this month,
//! whether or not a session runs.
//!
//! The sign-in is looked for where Copilot CLI looks: the
//! `COPILOT_GITHUB_TOKEN`, `GH_TOKEN` and `GITHUB_TOKEN` variables, the
//! one it saved (OS keychain item `copilot-cli`), and `gh`'s. Kumo only
//! reads it.

use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

use kumo_domain::agents::{
    AccountProblem, AccountUsage, PlanReading, ProgramLocator, UsageUnit, UsageWindow,
};
use serde_json::Value;

use super::account::{AccountHttp, parse_day};

const USAGE_URL: &str = "https://api.github.com/copilot_internal/user";
const KEYCHAIN_SERVICE: &str = "copilot-cli";
const TOKEN_VARIABLES: [&str; 3] = ["COPILOT_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"];

/// [`AccountUsage`] for Copilot CLI's GitHub account.
pub struct CopilotAccount {
    /// Copilot CLI's folder: `$COPILOT_HOME`, else `~/.copilot`.
    config_dir: PathBuf,
    locator: Arc<dyn ProgramLocator>,
    /// The user didn't let Kumo read the keychain item: not asked again
    /// while Kumo runs.
    keychain_refused: AtomicBool,
    http: AccountHttp,
}

impl std::fmt::Debug for CopilotAccount {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("CopilotAccount")
            .field("config_dir", &self.config_dir)
            .finish_non_exhaustive()
    }
}

impl CopilotAccount {
    pub fn new(home: &Path, locator: Arc<dyn ProgramLocator>) -> Self {
        let config_dir = std::env::var_os("COPILOT_HOME")
            .filter(|v| !v.is_empty())
            .map_or_else(|| home.join(".copilot"), PathBuf::from);
        Self {
            config_dir,
            locator,
            keychain_refused: AtomicBool::new(false),
            http: AccountHttp::new("GitHub"),
        }
    }

    fn token(&self) -> Option<String> {
        TOKEN_VARIABLES
            .iter()
            .find_map(|name| std::env::var(name).ok().filter(|t| !t.trim().is_empty()))
            .or_else(|| self.saved_token())
            .or_else(|| self.gh_token())
    }

    /// The one Copilot CLI saved, for the user it last signed in.
    fn saved_token(&self) -> Option<String> {
        if self.keychain_refused.load(Ordering::Relaxed) {
            return None;
        }
        let accounts = last_user(&self.config_dir)
            .map(|(host, login)| format!("{host}:{login}"))
            .into_iter()
            .map(Some)
            .chain([None]);
        for account in accounts {
            match crate::platform::saved_secret(KEYCHAIN_SERVICE, account.as_deref()) {
                Ok(Some(secret)) => return token_in(&secret),
                Ok(None) => {}
                Err(why) => {
                    tracing::debug!(%why, "Copilot CLI's sign-in can't be read from the keychain");
                    self.keychain_refused.store(true, Ordering::Relaxed);
                    return None;
                }
            }
        }
        None
    }

    fn gh_token(&self) -> Option<String> {
        let gh = self.locator.locate("gh")?;
        let out = crate::platform::background(&gh)
            .args(["auth", "token"])
            .env("PATH", self.locator.search_path())
            .stdin(Stdio::null())
            .stderr(Stdio::null())
            .output()
            .ok()?;
        let token = String::from_utf8_lossy(&out.stdout).trim().to_owned();
        (out.status.success() && !token.is_empty()).then_some(token)
    }
}

impl AccountUsage for CopilotAccount {
    fn provider_id(&self) -> &str {
        "copilot"
    }

    fn read(&self) -> Result<PlanReading, AccountProblem> {
        let token = self
            .token()
            .ok_or_else(|| AccountProblem::SignedOut("Copilot CLI isn't signed in".into()))?;
        let auth = format!("token {token}");
        let answer = self.http.get(
            USAGE_URL,
            &[
                ("Authorization", &auth),
                ("X-GitHub-Api-Version", "2025-04-01"),
                (
                    "Editor-Version",
                    concat!("kumo/", env!("CARGO_PKG_VERSION")),
                ),
            ],
        )?;
        Ok(reading_of(&answer))
    }
}

/// `(host, login)` of the user Copilot CLI last signed in.
fn last_user(config_dir: &Path) -> Option<(String, String)> {
    let config: Value =
        serde_json::from_str(&std::fs::read_to_string(config_dir.join("config.json")).ok()?)
            .ok()?;
    let user = config.get("last_logged_in_user")?;
    let host = user.get("host")?.as_str()?;
    let login = user.get("login")?.as_str()?;
    Some((host.to_owned(), login.to_owned()))
}

/// The token in a saved secret: the token itself, or JSON holding it.
fn token_in(secret: &str) -> Option<String> {
    let secret = secret.trim();
    let token = match serde_json::from_str::<Value>(secret) {
        Ok(Value::Object(saved)) => ["token", "access_token", "oauth_token"]
            .iter()
            .find_map(|key| saved.get(*key).and_then(Value::as_str))?
            .to_owned(),
        _ => secret.to_owned(),
    };
    (!token.is_empty()).then_some(token)
}

fn reading_of(answer: &Value) -> PlanReading {
    let resets_at = [
        "quota_reset_date_utc",
        "quota_reset_date",
        "limited_user_reset_date",
    ]
    .iter()
    .find_map(|key| answer.get(*key).and_then(Value::as_str).and_then(parse_day));
    let mut windows = Vec::new();
    if let Some(snapshots) = answer.get("quota_snapshots").and_then(Value::as_object) {
        // Premium requests first: what plans run out of.
        let mut keys: Vec<&String> = snapshots.keys().collect();
        keys.sort_by_key(|k| (k.as_str() != "premium_interactions", k.as_str()));
        for key in keys {
            let snapshot = &snapshots[key];
            if snapshot.get("unlimited").and_then(Value::as_bool) == Some(true) {
                continue;
            }
            let of = snapshot
                .get("entitlement")
                .and_then(Value::as_f64)
                .unwrap_or(0.0);
            let left = snapshot.get("remaining").and_then(Value::as_f64);
            if of <= 0.0 {
                continue;
            }
            let left = left.or_else(|| {
                let percent = snapshot.get("percent_remaining")?.as_f64()?;
                Some(of * percent / 100.0)
            });
            if let Some(left) = left {
                windows.push(monthly(quota_label(key), left, of, resets_at));
            }
        }
    } else if let (Some(left), Some(of)) = (
        answer.get("limited_user_quotas").and_then(Value::as_object),
        answer.get("monthly_quotas").and_then(Value::as_object),
    ) {
        // The free plan counts chats and completions instead.
        for (key, total) in of {
            let (Some(total), Some(left)) = (total.as_f64(), left.get(key).and_then(Value::as_f64))
            else {
                continue;
            };
            if total > 0.0 {
                windows.push(monthly(quota_label(key), left, total, resets_at));
            }
        }
    }
    PlanReading {
        plan: plan_name(answer),
        windows,
    }
}

fn monthly(
    label: String,
    left: f64,
    of: f64,
    resets_at: Option<kumo_domain::time::Timestamp>,
) -> UsageWindow {
    UsageWindow {
        label,
        short: "mo".into(),
        left: left.clamp(0.0, of),
        of,
        unit: UsageUnit::Requests,
        resets_at,
    }
}

fn quota_label(key: &str) -> String {
    match key {
        "premium_interactions" => "Premium requests · monthly".into(),
        "chat" => "Chat messages · monthly".into(),
        "completions" => "Code completions · monthly".into(),
        other => {
            let mut chars = other.chars();
            let first = chars.next().map(|c| c.to_uppercase().to_string());
            format!(
                "{}{} · monthly",
                first.unwrap_or_default(),
                chars.as_str().replace('_', " ")
            )
        }
    }
}

fn plan_name(answer: &Value) -> String {
    let sku = answer
        .get("access_type_sku")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let plan = answer
        .get("copilot_plan")
        .and_then(Value::as_str)
        .unwrap_or_default();
    match plan {
        "free" => "Copilot Free".into(),
        "individual" if sku.contains("plus") => "Copilot Pro+".into(),
        "individual" | "individual_pro" => "Copilot Pro".into(),
        "business" => "Copilot Business".into(),
        "enterprise" => "Copilot Enterprise".into(),
        _ => String::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const PRO: &str = r#"{"login":"someone","access_type_sku":"monthly_subscriber","copilot_plan":"individual","quota_reset_date":"2026-12-01","quota_reset_date_utc":"2026-12-01T00:00:00.000Z","quota_snapshots":{"chat":{"entitlement":0,"remaining":0,"percent_remaining":100,"unlimited":true},"completions":{"entitlement":0,"remaining":0,"percent_remaining":100,"unlimited":true},"premium_interactions":{"entitlement":300,"remaining":250.5,"percent_remaining":83.5,"unlimited":false,"overage_permitted":false}}}"#;
    const FREE: &str = r#"{"login":"someone","access_type_sku":"free_limited_copilot","copilot_plan":"free","limited_user_quotas":{"chat":40,"completions":1900},"monthly_quotas":{"chat":50,"completions":2000},"limited_user_reset_date":"2026-12-01"}"#;

    #[test]
    fn reads_premium_requests_left_this_month() {
        let reading = reading_of(&serde_json::from_str(PRO).unwrap());
        assert_eq!(reading.plan, "Copilot Pro");
        assert_eq!(reading.windows.len(), 1, "unlimited quotas are left out");
        let w = &reading.windows[0];
        assert_eq!(
            (w.label.as_str(), w.short.as_str(), w.left, w.of, w.unit),
            (
                "Premium requests · monthly",
                "mo",
                250.5,
                300.0,
                UsageUnit::Requests
            )
        );
        assert_eq!(w.resets_at, parse_day("2026-12-01"));
    }

    #[test]
    fn the_free_plan_counts_chats_and_completions() {
        let reading = reading_of(&serde_json::from_str(FREE).unwrap());
        assert_eq!(reading.plan, "Copilot Free");
        let mut seen: Vec<_> = reading
            .windows
            .iter()
            .map(|w| (w.label.as_str(), w.left, w.of))
            .collect();
        seen.sort_by(|a, b| a.0.cmp(b.0));
        assert_eq!(
            seen,
            [
                ("Chat messages · monthly", 40.0, 50.0),
                ("Code completions · monthly", 1900.0, 2000.0),
            ]
        );
    }

    #[test]
    fn a_saved_token_is_the_secret_or_inside_it() {
        assert_eq!(token_in("gho_abc\n").as_deref(), Some("gho_abc"));
        assert_eq!(
            token_in(r#"{"token":"gho_abc"}"#).as_deref(),
            Some("gho_abc")
        );
        assert_eq!(token_in(""), None);
    }

    #[test]
    fn finds_the_user_copilot_last_signed_in() {
        let dir = tempfile::tempdir().unwrap();
        assert_eq!(last_user(dir.path()), None);
        std::fs::write(
            dir.path().join("config.json"),
            r#"{"last_logged_in_user":{"host":"https://github.com","login":"someone"}}"#,
        )
        .unwrap();
        assert_eq!(
            last_user(dir.path()),
            Some(("https://github.com".into(), "someone".into()))
        );
    }
}
