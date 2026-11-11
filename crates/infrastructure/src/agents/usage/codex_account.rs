//! Codex's plan usage, asked of the ChatGPT account with Codex's own
//! sign-in (`<CODEX_HOME>/auth.json`): the same numbers as `/status`,
//! whether or not a session runs. Kumo only reads the sign-in; Codex
//! renews it when it runs.

use std::path::{Path, PathBuf};

use kumo_domain::agents::{AccountProblem, AccountUsage, PlanReading, UsageWindow};
use serde_json::Value;

use super::account::{AccountHttp, from_unix_secs};
use super::codex::plan_name;

const USAGE_URL: &str = "https://chatgpt.com/backend-api/wham/usage";

/// [`AccountUsage`] for Codex's ChatGPT account.
#[derive(Debug)]
pub struct CodexAccount {
    /// `CODEX_HOME` (see [`super::codex_home`]).
    home: PathBuf,
    http: AccountHttp,
}

impl CodexAccount {
    pub fn new(home: &Path) -> Self {
        Self {
            home: home.to_owned(),
            http: AccountHttp::new("ChatGPT"),
        }
    }
}

impl AccountUsage for CodexAccount {
    fn provider_id(&self) -> &str {
        "codex"
    }

    fn read(&self) -> Result<PlanReading, AccountProblem> {
        let saved = std::fs::read_to_string(self.home.join("auth.json"))
            .map_err(|_| AccountProblem::SignedOut("Codex isn't signed in".into()))?;
        let saved: Value = serde_json::from_str(&saved).map_err(|_| {
            AccountProblem::Unavailable("Codex's sign-in is in a form Kumo can't read".into())
        })?;
        let tokens = saved.get("tokens").filter(|t| !t.is_null());
        let token = tokens
            .and_then(|t| t.get("access_token"))
            .and_then(Value::as_str)
            .filter(|t| !t.is_empty());
        let Some(token) = token else {
            return Err(
                if saved.get("OPENAI_API_KEY").is_some_and(Value::is_string) {
                    // Paid per use: no plan limits to show.
                    AccountProblem::Unavailable(
                        "Codex uses an API key: it has no plan limits".into(),
                    )
                } else {
                    AccountProblem::SignedOut("Codex isn't signed in".into())
                },
            );
        };
        let auth = format!("Bearer {token}");
        let mut headers = vec![("Authorization", auth.as_str())];
        if let Some(account) = tokens
            .and_then(|t| t.get("account_id"))
            .and_then(Value::as_str)
        {
            headers.push(("ChatGPT-Account-Id", account));
        }
        let answer = self.http.get(USAGE_URL, &headers)?;
        Ok(reading_of(&answer))
    }
}

fn reading_of(answer: &Value) -> PlanReading {
    let limits = answer.get("rate_limit");
    let windows = ["primary_window", "secondary_window"]
        .iter()
        .filter_map(|key| {
            let window = limits?.get(*key)?;
            let used = window.get("used_percent")?.as_f64()?;
            let seconds = window.get("limit_window_seconds")?.as_u64()?;
            let resets_at = window
                .get("reset_at")
                .and_then(Value::as_u64)
                .filter(|s| *s > 0)
                .map(from_unix_secs);
            Some(UsageWindow::percent_over_minutes(
                seconds / 60,
                used,
                resets_at,
            ))
        })
        .collect();
    PlanReading {
        plan: answer
            .get("plan_type")
            .and_then(Value::as_str)
            .map(plan_name)
            .unwrap_or_default(),
        windows,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Trimmed from an answer of 2026-11.
    const ANSWER: &str = r#"{"plan_type":"plus","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":25,"limit_window_seconds":18000,"reset_after_seconds":18000,"reset_at":1794382708},"secondary_window":{"used_percent":1,"limit_window_seconds":604800,"reset_after_seconds":416165,"reset_at":1794780872}},"code_review_rate_limit":null,"credits":{"has_credits":false,"unlimited":false,"balance":"0"}}"#;

    #[test]
    fn reads_the_plan_and_both_windows() {
        let reading = reading_of(&serde_json::from_str(ANSWER).unwrap());
        assert_eq!(reading.plan, "ChatGPT Plus");
        let seen: Vec<_> = reading
            .windows
            .iter()
            .map(|w| (w.label.as_str(), w.left, w.resets_at))
            .collect();
        assert_eq!(
            seen,
            [
                ("5-hour session", 75.0, Some(from_unix_secs(1_794_382_708))),
                ("Weekly", 99.0, Some(from_unix_secs(1_794_780_872))),
            ]
        );
    }

    #[test]
    fn signed_out_or_on_an_api_key_tells_why() {
        let home = tempfile::tempdir().unwrap();
        let account = CodexAccount::new(home.path());
        assert!(matches!(account.read(), Err(AccountProblem::SignedOut(_))));
        std::fs::write(
            home.path().join("auth.json"),
            r#"{"auth_mode":"apikey","OPENAI_API_KEY":"sk-x","tokens":null}"#,
        )
        .unwrap();
        assert!(matches!(
            account.read(),
            Err(AccountProblem::Unavailable(_))
        ));
    }
}
