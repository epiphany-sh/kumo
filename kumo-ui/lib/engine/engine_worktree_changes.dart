import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

import '../data/changes.dart';
import '../data/mock_project.dart';
import '../data/worktree_changes.dart' as ui;
import 'generated/kumo/v1/kumo.pbgrpc.dart' hide DiffLine;
import 'kumo_engine.dart';

/// One worktree's changes as `kumod` streams them (`Git.WatchStatus`).
/// File lists, diffs and gutter marks are fetched on demand and cached
/// until the status changes.
class EngineWorktreeChanges extends ui.WorktreeChanges {
  EngineWorktreeChanges(this._engine, this.worktree) {
    _watch();
  }

  final KumoEngine _engine;

  /// Absolute path of the worktree.
  final String worktree;

  bool _disposed = false;
  WorktreeChanges _status = WorktreeChanges();
  Map<String, FileChange> _working = const {};
  List<String> _files = const [];
  int _version = 0;
  String? _error;
  final _marks = <String, Map<int, bool>>{};

  Future<EngineConnection> get _conn => _engine.connection();

  Future<void> _watch() async {
    while (!_disposed) {
      try {
        final conn = await _conn;
        await for (final status in conn.git.watchStatus(WatchStatusRequest(worktreePath: worktree))) {
          if (_disposed) return;
          _apply(status);
          unawaited(_listFiles());
        }
      } on Object catch (e) {
        if (_disposed) return;
        _fail(e);
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  void _apply(WorktreeChanges status) {
    _status = status;
    _working = {for (final c in status.working) c.path: c};
    _version++;
    _marks.clear();
    notifyListeners();
  }

  Future<void> _listFiles() async {
    try {
      final list = await (await _conn).git.listFiles(ListFilesRequest(worktreePath: worktree));
      if (_disposed) return;
      _files = List.of(list.paths);
      notifyListeners();
    } on Object catch (e) {
      _fail(e);
    }
  }

  void _fail(Object error) {
    _error = error is GrpcError ? (error.message ?? error.codeName) : '$error';
    if (!_disposed) notifyListeners();
  }

  /// Runs a daemon action; the status stream brings the result.
  Future<bool> _act(Future<void> Function(GitClient git) action) async {
    try {
      _error = null;
      await action((await _conn).git);
      return true;
    } on Object catch (e) {
      _fail(e);
      return false;
    }
  }

  // ---- Header ----

  @override
  String get branch => _status.branch.isEmpty ? 'detached' : _status.branch;
  @override
  String get base => _status.base;
  @override
  int get ahead => _status.ahead;
  @override
  int get behind => _status.behind;
  @override
  bool get pushed => _status.upstream.isNotEmpty;
  @override
  int get version => _version;
  @override
  String? get error => _error;

  // ---- Files ----

  @override
  List<String> get files => _files;

  @override
  Future<String?> read(String path) async {
    try {
      final file = await (await _conn).git.readFile(ReadFileRequest(worktreePath: worktree, path: path));
      if (file.binary) return null;
      return utf8.decode(file.content, allowMalformed: true);
    } on GrpcError {
      // Deleted in the working tree: show the last committed version.
      final diff = await this.diff(path);
      return diff == null ? null : [for (final l in diff.lines) if (l.kind != DiffKind.added) l.text].join('\n');
    }
  }

  @override
  Future<void> write(String path, String text) =>
      _act((git) => git.writeFile(WriteFileRequest(worktreePath: worktree, path: path, content: utf8.encode(text))));

  // ---- Status ----

  static GitStatus? _statusOf(FileChange c) {
    if (c.conflict) return GitStatus.conflict;
    final kinds = {c.staged, c.unstaged};
    if (kinds.contains(ChangeKind.CHANGE_KIND_DELETED)) return GitStatus.deleted;
    if (c.unstaged == ChangeKind.CHANGE_KIND_UNTRACKED) return GitStatus.untracked;
    if (c.staged == ChangeKind.CHANGE_KIND_ADDED) return GitStatus.added;
    if (c.staged == ChangeKind.CHANGE_KIND_NONE && c.unstaged == ChangeKind.CHANGE_KIND_NONE) return null;
    return GitStatus.modified;
  }

  @override
  GitStatus? statusOf(String path) {
    final change = _working[path];
    return change == null ? null : _statusOf(change);
  }

  @override
  List<String> get changed => [for (final c in _status.working) if (_statusOf(c) != null) c.path];
  @override
  List<String> get conflicts => [for (final c in _status.working) if (c.conflict) c.path];
  @override
  List<String> get stagedList => [
        for (final c in _status.working)
          if (!c.conflict && c.staged != ChangeKind.CHANGE_KIND_NONE) c.path,
      ];
  @override
  List<String> get unstagedChanges => [
        for (final c in _status.working)
          if (!c.conflict && c.unstaged != ChangeKind.CHANGE_KIND_NONE && c.unstaged != ChangeKind.CHANGE_KIND_UNTRACKED) c.path,
      ];
  @override
  List<String> get untracked => [for (final c in _status.working) if (c.unstaged == ChangeKind.CHANGE_KIND_UNTRACKED) c.path];

  static String _letter(FileChange c) {
    final kinds = {c.staged, c.unstaged};
    if (kinds.contains(ChangeKind.CHANGE_KIND_DELETED)) return 'D';
    if (kinds.contains(ChangeKind.CHANGE_KIND_ADDED) || kinds.contains(ChangeKind.CHANGE_KIND_UNTRACKED)) return 'A';
    if (kinds.contains(ChangeKind.CHANGE_KIND_RENAMED)) return 'R';
    return 'M';
  }

  ChangedFile _changedFile(FileChange c, {required bool committed}) => ChangedFile(
        path: c.path,
        kind: _letter(c),
        lines: const [],
        committed: committed,
        addedCount: c.additions,
        deletedCount: c.deletions,
      );

  @override
  List<ChangedFile> get pending => [for (final c in _status.working) _changedFile(c, committed: false)];

  @override
  List<ChangedFile> get onBranch => [for (final c in _status.committed) _changedFile(c, committed: true)];

  @override
  Future<ChangedFile?> diff(String path) async {
    final working = _working[path];
    final committed = _status.committed.where((c) => c.path == path).firstOrNull;
    final scope = working == null && committed != null ? DiffScope.DIFF_SCOPE_COMMITTED : DiffScope.DIFF_SCOPE_WORKING;
    try {
      final diff = await (await _conn).git.diff(DiffRequest(worktreePath: worktree, path: path, scope: scope));
      final lines = [
        for (final l in diff.lines)
          DiffLine(switch (l.kind) {
            DiffLineKind.DIFF_LINE_KIND_ADDED => DiffKind.added,
            DiffLineKind.DIFF_LINE_KIND_DELETED => DiffKind.deleted,
            _ => DiffKind.context,
          }, l.text),
      ];
      final change = working ?? committed;
      return ChangedFile(path: path, kind: change == null ? 'M' : _letter(change), lines: lines, committed: working == null && committed != null);
    } on Object catch (e) {
      _fail(e);
      return null;
    }
  }

  @override
  Future<Map<int, bool>> marks(String path) async {
    final cached = _marks[path];
    if (cached != null) return cached;
    if (statusOf(path) == null) return const {};
    final file = await diff(path);
    final marks = <int, bool>{};
    var line = 0;
    var afterDeletion = false;
    for (final l in file?.lines ?? const <DiffLine>[]) {
      switch (l.kind) {
        case DiffKind.deleted:
          afterDeletion = true;
        case DiffKind.added:
          marks[++line] = !afterDeletion;
        case DiffKind.context:
          line++;
          afterDeletion = false;
      }
    }
    return _marks[path] = marks;
  }

  // ---- Actions ----

  PathsRequest _paths(String path) => PathsRequest(worktreePath: worktree, paths: [path]);

  @override
  void stage(String path) => _act((git) => git.stage(_paths(path))).ignore();

  @override
  void unstage(String path) => _act((git) => git.unstage(_paths(path))).ignore();

  @override
  Future<void> restore(String path) => _act((git) => git.restore(_paths(path)));

  @override
  Future<void> resolveConflict(String path, String keep, String text) async {
    await write(path, text);
    if (_error == null) await _act((git) => git.stage(_paths(path)));
  }

  @override
  Future<String?> commit(String message, {bool all = false, bool amend = false, bool push = false}) async {
    String? sha;
    final ok = await _act((git) async {
      sha = (await git.commit(CommitRequest(worktreePath: worktree, message: message, all: all, amend: amend))).shortSha;
      if (push) await git.push(WorktreeRequest(worktreePath: worktree));
    });
    return ok ? sha : null;
  }

  @override
  Future<void> push() => _act((git) => git.push(WorktreeRequest(worktreePath: worktree)));

  @override
  Future<void> undoLastCommit() => _act((git) => git.undoLastCommit(WorktreeRequest(worktreePath: worktree)));

  @override
  Future<List<ui.CommitInfo>?> log({int limit = 30}) async {
    try {
      final log = await (await _conn).git.log(LogRequest(worktreePath: worktree, limit: limit));
      return [
        for (final c in log.commits)
          ui.CommitInfo(
            sha: c.sha,
            shortSha: c.shortSha,
            subject: c.subject,
            author: c.author,
            time: DateTime.fromMillisecondsSinceEpoch((c.timeUnix * Int64(1000)).toInt()),
          ),
      ];
    } on Object catch (e) {
      _fail(e);
      return const [];
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
