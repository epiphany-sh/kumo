import 'package:flutter/foundation.dart';

import 'mock_data.dart';
import 'models.dart';

/// The tools tasks come from.
enum TaskSourceKind {
  obsidian('Obsidian', 'OB', 'Checkboxes in the notes of a vault. Kumo watches the folder and ticks them back.'),
  bear('Bear', 'BR', 'Checkboxes in your Bear notes, read from its database on this Mac (read only).'),
  github('GitHub', 'GH', 'Issues, through your own GitHub CLI (gh): Kumo never sees a GitHub token.'),
  jira('Jira', 'JI', 'Jira Cloud, with your account email and an API token kept in the Keychain.'),
  todoist('Todoist', 'TD', 'Todoist, with a personal API token kept in the Keychain.');

  const TaskSourceKind(this.label, this.badge, this.blurb);
  final String label;
  final String badge;
  final String blurb;

  bool get needsSecret => this == jira || this == todoist;
}

enum TaskPriority { none, low, medium, high, urgent }

/// A configured source, as the engine reports it.
@immutable
class TaskSourceInfo {
  const TaskSourceInfo({
    required this.id,
    required this.kind,
    required this.name,
    this.options = const {},
    this.enabled = true,
    this.hasSecret = false,
    this.writable = const {},
    this.syncing = false,
    this.lastSynced,
    this.error = '',
    this.taskCount = 0,
  });

  final String id;
  final TaskSourceKind kind;
  final String name;
  final Map<String, String> options;
  final bool enabled;
  final bool hasSecret;

  /// Columns Kumo can move its tasks to (written back to the tool).
  final Set<TaskColumn> writable;
  final bool syncing;
  final DateTime? lastSynced;

  /// Why the last read failed; its cached tasks are still shown.
  final String error;
  final int taskCount;
}

/// A source found on this machine, ready to add.
@immutable
class DetectedSourceInfo {
  const DetectedSourceInfo({required this.kind, required this.name, required this.options});
  final TaskSourceKind kind;
  final String name;
  final Map<String, String> options;
}

/// One task, whatever tool it lives in.
@immutable
class TaskEntry {
  const TaskEntry({
    required this.id,
    required this.sourceId,
    required this.kind,
    required this.key,
    required this.title,
    required this.column,
    this.priority = TaskPriority.none,
    this.due = '',
    this.url = '',
    this.context = '',
    this.labels = const [],
    this.updated,
    this.suggestedBranch = '',
  });

  final String id;
  final String sourceId;
  final TaskSourceKind kind;

  /// Issue key (PRC-412, #18), project or note.
  final String key;
  final String title;
  final TaskColumn column;
  final TaskPriority priority;

  /// YYYY-MM-DD, or empty.
  final String due;
  final String url;

  /// Repository, project or folder.
  final String context;
  final List<String> labels;
  final DateTime? updated;
  final String suggestedBranch;

  TaskEntry withColumn(TaskColumn column) => TaskEntry(
        id: id,
        sourceId: sourceId,
        kind: kind,
        key: key,
        title: title,
        column: column,
        priority: priority,
        due: due,
        url: url,
        context: context,
        labels: labels,
        updated: updated,
        suggestedBranch: suggestedBranch,
      );
}

/// A task being worked on in a worktree.
@immutable
class TaskLinkInfo {
  const TaskLinkInfo({required this.taskId, required this.worktreePath, required this.branch});
  final String taskId;
  final String worktreePath;
  final String branch;
}

/// Tasks from the user's tools, served from the engine's local cache:
/// nothing here waits on the network except [detect], [test] and
/// [setStatus].
abstract class TasksSource extends ChangeNotifier {
  /// Backed by the daemon (false: design mocks).
  bool get live;

  List<TaskSourceInfo> get sources;

  /// Tasks of enabled sources, in source order.
  List<TaskEntry> get tasks;
  List<TaskLinkInfo> get links;

  /// Last failure reported by the daemon, readable.
  String? get error;

  TaskSourceInfo? source(String id) => sources.where((s) => s.id == id).firstOrNull;
  List<TaskLinkInfo> linksOf(String taskId) => [for (final l in links) if (l.taskId == taskId) l];

  /// Sources on this machine that aren't configured yet.
  Future<List<DetectedSourceInfo>> detect();

