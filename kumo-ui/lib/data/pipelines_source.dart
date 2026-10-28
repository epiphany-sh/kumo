import 'package:flutter/foundation.dart';

/// CI providers Kumo reads pipelines from, by repository host.
enum CiProvider {
  githubActions('GH', 'GitHub', 'GitHub Actions'),
  gitlabCi('GL', 'GitLab', 'GitLab CI'),
  bitbucketPipelines('BB', 'Bitbucket', 'Bitbucket Pipelines');

  const CiProvider(this.host, this.hostName, this.label);

  /// Host key as repos carry it (GH / GL / BB).
  final String host;

  /// The forge, for messages ("Your GitHub token…").
  final String hostName;

  /// The CI product, for headers and links ("Open in GitHub Actions").
  final String label;

  static CiProvider? ofHost(String host) {
    for (final p in values) {
      if (p.host == host) return p;
    }
    return null;
  }
}

/// State of a pipeline run or of one of its jobs.
enum CiState {
  queued,
  running,
  passed,
  failed,
  canceled,
  skipped;

  bool get finished => this == passed || this == failed || this == canceled || this == skipped;
}

/// One job (GitHub: job · GitLab: job · Bitbucket: step) of a run.
@immutable
class CiJob {
  const CiJob({required this.name, required this.state, this.duration, this.startedAt, this.failure, this.url = ''});
  final String name;
  final CiState state;

  /// How long it ran (finished jobs).
  final Duration? duration;

  /// When it started (running jobs show the time so far).
  final DateTime? startedAt;

  /// First meaningful line of the failure (a failing test, a lint error),
  /// for failed jobs. Empty when the provider doesn't expose it.
  final String? failure;
  final String url;
}

/// A pipeline run for the branch: the latest one is what the widget shows.
@immutable
class CiRun {
  const CiRun({
    required this.id,
    required this.label,
    required this.shortSha,
    required this.state,
    required this.jobs,
    this.title = '',
    this.createdAt,
    this.finishedAt,
    this.url = '',
  });

  /// Provider id, to re-run or cancel it.
  final String id;

  /// What the provider calls it: `run #8812`, `pipeline #4417`.
  final String label;
  final String shortSha;

  /// Commit subject it ran for.
  final String title;
  final CiState state;
  final List<CiJob> jobs;
  final DateTime? createdAt;
  final DateTime? finishedAt;
  final String url;

  int get done => jobs.where((j) => j.state.finished).length;
  bool get hasFailedJobs => jobs.any((j) => j.state == CiState.failed);
}

/// Why pipelines can't be shown. Kinds map to the provider's answer:
/// 401 → [unauthorized], 403 → [forbidden], no token → [notConnected],
/// 404 → [notFound], 429 / secondary limit → [rateLimited], timeouts and
/// 5xx → [unreachable]. [notPushed]: the branch has no upstream yet.
enum CiProblemKind { notConnected, unauthorized, forbidden, notFound, rateLimited, unreachable, notPushed, unsupported }

@immutable
class CiProblem {
  const CiProblem(this.kind, {this.detail = '', this.missingScope = '', this.retryAt, this.commitsWaiting = 0});
  final CiProblemKind kind;

  /// What the provider said, verbatim and short (`HTTP 403 · Resource not
  /// accessible by personal access token`), shown small under the message.
  final String detail;

  /// The permission the token lacks, when the provider says which
  /// (`actions:read`, `read_api`, `pipeline`).
  final String missingScope;

  /// When Kumo tries again on its own (rate limits, outages).
  final DateTime? retryAt;

  /// Local commits waiting for the first push ([CiProblemKind.notPushed]).
  final int commitsWaiting;

  /// Problems that leave the last known run on screen (marked stale).
  bool get keepsLastRun => kind == CiProblemKind.rateLimited || kind == CiProblemKind.unreachable;

