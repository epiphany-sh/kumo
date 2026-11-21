import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/agents_source.dart';
import '../data/models.dart';
import '../data/todos_source.dart';
import '../data/workspace_source.dart';
import '../shell/screen_chrome.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/controls.dart';
import '../widgets/kicons.dart';
import '../widgets/repo_picker.dart';
import 'task_visuals.dart';

/// The user's own TODOs, in Tasks next to the tickets: written down here,
/// kept on this Mac by the workspace, and handed to an agent in a new
/// worktree whenever the user decides. From then on each shows the status
/// the agent reports (working, testing, waiting for review) and what the
/// user can do next: approve and push, open the PR, clean up once merged.
class TodosView extends StatefulWidget {
  const TodosView({super.key, required this.viewSwitch});

  /// Tickets | TODOs, as the board shows it.
  final Widget viewSwitch;

  @override
  State<TodosView> createState() => _TodosViewState();
}

const _panelWidth = 400.0;

class _TodosViewState extends State<TodosView> {
  final _draft = TextEditingController();
  final _draftFocus = FocusNode(debugLabel: 'New TODO');
  String? _draftRepo;
  String? _selected;
  bool _showDone = false;
  bool _adding = false;
  Timer? _merges;

  @override
  void initState() {
    super.initState();
    _draft.addListener(() => setState(() {}));
  }

  /// Pull requests merge on the host: looked for every minute while this
  /// shows, and once on coming back. Tasks sits in the shell's
  /// IndexedStack, so this stays mounted under the other views: there it
  /// doesn't ask (as the Git view doesn't poll CI offstage). Nor while the
  /// app is hidden.
  void _watchMerges(AppState s) {
    final showing = s.view == KumoView.tasks;
    if (showing == (_merges != null)) return;
    _merges?.cancel();
    _merges = null;
    if (!showing) return;
    void check() {
      final life = WidgetsBinding.instance.lifecycleState;
      if (life == AppLifecycleState.hidden || life == AppLifecycleState.paused) return;
      s.checkTodoMerges().ignore();
    }

    _merges = Timer.periodic(const Duration(minutes: 1), (_) => check());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) check();
    });
  }

  @override
  void dispose() {
    _merges?.cancel();
    _draft.dispose();
    _draftFocus.dispose();
    super.dispose();
  }

  Future<void> _add(AppState s) async {
    final title = _draft.text.trim();
    if (title.isEmpty || _adding) return;
    setState(() => _adding = true);
    final added = await s.todos.add(title, repoPath: _draftRepo ?? '');
    if (!mounted) return;
    setState(() {
      _adding = false;
      if (added != null) _draft.clear();
    });
    _draftFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    _watchMerges(s);
    return ListenableBuilder(listenable: s.todos, builder: (context, _) => _build(context, s, s.todos));
  }

  Widget _build(BuildContext context, AppState s, TodosSource source) {
    final c = context.c;
    final all = source.todos;
    if (_selected != null && source.todo(_selected!) == null) _selected = null;
    final columns = todoColumns(all, s, c);
    final done = [for (final t in all) if (t.done) t];
    final open = columns.first.items.length;
    final withAgent = columns[1].items.length;
    final needsYou = columns[2].items.length;
    final parts = [
      '$open to do',
      '$withAgent with an agent',
      if (needsYou > 0) '$needsYou need${needsYou == 1 ? 's' : ''} you',
    ];

    final board = Section(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('Tasks', style: sans(22, weight: FontWeight.w600, color: c.text, letterSpacing: -0.4)),
                widget.viewSwitch,
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Icon(KIcons.lock, size: 12, color: c.text3),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    all.isEmpty ? 'Kept on this Mac by Kumo, never synced' : 'Kept on this Mac by Kumo, never synced · ${parts.join(' · ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: sans(12, color: c.text3),
                  ),
                ),
              ]),
            ]),
          ),
          if (done.isNotEmpty) ...[
            const SizedBox(width: 12),
            KButton(
              label: _showDone ? 'Hide done' : 'Show done',
              kind: KButtonKind.ghost,
              height: 30,
              fontSize: 12,
              trailing: Text('${done.length}', style: sans(11, color: c.text3)),
              onTap: () => setState(() => _showDone = !_showDone),
            ),
          ],
        ]),
        const SizedBox(height: 14),
        _composer(s, c),
        if (source.error != null) ...[
          const SizedBox(height: 8),
          Text(source.error!, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(12, color: c.err)),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: all.isEmpty
              ? _empty(c)
              : _TodoBoard(
                  columns: [...columns, if (_showDone) TodoColumn('Done', c.ok, done, 'Checked off TODOs')],
                  selected: _selected,
                  onPick: (id) => setState(() => _selected = _selected == id ? null : id),
                ),
        ),
      ]),
    );

    final selected = _selected == null ? null : source.todo(_selected!);
    return ScreenFrame(
      toolbar: ScreenToolbar(
        breadcrumb: const Breadcrumb(icon: KIcons.tasks, parts: ['Tasks', 'TODOs · on this Mac']),
        primary: KButton.primary(label: 'New TODO', icon: KIcons.add, height: 36, onTap: () => _draftFocus.requestFocus()),
      ),
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: board),
        if (selected != null) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: _panelWidth,
            child: _TodoPanel(key: ValueKey(selected.id), todo: selected, onClose: () => setState(() => _selected = null)),
          ),
        ],
      ]),
      status: [
        StatusText('${all.where((t) => !t.done).length} open · ${done.length} done'),
        if (needsYou > 0) StatusText('$needsYou waiting for you', color: c.warn),
        Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Flexible(child: StatusText(source.live ? 'Agents report each step with kumod todo' : 'Demo data: nothing is saved', flexible: true)),
          ]),
        ),
      ],
    );
  }

  /// One bar: what to do, which repository, Add. Return adds it too.
  Widget _composer(AppState s, KumoPalette c) {
    final typing = _draft.text.trim().isNotEmpty;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          ListenableBuilder(
            listenable: _draftFocus,
            builder: (context, _) {
              final focused = _draftFocus.hasFocus;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 48,
                padding: const EdgeInsets.fromLTRB(14, 0, 7, 0),
                decoration: BoxDecoration(
                  color: c.chip,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: focused ? c.acc : c.chipBorder, width: focused ? 1.5 : 1),
                  boxShadow: focused ? [BoxShadow(color: c.accSoft, blurRadius: 0, spreadRadius: 3)] : null,
                ),
                child: Row(children: [
                  Icon(KIcons.add, size: 17, color: focused || typing ? c.acc : c.text3),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _draft,
                      focusNode: _draftFocus,
                      style: sans(14, color: c.text),
                      cursorColor: c.acc,
                      onSubmitted: (_) => _add(s),
                      decoration: InputDecoration.collapsed(hintText: 'Add a TODO: what needs doing, in your own words', hintStyle: sans(14, color: c.text3)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 220, child: RepoPicker(value: _draftRepo, allowAny: true, compact: true, onChanged: (id) => setState(() => _draftRepo = id))),
                  const SizedBox(width: 6),
                  KButton.primary(label: 'Add', height: 34, fontSize: 12.5, onTap: typing && !_adding ? () => _add(s) : null),
                ]),
              );
            },
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Row(children: [
              const Kbd('↩'),
              const SizedBox(width: 6),
              Flexible(child: Text('adds it. It waits here until you hand it to an agent.', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _empty(KumoPalette c) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(13)),
              child: Icon(KIcons.tasks, size: 20, color: c.text2),
            ),
            const SizedBox(height: 14),
            Text('Nothing to do yet', style: sans(16, weight: FontWeight.w600, color: c.text)),
            const SizedBox(height: 6),
            Text(
              'Write down what crosses your mind while you work: a bug you saw, a test that’s missing, a rename. '
              'Kumo keeps it on this Mac. When you’re ready, one click starts an agent on it in its own worktree.',
              textAlign: TextAlign.center,
              style: sans(12.5, color: c.text2, height: 1.5),
            ),
          ]),
        ),
      );
}

