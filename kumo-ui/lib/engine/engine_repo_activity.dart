import 'package:grpc/grpc.dart';

import '../data/models.dart';
import '../data/pipelines_source.dart';
import '../data/pull_requests_source.dart';
import '../data/repo_activity.dart';
import '../data/workspace_source.dart';
import '../platform/git_user.dart';
import 'engine_pipelines_source.dart';
import 'engine_pull_requests.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart' as pb;
import 'kumo_engine.dart';

/// One repository's activity from what `kumod` already serves:
///
/// * history: `Git.Log` on the main checkout (main only: reading every
///   branch needs a newer daemon);
/// * branches: the workspace's worktrees plus `Workspace.ListBranches`;
/// * pipelines: one `Pipelines.Watch` per local worktree, showing each
///   branch's latest run (teammates' branches without a worktree aren't
///   watched);
/// * pull requests: `PullRequests.List`, with the same tokens as pipelines.
class EngineRepoActivity extends RepoActivitySource {
  EngineRepoActivity(this._engine, this._workspace, this.repo, List<Worktree> worktrees, {PullRequestsSource? pullRequests})
      : _worktrees = [...worktrees.where((w) => w.isMain), ...worktrees.where((w) => !w.isMain)],
        provider = CiProvider.ofHost(repo.host),
        _pulls = pullRequests ?? EnginePullRequests(_engine) {
    final provider = this.provider;
    if (provider != null) {
      for (final w in _worktrees) {
        final source = EnginePipelinesSource(_engine, _workspace.absolutePathOf(w), provider: provider, branch: w.branch);
        source.addListener(_changed);
        _pipelines.add((w, source));
      }
    }
    _load();
    if (provider != null) _loadPrs();
  }

  final KumoEngine _engine;
  final WorkspaceSource _workspace;
  final PullRequestsSource _pulls;

  List<RepoPullRequest> _prs = const [];
  CiProblem? _prsProblem;
  bool _prsLoading = true;

  Future<void> _loadPrs({bool refresh = false}) async {
    PullRequestList answer;
    try {
      answer = await _pulls.list(repo.path ?? repo.id, refresh: refresh);
    } on Object catch (e) {
      answer = PullRequestList(problem: CiProblem(CiProblemKind.unreachable, detail: '$e'));
    }
    if (_disposed) return;
    _prs = [for (final p in answer.pullRequests) p.toRepo()];
    _prsProblem = answer.problem;
    _prsLoading = false;
    notifyListeners();
  }

  @override
  final Repo repo;
  @override
  final CiProvider? provider;

  /// Main checkout first.
  final List<Worktree> _worktrees;
  final List<(Worktree, PipelinesSource)> _pipelines = [];
  bool _disposed = false;

  bool _loading = true;
  String? _error;
  List<RepoCommit> _commits = const [];
  RepoBranches? _remote;

  /// Last commit of each worktree (by path).
  Map<String, RepoCommit> _tips = const {};

  /// Path of the main checkout, where `Git.Log` reads main's history.
  String get _mainPath {
    final main = _worktrees.where((w) => w.isMain).firstOrNull;
    return main == null ? (repo.path ?? repo.id) : _workspace.absolutePathOf(main);
  }

  Future<void> _load() async {
    try {
      final conn = await _engine.connection();
      // Each worktree's last commit; one that can't be read just shows none.
      final tips = Future.wait([
        for (final w in _worktrees) _log(conn, _workspace.absolutePathOf(w), 1).catchError((Object _) => const <RepoCommit>[]),
      ]);
      final commits = await _log(conn, _mainPath, 30);
      final lastOf = await tips;
      // Remote branches; null (and the workspace's error set) on failure.
      final remote = await _workspace.branches(repo);
      if (_disposed) return;
      _commits = commits;
      _tips = {
        for (var i = 0; i < _worktrees.length; i++)
          if (lastOf[i].firstOrNull case final tip?) _worktrees[i].path: tip,
      };
      _remote = remote;
      _error = null;
    } on Object catch (e) {
      if (_disposed) return;
      _error = e is GrpcError ? (e.message ?? e.codeName) : '$e';
    }
    _loading = false;
    notifyListeners();
  }

  static Future<List<RepoCommit>> _log(EngineConnection conn, String path, int limit) async {
    final log = await conn.git.log(pb.LogRequest(worktreePath: path, limit: limit));
    return [for (final c in log.commits) _commit(c)];
  }

  /// `feat: x (#518)` (squash merge) and `Merge pull request #518 from …`
  /// name the pull request they came from.
  static final _squashRef = RegExp(r'\s*\((#\d+|![0-9]+)\)$');
  static final _mergeRef = RegExp(r'^Merge (?:pull|merge) request (#\d+|![0-9]+)');