  /// Checks options and credentials without saving; throws a readable
  /// message when it fails. An empty [secret] uses the one stored for [id].
  Future<String> test({String? id, required TaskSourceKind kind, required Map<String, String> options, String secret = ''});

  /// Creates (no [id]) or updates a source; throws a readable message.
  Future<TaskSourceInfo> saveSource({String? id, required TaskSourceKind kind, String name = '', required Map<String, String> options, bool enabled = true, String secret = ''});

  Future<void> deleteSource(String id);

  /// Reads a source (all of them without [id]) now.
  Future<void> sync([String? id]);

  /// Moves a task, writing it back to its tool. Shows at once; returns
  /// false (with [error] set) if the tool refused, and the task goes back.
  Future<bool> setStatus(String taskId, TaskColumn column);

  Future<void> link(String taskId, {required String worktreePath, required String branch});
  Future<void> unlink(String taskId, String worktreePath);
}

/// The design canvas: the mock board (Jira, ClickUp, Trello, Todoist).
class MockTasksSource extends TasksSource {
  MockTasksSource() {
    for (final t in Mock.tasks) {
      _tasks.add(TaskEntry(
        id: 'mock-${t.src}/${t.key}-${_tasks.length}',
        sourceId: 'mock-${t.src}',
        kind: switch (t.src) { 'JI' => TaskSourceKind.jira, 'TD' => TaskSourceKind.todoist, _ => TaskSourceKind.obsidian },
        key: t.key,
        title: t.title,
        column: t.col,
        priority: switch (t.prio) { 'High' => TaskPriority.high, 'Med' => TaskPriority.medium, _ => TaskPriority.low },
        context: t.meta,
        suggestedBranch: t.branch ?? 'feat/${t.key}',
      ));
      if (t.branch != null) {
        _links.add(TaskLinkInfo(taskId: _tasks.last.id, worktreePath: '~/wt/${t.branch}', branch: t.branch!));
      }
    }
  }

  final _tasks = <TaskEntry>[];
  final _links = <TaskLinkInfo>[];

  static const _all = {TaskColumn.todo, TaskColumn.doing, TaskColumn.review, TaskColumn.done};

  @override
  bool get live => false;

  @override
  List<TaskSourceInfo> get sources => [
        for (final (k, name, kind) in const [
          ('JI', 'Jira', TaskSourceKind.jira),
          ('CU', 'ClickUp', TaskSourceKind.obsidian),
          ('TR', 'Trello', TaskSourceKind.obsidian),
          ('TD', 'Todoist', TaskSourceKind.todoist),
        ])
          TaskSourceInfo(
            id: 'mock-$k',
            kind: kind,
            name: name,
            hasSecret: true,
            writable: _all,
            lastSynced: DateTime.now().subtract(const Duration(minutes: 1)),
            taskCount: _tasks.where((t) => t.sourceId == 'mock-$k').length,
          ),
      ];

  @override
  List<TaskEntry> get tasks => List.unmodifiable(_tasks);
  @override
  List<TaskLinkInfo> get links => List.unmodifiable(_links);
  @override
  String? get error => null;

  @override
  Future<List<DetectedSourceInfo>> detect() async => const [];
  @override
  Future<String> test({String? id, required TaskSourceKind kind, required Map<String, String> options, String secret = ''}) async => 'Connected';
  @override
  Future<TaskSourceInfo> saveSource({String? id, required TaskSourceKind kind, String name = '', required Map<String, String> options, bool enabled = true, String secret = ''}) async =>
      TaskSourceInfo(id: id ?? 'mock-new', kind: kind, name: name.isEmpty ? kind.label : name, options: options, enabled: enabled);
  @override
  Future<void> deleteSource(String id) async {}
  @override
  Future<void> sync([String? id]) async {}

  @override
  Future<bool> setStatus(String taskId, TaskColumn column) async {
    final at = _tasks.indexWhere((t) => t.id == taskId);
    if (at >= 0) _tasks[at] = _tasks[at].withColumn(column);
    notifyListeners();
    return true;
  }

  @override
  Future<void> link(String taskId, {required String worktreePath, required String branch}) async {
    _links.add(TaskLinkInfo(taskId: taskId, worktreePath: worktreePath, branch: branch));
    notifyListeners();
  }

  @override
  Future<void> unlink(String taskId, String worktreePath) async {
    _links.removeWhere((l) => l.taskId == taskId && l.worktreePath == worktreePath);
    notifyListeners();
  }
}
