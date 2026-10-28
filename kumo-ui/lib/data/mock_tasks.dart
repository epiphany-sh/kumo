import 'agents_source.dart';
import 'models.dart';
import 'tasks_source.dart';

/// The design's board: the sources, people, sprints and tickets of the
/// approved Tasks design (docs/design/tasks, `ticketData()` in
/// Tasks.dc.html), for [MockTasksSource] (the app without a daemon, widget
/// tests).
///
/// Ids are `<sourceId>/<key>` (`mock-JI/PRC-11355`, `mock-GH/zen-engine#42`)
/// so refs can point at them; personal to-dos, whose key is a note or a
/// project, use the design's id instead (`mock-OB/ob-aws`,
/// `mock-TD/td-kafka`, `mock-TD/td-runbook`). [id] maps a design id to it.
/// Dates are relative to today, so "2 days overdue" and "Due today" read
/// like the screens.
final class MockTasks {
  MockTasks._();

  static const _all = {TaskColumn.todo, TaskColumn.doing, TaskColumn.review, TaskColumn.done};
  static const _openDone = {TaskColumn.todo, TaskColumn.done};

  static const _sources = [
    ('JI', 'Jira · Pricing', TaskSourceKind.jira, _all),
    ('GH', 'GitHub', TaskSourceKind.github, _openDone),
    ('OB', 'Obsidian', TaskSourceKind.obsidian, _openDone),
    ('TD', 'Todoist', TaskSourceKind.todoist, _openDone),
  ];

  static List<TaskSourceInfo> sources(List<TaskEntry> tasks) => [
        for (final (k, name, kind, writable) in _sources)
          TaskSourceInfo(
            id: 'mock-$k',
            kind: kind,
            name: name,
            hasSecret: kind.needsSecret,
            writable: writable,
            lastSynced: DateTime.now().subtract(const Duration(minutes: 1)),
            taskCount: tasks.where((t) => t.sourceId == 'mock-$k').length,
          ),
      ];

  // ---- People ----

  static const me = TaskPerson(id: 'me', name: 'Mauri', initials: 'M', you: true);
  static const ana = TaskPerson(id: 'ana', name: 'Ana Gómez', initials: 'AG');
  static const lucia = TaskPerson(id: 'lucia', name: 'Lucía', initials: 'L');
  static const tomas = TaskPerson(id: 'tomas', name: 'Tomás', initials: 'T');
  static const valentina = TaskPerson(id: 'valentina', name: 'Valentina', initials: 'V');
  static const nico = TaskPerson(id: 'nico', name: 'Nico', initials: 'N');

  /// By the design's person id ("me", "ana", …).
  static const people = {'me': me, 'ana': ana, 'lucia': lucia, 'tomas': tomas, 'valentina': valentina, 'nico': nico};

  // ---- Sprints ----

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _day(int offset) => _today.add(Duration(days: offset));

  /// Pricing 2026.21 (closed), 2026.22 (active, 7 days left), 2026.23 (next).
  static TaskSprint get previousSprint => TaskSprint(name: 'Pricing 2026.21', state: SprintState.closed, start: _day(-21), end: _day(-8));
  static TaskSprint get currentSprint => TaskSprint(name: 'Pricing 2026.22', state: SprintState.active, start: _day(-7), end: _day(7));
  static TaskSprint get nextSprint => TaskSprint(name: 'Pricing 2026.23', state: SprintState.future, start: _day(8), end: _day(21));

  // ---- Tickets ----

  /// The Kumo id of a design id ("PRC-11355" → "mock-JI/PRC-11355").
  static String id(String designId) => _byDesignId[designId]?.kumoId ?? designId;

  static final Map<String, _T> _byDesignId = {for (final t in _data) t.id: t};

  /// The board's tasks.
  static List<TaskEntry> tasks() => [for (final t in _data) if (t.board) _entry(t)];

  /// Tickets the board doesn't show but cards and details mention: the
  /// epics, the rest of the sub-tasks and an old duplicate.
  static List<TaskEntry> offBoard() => [for (final t in _data) if (!t.board) _entry(t)];

  /// A ticket (on the board or not) as a reference, by its design id.
  static TaskRef ref(String designId) {
    final t = _byDesignId[designId]!;
    return TaskRef(
      id: t.kumoId,
      key: t.key,
      title: t.title,
      type: t.type,
      sourceStatus: t.status,
      column: t.column,
      assignee: people[t.as],
      color: t.color,
      url: _url(t),
    );
  }

