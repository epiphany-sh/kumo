import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/models.dart';
import '../data/tasks_source.dart';
import '../data/workspace_source.dart';
import '../platform/open_url.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';
import 'task_detail/markdown.dart';
import 'task_labels.dart';
import 'task_visuals.dart';

part 'task_detail/actions.dart';
part 'task_detail/sections.dart';

/// The ticket: what it's about (description, acceptance criteria,
/// subtasks, links, attachments, comments, fields) and, pinned at the
/// bottom, what to do with it (move it, start it in a worktree, the
/// worktrees it's being worked on in).
///
/// Shows what's known at once (the last detail fetched, else the board's
/// card) and asks the source for the rest ([TasksSource.getTask]). The
/// board owns selection, history and the keyboard: this panel calls back.
class TaskDetailPanel extends StatefulWidget {
  const TaskDetailPanel({
    super.key,
    required this.taskId,
    this.expanded = false,
    this.canGoBack = false,
    this.onBack,
    required this.onOpen,
    required this.onExpand,
    required this.onClose,
    this.onStep,
  });

  /// Any task id, also of tickets that aren't on the board (epics,
  /// sub-tasks, linked issues).
  final String taskId;

  /// The large two-column view inside Tasks.
  final bool expanded;
  final bool canGoBack;
  final VoidCallback? onBack;

  /// Opens another ticket (epic, parent, sub-task, linked issue, a key in
  /// the text), keeping history.
  final ValueChanged<String> onOpen;

  /// ⤢ (true) or back to the side panel (false).
  final ValueChanged<bool> onExpand;
  final VoidCallback onClose;

  /// The header's ↑ (-1) and ↓ (+1); null disables them.
  final ValueChanged<int>? onStep;

  @override
  State<TaskDetailPanel> createState() => _TaskDetailState();
}

/// Sources Kumo reaches over the network: they can be offline.
bool _remote(TaskSourceKind k) => k == TaskSourceKind.jira || k == TaskSourceKind.github || k == TaskSourceKind.todoist;

class _TaskDetailState extends State<TaskDetailPanel> {
  TasksSource? _tasks;
  TaskDetail? _detail;
  bool _loading = false;
  String? _loadError;
  int _gen = 0;

  // Per ticket.
  bool _descMore = false;
  bool _allComments = false;
  bool _agentInfo = false;
  bool _formOpen = false;
  bool _copied = false;
  Timer? _copiedTimer;
  bool _moving = false;
  String? _error;

