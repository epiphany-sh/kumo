//! What the account readers share: asking over HTTPS and reading the
//! dates the answers carry.

use std::time::Duration;

use kumo_domain::agents::AccountProblem;
use kumo_domain::time::Timestamp;
use serde_json::Value;
use ureq::tls::{RootCerts, TlsConfig, TlsProvider};

use super::codex::parse_utc;

/// JSON over HTTPS with the OS's TLS and trust store, failures told as
/// [`AccountProblem`]s.
#[derive(Debug, Clone)]
pub(super) struct AccountHttp {
    agent: ureq::Agent,
    /// Whose account, in messages: "Claude", "ChatGPT", "GitHub".
    name: &'static str,
}

impl AccountHttp {
    pub(super) fn new(name: &'static str) -> Self {
        let tls = TlsConfig::builder()
            .provider(TlsProvider::NativeTls)
            .root_certs(RootCerts::PlatformVerifier)
            .build();
        let agent = ureq::Agent::config_builder()
            .tls_config(tls)
            .timeout_global(Some(Duration::from_secs(20)))
            .http_status_as_error(false)
            .user_agent(concat!("kumo/", env!("CARGO_PKG_VERSION")))
            .build()
            .into();
        Self { agent, name }
    }

    /// GETs `url` with `headers`. Never logs them: they carry the sign-in.
    pub(super) fn get(&self, url: &str, headers: &[(&str, &str)]) -> Result<Value, AccountProblem> {
        let name = self.name;
        let mut request = self.agent.get(url).header("Accept", "application/json");
        for (header, value) in headers {
            request = request.header(*header, *value);
        }
        let mut response = request.call().map_err(|e| {
            AccountProblem::Unavailable(format!("Can't reach {name} to read the usage: {e}"))
        })?;
        let status = response.status().as_u16();
        let body = response
            .body_mut()
            .with_config()
            .limit(4 * 1024 * 1024)
            .read_to_string()
            .map_err(|e| {
                AccountProblem::Unavailable(format!("{name} cut the answer short: {e}"))
            })?;
        match status {
            200..=299 => serde_json::from_str(&body).map_err(|_| {
                AccountProblem::Unavailable(format!("{name} answered something unexpected"))
            }),
            401 => Err(AccountProblem::SignedOut(format!(
                "{name} turned the sign-in down: it expired or was signed out"
            ))),
            403 => Err(AccountProblem::SignedOut(format!(
                "{name} won't tell this sign-in its usage"
            ))),
            429 => Err(AccountProblem::Unavailable(format!(
                "{name} asks to wait before reading the usage again"
            ))),
            _ => Err(AccountProblem::Unavailable(format!(
                "{name} couldn't tell the usage ({status})"
            ))),
        }
    }
}

/// An RFC 3339 time: `2026-11-15T08:00:00.0736+00:00`, or with `Z`.
pub(super) fn parse_rfc3339(raw: &str) -> Option<Timestamp> {
    if raw.ends_with('Z') {
        return parse_utc(raw);
    }
    let time_at = raw.find('T')?;
    let offset_at = time_at + raw[time_at..].rfind(['+', '-'])?;
    let (local, offset) = raw.split_at(offset_at);
    let east = offset.starts_with('+');
    let (hours, minutes) = offset[1..].split_once(':')?;
    let offset_secs = hours.parse::<u64>().ok()? * 3_600 + minutes.parse::<u64>().ok()? * 60;
    let local = parse_utc(&format!("{local}Z"))?.as_unix_nanos();
    let shift = offset_secs * 1_000_000_000;
    // East of UTC is ahead of it: UTC is earlier.
    let utc = if east {
        local.checked_sub(shift)?
    } else {
        local.checked_add(shift)?
    };
    Some(Timestamp::from_unix_nanos(utc))
}

/// A date (`2026-12-01`) at its start, UTC; or a full RFC 3339 time.
pub(super) fn parse_day(raw: &str) -> Option<Timestamp> {
    if raw.contains('T') {
        parse_rfc3339(raw)
    } else {
        parse_utc(&format!("{raw}T00:00:00Z"))
    }
}

/// Unix seconds, as some answers carry times.
pub(super) fn from_unix_secs(secs: u64) -> Timestamp {
    Timestamp::from_unix_nanos(secs.saturating_mul(1_000_000_000))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_times_with_an_offset_as_utc() {
        let z = parse_utc("2026-11-15T08:00:00Z").unwrap();
        assert_eq!(parse_rfc3339("2026-11-15T08:00:00.000+00:00"), Some(z));
        assert_eq!(parse_rfc3339("2026-11-15T05:00:00-03:00"), Some(z));
        assert_eq!(parse_rfc3339("2026-11-15T10:00:00+02:00"), Some(z));
        assert_eq!(parse_rfc3339("2026-11-15T08:00:00Z"), Some(z));
        assert_eq!(parse_rfc3339("not a time"), None);
    }

    #[test]
    fn a_day_starts_at_midnight_utc() {
        assert_eq!(parse_day("2026-12-01"), parse_utc("2026-12-01T00:00:00Z"));
        assert_eq!(
            parse_day("2026-12-01T00:00:00.000Z"),
            parse_utc("2026-12-01T00:00:00Z")
        );
    }
}
