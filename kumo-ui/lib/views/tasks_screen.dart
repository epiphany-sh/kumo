import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/agents_source.dart';
import '../data/models.dart';
import '../data/tasks_source.dart';
import '../data/workspace_source.dart';
import '../overlays/settings_dialog.dart';
import '../platform/open_url.dart';
import '../shell/screen_chrome.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/kicons.dart';

/// One board for every task source (Obsidian, Bear, GitHub, Jira,
/// Todoist), served from the engine's cache. The selected task on the
/// right, with "start in a worktree".
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

const _columns = [
  (TaskColumn.todo, 'To do'),
  (TaskColumn.doing, 'In progress'),
  (TaskColumn.review, 'In review'),
  (TaskColumn.done, 'Done'),
];

/// For the narrow "Move to" control.
const _shortColumns = [
  (TaskColumn.todo, 'To do'),
  (TaskColumn.doing, 'Doing'),
  (TaskColumn.review, 'Review'),
  (TaskColumn.done, 'Done'),
];

String _columnName(TaskColumn column) => _columns.firstWhere((c) => c.$1 == column).$2;

class _TasksScreenState extends State<TasksScreen> {
  String _source = 'all';
  String? _selected;
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Tasks matching the source chip and every word of the search.
  List<TaskEntry> _visible(List<TaskEntry> tasks) {
    final words = _query.text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return [
      for (final t in tasks)
        if ((_source == 'all' || t.sourceId == _source) &&
            words.every((w) => t.title.toLowerCase().contains(w) || t.key.toLowerCase().contains(w) || t.context.toLowerCase().contains(w) || t.labels.any((l) => l.toLowerCase().contains(w))))
          t,
    ];
  }

  void _openSettings() => showSettingsDialog(context, initial: SettingsTab.tickets);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(listenable: s.tasks, builder: (context, _) => _build(context, s, s.tasks));
  }

  Widget _build(BuildContext context, AppState s, TasksSource source) {
    final c = context.c;
    final sources = source.sources;
    if (_source != 'all' && source.source(_source) == null) _source = 'all';
    final visible = _visible(source.tasks);
    final selected = source.tasks.where((t) => t.id == _selected).firstOrNull;
    final linked = {for (final l in source.links) l.taskId};
    final syncing = sources.any((x) => x.syncing);
    final subtitle = sources.isEmpty
        ? 'Connect where your tasks live: Obsidian, Bear, GitHub, Jira, Todoist'
        : '${sources.map((x) => x.name).join(', ')} · ${_syncNote(sources)}';

    return ScreenFrame(
      toolbar: ScreenToolbar(
        breadcrumb: Breadcrumb(icon: KIcons.tasks, parts: ['Tasks', sources.isEmpty ? 'No sources yet' : '${sources.length} sources']),
        primary: sources.isEmpty
            ? KButton.primary(label: 'Connect a source', icon: KIcons.add, height: 36, onTap: _openSettings)
            : KButton.primary(label: syncing ? 'Syncing…' : 'Sync now', icon: KIcons.download, height: 36, onTap: syncing ? null : () => source.sync()),
      ),
      body: LayoutBuilder(builder: (context, box) {
        final showDetail = box.maxWidth >= 900 && selected != null;
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Section(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('Tasks', style: sans(22, weight: FontWeight.w600, color: c.text, letterSpacing: -0.4)),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text3)),
                  ]),
                  if (sources.isNotEmpty)
                    Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      SizedBox(width: 200, child: _SearchField(controller: _query)),
                      _SourceChip(k: '∗', label: 'All', count: source.tasks.length, selected: _source == 'all', onTap: () => setState(() => _source = 'all')),
                      for (final x in sources)
                        _SourceChip(
                          k: x.kind.badge,
                          label: x.name,
                          count: x.taskCount,
                          selected: _source == x.id,
                          warn: x.error.isNotEmpty,
                          onTap: () => setState(() => _source = x.id),
                        ),
                    ]),
                ]),
                for (final x in sources)
                  if (x.error.isNotEmpty && (_source == 'all' || _source == x.id)) _SourceError(source: x, onFix: _openSettings, onRetry: () => source.sync(x.id)),
                if (source.error != null) ...[
                  const SizedBox(height: 8),
                  Text(source.error!, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(12, color: c.err)),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: sources.isEmpty
                      ? _Empty(onConnect: _openSettings)
                      : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          for (var i = 0; i < _columns.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(
                              child: _Column(
                                label: _columns[i].$2,
                                color: switch (_columns[i].$1) {
                                  TaskColumn.todo => c.text3,
                                  TaskColumn.doing => c.acc,
                                  TaskColumn.review => c.warn,
                                  TaskColumn.done => c.ok,
                                },
                                tasks: _sorted([for (final t in visible) if (t.column == _columns[i].$1) t]),
                                selected: _selected,
                                links: source,
                                runs: s.agents.runs,
                                onSelect: (t) => setState(() => _selected = _selected == t.id ? null : t.id),
                              ),
                            ),
                          ],
                        ]),
                ),
              ]),
            ),
          ),
          if (showDetail) ...[
            const SizedBox(width: 10),
            SizedBox(width: 360, child: _TaskDetail(key: ValueKey(selected.id), task: selected, onClose: () => setState(() => _selected = null))),
          ],
        ]);
      }),
      status: [
        StatusText('${source.tasks.length} tasks · ${source.tasks.where((t) => linked.contains(t.id)).length} in worktrees'),
        if (sources.where((x) => x.error.isNotEmpty).length case final failing when failing > 0)
          StatusText(failing == 1 ? '1 source failing' : '$failing sources failing', color: c.err)
        else if (sources.isNotEmpty)
          StatusText(_syncNote(sources)),
        const Spacer(),
        const StatusText('Moving a task updates its app'),
      ],
    );
  }

  /// Most urgent first, then the nearest due date, then the latest change.
  static List<TaskEntry> _sorted(List<TaskEntry> tasks) => tasks
    ..sort((a, b) {
      final p = b.priority.index.compareTo(a.priority.index);
      if (p != 0) return p;
      final due = (a.due.isEmpty ? '9999' : a.due).compareTo(b.due.isEmpty ? '9999' : b.due);
      if (due != 0) return due;
      return (b.updated ?? DateTime(0)).compareTo(a.updated ?? DateTime(0));
    });

  static String _syncNote(List<TaskSourceInfo> sources) {
    if (sources.any((x) => x.syncing)) return 'syncing…';
    final times = [for (final x in sources) if (x.lastSynced != null) x.lastSynced!]..sort();
    return times.isEmpty ? 'not synced yet' : _ago(times.first);
  }
}