  // The start form.
  String? _repo;
  String _base = '';
  String? _agent;
  bool _agentOn = true;
  bool _busy = false;
  RepoBranches? _branches;
  final _branch = TextEditingController();
  String _branchFor = '';
  final _scroll = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tasks != null) return;
    final s = AppScope.read(context);
    _tasks = s.tasks;
    _open(widget.taskId);
    final repos = s.workspace.repos;
    final active = s.activeRepo;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pickRepo(active != null && repos.any((r) => r.id == active.id) ? active.id : repos.firstOrNull?.id);
    });
  }

  @override
  void didUpdateWidget(TaskDetailPanel old) {
    super.didUpdateWidget(old);
    if (old.taskId != widget.taskId) {
      _descMore = false;
      _allComments = false;
      _agentInfo = false;
      _formOpen = false;
      _copied = false;
      _moving = false;
      _error = null;
      _open(widget.taskId);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _gen++;
    _copiedTimer?.cancel();
    _branch.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// For the part files' extensions ([setState] is protected).
  void _set(VoidCallback fn) => setState(fn);

  /// Shows what's cached for [id] and asks the source for the rest.
  void _open(String id) {
    _detail = _tasks!.cachedDetail(id);
    _loadError = null;
    _loading = true;
    _syncBranch(_tasks!.tasks.where((t) => t.id == id).firstOrNull ?? _detail?.task);
    _fetch(id, ++_gen, refresh: false);
  }

  /// The start form suggests the ticket's branch, once per ticket.
  void _syncBranch(TaskEntry? task) {
    if (task == null || _branchFor == task.id) return;
    _branchFor = task.id;
    _branch.text = task.suggestedBranch;
  }

  Future<void> _fetch(String id, int gen, {required bool refresh}) async {
    TaskDetail? detail;
    String? error;
    try {
      detail = await _tasks!.getTask(id, refresh: refresh);
    } on Object catch (e) {
      error = '$e';
    }
    if (!mounted || gen != _gen) return;
    setState(() {
      _loading = false;
      if (detail != null) _detail = detail;
      _loadError = error;
      _syncBranch(_detail?.task);
    });
  }

  void _retry() {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _fetch(widget.taskId, ++_gen, refresh: true);
  }

  Future<void> _pickRepo(String? id) async {
    setState(() {
      _repo = id;
      _branches = null;
    });
    final s = AppScope.read(context);
    final repo = id == null ? null : s.workspace.repo(id);
    if (repo == null) return;
    final branches = await s.workspace.branches(repo);
    if (!mounted || _repo != id) return;
    setState(() {
      _branches = branches;
      _base = branches?.current ?? '';
    });
  }

  /// The card as fresh as it gets: the board's (moves show at once), else
  /// the detail's.
  TaskEntry? _entry(TasksSource tasks) => tasks.tasks.where((t) => t.id == widget.taskId).firstOrNull ?? _detail?.task;

  /// The id to open [ref] with.
  String _refId(TaskRef ref, TaskEntry? task) {
    if (ref.id.isNotEmpty) return ref.id;
    final slash = widget.taskId.indexOf('/');
    final source = task?.sourceId ?? (slash > 0 ? widget.taskId.substring(0, slash) : widget.taskId);
    return '$source/${ref.key}';
  }

  void _openRef(TaskRef ref, TaskEntry? task) => widget.onOpen(_refId(ref, task));

  /// A key in the text ("PRC-11300"), in the current ticket's source.
  void _openKey(String key, TaskEntry? task) => _openRef(TaskRef(key: key, title: key), task);

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(listenable: s.tasks, builder: (context, _) => _build(context, s));
  }

  Widget _build(BuildContext context, AppState s) {
    final c = context.c;
    final task = _entry(s.tasks);
    final v = _View.of(this, s, task);
    final header = _Header(state: this, view: v);
    if (widget.expanded) {
      return GlassPanel(
        clip: true,
        radius: 20,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          Divider(height: 1, thickness: 1, color: c.divider),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Scrollbar(
                  controller: _scroll,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _gapped(_mainSections(v), 22)),
                      ),
                    ),
                  ),
                ),
              ),
              Container(width: 1, color: c.divider),
              SizedBox(
                width: 368,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 18, 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (task != null) ..._actions(v),
                    if (!v.loading && task != null) ...[
                      const SizedBox(height: 18),
                      Divider(height: 1, thickness: 1, color: c.divider),
                      const SizedBox(height: 18),
                      ..._gapped(_metaSections(v), 16),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      );
    }
    return GlassPanel(
      clip: true,
      radius: 20,
      child: LayoutBuilder(builder: (context, box) {
        final footMax = math.min(430.0, box.maxHeight * 0.62);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          Divider(height: 1, thickness: 1, color: c.divider),
          Expanded(
            child: Scrollbar(
              controller: _scroll,
              child: SingleChildScrollView(
                key: const ValueKey('task-detail-body'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _gapped(_panelSections(v), 20)),
              ),
            ),
          ),
          if (task != null)
            Container(
              key: const ValueKey('task-detail-footer'),
              constraints: BoxConstraints(maxHeight: footMax),
              decoration: BoxDecoration(color: c.panelStrong, border: Border(top: BorderSide(color: c.divider))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: _actions(v)),
              ),
            ),
        ]);
      }),
    );
  }

  /// The side panel's scrolling content, in the design's order.
  List<Widget> _panelSections(_View v) => [
        ..._notices(v),
        if (v.loading)
          _Loading(text: v.loadingText)
        else if (v.task == null)
          _LoadFailed(keyText: v.key, error: _loadError ?? 'Unknown task', onRetry: _retry)
        else ...[
          ..._metaSections(v),
          if (v.offBasic) const _NotSavedYet(),
          ..._contentSections(v),
        ],
      ];

  /// The large view's left column.
  List<Widget> _mainSections(_View v) => [
        ..._notices(v),
        if (v.loading)
          _Loading(text: v.loadingText)
        else if (v.task == null)
          _LoadFailed(keyText: v.key, error: _loadError ?? 'Unknown task', onRetry: _retry)
        else ...[
          if (v.offBasic) const _NotSavedYet(),
          ..._contentSections(v),
        ],
      ];

  List<Widget> _notices(_View v) => [
        if (v.offline) _OfflineNotice(view: v, onRetry: _retry),
        if (v.blockers.isNotEmpty) _BlockedBanner(blockers: v.blockers, onOpen: () => _openRef(v.blockers.first, v.task)),
      ];

  List<Widget> _metaSections(_View v) => [
        if (v.people.isNotEmpty) _People(people: v.people),
        _Fields(view: v, onOpen: (ref) => _openRef(ref, v.task)),
        if (v.time != null && v.detail != null) _TimeBar(time: v.time!),
      ];

  List<Widget> _contentSections(_View v) {
    final d = v.detail;
    if (d == null) return const [];
    final md = MdStyle(onOpenKey: v.task!.kind == TaskSourceKind.jira ? (k) => _openKey(k, v.task) : null, mentions: v.mentions, keyProjects: v.keyProjects);
    return [
      if (d.acceptanceCriteria.trim().isNotEmpty) _AcceptanceCriteria(source: d.acceptanceCriteria, style: md),
      _Description(
        heading: v.task!.kind == TaskSourceKind.obsidian ? 'From ${v.task!.key}' : 'Description',
        source: d.description,
        style: md,
        collapsible: !widget.expanded,
        open: _descMore,
        onToggle: () => setState(() => _descMore = !_descMore),
      ),
      if (d.subtasks.isNotEmpty) _Subtasks(epic: v.task!.type == TaskType.epic, subtasks: d.subtasks, onOpen: (r) => _openRef(r, v.task)),
      if (d.links.isNotEmpty) _Links(links: d.links, onOpen: (r) => _openRef(r, v.task)),
      if (d.attachments.isNotEmpty) _Attachments(attachments: d.attachments, kindLabel: v.task!.kind.label, fallbackUrl: v.task!.url),
      if (v.hasComments)
        _Comments(
          comments: d.comments,
          all: _allComments,
          onToggle: () => setState(() => _allComments = !_allComments),
          style: md,
          kindLabel: v.task!.kind.label,
          url: v.task!.url,
        ),
    ];
  }
}

