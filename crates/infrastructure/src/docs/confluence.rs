//! Confluence Cloud, signed in with a Jira source's Atlassian account
//! (same site, email and API token). Lists through CQL search, reads pages
//! as ADF through API v2 and turns them into Markdown, browses spaces and
//! page trees through API v2.

use base64::Engine;
use base64::engine::general_purpose::STANDARD as BASE64;
use kumo_domain::docs::{Doc, DocId, DocKind, DocNode, DocSummary, DocsConnector};
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

/// Most entries API v2 returns per request.
const PAGE_MAX: usize = 250;
/// Requests one level may take, following `_links.next`.
const MAX_REQUESTS: usize = 20;

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

    /// The items of a v2 list starting at `path` that `keep` keeps,
    /// following `_links.next` until there are more than `limit`; whether
    /// there were more; the site's base URL, as the answers give it.
    fn collect(
        &self,
        account: &Account<'_>,
        path: String,
        limit: usize,
        keep: impl Fn(&Value) -> bool,
    ) -> Result<(Vec<Value>, bool, String), TaskError> {
        let mut base = format!("{}/wiki", account.site);
        let mut items = Vec::new();
        let mut next = Some(path);
        for _ in 0..MAX_REQUESTS {
            let Some(path) = next.take() else { break };
            let mut answer = self.get(account, &path)?;
            if let Some(b) = answer.pointer("/_links/base").and_then(Value::as_str) {
                b.clone_into(&mut base);
            }
            next = answer
                .pointer("/_links/next")
                .and_then(Value::as_str)
                .and_then(relative);
            if let Some(Value::Array(results)) = answer.get_mut("results").map(Value::take) {
                items.extend(results.into_iter().filter(|item| keep(item)));
            }
            if items.len() > limit {
                break;
            }
        }
        let truncated = items.len() > limit || next.is_some();
        items.truncate(limit);
        Ok((items, truncated, base))
    }

    fn space(&self, account: &Account<'_>, id: &str) -> Result<Space, TaskError> {
        let space = self.get(account, &format!("/wiki/api/v2/spaces/{}", enc(id)))?;
        Ok(Space {
            name: space["name"].as_str().unwrap_or_default().to_owned(),
            key: space["key"].as_str().unwrap_or_default().to_owned(),
            homepage: id_of(&space["homepageId"]),
        })
    }

    /// The pages right under page `id`; other content types (folders,
    /// whiteboards, databases, embeds) are skipped. `space` when known,
    /// else the children's own.
    fn children_of(
        &self,
        source: &TaskSource,
        account: &Account<'_>,
        id: &str,
        space: Option<&Space>,
        limit: usize,
    ) -> Result<(Vec<DocNode>, bool), TaskError> {
        let (pages, truncated, base) = self.collect(
            account,
            format!(
                "/wiki/api/v2/pages/{id}/direct-children?sort=title&limit={}",
                (limit + 1).clamp(1, PAGE_MAX)
            ),
            limit,
            |item| item["type"].as_str() == Some("page"),
        )?;
        // Children don't carry their space's name or key: one request for
        // the level, not one per page.
        let fetched = match (space, pages.first().and_then(|p| id_of(&p["spaceId"]))) {
            (None, Some(space_id)) => self.space(account, &space_id).ok(),
            _ => None,
        };
        let space = space.or(fetched.as_ref());
        let nodes = pages
            .iter()
            .filter_map(|page| page_node(source, &base, space, page))
            .collect();
        Ok((nodes, truncated))
    }
}

/// What a page needs from its space.
struct Space {
    name: String,
    key: String,
    homepage: Option<String>,
}

