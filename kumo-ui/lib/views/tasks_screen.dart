import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/agents_source.dart';
import '../data/mock_tasks.dart';
import '../data/models.dart';
import '../data/tasks_source.dart';
import '../overlays/settings_dialog.dart';
import '../shell/screen_chrome.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/kicons.dart';
import 'task_detail.dart';
import 'task_labels.dart';
import 'task_visuals.dart';

/// One board for every task source (Obsidian, Bear, GitHub, Jira,
/// Todoist), served from the engine's cache. Mine by default, Everyone on
/// request; the selected ticket opens in a 440 px panel beside the board,
/// or over the whole view when expanded.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  /// Preference: "mine" or "everyone".
  static const scopeSetting = 'tasks.scope';

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

/// Narrowest a column gets; below it the board scrolls sideways.
const _minColumn = 232.0;
const _columnGap = 12.0;
const _panelWidth = 440.0;

/// Below this, an open ticket takes the whole view.
const _sideBySide = _panelWidth + 10 + 320;

class _TasksScreenState extends State<TasksScreen> {
  String _source = 'all';
  String? _selected;
  bool _expanded = false;
  final _history = <String>[];
  final _query = TextEditingController();
  final _keys = FocusNode(debugLabel: 'Tasks board');
  /// Built cards by task id, to scroll one into view. (Not GlobalKeys:
  /// cards move between list slots and columns.)
  final _cards = <String, BuildContext>{};
  final _scrollers = {for (final (col, _) in taskColumns) col: ScrollController()};
  final _sideways = ScrollController();