String _ago(DateTime? at) {
  if (at == null) return 'not synced yet';
  final d = DateTime.now().difference(at);
  if (d.inSeconds < 60) return 'synced just now';
  if (d.inMinutes < 60) return 'synced ${d.inMinutes} min ago';
  if (d.inHours < 24) return 'synced ${d.inHours} h ago';
  return 'synced ${d.inDays} d ago';
}

String _priorityLabel(TaskPriority p) => switch (p) {
      TaskPriority.urgent => 'Urgent',
      TaskPriority.high => 'High',
      TaskPriority.medium => 'Med',
      TaskPriority.low => 'Low',
      TaskPriority.none => '',
    };

/// The latest agent run in [worktree], if any.
AgentRun? _runIn(List<AgentRun> runs, String worktree) {
  AgentRun? latest;
  for (final r in runs) {
    if (r.worktreePath == worktree && (latest == null || r.startedAt.isAfter(latest.startedAt))) latest = r;
  }
  return latest;
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(15), border: Border.all(color: c.chipBorder)),
      child: Row(children: [
        Icon(KIcons.search, size: 13, color: c.text3),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: controller,
            style: sans(12, color: c.text),
            cursorColor: c.acc,
            decoration: const InputDecoration.collapsed(hintText: 'Filter tasks'),
          ),
        ),
      ]),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.k, required this.label, required this.count, required this.selected, required this.onTap, this.warn = false});
  final String k;
  final String label;
  final int count;
  final bool selected;
  final bool warn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: 'Filter $label',
      builder: (context, hover, focus) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 30,
        padding: const EdgeInsets.fromLTRB(5, 0, 11, 0),
        decoration: BoxDecoration(
          color: selected ? c.tabActive : (hover ? c.tile : null),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: selected ? c.chipBorder : c.paneBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SourceTile(k, size: 20),
          const SizedBox(width: 6),
          Text(label, style: sans(12, weight: FontWeight.w500, color: selected ? c.text : c.text2)),
          const SizedBox(width: 6),
          if (warn) Icon(KIcons.warning, size: 12, color: c.err) else Text('$count', style: sans(11, color: c.text3)),
        ]),
      ),
    );
  }
}