/// A column of the board: its title, dot color, TODOs and what it says
/// when empty.
class TodoColumn {
  const TodoColumn(this.title, this.color, this.items, this.empty);
  final String title;
  final Color color;
  final List<TodoItem> items;
  final String empty;
}

/// To do, With an agent, Needs you, Shipping: where each open TODO is. An
/// agent that stopped before finishing needs the user too.
List<TodoColumn> todoColumns(List<TodoItem> all, AppState s, KumoPalette c) {
  final open = [for (final t in all) if (!t.done && t.run == null) t];
  final live = [for (final t in all) if (!t.done && t.run != null) t];
  bool stopped(TodoItem t) => todoAgentStopped(s, t);
  return [
    TodoColumn('To do', c.text3, open, 'Add one above. It waits here until you run it.'),
    TodoColumn('With an agent', c.acc, [for (final t in live) if (t.status.withAgent && !stopped(t)) t], 'Run a TODO with an agent to see it here.'),
    TodoColumn('Needs you', c.warn, [for (final t in live) if (t.status.needsYou || (t.status.withAgent && stopped(t))) t], 'Nothing to review or clean up.'),
    TodoColumn('Shipping', c.purple, [for (final t in live) if (t.status.shipping) t], 'Approved TODOs on their way: pushed, or with a PR.'),
  ];
}

/// [t]'s agent ended before reporting it done: it crashed, was refused
/// (an unknown model) or its session is gone.
bool todoAgentStopped(AppState s, TodoItem t) {
  final run = t.run;
  if (run == null || t.done || !t.status.withAgent || !s.agents.live) return false;
  final session = s.agents.runs.where((r) => r.id == run.sessionId).firstOrNull;
  if (session != null) return session.status == AgentStatus.done;
  // Not listed: gone with a restart, unless it was only just started.
  final since = t.steps.isEmpty ? t.created : t.steps.last.at;
  return DateTime.now().difference(since) > const Duration(seconds: 30);
}

/// The columns side by side; narrower than they fit, the board scrolls
/// sideways, like the tickets board.
class _TodoBoard extends StatefulWidget {
  const _TodoBoard({required this.columns, required this.selected, required this.onPick});