  /// Visible tickets in board order (columns left to right, top to bottom),
  /// as last built: what ↑ and ↓ walk.
  List<TaskEntry> _order = const [];

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _keys.dispose();
    for (final s in _scrollers.values) {
      s.dispose();
    }
    _sideways.dispose();
    super.dispose();
  }

  // ---- Selection ----

  /// Opens [id] in the panel. [push]: from a link in the panel, so "back"
  /// returns to the current one; otherwise the history starts over.
  void _select(String id, {bool push = false}) {
    setState(() {
      if (push && _selected != null && _selected != id) {
        _history.add(_selected!);
      } else if (!push) {
        _history.clear();
      }
      _selected = id;
    });
  }

  void _back() {
    if (_history.isEmpty) return;
    setState(() => _selected = _history.removeLast());
  }

  void _close() {
    setState(() {
      _selected = null;
      _history.clear();
      _expanded = false;
    });
    _keys.requestFocus();
  }

  void _pick(TaskEntry t) {
    if (_selected == t.id) {
      _close();
    } else {
      _select(t.id);
      _keys.requestFocus();
    }
  }

  /// ↑ (-1) / ↓ (+1): the previous or next visible ticket. A ticket opened
  /// from a link steps from the board ticket it was opened from.
  bool _step(int delta) {
    final sel = _selected;
    if (sel == null || _order.isEmpty) return false;
    var at = _order.indexWhere((t) => t.id == sel);
    if (at < 0 && _history.isNotEmpty) at = _order.indexWhere((t) => t.id == _history.first);
    final TaskEntry? next;
    if (at < 0) {
      next = delta > 0 ? _order.first : _order.last;
    } else {
      final i = at + delta;
      next = i >= 0 && i < _order.length ? _order[i] : null;
    }
    if (next == null) return true;
    _select(next.id);
    _reveal(next, delta);
    return true;
  }

  /// Esc: collapses the expanded view, or closes the panel.
  bool _escape() {
    if (_selected == null) return false;
    if (_expanded) {
      setState(() => _expanded = false);
    } else {
      _close();
    }
    return true;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final hw = HardwareKeyboard.instance;
    if (hw.isMetaPressed || hw.isControlPressed || hw.isAltPressed) return KeyEventResult.ignored;
    final focus = FocusManager.instance.primaryFocus;
    final typing = focus?.context?.findAncestorStateOfType<EditableTextState>() != null;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (e is KeyRepeatEvent) return KeyEventResult.handled;
      if (typing) {
        _keys.requestFocus();
        return KeyEventResult.handled;
      }
      return _escape() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (typing) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      return _step(key == LogicalKeyboardKey.arrowDown ? 1 : -1) ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  /// Scrolls the board so [t]'s card shows (columns are lazy: a card far
  /// down may not be built yet).
  void _reveal(TaskEntry t, int delta) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _cards[t.id];
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 140),
          alignmentPolicy: delta > 0 ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
        return;
      }
      final column = _scrollers[t.column];
      final at = _order.where((x) => x.column == t.column).toList().indexWhere((x) => x.id == t.id);
      if (column == null || !column.hasClients || at < 0) return;
      column.jumpTo((at * 120.0).clamp(0, column.position.maxScrollExtent));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final again = _cards[t.id];
        if (again != null && again.mounted) Scrollable.ensureVisible(again, alignment: 0.5);
      });
    });
  }

  // ---- Scope and filters ----

  static bool _everyone(AppState s) => s.setting<String>(TasksScreen.scopeSetting, 'mine') == 'everyone';

  void _setScope(AppState s, bool everyone) {
    s.setSetting(TasksScreen.scopeSetting, everyone ? 'everyone' : 'mine');
    setState(() {});
  }

  List<String> get _words => _query.text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// Every word in the key, title, labels, epic or parent, assignee or
  /// context.
  static bool _matches(TaskEntry t, List<String> words) {
    if (words.isEmpty) return true;
    final hay = [t.key, t.title, ...t.labels, t.parent?.key ?? '', t.parent?.title ?? '', t.assignee?.name ?? '', t.context].join(' ').toLowerCase();
    return words.every(hay.contains);
  }

  /// Most urgent first, then the nearest due date; otherwise as the source
  /// sends them.
  static List<TaskEntry> _sorted(List<TaskEntry> tasks) {
    final indexed = tasks.indexed.toList()
      ..sort((a, b) {
        final p = b.$2.priority.index.compareTo(a.$2.priority.index);
        if (p != 0) return p;
        final due = (a.$2.due.isEmpty ? '9999' : a.$2.due).compareTo(b.$2.due.isEmpty ? '9999' : b.$2.due);
        if (due != 0) return due;
        return a.$1.compareTo(b.$1);
      });
    return [for (final (_, t) in indexed) t];
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
    final everyone = _everyone(s);
    final all = source.tasks;
    final words = _words;
    bool inScope(TaskEntry t, bool every) => every || t.mine;
    bool inSource(TaskEntry t) => _source == 'all' || t.sourceId == _source;
    final visible = [for (final t in all) if (inScope(t, everyone) && inSource(t) && _matches(t, words)) t];
    final columns = {for (final (col, _) in taskColumns) col: _sorted([for (final t in visible) if (t.column == col) t])};
    _order = [for (final list in columns.values) ...list];
    final linked = {for (final l in source.links) l.taskId};
    final runs = [...s.agents.runs, if (!source.live && !s.agents.live) ...MockTasks.runs()];
    final syncing = sources.any((x) => x.syncing);
    final failing = sources.where((x) => x.error.isNotEmpty).length;
    final mineCount = all.where((t) => t.mine).length;
    final inWorktrees = all.where((t) => linked.contains(t.id)).length;
    final subtitle = sources.isEmpty
        ? 'Connect where your tasks live: Obsidian, Bear, GitHub, Jira, Todoist'
        : '${sources.map((x) => x.name).join(', ')} · ${_syncNote(sources)}';
    final keysHint = _selected == null ? '⌘K finds a ticket by key or title' : '↑ ↓ switch tickets · Esc ${_expanded ? 'back to the panel' : 'closes'}';

    final board = Section(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Tasks', style: sans(22, weight: FontWeight.w600, color: c.text, letterSpacing: -0.4)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text3)),
            ]),
          ),
          if (sources.isNotEmpty) ...[
            const SizedBox(width: 12),
            Tooltip(
              message: everyone
                  ? 'Everything each source brings in: the whole Jira project, every open issue'
                  : 'Assigned to you in Jira and GitHub, plus everything in Obsidian and Todoist',
              child: KSegmented<bool>(
                label: 'Whose tasks',
                height: 30,
                items: [(false, 'Mine', '$mineCount'), (true, 'Everyone', '${all.length}')],
                value: everyone,
                onChanged: (v) => _setScope(s, v),
              ),
            ),
          ],
        ]),
        if (sources.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 200, child: _SearchField(controller: _query)),
            _SourceChip(
              k: '∗',
              label: 'All',
              count: all.where((t) => inScope(t, everyone)).length,
              selected: _source == 'all',
              onTap: () => setState(() => _source = 'all'),
            ),
            for (final x in sources)
              _SourceChip(
                k: x.kind.badge,
                label: x.name,
                count: all.where((t) => t.sourceId == x.id && inScope(t, everyone)).length,
                selected: _source == x.id,
                warn: x.error.isNotEmpty,
                onTap: () => setState(() => _source = x.id),
              ),
          ]),
        ],
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
              : visible.isEmpty
                  ? _emptyState(s, source, everyone, words)
                  : _columns(context, columns, everyone, source, runs),
        ),
      ]),
    );

    return ScreenFrame(
      toolbar: ScreenToolbar(
        breadcrumb: Breadcrumb(icon: KIcons.tasks, parts: ['Tasks', sources.isEmpty ? 'No sources yet' : '${everyone ? 'Everyone' : 'Mine'} · ${sources.length} sources']),
        primary: sources.isEmpty
            ? KButton.primary(label: 'Connect a source', icon: KIcons.add, height: 36, onTap: _openSettings)
            : KButton.primary(label: syncing ? 'Syncing…' : 'Sync now', icon: KIcons.download, height: 36, onTap: syncing ? null : () => source.sync()),
      ),
      body: Focus(
        focusNode: _keys,
        onKeyEvent: _onKey,
        child: LayoutBuilder(builder: (context, box) {
          final selectedId = _selected;
          final open = selectedId != null;
          final full = open && (_expanded || box.maxWidth < _sideBySide);
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!full) Expanded(key: const ValueKey('board'), child: board),
            if (open && !full) const SizedBox(key: ValueKey('gap'), width: 10),
            if (open)
              // Same wrapper side by side and expanded, so the panel keeps
              // its state (scroll, open form) when it grows.
              Flexible(
                key: const ValueKey('panel'),
                flex: full ? 1 : 0,
                fit: FlexFit.tight,
                child: SizedBox(
                  width: full ? null : _panelWidth,
                  child: TaskDetailPanel(
                    key: ValueKey(selectedId),
                    taskId: selectedId,
                    expanded: _expanded,
                    canGoBack: _history.isNotEmpty,
                    onBack: _back,
                    onOpen: (String id) => _select(id, push: true),
                    onExpand: (bool v) => setState(() => _expanded = v),
                    onClose: _close,
                    onStep: (int delta) => _step(delta),
                  ),
                ),
              ),
          ]);
        }),
      ),
      status: [
        StatusText(everyone ? '${all.length} tasks · $mineCount yours · $inWorktrees in worktrees' : '$mineCount yours of ${all.length} · $inWorktrees in worktrees'),
        if (failing > 0)
          StatusText(failing == 1 ? '1 source failing' : '$failing sources failing', color: c.err)
        else if (sources.isNotEmpty)
          StatusText(_syncNote(sources)),
        // Flush right; the keys hint gives way first when narrow.
        Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Flexible(child: StatusText(keysHint, flexible: true)),
            const SizedBox(width: 16),
            const StatusText('Moving a task updates its app'),
          ]),
        ),
      ],
    );
  }

  Widget _columns(BuildContext context, Map<TaskColumn, List<TaskEntry>> columns, bool everyone, TasksSource source, List<AgentRun> runs) {
    final c = context.c;
    return LayoutBuilder(builder: (context, box) {
      const need = _minColumn * 4 + _columnGap * 3;
      final row = Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, (col, label)) in taskColumns.indexed) ...[
          if (i > 0) const SizedBox(width: _columnGap),
          Expanded(
            child: _Column(
              label: label,
              color: switch (col) {
                TaskColumn.todo => c.text3,
                TaskColumn.doing => c.acc,
                TaskColumn.review => c.warn,
                TaskColumn.done => c.ok,
              },
              tasks: columns[col]!,
              controller: _scrollers[col]!,
              cardBuilder: (t) {
                final link = source.linksOf(t.id).lastOrNull;
                return _Tracked(
                  key: ValueKey(t.id),
                  id: t.id,
                  registry: _cards,
                  child: _TaskCard(
                    task: t,
                    selected: t.id == _selected,
                    everyone: everyone,
                    link: link,
                    run: link == null ? null : runIn(runs, link.worktreePath),
                    onTap: () => _pick(t),
                  ),
                );
              },
            ),
          ),
        ],
      ]);
      if (box.maxWidth >= need) return row;
      return Scrollbar(
        controller: _sideways,
        child: SingleChildScrollView(
          controller: _sideways,
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: need, height: box.maxHeight, child: row),
        ),
      );
    });
  }

  Widget _emptyState(AppState s, TasksSource source, bool everyone, List<String> words) {
    final src = source.source(_source);
    final all = source.tasks;
    bool inSource(TaskEntry t) => _source == 'all' || t.sourceId == _source;
    if (words.isNotEmpty) {
      final everyMatches = all.where((t) => inSource(t) && _matches(t, words)).length;
      final teammates = !everyone && everyMatches > 0;
      return _EmptyState(
        icon: KIcons.search,
        title: 'No tasks match “${_query.text.trim()}”',
        body: teammates
            ? 'Nothing of yours has that word. $everyMatches ${everyMatches == 1 ? 'teammate’s task does.' : 'teammates’ tasks do.'}'
            : 'Try another word, or check the source chips: the filter looks at keys, titles, labels, epics and people.',
        primary: ('Clear filter', _query.clear),
        secondary: teammates ? ('Search everyone ($everyMatches)', () => _setScope(s, true)) : null,
      );
    }
    if (!everyone) {
      final theirs = all.where(inSource).length;
      return _EmptyState(
        icon: Icons.person_outline_rounded,
        title: 'Nothing assigned to you in ${src?.kind.label ?? 'your sources'}',
        body: theirs > 0
            ? '${src?.name ?? 'Your sources'} has $theirs ${theirs == 1 ? 'task' : 'tasks'} for other people or nobody. Everyone shows them all.'
            : 'When something is assigned to you, it shows up here.',
        primary: ('Show everyone', () => _setScope(s, true)),
        secondary: _source != 'all' ? ('All sources', () => setState(() => _source = 'all')) : null,
      );
    }
    return _EmptyState(
      icon: KIcons.tasks,
      title: 'Nothing in ${src?.name ?? 'your sources'}',
      body: 'Kumo shows what the source returns. Sync again, or check its query in Settings.',
      primary: ('Sync now', () => source.sync(src?.id)),
    );
  }

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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: 'Filters this board. ⌘K searches every ticket.',
      waitDuration: const Duration(milliseconds: 800),
      child: Container(
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
              decoration: InputDecoration.collapsed(hintText: 'Filter tasks', hintStyle: sans(12, color: c.text3)),
            ),
          ),
        ]),
      ),
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
          border: Border.all(color: focus ? c.acc : (selected ? c.chipBorder : c.paneBorder), width: focus ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SourceTile(k, size: 20),
          const SizedBox(width: 6),
          Text(label, style: sans(12, weight: FontWeight.w500, color: selected ? c.text : c.text2)),
          const SizedBox(width: 6),
          if (warn) Icon(KIcons.warning, size: 12, color: c.err, semanticLabel: 'Failing') else Text('$count', style: sans(11, color: c.text3)),
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

/// No sources yet.
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

/// Nothing to show with sources connected: nothing of yours, or the filter
/// left everything out.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.body, required this.primary, this.secondary});
  final IconData icon;
  final String title;
  final String body;
  final (String, VoidCallback) primary;
  final (String, VoidCallback)? secondary;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Semantics(
            liveRegion: true,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 18, color: c.text2),
              ),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center, style: sans(16, weight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 6),
              Text(body, textAlign: TextAlign.center, style: sans(12.5, color: c.text2, height: 1.5)),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                KButton.primary(label: primary.$1, height: 34, onTap: primary.$2),
                if (secondary case (final label, final onTap)) KButton(label: label, height: 34, onTap: onTap),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.label, required this.color, required this.tasks, required this.controller, required this.cardBuilder});
  final String label;
  final Color color;
  final List<TaskEntry> tasks;
  final ScrollController controller;
  final Widget Function(TaskEntry) cardBuilder;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Semantics(
          header: true,
          child: Row(children: [
            Dot(color, size: 8, ring: true),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: FontWeight.w600, color: c.text))),
            const SizedBox(width: 8),
            Text('${tasks.length}', style: sans(11.5, color: c.text3)),
          ]),
        ),
      ),
      Expanded(
        child: tasks.isEmpty
            ? Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: c.paneBorder)),
                  child: Text('Nothing here', textAlign: TextAlign.center, style: sans(12, color: c.text3)),
                ),
              )
            // Lazy: a source can bring thousands of tasks. The padding
            // leaves room for the selected card's ring.
            : ListView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(3, 3, 3, 18),
                itemCount: tasks.length,
                itemBuilder: (context, i) => Padding(padding: const EdgeInsets.only(bottom: 8), child: cardBuilder(tasks[i])),
              ),
      ),
    ]);
  }
}

