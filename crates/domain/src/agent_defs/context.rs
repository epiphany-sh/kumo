//! What a run is given, written as files next to it, and the links it can
//! start from.

use crate::agents::{AgentContext, ContextKind};

/// A repository, branch or pull/merge request link, read the way the UI
/// reads it (`parseRepoLink` in kumo-ui).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RepoLink {
    /// e.g. github.com.
    pub host: String,
    /// owner/repo (GitLab: group/sub/repo).
    pub path: String,
    pub number: Option<u64>,
    pub merge_request: bool,
    pub branch: String,
}

impl RepoLink {
    pub fn parse(url: &str) -> Option<Self> {
        let url = url.trim();
        let rest = url
            .strip_prefix("https://")
            .or_else(|| url.strip_prefix("http://"))?;
        let rest = rest.split(['?', '#']).next().unwrap_or_default();
        let (host, path) = rest.split_once('/')?;
        if host.is_empty() {
            return None;
        }
        let parts: Vec<&str> = path.split('/').filter(|p| !p.is_empty()).collect();
        let dash = parts.iter().position(|p| *p == "-");
        let cut = dash.or_else(|| {
            parts
                .iter()
                .position(|p| matches!(*p, "pull" | "tree" | "pulls" | "merge_requests"))
        });
        let repo = cut.map_or(&parts[..], |c| &parts[..c]).join("/");
        let repo = repo.strip_suffix(".git").unwrap_or(&repo).to_owned();
        if repo.split('/').count() < 2 {
            return None;
        }
        let tail: &[&str] = match (dash, cut) {
            (Some(d), _) => &parts[d + 1..],
            (None, Some(c)) => &parts[c..],
            _ => &[],
        };
        let mut link = Self {
            host: host.to_owned(),
            path: repo,
            number: None,
            merge_request: false,
            branch: String::new(),
        };
        match tail {
            [kind @ ("pull" | "merge_requests"), n, ..] => {
                link.number = Some(n.parse().ok()?);
                link.merge_request = *kind == "merge_requests";
            }
            ["tree", branch @ ..] if !branch.is_empty() => link.branch = branch.join("/"),
            _ => {}
        }
        Some(link)
    }

    /// The repository's name.
    pub fn name(&self) -> &str {
        self.path.rsplit('/').next().unwrap_or(&self.path)
    }

    /// The ref a host keeps a pull/merge request's head under.
    pub fn head_ref(&self) -> Option<String> {
        let n = self.number?;
        Some(if self.merge_request {
            format!("refs/merge-requests/{n}/head")
        } else {
            format!("refs/pull/{n}/head")
        })
    }

    /// Whether `remote` (a clone URL) is this repository.
    pub fn same_repo(&self, remote: &str) -> bool {
        let remote = remote.trim().trim_end_matches('/');
        let remote = remote.strip_suffix(".git").unwrap_or(remote);
        let tail = remote
            .rsplit_once(&format!("{}:", self.host))
            .or_else(|| remote.rsplit_once(&format!("{}/", self.host)))
            .map(|(_, t)| t.trim_start_matches('/'));
        tail.is_some_and(|t| t.eq_ignore_ascii_case(&self.path))
    }
}

/// One file of a run's context folder.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ContextFile {
    /// The file's name in the folder.
    pub name: String,
    pub text: String,
}

/// What a context item became: the files written and the line `context.md`
/// gives it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WrittenContext {
    pub item: AgentContext,
    pub files: Vec<ContextFile>,
    /// What couldn't be read, said in its line instead.
    pub problem: Option<String>,
}

/// `context.md`: everything the run was given, one line each.
pub fn context_index(written: &[WrittenContext]) -> String {
    let mut out = String::from("# What you were given for this run\n\n");
    for w in written {
        let kind = match w.item.kind {
            ContextKind::Task => "Ticket",
            ContextKind::Doc => "Page",
            ContextKind::Code => "Code",
            ContextKind::PullRequest => "Pull request",
            ContextKind::Files => "Files",
            ContextKind::Link => "Link",
        };
        out.push_str(&format!("- {kind}: {}", w.item.title));
        if !w.item.url.is_empty() {
            out.push_str(&format!(" ({})", w.item.url));
        }
        let files: Vec<&str> = w.files.iter().map(|f| f.name.as_str()).collect();
        if !files.is_empty() {
            out.push_str(&format!(" → {}", files.join(", ")));
        }
        if let Some(problem) = &w.problem {
            out.push_str(&format!(" · couldn’t be read: {problem}"));
        }
        out.push('\n');
    }
    out
}

/// `text` as a file name: letters, digits, `-`, `_` and `.`, nothing that
/// leaves the folder.
pub fn file_name(text: &str, extension: &str) -> String {
    let mut name: String = text
        .chars()
        .map(|c| {
            if c.is_alphanumeric() || matches!(c, '-' | '_') {
                c
            } else {
                '-'
            }
        })
        .collect();
    while name.contains("--") {
        name = name.replace("--", "-");
    }
    let name = name.trim_matches('-');
    let name: String = name.chars().take(60).collect();
    format!(
        "{}.{extension}",
        if name.is_empty() { "item" } else { &name }
    )
}

/// The ticket key in a context title: "PRC-412 · Bulk discounts" → PRC-412.
pub fn task_key(title: &str) -> &str {
    title.split(" · ").next().unwrap_or(title).trim()
}

