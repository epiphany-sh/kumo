use crate::changes::CommitInfo;
use crate::pipelines::CiState;
use crate::time::Timestamp;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ReleaseKind {
    Release,
    PreRelease,
    Draft,
    /// A tag nobody turned into a release.
    TagOnly,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReleaseAsset {
    pub name: String,
    /// Bytes; 0 when the host doesn't say.
    pub size: u64,
}

/// A release, or a bare tag.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Release {
    pub tag: String,
    pub kind: ReleaseKind,
    pub name: String,
    /// Markdown; empty = none.
    pub notes: String,
    /// Display name, else login.
    pub author: String,
    /// The tagged commit; empty for a draft without a tag yet.
    pub sha: String,
    /// Published, else tagged.
    pub time: Option<Timestamp>,
    /// The release page, else the tag's.
    pub url: String,
    /// Latest run on the tagged commit, when known.
    pub checks: Option<CiState>,
    pub assets: Vec<ReleaseAsset>,
}

impl Release {
    /// A tag without a release.
    pub fn of_tag(tag: &GitTag, url: String) -> Self {
        Self {
            tag: tag.name.clone(),
            kind: ReleaseKind::TagOnly,
            name: String::new(),
            notes: String::new(),
            author: tag.author.clone(),
            sha: tag.sha.clone(),
            time: tag.time,
            url,
            checks: None,
            assets: Vec::new(),
        }
    }
}

/// A tag as git has it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GitTag {
    pub name: String,
    /// The commit it points at (annotated tags: peeled).
    pub sha: String,
    /// Tagged (annotated) or committed (lightweight).
    pub time: Option<Timestamp>,
    /// The tagger, else the commit's author.
    pub author: String,
}

/// A pull request merged in a range of history.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MergedPr {
    /// `#518`, `!228`.
    pub reference: String,
    pub title: String,
    pub author: String,
    /// `PRC-412`, from its branch or title.
    pub ticket: Option<String>,
}

impl MergedPr {
    /// The pull request a commit on the range merged, if it names one: a
    /// merge (`Merge pull request #518 from acme/feat/PRC-412-x`, GitLab's
    /// `Merge branch 'x' into 'main'` + `See merge request g/r!228`) or a
    /// squash (`feat: x (#518)`).
    pub fn from_commit(subject: &str, author: &str, body: &str) -> Option<Self> {
        let reference = CommitInfo::pr_ref_of(subject, body)?;
        let body_title = || {
            body.lines()
                .map(str::trim)
                .find(|l| !l.is_empty() && !l.starts_with("See merge request "))
                .map(str::to_owned)
        };
        let (title, branch) = if let Some(rest) = subject
            .strip_prefix("Merge pull request ")
            .or_else(|| subject.strip_prefix("Merge merge request "))
        {
            // `#518 from owner/branch`: the branch is after the owner.
            let from = rest.split_once(" from ").map(|(_, f)| f.trim());
            let branch = from.map(|f| f.split_once('/').map_or(f, |(_, b)| b).to_owned());
            (body_title().or_else(|| branch.clone()), branch)
        } else if let Some(rest) = subject.strip_prefix("Merge branch '") {
            let branch = rest.split('\'').next().map(str::to_owned);
            (body_title().or_else(|| branch.clone()), branch)
        } else {
            (
                Some(CommitInfo::subject_without_ref(subject).to_owned()),
                None,
            )
        };
        let title = title.unwrap_or_default();
        let ticket = branch
            .as_deref()
            .and_then(ticket_in)
            .or_else(|| ticket_in(&title));
        Some(Self {
            reference,
            title,
            author: author.to_owned(),
            ticket,
        })
    }
}

/// The first `ABC-123` in `text` (an uppercase key, a dash, digits).
pub fn ticket_in(text: &str) -> Option<String> {
    let bytes = text.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        let starts_word = i == 0 || !bytes[i - 1].is_ascii_alphanumeric();
        if starts_word && bytes[i].is_ascii_uppercase() {
            let mut j = i + 1;
            while j < bytes.len() && (bytes[j].is_ascii_uppercase() || bytes[j].is_ascii_digit()) {
                j += 1;
            }
            if j > i + 1 && j < bytes.len() && bytes[j] == b'-' {
                let mut k = j + 1;
                while k < bytes.len() && bytes[k].is_ascii_digit() {
                    k += 1;
                }
                if k > j + 1 {
                    return Some(text[i..k].to_owned());
                }
            }
            i = j;
        } else {
            i += 1;
        }
    }
    None
}

/// What changed between two tags.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ReleaseRange {
    /// The tag it starts after; empty: from the first commit.
    pub since: String,
    pub commits: u32,
    pub added: u32,
    pub deleted: u32,
    pub files: u32,
    /// Newest first.
    pub prs: Vec<MergedPr>,
}

/// What to change of a release (None: as is).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ReleaseEdit {
    pub name: Option<String>,
    pub notes: Option<String>,
    /// Turn a pre-release or draft into the latest release.
    pub publish: bool,
    /// The tagged commit: a release created for a tag the host doesn't
    /// have yet tags this commit, not the default branch.
    pub sha: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tickets() {
        assert_eq!(ticket_in("feat/PRC-412-bulk").as_deref(), Some("PRC-412"));
        assert_eq!(ticket_in("fix: x (AB2-9)").as_deref(), Some("AB2-9"));
        assert_eq!(ticket_in("utf-8 and A-1 and v1-2"), None);
        assert_eq!(ticket_in("xPRC-1"), None);
    }

    #[test]
    fn merged_pull_requests_from_their_commits() {
        let merge = MergedPr::from_commit(
            "Merge pull request #521 from pricing/feat/PRC-412-bulk-discounts",
            "Mauri",
            "feat: bulk discounts by category\n",
        )
        .unwrap();
        assert_eq!(
            merge,
            MergedPr {
                reference: "#521".into(),
                title: "feat: bulk discounts by category".into(),
                author: "Mauri".into(),
                ticket: Some("PRC-412".into()),
            }
        );
        let squash = MergedPr::from_commit("fix: cache key (PRC-409) (#516)", "Lucía", "").unwrap();
        assert_eq!(
            (
                squash.reference.as_str(),
                squash.title.as_str(),
                squash.ticket.as_deref()
            ),
            ("#516", "fix: cache key (PRC-409)", Some("PRC-409"))
        );
        let gitlab = MergedPr::from_commit(
            "Merge branch 'perf/PRR-9-batch' into 'main'",
            "Lucía",
            "perf: batch lookups\n\nSee merge request pricing/reader!224",
        )
        .unwrap();
        assert_eq!(
            (
                gitlab.reference.as_str(),
                gitlab.title.as_str(),
                gitlab.ticket.as_deref()
            ),
            ("!224", "perf: batch lookups", Some("PRR-9"))
        );
        assert_eq!(MergedPr::from_commit("chore: no ref", "x", ""), None);
    }
}