/// Keeps [registry] pointing at this card's context while it is built.
class _Tracked extends StatefulWidget {
  const _Tracked({super.key, required this.id, required this.registry, required this.child});
  final String id;
  final Map<String, BuildContext> registry;
  final Widget child;

  @override
  State<_Tracked> createState() => _TrackedState();
}

class _TrackedState extends State<_Tracked> {
  @override
  void initState() {
    super.initState();
    widget.registry[widget.id] = context;
  }

  @override
  void didUpdateWidget(_Tracked old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id && old.registry[old.id] == context) old.registry.remove(old.id);
    widget.registry[widget.id] = context;
  }

  @override
  void dispose() {
    if (widget.registry[widget.id] == context) widget.registry.remove(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A ticket on the board: type and key, priority, title, what says more
/// than the column (source status, blocked, epic or parent, sprint,
/// labels), the agent in its worktree, and a footer with points, subtasks,
/// comments, due and (in Everyone) the assignee. Empty fields drop out.
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.selected, required this.everyone, required this.onTap, this.link, this.run});
  final TaskEntry task;
  final bool selected;
  final bool everyone;
  final TaskLinkInfo? link;
  final AgentRun? run;
  final VoidCallback onTap;

  static bool _personal(TaskSourceKind k) => k == TaskSourceKind.obsidian || k == TaskSourceKind.bear || k == TaskSourceKind.todoist;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = task;
    final column = columnName(t.column);
    final prio = priorityLabel(t.priority);
    final prioIcon = priorityIcon(t.priority);
    final prioColor = priorityColor(c, t.priority);
    final status = t.kind == TaskSourceKind.jira ? statusBeyondColumn(t, column) : null;
    final parent = t.parent;
    final epic = parent != null && parent.type == TaskType.epic ? parent : null;
    final parentStory = parent != null && parent.type != TaskType.epic ? parent : null;
    final sprintNote = t.sprint == null ? null : sprintCardNote(t.sprint!);
    final due = dueInfo(t.due);
    final showWho = everyone && !_personal(t.kind);
    final who = t.assignee;
    final typeLabel = t.typeName.isNotEmpty ? t.typeName : taskTypeLabel(t.type);

    final chips = <Widget>[
      if (status != null) _StatusChip(status: status, column: t.column),
      if (t.blocked)
        _Chip(
          icon: Icons.lock_outline_rounded,
          text: 'Blocked',
          color: c.warn,
          background: c.warnSoft,
          bold: true,
          tooltip: 'Blocked by an issue that isn’t done yet',
        ),
      if (epic != null)
        Builder(builder: (context) {
          final (dot, bg) = epicColors(c, color: epic.color, key: epic.key);
          return _Chip(
            leading: Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, borderRadius: BorderRadius.circular(2))),
            text: epic.title,
            color: c.text,
            background: bg,
            tooltip: '${t.type == TaskType.subtask ? 'Parent epic' : 'Epic'} ${epic.key} · ${epic.title}',
          );
        }),
      if (parentStory != null)
        _Chip(
          icon: taskTypeIcon(TaskType.subtask),
          iconColor: c.text3,
          monoPrefix: parentStory.key,
          text: parentStory.title,
          color: c.text2,
          background: c.tile,
          tooltip: 'Parent ${parentStory.key} · ${parentStory.title}',
        ),
      if (sprintNote != null)
        _Chip(
          icon: Icons.sync_rounded,
          iconColor: c.text3,
          text: sprintNote,
          color: c.text2,
          background: c.tile,
          tooltip: t.sprint!.state == SprintState.closed
              ? 'Sprint ${t.sprint!.name} has closed; this was carried over'
              : 'Planned for the next sprint, ${t.sprint!.name}',
        ),
      for (final l in t.labels.take(2)) TagChip(l),
      if (t.labels.length > 2) Tooltip(message: t.labels.skip(2).join(', '), child: TagChip('+${t.labels.length - 2}')),
    ];

    final foot = <Widget>[
      if (t.points > 0)
        Tooltip(
          message: '${_points(t.points)} story points',
          child: Container(
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(9)),
            child: Center(widthFactor: 1, child: Text('${_points(t.points)} pts', style: sans(11, weight: FontWeight.w600, color: c.text2, height: 1))),
          ),
        ),
      if (t.subtasksTotal > 0)
        _Meta(icon: Icons.checklist_rtl_rounded, text: '${t.subtasksDone}/${t.subtasksTotal}', tooltip: '${t.subtasksDone} of ${t.subtasksTotal} subtasks done'),
      if (t.commentCount > 0)
        _Meta(icon: Icons.chat_bubble_outline_rounded, text: '${t.commentCount}', tooltip: '${t.commentCount} ${t.commentCount == 1 ? 'comment' : 'comments'}'),
      if (due != null) _Due(due: due),
    ];

    final aria = [
      t.key,
      typeLabel,
      t.title,
      column,
      if (status != null) 'status $status',
      if (t.blocked) 'blocked',
      if (showWho) who == null ? 'unassigned' : 'assigned to ${who.you ? 'you' : who.name}',
    ].join(', ');

    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: aria,
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
        decoration: BoxDecoration(
          color: c.pane,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected || focus ? c.acc : (hover ? c.chipBorder : c.paneBorder), width: focus && !selected ? 1.5 : 1),
          boxShadow: selected ? [BoxShadow(color: c.accSoft, spreadRadius: 3)] : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Tooltip(message: _sourceName(context, t), child: TagChip(t.kind.badge)),
            const SizedBox(width: 6),
            Tooltip(message: typeLabel, child: Icon(taskTypeIcon(t.type), size: 14, color: taskTypeColor(c, t.type), semanticLabel: typeLabel)),
            const SizedBox(width: 6),
            Expanded(child: Text(t.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text2))),
            if (prio.isNotEmpty)
              Tooltip(
                message: '${priorityLongLabel(t.priority)} priority',
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (prioIcon != null) Icon(prioIcon, size: 13, color: prioColor),
                  const SizedBox(width: 2),
                  Text(prio, style: sans(11, weight: FontWeight.w600, color: prioColor)),
                ]),
              ),
          ]),
          const SizedBox(height: 8),
          Text(t.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: sans(13, weight: FontWeight.w500, color: c.text, height: 1.35)),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: chips),
          ],
          if (link != null) ...[
            const SizedBox(height: 8),
            _AgentBlock(link: link!, run: run),
          ],
          if (foot.isNotEmpty || showWho) ...[
            const SizedBox(height: 8),
            if (!showWho)
              Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: foot)
            else if (foot.isEmpty)
              Align(alignment: Alignment.centerRight, child: _Who(person: who))
            else
              _FootRow(children: [
                Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: foot),
                _Who(person: who),
              ]),
          ],
        ]),
      ),
    );
  }

  static String _sourceName(BuildContext context, TaskEntry t) => AppScope.read(context).tasks.source(t.sourceId)?.name ?? t.kind.label;

  static String _points(double p) => p == p.roundToDouble() ? p.toInt().toString() : p.toString();
}