  final List<TodoColumn> columns;
  final String? selected;
  final ValueChanged<String> onPick;

  @override
  State<_TodoBoard> createState() => _TodoBoardState();
}

const _minColumn = 250.0;
const _columnGap = 12.0;

class _TodoBoardState extends State<_TodoBoard> {
  final _sideways = ScrollController();

  @override
  void dispose() {
    _sideways.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.columns.length;
    return LayoutBuilder(builder: (context, box) {
      final need = n * _minColumn + (n - 1) * _columnGap;
      final width = box.maxWidth >= need ? box.maxWidth : need;
      final columnWidth = (width - (n - 1) * _columnGap) / n;
      final row = SizedBox(
        width: width,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, col) in widget.columns.indexed) ...[
            if (i > 0) const SizedBox(width: _columnGap),
            SizedBox(width: columnWidth, child: _Column(column: col, selected: widget.selected, onPick: widget.onPick)),
          ],
        ]),
      );
      if (width <= box.maxWidth) return row;
      return Scrollbar(
        controller: _sideways,
        child: SingleChildScrollView(controller: _sideways, scrollDirection: Axis.horizontal, child: row),
      );
    });
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.column, required this.selected, required this.onPick});

  final TodoColumn column;
  final String? selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = column;
    final dot = col.color;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Row(children: [
          Dot(dot, ring: true, size: 8),
          const SizedBox(width: 8),
          Flexible(child: Text(col.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: FontWeight.w600, color: c.text))),
          const SizedBox(width: 8),
          Text('${col.items.length}', style: sans(11.5, color: c.text3)),
        ]),
      ),
      Expanded(
        child: col.items.isEmpty
            ? Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: c.paneBorder)),
                  child: Text(col.empty, textAlign: TextAlign.center, style: sans(12, color: c.text3, height: 1.4)),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 18),
                itemCount: col.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final t = col.items[i];
                  return _TodoCard(todo: t, selected: t.id == selected, onTap: () => onPick(t.id));
                },
              ),
      ),
    ]);
  }
}

/// What a status looks like: its color, soft background and icon.
(Color, Color, IconData) todoStatusLook(KumoPalette c, TodoStatus status) => switch (status) {
      TodoStatus.open => (c.text3, c.tile, KIcons.tasks),
      TodoStatus.working => (c.acc, c.accSoft, KIcons.sparkle),
      TodoStatus.testing => (c.cyan, c.cyan.withAlpha(36), KIcons.flask),
      TodoStatus.review => (c.warn, c.warnSoft, KIcons.compare),
      TodoStatus.pushed => (c.purple, c.purple.withAlpha(36), KIcons.upload),
      TodoStatus.pr => (c.purple, c.purple.withAlpha(36), KIcons.pullRequest),
      TodoStatus.merged => (c.ok, c.okSoft, KIcons.merged),
    };

/// The short status a card shows: "Claude Code · testing", "Needs your review".
String todoPillText(TodoItem t) {
  final run = t.run;
  final agent = run?.agentName ?? '';
  return switch (t.status) {
    TodoStatus.working || TodoStatus.testing => agent.isEmpty ? t.status.label : '$agent · ${t.status.label.toLowerCase()}',
    TodoStatus.review => 'Needs your review',
    TodoStatus.pr => run != null && run.prNumber > 0 ? 'PR #${run.prNumber}' : 'PR created',
    TodoStatus.merged => 'Merged · clean up',
    _ => t.status.label,
  };
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({required this.todo, required this.selected, required this.onTap});

  final TodoItem todo;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final t = todo;
    final repo = t.repoPath.isEmpty ? null : s.workspace.repo(t.repoPath);
    final run = t.run;
    final active = run != null && !t.done;
    final stopped = todoAgentStopped(s, t);
    final (color, soft, icon) = stopped ? (c.err, c.errSoft, KIcons.warning) : todoStatusLook(c, t.status);
    return KPressable(
      onTap: onTap,
      semanticLabel: t.title,
      selected: selected,
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: selected ? c.accSoft : (hover ? Color.alphaBlend(c.tile, c.pane) : c.pane),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected || focus ? c.acc : c.paneBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: _DoneBox(todo: t)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: sans(13, weight: FontWeight.w500, color: t.done ? c.text3 : c.text, height: 1.35).copyWith(decoration: t.done ? TextDecoration.lineThrough : null),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (repo != null || t.repoPath.isNotEmpty) _meta(c, KIcons.repo, repo?.name ?? t.repoPath.split('/').last, mono: true),
            if (active) _meta(c, KIcons.branch, run.branch, mono: true),
            if (t.notes.trim().isNotEmpty) _meta(c, KIcons.page, 'Notes'),
            _meta(c, KIcons.clock, relativeTime(t.created)),
          ]),
          if (active) ...[
            const SizedBox(height: 10),
            Tooltip(
              message: [
                stopped ? 'Its agent stopped before finishing' : t.status.label,
                if (t.steps.isNotEmpty) 'set by ${t.steps.last.by}, ${relativeTime(t.steps.last.at)}',
                if (run.describe.isNotEmpty) run.describe,
              ].join('\n'),
              child: Container(
                height: 26,
                padding: const EdgeInsets.only(left: 8, right: 10),
                decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(13)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 12, color: color),
                  const SizedBox(width: 6),
                  Flexible(child: Text(stopped ? 'Agent stopped' : todoPillText(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, weight: FontWeight.w600, color: color))),
                ]),
              ),
            ),
          ] else if (!t.done) ...[
            const SizedBox(height: 10),
            KButton(label: 'Run with agent', icon: KIcons.sparkle, height: 28, fontSize: 12, onTap: onTap),
          ],
        ]),
      ),
    );
  }

  static Widget _meta(KumoPalette c, IconData icon, String text, {bool mono = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: c.text3),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono ? monoText(11, c.text3) : sans(11.5, color: c.text3)),
        ),
      ]);
}

