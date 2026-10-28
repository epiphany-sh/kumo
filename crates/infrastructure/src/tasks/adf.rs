//! Atlassian Document Format (Jira's rich text) to Markdown, so the UI and
//! agents read descriptions and comments the same way for every source.
//! Unknown nodes keep their text: nothing the user wrote is dropped.

use serde_json::Value;

use super::dates::date_of_unix_ms;

/// The document (or any ADF node) as Markdown.
pub(super) fn to_markdown(node: &Value) -> String {
    let markdown = block(node);
    markdown.trim_matches('\n').to_owned()
}

fn kind(node: &Value) -> &str {
    node.get("type").and_then(Value::as_str).unwrap_or_default()
}

fn children(node: &Value) -> &[Value] {
    node.get("content")
        .and_then(Value::as_array)
        .map_or(&[], Vec::as_slice)
}

fn attr<'a>(node: &'a Value, name: &str) -> Option<&'a Value> {
    node.get("attrs")?.get(name)
}

fn attr_str<'a>(node: &'a Value, name: &str) -> &'a str {
    attr(node, name).and_then(Value::as_str).unwrap_or_default()
}

// ---- Blocks ----

/// Blocks separated by a blank line.
fn blocks(nodes: &[Value]) -> String {
    join_blocks(nodes, "\n\n")
}

/// Blocks inside a list item: tight, one per line.
fn tight(nodes: &[Value]) -> String {
    join_blocks(nodes, "\n")
}

fn join_blocks(nodes: &[Value], separator: &str) -> String {
    let mut out: Vec<String> = Vec::new();
    let mut inline_run: Vec<Value> = Vec::new();
    for node in nodes {
        if is_inline(node) {
            // Stray inline nodes (a malformed doc): one paragraph.
            inline_run.push(node.clone());
            continue;
        }
        if !inline_run.is_empty() {
            out.push(paragraph(&std::mem::take(&mut inline_run)));
        }
        out.push(block(node));
    }
    if !inline_run.is_empty() {
        out.push(paragraph(&inline_run));
    }
    out.retain(|b| !b.trim().is_empty());
    out.join(separator)
}

fn is_inline(node: &Value) -> bool {
    matches!(
        kind(node),
        "text"
            | "hardBreak"
            | "mention"
            | "emoji"
            | "inlineCard"
            | "date"
            | "status"
            | "mediaInline"
            | "placeholder"
            | "inlineExtension"
    )
}

fn block(node: &Value) -> String {
    match kind(node) {
        "doc"
        | "layoutSection"
        | "layoutColumn"
        | "bodiedExtension"
        | "extensionFrame"
        | "multiBodiedExtension" => blocks(children(node)),
        "paragraph" => paragraph(children(node)),
        "heading" => {
            let level = attr(node, "level")
                .and_then(Value::as_u64)
                .unwrap_or(1)
                .clamp(1, 6);
            let text = inline(children(node));
            if text.trim().is_empty() {
                String::new()
            } else {
                format!("{} {}", "#".repeat(level as usize), text.trim())
            }
        }
        "bulletList" => list(children(node), None),
        "orderedList" => {
            let start = attr(node, "order").and_then(Value::as_u64).unwrap_or(1);
            list(children(node), Some(start))
        }
        "taskList" => task_list(children(node), "taskItem"),
        "decisionList" => task_list(children(node), "decisionItem"),
        "listItem" => tight(children(node)),
        "taskItem" | "decisionItem" => task_list(std::slice::from_ref(node), kind(node)),
        "codeBlock" => code_block(node),
        "blockquote" => quote(&blocks(children(node))),
        "panel" => panel(node),
        "table" => table(node),
        "rule" => "---".to_owned(),
        "mediaSingle" | "mediaGroup" => children(node)
            .iter()
            .map(media)
            .filter(|m| !m.is_empty())
            .collect::<Vec<_>>()
            .join("\n"),
        "media" => media(node),
        "expand" | "nestedExpand" => {
            let title = attr_str(node, "title").trim();
            let body = blocks(children(node));
            if title.is_empty() {
                body
            } else {
                format!("### {}\n\n{body}", escape(title))
            }
        }
        "blockCard" | "embedCard" => card(node),
        "extension" => String::new(),
        _ if is_inline(node) => paragraph(std::slice::from_ref(node)),
        _ => blocks(children(node)),
    }
}