/// The card's footer in Everyone: the meta on the left, the assignee at
/// the right end; on a line of its own, still at the right, when they
/// don't fit side by side.
class _FootRow extends MultiChildRenderObjectWidget {
  const _FootRow({required super.children}) : assert(children.length == 2);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFootRow();
}

class _FootParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderFootRow extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _FootParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _FootParentData> {
  static const _gap = 8.0;
  static const _runGap = 6.0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FootParentData) child.parentData = _FootParentData();
  }

  /// Where the two children go, and the size, for children of [lead] and
  /// [trail] sizes.
  (Offset, Offset, Size) _arrange(BoxConstraints constraints, Size lead, Size trail) {
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : lead.width + _gap + trail.width;
    if (lead.width + _gap + trail.width <= width) {
      final h = lead.height > trail.height ? lead.height : trail.height;
      return (Offset(0, (h - lead.height) / 2), Offset(width - trail.width, (h - trail.height) / 2), constraints.constrain(Size(width, h)));
    }
    return (Offset.zero, Offset(width - trail.width, lead.height + _runGap), constraints.constrain(Size(width, lead.height + _runGap + trail.height)));
  }

  @override
  void performLayout() {
    final lead = firstChild!;
    final trail = childAfter(lead)!;
    final loose = constraints.loosen();
    lead.layout(loose, parentUsesSize: true);
    trail.layout(loose, parentUsesSize: true);
    final (a, b, box) = _arrange(constraints, lead.size, trail.size);
    (lead.parentData! as _FootParentData).offset = a;
    (trail.parentData! as _FootParentData).offset = b;
    size = box;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final loose = constraints.loosen();
    return _arrange(constraints, firstChild!.getDryLayout(loose), lastChild!.getDryLayout(loose)).$3;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final lead = firstChild!.getMinIntrinsicWidth(height);
    final trail = lastChild!.getMinIntrinsicWidth(height);
    return lead > trail ? lead : trail;
  }

  @override
  double computeMaxIntrinsicWidth(double height) => firstChild!.getMaxIntrinsicWidth(height) + _gap + lastChild!.getMaxIntrinsicWidth(height);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}

