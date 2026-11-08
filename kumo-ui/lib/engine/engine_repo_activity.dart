import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

import '../data/models.dart';
import '../data/pipelines_source.dart';
import '../data/pull_requests_source.dart';
import '../data/repo_activity.dart';
import '../data/repo_history.dart';
import '../data/workspace_source.dart';
import '../platform/git_user.dart';
import 'engine_pipelines_source.dart';
import 'engine_pull_requests.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart' as pb;
import 'kumo_engine.dart';

/// One repository's activity from what `kumod` serves:
///
/// * history: `Git.Log` on the main checkout, every branch included, and
///   `Git.ShowCommit` for what a commit changed;
/// * branches: the workspace's worktrees plus `Workspace.ListBranches`;
/// * pipelines: one `Pipelines.Watch` per local worktree, showing each
///   branch's latest run (teammates' branches without a worktree aren't
///   watched);
/// * pull requests: `PullRequests.List`, with the same tokens as pipelines,
///   and their review threads (`Threads` / `AnswerThread`);
/// * releases and tags: `Releases`, loaded and refreshed with the PRs.
///
/// An older daemon answers what it has: each feature turns off (the view
/// keeps its "update kumod" notes) once a call comes back UNIMPLEMENTED.
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
    _loadReleases();
  }

  final KumoEngine _engine;
  final WorkspaceSource _workspace;
  final PullRequestsSource _pulls;

  List<RepoPullRequest> _prs = const [];
  CiProblem? _prsProblem;
  CiProblem? _releasesProblem;
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
  bool get prsEditable => _pulls.canEdit;

  @override
  Future<void> editPr(RepoPullRequest pr, {String? title, String? body, bool? draft}) async {
    await _pulls.edit(repoPath: repo.path ?? repo.id, number: pr.id, title: title, body: body, draft: draft);
    if (!_disposed) await _loadPrs(refresh: true);
  }

  /// The repository's main checkout, as the daemon's repo-wide calls take it.
  String get _repoPath => repo.path ?? repo.id;

  /// A readable message from a daemon error.
  static String _say(Object e) => e is GrpcError ? (e.message ?? e.codeName) : '$e';

  // ---- History: every branch, and what a commit changed ----

  /// Whether the daemon has `Git.ShowCommit` (and with it every branch's
  /// log and review threads); null until asked.
  bool? _newer;

  /// An older daemon ignores `all_branches` rather than refusing it: ask
  /// for something only a newer one has. An empty sha is refused before
  /// git runs.
  Future<bool> _probe(EngineConnection conn) async {
    try {
      await conn.git.showCommit(pb.ShowCommitRequest(worktreePath: _mainPath, sha: ''));
      return true;
    } on GrpcError catch (e) {
      return e.code != StatusCode.unimplemented;
    }
  }

  @override
  bool get commitDetailsSupported => _newer ?? false;

  @override
  Future<CommitDetail> commitDetail(RepoCommit commit) async {
    final pb.CommitDetail d;
    try {
      d = await (await _engine.connection()).git.showCommit(pb.ShowCommitRequest(worktreePath: _mainPath, sha: commit.sha));
    } on GrpcError catch (e) {
      if (e.code == StatusCode.unimplemented) throw 'Kumo’s engine can’t read a commit’s changes yet: update kumod';
      throw _say(e);
    }
    return CommitDetail(
      sha: d.sha,
      body: d.body,
      parents: d.parents,
      time: d.timeUnix == 0 ? null : DateTime.fromMillisecondsSinceEpoch(d.timeUnix.toInt() * 1000),
      files: [for (final f in d.files) _file(f)],
    );
  }

  static CommitFile _file(pb.CommitFile f) => CommitFile(
        path: f.path,
        oldPath: f.oldPath.isEmpty ? null : f.oldPath,
        kind: switch (f.kind) {
          pb.ChangeKind.CHANGE_KIND_ADDED => CommitFileKind.added,
          pb.ChangeKind.CHANGE_KIND_DELETED => CommitFileKind.deleted,
          pb.ChangeKind.CHANGE_KIND_RENAMED => CommitFileKind.renamed,
          _ => CommitFileKind.modified,
        },
        binary: f.binary,
        cut: f.cut,
        added: f.added,
        deleted: f.deleted,
        hunks: [
          for (final h in f.hunks)
            // Numbered the way DiffHunk.parse does, from where it starts.
            DiffHunk.parse(
              h.oldStart,
              h.newStart,
              [
                for (final l in h.lines)
                  switch (l.kind) {
                    pb.DiffLineKind.DIFF_LINE_KIND_ADDED => '+${l.text}',
                    pb.DiffLineKind.DIFF_LINE_KIND_DELETED => '-${l.text}',
                    _ => ' ${l.text}',
                  },
              ],
              section: h.section,
            ),
        ],
      );

  // ---- Releases and tags ----

  /// Null until `Releases.List` answers; false when the daemon has none.
  bool? _releasesSupported;
  bool _releasesLoading = true;
  List<RepoRelease> _releases = const [];
  int _olderReleases = 0;

  Future<void> _loadReleases({bool refresh = false}) async {
    try {
      final conn = await _engine.connection();
      final list = await conn.releases.list(pb.ListReleasesRequest(repoPath: _repoPath, refresh: refresh));
      if (_disposed) return;
      _releases = [for (final r in list.releases) _release(r)];
      _olderReleases = list.older;
      _releasesSupported = true;
      _releasesProblem = list.hasProblem() ? ciProblemFrom(list.problem) : null;
    } on GrpcError catch (e) {
      if (_disposed) return;
      if (e.code == StatusCode.unimplemented) {
        _releasesSupported = false;
      } else {
        _releasesProblem = CiProblem(CiProblemKind.unreachable, detail: e.message ?? e.codeName);
      }
    } on Object catch (e) {
      if (_disposed) return;
      _releasesProblem = CiProblem(CiProblemKind.unreachable, detail: '$e');
    }
    _releasesLoading = false;
    notifyListeners();
  }

  static RepoRelease _release(pb.Release r) => RepoRelease(
        tag: r.tag,
        kind: switch (r.kind) {
          pb.ReleaseKind.RELEASE_KIND_PRE_RELEASE => ReleaseKind.preRelease,
          pb.ReleaseKind.RELEASE_KIND_DRAFT => ReleaseKind.draft,
          pb.ReleaseKind.RELEASE_KIND_TAG_ONLY => ReleaseKind.tagOnly,
          _ => ReleaseKind.release,
        },
        time: DateTime.fromMillisecondsSinceEpoch(r.timeUnix.toInt() * 1000),
        name: r.name,
        notes: r.notes,
        author: r.author.isEmpty ? null : r.author,
        sha: r.sha.length > 7 ? r.sha.substring(0, 7) : r.sha,
        url: r.url,
        checks: !r.hasChecks()
            ? null
            : switch (r.checks) {
                pb.CiState.CI_STATE_PASSED => true,
                pb.CiState.CI_STATE_FAILED => false,
                _ => null,
              },
        assets: [for (final a in r.assets) (a.name, _size(a.size))],
      );

  /// `1.4 MB`; empty when the host didn't say.
  static String _size(Int64 bytes) {
    final b = bytes.toInt();
    if (b <= 0) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  bool get releasesSupported => _releasesSupported ?? true;
  @override
  bool get releasesLoading => _releasesLoading;
  @override
  List<RepoRelease> get releases => _releases;
  @override
  int get olderReleases => _olderReleases;

  @override
  Future<ReleaseRange> releaseRange(RepoRelease release, {RepoRelease? since}) async {
    final pb.ReleaseRange r;
    try {
      r = await (await _engine.connection()).releases.range(pb.ReleaseRangeRequest(repoPath: _repoPath, tag: release.tag, since: since?.tag ?? ''));
    } on GrpcError catch (e) {
      if (e.code == StatusCode.unimplemented) throw 'Kumo’s engine can’t compare tags yet: update kumod';
      throw _say(e);
    }
    return ReleaseRange(
      since: r.since.isEmpty ? null : r.since,
      commits: r.commits,
      added: r.added,
      deleted: r.deleted,
      files: r.files,
      prs: [for (final p in r.prs) (p.ref, p.title, p.author, p.ticket.isEmpty ? null : p.ticket)],
    );
  }

  /// Bitbucket has tags but no releases; a host Kumo doesn't know, neither.
  @override
  bool get releasesEditable => releasesSupported && provider != null && repo.host != 'BB';

  @override
  Future<void> editRelease(RepoRelease release, {String? name, String? notes, bool publish = false}) async {
    try {
      final request = pb.EditReleaseRequest(repoPath: _repoPath, tag: release.tag, publish: publish);
      if (name != null) request.name = name;
      if (notes != null) request.notes = notes;
      await (await _engine.connection()).releases.edit(request);
    } on GrpcError catch (e) {
      throw _say(e);
    }
    if (!_disposed) await _loadReleases(refresh: true);
  }

  // ---- Review threads ----

  /// Set when `Threads` came back UNIMPLEMENTED.
  bool _threadsMissing = false;

  @override
  bool get threadsSupported => (_newer ?? false) && !_threadsMissing;

  @override
  int? openThreadsOf(RepoPullRequest pr) => pr.openThreads;

  @override
  Future<List<ReviewThread>> reviewThreads(RepoPullRequest pr) async {
    final pb.ThreadList list;
    try {
      list = await (await _engine.connection()).pulls.threads(pb.PullRequestThreadsRequest(repoPath: _repoPath, number: Int64(pr.id)));
    } on GrpcError catch (e) {
      if (e.code == StatusCode.unimplemented) {
        _threadsMissing = true;
        if (!_disposed) notifyListeners();
        return const [];
      }
      throw _say(e);
    }
    return [
      for (final t in list.threads)
        ReviewThread(
          id: t.id,
          author: t.author,
          path: t.path,
          line: t.line == 0 ? null : t.line,
          body: t.body,
          time: DateTime.fromMillisecondsSinceEpoch(t.timeUnix.toInt() * 1000),
          resolved: t.resolved,
        ),
    ];
  }

  @override
  bool get threadsWritable => threadsSupported;

  @override
  Future<void> answerThread(RepoPullRequest pr, ReviewThread thread, {String reply = '', bool resolve = false}) async {
    try {
      await (await _engine.connection()).pulls.answerThread(
            pb.AnswerThreadRequest(repoPath: _repoPath, number: Int64(pr.id), threadId: thread.id, reply: reply, resolve: resolve),
          );
    } on GrpcError catch (e) {
      throw _say(e);
    }
    if (!_disposed) await _loadPrs(refresh: true);
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
      // Main plus every other branch's commits not on it yet (an older
      // daemon sends main's alone).
      final commits = await _log(conn, _mainPath, 30, allBranches: true);
      final newer = await _probe(conn);
      final lastOf = await tips;
      // Remote branches; null (and the workspace's error set) on failure.
      final remote = await _workspace.branches(repo);
      if (_disposed) return;
      _commits = commits;
      _newer = newer;
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

  static Future<List<RepoCommit>> _log(EngineConnection conn, String path, int limit, {bool allBranches = false}) async {
    final log = await conn.git.log(pb.LogRequest(worktreePath: path, limit: limit, allBranches: allBranches));
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
      branch: c.branch.isEmpty ? null : c.branch,
      // The daemon also reads GitLab's `See merge request` from the body.
      prRef: c.prRef.isEmpty ? pr : c.prRef,
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
  List<RepoCommit> commits({bool allBranches = false}) => allBranches ? _commits : [for (final c in _commits) if (c.branch == null) c];

  @override
  bool get allBranchesSupported => _newer ?? false;

  @override
  bool get prsSupported => provider != null;
  @override
  List<RepoPullRequest> get pullRequests => _prs;
  @override
  CiProblem? get prsProblem => _prsProblem;
  @override
  CiProblem? get releasesProblem => _releasesProblem;
  @override
  bool get prsLoading => _prsLoading;

  /// Asks the host again, releases included.
  @override
  Future<void> retryPrs() => Future.wait([_loadPrs(refresh: true), _loadReleases(refresh: true)]);

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
