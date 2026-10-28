use std::collections::BTreeMap;
use std::fmt;
use std::path::PathBuf;

use super::{TaskError, TaskStatus};

/// The tools Kumo reads tasks from.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum SourceKind {
    /// Checkboxes in the notes of a vault (a folder of Markdown).
    Obsidian,
    /// Checkboxes in Bear notes (read from its local database).
    Bear,
    /// Issues, through the user's own `gh` CLI.
    GitHub,
    Jira,
    Todoist,
}

impl SourceKind {
    pub const ALL: [SourceKind; 5] = [
        SourceKind::Obsidian,
        SourceKind::Bear,
        SourceKind::GitHub,
        SourceKind::Jira,
        SourceKind::Todoist,
    ];

    /// Stable identifier, for storage and the wire.
    pub fn id(self) -> &'static str {
        match self {
            SourceKind::Obsidian => "obsidian",
            SourceKind::Bear => "bear",
            SourceKind::GitHub => "github",
            SourceKind::Jira => "jira",
            SourceKind::Todoist => "todoist",
        }
    }

    pub fn from_id(id: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|kind| kind.id() == id)
    }

    pub fn name(self) -> &'static str {
        match self {
            SourceKind::Obsidian => "Obsidian",
            SourceKind::Bear => "Bear",
            SourceKind::GitHub => "GitHub",
            SourceKind::Jira => "Jira",
            SourceKind::Todoist => "Todoist",
        }
    }

    /// Two-letter badge.
    pub fn badge(self) -> &'static str {
        match self {
            SourceKind::Obsidian => "OB",
            SourceKind::Bear => "BR",
            SourceKind::GitHub => "GH",
            SourceKind::Jira => "JI",
            SourceKind::Todoist => "TD",
        }
    }

    /// Needs an API token, kept in the OS keychain.
    pub fn needs_secret(self) -> bool {
        matches!(self, SourceKind::Jira | SourceKind::Todoist)
    }

    /// Reads files on this machine: synced on change, not on a timer.
    pub fn is_local(self) -> bool {
        matches!(self, SourceKind::Obsidian | SourceKind::Bear)
    }

    /// Statuses Kumo can write back.
    pub fn writable(self) -> &'static [TaskStatus] {
        use TaskStatus::*;
        match self {
            SourceKind::Obsidian => &[Todo, Doing, Done],
            SourceKind::Bear => &[],
            SourceKind::GitHub | SourceKind::Todoist => &[Todo, Done],
            SourceKind::Jira => &[Todo, Doing, Review, Done],
        }
    }
}

impl fmt::Display for SourceKind {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.name())
    }
}

/// A configured source's id.
#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct SourceId(String);

impl SourceId {
    pub fn generate() -> Self {
        Self(uuid::Uuid::new_v4().simple().to_string())
    }