/// The assignee in Everyone: "You" or "Unassigned" beside the avatar; a
/// teammate's name shows on hover.
class _Who extends StatelessWidget {
  const _Who({required this.person});
  final TaskPerson? person;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = person;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (p == null)
        Text('Unassigned', style: sans(11, color: c.text3))
      else if (p.you)
        Text('You', style: sans(11.5, weight: FontWeight.w600, color: c.acc)),
      if (p == null || p.you) const SizedBox(width: 5),
      PersonAvatar(person: p, size: 20),
    ]);
  }
}

/// The source's status, with the icon of the column it maps to.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.column});
  final String status;
  final TaskColumn column;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (icon, color, bg) = switch (column) {
      TaskColumn.todo => (Icons.radio_button_unchecked_rounded, c.text2, c.tile),
      TaskColumn.doing => (Icons.timelapse_rounded, c.acc, c.accSoft),
      TaskColumn.review => (Icons.visibility_outlined, c.warn, c.warnSoft),
      TaskColumn.done => (Icons.check_rounded, c.ok, c.okSoft),
    };
    return _Chip(icon: icon, text: status, color: color, background: bg, bold: true, radius: 10, tooltip: 'Status in Jira');
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.color,
    required this.background,
    this.icon,
    this.iconColor,
    this.leading,
    this.monoPrefix,
    this.tooltip,
    this.bold = false,
    this.radius = 6,
  });
  final String text;
  final Color color;
  final Color background;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String? monoPrefix;
  final String? tooltip;
  final bool bold;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      height: 20,
      padding: EdgeInsets.fromLTRB(icon != null || leading != null ? 5 : 7, 0, 7, 0),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 11, color: iconColor ?? color), const SizedBox(width: 4)],
        if (leading != null) ...[leading!, const SizedBox(width: 5)],
        if (monoPrefix != null) ...[Text(monoPrefix!, style: mono(10.5, color: color, height: 1)), const SizedBox(width: 5)],
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, weight: bold ? FontWeight.w600 : FontWeight.w500, color: color, height: 1))),
      ]),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.tooltip});
  final IconData icon;
  final String text;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: c.text3),
        const SizedBox(width: 4),
        Text(text, style: sans(11, color: c.text3)),
      ]),
    );
  }
}

