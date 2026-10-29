//! Confluence Cloud, signed in with a Jira source's Atlassian account
//! (same site, email and API token). Lists through CQL search, reads pages
//! as ADF through API v2 and turns them into Markdown.

use base64::Engine;
use base64::engine::general_purpose::STANDARD as BASE64;
use kumo_domain::docs::{Doc, DocId, DocKind, DocSummary, DocsConnector};
use kumo_domain::tasks::{SourceOptions, TaskError, TaskSource};
use serde_json::Value;

use crate::ci::http::enc;
use crate::tasks::adf;
use crate::tasks::dates::parse_timestamp;
use crate::tasks::http::Http;

/// Pages the user wrote, edited or watches.
const MINE_CQL: &str = "type = page AND (contributor = currentUser() OR watcher = currentUser()) ORDER BY lastmodified DESC";
/// When they have none: the site's latest.
const LATEST_CQL: &str = "type = page ORDER BY lastmodified DESC";

#[derive(Debug)]
pub struct ConfluenceDocs {
    http: Http,
}

impl Default for ConfluenceDocs {
    fn default() -> Self {
        Self {
            http: Http::named("Confluence"),
        }
    }
}

struct Account<'a> {
    site: &'a str,
    auth: String,
}

impl ConfluenceDocs {
    fn account<'a>(source: &'a TaskSource, token: Option<&str>) -> Result<Account<'a>, TaskError> {
        let SourceOptions::Jira { site, email, .. } = &source.options else {
            return Err(TaskError::Invalid(
                "Confluence reads through a Jira source".into(),
            ));
        };
        let token = token.ok_or_else(|| {
            TaskError::Auth("enter the Atlassian API token of your Jira source".into())
        })?;
        Ok(Account {
            site,
            auth: format!("Basic {}", BASE64.encode(format!("{email}:{token}"))),
        })
    }

    fn get(&self, account: &Account<'_>, path: &str) -> Result<Value, TaskError> {
        self.http
            .get(&format!("{}{path}", account.site), &account.auth)
    }

    fn cql(
        &self,
        source: &TaskSource,
        account: &Account<'_>,
        cql: &str,
        limit: usize,
    ) -> Result<Vec<DocSummary>, TaskError> {
        let found = self.get(
            account,
            &format!(
                "/wiki/rest/api/search?cql={}&limit={}&expand=content.version",
                enc(cql),
                limit.clamp(1, 100)
            ),
        )?;
        let base = found
            .pointer("/_links/base")
            .and_then(Value::as_str)
            .map_or_else(|| format!("{}/wiki", account.site), str::to_owned);
        Ok(found["results"]
            .as_array()
            .into_iter()
            .flatten()
            .filter_map(|hit| summary_of_hit(source, &base, hit))
            .take(limit)
            .collect())
    }
}

impl DocsConnector for ConfluenceDocs {
    fn kind(&self) -> DocKind {
        DocKind::Confluence
    }

    fn recent(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        limit: usize,
    ) -> Result<Vec<DocSummary>, TaskError> {
        let account = Self::account(source, secret)?;
        let mine = self.cql(source, &account, MINE_CQL, limit)?;
        if !mine.is_empty() {
            return Ok(mine);
        }
        self.cql(source, &account, LATEST_CQL, limit)
    }

    fn search(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        query: &str,
        limit: usize,
    ) -> Result<Vec<DocSummary>, TaskError> {
        let account = Self::account(source, secret)?;
        let quoted = query.trim().replace('\\', "\\\\").replace('"', "\\\"");
        let cql = format!("type = page AND (title ~ \"{quoted}\" OR text ~ \"{quoted}\")");
        self.cql(source, &account, &cql, limit)
    }

