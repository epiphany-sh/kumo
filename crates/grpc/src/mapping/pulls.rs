use kumo_application::pulls::{BranchPullRequest, PullRequestList};
use kumo_domain::pulls::{PrState, PullRequest, ReviewState};
use kumo_proto::v1 as pb;

use super::pipelines::{ci_problem_to, ci_provider_to, ms, state_to};
use super::tasks::person_to;

pub fn pull_request_to(pr: &PullRequest) -> pb::PullRequest {
    pb::PullRequest {
        number: pr.number,
        label: pr.label.clone(),
        title: pr.title.clone(),
        author: Some(person_to(&pr.author)),
        branch: pr.branch.clone(),
        base: pr.base.clone(),
        draft: pr.draft,
        state: match pr.state {
            PrState::Open => pb::PrState::Open,
            PrState::Merged => pb::PrState::Merged,
            PrState::Closed => pb::PrState::Closed,
        }
        .into(),
        review: match pr.review {
            ReviewState::None => pb::ReviewState::None,
            ReviewState::Required => pb::ReviewState::Required,
            ReviewState::ChangesRequested => pb::ReviewState::ChangesRequested,
            ReviewState::Approved => pb::ReviewState::Approved,
        }
        .into(),
        review_requested_from_you: pr.review_requested_from_you,
        reviewers: pr.reviewers.iter().map(person_to).collect(),
        checks_passed: pr.checks_passed,
        checks_total: pr.checks_total,
        checks_state: pr.checks_state.map(|s| state_to(s).into()),
        url: pr.url.clone(),
        created_at: ms(pr.created_at),
        updated_at: ms(pr.updated_at),
        comment_count: pr.comment_count,
    }
}

pub fn pull_request_list_to(list: &PullRequestList) -> pb::PullRequestList {
    pb::PullRequestList {
        provider: ci_provider_to(list.provider).into(),
        pull_requests: list.pull_requests.iter().map(pull_request_to).collect(),
        problem: list.problem.as_ref().map(ci_problem_to),
    }
}

pub fn branch_pull_request_to(b: &BranchPullRequest) -> pb::BranchPullRequest {
    pb::BranchPullRequest {
        provider: ci_provider_to(b.provider).into(),
        pull_request: b.pull_request.as_ref().map(pull_request_to),
        problem: b.problem.as_ref().map(ci_problem_to),
    }
}