fn paragraph(nodes: &[Value]) -> String {
    let mut nodes = nodes;
    while let [rest @ .., last] = nodes
        && kind(last) == "hardBreak"
    {
        nodes = rest;
    }
    let text = inline(nodes);
    guard_line_start(text.trim_matches(|c: char| c == ' ' || c == '\n'))
}

/// Text that would otherwise read as a heading, list or quote.
fn guard_line_start(text: &str) -> String {
    let starts_block = text.starts_with('#')
        || text.starts_with('>')
        || ["- ", "+ ", "* "].iter().any(|p| text.starts_with(p))
        || {
            let digits = text.len() - text.trim_start_matches(|c: char| c.is_ascii_digit()).len();
            digits > 0 && text[digits..].starts_with(". ")
        };
    if !starts_block {
        return text.to_owned();
    }
    match text.find(|c: char| !c.is_ascii_digit()) {
        Some(at) if at > 0 => format!("{}\\{}", &text[..at], &text[at..]),
        _ => format!("\\{text}"),
    }
}

fn list(items: &[Value], start: Option<u64>) -> String {
    items
        .iter()
        .enumerate()
        .map(|(n, item)| {
            let marker = match start {
                Some(start) => format!("{}. ", start + n as u64),
                None => "- ".to_owned(),
            };
            let body = if kind(item) == "listItem" {
                tight(children(item))
            } else {
                block(item)
            };
            indent_after_first(&marker, &body)
        })
        .collect::<Vec<_>>()
        .join("\n")
}

/// Task lists nest by containing other task lists next to their items.
fn task_list(items: &[Value], item_kind: &str) -> String {
    items
        .iter()
        .map(|item| match kind(item) {
            k if k == item_kind => {
                let done = attr_str(item, "state").eq_ignore_ascii_case("DONE")
                    || attr_str(item, "state").eq_ignore_ascii_case("DECIDED");
                let marker = if item_kind == "decisionItem" {
                    "- ".to_owned()
                } else if done {
                    "- [x] ".to_owned()
                } else {
                    "- [ ] ".to_owned()
                };
                indent_after_first(&marker, inline(children(item)).trim())
            }
            "taskList" | "decisionList" => indent_all("  ", &task_list(children(item), item_kind)),
            _ => indent_all("  ", &block(item)),
        })
        .filter(|l| !l.trim().is_empty())
        .collect::<Vec<_>>()
        .join("\n")
}

/// `marker` on the first line; the rest indented to line up with it.
fn indent_after_first(marker: &str, body: &str) -> String {
    let pad = " ".repeat(marker.chars().count());
    let mut lines = body.lines();
    let first = lines.next().unwrap_or_default();
    std::iter::once(format!("{marker}{first}"))
        .chain(lines.map(|l| {
            if l.is_empty() {
                String::new()
            } else {
                format!("{pad}{l}")
            }
        }))
        .collect::<Vec<_>>()
        .join("\n")
}

