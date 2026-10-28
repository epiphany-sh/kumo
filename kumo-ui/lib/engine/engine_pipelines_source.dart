import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

import '../data/ci_hosts_source.dart';
import '../data/pipelines_source.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart' as pb;
import 'kumo_engine.dart';

/// The pipelines of one worktree's branch as `kumod` polls them
/// (`Pipelines.Watch`). [provider] and [branch] are what the repository
/// suggests until the first snapshot says.
class EnginePipelinesSource extends PipelinesSource {
  EnginePipelinesSource(this._engine, this.worktreePath, {CiProvider? provider, String branch = ''})
      : _provider = provider,
        _branch = branch {
    _watch();
  }

  final KumoEngine _engine;
  final String worktreePath;
  bool _disposed = false;

  CiProvider? _provider;
  String _repo = '';
  String _branch;
  CiRun? _latest;
  CiProblem? _problem;
  bool _loading = true;
  DateTime? _checkedAt;
  bool _busy = false;
  String? _actionError;

  @override
  CiProvider? get provider => _provider;
  @override
  String get repo => _repo;
  @override
  String get branch => _branch;
  @override
  CiRun? get latest => _latest;
  @override
  CiProblem? get problem => _problem;
  @override
  bool get loading => _loading;
  @override
  DateTime? get checkedAt => _checkedAt;
  @override
  bool get busy => _busy;
  @override
  String? get actionError => _actionError;

  Future<pb.PipelinesClient> get _client async => (await _engine.connection()).pipelines;