/// "2 days overdue" in red with a warning icon (not only color), "Due
/// today" / "Due tomorrow" in amber, otherwise the date.
class _Due extends StatelessWidget {
  const _Due({required this.due});
  final DueInfo due;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = due.overdue ? c.err : (due.soon ? c.warn : c.text3);
    return Tooltip(
      message: 'Due ${due.long}',
      child: Container(
        height: 18,
        padding: due.overdue ? const EdgeInsets.fromLTRB(4, 0, 6, 0) : EdgeInsets.zero,
        decoration: due.overdue ? BoxDecoration(color: c.errSoft, borderRadius: BorderRadius.circular(9)) : null,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(due.overdue ? Icons.warning_amber_rounded : Icons.calendar_today_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(due.text, style: sans(11, weight: due.overdue || due.soon ? FontWeight.w600 : FontWeight.w400, color: color, height: 1)),
        ]),
      ),
    );
  }
}

/// The worktree linked to the ticket and its agent ("Claude Code ·
/// working"), colored by status.
class _AgentBlock extends StatelessWidget {
  const _AgentBlock({required this.link, this.run});
  final TaskLinkInfo link;
  final AgentRun? run;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = run;
    final (word, color) = switch (r?.status) {
      AgentStatus.needsYou => ('needs you', c.warn),
      AgentStatus.done => ('finished', c.ok),
      _ => ('working', c.acc),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (r != null) ...[
          Row(children: [
            Dot(color, size: 6),
            const SizedBox(width: 6),
            Flexible(
              child: Text('${r.providerName} · $word', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, weight: FontWeight.w600, color: color)),
            ),
          ]),
          const SizedBox(height: 3),
        ],
        Row(children: [
          Icon(KIcons.branch, size: 11, color: c.text3),
          const SizedBox(width: 5),
          Flexible(child: Text(link.branch, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(10.5, color: c.text3))),
        ]),
      ]),
    );
  }
}