fn indent_all(pad: &str, body: &str) -> String {
    body.lines()
        .map(|l| {
            if l.is_empty() {
                String::new()
            } else {
                format!("{pad}{l}")
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}

fn code_block(node: &Value) -> String {
    let code: String = children(node)
        .iter()
        .filter_map(|t| t.get("text").and_then(Value::as_str))
        .collect();
    let language = attr_str(node, "language")
        .chars()
        .filter(|c| !c.is_whitespace() && *c != '`')
        .collect::<String>();
    // A fence longer than any run of backticks inside.
    let longest = code.split(|c| c != '`').map(str::len).max().unwrap_or(0);
    let fence = "`".repeat(longest.max(2) + 1);
    format!(
        "{fence}{language}\n{}\n{fence}",
        code.trim_end_matches('\n')
    )
}

fn quote(body: &str) -> String {
    body.lines()
        .map(|l| {
            if l.is_empty() {
                ">".to_owned()
            } else {
                format!("> {l}")
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}

fn panel(node: &Value) -> String {
    let label = match attr_str(node, "panelType") {
        "info" => "Info",
        "warning" => "Warning",
        "error" => "Error",
        "success" => "Success",
        "tip" => "Tip",
        _ => "Note",
    };
    let body = blocks(children(node));
    quote(&format!("**{label}:** {body}"))
}

fn table(node: &Value) -> String {
    let rows: Vec<Vec<String>> = children(node)
        .iter()
        .filter(|r| kind(r) == "tableRow")
        .map(|row| {
            children(row)
                .iter()
                .map(|cell| {
                    blocks(children(cell))
                        .replace("\\\n", "<br>")
                        .replace("\n\n", "<br>")
                        .replace('\n', "<br>")
                        .replace('|', "\\|")
                })
                .collect()
        })
        .collect();
    let columns = rows.iter().map(Vec::len).max().unwrap_or(0);
    if columns == 0 {
        return String::new();
    }
    let line = |cells: &[String]| {
        let padded: Vec<&str> = (0..columns)
            .map(|n| cells.get(n).map_or("", |c| c.trim()))
            .collect();
        format!("| {} |", padded.join(" | "))
    };
    let mut out = vec![line(&rows[0]), format!("|{}", " --- |".repeat(columns))];
    out.extend(rows[1..].iter().map(|r| line(r)));
    out.join("\n")
}

/// An image, by its file name (what the attachments list shows), so the
/// UI can match it.
fn media(node: &Value) -> String {
    if kind(node) != "media" && kind(node) != "mediaInline" {
        return String::new();
    }
    let name = [attr_str(node, "alt"), attr_str(node, "url")]
        .into_iter()
        .map(str::trim)
        .find(|n| !n.is_empty())
        .unwrap_or("attachment");
    format!("![{}]({})", escape(name), link_target(name))
}

fn card(node: &Value) -> String {
    let url = attr_str(node, "url");
    if url.is_empty() {
        return String::new();
    }
    format!("[{}]({})", escape(url), link_target(url))
}

// ---- Inline ----

fn inline(nodes: &[Value]) -> String {
    let mut out = String::new();
    let mut at = 0;
    while at < nodes.len() {
        let node = &nodes[at];
        if kind(node) == "text" {
            // Neighbours with the same marks become one run, so "**a****b**"
            // doesn't happen.
            let marks = node.get("marks");
            let mut text = String::new();
            while at < nodes.len() && kind(&nodes[at]) == "text" && nodes[at].get("marks") == marks
            {
                text.push_str(
                    nodes[at]
                        .get("text")
                        .and_then(Value::as_str)
                        .unwrap_or_default(),
                );
                at += 1;
            }
            out.push_str(&marked(&text, marks.and_then(Value::as_array)));
            continue;
        }
        out.push_str(&inline_node(node));
        at += 1;
    }
    out
}

fn inline_node(node: &Value) -> String {
    match kind(node) {
        "hardBreak" => "\\\n".to_owned(),
        "mention" => {
            let name = attr_str(node, "text").trim().trim_start_matches('@');
            if name.is_empty() {
                "@someone".to_owned()
            } else {
                format!("@{name}")
            }
        }
        "emoji" => {
            let text = attr_str(node, "text");
            if text.is_empty() {
                attr_str(node, "shortName").to_owned()
            } else {
                text.to_owned()
            }
        }
        "inlineCard" => card(node),
        "date" => attr(node, "timestamp")
            .and_then(|t| {
                t.as_str()
                    .and_then(|s| s.parse().ok())
                    .or_else(|| t.as_i64())
            })
            .map(date_of_unix_ms)
            .unwrap_or_default(),
        "status" => {
            let text = attr_str(node, "text").trim();
            if text.is_empty() {
                String::new()
            } else {
                format!("**{}**", escape(text))
            }
        }
        "mediaInline" => media(node),
        "placeholder" | "inlineExtension" => String::new(),
        _ => inline(children(node)),
    }
}

/// Text with its marks; spaces stay outside the markers (`** a**` isn't
/// bold in Markdown).
fn marked(text: &str, marks: Option<&Vec<Value>>) -> String {
    let marks = marks.map_or(&[][..], Vec::as_slice);
    if text.is_empty() {
        return String::new();
    }
    let has = |name: &str| marks.iter().any(|m| kind(m) == name);
    let core = text.trim();
    if core.is_empty() {
        return text.to_owned();
    }
    let lead = &text[..text.len() - text.trim_start().len()];
    let trail = &text[text.trim_end().len()..];
    let mut out = if has("code") {
        code_span(core)
    } else {
        escape(core)
    };
    if has("strike") {
        out = format!("~~{out}~~");
    }
    if has("em") {
        out = format!("*{out}*");
    }
    if has("strong") {
        out = format!("**{out}**");
    }
    if let Some(href) = marks
        .iter()
        .find(|m| kind(m) == "link")
        .map(|m| attr_str(m, "href"))
        .filter(|h| !h.is_empty())
    {
        out = format!("[{out}]({})", link_target(href));
    }
    format!("{lead}{out}{trail}")
}

fn code_span(code: &str) -> String {
    let longest = code.split(|c| c != '`').map(str::len).max().unwrap_or(0);
    let ticks = "`".repeat(longest + 1);
    if longest > 0 {
        format!("{ticks} {code} {ticks}")
    } else {
        format!("{ticks}{code}{ticks}")
    }
}

/// A link destination; in angle brackets when it has spaces or parentheses.
fn link_target(url: &str) -> String {
    if url.contains([' ', '(', ')', '<', '>']) {
        format!("<{}>", url.replace('<', "%3C").replace('>', "%3E"))
    } else {
        url.to_owned()
    }
}

/// Escapes what Markdown would read as formatting. `_` inside words
/// (`price_history`) stays as is: Markdown doesn't read it there.
fn escape(text: &str) -> String {
    let chars: Vec<char> = text.chars().collect();
    let mut out = String::with_capacity(text.len());
    for (n, c) in chars.iter().enumerate() {
        let escaped = match c {
            '\\' | '`' | '*' | '[' | ']' | '<' => true,
            '_' => {
                let word = |at: Option<&char>| at.is_some_and(|c| c.is_alphanumeric());
                !(word(n.checked_sub(1).and_then(|p| chars.get(p))) && word(chars.get(n + 1)))
            }
            '~' => {
                chars.get(n + 1) == Some(&'~')
                    || n.checked_sub(1).and_then(|p| chars.get(p)) == Some(&'~')
            }
            _ => false,
        };
        if escaped {
            out.push('\\');
        }
        out.push(*c);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn doc(content: Value) -> Value {
        json!({"type": "doc", "version": 1, "content": content})
    }

    #[test]
    fn converts_every_node_jira_sends() {
        let adf: Value =
            serde_json::from_str(include_str!("fixtures/jira_adf_all_nodes.json")).unwrap();
        let expected = include_str!("fixtures/jira_adf_all_nodes.md");
        assert_eq!(to_markdown(&adf), expected.trim_end());
    }

    #[test]
    fn marks_keep_spaces_outside_and_merge_neighbours() {
        let adf = doc(json!([{"type": "paragraph", "content": [
            {"type": "text", "text": "Say "},
            {"type": "text", "text": "hello ", "marks": [{"type": "strong"}]},
            {"type": "text", "text": "world", "marks": [{"type": "strong"}]},
            {"type": "text", "text": " to "},
            {"type": "text", "text": "a`b", "marks": [{"type": "code"}]},
            {"type": "text", "text": " and ", "marks": []},
            {"type": "text", "text": "docs", "marks": [{"type": "em"}, {"type": "link", "attrs": {"href": "https://x.y/a (b)"}}]}
        ]}]));
        assert_eq!(
            to_markdown(&adf),
            "Say **hello world** to `` a`b `` and [*docs*](<https://x.y/a (b)>)"
        );
    }

    #[test]
    fn escapes_what_would_read_as_markdown() {
        let adf = doc(json!([
            {"type": "paragraph", "content": [{"type": "text", "text": "# not a heading"}]},
            {"type": "paragraph", "content": [{"type": "text", "text": "1. not a list, *nor* [a link] _x_ price_history"}]},
            {"type": "paragraph", "content": [{"type": "text", "text": "- nor a bullet"}]}
        ]));
        assert_eq!(
            to_markdown(&adf),
            "\\# not a heading\n\n1\\. not a list, \\*nor\\* \\[a link\\] \\_x\\_ price_history\n\n\\- nor a bullet"
        );
    }

    #[test]
    fn plain_values_and_empty_docs() {
        assert_eq!(to_markdown(&doc(json!([]))), "");
        assert_eq!(to_markdown(&Value::Null), "");
        let unknown = doc(json!([{"type": "somethingNew", "content": [
            {"type": "paragraph", "content": [{"type": "text", "text": "kept"}]}
        ]}]));
        assert_eq!(to_markdown(&unknown), "kept");
    }
}