  Future<void> _watch() async {
    while (!_disposed) {
      try {
        await for (final snapshot in (await _client).watch(pb.WatchPipelinesRequest(worktreePath: worktreePath))) {
          if (_disposed) return;
          _apply(snapshot);
        }
      } on Object {
        // The daemon restarted, or doesn't know the worktree yet (just
        // created): try again shortly.
        if (_disposed) return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  void _apply(pb.PipelinesSnapshot s) {
    _loading = false;
    _provider = ciProviderFrom(s.provider);
    _repo = s.repo;
    if (s.branch.isNotEmpty) _branch = s.branch;
    _latest = s.hasLatest() ? ciRunFrom(s.latest) : null;
    _problem = s.hasProblem() ? ciProblemFrom(s.problem) : null;
    _checkedAt = _time(s.checkedAt);
    notifyListeners();
  }

  /// Runs an action with [busy] on; its failure becomes [actionError].
  Future<void> _act(Future<void> Function(pb.PipelinesClient client) call) async {
    if (_busy) return;
    _busy = true;
    _actionError = null;
    notifyListeners();
    try {
      await call(await _client);
    } on Object catch (e) {
      _actionError = e is GrpcError ? (e.message ?? e.codeName) : '$e';
    }
    if (_disposed) return;
    _busy = false;
    notifyListeners();
  }

  @override
  Future<void> refresh() => _act((c) => c.refresh(pb.WorktreeRequest(worktreePath: worktreePath)));

  @override
  Future<void> rerunFailed() async {
    final run = _latest;
    if (run == null) return;
    await _act((c) => c.rerunFailed(pb.RerunFailedRequest(worktreePath: worktreePath, runId: run.id)));
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Settings › Repositories over `Pipelines.ListHosts` / `SaveHostToken` /
/// `TestHost`.
class EngineCiHostsSource implements CiHostsSource {
  EngineCiHostsSource(this._engine);
  final KumoEngine _engine;

  Future<T> _call<T>(Future<T> Function(pb.PipelinesClient client) call) async {
    try {
      return await call((await _engine.connection()).pipelines);
    } on GrpcError catch (e) {
      throw e.message ?? e.codeName;
    }
  }

  @override
  Future<List<CiHostInfo>> list() async {
    final answer = await _call((c) => c.listHosts(pb.ListHostsRequest()));
    return [for (final h in answer.hosts) if (ciHostFrom(h) case final host?) host];
  }

  @override
  Future<CiHostInfo> saveToken(String host, String token) async {
    final saved = await _call((c) => c.saveHostToken(pb.SaveHostTokenRequest(host: host, token: token)));
    return ciHostFrom(saved) ?? CiHostInfo(host: host, provider: CiProvider.githubActions);
  }

  @override
  Future<CiHostTest> test(String host, {String token = ''}) async {
    final answer = await _call((c) => c.testHost(pb.TestHostRequest(host: host, token: token)));
    return CiHostTest(message: answer.message, problem: answer.hasProblem() ? ciProblemFrom(answer.problem) : null);
  }

  @override
  Future<String> signInWithGh(String host) async => (await _call((c) => c.signInWithGh(pb.SignInWithGhRequest(host: host)))).terminalId;
}

/// Unix ms; 0 means unknown.
DateTime? _time(Int64 ms) => ms <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms.toInt());

CiProvider? ciProviderFrom(pb.CiProvider p) => switch (p) {
      pb.CiProvider.CI_PROVIDER_GITHUB_ACTIONS => CiProvider.githubActions,
      pb.CiProvider.CI_PROVIDER_GITLAB_CI => CiProvider.gitlabCi,
      pb.CiProvider.CI_PROVIDER_BITBUCKET_PIPELINES => CiProvider.bitbucketPipelines,
      _ => null,
    };

CiState ciStateFrom(pb.CiState s) => switch (s) {
      pb.CiState.CI_STATE_RUNNING => CiState.running,
      pb.CiState.CI_STATE_PASSED => CiState.passed,
      pb.CiState.CI_STATE_FAILED => CiState.failed,
      pb.CiState.CI_STATE_CANCELED => CiState.canceled,
      pb.CiState.CI_STATE_SKIPPED => CiState.skipped,
      _ => CiState.queued,
    };

CiJob ciJobFrom(pb.CiJob j) => CiJob(
      name: j.name,
      state: ciStateFrom(j.state),
      duration: j.durationMs.toInt() > 0 ? Duration(milliseconds: j.durationMs.toInt()) : null,
      startedAt: _time(j.startedAt),
      failure: j.failure.isEmpty ? null : j.failure,
      url: j.url,
    );

CiRun ciRunFrom(pb.CiRun r) => CiRun(
      id: r.id,
      label: r.label,
      shortSha: r.shortSha,
      title: r.title,
      state: ciStateFrom(r.state),
      createdAt: _time(r.createdAt),
      finishedAt: _time(r.finishedAt),
      url: r.url,
      jobs: [for (final j in r.jobs) ciJobFrom(j)],
    );

CiProblem ciProblemFrom(pb.CiProblem p) => CiProblem(
      switch (p.kind) {
        pb.CiProblemKind.CI_PROBLEM_KIND_NOT_CONNECTED => CiProblemKind.notConnected,
        pb.CiProblemKind.CI_PROBLEM_KIND_UNAUTHORIZED => CiProblemKind.unauthorized,
        pb.CiProblemKind.CI_PROBLEM_KIND_FORBIDDEN => CiProblemKind.forbidden,
        pb.CiProblemKind.CI_PROBLEM_KIND_NOT_FOUND => CiProblemKind.notFound,
        pb.CiProblemKind.CI_PROBLEM_KIND_RATE_LIMITED => CiProblemKind.rateLimited,
        pb.CiProblemKind.CI_PROBLEM_KIND_UNREACHABLE => CiProblemKind.unreachable,
        pb.CiProblemKind.CI_PROBLEM_KIND_NOT_PUSHED => CiProblemKind.notPushed,
        _ => CiProblemKind.unsupported,
      },
      detail: p.detail,
      missingScope: p.missingScope,
      retryAt: _time(p.retryAt),
      commitsWaiting: p.commitsWaiting,
    );

CiHostInfo? ciHostFrom(pb.CiHostInfo h) {
  final provider = ciProviderFrom(h.provider);
  if (provider == null) return null;
  return CiHostInfo(
    host: h.host,
    provider: provider,
    hasToken: h.hasToken,
    usesGh: h.usesGh,
    ghAccount: h.ghAccount,
    ghAvailable: h.ghAvailable,
    repos: List.of(h.repos),
  );
}