class _SourceError extends StatelessWidget {
  const _SourceError({required this.source, required this.onFix, required this.onRetry});
  final TaskSourceInfo source;
  final VoidCallback onFix;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: c.errSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(KIcons.warning, size: 14, color: c.err),
        const SizedBox(width: 8),
        Expanded(
          child: Text('${source.name}: ${source.error}', maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text)),
        ),
        KButton(label: 'Retry', height: 26, fontSize: 12, kind: KButtonKind.ghost, onTap: onRetry),
        const SizedBox(width: 6),
        KButton(label: 'Settings', height: 26, fontSize: 12, onTap: onFix),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onConnect});
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 6, children: [for (final k in TaskSourceKind.values) SourceTile(k.badge, size: 30, tooltip: k.label)]),
          const SizedBox(height: 14),
          Text('Bring your tasks in', style: sans(16, weight: FontWeight.w600, color: c.text)),
          const SizedBox(height: 6),
          Text(
            'Checkboxes from an Obsidian vault or Bear, GitHub issues, Jira or Todoist. Kumo keeps them on this Mac, so the board opens instantly, and can start a worktree with an agent from any of them.',
            textAlign: TextAlign.center,
            style: sans(12.5, color: c.text2, height: 1.5),
          ),
          const SizedBox(height: 16),
          KButton.primary(label: 'Connect a source', icon: KIcons.add, height: 34, onTap: onConnect),
        ]),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.label, required this.color, required this.tasks, required this.selected, required this.links, required this.runs, required this.onSelect});
  final String label;
  final Color color;
  final List<TaskEntry> tasks;
  final String? selected;
  final TasksSource links;
  final List<AgentRun> runs;
  final ValueChanged<TaskEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Row(children: [
          Dot(color, size: 8, ring: true),
          const SizedBox(width: 8),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: FontWeight.w600, color: c.text))),
          const SizedBox(width: 8),
          Text('${tasks.length}', style: sans(11.5, color: c.text3)),
        ]),
      ),
      Expanded(
        // Lazy: a source can bring thousands of tasks.
        child: ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, i) {
            final t = tasks[i];
            final link = links.linksOf(t.id).lastOrNull;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TaskCard(
                task: t,
                selected: t.id == selected,
                link: link,
                run: link == null ? null : _runIn(runs, link.worktreePath),
                onTap: () => onSelect(t),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.selected, required this.onTap, this.link, this.run});
  final TaskEntry task;
  final bool selected;
  final TaskLinkInfo? link;
  final AgentRun? run;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = task;
    final prio = _priorityLabel(t.priority);
    final prioColor = t.priority.index >= TaskPriority.high.index ? c.warn : c.text3;
    final needsYou = run?.status == AgentStatus.needsYou;
    final meta = [if (t.context.isNotEmpty) t.context, if (t.due.isNotEmpty) 'due ${t.due}', for (final l in t.labels.take(2)) '#$l'].join(' · ');
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '${t.key} ${t.title}',
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.pane,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? c.acc : (hover || focus ? c.chipBorder : c.paneBorder)),
          boxShadow: selected ? [BoxShadow(color: c.accSoft, spreadRadius: 3)] : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            TagChip(t.kind.badge),
            const SizedBox(width: 6),
            Flexible(child: Text(t.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text2))),
            const Spacer(),
            if (prio.isNotEmpty) Text(prio, style: sans(11, weight: FontWeight.w600, color: prioColor)),
          ]),
          const SizedBox(height: 8),
          Text(t.title, maxLines: 4, overflow: TextOverflow.ellipsis, style: sans(13, weight: FontWeight.w500, color: c.text, height: 1.35)),
          if (link != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (run != null)
                  Row(children: [
                    Dot(needsYou ? c.warn : (run!.status == AgentStatus.done ? c.text3 : c.acc), size: 6),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${run!.providerName} · ${switch (run!.status) { AgentStatus.needsYou => 'needs you', AgentStatus.done => 'finished', _ => 'working' }}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: sans(11.5, weight: FontWeight.w600, color: needsYou ? c.warn : c.acc),
                      ),
                    ),
                  ]),
                Text(link!.branch, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(10.5, color: c.text3)),
              ]),
            ),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3)),
          ],
        ]),
      ),
    );
  }
}