    fn read(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        external: &str,
    ) -> Result<Doc, TaskError> {
        // Ids come from clients: only Confluence's numeric ones reach a URL.
        if external.is_empty() || !external.bytes().all(|b| b.is_ascii_digit()) {
            return Err(TaskError::Invalid(format!(
                "unknown Confluence page: {external}"
            )));
        }
        let account = Self::account(source, secret)?;
        let page = self.get(
            &account,
            &format!("/wiki/api/v2/pages/{external}?body-format=atlas_doc_format"),
        )?;
        let space = page["spaceId"]
            .as_str()
            .map(str::to_owned)
            .or_else(|| page["spaceId"].as_u64().map(|id| id.to_string()))
            .and_then(|id| {
                self.get(&account, &format!("/wiki/api/v2/spaces/{}", enc(&id)))
                    .ok()
            })
            .and_then(|s| s["name"].as_str().map(str::to_owned))
            .unwrap_or_default();
        let author = page
            .pointer("/version/authorId")
            .and_then(Value::as_str)
            .and_then(|id| {
                self.get(
                    &account,
                    &format!("/wiki/rest/api/user?accountId={}", enc(id)),
                )
                .ok()
            })
            .and_then(|u| u["displayName"].as_str().map(str::to_owned));
        let base = page
            .pointer("/_links/base")
            .and_then(Value::as_str)
            .map_or_else(|| format!("{}/wiki", account.site), str::to_owned);
        let webui = page
            .pointer("/_links/webui")
            .and_then(Value::as_str)
            .unwrap_or_default();
        // The body is ADF as a JSON string.
        let markdown = page
            .pointer("/body/atlas_doc_format/value")
            .and_then(Value::as_str)
            .and_then(|raw| serde_json::from_str::<Value>(raw).ok())
            .map(|adf| adf::to_markdown(&adf))
            .unwrap_or_default();
        Ok(Doc {
            summary: DocSummary {
                id: DocId::new(&source.id, external),
                title: page["title"].as_str().unwrap_or("Untitled").to_owned(),
                place: space.clone(),
                updated_at: page
                    .pointer("/version/createdAt")
                    .and_then(Value::as_str)
                    .and_then(unix_ms),
                author,
                url: if webui.is_empty() {
                    String::new()
                } else {
                    format!("{base}{webui}")
                },
                excerpt: String::new(),
            },
            markdown,
            path: if space.is_empty() {
                vec![]
            } else {
                vec![space]
            },
            file: None,
        })
    }
}

fn unix_ms(raw: &str) -> Option<i64> {
    parse_timestamp(raw).and_then(|t| i64::try_from(t.as_unix_nanos() / 1_000_000).ok())
}

/// One CQL search result; None for anything that isn't a page.
fn summary_of_hit(source: &TaskSource, base: &str, hit: &Value) -> Option<DocSummary> {
    let content = &hit["content"];
    if content["type"].as_str() != Some("page") {
        return None;
    }
    let id = content["id"].as_str()?;
    let webui = content
        .pointer("/_links/webui")
        .and_then(Value::as_str)
        .or(hit["url"].as_str())
        .unwrap_or_default();
    Some(DocSummary {
        id: DocId::new(&source.id, id),
        title: content["title"].as_str().unwrap_or("Untitled").to_owned(),
        place: hit
            .pointer("/resultGlobalContainer/title")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_owned(),
        updated_at: content
            .pointer("/version/when")
            .and_then(Value::as_str)
            .or(hit["lastModified"].as_str())
            .and_then(unix_ms),
        author: content
            .pointer("/version/by/displayName")
            .and_then(Value::as_str)
            .map(str::to_owned),
        url: if webui.is_empty() {
            String::new()
        } else {
            format!("{base}{webui}")
        },
        excerpt: plain_excerpt(hit["excerpt"].as_str().unwrap_or_default()),
    })
}