  /// Problems the user fixes in Settings › Repositories.
  bool get needsSettings => kind == CiProblemKind.notConnected || kind == CiProblemKind.unauthorized || kind == CiProblemKind.forbidden;
}

/// Plain-language title and explanation for [p]; the UI shows
/// [CiProblem.detail] under them.
(String, String) describeCiProblem(CiProblem p, CiProvider provider, {String repo = ''}) {
  final host = provider.hostName;
  final where = repo.isEmpty ? 'this repository' : repo;
  return switch (p.kind) {
    CiProblemKind.notConnected => ('$host isn’t connected', 'Connect it once and this widget shows every pipeline run for the branch you’re on.'),
    CiProblemKind.unauthorized => ('Your $host token stopped working', '$host rejected it, so it probably expired or was revoked. Paste a new one in Settings and pipelines come back on their own.'),
    CiProblemKind.forbidden => (
        'Your $host token can’t read pipelines',
        'Kumo can see $where but not its ${provider.label} runs. ${_scopeHint(provider, p.missingScope)} Then retry.',
      ),
    CiProblemKind.notFound => ('${provider.label} has nothing for $where', 'Either the repository doesn’t use ${provider.label}, or the token can’t see it.'),
    CiProblemKind.rateLimited => ('$host asked Kumo to slow down', 'Too many requests for now. Showing the last status we got${_retryIn(p.retryAt)}.'),
    CiProblemKind.unreachable => ('$host isn’t answering', 'Showing the last status we got${_retryIn(p.retryAt)}, or retry now.'),
    CiProblemKind.notPushed => (
        'No pipelines yet',
        p.commitsWaiting > 0
            ? 'This branch only exists locally. ${p.commitsWaiting} ${p.commitsWaiting == 1 ? 'commit is' : 'commits are'} waiting; pipelines start after the first push.'
            : 'This branch only exists locally. Pipelines start after the first push.',
      ),
    CiProblemKind.unsupported => ('No pipelines for this host', 'Kumo reads pipelines from GitHub Actions, GitLab CI and Bitbucket Pipelines.'),
  };
}

String _scopeHint(CiProvider provider, String scope) {
  if (scope.isNotEmpty) return 'Give the token the “$scope” permission.';
  return switch (provider) {
    CiProvider.githubActions => 'Give the token read access to Actions (fine-grained) or the “repo” scope (classic).',
    CiProvider.gitlabCi => 'Give the token the “read_api” scope.',
    CiProvider.bitbucketPipelines => 'Give the token the “Pipelines: Read” permission.',
  };
}

String _retryIn(DateTime? at) {
  if (at == null) return '';
  final s = at.difference(DateTime.now()).inSeconds;
  if (s <= 0) return '; Kumo is trying again';
  return s < 90 ? '; Kumo tries again in $s s' : '; Kumo tries again in ${(s / 60).round()} min';
}

/// Pipelines of one worktree's branch on its repository's CI. The daemon
/// polls the provider with the token from Settings › Repositories and
/// streams it; [MockPipelinesSource] backs the design and tests.
abstract class PipelinesSource extends ChangeNotifier {
  /// Null when the repository's host has no supported CI.
  CiProvider? get provider;

  /// `owner/repo` on the host.
  String get repo;
  String get branch;

  /// Latest run for the branch; with a [problem] that [CiProblem.keepsLastRun]
  /// it is the last one seen (stale).
  CiRun? get latest;
  CiProblem? get problem;

  /// True until the first answer arrives.
  bool get loading;

  /// When the provider last answered.
  DateTime? get checkedAt;

  /// A refresh / re-run is in flight.
  bool get busy;

  /// Why the last action failed (re-run refused, …); the widget shows it.
  String? get actionError;

  /// Asks the provider now instead of waiting for the next poll.
  Future<void> refresh();

  /// Re-runs the failed jobs of [latest] (the whole run where the provider
  /// can't re-run single jobs).
  Future<void> rerunFailed();

