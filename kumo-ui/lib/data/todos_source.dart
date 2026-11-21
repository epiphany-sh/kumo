import 'package:flutter/foundation.dart';

/// Where a TODO is: open until handed to an agent; then the agent reports
/// working, testing and review; the user approves (pushed) and opens the
/// pull request; Kumo sees it merge.
enum TodoStatus {
  open('To do'),
  working('Working'),
  testing('Testing'),
  review('Waiting for your review'),
  pushed('Pushed'),
  pr('PR created'),
  merged('Merged');

  const TodoStatus(this.label);
  final String label;

  /// The steps a TODO goes through once with an agent, in order.
  static const steps = [working, testing, review, pushed, pr, merged];

  /// The agent is on it.
  bool get withAgent => this == working || this == testing;

  /// The user's turn: try it and approve, or clean it up.
  bool get needsYou => this == review || this == merged;

  /// On its way: pushed, or its pull request is open.
  bool get shipping => this == pushed || this == pr;
}

@immutable
class TodoStep {
  const TodoStep({required this.status, required this.by, required this.at, this.note = ''});
  final TodoStatus status;

  /// An agent's name, "You" or "Kumo".
  final String by;
  final DateTime at;
  final String note;
}

/// Where a TODO runs once handed to an agent.
@immutable
class TodoRun {
  const TodoRun({
    required this.repoPath,
    required this.worktreePath,
    required this.branch,
    this.base = '',
    this.providerId = '',
    this.agentName = '',
    this.model = '',
    this.effort = '',
    this.sessionId = '',
    this.prNumber = 0,
    this.prUrl = '',
  });

  final String repoPath;
  final String worktreePath;
  final String branch;
  final String base;
  final String providerId;
  final String agentName;

  /// Empty: the CLI's own setting.
  final String model;
  final String effort;

  /// The agent session working on it; empty once it's gone.
  final String sessionId;
  final int prNumber;
  final String prUrl;

  /// "Claude Code · opus · high effort".
  String get describe => [
        if (agentName.isNotEmpty) agentName,
        if (model.isNotEmpty) model,
        if (effort.isNotEmpty) '$effort effort',
      ].join(' · ');

  TodoRun copyWith({int? prNumber, String? prUrl}) => TodoRun(
        repoPath: repoPath,
        worktreePath: worktreePath,
        branch: branch,
        base: base,
        providerId: providerId,
        agentName: agentName,
        model: model,
        effort: effort,
        sessionId: sessionId,
        prNumber: prNumber ?? this.prNumber,
        prUrl: prUrl ?? this.prUrl,
      );
}

/// One of the user's TODOs, kept on this Mac by the workspace.
@immutable
class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    this.notes = '',
    this.repoPath = '',
    this.done = false,
    required this.created,
    this.run,
    this.steps = const [],
  });

  final String id;
  final String title;
  final String notes;

  /// The repository it's about; empty: any.
  final String repoPath;
  final bool done;
  final DateTime created;
  final TodoRun? run;

  /// Oldest first; the last one is the current status.
  final List<TodoStep> steps;

  TodoStatus get status => steps.isEmpty ? TodoStatus.open : steps.last.status;
  TodoStep? stepOf(TodoStatus s) => steps.where((x) => x.status == s).lastOrNull;

  TodoItem copyWith({String? title, String? notes, String? repoPath, bool? done, TodoRun? run, bool clearRun = false, List<TodoStep>? steps}) => TodoItem(
        id: id,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        repoPath: repoPath ?? this.repoPath,
        done: done ?? this.done,
        created: created,
        run: clearRun ? null : (run ?? this.run),
        steps: steps ?? this.steps,
      );
}

/// The workspace's TODOs. [EngineTodosSource] reads `kumod`'s;
/// [MockTodosSource] keeps them in memory (design and tests).
abstract class TodosSource extends ChangeNotifier {
  /// Backed by the engine.
  bool get live => false;

  /// Newest first.
  List<TodoItem> get todos;