    /// Ids never contain '/': task ids are `<source>/<external>`.
    pub fn parse(raw: &str) -> Result<Self, TaskError> {
        let raw = raw.trim();
        if raw.is_empty() || raw.contains('/') {
            return Err(TaskError::UnknownSource(raw.to_owned()));
        }
        Ok(Self(raw.to_owned()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for SourceId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// Where each kind of source reads from. On the wire and on disk these are
/// plain string options (see [`SourceOptions::to_map`]).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SourceOptions {
    Obsidian {
        vault: PathBuf,
    },
    /// `None`: Bear's usual database.
    Bear {
        database: Option<PathBuf>,
    },
    /// GitHub search syntax.
    GitHub {
        query: String,
    },
    /// `site` like `https://acme.atlassian.net`; signs in with `email` and
    /// an API token.
    Jira {
        site: String,
        email: String,
        jql: String,
    },
    /// Only this project's tasks; empty: every open task.
    Todoist {
        project: String,
    },
}

impl SourceOptions {
    pub const GITHUB_QUERY: &str = "is:open is:issue assignee:@me archived:false";
    pub const JIRA_JQL: &str = "assignee = currentUser() AND (statusCategory != Done OR updated >= -14d) ORDER BY updated DESC";

    pub fn kind(&self) -> SourceKind {
        match self {
            SourceOptions::Obsidian { .. } => SourceKind::Obsidian,
            SourceOptions::Bear { .. } => SourceKind::Bear,
            SourceOptions::GitHub { .. } => SourceKind::GitHub,
            SourceOptions::Jira { .. } => SourceKind::Jira,
            SourceOptions::Todoist { .. } => SourceKind::Todoist,
        }
    }

    /// Validates the options of a `kind`; empty optional ones take their
    /// defaults.
    pub fn from_map(kind: SourceKind, map: &BTreeMap<String, String>) -> Result<Self, TaskError> {
        let get = |key: &str| map.get(key).map(|v| v.trim()).unwrap_or_default();
        let required = |key: &str, what: &str| {
            let value = get(key);
            if value.is_empty() {
                Err(TaskError::Invalid(format!("{kind}: {what} is required")))
            } else {
                Ok(value.to_owned())
            }
        };
        Ok(match kind {
            SourceKind::Obsidian => SourceOptions::Obsidian {
                vault: PathBuf::from(required("vault", "the vault folder")?),
            },
            SourceKind::Bear => SourceOptions::Bear {
                database: Some(get("database"))
                    .filter(|d| !d.is_empty())
                    .map(PathBuf::from),
            },
            SourceKind::GitHub => SourceOptions::GitHub {
                query: or_default(get("query"), Self::GITHUB_QUERY),
            },
            SourceKind::Jira => {
                let site = required("site", "the site URL")?;
                let site = site.trim_end_matches('/').to_owned();
                if !(site.starts_with("https://") || is_loopback_http(&site)) {
                    return Err(TaskError::Invalid(
                        "Jira: the site must be an https:// URL, e.g. https://acme.atlassian.net"
                            .into(),
                    ));
                }
                SourceOptions::Jira {
                    site,
                    email: required("email", "the account email")?,
                    jql: or_default(get("jql"), Self::JIRA_JQL),
                }
            }
            SourceKind::Todoist => SourceOptions::Todoist {
                project: get("project").to_owned(),
            },
        })
    }

    pub fn to_map(&self) -> BTreeMap<String, String> {
        let pairs: Vec<(&str, String)> = match self {
            SourceOptions::Obsidian { vault } => vec![("vault", vault.display().to_string())],
            SourceOptions::Bear { database } => database
                .iter()
                .map(|d| ("database", d.display().to_string()))
                .collect(),
            SourceOptions::GitHub { query } => vec![("query", query.clone())],
            SourceOptions::Jira { site, email, jql } => vec![
                ("site", site.clone()),
                ("email", email.clone()),
                ("jql", jql.clone()),
            ],
            SourceOptions::Todoist { project } => vec![("project", project.clone())],
        };
        pairs.into_iter().map(|(k, v)| (k.to_owned(), v)).collect()
    }
}

fn or_default(value: &str, default: &str) -> String {
    if value.is_empty() { default } else { value }.to_owned()
}

/// Plain HTTP only to this machine (tests, local proxies).
fn is_loopback_http(site: &str) -> bool {
    ["http://127.0.0.1:", "http://localhost:", "http://[::1]:"]
        .iter()
        .any(|prefix| site.starts_with(prefix))
}

/// A configured source.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TaskSource {
    pub id: SourceId,
    pub name: String,
    pub options: SourceOptions,
    pub enabled: bool,
}

impl TaskSource {
    pub fn kind(&self) -> SourceKind {
        self.options.kind()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn map(pairs: &[(&str, &str)]) -> BTreeMap<String, String> {
        pairs
            .iter()
            .map(|(k, v)| ((*k).to_owned(), (*v).to_owned()))
            .collect()
    }

    #[test]
    fn options_round_trip_and_take_defaults() {
        let github = SourceOptions::from_map(SourceKind::GitHub, &map(&[])).unwrap();
        assert_eq!(
            github,
            SourceOptions::GitHub {
                query: SourceOptions::GITHUB_QUERY.into()
            }
        );
        let jira = SourceOptions::from_map(
            SourceKind::Jira,
            &map(&[("site", "https://acme.atlassian.net/"), ("email", "a@b.c")]),
        )
        .unwrap();
        assert_eq!(
            SourceOptions::from_map(SourceKind::Jira, &jira.to_map()).unwrap(),
            jira
        );
        assert!(
            matches!(jira, SourceOptions::Jira { ref site, .. } if site == "https://acme.atlassian.net")
        );
    }

    #[test]
    fn rejects_missing_or_insecure_options() {
        assert!(SourceOptions::from_map(SourceKind::Obsidian, &map(&[("vault", " ")])).is_err());
        let insecure = map(&[("site", "http://acme.atlassian.net"), ("email", "a@b.c")]);
        assert!(SourceOptions::from_map(SourceKind::Jira, &insecure).is_err());
        let local = map(&[("site", "http://127.0.0.1:8080"), ("email", "a@b.c")]);
        assert!(SourceOptions::from_map(SourceKind::Jira, &local).is_ok());
    }

    #[test]
    fn kinds_round_trip_through_their_ids() {
        for kind in SourceKind::ALL {
            assert_eq!(SourceKind::from_id(kind.id()), Some(kind));
        }
        assert_eq!(SourceKind::from_id("trello"), None);
    }

    #[test]
    fn source_ids_never_contain_a_slash() {
        assert!(SourceId::parse("a/b").is_err());
        assert!(SourceId::parse("").is_err());
        assert_eq!(SourceId::parse(" abc ").unwrap().as_str(), "abc");
    }
}
