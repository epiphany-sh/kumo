import 'package:flutter/foundation.dart';

import 'pipelines_source.dart';
import 'repo_activity.dart';

enum PrOpenState { open, merged, closed }

enum PrReview { none, required, changesRequested, approved }

/// A pull (GitLab: merge) request as the host reports it.
@immutable
class PullRequestInfo {
  const PullRequestInfo({
    required this.number,
    required this.label,
    required this.title,
    required this.author,
    this.authorIsYou = false,
    required this.branch,
    this.base = '',
    this.draft = false,
    this.state = PrOpenState.open,
    this.review = PrReview.none,
    this.reviewRequestedFromYou = false,
    this.reviewers = const [],
    this.checksPassed = 0,
    this.checksTotal = 0,
    this.checksState,
    this.url = '',
    this.created,
    this.updated,
    this.commentCount = 0,
  });

  final int number;

  /// `#521`, `!231`.
  final String label;
  final String title;
  final String author;
  final bool authorIsYou;
  final String branch;
  final String base;
  final bool draft;
  final PrOpenState state;
  final PrReview review;
  final bool reviewRequestedFromYou;
  final List<String> reviewers;
  final int checksPassed;
  final int checksTotal;

  /// Null when no check ran.
  final CiState? checksState;
  final String url;
  final DateTime? created;
  final DateTime? updated;
  final int commentCount;

  /// What the Git view's list shows.
  RepoPullRequest toRepo() => RepoPullRequest(
        number: label,
        title: title,
        author: author,
        branch: branch,
        state: draft
            ? RepoPrState.draft
            : switch (review) {
                PrReview.approved => RepoPrState.approved,
                PrReview.changesRequested => RepoPrState.changesRequested,
                PrReview.required => RepoPrState.reviewRequested,
                PrReview.none => RepoPrState.ready,
              },
        mine: authorIsYou,
        reviewRequestedFromMe: reviewRequestedFromYou,
        checksPassed: checksPassed,
        checksTotal: checksTotal,
        checksState: checksState,
        url: url,
      );
}

/// A repository's open pull requests, or why they can't be read.
@immutable
class PullRequestList {
  const PullRequestList({this.provider, this.pullRequests = const [], this.problem});
  final CiProvider? provider;
  final List<PullRequestInfo> pullRequests;
  final CiProblem? problem;
}

/// A worktree branch's pull request (null: it never had one).
@immutable
class BranchPullRequest {
  const BranchPullRequest({this.provider, this.pullRequest, this.problem});
  final CiProvider? provider;
  final PullRequestInfo? pullRequest;
  final CiProblem? problem;
}

/// Pull requests from the repositories' hosts, through the daemon, with
/// the same tokens as pipelines. [MockPullRequests] backs the design and
/// tests.
abstract class PullRequestsSource {
  /// Open pull requests of the repository whose main checkout is
  /// [repoPath]. [refresh] asks the host even if the last answer is recent.
  Future<PullRequestList> list(String repoPath, {bool refresh = false});

  /// The pull request of the branch checked out at [worktreePath].
  Future<BranchPullRequest> forBranch(String worktreePath, {bool refresh = false});

  /// Opens one from the worktree's (pushed) branch; throws a readable
  /// message when the host refuses. An empty [base] is the default branch.
  Future<PullRequestInfo> create({required String worktreePath, required String title, String body = '', String base = '', bool draft = false});
}

/// The design's pull requests: #521 for feat/PRC-412-bulk-discounts (a
/// draft of yours waiting on Lucía) and #518, whose review you were asked
/// for. Other branches have none; creating one adds it.
class MockPullRequests implements PullRequestsSource {
  MockPullRequests({this.latency = Duration.zero});

  final Duration latency;
  final created = <String, PullRequestInfo>{};

  static const _prs = [
    PullRequestInfo(
      number: 521,
      label: '#521',
      title: 'feat: bulk discounts by category',
      author: 'Mauri',
      authorIsYou: true,
      branch: 'feat/PRC-412-bulk-discounts',
      base: 'main',
      draft: true,
      review: PrReview.required,
      reviewers: ['Lucía'],
      checksPassed: 2,
      checksTotal: 3,
      checksState: CiState.running,
      url: 'https://github.com/pricing/price-admin/pull/521',
      commentCount: 4,
    ),
    PullRequestInfo(
      number: 518,
      label: '#518',
      title: 'fix: rounding on installment prices',
      author: 'Tomás',
      branch: 'fix/PRC-398-rounding',
      base: 'main',
      review: PrReview.changesRequested,
      reviewRequestedFromYou: true,
      reviewers: ['Mauri', 'Nico'],
      checksPassed: 1,
      checksTotal: 2,
      checksState: CiState.failed,
      url: 'https://github.com/pricing/price-admin/pull/518',
      commentCount: 9,
    ),
  ];

  Future<void> _wait() => latency > Duration.zero ? Future<void>.delayed(latency) : Future<void>.value();

  @override
  Future<PullRequestList> list(String repoPath, {bool refresh = false}) async {
    await _wait();
    return PullRequestList(provider: CiProvider.githubActions, pullRequests: [..._prs, ...created.values]);
  }

  @override
  Future<BranchPullRequest> forBranch(String worktreePath, {bool refresh = false}) async {
    await _wait();
    // Mock worktrees live at ~/wt/<repo>/<key>: the key names the branch.
    final key = worktreePath.split('/').last;
    final pr = created[worktreePath] ?? _prs.where((p) => p.branch.contains(key)).firstOrNull;
    return BranchPullRequest(provider: CiProvider.githubActions, pullRequest: pr);
  }

  @override
  Future<PullRequestInfo> create({required String worktreePath, required String title, String body = '', String base = '', bool draft = false}) async {
    await _wait();
    if (title.trim().isEmpty) throw 'A pull request needs a title';
    final pr = PullRequestInfo(
      number: 530 + created.length,
      label: '#${530 + created.length}',
      title: title.trim(),
      author: 'Mauri',
      authorIsYou: true,
      branch: worktreePath.split('/').last,
      base: base.isEmpty ? 'main' : base,
      draft: draft,
      url: 'https://github.com/pricing/price-admin/pull/${530 + created.length}',
    );
    return created[worktreePath] = pr;
  }
}