  /// Called once the branch was pushed (it had no upstream before).
  void branchPushed() => refresh();
}

/// Nothing to show: no worktree selected.
class NoPipelines extends PipelinesSource {
  @override
  CiProvider? get provider => null;
  @override
  String get repo => '';
  @override
  String get branch => '';
  @override
  CiRun? get latest => null;
  @override
  CiProblem? get problem => null;
  @override
  bool get loading => false;
  @override
  DateTime? get checkedAt => null;
  @override
  bool get busy => false;
  @override
  String? get actionError => null;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> rerunFailed() async {}
}

/// Scenarios of the design mocks: the happy ones and every problem.
enum MockPipelinesScenario { running, passed, failed, notPushed, forbidden, unauthorized, notConnected, unreachable }

/// The design's pipelines: a running run (Refresh finishes it), re-runs, and
/// each problem in [MockPipelinesScenario]. Retry clears a problem as if it
/// had been fixed; a push starts the first run of a local-only branch. No
/// timers run on their own, so tests can leave it undisposed.
class MockPipelinesSource extends PipelinesSource {
  MockPipelinesSource({
    this.scenario = MockPipelinesScenario.running,
    this.provider = CiProvider.githubActions,
    this.repo = 'pricing/price-admin',
    this.branch = 'feat/PRC-412-bulk-discounts',
    this.latency = const Duration(milliseconds: 600),
    this.unpushed = 2,
  }) {
    _apply(scenario);
  }

  final MockPipelinesScenario scenario;
  @override
  final CiProvider? provider;
  @override
  final String repo;
  @override
  final String branch;

  /// How long refresh / re-run take to answer.
  final Duration latency;


  /// Local commits waiting for the first push ([MockPipelinesScenario.notPushed]).
  final int unpushed;

  CiRun? _latest;
  CiProblem? _problem;
  DateTime? _checkedAt;
  bool _busy = false;
  bool _disposed = false;

  @override
  CiRun? get latest => _latest;
  @override
  CiProblem? get problem => _problem;
  @override
  bool get loading => false;
  @override
  DateTime? get checkedAt => _checkedAt;
  @override
  bool get busy => _busy;
  @override
  String? get actionError => null;

  static const _done = [('build', 72), ('unit tests', 160), ('golangci-lint', 48)];

  CiRun _running(DateTime now, {String label = 'run #8812', String sha = '4e1b2c0'}) => CiRun(
        id: label,
        label: label,
        shortSha: sha,
        title: 'feat: BulkDiscount aggregate',
        url: _url,
        state: CiState.running,
        createdAt: now.subtract(const Duration(minutes: 9)),
        jobs: [
          for (final (n, s) in _done) CiJob(name: n, state: CiState.passed, duration: Duration(seconds: s)),
          CiJob(name: 'integration · testcontainers', state: CiState.running, startedAt: now.subtract(const Duration(seconds: 65))),
          const CiJob(name: 'deploy · staging', state: CiState.queued),
        ],
      );

  CiRun _passed(CiRun from) => CiRun(
        id: from.id,
        label: from.label,
        shortSha: from.shortSha,
        title: from.title,
        url: from.url,
        state: CiState.passed,
        createdAt: from.createdAt,
        finishedAt: DateTime.now(),
        jobs: [
          for (final (n, s) in _done) CiJob(name: n, state: CiState.passed, duration: Duration(seconds: s)),
          const CiJob(name: 'integration · testcontainers', state: CiState.passed, duration: Duration(minutes: 3, seconds: 52)),
          const CiJob(name: 'deploy · staging', state: CiState.passed, duration: Duration(seconds: 58)),
        ],
      );