/// What `Browse` may ask for, from a node key.
enum Level<'a> {
    Spaces,
    Space(&'a str),
    Page(&'a str),
}

impl<'a> Level<'a> {
    /// `space:<id>` or `page:<id>`; ids are numeric, as they reach a URL.
    fn parse(parent: Option<&'a str>) -> Result<Self, TaskError> {
        let Some(key) = parent else {
            return Ok(Self::Spaces);
        };
        let numeric = |id: &str| !id.is_empty() && id.bytes().all(|b| b.is_ascii_digit());
        match key.split_once(':') {
            Some(("space", id)) if numeric(id) => Ok(Self::Space(id)),
            Some(("page", id)) if numeric(id) => Ok(Self::Page(id)),
            _ => Err(TaskError::Invalid(format!(
                "unknown Confluence level: {key}"
            ))),
        }
    }
}

/// `_links.next`, relative to the site: with or without `/wiki`.
fn relative(next: &str) -> Option<String> {
    if !next.starts_with('/') || next.starts_with("//") {
        return None;
    }
    Some(if next.starts_with("/wiki/") {
        next.to_owned()
    } else {
        format!("/wiki{next}")
    })
}

/// v2 ids are strings; tolerate numbers.
fn id_of(raw: &Value) -> Option<String> {
    raw.as_str()
        .map(str::to_owned)
        .or_else(|| raw.as_u64().map(|id| id.to_string()))
        .filter(|id| !id.is_empty())
}

/// A page of a v2 list (a space's pages or a page's children). Its
/// `doc` is built like [`summary_of_hit`]'s, without the body.
fn page_node(
    source: &TaskSource,
    base: &str,
    space: Option<&Space>,
    page: &Value,
) -> Option<DocNode> {
    let id = id_of(&page["id"])?;
    let title = page["title"].as_str().unwrap_or("Untitled").to_owned();
    // Only a space's page list links to the page; children get the
    // space's page URL.
    let webui = page
        .pointer("/_links/webui")
        .and_then(Value::as_str)
        .map(str::to_owned)
        .or_else(|| {
            space
                .filter(|s| !s.key.is_empty())
                .map(|s| format!("/spaces/{}/pages/{id}", enc(&s.key)))
        })
        .unwrap_or_else(|| format!("/pages/viewpage.action?pageId={id}"));
    Some(DocNode {
        key: format!("page:{id}"),
        title: title.clone(),
        doc: Some(DocSummary {
            id: DocId::new(&source.id, &id),
            title,
            place: space.map(|s| s.name.clone()).unwrap_or_default(),
            updated_at: page
                .pointer("/version/createdAt")
                .and_then(Value::as_str)
                .and_then(unix_ms),
            // v2 lists only give the author's account id.
            author: None,
            url: format!("{base}{webui}"),
            excerpt: String::new(),
        }),
        // v2 lists don't say whether a page has children, and asking per
        // page would cost a request each: every page may be opened, and
        // an empty level reads "Nothing under this page".
        children: 1,
        note: if page["status"].as_str() == Some("archived") {
            "archived".into()
        } else {
            String::new()
        },
    })
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

    /// Keys: `space:<id>` for a space, `page:<id>` for a page. Pages only:
    /// folders, whiteboards, databases and embeds are left out.
    fn browse(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        parent: Option<&str>,
        limit: usize,
    ) -> Result<(Vec<DocNode>, bool), TaskError> {
        let level = Level::parse(parent)?;
        let account = Self::account(source, secret)?;
        let per_request = (limit + 1).clamp(1, PAGE_MAX);
        let (mut nodes, truncated) = match level {
            Level::Spaces => {
                let (spaces, truncated, _) = self.collect(
                    &account,
                    format!("/wiki/api/v2/spaces?status=current&sort=name&limit={per_request}"),
                    limit,
                    |space| space["type"].as_str() != Some("personal"),
                )?;
                let nodes = spaces
                    .iter()
                    .filter_map(|space| {
                        Some(DocNode {
                            key: format!("space:{}", id_of(&space["id"])?),
                            title: space["name"].as_str().unwrap_or_default().to_owned(),
                            doc: None,
                            // Never counted: one more request per space.
                            children: 1,
                            note: String::new(),
                        })
                    })
                    .collect();
                (nodes, truncated)
            }
            Level::Space(id) => {
                let space = self.space(&account, id)?;
                let (pages, mut truncated, base) = self.collect(
                    &account,
                    format!(
                        "/wiki/api/v2/spaces/{id}/pages?depth=root&sort=title&limit={per_request}"
                    ),
                    limit,
                    |_| true,
                )?;
                let mut nodes: Vec<DocNode> = Vec::new();
                for page in &pages {
                    // The home page holds most of a space: its children
                    // stand in for it, so it takes one click less.
                    if let Some(home) =
                        id_of(&page["id"]).filter(|p| space.homepage.as_ref() == Some(p))
                    {
                        let (children, more) =
                            self.children_of(source, &account, &home, Some(&space), limit)?;
                        truncated |= more;
                        nodes.extend(children);
                    } else {
                        nodes.extend(page_node(source, &base, Some(&space), page));
                    }
                }
                (nodes, truncated)
            }
            Level::Page(id) => self.children_of(source, &account, id, None, limit)?,
        };
        // Confluence's own tree order isn't available across content types
        // (CONFCLOUD-79631): by title.
        DocNode::sort(&mut nodes);
        let truncated = truncated || nodes.len() > limit;
        nodes.truncate(limit);
        Ok((nodes, truncated))
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
        if let Some(answer) = browse_route(path) {
            return answer;
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
            "/wiki/api/v2/spaces/65538" => (
                200,
                r#"{"id":"65538","key":"PRC","name":"Pricing","homepageId":"100"}"#.into(),
            ),
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

    /// Spaces (two answers, one personal space), Pricing's root pages (its
    /// home page and an archived one), and children mixing content types.
    fn browse_route(path: &str) -> Option<(u16, String)> {
        let (route, query) = path.split_once('?').unwrap_or((path, ""));
        let base = r#""base":"https://acme.atlassian.net/wiki""#;
        let body = match route {
            "/wiki/api/v2/spaces" if query.contains("cursor=2") => format!(
                r#"{{"results":[{{"id":"7","key":"ENG","name":"engineering","type":"collaboration","status":"current"}}],"_links":{{{base}}}}}"#
            ),
            "/wiki/api/v2/spaces" => format!(
                r#"{{"results":[{{"id":"65538","key":"PRC","name":"Pricing","type":"global","status":"current"}},
                {{"id":"9","key":"~ana","name":"Ana","type":"personal","status":"current"}}],
                "_links":{{"next":"/wiki/api/v2/spaces?cursor=2&limit=201",{base}}}}}"#
            ),
            "/wiki/api/v2/spaces/65538/pages" => format!(
                r#"{{"results":[{{"id":"300","title":"Zz old","status":"archived","spaceId":"65538",
                "_links":{{"webui":"/spaces/PRC/pages/300/Zz+old"}}}},
                {{"id":"100","title":"Pricing Home","status":"current","spaceId":"65538",
                "version":{{"createdAt":"2026-10-25T12:00:00.000Z"}},"_links":{{"webui":"/spaces/PRC/overview"}}}}],
                "_links":{{{base}}}}}"#
            ),
            "/wiki/api/v2/pages/100/direct-children" => format!(
                r#"{{"results":[{{"id":"98311","title":"Discount rules v3","type":"page","status":"current","spaceId":"65538"}},
                {{"id":"5","title":"Assets","type":"folder","status":"current","spaceId":"65538"}},
                {{"id":"6","title":"Board","type":"whiteboard","status":"current","spaceId":"65538"}},
                {{"id":"200","title":"appendix","type":"page","status":"current","spaceId":"65538"}}],
                "_links":{{{base}}}}}"#
            ),
            "/wiki/api/v2/pages/98311/direct-children" => format!(
                r#"{{"results":[{{"id":"401","title":"Examples","type":"page","status":"current","spaceId":"65538"}},
                {{"id":"402","title":"Diagram","type":"whiteboard","status":"current","spaceId":"65538"}}],
                "_links":{{"next":"/wiki/api/v2/pages/98311/direct-children?cursor=2",{base}}}}}"#
            ),
            _ => return None,
        };
        Some((200, body))
    }

    fn level(nodes: &[DocNode]) -> Vec<(&str, &str, Option<&str>, &str)> {
        nodes
            .iter()
            .map(|n| {
                (
                    n.key.as_str(),
                    n.title.as_str(),
                    n.doc.as_ref().map(|d| d.id.as_str()),
                    n.note.as_str(),
                )
            })
            .collect()
    }

    #[test]
    fn browse_lists_the_spaces_but_personal_ones() {
        let server = TestServer::start(route);
        let (spaces, truncated) = ConfluenceDocs::default()
            .browse(&source(&server.url), Some("tok"), None, 200)
            .unwrap();
        assert_eq!(
            level(&spaces),
            [
                ("space:7", "engineering", None, ""),
                ("space:65538", "Pricing", None, "")
            ],
            "every answer, by title"
        );
        assert!(spaces.iter().all(|s| s.children == 1));
        assert!(!truncated);
        let sent: Vec<_> = server.requests().iter().map(|r| r.path.clone()).collect();
        assert_eq!(
            sent,
            [
                "/wiki/api/v2/spaces?status=current&sort=name&limit=201",
                "/wiki/api/v2/spaces?cursor=2&limit=201"
            ]
        );
    }

    #[test]
    fn browse_opens_a_space_at_its_home_pages_children() {
        let server = TestServer::start(route);
        let (pages, truncated) = ConfluenceDocs::default()
            .browse(&source(&server.url), Some("tok"), Some("space:65538"), 200)
            .unwrap();
        assert_eq!(
            level(&pages),
            [
                ("page:200", "appendix", Some("jira1/200"), ""),
                ("page:98311", "Discount rules v3", Some("jira1/98311"), ""),
                ("page:300", "Zz old", Some("jira1/300"), "archived")
            ],
            "no folders or whiteboards, the home page stands aside"
        );
        assert!(!truncated);
        let doc = pages[1].doc.as_ref().unwrap();
        assert_eq!(doc.place, "Pricing");
        assert_eq!(
            doc.url,
            "https://acme.atlassian.net/wiki/spaces/PRC/pages/98311"
        );
        assert_eq!(pages[1].children, 1);
        assert_eq!(
            pages[2].doc.as_ref().unwrap().url,
            "https://acme.atlassian.net/wiki/spaces/PRC/pages/300/Zz+old"
        );
        // The node's doc reads like any page.
        let read = ConfluenceDocs::default()
            .read(&source(&server.url), Some("tok"), doc.id.external())
            .unwrap();
        assert_eq!(read.summary.title, "Discount rules v3");
    }

    #[test]
    fn browse_lists_a_pages_children_and_says_when_there_are_more() {
        let server = TestServer::start(route);
        let docs = ConfluenceDocs::default();
        let src = source(&server.url);
        let (children, truncated) = docs
            .browse(&src, Some("tok"), Some("page:98311"), 1)
            .unwrap();
        assert_eq!(
            level(&children),
            [("page:401", "Examples", Some("jira1/401"), "")]
        );
        assert!(truncated, "a next page is left");
        assert_eq!(children[0].doc.as_ref().unwrap().place, "Pricing");
        let (spaces, truncated) = docs.browse(&src, Some("tok"), None, 1).unwrap();
        assert_eq!(level(&spaces), [("space:65538", "Pricing", None, "")]);
        assert!(truncated);
        for bad in ["page:../x", "space:", "folder:1", "98311"] {
            assert!(
                matches!(
                    docs.browse(&src, Some("tok"), Some(bad), 10),
                    Err(TaskError::Invalid(_))
                ),
                "{bad}"
            );
        }
        assert!(matches!(
            docs.browse(&src, None, None, 10),
            Err(TaskError::Auth(_))
        ));
    }
}
