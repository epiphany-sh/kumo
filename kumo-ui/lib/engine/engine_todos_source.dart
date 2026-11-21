import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

import '../data/todos_source.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart' as pb;
import 'kumo_engine.dart';

/// TODOs as `kumod` keeps them: the whole list streamed (`Todos.Watch`),
/// changes sent back as calls.
class EngineTodosSource extends TodosSource {
  EngineTodosSource(this._engine) {
    _watch();
  }

  final KumoEngine _engine;
  bool _disposed = false;
  List<TodoItem> _todos = const [];
  String? _error;

  @override
  bool get live => true;
  @override
  List<TodoItem> get todos => _todos;
  @override
  String? get error => _error;

  Future<pb.TodosClient> get _client async => (await _engine.connection()).todos;

  Future<void> _watch() async {
    while (!_disposed) {
      try {
        await for (final list in (await _client).watch(pb.WatchTodosRequest())) {
          if (_disposed) return;
          _todos = [for (final t in list.todos) _todo(t)];
          _error = null;
          notifyListeners();
        }
      } on GrpcError catch (e) {
        if (_disposed) return;
        // A daemon from before TODOs: say so once, and keep trying (it may
        // be updated and restarted).
        if (e.code == StatusCode.unimplemented) {
          _fail('This Kumo engine has no TODOs yet: restart Kumo to update it.');
        } else if (!_engine.restarting) {
          _fail(e);
        }
      } on Object catch (e) {
        if (_disposed) return;
        if (!_engine.restarting) _fail(e);
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  void _fail(Object error) {
    _error = error is GrpcError ? (error.message ?? error.codeName) : '$error';
    if (!_disposed) notifyListeners();
  }

  /// Runs a call; a failure becomes [error] and returns null.
  Future<T?> _call<T>(Future<T> Function(pb.TodosClient client) call) async {
    try {
      final result = await call(await _client);
      _error = null;
      return result;
    } on Object catch (e) {
      _fail(e);
      return null;
    }
  }

  /// The answer as the stream will send it, so the UI doesn't wait for it.
  TodoItem? _apply(pb.Todo? todo) {
    if (todo == null) return null;
    final item = _todo(todo);
    final at = _todos.indexWhere((t) => t.id == item.id);
    _todos = at >= 0 ? ([..._todos]..[at] = item) : [item, ..._todos];
    notifyListeners();
    return item;
  }

  @override
  Future<TodoItem?> add(String title, {String notes = '', String repoPath = ''}) async =>
      _apply(await _call((c) => c.add(pb.AddTodoRequest(title: title, notes: notes, repoPath: repoPath))));

  @override
  Future<TodoItem?> update(TodoItem todo, {String? title, String? notes, String? repoPath, bool? done}) async => _apply(await _call((c) => c.update(pb.UpdateTodoRequest(
        id: todo.id,
        title: title ?? todo.title,
        notes: notes ?? todo.notes,
        repoPath: repoPath ?? todo.repoPath,
        done: done ?? todo.done,
      ))));

  @override
  Future<bool> delete(String id) async {
    final ok = await _call((c) => c.delete(pb.DeleteTodoRequest(id: id))) != null;
    if (ok) {
      _todos = [for (final t in _todos) if (t.id != id) t];
      notifyListeners();
    }
    return ok;
  }

  @override
  Future<TodoItem?> attach(String id, TodoRun run) async => _apply(await _call((c) => c.attach(pb.AttachTodoRequest(id: id, run: _runTo(run)))));

  @override
  Future<TodoItem?> setStatus(String id, TodoStatus status, {String by = 'You', String note = '', int prNumber = 0, String prUrl = '', bool clearRun = false}) async =>
      _apply(await _call((c) => c.setStatus(pb.SetTodoStatusRequest(
            id: id,
            status: _statusTo(status),
            by: by,
            note: note,
            prNumber: prNumber > 0 ? Int64(prNumber) : null,
            prUrl: prUrl,
            clearRun: clearRun,
          ))));

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ---- Mapping ----

  static const _statuses = {
    pb.TodoStatus.TODO_STATUS_OPEN: TodoStatus.open,
    pb.TodoStatus.TODO_STATUS_WORKING: TodoStatus.working,
    pb.TodoStatus.TODO_STATUS_TESTING: TodoStatus.testing,
    pb.TodoStatus.TODO_STATUS_REVIEW: TodoStatus.review,
    pb.TodoStatus.TODO_STATUS_PUSHED: TodoStatus.pushed,
    pb.TodoStatus.TODO_STATUS_PR: TodoStatus.pr,
    pb.TodoStatus.TODO_STATUS_MERGED: TodoStatus.merged,
  };

  static TodoStatus _status(pb.TodoStatus s) => _statuses[s] ?? TodoStatus.open;
  static pb.TodoStatus _statusTo(TodoStatus s) => _statuses.entries.firstWhere((e) => e.value == s).key;

  static DateTime _ms(Int64 v) => DateTime.fromMillisecondsSinceEpoch(v.toInt());

  static TodoRun _run(pb.TodoRun r) => TodoRun(
        repoPath: r.repoPath,
        worktreePath: r.worktreePath,
        branch: r.branch,
        base: r.base,
        providerId: r.providerId,
        agentName: r.agentName,
        model: r.model,
        effort: r.effort,
        sessionId: r.sessionId,
        prNumber: r.prNumber.toInt(),
        prUrl: r.prUrl,
      );

  static pb.TodoRun _runTo(TodoRun r) => pb.TodoRun(
        repoPath: r.repoPath,
        worktreePath: r.worktreePath,
        branch: r.branch,
        base: r.base,
        providerId: r.providerId,
        agentName: r.agentName,
        model: r.model,
        effort: r.effort,
        sessionId: r.sessionId,
      );

  static TodoItem _todo(pb.Todo t) => TodoItem(
        id: t.id,
        title: t.title,
        notes: t.notes,
        repoPath: t.repoPath,
        done: t.done,
        created: _ms(t.createdUnixMs),
        run: t.hasRun() ? _run(t.run) : null,
        steps: [for (final s in t.steps) TodoStep(status: _status(s.status), by: s.by, at: _ms(s.atUnixMs), note: s.note)],
      );
}
