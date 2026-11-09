//! Web pages read once, as text.

use std::net::{IpAddr, ToSocketAddrs};
use std::time::Duration;

use kumo_domain::agent_defs::{PageReader, html_text};
use ureq::http::Uri;

/// Pages longer than this are cut.
const MAX_BYTES: u64 = 2 * 1024 * 1024;
const MAX_REDIRECTS: usize = 5;

/// [`PageReader`] over HTTP. An address on this machine or the local network
/// can be read when it's the one given, but a page elsewhere can't redirect
/// there: what comes back goes to an agent.
#[derive(Debug, Clone)]
pub struct HttpPageReader {
    agent: ureq::Agent,
    is_internal: fn(&str) -> bool,
}

impl Default for HttpPageReader {
    fn default() -> Self {
        let agent = ureq::Agent::config_builder()
            .timeout_global(Some(Duration::from_secs(20)))
            .http_status_as_error(false)
            // Followed below, each one checked first.
            .max_redirects(0)
            .build()
            .into();
        Self { agent, is_internal }
    }
}

impl PageReader for HttpPageReader {
    fn read(&self, url: &str) -> Result<String, String> {
        if !is_web_link(url) {
            return Err("not a web link".to_owned());
        }
        let mut current = url.to_owned();
        let mut internal = (self.is_internal)(&current);
        for _ in 0..=MAX_REDIRECTS {
            let mut response = self
                .agent
                .get(&current)
                .header("User-Agent", "Kumo")
                .call()
                .map_err(|e| e.to_string())?;
            let status = response.status();
            let location = response
                .headers()
                .get("location")
                .and_then(|v| v.to_str().ok());
            if matches!(status.as_u16(), 301 | 302 | 303 | 307 | 308)
                && let Some(location) = location
            {
                let next = redirect_target(&current, location)?;
                let next_internal = (self.is_internal)(&next);
                if next_internal && !internal {
                    return Err("the page redirects to an internal address".to_owned());
                }
                internal = next_internal;
                current = next;
                continue;
            }
            if !status.is_success() {
                return Err(format!("HTTP {}", status.as_u16()));
            }
            let html = response
                .headers()
                .get("content-type")
                .and_then(|v| v.to_str().ok())
                .is_some_and(|t| t.contains("html"));
            let body = response
                .body_mut()
                .with_config()
                .limit(MAX_BYTES)
                .read_to_string()
                .map_err(|e| e.to_string())?;
            let head = body
                .trim_start()
                .get(..15)
                .unwrap_or_default()
                .to_ascii_lowercase();
            let html = html || head.starts_with("<!doctype html") || head.starts_with("<html");
            return Ok(if html { html_text(&body) } else { body });
        }
        Err("too many redirects".to_owned())
    }
}

fn is_web_link(url: &str) -> bool {
    url.starts_with("https://") || url.starts_with("http://")
}

/// Where a `Location` header leads from `base`.
fn redirect_target(base: &str, location: &str) -> Result<String, String> {
    if is_web_link(location) {
        return Ok(location.to_owned());
    }
    let uri: Uri = base.parse().map_err(|_| "not a web link".to_owned())?;
    let (Some(scheme), Some(authority)) = (uri.scheme_str(), uri.authority()) else {
        return Err("not a web link".to_owned());
    };
    if let Some(rest) = location.strip_prefix("//") {
        return Ok(format!("{scheme}://{rest}"));
    }
    if location.starts_with('/') {
        return Ok(format!("{scheme}://{authority}{location}"));
    }
    // Another scheme (`file:`, …) isn't followed.
    let first = location.split(['/', '?', '#']).next().unwrap_or_default();
    if first.contains(':') {
        return Err("the page redirects to something that isn't a web link".to_owned());
    }
    let path = uri.path();
    let folder = &path[..=path.rfind('/').unwrap_or(0)];
    Ok(format!("{scheme}://{authority}{folder}{location}"))
}

/// Whether `url` leads to this machine or a private network. What can't be
/// read counts as internal; a name that doesn't resolve can't be reached.
fn is_internal(url: &str) -> bool {
    let Ok(uri) = url.parse::<Uri>() else {
        return true;
    };
    let Some(host) = uri.host() else {
        return true;
    };
    let host = host.trim_matches(['[', ']']);
    let name = host.to_ascii_lowercase();
    if name == "localhost" || name.ends_with(".localhost") || name.ends_with(".local") {
        return true;
    }
    let port = uri
        .port_u16()
        .unwrap_or(if uri.scheme_str() == Some("https") {
            443
        } else {
            80
        });
    (host, port)
        .to_socket_addrs()
        .is_ok_and(|mut addresses| addresses.any(|a| is_internal_ip(a.ip())))
}

