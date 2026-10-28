import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

import '../data/pull_requests_source.dart';
import 'engine_pipelines_source.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart' as pb;
import 'kumo_engine.dart';

/// Pull requests over `PullRequests` (List / ForBranch / Create).
class EnginePullRequests implements PullRequestsSource {
  EnginePullRequests(this._engine);
  final KumoEngine _engine;

  Future<T> _call<T>(Future<T> Function(pb.PullRequestsClient client) call) async {
    try {
      return await call((await _engine.connection()).pulls);
    } on GrpcError catch (e) {
      throw e.message ?? e.codeName;
    }
  }

  @override
  Future<PullRequestList> list(String repoPath, {bool refresh = false}) async {
    final answer = await _call((c) => c.list(pb.ListPullRequestsRequest(repoPath: repoPath, refresh: refresh)));
    return PullRequestList(
      provider: ciProviderFrom(answer.provider),
      pullRequests: [for (final p in answer.pullRequests) pullRequestFrom(p)],
      problem: answer.hasProblem() ? ciProblemFrom(answer.problem) : null,
    );
  }

  @override
  Future<BranchPullRequest> forBranch(String worktreePath, {bool refresh = false}) async {
    final answer = await _call((c) => c.forBranch(pb.BranchPullRequestRequest(worktreePath: worktreePath, refresh: refresh)));
    return BranchPullRequest(
      provider: ciProviderFrom(answer.provider),
      pullRequest: answer.hasPullRequest() ? pullRequestFrom(answer.pullRequest) : null,
      problem: answer.hasProblem() ? ciProblemFrom(answer.problem) : null,
    );
  }

  @override
  Future<PullRequestInfo> create({required String worktreePath, required String title, String body = '', String base = '', bool draft = false}) async =>
      pullRequestFrom(await _call((c) => c.create(pb.CreatePullRequestRequest(worktreePath: worktreePath, title: title, body: body, base: base, draft: draft))));
}

DateTime? _time(Int64 ms) => ms <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms.toInt());

PullRequestInfo pullRequestFrom(pb.PullRequest p) => PullRequestInfo(
      number: p.number.toInt(),
      label: p.label,
      title: p.title,
      author: p.author.name,
      authorIsYou: p.author.you,
      branch: p.branch,
      base: p.base,
      draft: p.draft,
      state: switch (p.state) {
        pb.PrState.PR_STATE_MERGED => PrOpenState.merged,
        pb.PrState.PR_STATE_CLOSED => PrOpenState.closed,
        _ => PrOpenState.open,
      },
      review: switch (p.review) {
        pb.ReviewState.REVIEW_STATE_REQUIRED => PrReview.required,
        pb.ReviewState.REVIEW_STATE_CHANGES_REQUESTED => PrReview.changesRequested,
        pb.ReviewState.REVIEW_STATE_APPROVED => PrReview.approved,
        _ => PrReview.none,
      },
      reviewRequestedFromYou: p.reviewRequestedFromYou,
      reviewers: [for (final r in p.reviewers) r.name],
      checksPassed: p.checksPassed,
      checksTotal: p.checksTotal,
      checksState: p.hasChecksState() ? ciStateFrom(p.checksState) : null,
      url: p.url,
      created: _time(p.createdAt),
      updated: _time(p.updatedAt),
      commentCount: p.commentCount,
    );