List<Widget> _gapped(List<Widget> items, double gap) => [
      for (var i = 0; i < items.length; i++) ...[if (i > 0) SizedBox(height: gap), items[i]],
    ];

/// What the panel shows, worked out once per build.
class _View {
  _View({
    required this.task,
    required this.detail,
    required this.source,
    required this.key,
    required this.loading,
    required this.offBasic,
    required this.stale,
    required this.error,
  });

  factory _View.of(_TaskDetailState st, AppState s, TaskEntry? task) {
    final detail = st._detail;
    final id = st.widget.taskId;
    final key = task?.key ?? (id.contains('/') ? id.substring(id.indexOf('/') + 1) : id);
    final hasData = detail != null;
    return _View(
      task: task,
      detail: detail,
      source: task == null ? null : s.tasks.source(task.sourceId),
      key: key,
      loading: !hasData && st._loading,
      offBasic: !hasData && !st._loading && st._loadError != null && task != null,
      stale: detail?.stale ?? false,
      error: st._loadError,
    );
  }

  final TaskEntry? task;
  final TaskDetail? detail;
  final TaskSourceInfo? source;
  final String key;

  /// Nothing fetched yet, and the source is being asked.
  final bool loading;

  /// The source couldn't answer and nothing was ever fetched: the card's
  /// fields only.
  final bool offBasic;

  /// The daemon's saved copy: the source couldn't be reached.
  final bool stale;
  final String? error;

  bool get offline => offBasic || stale;

  /// Moving writes to the tool: not while it's unreachable.
  bool get moveBlocked => offline && task != null && _remote(task!.kind);

  String get kindLabel => task?.kind.label ?? 'the source';
  String get sourceName => source?.name ?? task?.kind.label ?? '';

  String get loadingText => 'Loading $key from $kindLabel…';

  bool get isJira => task?.kind == TaskSourceKind.jira;
  bool get isGitHub => task?.kind == TaskSourceKind.github;

  bool get hasComments => task != null && task!.kind != TaskSourceKind.obsidian && task!.kind != TaskSourceKind.bear;

  TimeTracking? get time => detail?.timeTracking;

  /// (role, person) of the ticket; personal tasks have none.
  List<(String, TaskPerson?)> get people => [
        if (isJira) ...[('Assignee', task!.assignee), ('Reporter', detail?.reporter)],
        if (isGitHub) ...[('Assignee', task!.assignee), ('Opened by', detail?.reporter)],
      ];

  /// Issues that block this one and aren't done.
  List<TaskRef> get blockers => [
        for (final l in detail?.links ?? const <LinkedTask>[])
          if (l.kind == LinkKind.blockedBy && l.task.column != TaskColumn.done) l.task,
      ];

  List<String> get mentions => {
        if (task?.assignee != null) task!.assignee!.name,
        if (detail?.reporter != null) detail!.reporter!.name,
        for (final c in detail?.comments ?? const <TaskComment>[]) c.author.name,
      }.toList();

  /// Projects whose keys in the text open in the panel: this ticket's and
  /// those of the tickets it mentions.
  Set<String> get keyProjects {
    String? project(String key) {
      final m = RegExp(r'^([A-Z][A-Z0-9]{1,9})-\d+$').firstMatch(key);
      return m?.group(1);
    }

    return {
      for (final k in [
        if (task != null) task!.key,
        if (task?.parent != null) task!.parent!.key,
        for (final s in detail?.subtasks ?? const <TaskRef>[]) s.key,
        for (final l in detail?.links ?? const <LinkedTask>[]) l.task.key,
      ])
        if (project(k) case final p?) p,
    };
  }

  /// "Created Oct 14, 2026 · Updated 3 h ago".
  String get stamp {
    final created = detail?.created;
    if (created == null || offBasic) return '';
    final updated = task?.updated;
    return '${isGitHub ? 'Opened' : 'Created'} ${shortDate(created)}, ${created.year}${updated == null ? '' : ' · Updated ${relativeTime(updated)}'}';
  }
}