fn is_internal_ip(ip: IpAddr) -> bool {
    match ip.to_canonical() {
        IpAddr::V4(ip) => {
            let [a, b, ..] = ip.octets();
            ip.is_loopback()
                || ip.is_private()
                || ip.is_link_local()
                || ip.is_unspecified()
                || ip.is_broadcast()
                // Shared address space (RFC 6598).
                || (a == 100 && (64..128).contains(&b))
        }
        IpAddr::V6(ip) => {
            let first = ip.segments()[0];
            ip.is_loopback()
                || ip.is_unspecified()
                // Unique local and link-local.
                || (first & 0xfe00) == 0xfc00
                || (first & 0xffc0) == 0xfe80
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_server::TestServer;

    #[test]
    fn html_comes_back_as_text_and_errors_say_the_status() {
        let server = TestServer::with_headers(|request| match request.path.as_str() {
            "/a" => (
                200,
                vec![("Content-Type".into(), "text/html".into())],
                "<html><body><p>Hello</p></body></html>".into(),
            ),
            _ => (404, Vec::new(), "gone".into()),
        });
        let reader = HttpPageReader::default();
        let page = reader.read(&format!("{}/a", server.url)).unwrap();
        assert_eq!(page, "Hello");
        assert_eq!(
            reader.read(&format!("{}/b", server.url)),
            Err("HTTP 404".into())
        );
        assert!(reader.read("file:///etc/passwd").is_err());
    }

    fn redirecting_server() -> TestServer {
        TestServer::with_headers(|request| {
            let to = |path: &str| {
                (
                    302,
                    vec![("Location".into(), path.to_owned())],
                    String::new(),
                )
            };
            match request.path.as_str() {
                "/public" | "/start" => to("/internal"),
                "/loop" => to("/loop"),
                "/file" => to("file:///etc/passwd"),
                _ => (200, Vec::new(), "from inside".into()),
            }
        })
    }

    #[test]
    fn a_page_elsewhere_cannot_redirect_to_an_internal_address() {
        let server = redirecting_server();
        let reader = HttpPageReader {
            is_internal: |url| url.ends_with("/internal"),
            ..HttpPageReader::default()
        };
        assert_eq!(
            reader.read(&format!("{}/public", server.url)),
            Err("the page redirects to an internal address".into())
        );
    }

    #[test]
    fn an_internal_address_given_can_be_read_and_redirect_inside() {
        let server = redirecting_server();
        let reader = HttpPageReader::default();
        assert_eq!(
            reader.read(&format!("{}/start", server.url)).as_deref(),
            Ok("from inside")
        );
        assert_eq!(
            reader.read(&format!("{}/loop", server.url)),
            Err("too many redirects".into())
        );
        assert!(reader.read(&format!("{}/file", server.url)).is_err());
    }

    #[test]
    fn redirects_resolve_against_the_page() {
        let base = "https://a.example/docs/page?x=1";
        for (location, expected) in [
            ("https://b.example/c", "https://b.example/c"),
            ("//b.example/c", "https://b.example/c"),
            ("/c", "https://a.example/c"),
            ("c?y=a:b", "https://a.example/docs/c?y=a:b"),
        ] {
            assert_eq!(redirect_target(base, location).as_deref(), Ok(expected));
        }
        assert!(redirect_target(base, "file:///etc/passwd").is_err());
    }

    #[test]
    fn knows_internal_addresses() {
        for url in [
            "http://localhost:1/",
            "http://LOCALHOST/",
            "http://printer.local/",
            "http://127.0.0.1/",
            "http://user@127.0.0.1/",
            "http://10.1.2.3/",
            "http://172.16.0.1/",
            "http://192.168.1.1/",
            "http://169.254.169.254/latest",
            "http://100.64.0.1/",
            "http://0.0.0.0/",
            "http://[::1]/",
            "http://[::ffff:127.0.0.1]/",
            "http://[fc00::1]/",
            "http://[fe80::1]/",
            "not a url",
        ] {
            assert!(is_internal(url), "{url}");
        }
        for url in [
            "http://8.8.8.8/",
            "https://1.1.1.1/",
            "http://[2606:4700::1111]/",
        ] {
            assert!(!is_internal(url), "{url}");
        }
    }
}