TextStyle monoText(double size, Color color) => mono(size, color: color);

class _DoneBox extends StatelessWidget {
  const _DoneBox({required this.todo});
  final TodoItem todo;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final done = todo.done;
    return KPressable(
      onTap: () => s.todos.update(todo, done: !done),
      semanticLabel: done ? 'Mark “${todo.title}” not done' : 'Mark “${todo.title}” done',
      selected: done,
      builder: (context, hover, focus) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? c.accFill : null,
          border: Border.all(color: done ? c.accFill : (hover || focus ? c.acc : c.text3), width: 1.5),
        ),
        child: done ? Icon(KIcons.check, size: 12, color: c.accText) : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The panel: the TODO, its progress, and what to do next.

class _TodoPanel extends StatefulWidget {
  const _TodoPanel({super.key, required this.todo, required this.onClose});

  final TodoItem todo;
  final VoidCallback onClose;

  @override
  State<_TodoPanel> createState() => _TodoPanelState();
}

class _TodoPanelState extends State<_TodoPanel> {
  late final _title = TextEditingController(text: widget.todo.title);
  late final _notes = TextEditingController(text: widget.todo.notes);
  final _titleFocus = FocusNode();
  final _notesFocus = FocusNode();
  final _feedback = TextEditingController();
  bool _formOpen = false;
  bool _retrying = false;
  bool _asking = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) _save();
    });
    _notesFocus.addListener(() {
      if (!_notesFocus.hasFocus) _save();
    });
    _feedback.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant _TodoPanel old) {
    super.didUpdateWidget(old);
    // Changed elsewhere (another window): follow it unless being typed.
    if (!_titleFocus.hasFocus && widget.todo.title != _title.text) _title.text = widget.todo.title;
    if (!_notesFocus.hasFocus && widget.todo.notes != _notes.text) _notes.text = widget.todo.notes;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _titleFocus.dispose();
    _notesFocus.dispose();
    _feedback.dispose();
    super.dispose();
  }

  void _save() {
    final t = widget.todo;
    final title = _title.text.trim();
    if (title.isEmpty) {
      _title.text = t.title;
      return;
    }
    if (title == t.title && _notes.text.trimRight() == t.notes) return;
    AppScope.read(context).todos.update(t, title: title, notes: _notes.text.trimRight());
  }

  Future<void> _act(Future<String?> Function() action, {VoidCallback? after}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      error = await action();
    } on Object catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null) after?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final t = widget.todo;
    final run = t.run;
    final active = run != null && !t.done;
    final added = relativeTime(t.created);
    return Section(
      strong: true,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 4),
          child: Row(children: [
            const TagChip('TODO'),
            const SizedBox(width: 8),
            Expanded(child: Text('Added $added · on this Mac', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3))),
            KIconButton(icon: KIcons.trash, label: 'Delete TODO', onTap: () => s.todos.delete(t.id).then((_) => widget.onClose())),
            KIconButton(icon: KIcons.close, label: 'Close (Esc)', onTap: widget.onClose),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
            TextField(
              controller: _title,
              focusNode: _titleFocus,
              style: sans(17, weight: FontWeight.w600, color: c.text, letterSpacing: -0.2),
              cursorColor: c.acc,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration.collapsed(hintText: 'Title'),
            ),
            const SizedBox(height: 12),
            Text('Notes', style: sans(11, color: c.text3)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.chipBorder)),
              child: TextField(
                controller: _notes,
                focusNode: _notesFocus,
                minLines: 4,
                maxLines: 10,
                style: sans(12.5, color: c.text, height: 1.45),
                cursorColor: c.acc,
                decoration: InputDecoration.collapsed(hintText: 'Context for you and the agent: files, links, what done looks like', hintStyle: sans(12.5, color: c.text3)),
              ),
            ),
            if (active) ...[
              const SizedBox(height: 16),
              _worktree(s, c, t, run),
              const SizedBox(height: 16),
              _Progress(todo: t),
            ],
          ]),
        ),
        if (!t.done)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              if (!active) ...[
                if (_formOpen)
                  _StartForm(todo: t, onCancel: () => setState(() => _formOpen = false))
                else ...[
                  KButton.primary(label: 'Run with an agent', icon: KIcons.sparkle, height: 36, expand: true, onTap: () => setState(() => _formOpen = true)),
                  const SizedBox(height: 6),
                  Text('Nothing starts until you click. It stays here meanwhile.', textAlign: TextAlign.center, style: sans(11.5, color: c.text3)),
                ],
              ] else
                ..._actions(s, c, t, run),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, maxLines: 4, overflow: TextOverflow.ellipsis, style: sans(12, color: c.err)),
              ],
            ]),
          ),
      ]),
    );
  }

  Widget _worktree(AppState s, KumoPalette c, TodoItem t, TodoRun run) {
    final terminal = s.agents.runs.where((r) => r.id == run.sessionId && r.status != AgentStatus.done).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(KIcons.branch, size: 12, color: c.text3),
        const SizedBox(width: 6),
        Text('Its worktree', style: sans(11, color: c.text3)),
      ]),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
        decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(run.branch, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(12, weight: FontWeight.w500, color: c.text)),
              Text(run.worktreePath, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3)),
              if (run.describe.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(KIcons.sparkle, size: 12, color: c.acc),
                  const SizedBox(width: 5),
                  Flexible(child: Text(run.describe, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text2))),
                ]),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          KButton(
            label: 'Terminal',
            icon: KIcons.terminal,
            height: 28,
            fontSize: 12,
            onTap: () {
              if (terminal != null) {
                s.openTerminal(terminal.terminalId, title: terminal.title, agent: true, directory: run.worktreePath);
              } else {
                final where = s.todoWorktree(t);
                if (where != null) s.openWorktree(where.$2);
              }
            },
          ),
        ]),
      ),
    ]);
  }

  /// Its agent ended before saying it was done: why (its last line), and
  /// starting it again in the same worktree, or reviewing what it left.
  List<Widget> _stopped(AppState s, KumoPalette c, TodoItem t, TodoRun run, String agent) {
    final session = s.agents.runs.where((r) => r.id == run.sessionId).firstOrNull;
    final last = session?.lastLine.trim() ?? '';
    final code = session?.exitCode ?? 0;
    if (_retrying) return [_StartForm(todo: t, retry: true, onCancel: () => setState(() => _retrying = false))];
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.errSoft, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(KIcons.warning, size: 15, color: c.err),
            const SizedBox(width: 7),
            Expanded(child: Text('$agent stopped before finishing', style: sans(13, weight: FontWeight.w600, color: c.err))),
          ]),
          const SizedBox(height: 6),
          Text(
            session == null
                ? 'Its session is gone (Kumo restarted, or it was closed). The worktree and its changes are still there.'
                : code == 0
                    ? 'It exited without reporting the change done.'
                    : 'It exited with code $code.',
            style: sans(12, color: c.text2, height: 1.45),
          ),
          if (last.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(8)),
              child: Text(last, maxLines: 4, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text2, height: 1.4)),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: KButton(
            label: 'Review what it did',
            height: 32,
            expand: true,
            onTap: _busy ? null : () => _act(() async => await s.todos.setStatus(t.id, TodoStatus.review, by: 'You', note: '$agent stopped before finishing') == null ? s.todos.error : null),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: KButton.primary(label: 'Try again', icon: KIcons.refresh, height: 32, expand: true, onTap: () => setState(() => _retrying = true))),
      ]),
    ];
  }

  void _reviewChanges(AppState s, TodoItem t) {
    final where = s.todoWorktree(t);
    if (where == null) return;
    s.selectWorktree(where.$2.branch, path: where.$2.path);
    s.view = KumoView.git;
  }

  List<Widget> _actions(AppState s, KumoPalette c, TodoItem t, TodoRun run) {
    final agent = run.agentName.isEmpty ? 'the agent' : run.agentName;
    switch (t.status) {
      case TodoStatus.open:
      case TodoStatus.working:
      case TodoStatus.testing:
        if (todoAgentStopped(s, t)) return _stopped(s, c, t, run, agent);
        return [
          Row(children: [
            Icon(t.status == TodoStatus.testing ? KIcons.flask : KIcons.sparkle, size: 14, color: t.status == TodoStatus.testing ? c.cyan : c.acc),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.status == TodoStatus.testing ? '$agent is testing its change. It asks for your review when the tests pass.' : '$agent is on it. It moves to testing when the change is written.',
                style: sans(12.5, color: c.text2, height: 1.45),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          KButton(label: 'Stop agent', icon: KIcons.pause, height: 32, expand: true, onTap: _busy ? null : () => _act(() async {
                await s.stopTodoAgent(t);
                return s.todos.error;
              })),
        ];
      case TodoStatus.review:
        final note = t.stepOf(TodoStatus.review)?.note ?? '';
        return [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.warnSoft, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(KIcons.compare, size: 15, color: c.warn),
                const SizedBox(width: 7),
                Expanded(child: Text('Your turn: test it and approve it', style: sans(13, weight: FontWeight.w600, color: c.warn))),
              ]),
              const SizedBox(height: 6),
              Text(
                note.isNotEmpty ? note : '$agent says it’s done. Try it in its worktree, then approve it or ask for changes.',
                style: sans(12, color: c.text2, height: 1.45),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                KButton(label: 'Review changes', icon: KIcons.compare, height: 30, fontSize: 12, onTap: () => _reviewChanges(s, t)),
              ]),
            ]),
          ),
          const SizedBox(height: 10),
          if (_asking) ...[
            Text('What should change?', style: sans(11, color: c.text3)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.chipBorder)),
              child: TextField(
                controller: _feedback,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                style: sans(12.5, color: c.text, height: 1.45),
                cursorColor: c.acc,
                decoration: InputDecoration.collapsed(hintText: 'e.g. The retry banner covers the job list: put it under the header.', hintStyle: sans(12.5, color: c.text3)),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: KButton(label: 'Cancel', height: 32, expand: true, onTap: () => setState(() => _asking = false))),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: KButton.primary(
                  label: 'Send to $agent',
                  icon: KIcons.send,
                  height: 32,
                  expand: true,
                  onTap: _busy || _feedback.text.trim().isEmpty
                      ? null
                      : () => _act(() => s.askTodoChanges(t, _feedback.text.trim()), after: () {
                            _asking = false;
                            _feedback.clear();
                          }),
                ),
              ),
            ]),
          ] else
            Row(children: [
              Expanded(child: KButton(label: 'Ask for changes', height: 32, expand: true, onTap: () => setState(() => _asking = true))),
              const SizedBox(width: 8),
              Expanded(
                child: KButton.primary(
                  label: _busy ? 'Pushing…' : 'Approve and push',
                  icon: KIcons.check,
                  height: 32,
                  expand: true,
                  onTap: _busy ? null : () => _act(() => s.approveTodo(t)),
                ),
              ),
            ]),
        ];
      case TodoStatus.pushed:
        return [
          Text.rich(
            TextSpan(style: sans(12.5, color: c.text2, height: 1.45), children: [
              const TextSpan(text: 'Pushed to '),
              TextSpan(text: 'origin/${run.branch}', style: mono(12, color: c.text)),
              const TextSpan(text: '. The pull request gets the TODO as its title and your notes as its description.'),
            ]),
          ),
          const SizedBox(height: 10),
          KButton.primary(label: _busy ? 'Opening the PR…' : 'Create PR', icon: KIcons.pullRequest, height: 36, expand: true, onTap: _busy ? null : () => _act(() => s.createTodoPr(t))),
        ];
      case TodoStatus.pr:
        final label = run.prNumber > 0 ? '#${run.prNumber}' : 'PR';
        return [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(color: c.purple.withAlpha(36), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(KIcons.pullRequest, size: 18, color: c.purple),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$label ', style: mono(12.5, weight: FontWeight.w600, color: c.purple)),
                    TextSpan(text: t.title, style: sans(12.5, weight: FontWeight.w600, color: c.text)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              KButton(label: 'Open in Git', height: 28, fontSize: 12, onTap: () => _reviewChanges(s, t)),
            ]),
          ),
          const SizedBox(height: 8),
          Text('Kumo watches the PR. When it merges, this TODO moves to Merged and offers to clean up.', style: sans(11.5, color: c.text3, height: 1.45)),
        ];
      case TodoStatus.merged:
        final auto = s.setting<bool>(AppState.todoAutoCleanSetting, false);
        return [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.okSoft, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(KIcons.merged, size: 15, color: c.ok),
                const SizedBox(width: 7),
                Expanded(child: Text('Merged${run.base.isNotEmpty ? ' into ${run.base}' : ''}', style: sans(13, weight: FontWeight.w600, color: c.ok))),
              ]),
              const SizedBox(height: 4),
              Text('Clean up removes the worktree and its local branch, and checks the TODO off. The PR and its commits stay where they are.',
                  style: sans(12, color: c.text2, height: 1.45)),
            ]),
          ),
          const SizedBox(height: 10),
          KButton.primary(label: _busy ? 'Removing the worktree…' : 'Clean up', icon: KIcons.trash, height: 36, expand: true, onTap: _busy ? null : () => _act(() => s.cleanUpTodo(t), after: widget.onClose)),
          const SizedBox(height: 10),
          Row(children: [
            KSwitch(value: auto, onChanged: (v) => setState(() => s.setSetting(AppState.todoAutoCleanSetting, v)), label: 'Clean up merged TODOs on their own'),
            const SizedBox(width: 8),
            Expanded(child: Text('Clean up merged TODOs on their own', style: sans(12, color: c.text2))),
          ]),
        ];
    }
  }
}

