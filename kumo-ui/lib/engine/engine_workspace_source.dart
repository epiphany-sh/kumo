import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:grpc/grpc.dart';

import '../data/models.dart' as ui;
import '../data/workspace_source.dart';
import '../data/worktree_arrivals.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart';
import 'kumo_engine.dart';

/// The workspace as `kumod` streams it (`Workspace.Watch`).
class EngineWorkspaceSource extends WorkspaceSource {
  EngineWorkspaceSource(this._engine) {
    _watch();
    // The user may have run git in a terminal while the window was away.
    _lifecycle = AppLifecycleListener(onResume: refresh);
  }

  final KumoEngine _engine;
  late final AppLifecycleListener _lifecycle;
  bool _disposed = false;

  WorkspaceSnapshot? _snapshot;
  List<ui.Namespace> _namespaces = const [];
  Map<String, ui.Repo> _repos = const {};
  List<ui.RepoCandidate> _discovered = const [];
  String? _error;
  final WorktreeArrivals _arrivals = WorktreeArrivals();

  /// Displayed worktree path (`~/…`) → absolute path, for daemon calls.
  final Map<String, String> _absolute = {};

  static final String _home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';

  @override
  List<ui.Namespace> get namespaces => _namespaces;

  @override
  List<ui.Repo> get repos => [
        for (final id in {for (final n in _namespaces) ...n.repos})
          if (_repos[id] case final r?) r,
      ];

  @override
  ui.Repo? repo(String id) => _repos[id] ?? _discovered.where((c) => c.repo.id == id).map((c) => c.repo).firstOrNull;

  /// Discovered repositories plus the ones already in the workspace.
  @override
  List<ui.RepoCandidate> get candidates {
    final known = {for (final c in _discovered) c.repo.id};
    return [
      ..._discovered,
      for (final r in repos)
        if (!known.contains(r.id)) _candidate(r.id, r.name, r.host, '', r.worktrees.length),
    ];
  }

  @override
  String? get error => _error;

  @override
  bool get loaded => _snapshot != null || _error != null;

