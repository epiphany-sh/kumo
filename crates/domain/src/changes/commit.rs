use super::{ChangeKind, DiffLine};

/// A commit in the history.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct CommitInfo {
    pub sha: String,
    pub short_sha: String,
    pub subject: String,
    pub author: String,
    pub time_unix: u64,
    /// The branch it's on when it isn't on main yet (all branches only).
    pub branch: Option<String>,
    /// The pull request it came from: `#518`, `!228`.
    pub pr_ref: Option<String>,
}

impl CommitInfo {
    /// The pull request a commit names: `Merge pull request #518 from …`,
    /// a squash `… (#518)`, or GitLab's `See merge request group/repo!228`
    /// in the body.
    pub fn pr_ref_of(subject: &str, body: &str) -> Option<String> {
        let subject = subject.trim();
        if let Some(rest) = subject
            .strip_prefix("Merge pull request ")
            .or_else(|| subject.strip_prefix("Merge merge request "))
            && let Some(r) = reference(rest.split_whitespace().next().unwrap_or_default())
        {
            return Some(r);
        }
        if let Some(open) = subject.rfind(" (")
            && let Some(inner) = subject[open + 2..].strip_suffix(')')
            && let Some(r) = reference(inner)
        {
            return Some(r);
        }
        body.lines().rev().find_map(|line| {
            let rest = line.trim().strip_prefix("See merge request ")?;
            let bang = rest.rfind('!')?;
            reference(rest[bang..].trim_end_matches('.'))
        })
    }

    /// The subject without the squash's `(#518)`.
    pub fn subject_without_ref(subject: &str) -> &str {
        match subject.rfind(" (") {
            Some(open)
                if subject[open + 2..]
                    .strip_suffix(')')
                    .and_then(reference)
                    .is_some() =>
            {
                subject[..open].trim_end()
            }
            _ => subject,
        }
    }
}

/// `#518` or `!228`, exactly.
fn reference(raw: &str) -> Option<String> {
    let mut chars = raw.chars();
    let sign = chars.next()?;
    let digits = chars.as_str();
    (matches!(sign, '#' | '!') && !digits.is_empty() && digits.bytes().all(|b| b.is_ascii_digit()))
        .then(|| raw.to_owned())
}

/// How to commit.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommitOptions {
    pub message: String,
    /// Stage every change first.
    pub all: bool,
    pub amend: bool,
}

/// `@@ -old_start,… +new_start,… @@ section` and its lines.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct DiffHunk {
    pub old_start: u32,
    pub new_start: u32,
    /// What git prints after the second `@@` (the enclosing function).
    pub section: String,
    pub lines: Vec<DiffLine>,
}

/// A file one commit touched.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct CommitFile {
    pub path: String,
    /// Renames: where it was.
    pub old_path: Option<String>,
    pub kind: ChangeKind,
    pub added: u32,
    pub deleted: u32,
    pub binary: bool,
    /// Empty for binaries and when [`cut`](Self::cut).
    pub hunks: Vec<DiffHunk>,
    /// Too big: counts without hunks.
    pub cut: bool,
}

/// What one commit changed, file by file.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct CommitDetail {
    pub sha: String,
    /// The message after the subject line.
    pub body: String,
    /// Short shas.
    pub parents: Vec<String>,
    pub time_unix: u64,
    pub files: Vec<CommitFile>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pull_request_references() {
        let of = CommitInfo::pr_ref_of;
        assert_eq!(
            of("Merge pull request #518 from acme/feat/x", "").as_deref(),
            Some("#518")
        );
        assert_eq!(
            of("feat: bulk discounts (#521)", "").as_deref(),
            Some("#521")
        );
        assert_eq!(
            of(
                "Merge branch 'feat/x' into 'main'",
                "Adds x\n\nSee merge request platform/reader!228"
            )
            .as_deref(),
            Some("!228")
        );
        assert_eq!(of("fix: thing (see notes)", ""), None);
        assert_eq!(of("chore: #12 is not a ref", ""), None);
        assert_eq!(
            CommitInfo::subject_without_ref("feat: bulk discounts (#521)"),
            "feat: bulk discounts"
        );
        assert_eq!(CommitInfo::subject_without_ref("fix: a (b)"), "fix: a (b)");
    }
}