  CiRun _failed(DateTime now) => CiRun(
        id: 'run #8812',
        label: 'run #8812',
        shortSha: '4e1b2c0',
        title: 'feat: BulkDiscount aggregate',
        url: _url,
        state: CiState.failed,
        createdAt: now.subtract(const Duration(minutes: 9)),
        finishedAt: now.subtract(const Duration(minutes: 4)),
        jobs: [
          for (final (n, s) in _done) CiJob(name: n, state: CiState.passed, duration: Duration(seconds: s)),
          const CiJob(
            name: 'integration · testcontainers',
            state: CiState.failed,
            duration: Duration(seconds: 82),
            failure: 'TestBulkUpsert · bulk_test.go:88 · expected 3 rows, got 2',
          ),
          const CiJob(name: 'deploy · staging', state: CiState.skipped),
        ],
      );

  void _apply(MockPipelinesScenario s) {
    final now = DateTime.now();
    _checkedAt = now.subtract(const Duration(seconds: 40));
    _problem = null;
    if (provider == null) {
      _latest = null;
      _problem = const CiProblem(CiProblemKind.unsupported);
      return;
    }
    switch (s) {
      case MockPipelinesScenario.running:
        _startRun(_running(now));
      case MockPipelinesScenario.passed:
        _latest = _passed(_running(now, label: 'run #8813', sha: '3f9c2ab'));
      case MockPipelinesScenario.failed:
        _latest = _failed(now);
      case MockPipelinesScenario.notPushed:
        _latest = null;
        _problem = CiProblem(CiProblemKind.notPushed, commitsWaiting: unpushed);
      case MockPipelinesScenario.forbidden:
        _latest = null;
        _problem = const CiProblem(CiProblemKind.forbidden, detail: 'HTTP 403 · Resource not accessible by personal access token');
      case MockPipelinesScenario.unauthorized:
        _latest = null;
        _problem = const CiProblem(CiProblemKind.unauthorized, detail: 'HTTP 401 · Bad credentials');
      case MockPipelinesScenario.notConnected:
        _latest = null;
        _problem = const CiProblem(CiProblemKind.notConnected);
      case MockPipelinesScenario.unreachable:
        _latest = _running(now);
        _checkedAt = now.subtract(const Duration(minutes: 4));
        _problem = CiProblem(CiProblemKind.unreachable, detail: 'Timed out after 10 s · api.github.com', retryAt: now.add(const Duration(seconds: 30)));
    }
  }

  void _startRun(CiRun run) => _latest = run;

  /// Where "Open in …" goes: the branch's runs on the host.
  String get _url {
    final b = Uri.encodeQueryComponent(branch);
    return switch (provider) {
      CiProvider.githubActions => 'https://github.com/$repo/actions?query=branch%3A$b',
      CiProvider.gitlabCi => 'https://gitlab.com/$repo/-/pipelines?ref=$b',
      CiProvider.bitbucketPipelines => 'https://bitbucket.org/$repo/pipelines',
      null => '',
    };
  }

  Future<void> _answer(void Function() apply) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    await Future<void>.delayed(latency);
    if (_disposed) return;
    _busy = false;
    _checkedAt = DateTime.now();
    apply();
    notifyListeners();
  }

  @override
  Future<void> refresh() => _answer(() {
        // Retry after fixing the token / the outage: the run shows up.
        final kind = _problem?.kind;
        if (kind == null) {
          // The running run has finished by the next look.
          final last = _latest;
          if (last != null && last.state == CiState.running) _latest = _passed(last);
        } else if (kind != CiProblemKind.notPushed && kind != CiProblemKind.unsupported) {
          _problem = null;
          _startRun(_running(DateTime.now()));
        }
      });

  @override
  Future<void> rerunFailed() => _answer(() {
        final last = _latest;
        if (last == null || !last.hasFailedJobs) return;
        _startRun(_running(DateTime.now(), label: 'run #8812 · attempt 2', sha: last.shortSha));
      });

  @override
  void branchPushed() {
    if (_problem?.kind != CiProblemKind.notPushed) return;
    _answer(() {
      _problem = null;
      _startRun(_running(DateTime.now(), label: 'run #1'));
    }).ignore();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