  /// Worktrees already linked to tasks (the sidebar's worktrees).
  static List<TaskLinkInfo> links(List<TaskEntry> tasks) => [
        for (final t in _data)
          if (t.branch.isNotEmpty && tasks.any((x) => x.id == t.kumoId))
            TaskLinkInfo(taskId: t.kumoId, worktreePath: _worktrees[t.branch]!.$1, branch: t.branch),
      ];

  /// The agents working in those worktrees, for the board's agent block
  /// while the agents source is the design canvas too.
  static List<AgentRun> runs() {
    final started = DateTime.now().subtract(const Duration(minutes: 20));
    return [
      for (final MapEntry(key: branch, value: (path, provider, status, line)) in _worktrees.entries)
        AgentRun(
          id: 'mock-run-${branch.split('/').last}',
          providerId: provider == 'Codex CLI' ? 'codex' : 'claude',
          providerName: provider,
          short: provider == 'Codex CLI' ? 'codex' : 'claude',
          worktreePath: path,
          terminalId: '',
          title: branch,
          status: status,
          startedAt: started,
          lastLine: line,
        ),
    ];
  }

  static const _worktrees = {
    'feat/PRC-412-bulk-discounts': ('~/wt/price-admin/PRC-412', 'Claude Code', AgentStatus.running, 'Edit internal/kafka/bulk_consumer.go'),
    'fix/PRC-398-rounding': ('~/wt/price-admin/PRC-398', 'Codex CLI', AgentStatus.needsYou, 'Waiting: migration on staging'),
    'perf/cache-warmup': ('~/wt/price-reader-v2/cache', 'Claude Code', AgentStatus.done, 'MR !231 · pipeline passed'),
  };

  static String _url(_T t) => switch (t.src) {
        'JI' => 'https://jira.pricing.local/browse/${t.key}',
        'GH' => 'https://github.com/pricing/zen-engine/issues/42',
        _ => '',
      };

  static TaskEntry _entry(_T t) {
    final kind = switch (t.src) {
      'JI' => TaskSourceKind.jira,
      'GH' => TaskSourceKind.github,
      'OB' => TaskSourceKind.obsidian,
      _ => TaskSourceKind.todoist,
    };
    final personal = t.src == 'OB' || t.src == 'TD';
    final subs = [for (final k in t.subs) _byDesignId[k]!];
    final epic = t.epic.isNotEmpty ? t.epic : t.parent;
    return TaskEntry(
      id: t.kumoId,
      sourceId: 'mock-${t.src}',
      kind: kind,
      key: t.key,
      title: t.title,
      column: t.column,
      priority: t.pri,
      due: t.due == null ? '' : _iso(_day(t.due!)),
      url: _url(t),
      context: switch (t.src) { 'JI' => 'Pricing', 'GH' => 'pricing/zen-engine', _ => t.key },
      labels: t.labels,
      updated: DateTime.now().subtract(t.updated),
      suggestedBranch: t.branch.isNotEmpty ? t.branch : '${t.type == TaskType.bug ? 'fix' : 'feat'}/${t.key}-${_slug(t.title)}',
      type: t.type,
      typeName: t.type == TaskType.todo ? '' : (t.type == TaskType.issue ? 'Issue' : _typeNames[t.type]!),
      sourceStatus: t.status,
      assignee: personal ? null : people[t.as],
      relations: t.as == 'me' && !personal ? const {TaskRelation.assigned} : const {},
      mine: personal || t.as == 'me',
      points: t.pts.toDouble(),
      subtasksDone: subs.where((s) => s.column == TaskColumn.done).length,
      subtasksTotal: subs.length,
      commentCount: t.comments,
      parent: epic.isEmpty ? null : ref(epic),
      blocked: t.blockedBy.any((k) => _byDesignId[k]!.column != TaskColumn.done),
      sprint: switch (t.sprint) { 'prev' => previousSprint, 'cur' => currentSprint, 'next' => nextSprint, _ => null },
    );
  }

  static const _typeNames = {
    TaskType.story: 'Story',
    TaskType.bug: 'Bug',
    TaskType.task: 'Task',
    TaskType.subtask: 'Sub-task',
    TaskType.epic: 'Epic',
  };