  /// The last failure, for the user.
  String? get error;

  TodoItem? todo(String id) => todos.where((t) => t.id == id).firstOrNull;

  Future<TodoItem?> add(String title, {String notes = '', String repoPath = ''});

  /// Changes what's given; the rest stays.
  Future<TodoItem?> update(TodoItem todo, {String? title, String? notes, String? repoPath, bool? done});

  Future<bool> delete(String id);

  /// Records where it runs once its worktree and agent are up: it's
  /// working from then on.
  Future<TodoItem?> attach(String id, TodoRun run);

  /// Moves it to [status]. [clearRun] with [TodoStatus.open] forgets where
  /// it ran (cleaned up, or given up).
  Future<TodoItem?> setStatus(String id, TodoStatus status, {String by = 'You', String note = '', int prNumber = 0, String prUrl = '', bool clearRun = false});
}

/// TODOs in memory, with the engine's rules: a status needs a run, and
/// going back drops the later steps.
class MockTodosSource extends TodosSource {
  MockTodosSource({List<TodoItem>? seed}) : _todos = [...?seed];

  final List<TodoItem> _todos;
  String? _error;
  int _next = 0;

  @override
  List<TodoItem> get todos => List.unmodifiable(_todos);
  @override
  String? get error => _error;

  TodoItem _put(TodoItem t) {
    final at = _todos.indexWhere((x) => x.id == t.id);
    if (at >= 0) {
      _todos[at] = t;
    } else {
      _todos.insert(0, t);
    }
    _error = null;
    notifyListeners();
    return t;
  }

  TodoItem? _fail(String message) {
    _error = message;
    notifyListeners();
    return null;
  }

  @override
  Future<TodoItem?> add(String title, {String notes = '', String repoPath = ''}) async {
    final t = title.trim();
    if (t.isEmpty) return _fail('a TODO needs a title');
    return _put(TodoItem(id: 'todo-${_next++}', title: t, notes: notes.trimRight(), repoPath: repoPath, created: DateTime.now()));
  }

  @override
  Future<TodoItem?> update(TodoItem todo, {String? title, String? notes, String? repoPath, bool? done}) async {
    final current = this.todo(todo.id);
    if (current == null) return _fail('unknown TODO');
    if (title != null && title.trim().isEmpty) return _fail('a TODO needs a title');
    return _put(current.copyWith(title: title?.trim(), notes: notes?.trimRight(), repoPath: repoPath, done: done));
  }

  @override
  Future<bool> delete(String id) async {
    final before = _todos.length;
    _todos.removeWhere((t) => t.id == id);
    notifyListeners();
    return _todos.length < before;
  }

  @override
  Future<TodoItem?> attach(String id, TodoRun run) async {
    final current = todo(id);
    if (current == null) return _fail('unknown TODO');
    final by = run.agentName.isEmpty ? 'You' : run.agentName;
    return _put(current.copyWith(
      run: run,
      done: false,
      repoPath: current.repoPath.isEmpty ? run.repoPath : null,
      steps: [TodoStep(status: TodoStatus.working, by: by, at: DateTime.now())],
    ));
  }

  @override
  Future<TodoItem?> setStatus(String id, TodoStatus status, {String by = 'You', String note = '', int prNumber = 0, String prUrl = '', bool clearRun = false}) async {
    final current = todo(id);
    if (current == null) return _fail('unknown TODO');
    if (status == TodoStatus.open) return _put(current.copyWith(steps: const [], clearRun: clearRun));
    if (current.run == null) return _fail('hand it to an agent first: it has no worktree yet');
    final steps = [
      for (final s in current.steps)
        if (s.status.index < status.index) s,
      TodoStep(status: status, by: by, at: DateTime.now(), note: note),
    ];
    final run = status == TodoStatus.pr && prNumber > 0 ? current.run!.copyWith(prNumber: prNumber, prUrl: prUrl) : null;
    return _put(current.copyWith(steps: steps, run: run));
  }
}
