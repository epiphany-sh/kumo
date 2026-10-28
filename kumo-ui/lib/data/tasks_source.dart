import 'package:flutter/foundation.dart';

import 'mock_task_details.dart';
import 'mock_tasks.dart';
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

/// What kind of ticket a task is (its icon on the card).
enum TaskType { story, bug, task, subtask, epic, issue, todo }

/// How a task relates to the user. "Mine" is [assigned] today; [reported]
/// and [watching] are room for later.
enum TaskRelation { assigned, reported, watching }

/// Someone in a source: an assignee, a reporter, a comment's author.
@immutable
class TaskPerson {
  const TaskPerson({required this.id, required this.name, this.initials = '', this.you = false});

  /// The source's id (Jira accountId, GitHub login).
  final String id;
  final String name;

  /// "AG"; one letter for one-word names.
  final String initials;

  /// The signed-in user.
  final bool you;
}

enum SprintState { closed, active, future }

@immutable
class TaskSprint {
  const TaskSprint({required this.name, required this.state, this.start, this.end});
  final String name;
  final SprintState state;
  final DateTime? start;
  final DateTime? end;
}

/// Another ticket, as a card or a detail mentions it (epic, parent,
/// sub-task, linked issue).
@immutable
class TaskRef {
  const TaskRef({
    this.id = '',
    required this.key,
    required this.title,
    this.type = TaskType.task,
    this.sourceStatus = '',
    this.column = TaskColumn.todo,
    this.assignee,
    this.color = '',
    this.url = '',
  });

  /// Kumo's id ("source/external") when known; empty otherwise (opening it
  /// asks [TasksSource.getTask] with `<sourceId>/<key>`).
  final String id;
  final String key;
  final String title;
  final TaskType type;
  final String sourceStatus;
  final TaskColumn column;
  final TaskPerson? assignee;

  /// Epics: a palette name ("violet", "teal", "amber"…); empty = by key.
  final String color;
  final String url;
}

enum LinkKind { other, blocks, blockedBy, relates, duplicates, duplicatedBy }

@immutable
class LinkedTask {
  const LinkedTask({required this.kind, required this.relation, required this.task});
  final LinkKind kind;

  /// The source's wording ("is blocked by").
  final String relation;
  final TaskRef task;
}

@immutable
class TaskAttachment {
  const TaskAttachment({required this.name, this.kind = '', this.sizeBytes = 0, this.url = ''});
  final String name;

  /// "PNG image", "CSV", "PDF".
  final String kind;
  final int sizeBytes;
  final String url;
}

@immutable
class TaskComment {
  const TaskComment({required this.author, this.created, required this.body});
  final TaskPerson author;
  final DateTime? created;

  /// Markdown.
  final String body;
}

@immutable
class TimeTracking {
  const TimeTracking({this.estimate = '', this.logged = '', this.remaining = '', this.estimateSeconds = 0, this.loggedSeconds = 0, this.remainingSeconds = 0});

  /// The source's own wording ("3d", "1d 4h"); seconds for the bar.
  final String estimate;
  final String logged;
  final String remaining;
  final int estimateSeconds;
  final int loggedSeconds;
  final int remainingSeconds;
}

/// The whole ticket ([TasksSource.getTask]).
@immutable
class TaskDetail {
  const TaskDetail({
    required this.task,
    this.reporter,
    this.created,
    this.description = '',
    this.acceptanceCriteria = '',
    this.subtasks = const [],
    this.links = const [],
    this.attachments = const [],
    this.comments = const [],
    this.components = const [],
    this.fixVersions = const [],
    this.timeTracking,
    this.fetched,
    this.stale = false,
    this.staleReason = '',
    this.location = '',
  });

  /// The card's fields, as fresh as the detail.
  final TaskEntry task;
  final TaskPerson? reporter;
  final DateTime? created;

  /// Markdown.
  final String description;
  final String acceptanceCriteria;
  final List<TaskRef> subtasks;
  final List<LinkedTask> links;
  final List<TaskAttachment> attachments;

  /// Oldest first, all of them.
  final List<TaskComment> comments;
  final List<String> components;
  final List<String> fixVersions;
  final TimeTracking? timeTracking;

  /// When the source answered.
  final DateTime? fetched;

  /// Served from the daemon's cache: the source couldn't be reached.
  final bool stale;
  final String staleReason;

  /// Where a personal task lives ("Weekly.md · line 14", "Todoist · Inbox").
  final String location;
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
    this.type = TaskType.task,
    this.typeName = '',
    this.sourceStatus = '',
    this.assignee,
    this.relations = const {},
    this.mine = true,
    this.points = 0,
    this.subtasksDone = 0,
    this.subtasksTotal = 0,
    this.commentCount = 0,
    this.parent,
    this.blocked = false,
    this.sprint,
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

  final TaskType type;

  /// The source's own name for the type ("Story", "Sub-task").
  final String typeName;

  /// The source's own status ("Code Review", "QA"); [column] is where the
  /// board puts it. Cards show it only when it says more than the column.
  final String sourceStatus;
  final TaskPerson? assignee;
  final Set<TaskRelation> relations;

  /// The user's: assigned to them, or from a personal source (Obsidian,
  /// Bear, Todoist). What "Mine" shows.
  final bool mine;

  /// Story points; 0 = none.
  final double points;
  final int subtasksDone;
  final int subtasksTotal;
  final int commentCount;

  /// Epic, or parent of a sub-task.
  final TaskRef? parent;

  /// An issue that blocks this one isn't done yet.
  final bool blocked;
  final TaskSprint? sprint;

  /// Moved on the board: the source's status is unknown until it answers.
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
        type: type,
        typeName: typeName,
        sourceStatus: column == this.column ? sourceStatus : '',
        assignee: assignee,
        relations: relations,
        mine: mine,
        points: points,
        subtasksDone: subtasksDone,
        subtasksTotal: subtasksTotal,
        commentCount: commentCount,
        parent: parent,
        blocked: blocked,
        sprint: sprint,
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

  /// The whole ticket. Answered from the daemon's cache when fresh, or when
  /// the source can't be reached ([TaskDetail.stale]); throws a readable
  /// message when there's nothing to show. [refresh] asks the source anyway.
  Future<TaskDetail> getTask(String id, {bool refresh = false});

  /// The last detail fetched for [id] in this session, to show at once
  /// while [getTask] answers.
  TaskDetail? cachedDetail(String id);
}

/// The design canvas: the board and ticket details of the approved Tasks
/// design ([MockTasks], [MockTaskDetails]).
class MockTasksSource extends TasksSource {
  MockTasksSource({this.latency = Duration.zero}) {
    _tasks.addAll(MockTasks.tasks());
    _links.addAll(MockTasks.links(_tasks));
  }

  /// How long [getTask] takes, to see the loading state.
  final Duration latency;

  final _tasks = <TaskEntry>[];
  final _links = <TaskLinkInfo>[];
  final _details = <String, TaskDetail>{};

  @override
  bool get live => false;

  @override
  List<TaskSourceInfo> get sources => MockTasks.sources(_tasks);

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

  @override
  Future<TaskDetail> getTask(String id, {bool refresh = false}) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final designed = MockTaskDetails.of(_tasks)[id];
    final task = _tasks.where((t) => t.id == id).firstOrNull;
    final detail = designed ?? (task == null ? null : MockTaskDetails.basic(task));
    if (detail == null) throw 'Unknown task $id';
    return _details[id] = detail;
  }

  @override
  TaskDetail? cachedDetail(String id) => _details[id];
}
