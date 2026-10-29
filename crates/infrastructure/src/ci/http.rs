//! HTTPS for CI APIs: short timeouts, conditional requests (ETag) so that
//! polling an unchanged run costs no rate limit, and every failure
//! classified by what the user can do about it. Tokens only travel in
//! headers: they never reach an error or a log.

use std::collections::HashMap;
use std::sync::{Mutex, PoisonError};
use std::time::Duration;

use kumo_domain::pipelines::{CiProblem, CiProblemKind};
use kumo_domain::time::Timestamp;
use serde_json::Value;
use ureq::tls::{RootCerts, TlsConfig, TlsProvider};

const TIMEOUT: Duration = Duration::from_secs(10);

/// Conditional GETs remembered; beyond this, the cache starts over.
const MAX_CACHED: usize = 256;

/// A request header: (name, value).
pub(super) type Header = (&'static str, String);

/// What a provider answered.
#[derive(Debug, Clone, Default)]
pub(super) struct Answer {
    pub status: u16,
    pub headers: Vec<(String, String)>,
    pub body: String,
}

impl Answer {
    pub fn header(&self, name: &str) -> Option<&str> {
        self.headers
            .iter()
            .find(|(n, _)| n.eq_ignore_ascii_case(name))
            .map(|(_, v)| v.as_str())
    }
}

#[derive(Debug)]
pub(super) struct CiHttp {
    agent: ureq::Agent,
    /// url → (etag, body) of the last 200.
    etags: Mutex<HashMap<String, (String, String)>>,
}

impl Default for CiHttp {
    fn default() -> Self {
        let tls = TlsConfig::builder()
            .provider(TlsProvider::NativeTls)
            .root_certs(RootCerts::PlatformVerifier)
            .build();
        let agent = ureq::Agent::config_builder()
            .tls_config(tls)
            .timeout_global(Some(TIMEOUT))
            .http_status_as_error(false)
            .user_agent(concat!("kumo/", env!("CARGO_PKG_VERSION")))
            .build()
            .into();
        Self {
            agent,
            etags: Mutex::new(HashMap::new()),
        }
    }
}

impl CiHttp {
    /// GET as JSON, asking with the last ETag: a 304 reuses the last body.
    pub fn get_json(&self, url: &str, headers: &[Header]) -> Result<Value, CiProblem> {
        let cached = self.cache().get(url).cloned();
        let mut request = self.agent.get(url);
        for (name, value) in headers {
            request = request.header(*name, value);
        }
        if let Some((etag, _)) = &cached {
            request = request.header("If-None-Match", etag);
        }
        let answer = answer(url, request.call())?;
        let body = match (answer.status, cached) {
            (304, Some((_, body))) => body,
            (200..=299, _) => {
                if let Some(etag) = answer.header("etag") {
                    let mut cache = self.cache();
                    if cache.len() >= MAX_CACHED {
                        cache.clear();
                    }
                    cache.insert(url.to_owned(), (etag.to_owned(), answer.body.clone()));
                }
                answer.body
            }
            _ => return Err(classify(&answer, url, Timestamp::now())),
        };
        json(url, &body)
    }

    /// GET as text (job logs), without caching.
    pub fn get_text(&self, url: &str, headers: &[Header]) -> Result<String, CiProblem> {
        let mut request = self.agent.get(url);
        for (name, value) in headers {
            request = request.header(*name, value);
        }
        let answer = answer(url, request.call())?;
        if (200..=299).contains(&answer.status) {
            Ok(answer.body)
        } else {
            Err(classify(&answer, url, Timestamp::now()))
        }
    }

    /// POST, with a JSON body or none.
    pub fn post(
        &self,
        url: &str,
        headers: &[Header],
        body: Option<&Value>,
    ) -> Result<Value, CiProblem> {
        let mut request = self.agent.post(url);
        for (name, value) in headers {
            request = request.header(*name, value);
        }
        let answer = answer(
            url,
            match body {
                Some(body) => request.send_json(body),
                None => request.send_empty(),
            },
        )?;
        if (200..=299).contains(&answer.status) {
            if answer.body.trim().is_empty() {
                Ok(Value::Null)
            } else {
                json(url, &answer.body)
            }
        } else {
            Err(classify(&answer, url, Timestamp::now()))
        }
    }

    fn cache(&self) -> std::sync::MutexGuard<'_, HashMap<String, (String, String)>> {
        self.etags.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

fn json(url: &str, body: &str) -> Result<Value, CiProblem> {
    serde_json::from_str(body).map_err(|_| {
        CiProblem::new(
            CiProblemKind::Unreachable,
            format!("Unexpected answer from {}", domain(url)),
        )
    })
}

/// Reads a response; network failures are [`CiProblemKind::Unreachable`].
fn answer(
    url: &str,
    response: Result<ureq::http::Response<ureq::Body>, ureq::Error>,
) -> Result<Answer, CiProblem> {
    let mut response = response.map_err(|e| network(url, &e))?;
    let headers = response
        .headers()
        .iter()
        .filter_map(|(name, value)| {
            Some((name.as_str().to_owned(), value.to_str().ok()?.to_owned()))
        })
        .collect();
    let status = response.status().as_u16();
    let body = response
        .body_mut()
        .with_config()
        .limit(16 * 1024 * 1024)
        .read_to_string()
        .map_err(|e| network(url, &e))?;
    Ok(Answer {
        status,
        headers,
        body,
    })
}

fn network(url: &str, error: &ureq::Error) -> CiProblem {
    let host = domain(url);
    let detail = match error {
        ureq::Error::Timeout(_) => format!("Timed out after {} s · {host}", TIMEOUT.as_secs()),
        ureq::Error::HostNotFound => format!("Can't find {host}"),
        ureq::Error::ConnectionFailed => format!("Can't connect to {host}"),
        ureq::Error::Tls(_) | ureq::Error::NativeTls(_) => {
            format!("Secure connection to {host} failed")
        }
        _ => format!("Can't reach {host}"),
    };
    CiProblem::new(CiProblemKind::Unreachable, detail)
}

/// `api.github.com` from a URL.
pub(super) fn domain(url: &str) -> &str {
    let rest = url.split_once("://").map_or(url, |(_, rest)| rest);
    let authority = rest.split('/').next().unwrap_or(rest);
    authority.rsplit('@').next().unwrap_or(authority)
}

/// What an error answer means for the user (401, 403, 404, 429, 5xx…).
pub(super) fn classify(answer: &Answer, url: &str, now: Timestamp) -> CiProblem {
    let status = answer.status;
    let body: Value = serde_json::from_str(&answer.body).unwrap_or(Value::Null);
    let message = message(&body).unwrap_or_else(|| reason(status).to_owned());
    let detail = format!("HTTP {status} · {message}");
    let limited = status == 429
        || answer.header("x-ratelimit-remaining") == Some("0")
        || (status == 403
            && (answer.header("retry-after").is_some()
                || message.to_ascii_lowercase().contains("rate limit")));
    if limited {
        let mut problem = CiProblem::new(CiProblemKind::RateLimited, detail);
        problem.retry_at = retry_at(answer, now);
        return problem;
    }
    match status {
        401 => CiProblem::new(CiProblemKind::Unauthorized, detail),
        403 => {
            let mut problem = CiProblem::new(CiProblemKind::Forbidden, detail);
            problem.missing_scope = missing_scope(answer, &body);
            problem
        }
        500.. => CiProblem::new(
            CiProblemKind::Unreachable,
            format!("HTTP {status} · {}", domain(url)),
        ),
        _ => CiProblem::new(CiProblemKind::NotFound, detail),
    }
}

/// The error message in a JSON error body: GitHub and GitLab (`message`),
/// GitLab OAuth (`error_description`), Bitbucket (`error.message`).
fn message(body: &Value) -> Option<String> {
    let text = |v: &Value| {
        v.as_str()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(str::to_owned)
    };
    text(&body["message"])
        .or_else(|| text(&body["error"]["message"]))
        .or_else(|| text(&body["error_description"]))
        .or_else(|| text(&body["error"]))
        // GitLab validation errors: {"message": {"base": ["…"]}}.
        .or_else(|| {
            body["message"]
                .as_object()?
                .values()
                .find_map(|v| text(v.get(0)?))
        })
        .map(|m| m.lines().next().unwrap_or_default().to_owned())
}

fn reason(status: u16) -> &'static str {
    match status {
        400 => "Bad request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not found",
        409 => "Conflict",
        422 => "Unprocessable",
        429 => "Too many requests",
        _ => "Request failed",
    }
}

/// When to try again: `Retry-After` (seconds), else the reset time of the
/// rate limit (`x-ratelimit-reset` GitHub, `ratelimit-reset` GitLab).
fn retry_at(answer: &Answer, now: Timestamp) -> Option<Timestamp> {
    let secs = |v: &str| v.trim().parse::<u64>().ok();
    if let Some(after) = answer.header("retry-after").and_then(secs) {
        return Some(Timestamp::from_unix_nanos(
            now.as_unix_nanos() + after * 1_000_000_000,
        ));
    }
    let reset = answer
        .header("x-ratelimit-reset")
        .or_else(|| answer.header("ratelimit-reset"))
        .and_then(secs)?;
    Some(Timestamp::from_unix_nanos(reset * 1_000_000_000))
}

/// The permission the token lacks, when the provider says which.
fn missing_scope(answer: &Answer, body: &Value) -> String {
    // GitHub fine-grained tokens: `X-Accepted-GitHub-Permissions: actions=read`.
    if let Some(accepted) = answer.header("x-accepted-github-permissions") {
        let needed: Vec<String> = accepted
            .split([';', ','])
            .filter_map(|p| p.trim().split_once('='))
            .map(|(name, level)| format!("{}:{}", name.trim(), level.trim()))
            .collect();
        if !needed.is_empty() {
            return needed.join(", ");
        }
    }
    // GitHub classic tokens: accepted scopes the token doesn't have.
    if let Some(accepted) = answer.header("x-accepted-oauth-scopes") {
        let list = |v: &str| -> Vec<String> {
            v.split(',')
                .map(|s| s.trim().to_owned())
                .filter(|s| !s.is_empty())
                .collect()
        };
        let granted = list(answer.header("x-oauth-scopes").unwrap_or_default());
        let missing: Vec<String> = list(accepted)
            .into_iter()
            .filter(|s| !granted.contains(s))
            .collect();
        if !missing.is_empty() {
            return missing.join(" or ");
        }
    }
    // GitLab: {"error": "insufficient_scope", "scope": "read_api"}, or the
    // same in WWW-Authenticate.
    if let Some(scope) = body["scope"].as_str() {
        return scope.replace(' ', " or ");
    }
    if let Some(auth) = answer.header("www-authenticate")
        && let Some((_, rest)) = auth.split_once("scope=\"")
        && let Some((scope, _)) = rest.split_once('"')
    {
        return scope.replace(' ', " or ");
    }
    // Bitbucket: {"error": {"detail": {"required": ["pipeline"], "granted": […]}}}.
    let detail = &body["error"]["detail"];
    let names = |v: &Value| -> Vec<String> {
        v.as_array()
            .into_iter()
            .flatten()
            .filter_map(|s| s.as_str().map(str::to_owned))
            .collect()
    };
    let granted = names(&detail["granted"]);
    let missing: Vec<String> = names(&detail["required"])
        .into_iter()
        .filter(|s| !granted.contains(s))
        .collect();
    missing.join(", ")
}

/// Percent-encodes a path segment or query value.
pub(crate) fn enc(raw: &str) -> String {
    let mut out = String::with_capacity(raw.len());
    for b in raw.bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'.' | b'_' | b'~') {
            out.push(char::from(b));
        } else {
            out.push_str(&format!("%{b:02X}"));
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    const NOW: Timestamp = Timestamp::from_unix_nanos(1_800_000_000_000_000_000);

    fn answer(status: u16, headers: &[(&str, &str)], body: &str) -> Answer {
        Answer {
            status,
            headers: headers
                .iter()
                .map(|(n, v)| ((*n).to_owned(), (*v).to_owned()))
                .collect(),
            body: body.to_owned(),
        }
    }

    fn problem(status: u16, headers: &[(&str, &str)], body: &str) -> CiProblem {
        classify(
            &answer(status, headers, body),
            "https://api.github.com/repos/a/b/actions/runs",
            NOW,
        )
    }

    /// Status, headers, body → kind and detail.
    type Case = (
        u16,
        &'static [(&'static str, &'static str)],
        &'static str,
        CiProblemKind,
        &'static str,
    );

    #[test]
    fn every_answer_maps_to_what_the_user_can_do() {
        let cases: [Case; 9] = [
            (
                401,
                &[],
                r#"{"message":"Bad credentials"}"#,
                CiProblemKind::Unauthorized,
                "HTTP 401 · Bad credentials",
            ),
            (
                403,
                &[],
                r#"{"message":"Resource not accessible by personal access token"}"#,
                CiProblemKind::Forbidden,
                "HTTP 403 · Resource not accessible by personal access token",
            ),
            (
                404,
                &[],
                r#"{"message":"Not Found"}"#,
                CiProblemKind::NotFound,
                "HTTP 404 · Not Found",
            ),
            (
                403,
                &[
                    ("x-ratelimit-remaining", "0"),
                    ("x-ratelimit-reset", "1800000600"),
                ],
                r#"{"message":"API rate limit exceeded for user ID 1."}"#,
                CiProblemKind::RateLimited,
                "HTTP 403 · API rate limit exceeded for user ID 1.",
            ),
            (
                429,
                &[("Retry-After", "30")],
                "",
                CiProblemKind::RateLimited,
                "HTTP 429 · Too many requests",
            ),
            (
                403,
                &[("retry-after", "60")],
                r#"{"message":"You have exceeded a secondary rate limit."}"#,
                CiProblemKind::RateLimited,
                "HTTP 403 · You have exceeded a secondary rate limit.",
            ),
            (
                502,
                &[],
                "<html>Bad gateway</html>",
                CiProblemKind::Unreachable,
                "HTTP 502 · api.github.com",
            ),
            (
                503,
                &[],
                "",
                CiProblemKind::Unreachable,
                "HTTP 503 · api.github.com",
            ),
            (
                401,
                &[],
                r#"{"error":"invalid_token","error_description":"Token was revoked. You have to re-authorize from the user."}"#,
                CiProblemKind::Unauthorized,
                "HTTP 401 · Token was revoked. You have to re-authorize from the user.",
            ),
        ];
        for (status, headers, body, kind, detail) in cases {
            let p = problem(status, headers, body);
            assert_eq!(
                (p.kind, p.detail.as_str()),
                (kind, detail),
                "{status} {body}"
            );
        }
    }

    #[test]
    fn rate_limits_say_when_to_retry() {
        let reset = problem(
            403,
            &[
                ("x-ratelimit-remaining", "0"),
                ("x-ratelimit-reset", "1800000600"),
            ],
            "{}",
        );
        assert_eq!(
            reset.retry_at,
            Some(Timestamp::from_unix_nanos(1_800_000_600_000_000_000))
        );
        let after = problem(429, &[("Retry-After", "30")], "");
        assert_eq!(
            after.retry_at,
            Some(Timestamp::from_unix_nanos(
                NOW.as_unix_nanos() + 30_000_000_000
            ))
        );
        let gitlab = problem(
            429,
            &[("RateLimit-Reset", "1800000060")],
            r#"{"message":"Retry later"}"#,
        );
        assert_eq!(
            gitlab.retry_at,
            Some(Timestamp::from_unix_nanos(1_800_000_060_000_000_000))
        );
    }

    #[test]
    fn forbidden_names_the_missing_permission() {
        let fine_grained = problem(
            403,
            &[("X-Accepted-GitHub-Permissions", "actions=read")],
            r#"{"message":"Resource not accessible by personal access token"}"#,
        );
        assert_eq!(fine_grained.missing_scope, "actions:read");
        let classic = problem(
            403,
            &[
                ("X-Accepted-OAuth-Scopes", "repo"),
                ("X-OAuth-Scopes", "read:org, gist"),
            ],
            r#"{"message":"Must have admin rights"}"#,
        );
        assert_eq!(classic.missing_scope, "repo");
        let has_it = problem(
            403,
            &[
                ("X-Accepted-OAuth-Scopes", "repo"),
                ("X-OAuth-Scopes", "repo"),
            ],
            "{}",
        );
        assert_eq!(has_it.missing_scope, "");
        let gitlab = problem(
            403,
            &[],
            r#"{"error":"insufficient_scope","error_description":"The request requires higher privileges than provided by the access token.","scope":"read_api"}"#,
        );
        assert_eq!(
            (gitlab.kind, gitlab.missing_scope.as_str()),
            (CiProblemKind::Forbidden, "read_api")
        );
        let gitlab_header = problem(
            403,
            &[(
                "WWW-Authenticate",
                r#"Bearer realm="", error="insufficient_scope", scope="api read_api""#,
            )],
            "{}",
        );
        assert_eq!(gitlab_header.missing_scope, "api or read_api");
        let bitbucket = problem(
            403,
            &[],
            r#"{"type":"error","error":{"message":"Your credentials lack one or more required privilege scopes.","detail":{"granted":["repository"],"required":["pipeline"]}}}"#,
        );
        assert_eq!(bitbucket.missing_scope, "pipeline");
        assert_eq!(
            bitbucket.detail,
            "HTTP 403 · Your credentials lack one or more required privilege scopes."
        );
    }

    #[test]
    fn details_stay_short() {
        let long = format!(r#"{{"message":"{}"}}"#, "x".repeat(400));
        assert!(problem(404, &[], &long).detail.chars().count() <= CiProblem::MAX_DETAIL);
    }

    #[test]
    fn encodes_branches_and_project_paths() {
        assert_eq!(enc("feat/PRC-412 x"), "feat%2FPRC-412%20x");
        assert_eq!(enc("{a1-b2}"), "%7Ba1-b2%7D");
    }
}
