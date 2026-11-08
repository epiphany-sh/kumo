//! Web pages read once, as text.

use std::time::Duration;

use kumo_domain::agent_defs::{PageReader, html_text};

/// Pages longer than this are cut.
const MAX_BYTES: u64 = 2 * 1024 * 1024;

/// [`PageReader`] over HTTP.
#[derive(Debug, Clone)]
pub struct HttpPageReader {
    agent: ureq::Agent,
}

impl Default for HttpPageReader {
    fn default() -> Self {
        let agent = ureq::Agent::config_builder()
            .timeout_global(Some(Duration::from_secs(20)))
            .http_status_as_error(false)
            .build()
            .into();
        Self { agent }
    }
}

impl PageReader for HttpPageReader {
    fn read(&self, url: &str) -> Result<String, String> {
        if !(url.starts_with("https://") || url.starts_with("http://")) {
            return Err("not a web link".to_owned());
        }
        let mut response = self
            .agent
            .get(url)
            .header("User-Agent", "Kumo")
            .call()
            .map_err(|e| e.to_string())?;
        let status = response.status();
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
        Ok(if html { html_text(&body) } else { body })
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
}
