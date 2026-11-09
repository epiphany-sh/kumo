use kumo_application::releases::ReleaseList;
use kumo_domain::releases::{MergedPr, Release, ReleaseKind, ReleaseRange};
use kumo_proto::v1 as pb;

use super::pipelines::{ci_problem_to, state_to};

pub fn release_to(release: &Release) -> pb::Release {
    pb::Release {
        tag: release.tag.clone(),
        kind: match release.kind {
            ReleaseKind::Release => pb::ReleaseKind::Release,
            ReleaseKind::PreRelease => pb::ReleaseKind::PreRelease,
            ReleaseKind::Draft => pb::ReleaseKind::Draft,
            ReleaseKind::TagOnly => pb::ReleaseKind::TagOnly,
        }
        .into(),
        name: release.name.clone(),
        notes: release.notes.clone(),
        author: release.author.clone(),
        sha: release.sha.clone(),
        time_unix: release
            .time
            .map_or(0, |t| t.as_unix_nanos() / 1_000_000_000),
        url: release.url.clone(),
        checks: release.checks.map(|s| state_to(s).into()),
        assets: release
            .assets
            .iter()
            .map(|a| pb::ReleaseAsset {
                name: a.name.clone(),
                size: a.size,
            })
            .collect(),
    }
}

pub fn release_list_to(list: &ReleaseList) -> pb::ReleaseList {
    pb::ReleaseList {
        releases: list.releases.iter().map(release_to).collect(),
        older: list.older,
        problem: list.problem.as_ref().map(ci_problem_to),
    }
}

pub fn release_range_to(range: &ReleaseRange) -> pb::ReleaseRange {
    pb::ReleaseRange {
        since: range.since.clone(),
        commits: range.commits,
        added: range.added,
        deleted: range.deleted,
        files: range.files,
        prs: range.prs.iter().map(merged_pr_to).collect(),
    }
}

fn merged_pr_to(pr: &MergedPr) -> pb::MergedPr {
    pb::MergedPr {
        r#ref: pr.reference.clone(),
        title: pr.title.clone(),
        author: pr.author.clone(),
        ticket: pr.ticket.clone().unwrap_or_default(),
    }
}