/// The pull request number in a context item: its link, or "#521 · …" /
/// "!231 · …".
pub fn pull_number(item: &AgentContext) -> Option<u64> {
    if let Some(n) = RepoLink::parse(&item.url).and_then(|l| l.number) {
        return Some(n);
    }
    let head = task_key(&item.title);
    head.trim_start_matches(['#', '!']).parse().ok()
}

/// Text of an HTML page, roughly: tags, scripts and styles out, entities
/// for the common characters, blank lines folded.
pub fn html_text(html: &str) -> String {
    let mut out = String::new();
    let mut rest = html;
    while let Some(open) = rest.find('<') {
        out.push_str(&rest[..open]);
        let after = &rest[open..];
        let lower = after.get(..8).unwrap_or(after).to_ascii_lowercase();
        let skip_to = if lower.starts_with("<script") {
            after.to_ascii_lowercase().find("</script>").map(|i| i + 9)
        } else if lower.starts_with("<style") {
            after.to_ascii_lowercase().find("</style>").map(|i| i + 8)
        } else {
            after.find('>').map(|i| i + 1)
        };
        let Some(skip) = skip_to else {
            rest = "";
            break;
        };
        let tag = &after[..skip];
        if [
            "<br", "<p", "</p", "<div", "</div", "<li", "<h", "</h", "<tr",
        ]
        .iter()
        .any(|t| tag.to_ascii_lowercase().starts_with(t))
        {
            out.push('\n');
        }
        rest = &after[skip..];
    }
    out.push_str(rest);
    let decoded = out
        .replace("&nbsp;", " ")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&amp;", "&");
    let mut lines = Vec::new();
    for line in decoded.lines().map(str::trim) {
        if line.is_empty() && lines.last().is_none_or(|l: &&str| l.is_empty()) {
            continue;
        }
        lines.push(line);
    }
    lines.join("\n").trim().to_owned()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(kind: ContextKind, title: &str, url: &str) -> AgentContext {
        AgentContext {
            kind,
            title: title.into(),
            detail: String::new(),
            url: url.into(),
            id: String::new(),
        }
    }

    #[test]
    fn links_read_like_the_ui_reads_them() {
        let pr = RepoLink::parse("https://github.com/acme/app/pull/521/files").unwrap();
        assert_eq!(
            (pr.path.as_str(), pr.number, pr.merge_request),
            ("acme/app", Some(521), false)
        );
        assert_eq!(pr.head_ref().unwrap(), "refs/pull/521/head");
        let mr = RepoLink::parse("https://gitlab.com/g/sub/app/-/merge_requests/7").unwrap();
        assert_eq!(
            (mr.path.as_str(), mr.number, mr.merge_request),
            ("g/sub/app", Some(7), true)
        );
        let tree = RepoLink::parse("https://github.com/acme/app/tree/feat/x").unwrap();
        assert_eq!((tree.branch.as_str(), tree.name()), ("feat/x", "app"));
        let repo = RepoLink::parse("https://github.com/acme/app.git").unwrap();
        assert_eq!((repo.path.as_str(), repo.number), ("acme/app", None));
        assert!(RepoLink::parse("https://github.com/acme").is_none());
        assert!(RepoLink::parse("ftp://github.com/a/b").is_none());
        assert!(RepoLink::parse("https://github.com/a/b/pull/x").is_none());
    }

    #[test]
    fn remotes_match_by_host_and_path() {
        let link = RepoLink::parse("https://github.com/acme/app/pull/1").unwrap();
        assert!(link.same_repo("git@github.com:acme/app.git"));
        assert!(link.same_repo("https://github.com/Acme/App"));
        assert!(!link.same_repo("git@github.com:acme/app2.git"));
        assert!(!link.same_repo("git@gitlab.com:acme/app.git"));
    }

    #[test]
    fn the_index_lists_every_item() {
        let written = vec![
            WrittenContext {
                item: item(ContextKind::Task, "PRC-412 · Bulk", ""),
                files: vec![ContextFile {
                    name: "PRC-412.md".into(),
                    text: String::new(),
                }],
                problem: None,
            },
            WrittenContext {
                item: item(ContextKind::Link, "example.com/a", "https://example.com/a"),
                files: Vec::new(),
                problem: Some("HTTP 404".into()),
            },
        ];
        let index = context_index(&written);
        assert!(index.contains("- Ticket: PRC-412 · Bulk → PRC-412.md\n"));
        assert!(index.contains(
            "- Link: example.com/a (https://example.com/a) · couldn’t be read: HTTP 404\n"
        ));
    }

    #[test]
    fn names_numbers_and_keys() {
        assert_eq!(file_name("../etc/passwd", "md"), "etc-passwd.md");
        assert_eq!(file_name("", "txt"), "item.txt");
        assert_eq!(task_key("PRC-412 · Bulk discounts"), "PRC-412");
        assert_eq!(
            pull_number(&item(ContextKind::PullRequest, "#521 · Bulk", "")),
            Some(521)
        );
        assert_eq!(
            pull_number(&item(
                ContextKind::PullRequest,
                "x",
                "https://gitlab.com/a/b/-/merge_requests/9"
            )),
            Some(9)
        );
    }

    #[test]
    fn html_becomes_text() {
        let html = "<html><head><style>p{}</style><script>x()</script></head><body><h1>Title</h1><p>One &amp; two</p><br>Three</body></html>";
        assert_eq!(html_text(html), "Title\n\nOne & two\n\nThree");
    }
}