/// The selected task: its fields, where it can move, and the worktrees it
/// is being worked on in (or the form to start one).
class _TaskDetail extends StatefulWidget {
  const _TaskDetail({super.key, required this.task, required this.onClose});
  final TaskEntry task;
  final VoidCallback onClose;

  @override
  State<_TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends State<_TaskDetail> {
  String? _repo;
  String _base = '';
  String? _agent;
  bool _agentOn = true;
  bool _busy = false;
  bool _moving = false;
  String? _error;
  RepoBranches? _branches;
  late final _branch = TextEditingController(text: widget.task.suggestedBranch);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppScope.read(context);
      final repos = s.workspace.repos;
      final active = s.activeRepo;
      _pickRepo(active != null && repos.any((r) => r.id == active.id) ? active.id : repos.firstOrNull?.id);
    });
  }

  @override
  void dispose() {
    _branch.dispose();
    super.dispose();
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

  Future<void> _move(TasksSource tasks, TaskColumn column) async {
    setState(() {
      _moving = true;
      _error = null;
    });
    final ok = await tasks.setStatus(widget.task.id, column);
    if (!mounted) return;
    setState(() {
      _moving = false;
      if (!ok) _error = tasks.error;
    });
  }

  Future<void> _start(AppState s, Repo repo) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      error = await s.startTask(
        widget.task,
        repo: repo,
        branch: _branch.text.trim(),
        base: _base,
        agent: _agentOn,
        providerId: _agent,
      );
    } on Object catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final t = widget.task;
    final source = s.tasks.source(t.sourceId);
    final links = s.tasks.linksOf(t.id);
    final writable = source?.writable ?? const <TaskColumn>{};
    return ListView(padding: EdgeInsets.zero, children: [
      Section(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            TagChip(t.kind.badge),
            const SizedBox(width: 8),
            Flexible(child: Text(t.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(12, weight: FontWeight.w500, color: c.text))),
            const SizedBox(width: 8),
            Text(source?.name ?? t.kind.label, style: sans(12, color: c.text3)),
            const Spacer(),
            if (t.url.isNotEmpty) KIconButton(icon: KIcons.external, label: 'Open in ${t.kind.label}', onTap: () => openUrl(t.url)),
            KIconButton(icon: KIcons.close, label: 'Close', onTap: widget.onClose),
          ]),
          const SizedBox(height: 10),
          SelectableText(t.title, style: sans(17, weight: FontWeight.w600, color: c.text, letterSpacing: -0.3, height: 1.3)),
          const SizedBox(height: 14),
          Wrap(runSpacing: 10, children: [
            for (final (k, v) in [
              ('Status', _columnName(t.column)),
              ('Priority', _priorityLabel(t.priority).isEmpty ? '—' : _priorityLabel(t.priority)),
              ('Due', t.due.isEmpty ? '—' : t.due),
              ('In', t.context.isEmpty ? '—' : t.context),
            ])
              FractionallySizedBox(
                widthFactor: 0.5,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(k, style: sans(11, color: c.text3)),
                  Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13, weight: FontWeight.w500, color: c.text)),
                ]),
              ),
          ]),
          if (t.labels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final l in t.labels) TagChip('#$l')]),
          ],
          const SizedBox(height: 14),
          Text('Move to', style: sans(11, color: c.text3)),
          const SizedBox(height: 6),
          if (writable.isEmpty)
            Text('${t.kind.label} tasks are read only here: change them in ${t.kind.label}.', style: sans(12, color: c.text3))
          else
            Opacity(
              opacity: _moving ? 0.6 : 1,
              child: KSegmented<TaskColumn>(
                expand: true,
                label: 'Move to',
                value: t.column,
                items: [for (final (col, name) in _shortColumns) if (writable.contains(col) || col == t.column) (col, name, null)],
                onChanged: (col) {
                  if (!_moving && col != t.column && writable.contains(col)) _move(s.tasks, col);
                },
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Section(strong: true, child: links.isEmpty ? _startForm(s) : _worktrees(s, links)),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, maxLines: 4, overflow: TextOverflow.ellipsis, style: sans(12, color: c.err)),
      ],
    ]);
  }

  Widget _startForm(AppState s) {
    final c = context.c;
    final repos = s.workspace.repos;
    final repo = _repo == null ? null : s.workspace.repo(_repo!);
    final agents = s.agents.connected;
    final bases = _branches == null ? <String>[if (_base.isNotEmpty) _base] : [_branches!.current, for (final l in _branches!.local) if (l != _branches!.current) l];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(KIcons.agent, size: 16, color: c.acc),
        const SizedBox(width: 8),
        Text('Start in a worktree', style: sans(13, weight: FontWeight.w600, color: c.text)),
      ]),
      const SizedBox(height: 12),
      if (repos.isEmpty)
        Text('Add a repository to a namespace first: the worktree is created in it.', style: sans(12, color: c.text3))
      else ...[
        Row(children: [
          Expanded(
            child: KSelect<String>(
              label: 'Repository',
              value: _repo ?? repos.first.id,
              items: [for (final r in repos) (r.id, r.name)],
              onChanged: _pickRepo,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: bases.where((b) => b.isNotEmpty).isEmpty
                ? KField(label: 'Base branch', controller: TextEditingController(text: '…'), monospace: true)
                : KSelect<String>(
                    label: 'Base branch',
                    monospace: true,
                    value: _base.isEmpty ? bases.first : _base,
                    items: [for (final b in bases) if (b.isNotEmpty) (b, b)],
                    onChanged: (v) => setState(() => _base = v),
                  ),
          ),
        ]),
        const SizedBox(height: 10),
        KField(label: 'New branch', controller: _branch, monospace: true),
        const SizedBox(height: 10),
        Row(children: [
          KSwitch(value: _agentOn && agents.isNotEmpty, onChanged: agents.isEmpty ? (_) {} : (v) => setState(() => _agentOn = v), label: 'Start an agent'),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              agents.isEmpty ? 'No agent connected: just the worktree' : 'Start an agent with the task as its prompt',
              style: sans(12, color: c.text2),
            ),
          ),
        ]),
        if (_agentOn && agents.isNotEmpty) ...[
          const SizedBox(height: 10),
          KSelect<String>(
            label: 'Agent',
            value: _agent != null && agents.any((a) => a.id == _agent) ? _agent! : agents.first.id,
            items: [for (final a in agents) (a.id, a.name)],
            onChanged: (v) => setState(() => _agent = v),
          ),
        ],
        const SizedBox(height: 12),
        KButton.primary(
          label: _busy ? 'Creating…' : (_agentOn && agents.isNotEmpty ? 'Create worktree and start agent' : 'Create worktree'),
          expand: true,
          height: 36,
          onTap: _busy || repo == null || _branch.text.trim().isEmpty ? null : () => _start(s, repo),
        ),
      ],
    ]);
  }

  Widget _worktrees(AppState s, List<TaskLinkInfo> links) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(KIcons.branch, size: 16, color: c.acc),
        const SizedBox(width: 8),
        Text('Being worked on', style: sans(13, weight: FontWeight.w600, color: c.text)),
      ]),
      const SizedBox(height: 10),
      for (final link in links) ...[
        Builder(builder: (context) {
          final run = _runIn(s.agents.runs, link.worktreePath);
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(link.branch, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(12, weight: FontWeight.w500, color: c.text)),
              Text(link.worktreePath, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3)),
              if (run != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${run.providerName} · ${switch (run.status) { AgentStatus.needsYou => 'needs you', AgentStatus.done => 'finished', _ => 'working' }}${run.lastLine.isEmpty ? '' : ' · ${run.lastLine}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: sans(12, color: run.status == AgentStatus.needsYou ? c.warn : c.text2),
                ),
              ],
              const SizedBox(height: 10),
              Row(children: [
                if (run != null && run.status != AgentStatus.done)
                  KButton(label: 'Open terminal', icon: KIcons.terminal, height: 28, fontSize: 12, onTap: () => s.openTerminal(run.terminalId, title: run.title, agent: true)),
                const Spacer(),
                KButton(label: 'Unlink', height: 28, fontSize: 12, kind: KButtonKind.ghost, onTap: () => s.tasks.unlink(widget.task.id, link.worktreePath)),
              ]),
            ]),
          );
        }),
        const SizedBox(height: 8),
      ],
    ]);
  }
}
