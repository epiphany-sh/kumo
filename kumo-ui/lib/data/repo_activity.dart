/// What happened in one repository, for the Git view: main's history,
/// everyone's pull requests and pipelines, and its branches. Unlike
/// `PipelinesSource` or `WorktreeChanges`, nothing here is about the
/// worktree you're on: teammates' work is included.
library;

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'pipelines_source.dart';

/// A commit on main (or, with all branches, on any branch).
@immutable
class RepoCommit {
  const RepoCommit({required this.sha, required this.shortSha, required this.subject, required this.author, required this.time, this.branch, this.prRef});
  final String sha;
  final String shortSha;
  final String subject;

  /// Author name as git has it.
  final String author;
  final DateTime time;

  /// The branch it is on, when it isn't on main yet.
  final String? branch;

  /// The pull request it was merged from (`#518`, `!228`).
  final String? prRef;
}

/// Review state of an open pull request.
enum RepoPrState {
  draft('Draft'),
  reviewRequested('Review requested'),
  changesRequested('Changes requested'),
  ready('Ready'),
  approved('Approved');

  const RepoPrState(this.label);
  final String label;
}

/// An open pull (or merge) request of the repository.
@immutable
class RepoPullRequest {
  const RepoPullRequest({
    required this.number,
    required this.title,
    required this.author,
    required this.branch,
    required this.state,
    this.mine = false,
    this.reviewRequestedFromMe = false,
    this.checksPassed = 0,
    this.checksTotal = 0,
    this.checksState,
    this.url = '',
  });

  /// As the host shows it: `#521`, `!231`.
  final String number;
  final String title;
  final String author;
  final String branch;
  final RepoPrState state;

  /// Opened by you.
  final bool mine;

  /// Someone asked you to review it.
  final bool reviewRequestedFromMe;
  final int checksPassed;
  final int checksTotal;

  /// State of the latest run on its branch; null when nothing ran.
  final CiState? checksState;
  final String url;
}

/// The latest pipeline run of a branch.
@immutable
class RepoRun {
  const RepoRun({
    required this.branch,
    required this.label,
    required this.state,
    required this.title,
    this.author = '',
    this.startedAt,
    this.duration,
    this.jobs = const [],
    this.shortSha = '',
    this.url = '',
  });
  final String branch;

  /// What the provider calls it: `run #8814`, `pipeline #4417`.
  final String label;
  final CiState state;

  /// Commit subject it ran for.
  final String title;

  /// Who pushed it; empty when the provider doesn't say.
  final String author;
  final DateTime? startedAt;

  /// How long it took (finished) or has been running so far.
  final Duration? duration;
  final List<CiJob> jobs;
  final String shortSha;
  final String url;

  /// Identity within the repository.
  String get key => '$branch|$label';
  int get passed => jobs.where((j) => j.state == CiState.passed).length;
}

/// A branch of the repository: checked out in a worktree, or only on the
/// remote.
@immutable
class RepoBranch {
  const RepoBranch({required this.name, this.worktree, this.isMain = false, this.localOnly = false, this.lastAuthor, this.lastTime, this.vsMain});
  final String name;

  /// Where it is checked out; null for a remote-only branch.
  final Worktree? worktree;

  /// The repository's main branch (its main checkout).
  final bool isMain;

  /// Never pushed.
  final bool localOnly;

  /// Last commit; [lastTime] null with an author means no commits yet.
  final String? lastAuthor;
  final DateTime? lastTime;

  /// `↑2 ↓1` against main (for main: against its remote). Null when unknown.
  final String? vsMain;
}

/// How the host names pull requests (GitLab: merge requests).
class RepoTerms {
  const RepoTerms._(this.prs, this.prShort, this.prOne);
  final String prs;
  final String prShort;
  final String prOne;

  static RepoTerms of(String host) => host == 'GL' ? const RepoTerms._('merge requests', 'MRs', 'MR') : const RepoTerms._('pull requests', 'PRs', 'PR');
}

/// Activity of ONE repository. The Git view creates one per selected repo
/// and disposes it when the selection changes.
abstract class RepoActivitySource extends ChangeNotifier {
  Repo get repo;