  static String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// "migraciones" → "migraciones"; "Bulk discounts by category" → "bulk-discounts-by".
  static String _slug(String title) {
    const plain = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n'};
    final lower = title.toLowerCase().split('').map((ch) => plain[ch] ?? ch).join();
    final words = lower.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).take(3);
    return words.join('-');
  }

  static const _h = Duration(hours: 1);
  static const _d = Duration(days: 1);

  static const _data = <_T>[
    // To do
    _T('PRC-10599', 'JI', TaskType.bug, 'Generación automática de precios para los canales (Hijas)', TaskColumn.todo,
        status: 'To Do', pri: TaskPriority.high, pts: 3, sprint: 'prev', due: -2, labels: ['canales', 'hotfix', 'marketplace'], comments: 14, updated: Duration(hours: 2)),
    _T('PRC-11354', 'JI', TaskType.subtask, 'Migracion a Graviton (Parte 4/4)', TaskColumn.todo,
        status: 'To Do', pri: TaskPriority.low, sprint: 'cur', parent: 'PRC-11300', as: 'me', blockedBy: ['PRC-11355'], comments: 1, updated: _d),
    _T('PRC-11321', 'JI', TaskType.task, 'Analisis: Migracion a Envoy', TaskColumn.todo,
        status: 'Backlog', pri: TaskPriority.medium, pts: 3, sprint: 'next', as: 'tomas', labels: ['infra'], comments: 2, updated: Duration(days: 3)),
    _T('PRC-11371', 'JI', TaskType.story, 'Precios por zona de envío en checkout', TaskColumn.todo,
        status: 'To Do', pri: TaskPriority.medium, pts: 8, sprint: 'cur', epic: 'PRC-11250', as: 'valentina', labels: ['checkout'], updated: _d),
    _T('zen-engine#42', 'GH', TaskType.issue, 'Retry on 502 from pricing API', TaskColumn.todo,
        status: 'Open', as: 'me', labels: ['bug', 'api'], comments: 3, updated: _d),
    _T('ob-aws', 'OB', TaskType.todo, 'Revisar costos de AWS', TaskColumn.todo, key: 'Weekly.md', due: 3, as: 'me', updated: Duration(days: 2)),
    _T('td-kafka', 'TD', TaskType.todo, 'Rotate staging Kafka credentials', TaskColumn.todo,
        key: 'Inbox', pri: TaskPriority.high, due: 0, as: 'me', labels: ['ops'], updated: Duration(hours: 5)),
    // In progress
    _T('PRC-11355', 'JI', TaskType.story, 'migraciones', TaskColumn.doing,
        status: 'In Progress', pri: TaskPriority.low, pts: 5, sprint: 'cur', epic: 'PRC-11300', as: 'me', labels: ['graviton', 'db'],
        subs: ['PRC-11356', 'PRC-11357', 'PRC-11358', 'PRC-11359'], blockedBy: ['PRC-11340'], comments: 6, updated: Duration(hours: 3)),
    _T('PRC-412', 'JI', TaskType.story, 'Bulk discounts by category', TaskColumn.doing,
        status: 'In Progress', pri: TaskPriority.high, pts: 8, sprint: 'cur', epic: 'PRC-11280', as: 'me', labels: ['api'],
        branch: 'feat/PRC-412-bulk-discounts', comments: 2, updated: Duration(minutes: 20)),
    _T('PRC-398', 'JI', TaskType.bug, 'Rounding error on installment prices', TaskColumn.doing,
        status: 'In Progress', pri: TaskPriority.high, pts: 2, sprint: 'cur', as: 'me', labels: ['bug'], branch: 'fix/PRC-398-rounding', comments: 2, updated: _h),
    _T('PRC-11366', 'JI', TaskType.task, 'Alertas de margen negativo en Grafana', TaskColumn.doing,
        status: 'In Progress', pri: TaskPriority.medium, pts: 3, sprint: 'cur', as: 'nico', labels: ['observability'], comments: 1, updated: Duration(hours: 4)),
    // In review
    _T('PRC-405', 'JI', TaskType.story, 'Warm cache on deploy', TaskColumn.review,
        status: 'Code Review', pri: TaskPriority.medium, pts: 3, sprint: 'cur', as: 'me', branch: 'perf/cache-warmup', comments: 1, updated: _d),
    _T('PRC-11338', 'JI', TaskType.story, 'Validación de márgenes en carga masiva', TaskColumn.review,
        status: 'QA', pri: TaskPriority.medium, pts: 5, sprint: 'cur', epic: 'PRC-11280', as: 'ana', comments: 1, updated: Duration(hours: 6)),
    // Done
    _T('PRC-11340', 'JI', TaskType.task, 'Limpieza de ofertas de canales', TaskColumn.done,
        status: 'Done', pri: TaskPriority.medium, pts: 3, sprint: 'cur', as: 'lucia', comments: 1, updated: Duration(days: 2)),
    _T('PRC-11356', 'JI', TaskType.subtask, 'Migrar job de precios', TaskColumn.done,
        status: 'Done', pri: TaskPriority.low, parent: 'PRC-11355', as: 'me', updated: Duration(days: 4)),
    _T('PRC-377', 'JI', TaskType.bug, 'Fix currency rounding in exports', TaskColumn.done,
        status: 'Done', pri: TaskPriority.medium, pts: 2, sprint: 'prev', as: 'me', updated: Duration(days: 10)),
    _T('td-runbook', 'TD', TaskType.todo, 'Update pricing on-call runbook', TaskColumn.done, key: 'Inbox', pri: TaskPriority.low, as: 'me', updated: Duration(days: 1)),
    // Not on the board: epics, the rest of the sub-tasks, an old duplicate.
    _T('PRC-11300', 'JI', TaskType.epic, 'Migración a Graviton', TaskColumn.doing,
        board: false, status: 'In Progress', pri: TaskPriority.medium, as: 'ana', color: 'violet', subs: ['PRC-11351', 'PRC-11352', 'PRC-11353', 'PRC-11354', 'PRC-11355'], updated: Duration(hours: 5)),
    _T('PRC-11280', 'JI', TaskType.epic, 'Descuentos por volumen', TaskColumn.doing,
        board: false, status: 'In Progress', pri: TaskPriority.medium, as: 'ana', color: 'teal', subs: ['PRC-412', 'PRC-11338'], updated: Duration(hours: 5)),
    _T('PRC-11250', 'JI', TaskType.epic, 'Precios regionales', TaskColumn.todo,
        board: false, status: 'To Do', pri: TaskPriority.medium, as: 'valentina', color: 'amber', subs: ['PRC-11371'], updated: _d),
    _T('PRC-11351', 'JI', TaskType.subtask, 'Migracion a Graviton (Parte 1/4)', TaskColumn.done,
        board: false, status: 'Done', pri: TaskPriority.low, parent: 'PRC-11300', as: 'lucia', updated: Duration(days: 18)),
    _T('PRC-11352', 'JI', TaskType.subtask, 'Migracion a Graviton (Parte 2/4)', TaskColumn.done,
        board: false, status: 'Done', pri: TaskPriority.low, parent: 'PRC-11300', as: 'tomas', updated: Duration(days: 11)),
    _T('PRC-11353', 'JI', TaskType.subtask, 'Migracion a Graviton (Parte 3/4)', TaskColumn.doing,
        board: false, status: 'In Progress', pri: TaskPriority.low, parent: 'PRC-11300', as: 'nico', updated: Duration(hours: 5)),
    _T('PRC-11357', 'JI', TaskType.subtask, 'Analisis', TaskColumn.doing,
        board: false, status: 'In Progress', pri: TaskPriority.low, parent: 'PRC-11355', as: 'me', updated: Duration(hours: 5)),
    _T('PRC-11358', 'JI', TaskType.subtask, 'actualizar planilla', TaskColumn.todo,
        board: false, status: 'To Do', pri: TaskPriority.low, parent: 'PRC-11355', as: 'me', updated: Duration(days: 14)),
    _T('PRC-11359', 'JI', TaskType.subtask, 'verificacion en entornos', TaskColumn.todo,
        board: false, status: 'To Do', pri: TaskPriority.low, parent: 'PRC-11355', as: 'me', updated: Duration(days: 14)),
    _T('PRC-10577', 'JI', TaskType.bug, 'Precios duplicados en canal Hijas', TaskColumn.done,
        board: false, status: 'Done', pri: TaskPriority.medium, as: 'tomas', updated: Duration(days: 29)),
  ];
}

