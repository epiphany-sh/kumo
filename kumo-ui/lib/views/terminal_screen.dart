import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../editor/file_view.dart';
import '../engine/engine_scope.dart';
import '../engine/generated/kumo/v1/kumo.pb.dart' show TerminalInfo;
import '../engine/grpc_terminal_surface.dart';
import '../engine/kumo_engine.dart';
import '../shell/screen_chrome.dart';
import '../shell/side_panel.dart';
import '../terminal/mock_terminal.dart';
import '../terminal/pane_layout.dart';
import '../terminal/terminal_surface.dart';
import '../terminal/terminal_view.dart';
import '../theme/kumo_theme.dart';
import '../widgets/context_menu.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final Map<String, TerminalSurface> _surfaces = {};

  /// Terminal tabs. Each tab holds its own split layout of panes; + / ⌘T
  /// opens a new tab, ⌘D / ⇧⌘D split the focused pane inside the tab.
  final List<_TermTab> _tabs = [];
  int _active = 0;
  KumoEngine? _engine;
  bool _started = false;
  bool _agentConfirm = false;
  int _shellSeq = 0;
  AppState? _app;

  _TermTab? get _tab => _tabs.isEmpty ? null : _tabs[_active < _tabs.length ? _active : _tabs.length - 1];

  /// Layout / focus of the tab showing.
  PaneLayout get _layout => _tab?.layout ?? const PaneLayout([]);
  set _layout(PaneLayout l) => _tab?.layout = l;
  String? get _focus => _tab?.focus;
  set _focus(String? id) => _tab?.focus = id;

  _TermTab? _tabOf(String id) {
    for (final t in _tabs) {
      if (t.layout.contains(id)) return t;
    }
    return null;
  }

  static PaneLayout _single(String id) => PaneLayout([PaneColumn('col-$id', 1, [PaneCell(id, 1)])]);

  /// One key per pane so a pane keeps its state (steer text, scroll) when
  /// a split moves it to another column or into tabs mode.
  final Map<String, GlobalKey> _paneKeys = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) _start();
    final app = AppScope.read(context);
    if (!identical(app, _app)) {
      if (_app?.terminalHandler == _onCommand) _app!.terminalHandler = null;
      _app = app..terminalHandler = _onCommand;
    }
  }

  @override
  void dispose() {
    if (_app?.terminalHandler == _onCommand) _app!.terminalHandler = null;
    for (final t in _surfaces.values) {
      t.dispose();
    }
    super.dispose();
  }

  /// With an engine: the agent (still a mock until M3) and a real shell
  /// that first re-attaches to whatever the daemon kept running.
  /// Without one (widget tests): the scripted mocks.
  void _start() {
    _started = true;
    _engine = EngineScope.maybeOf(context);
    _surfaces['agent'] = MockSessions.agent();
    final engine = _engine;
    if (engine == null) {
      _surfaces['tests'] = MockSessions.tests();
      _surfaces['logs'] = MockSessions.logs();
      _tabs.add(_TermTab('t-agent', PaneLayout.initial, 'agent'));
      return;
    }
    _shellSeq = 1;
    _surfaces['sh-1'] = GrpcTerminalSurface.shell(engine, adopt: _adoptRunning, onExit: (_) => _closeExited('sh-1'));
    _tabs.add(_TermTab('t-agent', PaneLayout.live, 'sh-1'));
  }

  /// Terminals left running by a previous UI session: the first one fills
  /// the initial shell pane, the rest get panes of their own.
  Future<TerminalInfo?> _adoptRunning() async {
    final running = await _engine!.runningTerminals();
    if (running.isEmpty || !mounted) return null;
    for (final info in running.skip(1)) {
      final id = 'sh-${++_shellSeq}';
      _surfaces[id] = GrpcTerminalSurface.attach(_engine!, terminalId: info.terminalId, program: info.program, onExit: (_) => _closeExited(id));
      // Each re-attached terminal comes back as a tab of its own.
      setState(() => _tabs.add(_TermTab('t-$id', _single(id), id)));
    }
    return running.first;
  }

  /// A shell that exits closes its pane, like other terminals do.
  void _closeExited(String id) {
    if (mounted && _tabOf(id) != null) _close(id);
  }

  void _onCommand(TerminalCommand cmd) {
    switch (cmd) {
      case TerminalCommand.splitRight:
        _splitRight(_focus);
      case TerminalCommand.splitDown:
        _splitDown(_focus);
      case TerminalCommand.closePane:
        final file = _app?.activeFile;
        if (file != null) {
          _app!.closeFile(file);
        } else {
          _close(_focus);
        }
      case TerminalCommand.newTerminal:
        _newTab();
    }
  }

  String _newShell() {
    final n = ++_shellSeq;
    final id = 'sh-$n';
    final engine = _engine;
    _surfaces[id] = engine == null ? MockSessions.shell(n) : GrpcTerminalSurface.shell(engine, onExit: (_) => _closeExited(id));
    return id;
  }

  void _splitRight(String? target) {
    if (_tab == null) return _newTab();
    final id = _newShell();
    setState(() {
      _layout = _layout.splitRight(target, id, columnId: 'col-$id');
      _focus = id;
      _agentConfirm = false;
    });
  }

  void _splitDown(String? target) {
    if (_tab == null) return _newTab();
    final id = _newShell();
    setState(() {
      _layout = _layout.splitDown(target, id, columnId: 'col-$id');
      _focus = id;
      _agentConfirm = false;
    });
  }

  /// + / ⌘T: always a new tab with one fresh shell.
  void _newTab() {
    final id = _newShell();
    _app?.showTerminals();
    setState(() {
      _tabs.add(_TermTab('t-$id', _single(id), id));
      _active = _tabs.length - 1;
      _agentConfirm = false;
    });
  }

  void _activate(_TermTab t) {
    _app?.showTerminals();
    final i = _tabs.indexOf(t);
    if (i >= 0 && i != _active) setState(() => _active = i);
  }

  void _dropTab(_TermTab t) {
    final i = _tabs.indexOf(t);
    if (i < 0) return;
    _tabs.removeAt(i);
    if (i < _active || _active >= _tabs.length) _active = _active > 0 ? _active - 1 : 0;
  }

  void _disposeLater(String id) {
    final surface = _surfaces.remove(id);
    _paneKeys.remove(id);
    // Dispose after the pane is gone from the tree.
    if (surface != null) WidgetsBinding.instance.addPostFrameCallback((_) => surface.dispose());
  }

  /// ⌘W / pane ×: closes one pane; the tab goes away with its last pane.
  /// Closing the running agent asks first (a second ⌘W confirms).
  void _close(String? id) {
    if (id == null) return;
    final t = _tabOf(id);
    if (t == null) return;
    if (id == 'agent' && !_agentConfirm) {
      _activate(t);
      setState(() {
        _agentConfirm = true;
        t.focus = 'agent';
      });
      return;
    }
    _disposeLater(id);
    setState(() {
      t.focus = t.focus == id ? t.layout.focusAfterRemoving(id) : t.focus;
      t.layout = t.layout.remove(id);
      if (t.layout.isEmpty) _dropTab(t);
      if (id == 'agent') _agentConfirm = false;
    });
  }

  /// Tab ×: closes every pane in the tab (asks first if the agent runs there).
  void _closeTab(_TermTab t) {
    if (t.layout.contains('agent') && !_agentConfirm) {
      _activate(t);
      setState(() {
        _agentConfirm = true;
        t.focus = 'agent';
      });
      return;
    }
    for (final id in t.layout.panes) {
      _disposeLater(id);
    }
    setState(() {
      if (t.layout.contains('agent')) _agentConfirm = false;
      _dropTab(t);
    });
  }

  void _setFocus(String id) {
    _app?.showTerminals();
    if (_focus != id) setState(() => _focus = id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    return ScreenFrame(
      toolbar: ScreenToolbar(
        breadcrumb: Breadcrumb(icon: KIcons.branch, parts: [s.activeRepo?.name ?? 'No repository', if (s.changes.branch.isNotEmpty) s.changes.branch]),
        primary: KButton.primary(label: 'New agent', icon: KIcons.agent, height: 36, onTap: () {}),
      ),
      body: LayoutBuilder(builder: (context, box) {
        final showPanel = s.sidePanelOpen && box.maxWidth >= 640;
        // Settings › General › Side panel position.
        final right = s.sidePanelRight;
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (showPanel && !right) ...[const SizedBox(width: 300, child: SidePanel()), const SizedBox(width: 10)],
          Expanded(
            // Hybrid mode: this subtree uses the dark "smoked glass" palette.
            child: KumoTheme.scope(context: context, palette: context.tc, child: Builder(builder: _terminalArea)),
          ),
          if (showPanel && right) ...[const SizedBox(width: 10), const SizedBox(width: 300, child: SidePanel())],
        ]);
      }),
      status: [
        Flexible(child: StatusText('${s.changes.branch} ↑${s.commitsAhead} ↓${s.changes.behind}', icon: KIcons.branch, monospace: true, flexible: true)),
        StatusText('1 agent needs you', color: c.warn, dot: true),
        const StatusText('2 agents running'),
        const StatusText('gke-staging · pricing', icon: KIcons.cluster),
        const Spacer(),
        StatusText('${_tabs.length} ${_tabs.length == 1 ? 'tab' : 'tabs'} · ${_layout.panes.length} ${_layout.panes.length == 1 ? 'pane' : 'panes'}'),
        const StatusText('zsh · UTF-8'),
        if (_engine != null) _EngineStatus(engine: _engine!),
      ],
    );
  }

  (IconData, Color) _look(BuildContext context, String id) {
    final c = context.c;
    return switch (id) {
      'agent' => (KIcons.agent, c.acc),
      'tests' => (KIcons.terminal, c.ok),
      'logs' => (KIcons.cluster, c.cyan),
      _ => (KIcons.terminal, c.text2),
    };
  }

  String _tabLabel(String id) => id == 'agent' ? 'claude · PRC-412' : (_surfaces[id]?.title ?? id);

  Widget _terminalArea(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    return GlassPanel(
      fill: c.term,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  if (!s.sidePanelOpen && !s.sidePanelRight) ...[
                    KIconButton(icon: KIcons.sidePanel, label: 'Show side panel (⌥⌘B)', size: 30, iconSize: 16, onTap: s.toggleSidePanel),
                    const SizedBox(width: 4),
                  ],
                  for (final t in _tabs) ...[_tabChip(context, t), const SizedBox(width: 4)],
                  for (final p in s.openFiles) ...[_fileTab(context, p), const SizedBox(width: 4)],
                  KIconButton(icon: KIcons.add, label: 'New tab (⌘T)', size: 30, iconSize: 15, onTap: _newTab),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(11)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                KIconButton(icon: KIcons.splitRight, label: 'Split right (⌘D)', size: 28, iconSize: 15, onTap: () => _splitRight(_focus)),
                KIconButton(icon: KIcons.splitDown, label: 'Split down (⇧⌘D)', size: 28, iconSize: 15, onTap: () => _splitDown(_focus)),
              ]),
            ),
            if (!s.sidePanelOpen && s.sidePanelRight) ...[
              const SizedBox(width: 4),
              KIconButton(icon: KIcons.sidePanel, label: 'Show side panel (⌥⌘B)', size: 30, iconSize: 16, onTap: s.toggleSidePanel),
            ],
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: s.activeFile != null
                ? FileView(key: ValueKey(s.activeFile), path: s.activeFile!)
                : _layout.isEmpty
                ? _empty(context)
                : _splitPanes(context),
          ),
        ),
      ]),
    );
  }

  /// A tab chip: the title of its focused pane, plus how many panes it has.
  Widget _tabChip(BuildContext context, _TermTab t) {
    final c = context.c;
    final id = t.focus != null && t.layout.contains(t.focus!) ? t.focus! : t.layout.panes.first;
    final (_, dot) = _look(context, id);
    final on = identical(t, _tab) && AppScope.of(context).activeFile == null;
    final label = _tabLabel(id);
    final n = t.layout.panes.length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: 30,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: on ? chipDecoration(c, radius: 10, fill: c.tabActive) : BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        KPressable(
          onTap: () => _activate(t),
          semanticLabel: 'Terminal tab $label${n > 1 ? ', $n panes' : ''}',
          selected: on,
          builder: (context, hover, focus) => Row(mainAxisSize: MainAxisSize.min, children: [
            Dot(dot),
            const SizedBox(width: 8),
            Text(label, style: sans(12, weight: FontWeight.w500, color: on || hover ? c.text : c.text2)),
            if (n > 1) ...[
              const SizedBox(width: 6),
              Icon(KIcons.splitRight, size: 12, color: c.text3),
              const SizedBox(width: 2),
              Text('$n', style: sans(11, color: c.text3)),
            ],
          ]),
        ),
        const SizedBox(width: 6),
        KIconButton(icon: KIcons.close, label: 'Close tab $label', size: 18, iconSize: 11, color: c.text3, onTap: () => _closeTab(t)),
      ]),
    );
  }

  Widget _fileTab(BuildContext context, String path) {
    final c = context.c;
    final s = AppScope.of(context);
    final f = s.changedFile(path);
    final name = path.substring(path.lastIndexOf('/') + 1);
    final col = f == null ? c.text3 : (f.kind == 'A' ? c.ok : c.warn);
    final on = s.activeFile == path;
    return Tooltip(
      message: path,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 30,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: on ? chipDecoration(c, radius: 10, fill: c.tabActive) : BoxDecoration(borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          KPressable(
            onTap: () => s.openFile(path),
            semanticLabel: 'File tab $path',
            selected: on,
            builder: (context, hover, focus) => Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(KIcons.file, size: 13, color: col),
              const SizedBox(width: 7),
              Text(name, style: mono(11.5, color: on || hover ? c.text : c.text2)),
              if (f != null) ...[const SizedBox(width: 6), Text(f.kind, style: mono(10, weight: FontWeight.w700, color: col))],
            ]),
          ),
          const SizedBox(width: 6),
          KIconButton(icon: KIcons.close, label: 'Close $name (⌘W)', size: 18, iconSize: 11, color: c.text3, onTap: () => s.closeFile(path)),
        ]),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final c = context.c;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(KIcons.terminal, size: 26, color: c.text3),
        const SizedBox(height: 12),
        Text('No terminals open in this worktree', style: sans(12.5, color: c.text3)),
        const SizedBox(height: 12),
        KButton(label: 'New tab', height: 30, onTap: _newTab),
      ]),
    );
  }

  Widget _splitPanes(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cols = _layout.columns;
      final children = <Widget>[];
      for (var ci = 0; ci < cols.length; ci++) {
        if (ci > 0) {
          final index = ci;
          children.add(_Splitter(
            axis: Axis.horizontal,
            onDrag: (d) => setState(() => _layout = _layout.resizeColumns(index, d, box.maxWidth)),
            onReset: () => setState(() => _layout = _layout.evenColumns()),
          ));
        }
        children.add(Expanded(flex: _flex(cols[ci].weight), child: _column(context, ci)));
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    });
  }

  Widget _column(BuildContext context, int ci) {
    return LayoutBuilder(builder: (context, box) {
      final cells = _layout.columns[ci].cells;
      final children = <Widget>[];
      for (var ri = 0; ri < cells.length; ri++) {
        if (ri > 0) {
          final index = ri;
          children.add(_Splitter(
            axis: Axis.vertical,
            onDrag: (d) => setState(() => _layout = _layout.resizeRows(ci, index, d, box.maxHeight)),
            onReset: () => setState(() => _layout = _layout.evenRows(ci)),
          ));
        }
        children.add(Expanded(flex: _flex(cells[ri].weight), child: _pane(context, cells[ri].id)));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    });
  }

  static int _flex(double w) => (w * 1000).round().clamp(1, 1 << 30).toInt();

  Widget _pane(BuildContext context, String id) {
    final c = context.c;
    final surface = _surfaces[id]!;
    final (icon, color) = _look(context, id);
    final isAgent = id == 'agent';
    final focused = id == _focus && _layout.panes.length > 1;
    return LayoutBuilder(
      key: _paneKeys.putIfAbsent(id, GlobalKey.new),
      builder: (context, box) {
        final compact = box.maxWidth < 340;
        final tools = Row(mainAxisSize: MainAxisSize.min, children: [
          KIconButton(icon: KIcons.splitRight, label: 'Split right (⌘D)', size: 22, iconSize: 14, color: c.text3, onTap: () => _splitRight(id)),
          KIconButton(icon: KIcons.splitDown, label: 'Split down (⇧⌘D)', size: 22, iconSize: 14, color: c.text3, onTap: () => _splitDown(id)),
          KIconButton(icon: KIcons.close, label: 'Close pane (⌘W)', size: 22, iconSize: 13, color: c.text3, onTap: () => _close(id)),
        ]);
        Widget? status;
        if (isAgent) {
          final paused = AppScope.of(context).agentPaused;
          status = Pill(label: paused ? 'Paused' : 'Running · 12:04', color: paused ? c.warn : c.acc, background: paused ? c.warnSoft : c.accSoft);
        } else if (id == 'tests') {
          status = Text('148 passed', style: sans(11, weight: FontWeight.w600, color: c.ok));
        } else if (id == 'logs') {
          status = Text('1 warning', style: sans(11, weight: FontWeight.w600, color: c.warn));
        }
        final trailing = isAgent && _agentConfirm
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                if (!compact) ...[Text('Agent is still running', style: sans(11.5, color: c.text2)), const SizedBox(width: 8)],
                KButton(label: 'Keep', height: 24, fontSize: 11.5, onTap: () => setState(() => _agentConfirm = false)),
                const SizedBox(width: 6),
                DangerButton(label: 'Stop & close', height: 24, onTap: () => _close('agent')),
              ])
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (status != null && !compact) ...[status, const SizedBox(width: 6)],
                tools,
              ]);
        return TerminalPane(
          surface: surface,
          icon: icon,
          iconColor: color,
          focused: focused,
          active: id == _focus && AppScope.of(context).activeFile == null,
          onFocus: () => _setFocus(id),
          trailing: trailing,
          footer: isAgent ? _SteerBar(surface: surface, paused: AppScope.of(context).agentPaused, onPause: AppScope.read(context).toggleAgentPaused) : null,
        );
      },
    );
  }
}