  /// Name of main (what the main checkout has checked out).
  String get mainBranch;

  /// The author name that is "you", when known.
  String? get currentUser;

  /// True until the first answer arrives.
  bool get loading;

  /// Why history or branches couldn't be read.
  String? get error;

  /// Newest first. [allBranches] adds commits not on main yet.
  List<RepoCommit> commits({bool allBranches = false});

  /// Whether [commits] can include other branches.
  bool get allBranchesSupported;

  /// Whether [pullRequests] can be read at all (else the view says so).
  bool get prsSupported;
  List<RepoPullRequest> get pullRequests;

  /// Why pull requests couldn't be read (no token, no access…); null when
  /// they could.
  CiProblem? get prsProblem => null;

  /// True until the pull requests answer.
  bool get prsLoading => false;

  /// Asks the host for pull requests again (after fixing the token).
  Future<void> retryPrs() async {}

  /// The repository's CI; null when its host has none Kumo reads.
  CiProvider? get provider;

  /// Whether [runs] can be read at all.
  bool get runsSupported;

  /// Latest run per branch, newest first.
  List<RepoRun> get runs;

  /// Why (some) runs can't be read: shown once above them.
  CiProblem? get runsProblem;

  /// True while a branch's runs haven't answered yet.
  bool get runsLoading => false;

  /// Which branches [runs] covers, for the section's subtitle.
  String get runsScope => 'all branches';

  /// Asks the CI again (after fixing the token).
  Future<void> retryRuns();

  /// Worktrees (main first), then remote-only branches.
  List<RepoBranch> get branches;

  /// When remotes were last fetched; null when unknown.
  DateTime? get fetchedAt;

  /// Extra status bar note (git version, worktree root); null for none.
  String? get statusNote;
}

/// Builds the source for [repo]; [worktrees] are its visible worktrees.
typedef RepoActivityFactory = RepoActivitySource Function(Repo repo, List<Worktree> worktrees);

// ---------------------------------------------------------------------------
// Design mocks
// ---------------------------------------------------------------------------