  static RepoCommit _commit(pb.Commit c) {
    var subject = c.subject;
    String? pr;
    final squash = _squashRef.firstMatch(subject);
    if (squash != null) {
      pr = squash.group(1);
      subject = subject.substring(0, squash.start);
    } else {
      pr = _mergeRef.firstMatch(subject)?.group(1);
    }
    return RepoCommit(
      sha: c.sha,
      shortSha: c.shortSha,
      subject: subject,
      author: c.author,
      time: DateTime.fromMillisecondsSinceEpoch(c.timeUnix.toInt() * 1000),
      prRef: pr,
    );
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  String get mainBranch {
    final main = _worktrees.where((w) => w.isMain).firstOrNull?.branch ?? _remote?.current ?? '';
    return main.isEmpty ? 'main' : main;
  }

  /// Your git name: commits by it are yours.
  @override
  String? get currentUser => gitUserName;
  @override
  bool get loading => _loading;
  @override
  String? get error => _error;

  @override
  List<RepoCommit> commits({bool allBranches = false}) => _commits;

  @override
  bool get allBranchesSupported => false;

  @override
  bool get prsSupported => provider != null;
  @override
  List<RepoPullRequest> get pullRequests => _prs;
  @override
  CiProblem? get prsProblem => _prsProblem;
  @override
  bool get prsLoading => _prsLoading;

  @override
  Future<void> retryPrs() => _loadPrs(refresh: true);

  @override
  bool get runsSupported => provider != null;

  @override
  List<RepoRun> get runs {
    final out = [
      for (final (w, p) in _pipelines)
        if (p.latest case final run?) _run(w, run),
    ];
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    out.sort((a, b) => (b.startedAt ?? epoch).compareTo(a.startedAt ?? epoch));
    return out;
  }

  static RepoRun _run(Worktree w, CiRun run) {
    final started = run.createdAt;
    final end = run.finishedAt ?? (run.state.finished ? null : DateTime.now());
    return RepoRun(
      branch: w.branch,
      label: run.label,
      state: run.state,
      title: run.title,
      startedAt: started,
      duration: started == null || end == null ? null : end.difference(started),
      jobs: run.jobs,
      shortSha: run.shortSha,
      url: run.url,
    );
  }

  /// The first problem worth a banner: token ones before outages. A branch
  /// that was never pushed simply has no runs.
  @override
  CiProblem? get runsProblem {
    final problems = [
      for (final (_, p) in _pipelines)
        if (p.problem case final problem? when problem.kind != CiProblemKind.notPushed) problem,
    ];
    return problems.where((p) => p.needsSettings).firstOrNull ?? problems.firstOrNull;
  }

  /// Teammates' branches without a worktree here aren't watched.
  @override
  String get runsScope => 'branches with a worktree';

  @override
  bool get runsLoading => _pipelines.any((e) => e.$2.loading);

  @override
  Future<void> retryRuns() async {
    await Future.wait([for (final (_, p) in _pipelines) p.refresh()]);
  }

  @override
  List<RepoBranch> get branches {
    final checkedOut = {for (final w in _worktrees) w.branch};
    final rows = <RepoBranch>[
      for (final w in _worktrees)
        RepoBranch(
          name: w.branch,
          worktree: w,
          isMain: w.isMain,
          localOnly: !w.everPushed,
          lastAuthor: _tips[w.path]?.author,
          lastTime: _tips[w.path]?.time,
          // Only main's distance (from its remote) is known.
          vsMain: w.isMain ? _vsRemote(w) : null,
        ),
    ];
    final seen = <String>{};
    for (final ref in _remote?.remote ?? const <String>[]) {
      final slash = ref.indexOf('/');
      final name = slash < 0 ? ref : ref.substring(slash + 1);
      if (name == 'HEAD' || name.contains(' -> ') || checkedOut.contains(name) || !seen.add(name)) continue;
      rows.add(RepoBranch(name: name));
    }
    return rows;
  }

  /// `up to date`, or `↑1 ↓2 origin`.
  static String _vsRemote(Worktree w) {
    if (!w.everPushed) return 'local only';
    final behind = int.tryParse(RegExp(r'↓(\d+)').firstMatch(w.sync)?.group(1) ?? '') ?? 0;
    final ahead = w.unpushed;
    if (ahead == 0 && behind == 0) return 'up to date';
    return [if (ahead > 0) '↑$ahead', if (behind > 0) '↓$behind', 'origin'].join(' ');
  }

  @override
  DateTime? get fetchedAt => null;
  @override
  String? get statusNote => null;

  @override
  void dispose() {
    _disposed = true;
    for (final (_, p) in _pipelines) {
      p
        ..removeListener(_changed)
        ..dispose();
    }
    super.dispose();
  }
}