/// One terminal tab: its own split layout and focused pane.
class _TermTab {
  _TermTab(this.id, this.layout, this.focus);
  final String id;
  PaneLayout layout;
  String? focus;
}

/// Daemon connection state in the status bar.
class _EngineStatus extends StatelessWidget {
  const _EngineStatus({required this.engine});
  final KumoEngine engine;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) => switch (engine.status) {
        EngineStatus.ready => StatusText('kumod ${engine.current?.serverVersion ?? ''}', color: c.ok, dot: true),
        EngineStatus.connecting => StatusText('kumod starting…', color: c.text3, dot: true),
        EngineStatus.failed => Tooltip(message: engine.error ?? '', child: StatusText('kumod offline', color: c.err, dot: true)),
      },
    );
  }
}

/// Draggable gap between panes. [axis] is the direction the panes are laid
/// out in: horizontal = a vertical bar between columns.
class _Splitter extends StatefulWidget {
  const _Splitter({required this.axis, required this.onDrag, required this.onReset});
  final Axis axis;
  final ValueChanged<double> onDrag;
  final VoidCallback onReset;

  @override
  State<_Splitter> createState() => _SplitterState();
}

class _SplitterState extends State<_Splitter> {
  bool _hover = false;
  bool _drag = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final h = widget.axis == Axis.horizontal;
    final grip = AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: _hover || _drag ? 1 : 0.28,
      child: Container(
        width: h ? 4 : 40,
        height: h ? 40 : 4,
        decoration: BoxDecoration(color: _drag ? c.acc : c.text3, borderRadius: BorderRadius.circular(2)),
      ),
    );
    return Semantics(
      label: 'Resize panes',
      hint: 'Drag to resize, double-click to reset',
      child: MouseRegion(
        cursor: h ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: widget.onReset,
          onHorizontalDragStart: h ? (_) => setState(() => _drag = true) : null,
          onHorizontalDragUpdate: h ? (d) => widget.onDrag(d.delta.dx) : null,
          onHorizontalDragEnd: h ? (_) => setState(() => _drag = false) : null,
          onVerticalDragStart: h ? null : (_) => setState(() => _drag = true),
          onVerticalDragUpdate: h ? null : (d) => widget.onDrag(d.delta.dy),
          onVerticalDragEnd: h ? null : (_) => setState(() => _drag = false),
          child: SizedBox(width: h ? 10 : null, height: h ? null : 10, child: Center(child: grip)),
        ),
      ),
    );
  }
}