/// Search excerpts mark matches with `@@@hl@@@…@@@endhl@@@` and keep
/// some HTML entities.
fn plain_excerpt(raw: &str) -> String {
    let text = raw
        .replace("@@@hl@@@", "")
        .replace("@@@endhl@@@", "")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&amp;", "&");
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

#[cfg(test)]
mod tests {
    use kumo_domain::tasks::SourceId;

    use super::*;
    use crate::test_server::TestServer;

    fn source(site: &str) -> TaskSource {
        TaskSource {
            id: SourceId::parse("jira1").unwrap(),
            name: "Fravega".into(),
            options: SourceOptions::Jira {
                site: site.into(),
                email: "ana@acme.com".into(),
                jql: String::new(),
            },
            enabled: true,
        }
    }

    const HIT: &str = r#"{"content":{"id":"98311","type":"page","title":"Discount rules v3",
        "_links":{"webui":"/spaces/PRC/pages/98311/Discount+rules+v3"},
        "version":{"when":"2026-10-25T12:00:00.000Z","by":{"displayName":"Lucía"}}},
        "excerpt":"Only the @@@hl@@@highest@@@endhl@@@ rule &amp; nothing else",
        "resultGlobalContainer":{"title":"Pricing"},"lastModified":"2026-10-25T12:00:00.000Z"}"#;

    fn route(r: &crate::test_server::Request) -> (u16, String) {
        let path = r.path.as_str();
        if path.starts_with("/wiki/rest/api/search?cql=") {
            let cql = path.split("cql=").nth(1).unwrap_or_default();
            if cql.starts_with(&enc("type = page AND (contributor")) {
                return (
                    200,
                    r#"{"results":[],"_links":{"base":"https://acme.atlassian.net/wiki"}}"#.into(),
                );
            }
            let comment = r#"{"content":{"id":"7","type":"comment","title":"x"}}"#;
            return (
                200,
                format!(
                    r#"{{"results":[{HIT},{comment}],"_links":{{"base":"https://acme.atlassian.net/wiki"}}}}"#
                ),
            );
        }
        match path {
            "/wiki/api/v2/pages/98311?body-format=atlas_doc_format" => {
                let adf = r#"{"type":"doc","version":1,"content":[{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Scope"}]},{"type":"paragraph","content":[{"type":"text","text":"List prices only."}]}]}"#;
                let page = serde_json::json!({
                    "id": "98311", "title": "Discount rules v3", "spaceId": "65538",
                    "version": {"createdAt": "2026-10-25T12:00:00.000Z", "authorId": "acc-1"},
                    "body": {"atlas_doc_format": {"value": adf, "representation": "atlas_doc_format"}},
                    "_links": {"webui": "/spaces/PRC/pages/98311", "base": "https://acme.atlassian.net/wiki"}
                });
                (200, page.to_string())
            }
            "/wiki/api/v2/spaces/65538" => (200, r#"{"id":"65538","name":"Pricing"}"#.into()),
            "/wiki/rest/api/user?accountId=acc-1" => (200, r#"{"displayName":"Lucía"}"#.into()),
            _ => (404, r#"{"message":"not found"}"#.into()),
        }
    }

    #[test]
    fn recent_falls_back_to_the_latest_pages_and_skips_non_pages() {
        let server = TestServer::start(route);
        let docs = ConfluenceDocs::default()
            .recent(&source(&server.url), Some("tok"), 20)
            .unwrap();
        assert_eq!(docs.len(), 1);
        let d = &docs[0];
        assert_eq!(d.id.as_str(), "jira1/98311");
        assert_eq!(
            (d.title.as_str(), d.place.as_str()),
            ("Discount rules v3", "Pricing")
        );
        assert_eq!(d.author.as_deref(), Some("Lucía"));
        assert_eq!(
            d.url,
            "https://acme.atlassian.net/wiki/spaces/PRC/pages/98311/Discount+rules+v3"
        );
        assert!(d.updated_at.is_some());
        let first = &server.requests()[0];
        assert_eq!(
            first.header("Authorization"),
            Some(format!("Basic {}", BASE64.encode("ana@acme.com:tok")).as_str())
        );
    }

    #[test]
    fn search_quotes_the_query_and_cleans_excerpts() {
        let server = TestServer::start(route);
        let docs = ConfluenceDocs::default()
            .search(&source(&server.url), Some("tok"), r#"say "hi""#, 20)
            .unwrap();
        assert_eq!(docs[0].excerpt, "Only the highest rule & nothing else");
        let sent = &server.requests()[0].path;
        assert!(sent.contains(&enc(r#"title ~ "say \"hi\"""#)), "{sent}");
    }

    #[test]
    fn reads_a_page_as_markdown() {
        let server = TestServer::start(route);
        let doc = ConfluenceDocs::default()
            .read(&source(&server.url), Some("tok"), "98311")
            .unwrap();
        assert_eq!(doc.markdown, "## Scope\n\nList prices only.");
        assert_eq!(doc.path, ["Pricing"]);
        assert_eq!(doc.summary.author.as_deref(), Some("Lucía"));
        assert_eq!(
            doc.summary.url,
            "https://acme.atlassian.net/wiki/spaces/PRC/pages/98311"
        );
        assert!(matches!(
            ConfluenceDocs::default().read(&source(&server.url), Some("t"), "../x"),
            Err(TaskError::Invalid(_))
        ));
        assert!(matches!(
            ConfluenceDocs::default().recent(&source(&server.url), None, 5),
            Err(TaskError::Auth(_))
        ));
    }
}