/// The design's team activity for price-admin, price-reader-v2 and
/// users-permissions (teammates Lucía, Tomás, Valentina and Nico; Mauri is
/// "you"). Other repositories are empty. Synchronous and timer-free, so
/// widget tests can leave it to the view to dispose.
class MockRepoActivity extends RepoActivitySource {
  MockRepoActivity(this.repo, List<Worktree> worktrees, {DateTime? now}) {
    final at = now ?? DateTime.now();
    DateTime ago(int minutes) => at.subtract(Duration(minutes: minutes));
    final data = _designData[repo.name];
    _problem = data?.runsProblem;
    _fetchedAt = ago(2);

    _commits = [
      for (final (sha, subject, author, minutes, pr, branch) in data?.commits ?? const <_Commit>[])
        RepoCommit(
          sha: sha,
          shortSha: sha,
          subject: subject,
          author: author,
          time: ago(minutes),
          branch: branch.isEmpty ? null : branch,
          prRef: pr.isEmpty ? null : pr,
        ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    _runs = [
      for (final (label, branch, state, title, author, minutes, seconds, sha, jobs) in data?.runs ?? const <_Run>[])
        RepoRun(
          branch: branch,
          label: label,
          state: state,
          title: title,
          author: author,
          startedAt: ago(minutes),
          duration: seconds < 0 ? null : Duration(seconds: seconds),
          shortSha: sha,
          jobs: [
            for (final (name, jobState, jobSeconds, failure) in jobs)
              CiJob(
                name: name,
                state: jobState,
                duration: jobSeconds < 0 ? null : Duration(seconds: jobSeconds),
                failure: failure.isEmpty ? null : failure,
              ),
          ],
        ),
    ];

    _prs = [
      for (final (number, title, author, branch, state, reviewMe) in data?.prs ?? const <_Pr>[])
        _withChecks(RepoPullRequest(
          number: number,
          title: title,
          author: author,
          branch: branch,
          state: state,
          mine: author == _me,
          reviewRequestedFromMe: reviewMe,
        )),
    ];

    // Worktrees as the workspace has them (a removed one is gone, a new one
    // shows up), with the design's last commit and distance from main.
    final known = {for (final b in data?.branches ?? const <_Branch>[]) b.$1: b};
    final rows = <RepoBranch>[];
    final sorted = [...worktrees.where((w) => w.isMain), ...worktrees.where((w) => !w.isMain)];
    for (final w in sorted) {
      final b = known[w.branch];
      rows.add(RepoBranch(
        name: w.branch,
        worktree: w,
        isMain: w.isMain,
        localOnly: !w.everPushed,
        lastAuthor: b?.$2,
        lastTime: b == null || b.$3 < 0 ? null : ago(b.$3),
        vsMain: b?.$4,
      ));
    }
    final checkedOut = {for (final w in worktrees) w.branch};
    for (final (name, author, minutes, vs, path) in data?.branches ?? const <_Branch>[]) {
      if (path.isNotEmpty || checkedOut.contains(name)) continue;
      rows.add(RepoBranch(name: name, lastAuthor: author, lastTime: minutes < 0 ? null : ago(minutes), vsMain: vs));
    }
    _branches = rows;
  }

  static const _me = 'Mauri';

  @override
  final Repo repo;

  late final List<RepoCommit> _commits;
  late final List<RepoRun> _runs;
  late final List<RepoPullRequest> _prs;
  late final List<RepoBranch> _branches;
  late final CiProblem? _problem;
  late final DateTime _fetchedAt;

  /// Checks of a pull request: the latest run on its branch.
  RepoPullRequest _withChecks(RepoPullRequest p) {
    final run = _runs.where((r) => r.branch == p.branch).firstOrNull;
    if (run == null) return p;
    final failed = run.jobs.any((j) => j.state == CiState.failed);
    return RepoPullRequest(
      number: p.number,
      title: p.title,
      author: p.author,
      branch: p.branch,
      state: p.state,
      mine: p.mine,
      reviewRequestedFromMe: p.reviewRequestedFromMe,
      checksPassed: run.passed,
      checksTotal: run.jobs.length,
      checksState: failed ? CiState.failed : run.state,
      url: p.url,
    );
  }

  @override
  String get mainBranch => 'main';
  @override
  String? get currentUser => _me;
  @override
  bool get loading => false;
  @override
  String? get error => null;

  @override
  List<RepoCommit> commits({bool allBranches = false}) => allBranches ? _commits : [for (final c in _commits) if (c.branch == null) c];

  @override
  bool get allBranchesSupported => true;
  @override
  bool get prsSupported => true;
  @override
  List<RepoPullRequest> get pullRequests => _prs;
  @override
  CiProvider? get provider => CiProvider.ofHost(repo.host);
  @override
  bool get runsSupported => provider != null;
  @override
  List<RepoRun> get runs => _problem == null ? _runs : const [];
  @override
  CiProblem? get runsProblem => _problem;

  bool _disposed = false;

  /// The token isn't fixed in the mock: the problem stays.
  @override
  Future<void> retryRuns() async {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  List<RepoBranch> get branches => _branches;
  @override
  DateTime? get fetchedAt => _fetchedAt;
  @override
  String? get statusNote => 'git 2.47 · worktrees in ~/wt';
}

/// (sha, subject, author, minutes ago, PR, branch; '' = on main).
typedef _Commit = (String, String, String, int, String, String);

/// (number, title, author, branch, state, your review requested).
typedef _Pr = (String, String, String, String, RepoPrState, bool);

/// (name, state, seconds or -1, failure).
typedef _Job = (String, CiState, int, String);

/// (label, branch, state, commit subject, author, minutes ago, seconds or -1, sha, jobs).
typedef _Run = (String, String, CiState, String, String, int, int, String, List<_Job>);

/// (branch, last author, minutes ago or -1 for none, vs main, worktree path or '').
typedef _Branch = (String, String, int, String, String);

class _RepoData {
  const _RepoData({required this.commits, required this.prs, required this.runs, required this.branches, this.runsProblem});
  final List<_Commit> commits;
  final List<_Pr> prs;
  final List<_Run> runs;
  final List<_Branch> branches;
  final CiProblem? runsProblem;
}

const _designData = <String, _RepoData>{
  'price-admin': _RepoData(
    runsProblem: null,
    commits: [
      ('a3f9c12', 'feat: price history endpoint', 'Tomás', 24, '#520', ''),
      ('9d02e1f', 'fix: currency rounding in exports', 'Lucía', 132, '#518', ''),
      ('4b81d07', 'chore: bump pgx to v5.7', 'Nico', 1500, '', ''),
      ('e7c5a90', 'refactor: remove v1 price endpoints', 'Mauri', 2900, '#509', ''),
      ('1f3d6b2', 'feat: discount expiry notifications', 'Valentina', 3020, '#514', ''),
      ('8a20c4e', 'fix: nil pointer on empty price list', 'Nico', 4320, '#512', ''),
      ('63e9f1a', 'docs: rollback runbook for price imports', 'Lucía', 4520, '', ''),
      ('c0d47b8', 'feat: audit fields on price changes', 'Tomás', 5760, '#507', ''),
      ('d41f7c3', 'test: cover malformed CSV rows', 'Lucía', 2, '', 'feat/PRC-415-csv-validation'),
      ('7be2f41', 'feat: batch upsert with CopyFrom', 'Mauri', 2, '', 'feat/PRC-412-bulk-discounts'),
      ('b3e0c19', 'fix: round half-up after discount', 'Mauri', 6, '', 'fix/PRC-398-rounding'),
      ('2c9a0e5', 'feat: BulkDiscount aggregate', 'Mauri', 9, '', 'feat/PRC-412-bulk-discounts'),
      ('5e0b9a8', 'feat: block edits below minimum margin', 'Valentina', 50, '', 'feat/PRC-405-margin-guard'),
      ('91ac3e6', 'refactor: move rule evaluation to engine pkg', 'Tomás', 72, '', 'refactor/rules-engine'),
      ('b7d2e14', 'chore: bump golangci-lint to v1.61', 'Nico', 128, '', 'chore/golangci-1.61'),
      ('f08c3a7', 'refactor: extract rule interfaces', 'Tomás', 150, '', 'refactor/rules-engine'),
    ],
    prs: [
      ('#525', 'feat: validate CSV imports before apply', 'Lucía', 'feat/PRC-415-csv-validation', RepoPrState.reviewRequested, true),
      ('#524', 'chore: bump golangci-lint to v1.61', 'Nico', 'chore/golangci-1.61', RepoPrState.approved, false),
      ('#523', 'feat: margin guardrails on price edits', 'Valentina', 'feat/PRC-405-margin-guard', RepoPrState.reviewRequested, true),
      ('#521', 'feat: bulk discounts by category', 'Mauri', 'feat/PRC-412-bulk-discounts', RepoPrState.draft, false),
      ('#517', 'refactor: split pricing rules engine', 'Tomás', 'refactor/rules-engine', RepoPrState.changesRequested, false),
    ],
    runs: [
      ('run #8816', 'feat/PRC-415-csv-validation', CiState.queued, 'test: cover malformed CSV rows', 'Lucía', 1, -1, 'd41f7c3', [
        ('build', CiState.queued, -1, ''),
        ('golangci-lint', CiState.queued, -1, ''),
        ('unit tests', CiState.queued, -1, ''),
        ('integration · testcontainers', CiState.queued, -1, ''),
      ]),
      ('run #8815', 'feat/PRC-412-bulk-discounts', CiState.running, 'feat: batch upsert with CopyFrom', 'Mauri', 1, 65, '7be2f41', [
        ('build', CiState.passed, 41, ''),
        ('golangci-lint', CiState.passed, 24, ''),
        ('unit tests', CiState.running, -1, ''),
        ('integration · testcontainers', CiState.queued, -1, ''),
      ]),
      ('run #8814', 'main', CiState.failed, 'feat: price history endpoint', 'Tomás', 22, 372, 'a3f9c12', [
        ('build', CiState.passed, 69, ''),
        ('golangci-lint', CiState.passed, 46, ''),
        ('unit tests', CiState.passed, 153, ''),
        ('integration · testcontainers', CiState.failed, 104, 'TestPriceHistory/range_query: expected 12 rows, got 0'),
        ('deploy to staging', CiState.skipped, -1, ''),
      ]),
      ('run #8813', 'feat/PRC-405-margin-guard', CiState.passed, 'feat: block edits below minimum margin', 'Valentina', 48, 348, '5e0b9a8', [
        ('build', CiState.passed, 66, ''),
        ('golangci-lint', CiState.passed, 44, ''),
        ('unit tests', CiState.passed, 139, ''),
        ('integration · testcontainers', CiState.passed, 99, ''),
      ]),
      ('run #8811', 'refactor/rules-engine', CiState.failed, 'refactor: move rule evaluation to engine pkg', 'Tomás', 70, 178, '91ac3e6', [
        ('build', CiState.passed, 71, ''),
        ('golangci-lint', CiState.passed, 47, ''),
        ('unit tests', CiState.failed, 60, 'rules_test.go:88: TestStackedDiscounts want 18.50, got 18.49'),
        ('integration · testcontainers', CiState.skipped, -1, ''),
      ]),
      ('run #8810', 'chore/golangci-1.61', CiState.passed, 'chore: bump golangci-lint to v1.61', 'Nico', 125, 331, 'b7d2e14', [
        ('build', CiState.passed, 64, ''),
        ('golangci-lint', CiState.passed, 52, ''),
        ('unit tests', CiState.passed, 141, ''),
        ('integration · testcontainers', CiState.passed, 74, ''),
      ]),
      ('run #8809', 'main', CiState.passed, 'fix: currency rounding in exports', 'Lucía', 130, 589, '9d02e1f', [
        ('build', CiState.passed, 68, ''),
        ('golangci-lint', CiState.passed, 45, ''),
        ('unit tests', CiState.passed, 151, ''),
        ('integration · testcontainers', CiState.passed, 238, ''),
        ('deploy to staging', CiState.passed, 87, ''),
      ]),
    ],
    branches: [
      ('main', 'Tomás', 24, 'up to date', '~/dev/price-admin'),
      ('feat/PRC-412-bulk-discounts', 'Mauri', 2, '↑2 ↓1', '~/wt/price-admin/PRC-412'),
      ('fix/PRC-398-rounding', 'Mauri', 6, '↑1 ↓1', '~/wt/price-admin/PRC-398'),
      ('feat/PRC-415-csv-validation', 'Lucía', 2, '↑1 ↓0', ''),
      ('feat/PRC-405-margin-guard', 'Valentina', 50, '↑1 ↓1', ''),
      ('refactor/rules-engine', 'Tomás', 72, '↑2 ↓2', ''),
      ('chore/golangci-1.61', 'Nico', 128, '↑1 ↓2', ''),
    ],
  ),
  'price-reader-v2': _RepoData(
    runsProblem: null,
    commits: [
      ('4c2a9e7', 'fix: log cache misses at debug level', 'Tomás', 35, '!232', ''),
      ('77be019', 'fix: stale cache TTL on SKU updates', 'Nico', 1500, '!228', ''),
      ('3e8a5d1', 'feat: read-through cache for promo prices', 'Valentina', 1700, '!226', ''),
      ('b90c2f4', 'chore: move to Go 1.23', 'Tomás', 2900, '', ''),
      ('0d6e7a3', 'perf: batch Mongo lookups for price lists', 'Lucía', 4400, '!224', ''),
      ('5f1b8c9', 'fix: handle missing currency on legacy SKUs', 'Mauri', 5760, '!221', ''),
      ('a2e4d70', 'feat: expose p95 latency metric', 'Nico', 7200, '!219', ''),
      ('9c3f0b1', 'test: contract tests for price-admin events', 'Lucía', 8640, '!217', ''),
      ('6d0f2b8', 'feat: per-tenant cache namespaces', 'Valentina', 5, '', 'feat/tenant-cache'),
      ('a81c3d2', 'perf: warm cache on deploy', 'Mauri', 39, '', 'perf/cache-warmup'),
      ('2b7e9c4', 'fix: retry with jittered backoff', 'Lucía', 182, '', 'fix/consumer-backoff'),
      ('0e4d1a7', 'wip: kafka consumer backoff', 'Lucía', 252, '', 'fix/consumer-backoff'),
    ],
    prs: [
      ('!233', 'feat: per-tenant cache namespaces', 'Valentina', 'feat/tenant-cache', RepoPrState.draft, false),
      ('!231', 'perf: warm cache on deploy', 'Mauri', 'perf/cache-warmup', RepoPrState.ready, false),
      ('!230', 'fix: consumer backoff on rebalance', 'Lucía', 'fix/consumer-backoff', RepoPrState.reviewRequested, true),
    ],
    runs: [
      ('pipeline #4421', 'feat/tenant-cache', CiState.running, 'feat: per-tenant cache namespaces', 'Valentina', 4, 220, '6d0f2b8', [
        ('build:amd64', CiState.passed, 52, ''),
        ('build:arm64', CiState.passed, 64, ''),
        ('unit tests', CiState.passed, 91, ''),
        ('race tests', CiState.passed, 72, ''),
        ('golangci-lint', CiState.passed, 38, ''),
        ('gosec', CiState.passed, 21, ''),
        ('integration · redis', CiState.running, -1, ''),
        ('integration · mongo', CiState.running, -1, ''),
        ('contract tests', CiState.queued, -1, ''),
        ('docker image', CiState.queued, -1, ''),
        ('deploy to staging', CiState.queued, -1, ''),
        ('smoke tests', CiState.queued, -1, ''),
      ]),
      ('pipeline #4419', 'main', CiState.passed, 'fix: log cache misses at debug level', 'Tomás', 33, 422, '4c2a9e7', [
        ('build:amd64', CiState.passed, 49, ''),
        ('build:arm64', CiState.passed, 61, ''),
        ('unit tests', CiState.passed, 88, ''),
        ('race tests', CiState.passed, 75, ''),
        ('golangci-lint', CiState.passed, 36, ''),
        ('gosec', CiState.passed, 19, ''),
        ('integration · redis', CiState.passed, 102, ''),
        ('integration · mongo', CiState.passed, 115, ''),
        ('contract tests', CiState.passed, 58, ''),
        ('docker image', CiState.passed, 47, ''),
        ('deploy to staging', CiState.passed, 81, ''),
        ('smoke tests', CiState.passed, 34, ''),
      ]),
      ('pipeline #4417', 'perf/cache-warmup', CiState.passed, 'perf: warm cache on deploy', 'Mauri', 38, 566, 'a81c3d2', [
        ('build:amd64', CiState.passed, 72, ''),
        ('build:arm64', CiState.passed, 80, ''),
        ('unit tests', CiState.passed, 160, ''),
        ('race tests', CiState.passed, 118, ''),
        ('golangci-lint', CiState.passed, 48, ''),
        ('gosec', CiState.passed, 22, ''),
        ('integration · redis', CiState.passed, 125, ''),
        ('integration · mongo', CiState.passed, 131, ''),
        ('contract tests', CiState.passed, 62, ''),
        ('docker image', CiState.passed, 51, ''),
        ('deploy to staging', CiState.passed, 91, ''),
        ('smoke tests', CiState.passed, 40, ''),
      ]),
      ('pipeline #4412', 'fix/consumer-backoff', CiState.passed, 'fix: retry with jittered backoff', 'Lucía', 180, 492, '2b7e9c4', [
        ('build:amd64', CiState.passed, 50, ''),
        ('build:arm64', CiState.passed, 63, ''),
        ('unit tests', CiState.passed, 107, ''),
        ('race tests', CiState.passed, 93, ''),
        ('golangci-lint', CiState.passed, 39, ''),
        ('gosec', CiState.passed, 20, ''),
        ('integration · redis', CiState.passed, 109, ''),
        ('integration · mongo', CiState.passed, 122, ''),
        ('contract tests', CiState.passed, 65, ''),
        ('docker image', CiState.passed, 49, ''),
        ('deploy to staging', CiState.passed, 86, ''),
        ('smoke tests', CiState.passed, 37, ''),
      ]),
      ('pipeline #4409', 'fix/consumer-backoff', CiState.failed, 'wip: kafka consumer backoff', 'Lucía', 250, 167, '0e4d1a7', [
        ('build:amd64', CiState.passed, 51, ''),
        ('build:arm64', CiState.passed, 62, ''),
        ('unit tests', CiState.failed, 104, 'consumer_test.go:142: TestRebalance timed out after 30s'),
        ('race tests', CiState.passed, 81, ''),
        ('golangci-lint', CiState.passed, 37, ''),
        ('gosec', CiState.passed, 20, ''),
        ('integration · redis', CiState.skipped, -1, ''),
        ('integration · mongo', CiState.skipped, -1, ''),
        ('contract tests', CiState.skipped, -1, ''),
        ('docker image', CiState.skipped, -1, ''),
        ('deploy to staging', CiState.skipped, -1, ''),
        ('smoke tests', CiState.skipped, -1, ''),
      ]),
      ('pipeline #4402', 'main', CiState.passed, 'fix: stale cache TTL on SKU updates', 'Nico', 1490, 435, '77be019', [
        ('build:amd64', CiState.passed, 50, ''),
        ('build:arm64', CiState.passed, 62, ''),
        ('unit tests', CiState.passed, 90, ''),
        ('race tests', CiState.passed, 74, ''),
        ('golangci-lint', CiState.passed, 37, ''),
        ('gosec', CiState.passed, 19, ''),
        ('integration · redis', CiState.passed, 104, ''),
        ('integration · mongo', CiState.passed, 118, ''),
        ('contract tests', CiState.passed, 57, ''),
        ('docker image', CiState.passed, 46, ''),
        ('deploy to staging', CiState.passed, 84, ''),
        ('smoke tests', CiState.passed, 35, ''),
      ]),
    ],
    branches: [
      ('main', 'Tomás', 35, '↓1 origin', '~/dev/price-reader-v2'),
      ('perf/cache-warmup', 'Mauri', 39, '↑1 ↓1', '~/wt/price-reader-v2/cache'),
      ('feat/tenant-cache', 'Valentina', 5, '↑1 ↓0', ''),
      ('fix/consumer-backoff', 'Lucía', 182, '↑2 ↓1', ''),
    ],
  ),
  'users-permissions': _RepoData(
    runsProblem: CiProblem(CiProblemKind.forbidden, detail: 'HTTP 403 · Insufficient scope'),
    commits: [
      ('c6a03e9', 'feat: role templates', 'Lucía', 1560, '#64', ''),
      ('4f7a1c0', 'fix: invalidate scope cache on role change', 'Valentina', 4320, '#61', ''),
      ('2d9e6b3', 'feat: SCIM group sync', 'Tomás', 5760, '#60', ''),
      ('8b1c5f7', 'chore: rotate test fixture keys', 'Nico', 7200, '', ''),
      ('7e2d4a1', 'fix: deny by default on unknown scopes', 'Mauri', 8640, '#57', ''),
      ('0a9f3c8', 'feat: batch permission checks', 'Valentina', 11520, '#55', ''),
      ('5b6e1d2', 'docs: document role inheritance', 'Lucía', 12960, '', ''),
      ('f3c8b09', 'test: fuzz the scope parser', 'Tomás', 23040, '#52', ''),
      ('1e5b7c2', 'chore: move to Go 1.23', 'Nico', 2880, '', 'chore/go-1.23'),
    ],
    prs: [
    ],
    runs: [
    ],
    branches: [
      ('main', 'Lucía', 1560, 'up to date', '~/dev/users-permissions'),
      ('feat/audit-log', 'Mauri', -1, '↑0 ↓0', '~/wt/users-permissions/audit'),
      ('chore/go-1.23', 'Nico', 2880, '↑1 ↓1', ''),
    ],
  ),
};