/// "STEER" composer under the agent pane: message the running agent.
class _SteerBar extends StatefulWidget {
  const _SteerBar({required this.surface, required this.paused, required this.onPause});
  final TerminalSurface surface;
  final bool paused;
  final VoidCallback onPause;

  @override
  State<_SteerBar> createState() => _SteerBarState();
}

class _SteerBarState extends State<_SteerBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    widget.surface.sendText(_ctrl.text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(12, 5, 5, 5),
      decoration: chipDecoration(c, radius: 14),
      child: Row(children: [
        Text('STEER', style: sans(10.5, weight: FontWeight.w700, color: c.acc, letterSpacing: 0.8)),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            label: 'Message the agent',
            textField: true,
            child: TextField(
              controller: _ctrl,
              onSubmitted: (_) => _send(),
              style: sans(12.5, color: c.text),
              cursorColor: c.acc,
              decoration: InputDecoration.collapsed(hintText: 'Tell Claude to change course, or / for commands', hintStyle: sans(12.5, color: c.text3)),
            ),
          ),
        ),
        KIconButton(icon: widget.paused ? Icons.play_arrow_rounded : KIcons.pause, label: widget.paused ? 'Resume agent' : 'Pause agent', size: 30, iconSize: 15, onTap: widget.onPause),
        const SizedBox(width: 4),
        KPressable(
          onTap: _send,
          semanticLabel: 'Send to agent',
          builder: (context, hover, focus) => Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: c.accFill, borderRadius: BorderRadius.circular(10)),
            child: Icon(KIcons.send, size: 16, color: c.accText),
          ),
        ),
      ]),
    );
  }
}