/// Where it is: the six steps, each with who moved it there and when.
class _Progress extends StatelessWidget {
  const _Progress({required this.todo});
  final TodoItem todo;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final t = todo;
    final now = TodoStatus.steps.indexOf(t.status);
    final agent = t.run?.agentName ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('Progress', style: sans(11, color: c.text3))),
        SizedBox(
          width: 190,
          child: KSelect<TodoStatus>(
            label: 'Move to',
            value: t.status == TodoStatus.open ? TodoStatus.working : t.status,
            items: [for (final x in TodoStatus.steps) (x, x.label)],
            onChanged: (v) => s.todos.setStatus(t.id, v, by: 'You'),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      for (final (i, step) in TodoStatus.steps.indexed) _step(c, step, i, now, t),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(KIcons.info, size: 12, color: c.text3)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${agent.isEmpty ? 'The agent' : agent} reports each step to Kumo as it goes. After your approval, Kumo follows the push, the PR and the merge. Move it by hand if you need to.',
            style: sans(11.5, color: c.text3, height: 1.45),
          ),
        ),
      ]),
    ]);
  }

  Widget _step(KumoPalette c, TodoStatus step, int i, int now, TodoItem t) {
    final done = i < now;
    final current = i == now;
    final (color, soft, _) = todoStatusLook(c, step);
    final record = t.stepOf(step);
    final last = i == TodoStatus.steps.length - 1;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 18,
          child: Column(children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? c.accFill : (current ? soft : null),
                border: Border.all(color: done ? c.accFill : (current ? color : c.paneBorder), width: 1.5),
              ),
              child: done
                  ? Icon(KIcons.check, size: 10, color: c.accText)
                  : current
                      ? Center(child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)))
                      : null,
            ),
            if (!last) Expanded(child: Container(width: 1.5, color: done ? c.accFill : c.paneBorder)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1, bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(step.label, style: sans(12.5, weight: current ? FontWeight.w600 : FontWeight.w500, color: current ? c.text : (done ? c.text2 : c.text3))),
                  if (current && record != null && record.note.isNotEmpty) Text(record.note, style: sans(11.5, color: c.text3, height: 1.4)),
                ]),
              ),
              if (record != null && (done || current)) Text('${record.by} · ${relativeTime(record.at)}', style: sans(11, color: c.text3)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Hands the TODO to an agent: repository, base and new branch, the agent,
/// its model and effort. With [retry], it starts the agent again in the
/// TODO's own worktree (the last one stopped before finishing).
class _StartForm extends StatefulWidget {
  const _StartForm({required this.todo, required this.onCancel, this.retry = false});

  final TodoItem todo;
  final VoidCallback onCancel;
  final bool retry;

  @override
  State<_StartForm> createState() => _StartFormState();
}

class _StartFormState extends State<_StartForm> {
  String? _repo;
  RepoBranches? _branches;
  String _base = '';
  late final _branch = TextEditingController(text: suggestTodoBranch(widget.todo.title));
  String? _agent;
  String _model = '';
  String _effort = '';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _branch.addListener(() => setState(() {}));
    final run = widget.todo.run;
    if (widget.retry && run != null) _agent = run.providerId;
    if (widget.retry) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppScope.read(context);
      final first = widget.todo.repoPath.isNotEmpty && s.workspace.repo(widget.todo.repoPath) != null
          ? widget.todo.repoPath
          : (s.recentRepos.firstOrNull ?? s.workspace.repos.firstOrNull?.id);
      _pickRepo(first);
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
      _base = '';
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

  Future<void> _start(AppState s, AgentProviderInfo agent, Repo? repo) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final model = agent.tunable && agent.models.any((m) => m.id == _model) ? _model : '';
    final effort = agent.tunable && agent.takesEffortWith(model) && agent.effortsFor(model).contains(_effort) ? _effort : '';
    final String? error;
    if (widget.retry) {
      error = await s.retryTodo(widget.todo, providerId: agent.id, model: model, effort: effort);
    } else {
      error = await s.startTodo(widget.todo, repo: repo!, branch: _branch.text.trim(), base: _base, providerId: agent.id, model: model, effort: effort);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null && widget.retry) widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final agents = s.agents.connected;
    final retry = widget.retry;
    final repo = retry ? null : (_repo == null ? null : s.workspace.repo(_repo!));
    final agent = agents.where((a) => a.id == _agent).firstOrNull ?? agents.firstOrNull;
    final bases = _branches == null ? <String>[if (_base.isNotEmpty) _base] : [_branches!.current, for (final l in _branches!.local) if (l != _branches!.current) l];
    final model = agent != null && agent.models.any((m) => m.id == _model) ? _model : '';
    final efforts = agent == null ? const <String>[] : agent.effortsFor(model);
    final takesEffort = agent != null && agent.tunable && agent.takesEffortWith(model);
    final hasNotes = widget.todo.notes.trim().isNotEmpty;
    final run = widget.todo.run;
    final ready = !_busy && agent != null && (retry || (repo != null && _branch.text.trim().isNotEmpty));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Icon(KIcons.sparkle, size: 15, color: c.acc),
        const SizedBox(width: 8),
        Expanded(child: Text(retry ? 'Start the agent again' : 'Start in a worktree', style: sans(13.5, weight: FontWeight.w600, color: c.text))),
        KButton(label: 'Not now', kind: KButtonKind.ghost, height: 26, fontSize: 12, onTap: widget.onCancel),
      ]),
      const SizedBox(height: 10),
      if (!retry && s.workspace.repos.isEmpty)
        Text('Add a repository to a namespace first: the worktree is created in it.', style: sans(12, color: c.text3))
      else ...[
        if (retry && run != null)
          Text.rich(
            TextSpan(style: sans(12, color: c.text2, height: 1.45), children: [
              const TextSpan(text: 'In its worktree, on '),
              TextSpan(text: run.branch, style: mono(11.5, color: c.text)),
              const TextSpan(text: ': the new session picks up the changes already there.'),
            ]),
          )
        else ...[
          RepoPicker(label: 'Repository', value: _repo, onChanged: _pickRepo),
          const SizedBox(height: 10),
          Row(children: [
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
            const SizedBox(width: 10),
            Expanded(child: KField(label: 'New branch', controller: _branch, monospace: true)),
          ]),
        ],
        const SizedBox(height: 10),
        if (agents.isEmpty)
          Text('Connect an agent in Settings › AI agents to hand TODOs to it.', style: sans(12, color: c.text3))
        else ...[
          Row(children: [
            Expanded(
              child: KSelect<String>(
                label: 'Agent',
                value: agent!.id,
                items: [for (final a in agents) (a.id, a.name)],
                onChanged: (v) => setState(() {
                  _agent = v;
                  _model = '';
                  _effort = '';
                }),
              ),
            ),
            if (agent.tunable) ...[
              const SizedBox(width: 10),
              Expanded(
                child: KSelect<String>(
                  label: 'Model',
                  value: model,
                  items: [('', 'Its default'), for (final m in agent.models) (m.id, m.name)],
                  onChanged: (v) => setState(() {
                    _model = v;
                    if (!agent.effortsFor(v).contains(_effort)) _effort = '';
                  }),
                ),
              ),
            ],
          ]),
          if (agent.tunable && agent.models.isEmpty) ...[
            const SizedBox(height: 6),
            Text('${agent.name} lists no models Kumo can read: it starts with the one set in its own config.', style: sans(11.5, color: c.text3, height: 1.4)),
          ],
          if (agent.tunable && efforts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Effort', style: sans(11, color: c.text3)),
            const SizedBox(height: 4),
            if (takesEffort)
              KSegmented<String>(
                label: 'Effort',
                expand: true,
                height: 28,
                items: [('', 'Default', null), for (final e in efforts) (e, _effortLabel(e), null)],
                value: efforts.contains(_effort) ? _effort : '',
                onChanged: (v) => setState(() => _effort = v),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
                child: Text('With ${model.isEmpty ? 'its default model' : model}, ${agent.name} picks the effort itself: pick a model to set one.', style: sans(12, color: c.text3)),
              ),
          ] else if (agent.tunable) ...[
            const SizedBox(height: 6),
            Text('${agent.name} has no effort setting.', style: sans(11.5, color: c.text3)),
          ],
        ],
        if (!retry) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(KIcons.info, size: 13, color: c.text2),
                const SizedBox(width: 6),
                Text('The agent’s first prompt', style: sans(12, color: c.text2)),
              ]),
              const SizedBox(height: 6),
              _gets(c, KIcons.check, c.text, 'The TODO: “${widget.todo.title}”'),
              hasNotes
                  ? _gets(c, KIcons.check, c.text, 'Your notes, as written above')
                  : _gets(c, KIcons.info, c.warn, 'No notes yet: a line on what done looks like helps it stop at the right place'),
              _gets(c, KIcons.check, c.text, '${repo?.name ?? '—'}, on ${_branch.text.trim().isEmpty ? '—' : _branch.text.trim()} from ${_base.isEmpty ? '—' : _base}'),
              _gets(c, KIcons.check, c.text, 'How to report its progress: working, testing, then waiting for your review'),
              _gets(c, KIcons.lock, c.text3, 'Nothing else: your other TODOs stay on this Mac'),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        KButton.primary(
          label: _busy
              ? (retry ? 'Starting…' : 'Creating the worktree…')
              : (retry ? 'Start ${agent?.name ?? 'the agent'} again' : 'Create worktree and start ${agent?.name ?? 'agent'}'),
          expand: true,
          height: 36,
          onTap: ready ? () => _start(s, agent, repo) : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, maxLines: 4, overflow: TextOverflow.ellipsis, style: sans(12, color: c.err)),
        ],
      ],
    ]);
  }

  static String _effortLabel(String e) => e == 'xhigh' ? 'X-high' : '${e[0].toUpperCase()}${e.substring(1)}';

  Widget _gets(KumoPalette c, IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 12, color: color)),
          const SizedBox(width: 7),
          Expanded(child: Text(text, style: sans(12, color: color, height: 1.4))),
        ]),
      );
}

/// A branch for [title]: `fix/` for fixes, `test/` for tests, else `feat/`,
/// then up to four of its words.
String suggestTodoBranch(String title) {
  const skip = {'a', 'an', 'the', 'to', 'for', 'of', 'in', 'on', 'when', 'us', 'why', 'it', 'so', 'and', 'add', 'write', 'find', 'out'};
  final lower = title.toLowerCase();
  final words = lower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim().split(' ').where((w) => w.isNotEmpty && !skip.contains(w)).take(4).join('-');
  final prefix = RegExp(r'\b(fix|bug|retry|slow|error|broken|crash)\b').hasMatch(lower)
      ? 'fix/'
      : RegExp(r'\btests?\b').hasMatch(lower)
          ? 'test/'
          : 'feat/';
  return words.isEmpty ? prefix : '$prefix$words';
}
