import 'dart:async';

import 'package:grpc/grpc.dart';

import '../data/models.dart';
import '../data/tasks_source.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart' as pb;
import 'kumo_engine.dart';

/// Tasks as `kumod` serves them: the board streamed (`Tasks.Watch`), only
/// the task lists that changed in each update.
class EngineTasksSource extends TasksSource {
  EngineTasksSource(this._engine) {
    _watch();
  }

  final KumoEngine _engine;
  bool _disposed = false;
  List<TaskSourceInfo> _sources = const [];
  final _lists = <String, List<TaskEntry>>{};
  List<TaskEntry> _tasks = const [];
  List<TaskLinkInfo> _links = const [];
  String? _error;

  /// Moves shown before the daemon confirms them: task id → column.
  final _pending = <String, TaskColumn>{};

  @override
  bool get live => true;
  @override
  List<TaskSourceInfo> get sources => _sources;
  @override
  List<TaskEntry> get tasks => _tasks;
  @override
  List<TaskLinkInfo> get links => _links;
  @override
  String? get error => _error;

  Future<pb.TasksClient> get _client async => (await _engine.connection()).tasks;

  Future<void> _watch() async {
    while (!_disposed) {
      try {
        // A new stream starts with every list.
        _lists.clear();
        await for (final update in (await _client).watch(pb.WatchTasksRequest())) {
          if (_disposed) return;
          _apply(update);
        }
      } on Object catch (e) {
        if (_disposed) return;
        _fail(e);
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  void _apply(pb.TasksUpdate update) {
    _sources = [for (final s in update.sources) _source(s)];
    final kinds = {for (final s in _sources) s.id: s.kind};
    _lists.removeWhere((id, _) => !kinds.containsKey(id));
    for (final changed in update.changed) {
      final kind = kinds[changed.sourceId] ?? TaskSourceKind.obsidian;
      _lists[changed.sourceId] = [for (final t in changed.tasks) _task(t, kind)];
    }
    _rebuild();
    _links = [for (final l in update.links) TaskLinkInfo(taskId: l.taskId, worktreePath: l.worktreePath, branch: l.branch)];
    notifyListeners();
  }

  void _rebuild() {
    _tasks = [
      for (final s in _sources)
        for (final t in _lists[s.id] ?? const <TaskEntry>[])
          if (_pending[t.id] case final column?) t.withColumn(column) else t,
    ];
  }

  void _fail(Object error) {
    _error = _message(error);
    if (!_disposed) notifyListeners();
  }

  static String _message(Object error) => error is GrpcError ? (error.message ?? error.codeName) : '$error';

  /// Runs a call; failures come back as a readable message.
  Future<T> _call<T>(Future<T> Function(pb.TasksClient client) call) async {
    try {
      final result = await call(await _client);
      _error = null;
      return result;
    } on Object catch (e) {
      throw _message(e);
    }
  }

  @override
  Future<List<DetectedSourceInfo>> detect() async {
    final found = await _call((c) => c.detect(pb.DetectSourcesRequest()));
    return [
      for (final d in found.sources)
        if (_kindOf(d.kind) case final kind?) DetectedSourceInfo(kind: kind, name: d.name, options: Map.of(d.options)),
    ];
  }

  @override
  Future<String> test({String? id, required TaskSourceKind kind, required Map<String, String> options, String secret = ''}) async =>
      (await _call((c) => c.testSource(pb.TestSourceRequest(id: id ?? '', kind: _kind(kind), options: options.entries, secret: secret)))).message;

  @override
  Future<TaskSourceInfo> saveSource({String? id, required TaskSourceKind kind, String name = '', required Map<String, String> options, bool enabled = true, String secret = ''}) async {
    final saved = await _call((c) => c.saveSource(pb.SaveSourceRequest(
          id: id ?? '',
          kind: _kind(kind),
          name: name,
          options: options.entries,
          enabled: enabled,
          secret: secret,
        )));
    return _source(saved);
  }

  @override
  Future<void> deleteSource(String id) => _call((c) => c.deleteSource(pb.DeleteSourceRequest(id: id)));

  @override
  Future<void> sync([String? id]) async {
    try {
      await _call((c) => c.sync(pb.SyncTasksRequest(sourceId: id ?? '')));
    } on String catch (e) {
      _fail(e);
    }
  }

  @override
  Future<bool> setStatus(String taskId, TaskColumn column) async {
    _pending[taskId] = column;
    _rebuild();
    notifyListeners();
    try {
      await _call((c) => c.setStatus(pb.SetTaskStatusRequest(taskId: taskId, status: _status(column))));
      return true;
    } on String catch (e) {
      _fail(e);
      return false;
    } finally {
      // The daemon's push now carries the truth (moved, or back).
      _pending.remove(taskId);
      _rebuild();
      if (!_disposed) notifyListeners();
    }
  }

  @override
  Future<void> link(String taskId, {required String worktreePath, required String branch}) async {
    try {
      await _call((c) => c.link(pb.LinkTaskRequest(taskId: taskId, worktreePath: worktreePath, branch: branch)));
    } on String catch (e) {
      _fail(e);
    }
  }

  @override
  Future<void> unlink(String taskId, String worktreePath) async {
    try {
      await _call((c) => c.unlink(pb.UnlinkTaskRequest(taskId: taskId, worktreePath: worktreePath)));
    } on String catch (e) {
      _fail(e);
    }
  }

  static TaskSourceKind? _kindOf(pb.TaskSourceKind kind) => switch (kind) {
        pb.TaskSourceKind.TASK_SOURCE_KIND_OBSIDIAN => TaskSourceKind.obsidian,
        pb.TaskSourceKind.TASK_SOURCE_KIND_BEAR => TaskSourceKind.bear,
        pb.TaskSourceKind.TASK_SOURCE_KIND_GITHUB => TaskSourceKind.github,
        pb.TaskSourceKind.TASK_SOURCE_KIND_JIRA => TaskSourceKind.jira,
        pb.TaskSourceKind.TASK_SOURCE_KIND_TODOIST => TaskSourceKind.todoist,
        _ => null,
      };

  static pb.TaskSourceKind _kind(TaskSourceKind kind) => switch (kind) {
        TaskSourceKind.obsidian => pb.TaskSourceKind.TASK_SOURCE_KIND_OBSIDIAN,
        TaskSourceKind.bear => pb.TaskSourceKind.TASK_SOURCE_KIND_BEAR,
        TaskSourceKind.github => pb.TaskSourceKind.TASK_SOURCE_KIND_GITHUB,
        TaskSourceKind.jira => pb.TaskSourceKind.TASK_SOURCE_KIND_JIRA,
        TaskSourceKind.todoist => pb.TaskSourceKind.TASK_SOURCE_KIND_TODOIST,
      };

  static TaskColumn _column(pb.TaskStatus status) => switch (status) {
        pb.TaskStatus.TASK_STATUS_DOING => TaskColumn.doing,
        pb.TaskStatus.TASK_STATUS_REVIEW => TaskColumn.review,
        pb.TaskStatus.TASK_STATUS_DONE => TaskColumn.done,
        _ => TaskColumn.todo,
      };

  static pb.TaskStatus _status(TaskColumn column) => switch (column) {
        TaskColumn.todo => pb.TaskStatus.TASK_STATUS_TODO,
        TaskColumn.doing => pb.TaskStatus.TASK_STATUS_DOING,
        TaskColumn.review => pb.TaskStatus.TASK_STATUS_REVIEW,
        TaskColumn.done => pb.TaskStatus.TASK_STATUS_DONE,
      };

  static DateTime? _time(int ms) => ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);

  static TaskSourceInfo _source(pb.TaskSource s) => TaskSourceInfo(
        id: s.id,
        kind: _kindOf(s.kind) ?? TaskSourceKind.obsidian,
        name: s.name,
        options: Map.of(s.options),
        enabled: s.enabled,
        hasSecret: s.hasSecret,
        writable: {for (final w in s.writable) _column(w)},
        syncing: s.syncing,
        lastSynced: _time(s.lastSyncedUnixMs.toInt()),
        error: s.error,
        taskCount: s.taskCount,
      );

  static TaskEntry _task(pb.Task t, TaskSourceKind kind) => TaskEntry(
        id: t.id,
        sourceId: t.sourceId,
        kind: kind,
        key: t.key,
        title: t.title,
        column: _column(t.status),
        priority: switch (t.priority) {
          pb.TaskPriority.TASK_PRIORITY_URGENT => TaskPriority.urgent,
          pb.TaskPriority.TASK_PRIORITY_HIGH => TaskPriority.high,
          pb.TaskPriority.TASK_PRIORITY_MEDIUM => TaskPriority.medium,
          pb.TaskPriority.TASK_PRIORITY_LOW => TaskPriority.low,
          _ => TaskPriority.none,
        },
        due: t.due,
        url: t.url,
        context: t.context,
        labels: List.of(t.labels),
        updated: _time(t.updatedUnixMs.toInt()),
        suggestedBranch: t.suggestedBranch,
      );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