/// One ticket of the design's `ticketData()`.
final class _T {
  const _T(
    this.id,
    this.src,
    this.type,
    this.title,
    this.column, {
    String key = '',
    this.board = true,
    this.status = '',
    this.pri = TaskPriority.none,
    this.pts = 0,
    this.sprint = '',
    this.due,
    this.epic = '',
    this.parent = '',
    this.as = '',
    this.labels = const [],
    this.subs = const [],
    this.blockedBy = const [],
    this.branch = '',
    this.comments = 0,
    this.color = '',
    this.updated = Duration.zero,
  }) : _key = key;

  /// The design's id ("PRC-11355", "ob-aws").
  final String id;
  final String src;
  final TaskType type;
  final String title;
  final TaskColumn column;
  final String _key;
  final bool board;
  final String status;
  final TaskPriority pri;
  final int pts;

  /// "prev", "cur", "next" or empty.
  final String sprint;

  /// Days from today; null = no due date.
  final int? due;
  final String epic;
  final String parent;

  /// The design's person id; empty = unassigned.
  final String as;
  final List<String> labels;
  final List<String> subs;
  final List<String> blockedBy;
  final String branch;
  final int comments;
  final String color;
  final Duration updated;

  String get key => _key.isEmpty ? id : _key;
  String get kumoId => 'mock-$src/$id';
}