  Future<void> _watch() async {
    while (!_disposed) {
      try {
        final conn = await _engine.connection();
        await for (final snapshot in conn.workspace.watch(WatchWorkspaceRequest())) {
          if (_disposed) return;
          _apply(snapshot);
        }
      } on Object catch (e) {
        if (_disposed) return;
        // A restarting daemon ends every stream; the next one reconnects.
        if (!_engine.restarting) _fail(e);
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  void _apply(WorkspaceSnapshot snapshot) {
    _snapshot = snapshot;
    _namespaces = [
      for (final n in snapshot.namespaces) ui.Namespace(id: n.id, name: n.name, repos: List.of(n.repoPaths), collapsed: n.collapsed),
    ];
    _repos = {for (final r in snapshot.repositories) r.path: _repo(r)};
    _arrivals.update([
      for (final r in _repos.values)
        for (final w in r.worktrees) (r.id, w.branch, w.path),
    ]);
    notifyListeners();
  }

  @override
  Set<String> get arrived => _arrivals.arrived;

  @override
  void acknowledge(String path) {
    if (!_arrivals.arrived.contains(path)) return;
    _arrivals.acknowledge(path);
    notifyListeners();
  }

  /// Undo an optimistic change: back to what the daemon last said.
  void _revert() {
    final snapshot = _snapshot;
    if (snapshot != null) _apply(snapshot);
  }

  void _fail(Object error) {
    _error = error is GrpcError ? (error.message ?? error.codeName) : '$error';
    notifyListeners();
  }

  /// Runs a daemon call; on failure, reverts and reports.
  Future<void> _call(Future<void> Function(EngineConnection conn) call) async {
    try {
      _error = null;
      await call(await _engine.connection());
    } on Object catch (e) {
      _revert();
      _fail(e);
      rethrow;
    }
  }

  @override
  Future<void> discover() async {
    try {
      final conn = await _engine.connection();
      final found = await conn.workspace.discoverRepos(DiscoverReposRequest());
      _discovered = [
        for (final c in found.candidates) _candidate(c.path, c.name, _hostCode(c.host), c.fullName, c.worktreeCount),
      ];
      notifyListeners();
    } on Object catch (e) {
      _fail(e);
    }
  }

  @override
  String saveNamespace({String? id, required String name, required List<String> repos, bool collapsed = false, int? position}) {
    final nsId = id ?? _newId();
    final namespace = ui.Namespace(id: nsId, name: name.trim().isEmpty ? 'untitled' : name.trim(), repos: repos, collapsed: collapsed);
    final at = _namespaces.indexWhere((n) => n.id == nsId);
    final list = [..._namespaces];
    if (at >= 0) list.removeAt(at);
    list.insert((position ?? (at >= 0 ? at : list.length)).clamp(0, list.length), namespace);
    _namespaces = list;
    notifyListeners();

    final request = SaveNamespaceRequest(id: nsId, name: name, repoPaths: repos, collapsed: collapsed);
    if (position != null) request.position = position;
    _call((conn) => conn.workspace.saveNamespace(request)).ignore();
    return nsId;
  }

  @override
  void deleteNamespace(String id) {
    _namespaces = [for (final n in _namespaces) if (n.id != id) n];
    notifyListeners();
    _call((conn) => conn.workspace.deleteNamespace(DeleteNamespaceRequest(id: id))).ignore();
  }

  @override
  Future<void> createWorktree(ui.Repo repo, {required String branch, required bool createBranch, String base = '', String path = ''}) {
    _arrivals.expect(repo.id, branch);
    return _call((conn) => conn.workspace.createWorktree(CreateWorktreeRequest(
          repoPath: repo.id,
          branch: branch.trim(),
          createBranch: createBranch,
          base: base,
          path: path.trim(),
        ))).catchError((Object e) {
      _arrivals.forget(repo.id, branch);
      throw e;
    });
  }

  @override
  Future<WorktreeRemoval> removeWorktree(ui.Repo repo, ui.Worktree worktree, {bool force = false, bool deleteBranch = false}) async {
    var removal = const WorktreeRemoval();
    await _call((conn) async {
      final r = await conn.workspace.removeWorktree(RemoveWorktreeRequest(
        repoPath: repo.id,
        worktreePath: _absolute[worktree.path] ?? worktree.path,
        force: force,
        deleteBranch: deleteBranch,
      ));
      removal = WorktreeRemoval(removed: r.removed, changedFiles: r.changedFiles, branchKept: r.branchKept);
    });
    return removal;
  }

  @override
  void refresh() {
    if (_engine.current == null) return;
    _call((conn) => conn.workspace.refresh(RefreshWorkspaceRequest())).ignore();
  }

  @override
  String absolutePathOf(ui.Worktree worktree) => _absolute[worktree.path] ?? worktree.path;

  @override
  Future<RepoBranches?> branches(ui.Repo repo) async {
    try {
      final conn = await _engine.connection();
      final b = await conn.workspace.listBranches(ListBranchesRequest(repoPath: repo.id));
      return RepoBranches(current: b.current, local: List.of(b.local), remote: List.of(b.remote));
    } on Object catch (e) {
      _fail(e);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Mapping to the UI view-models
  // ---------------------------------------------------------------------------

  ui.Repo _repo(Repository r) => ui.Repo(
        name: r.name,
        host: _hostCode(r.host),
        path: r.path,
        worktrees: [for (final w in r.worktrees) _worktree(w)],
      );

  ui.Worktree _worktree(Worktree w) {
    final status = w.status;
    final shown = _tilde(w.path);
    _absolute[shown] = w.path;
    final changed = status.changedFiles;
    final pushed = status.upstream.isNotEmpty;
    return ui.Worktree(
      branch: w.branch.isEmpty ? 'detached @ ${w.head.length > 7 ? w.head.substring(0, 7) : w.head}' : w.branch,
      note: changed == 0 ? 'clean' : '$changed changed',
      tone: ui.WorktreeTone.idle,
      path: shown,
      sync: !pushed
          ? 'local only'
          : (status.ahead == 0 && status.behind == 0 ? 'up to date' : '↑${status.ahead} ↓${status.behind}'),
      agent: 'No agent',
      changes: changed == 0 ? 'clean' : '$changed ${changed == 1 ? 'file' : 'files'}',
      unpushed: status.ahead,
      everPushed: pushed,
      principal: w.isMain,
      changedFiles: changed,
    );
  }

  ui.RepoCandidate _candidate(String path, String name, String host, String fullName, int worktrees) => ui.RepoCandidate(
        host: host,
        fullName: fullName.isEmpty ? _tilde(path) : fullName,
        meta: '${_tilde(path)} · $worktrees ${worktrees == 1 ? 'worktree' : 'worktrees'}',
        cloned: true,
        repo: _repos[path] ?? ui.Repo(name: name, host: host, path: path, worktrees: const []),
      );

  static String _hostCode(GitHost host) => switch (host) {
        GitHost.GIT_HOST_GITHUB => 'GH',
        GitHost.GIT_HOST_GITLAB => 'GL',
        GitHost.GIT_HOST_BITBUCKET => 'BB',
        _ => 'LO',
      };

  static String _tilde(String path) => _home.isNotEmpty && path.startsWith(_home) ? '~${path.substring(_home.length)}' : path;

  static String _newId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  void dispose() {
    _disposed = true;
    _lifecycle.dispose();
    super.dispose();
  }
}
