//! JSON over HTTPS with the OS's TLS and trust store (so corporate proxies
//! and custom CAs work), mapping failures to what the user can act on.

use std::time::Duration;

use kumo_domain::tasks::{SourceKind, TaskError};
use serde_json::Value;
use ureq::tls::{RootCerts, TlsConfig, TlsProvider};

#[derive(Debug, Clone)]
pub(super) struct Http {
    agent: ureq::Agent,
    kind: SourceKind,
}

impl Http {
    pub(super) fn new(kind: SourceKind) -> Self {
        let tls = TlsConfig::builder()
            .provider(TlsProvider::NativeTls)
            .root_certs(RootCerts::PlatformVerifier)
            .build();
        let agent = ureq::Agent::config_builder()
            .tls_config(tls)
            .timeout_global(Some(Duration::from_secs(30)))
            .http_status_as_error(false)
            .user_agent(concat!("kumo/", env!("CARGO_PKG_VERSION")))
            .build()
            .into();
        Self { agent, kind }
    }

    pub(super) fn get(&self, url: &str, auth: &str) -> Result<Value, TaskError> {
        let response = self
            .agent
            .get(url)
            .header("Authorization", auth)
            .header("Accept", "application/json")
            .call();
        self.read(url, response)
    }

    pub(super) fn post_json(
        &self,
        url: &str,
        auth: &str,
        body: &Value,
    ) -> Result<Value, TaskError> {
        let response = self
            .agent
            .post(url)
            .header("Authorization", auth)
            .header("Accept", "application/json")
            .send_json(body);
        self.read(url, response)
    }

    pub(super) fn post_form(
        &self,
        url: &str,
        auth: &str,
        form: &[(&str, &str)],
    ) -> Result<Value, TaskError> {
        let response = self
            .agent
            .post(url)
            .header("Authorization", auth)
            .send_form(form.iter().copied());
        self.read(url, response)
    }

    fn read(
        &self,
        url: &str,
        response: Result<ureq::http::Response<ureq::Body>, ureq::Error>,
    ) -> Result<Value, TaskError> {
        let kind = self.kind;
        let mut response = response.map_err(|e| {
            TaskError::Unavailable(format!("can't reach {kind} ({}): {e}", host(url)))
        })?;
        let status = response.status().as_u16();
        let body = response
            .body_mut()
            .with_config()
            .limit(64 * 1024 * 1024)
            .read_to_string()
            .map_err(|e| {
                TaskError::Unavailable(format!("{kind}: reading the answer failed: {e}"))
            })?;
        match status {
            200..=299 if body.trim().is_empty() => Ok(Value::Null),
            200..=299 => serde_json::from_str(&body).map_err(|e| {
                TaskError::Source(format!("{kind} answered something unexpected: {e}"))
            }),
            401 => Err(TaskError::Auth(format!(
                "{kind} rejected the credentials: check the email and API token"
            ))),
            403 => Err(TaskError::Auth(format!(
                "{kind} denied access{}",
                detail(&body).map(|d| format!(": {d}")).unwrap_or_default()
            ))),
            429 => Err(TaskError::Unavailable(format!(
                "{kind} is rate limiting: retrying later"
            ))),
            500.. => Err(TaskError::Unavailable(format!(
                "{kind} is having problems ({status})"
            ))),
            _ => Err(TaskError::Source(format!(
                "{kind}: {}",
                detail(&body).unwrap_or_else(|| format!("request failed ({status})"))
            ))),
        }
    }
}

fn host(url: &str) -> &str {
    let rest = url.split_once("://").map_or(url, |(_, rest)| rest);
    rest.split('/').next().unwrap_or(rest)
}

/// The error message in a JSON error body (Jira, Todoist), if any.
fn detail(body: &str) -> Option<String> {
    let value: Value = serde_json::from_str(body).ok()?;
    let messages = value
        .get("errorMessages")
        .and_then(Value::as_array)
        .and_then(|m| m.first())
        .and_then(Value::as_str)
        .or_else(|| value.get("error").and_then(Value::as_str))
        .or_else(|| value.get("message").and_then(Value::as_str))?;
    Some(messages.chars().take(300).collect())
}
