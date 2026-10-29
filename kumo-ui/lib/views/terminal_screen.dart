import 'dart:io';

import 'package:flutter/gestures.dart' show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/agents_source.dart';
import '../data/models.dart' show AgentStatus;
import '../data/worktree_changes.dart' show CommitInfo;
import '../editor/file_view.dart';
import '../overlays/new_agent_dialog.dart';
import '../engine/engine_scope.dart';
import '../engine/generated/kumo/v1/kumo.pb.dart' show TerminalInfo;
import '../engine/grpc_terminal_surface.dart';
import '../engine/kumo_engine.dart';
import '../shell/screen_chrome.dart';
import '../shell/side_panel.dart';
import '../theme/palette.dart';
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

  /// One space of terminals per worktree, by its absolute path ('' when
  /// none is selected): selecting a worktree shows its space, and the others
  /// keep running. Each holds tabs; each tab its own split layout of panes.
  /// + / ⌘T opens a new tab, ⌘D / ⇧⌘D split the focused pane inside the tab.
  final Map<String, _Space> _spaces = {};
  String _spaceKey = '';
  KumoEngine? _engine;
  bool _started = false;
  bool _agentConfirm = false;
  int _shellSeq = 0;
  AppState? _app;

  /// Whether a shell already took over the terminals the daemon kept
  /// running from a previous UI session.
  bool _adopted = false;

  _Space get _space => _spaces.putIfAbsent(_spaceKey, _Space.new);

  /// The space of Home: shells in the home folder, tied to no repository.
  static const _homeKey = '~';
  List<_TermTab> get _tabs => _space.tabs;
  int get _active => _space.active;
  set _active(int i) => _space.active = i;

  _TermTab? get _tab => _tabs.isEmpty ? null : _tabs[_active < _tabs.length ? _active : _tabs.length - 1];

  /// Layout / focus of the tab showing.
  PaneLayout get _layout => _tab?.layout ?? const PaneLayout([]);
  set _layout(PaneLayout l) => _tab?.layout = l;
  String? get _focus => _tab?.focus;
  set _focus(String? id) => _tab?.focus = id;

  _TermTab? _tabOf(String id) {
    for (final space in _spaces.values) {
      for (final t in space.tabs) {
        if (t.layout.contains(id)) return t;
      }
    }
    return null;
  }

  /// The key of the space holding [t].
  String? _spaceOf(_TermTab t) => _spaces.entries.where((e) => e.value.tabs.contains(t)).firstOrNull?.key;

  /// The selected worktree's space key.
  static String _keyOf(AppState s) {
    final entry = s.activeWorktreeEntry;
    return entry == null ? '' : s.workspace.absolutePathOf(entry);
  }

  /// The space of the worktree [directory] is in (the deepest one), or the
  /// current one when it's in none.
  String _spaceFor(String? directory) {
    final s = _app;
    if (directory == null || directory.isEmpty || s == null) return _spaceKey;
    var best = '';
    for (final r in s.workspace.repos) {
      for (final w in r.worktrees) {
        final path = s.workspace.absolutePathOf(w);
        if ((directory == path || directory.startsWith('$path${Platform.pathSeparator}')) && path.length > best.length) best = path;
      }
    }
    return best.isEmpty ? _spaceKey : best;
  }

  /// Where new shells of space [key] start: the worktree, if it's a real
  /// path (the design mocks' aren't), else the home directory.
  static String? _directoryOf(String key) => key.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(key) ? key : null;

  /// The worktree at [directory] was removed: its space goes away with its
  /// terminals (shells are killed; agents were stopped by the app).
  void _closeSpace(String directory) {
    final space = _spaces.remove(directory);
    if (space == null || !mounted) return;
    for (final t in space.tabs) {
      for (final id in t.layout.panes) {
        _disposeLater(id);
      }
    }
    setState(() {});
  }

  /// Shows space [key] by selecting its worktree (or Home).
  void _showSpace(String key) {
    final s = _app;
    if (s == null || key == _spaceKey) return;
    if (key == _homeKey) return s.showHome();
    for (final r in s.workspace.repos) {
      for (final w in r.worktrees) {
        if (s.workspace.absolutePathOf(w) == key) return s.selectWorktree(w.branch, path: w.path);
      }
    }
  }

  /// Switches to the selected worktree's space. The first time a space
  /// shows, it gets a shell in the worktree (unless it has one already,
  /// e.g. one the daemon kept running); an agent opened there before
  /// stays in front.
  void _enter(String key) {
    _spaceKey = key;
    final space = _space;
    final engine = _engine;
    if (space.visited) return;
    space.visited = true;
    if (engine == null) {
      // Design mocks: Home starts with one shell.
      if (key == _homeKey) {
        final id = _newShell();
        space.tabs.add(_TermTab('t-$id', _single(id), id));
      }
      return;
    }
    final hasShell = space.tabs.any((t) => t.layout.panes.any((p) => !_agentPanes.contains(p)));
    if (hasShell) return;
    final id = 'sh-${++_shellSeq}';
    final adopt = !_adopted;
    _adopted = true;
    _surfaces[id] = GrpcTerminalSurface.shell(
      engine,
      directory: _directoryOf(key),
      adopt: adopt ? () => _adoptRunning(key) : null,
      onExit: (_) => _closeExited(id),
    );
    space.tabs.insert(0, _TermTab('t-$id', _single(id), id));
    if (space.tabs.length > 1) space.active++;
  }

  static PaneLayout _single(String id) => PaneLayout([PaneColumn('col-$id', 1, [PaneCell(id, 1)])]);

  /// Panes showing an agent's terminal, and the daemon terminal behind each
  /// pane opened on request (agents, sign-in flows).
  final Set<String> _agentPanes = {};
  final Map<String, String> _terminalOf = {};

  /// One key per pane so a pane keeps its state (steer text, scroll) when
  /// a split moves it to another column or into tabs mode.
  final Map<String, GlobalKey> _paneKeys = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) _start();
    final app = AppScope.read(context);
    if (!identical(app, _app)) {
      _unregister();
      _app = app
        ..terminalHandler = _onCommand
        ..terminalOpener = _openTerminal
        ..terminalSpaceCloser = _closeSpace;
    }
  }

  void _unregister() {
    final app = _app;
    if (app == null) return;
    if (app.terminalHandler == _onCommand) app.terminalHandler = null;
    if (app.terminalOpener == _openTerminal) app.terminalOpener = null;
    if (app.terminalSpaceCloser == _closeSpace) app.terminalSpaceCloser = null;
  }

  @override
  void dispose() {
    _unregister();
    for (final t in _surfaces.values) {
      t.dispose();
    }
    super.dispose();
  }

  /// With an engine, shells open as worktrees are shown (see [_enter]); the
  /// first re-attaches to whatever the daemon kept running.
  /// Without one (widget tests): the scripted mocks.
  void _start() {
    _started = true;
    _engine = EngineScope.maybeOf(context);
    if (_engine != null) return;
    _surfaces['agent'] = MockSessions.agent();
    _surfaces['tests'] = MockSessions.tests();
    _surfaces['logs'] = MockSessions.logs();
    _spaceKey = _keyOf(AppScope.read(context));
    _tabs.add(_TermTab('t-agent', PaneLayout.initial, 'agent'));
  }

  /// Terminals left running by a previous UI session, each back with its
  /// worktree: the first one of space [key] fills the shell pane opening
  /// there, the rest get tabs of their own.
  Future<TerminalInfo?> _adoptRunning(String key) async {
    final all = await _engine!.runningTerminals();
    if (!mounted) return null;
    // Agents' terminals come back as agent tabs (closing those detaches).
    final agents = _app!.agents;
    await agents.ready.timeout(const Duration(seconds: 2), onTimeout: () {});
    if (!mounted) return null;
    final runs = {for (final r in agents.runs) r.terminalId: r};
    for (final info in all.where((t) => runs.containsKey(t.terminalId))) {
      final run = runs[info.terminalId]!;
      _openTerminal(info.terminalId, run.title, agent: true, focus: false, directory: run.worktreePath);
    }
    TerminalInfo? here;
    for (final info in all.where((t) => !runs.containsKey(t.terminalId))) {
      final space = _spaceFor(info.cwd);
      if (here == null && space == key) {
        here = info;
        continue;
      }
      final id = 'sh-${++_shellSeq}';
      _surfaces[id] = GrpcTerminalSurface.attach(_engine!, terminalId: info.terminalId, program: info.program, directory: info.cwd, onExit: (_) => _closeExited(id));
      // Each re-attached terminal comes back as a tab of its own.
      setState(() => _spaces.putIfAbsent(space, _Space.new).tabs.add(_TermTab('t-$id', _single(id), id)));
    }
    return here;
  }

  /// Shows a daemon terminal in a new tab (or focuses the one showing it),
  /// in the space of the worktree [directory] is in.
  void _openTerminal(String terminalId, String title, {bool agent = false, bool focus = true, String? directory}) {
    final engine = _engine;
    if (engine == null || !mounted) return;
    final shown = _terminalOf.entries.where((e) => e.value == terminalId).firstOrNull?.key;
    final shownIn = shown == null ? null : _tabOf(shown);
    if (shownIn != null) {
      _activate(shownIn);
      setState(() => shownIn.focus = shown);
      return;
    }
    final id = '${agent ? 'ag' : 'sh'}-${++_shellSeq}';
    _surfaces[id] = GrpcTerminalSurface.attach(
      engine,
      terminalId: terminalId,
      program: title,
      title: title,
      directory: directory,
      killOnClose: !agent,
      onExit: agent ? null : (_) => _closeExited(id),
    );
    _terminalOf[id] = terminalId;
    if (agent) _agentPanes.add(id);
    final key = _spaceFor(directory);
    final space = _spaces.putIfAbsent(key, _Space.new);
    setState(() {
      space.tabs.add(_TermTab('t-$id', _single(id), id));
      if (focus) space.active = space.tabs.length - 1;
    });
    if (focus) _showSpace(key);
  }

  /// The agent session shown in pane [id], if any.
  AgentRun? _runOf(String id) {
    final terminal = _terminalOf[id];
    return terminal == null ? null : _app?.agents.runs.where((r) => r.terminalId == terminal).firstOrNull;
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
        final ctx = _app?.activeContext;
        final file = _app?.activeFile;
        final ctxFile = _app?.contextFile;
        if (ctx == ContextTab.files && ctxFile != null) {
          // In the Files tab ⌘W closes the file showing, then the tab.
          _app!.askClose(ctxFile, files: true);
        } else if (ctx != null) {
          _app!.closeContext(ctx);
        } else if (file != null) {
          _app!.askClose(file);
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
    _surfaces[id] = engine == null ? (_spaceKey == _homeKey ? MockSessions.homeShell(n) : MockSessions.shell(n)) : GrpcTerminalSurface.shell(engine, directory: _directoryOf(_spaceKey), onExit: (_) => _closeExited(id));
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
    final key = _spaceOf(t);
    if (key == null) return;
    final space = _spaces[key]!;
    final i = space.tabs.indexOf(t);
    if (i >= 0 && i != space.active) setState(() => space.active = i);
    _showSpace(key);
  }

  void _dropTab(_TermTab t) {
    final key = _spaceOf(t);
    if (key == null) return;
    final space = _spaces[key]!;
    final i = space.tabs.indexOf(t);
    space.tabs.removeAt(i);
    if (i < space.active || space.active >= space.tabs.length) space.active = space.active > 0 ? space.active - 1 : 0;
  }

  void _disposeLater(String id) {
    final surface = _surfaces.remove(id);
    _paneKeys.remove(id);
    _agentPanes.remove(id);
    _terminalOf.remove(id);
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
    final s = AppScope.of(context);
    // Until the workspace is known, the selected worktree isn't either.
    if (s.inHome || s.workspace.loaded) {
      final key = s.inHome ? _homeKey : _keyOf(s);
      if (key != _spaceKey || !_space.visited) _enter(key);
    }
    // The chrome palette (the terminal area switches to the terminal one).
    final chrome = context.c;
    return ScreenFrame(
      toolbar: ScreenToolbar(
        breadcrumb: const _ContextBar(),
        primary: KButton.primary(label: 'New agent', icon: KIcons.agent, height: 36, onTap: () => showNewAgentDialog(context)),
      ),
      body: LayoutBuilder(builder: (context, box) {
        // Widgets are about the worktree: none in Home.
        final showPanel = s.sidePanelOpen && !s.inHome && box.maxWidth >= 640;
        // Settings › General › Side panel position.
        final right = s.sidePanelRight;
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (showPanel && !right) ...[const SizedBox(width: 300, child: SidePanel()), const SizedBox(width: 10)],
          Expanded(
            // Hybrid mode: this subtree uses the dark "smoked glass" palette.
            child: KumoTheme.scope(context: context, palette: context.tc, child: Builder(builder: (context) => _terminalArea(context, chrome))),
          ),
          if (showPanel && right) ...[const SizedBox(width: 10), const SizedBox(width: 300, child: SidePanel())],
        ]);
      }),
      status: [
        if (s.inHome)
          const StatusText('~ · Home', icon: KIcons.home, monospace: true)
        else
          Flexible(child: StatusText('${s.changes.branch} ↑${s.commitsAhead} ↓${s.changes.behind}', icon: KIcons.branch, monospace: true, flexible: true)),
        ..._agentStatus(context, s),
        const Spacer(),
        StatusText('${_tabs.length} ${_tabs.length == 1 ? 'tab' : 'tabs'} · ${_layout.panes.length} ${_layout.panes.length == 1 ? 'pane' : 'panes'}'),
        const StatusText('zsh · UTF-8'),
        if (_engine != null) _EngineStatus(engine: _engine!),
      ],
    );
  }

  /// Status bar: agents waiting on you and running (mocks: the canvas).
  List<Widget> _agentStatus(BuildContext context, AppState s) {
    final c = context.c;
    if (!s.agents.live) {
      return [
        StatusText('1 agent needs you', color: c.warn, dot: true),
        const StatusText('2 agents running'),
        const StatusText('gke-staging · pricing', icon: KIcons.cluster),
      ];
    }
    final waiting = s.agents.runs.where((r) => r.status == AgentStatus.needsYou).length;
    final running = s.agents.runs.where((r) => r.status == AgentStatus.running).length;
    return [
      if (waiting > 0) StatusText('$waiting ${waiting == 1 ? 'agent needs' : 'agents need'} you', color: c.warn, dot: true),
      if (running > 0) StatusText('$running ${running == 1 ? 'agent' : 'agents'} running'),
    ];
  }

  (IconData, Color) _look(BuildContext context, String id) {
    final c = context.c;
    if (_agentPanes.contains(id)) return (KIcons.agent, c.acc);
    return switch (id) {
      'agent' => (KIcons.agent, c.acc),
      'tests' => (KIcons.terminal, c.ok),
      'logs' => (KIcons.cluster, c.cyan),
      _ => (KIcons.terminal, c.text2),
    };
  }

  String _tabLabel(String id) => id == 'agent' ? 'claude · PRC-412' : (_surfaces[id]?.title ?? id);

  Widget _terminalArea(BuildContext context, KumoPalette chrome) {
    final c = context.c;
    final s = AppScope.of(context);
    final ctx = s.activeContext;
    final panelToggle = !s.sidePanelOpen && !s.inHome;
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
                  if (panelToggle && !s.sidePanelRight) ...[
                    KIconButton(icon: KIcons.sidePanel, label: 'Show side panel (⌥⌘B)', size: 30, iconSize: 16, onTap: s.toggleSidePanel),
                    const SizedBox(width: 4),
                  ],
                  for (final t in _tabs) ...[_tabChip(context, t), const SizedBox(width: 4)],
                  for (final t in s.contextTabs) ...[_contextTab(context, t), const SizedBox(width: 4)],
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
            if (panelToggle && s.sidePanelRight) ...[
              const SizedBox(width: 4),
              KIconButton(icon: KIcons.sidePanel, label: 'Show side panel (⌥⌘B)', size: 30, iconSize: 16, onTap: s.toggleSidePanel),
            ],
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ctx == ContextTab.files
                ? const _ContextFiles()
                : ctx == ContextTab.git
                ? _ContextGit(chrome: chrome)
                : s.activeFile != null
                ? FileView(key: ValueKey(s.activeFile), path: s.activeFile!)
                : _layout.isEmpty
                ? (s.workspace.loaded || s.inHome ? _empty(context) : const SizedBox.shrink())
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
    final app = AppScope.of(context);
    final on = identical(t, _tab) && app.activeFile == null && app.activeContext == null;
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

  /// A context tab (Files / Git of the worktree) in the tab strip.
  Widget _contextTab(BuildContext context, ContextTab t) {
    final c = context.c;
    final s = AppScope.of(context);
    final on = s.activeContext == t;
    final label = '${t.label} · ${_shortBranch(s.changes.branch)}';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: 30,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: on ? chipDecoration(c, radius: 10, fill: c.tabActive) : BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        KPressable(
          onTap: () => s.openContext(t),
          semanticLabel: '${t.tooltip} tab',
          selected: on,
          builder: (context, hover, focus) => Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(t == ContextTab.files ? KIcons.files : KIcons.git, size: 13, color: on ? c.acc : c.text3),
            const SizedBox(width: 7),
            Text(label, style: sans(12, weight: FontWeight.w500, color: on || hover ? c.text : c.text2)),
          ]),
        ),
        const SizedBox(width: 6),
        KIconButton(icon: KIcons.close, label: 'Close tab $label (⌘W)', size: 18, iconSize: 11, color: c.text3, onTap: () => s.closeContext(t)),
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
              if (s.buffers.isDirty(path)) ...[const SizedBox(width: 6), Dot(c.text2, size: 7)],
            ]),
          ),
          const SizedBox(width: 6),
          KIconButton(
            icon: KIcons.close,
            label: s.buffers.isDirty(path) ? 'Close $name, unsaved changes (⌘W)' : 'Close $name (⌘W)',
            size: 18,
            iconSize: 11,
            color: c.text3,
            onTap: () => s.askClose(path),
          ),
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
        Text(AppScope.of(context).inHome ? 'No terminals open in Home' : 'No terminals open in this worktree', style: sans(12.5, color: c.text3)),
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
    final isMockAgent = id == 'agent';
    final run = _runOf(id);
    final isAgent = isMockAgent || _agentPanes.contains(id);
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
        if (isMockAgent) {
          final paused = AppScope.of(context).agentPaused;
          status = Pill(label: paused ? 'Paused' : 'Running · 12:04', color: paused ? c.warn : c.acc, background: paused ? c.warnSoft : c.accSoft);
        } else if (run != null) {
          status = switch (run.status) {
            AgentStatus.running => Pill(label: 'Working', color: c.acc, background: c.accSoft),
            AgentStatus.needsYou => Pill(label: 'Needs you', color: c.warn, background: c.warnSoft),
            AgentStatus.done => Pill(label: 'Exited · ${run.exitCode}', color: c.text3, background: c.tile),
          };
        } else if (id == 'tests') {
          status = Text('148 passed', style: sans(11, weight: FontWeight.w600, color: c.ok));
        } else if (id == 'logs') {
          status = Text('1 warning', style: sans(11, weight: FontWeight.w600, color: c.warn));
        }
        final trailing = isMockAgent && _agentConfirm
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
          active: id == _focus && AppScope.of(context).activeFile == null && AppScope.of(context).activeContext == null,
          onFocus: () => _setFocus(id),
          trailing: trailing,
          footer: isAgent
              ? _SteerBar(
                  surface: surface,
                  agentName: run?.providerName ?? 'Claude',
                  paused: AppScope.of(context).agentPaused,
                  // Pausing is part of the design canvas only.
                  onPause: isMockAgent ? AppScope.read(context).toggleAgentPaused : null,
                )
              : null,
        );
      },
    );
  }
}

/// Short name of a branch for tab titles: the ticket key when it has one
/// (`feat/PRC-412-bulk-discounts` → `PRC-412`), else its last segment.
String _shortBranch(String branch) {
  final key = RegExp(r'[A-Z][A-Z0-9]+-\d+').firstMatch(branch)?.group(0);
  if (key != null) return key;
  return branch.isEmpty ? 'worktree' : branch.split('/').last;
}

/// Header of the Terminal view: where you are (repo / branch, or Home) and
/// the worktree's tabs — Terminal, Files, Git.
class _ContextBar extends StatelessWidget {
  const _ContextBar();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    if (s.inHome) {
      return Tooltip(
        message: 'A shell in your home folder, not tied to any repository',
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(KIcons.home, size: 15, color: c.acc),
          const SizedBox(width: 8),
          Text('~', style: mono(13, weight: FontWeight.w600, color: c.text)),
          const SizedBox(width: 8),
          Text('Home', style: sans(13, color: c.text3)),
        ]),
      );
    }
    final ctx = s.activeContext;
    final items = [
      (null, KIcons.terminal, 'Terminal of this worktree'),
      (ContextTab.files, KIcons.files, ContextTab.files.tooltip),
      (ContextTab.git, KIcons.git, ContextTab.git.tooltip),
    ];
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: Tooltip(
          message: 'Current context: ${s.activeWorktreeEntry?.path ?? s.changes.branch}',
          child: Breadcrumb(icon: KIcons.branch, parts: [s.activeRepo?.name ?? 'No repository', if (s.changes.branch.isNotEmpty) s.changes.branch]),
        ),
      ),
      const SizedBox(width: 10),
      Container(
        height: 28,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (tab, icon, label) in items)
            Builder(builder: (context) {
              final on = tab == null ? ctx == null && s.activeFile == null : ctx == tab;
              return KPressable(
                onTap: tab == null ? s.showTerminals : () => s.openContext(tab),
                semanticLabel: label,
                tooltip: label,
                selected: on,
                builder: (context, hover, focus) => AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 30,
                  height: 24,
                  decoration: on ? chipDecoration(c, radius: 12, fill: c.tabActive) : BoxDecoration(color: hover ? c.tile : null, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 15, color: on || hover ? c.text : c.text2),
                ),
              );
            }),
        ]),
      ),
    ]);
  }
}

/// The worktree's Files tab: its tree on the left, the picked file with its
/// changes on the right.
class _ContextFiles extends StatelessWidget {
  const _ContextFiles();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final file = s.contextFile;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(width: 280, child: WorktreeFilesTree(selected: file, onOpen: s.showContextFile)),
      Container(width: 1, color: c.divider),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (s.contextFiles.isNotEmpty) ...[
            const _ContextFileStrip(),
            const SizedBox(height: 8),
          ],
          Expanded(child: _contextFileBody(context, file)),
        ]),
      ),
    ]);
  }

  Widget _contextFileBody(BuildContext context, String? file) {
    final c = context.c;
    return file == null
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(KIcons.file, size: 26, color: c.text3),
                  const SizedBox(height: 10),
                  Text('No file open', style: sans(13.5, weight: FontWeight.w600, color: c.text2)),
                  const SizedBox(height: 4),
                  Text('Pick a file on the left. Changed files are marked M / A.', style: sans(12.5, color: c.text3)),
                ]),
              )
            : FileView(key: ValueKey('ctx:$file'), path: file, startEditing: true);
  }
}

/// The Files tab's open files. The strip scrolls sideways (a mouse wheel
/// too), fades where tabs are cut off, keeps the file showing in view and
/// ends in “N open”: every open file, Close others and Close all.
class _ContextFileStrip extends StatefulWidget {
  const _ContextFileStrip();

  @override
  State<_ContextFileStrip> createState() => _ContextFileStripState();
}

class _ContextFileStripState extends State<_ContextFileStrip> {
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  String? _shown;
  int _shownAt = -1;
  bool _fadeStart = false;
  bool _fadeEnd = false;
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateFades);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _updateFades() {
    if (!mounted || !_scroll.hasClients) return;
    final p = _scroll.position;
    final start = p.extentBefore > 0.5;
    final end = p.extentAfter > 0.5;
    if (start != _fadeStart || end != _fadeEnd) {
      setState(() {
        _fadeStart = start;
        _fadeEnd = end;
      });
    }
  }

  /// After layout: refresh the fades and bring a newly shown file's tab
  /// into view, from whichever side it is cut off.
  void _afterLayout(String? file, int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateFades();
      if (file == null || file == _shown) return;
      final forward = index >= _shownAt;
      _shown = file;
      _shownAt = index;
      final ctx = _keys[file]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        alignmentPolicy: forward ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  void _wheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !_scroll.hasClients) return;
    final d = e.scrollDelta;
    if (d.dx.abs() >= d.dy.abs()) return; // a trackpad already scrolls sideways
    final p = _scroll.position;
    _scroll.jumpTo((p.pixels + d.dy).clamp(p.minScrollExtent, p.maxScrollExtent).toDouble());
  }

  void _openMenu(BuildContext anchor) {
    setState(() => _menuOpen = true);
    showKMenu(
      context,
      position: belowOf(anchor),
      alignRight: true,
      onClosed: () {
        if (mounted) setState(() => _menuOpen = false);
      },
      builder: (context, close) => _OpenFilesMenu(close: close),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final files = s.contextFiles;
    _keys.removeWhere((p, _) => !files.contains(p));
    _afterLayout(s.contextFile, s.contextFile == null ? -1 : files.indexOf(s.contextFile!));
    const fade = Color(0x00000000);
    const solid = Color(0xFF000000);
    return SizedBox(
      height: 30,
      child: Row(children: [
        Expanded(
          child: Listener(
            onPointerSignal: _wheel,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => LinearGradient(
                colors: [_fadeStart ? fade : solid, solid, solid, _fadeEnd ? fade : solid],
                stops: [0.0, rect.width <= 0 ? 0.0 : (28 / rect.width).clamp(0.0, 0.5), rect.width <= 0 ? 1.0 : (1 - 36 / rect.width).clamp(0.5, 1.0), 1.0],
              ).createShader(rect),
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _updateFades();
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final p in files)
                      Padding(
                        key: _keys.putIfAbsent(p, () => GlobalKey()),
                        padding: const EdgeInsets.only(right: 4),
                        child: _ContextFileTab(path: p),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Builder(
          builder: (anchor) => KPressable(
            onTap: () => _openMenu(anchor),
            semanticLabel: 'All open files, ${files.length} open',
            tooltip: 'All open files',
            builder: (context, hover, focus) => Container(
              height: 28,
              padding: const EdgeInsets.only(left: 10, right: 7),
              decoration: BoxDecoration(color: hover || focus || _menuOpen ? c.tabActive : c.tile, borderRadius: BorderRadius.circular(9)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${files.length} open', style: sans(11.5, weight: FontWeight.w500, color: c.text2)),
                const SizedBox(width: 3),
                Icon(KIcons.chevronDown, size: 14, color: c.text2),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// “N open”: every open file (the one showing checked) with its folder and
/// change letter, each closable, then Close others and Close all.
class _OpenFilesMenu extends StatelessWidget {
  const _OpenFilesMenu({required this.close});
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final files = s.contextFiles;
    return KMenuPanel(width: 340, children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            for (final p in files) _OpenFileRow(path: p, close: close),
          ]),
        ),
      ),
      const KMenuDivider(),
      KMenuItem(icon: KIcons.close, label: 'Close others', onTap: files.length > 1 && s.contextFile != null ? () => _then(s.closeOtherContextFiles) : null),
      KMenuItem(icon: KIcons.close, label: 'Close all', onTap: () => _then(s.closeAllContextFiles)),
    ]);
  }

  void _then(VoidCallback f) {
    close();
    f();
  }
}

class _OpenFileRow extends StatelessWidget {
  const _OpenFileRow({required this.path, required this.close});
  final String path;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final f = s.changedFile(path);
    final cut = path.lastIndexOf('/');
    final name = path.substring(cut + 1);
    final dir = cut < 0 ? '' : path.substring(0, cut);
    final on = s.contextFile == path;
    final col = f == null ? c.text3 : (f.kind == 'A' ? c.ok : c.warn);
    return Row(children: [
      Expanded(
        child: KPressable(
          onTap: () {
            close();
            s.showContextFile(path);
          },
          semanticLabel: 'Show $path',
          selected: on,
          builder: (context, hover, focus) => Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(7)),
            child: Row(children: [
              SizedBox(width: 15, child: on ? Icon(KIcons.check, size: 14, color: c.acc) : null),
              const SizedBox(width: 6),
              // A long name keeps some room for its folder.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, weight: on ? FontWeight.w600 : FontWeight.w400, color: c.text)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(dir, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(10.5, color: c.text3))),
              if (f != null) ...[const SizedBox(width: 6), Text(f.kind, style: mono(10, weight: FontWeight.w700, color: col))],
            ]),
          ),
        ),
      ),
      const SizedBox(width: 2),
      KIconButton(icon: KIcons.close, label: 'Close $name', size: 22, iconSize: 11, color: c.text3, onTap: () => s.askClose(path, files: true)),
    ]);
  }
}

/// A file tab inside the Files tab: name, change letter, close.
class _ContextFileTab extends StatelessWidget {
  const _ContextFileTab({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final f = s.changedFile(path);
    final name = path.substring(path.lastIndexOf('/') + 1);
    final col = f == null ? c.text3 : (f.kind == 'A' ? c.ok : c.warn);
    final on = s.contextFile == path;
    return Tooltip(
      message: path,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 30,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: on ? chipDecoration(c, radius: 10, fill: c.tabActive) : BoxDecoration(borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          KPressable(
            onTap: () => s.showContextFile(path),
            semanticLabel: 'Open file $path',
            selected: on,
            builder: (context, hover, focus) => Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(KIcons.file, size: 13, color: col),
              const SizedBox(width: 7),
              Text(name, style: mono(11.5, color: on || hover ? c.text : c.text2)),
              if (f != null) ...[const SizedBox(width: 6), Text(f.kind, style: mono(10, weight: FontWeight.w700, color: col))],
              if (s.buffers.isDirty(path)) ...[const SizedBox(width: 6), Dot(c.text2, size: 7)],
            ]),
          ),
          const SizedBox(width: 6),
          KIconButton(
            icon: KIcons.close,
            label: s.buffers.isDirty(path) ? 'Close $name, unsaved changes (⌘W)' : 'Close $name (⌘W)',
            size: 18,
            iconSize: 11,
            color: c.text3,
            onTap: () => s.askClose(path, files: true),
          ),
        ]),
      ),
    );
  }
}

/// The worktree's Git tab: source control on the left; on the right the
/// branch's commits, its pull request and its pipelines. In hybrid mode it
/// keeps the chrome palette (it isn't a terminal).
class _ContextGit extends StatelessWidget {
  const _ContextGit({required this.chrome});
  final KumoPalette chrome;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final hybrid = s.mode == KumoThemeMode.hybrid;
    Widget body(BuildContext context) {
      final c = context.c;
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(width: 340, child: SourceControlPanel()),
        Container(width: 1, color: c.divider),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(10, 4, 4, 10), children: [
            const _BranchCommits(),
            const SizedBox(height: 10),
            const PullRequestCard(),
            const SizedBox(height: 10),
            const PipelinesCard(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: KButton(
                label: 'Whole repository: everyone’s commits, PRs and pipelines in Git',
                icon: KIcons.arrowRight,
                kind: KButtonKind.ghost,
                height: 30,
                fontSize: 12,
                onTap: () => s.view = KumoView.git,
              ),
            ),
          ]),
        ),
      ]);
    }

    if (!hybrid) return Builder(builder: body);
    return KumoTheme.scope(
      context: context,
      palette: chrome,
      child: Container(
        decoration: BoxDecoration(color: chrome.paper, borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Builder(builder: body),
      ),
    );
  }
}

/// Latest commits of the branch; the ones not pushed yet are marked.
class _BranchCommits extends StatefulWidget {
  const _BranchCommits();

  @override
  State<_BranchCommits> createState() => _BranchCommitsState();
}

class _BranchCommitsState extends State<_BranchCommits> {
  Object? _source;
  int _version = -1;
  List<CommitInfo>? _commits;

  /// Design mocks (no history): the branch's two commits.
  static final _mock = [
    CommitInfo(sha: '9e41b07', shortSha: '9e41b07', subject: 'feat: BulkDiscount aggregate', author: 'Claude', time: DateTime.now().subtract(const Duration(minutes: 42))),
    CommitInfo(sha: 'a1c22d4', shortSha: 'a1c22d4', subject: 'feat: repository batch upsert with CopyFrom', author: 'Claude', time: DateTime.now().subtract(const Duration(hours: 1))),
  ];

  void _load() {
    final changes = AppScope.read(context).changes;
    if (identical(changes, _source) && changes.version == _version) return;
    _source = changes;
    _version = changes.version;
    changes.log(limit: 8).then((list) {
      if (!mounted || !identical(changes, AppScope.read(context).changes)) return;
      setState(() => _commits = list ?? _mock);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    _load();
    final commits = _commits ?? const <CommitInfo>[];
    final ahead = s.changes.pushed ? s.commitsAhead : commits.length;
    final note = !s.changes.pushed ? 'not published yet' : (ahead == 0 ? 'all pushed' : '$ahead not pushed');
    return Section(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(KIcons.branch, size: 15, color: c.acc),
          const SizedBox(width: 8),
          Expanded(child: Text('Commits on this branch', style: sans(12.5, weight: FontWeight.w600, color: c.text))),
          Text(note, style: sans(11.5, color: c.text3)),
        ]),
        const SizedBox(height: 8),
        if (_commits == null) Text('Reading history…', style: sans(12, color: c.text3)),
        if (_commits != null && commits.isEmpty) Text('No commits yet.', style: sans(12, color: c.text3)),
        for (var i = 0; i < commits.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text(commits[i].shortSha, style: mono(11.5, color: c.text3)),
              const SizedBox(width: 9),
              Expanded(child: Text(commits[i].subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, color: c.text))),
              if (i < ahead) ...[const SizedBox(width: 8), TagChip('not pushed', color: c.warn, background: c.warnSoft)],
              const SizedBox(width: 8),
              Text('${commits[i].author} · ${_ago(commits[i].time)}', style: sans(11.5, color: c.text3)),
            ]),
          ),
      ]),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

/// The terminals of one worktree: its tabs and the one showing.
class _Space {
  final List<_TermTab> tabs = [];
  int active = 0;

  /// Whether it has shown yet (the first time, it gets a shell).
  bool visited = false;
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
  const _SteerBar({required this.surface, required this.agentName, required this.paused, this.onPause});
  final TerminalSurface surface;
  final String agentName;
  final bool paused;
  final VoidCallback? onPause;

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
              decoration: InputDecoration.collapsed(hintText: 'Tell ${widget.agentName} to change course, or / for commands', hintStyle: sans(12.5, color: c.text3)),
            ),
          ),
        ),
        if (widget.onPause != null)
          KIconButton(icon: widget.paused ? Icons.play_arrow_rounded : KIcons.pause, label: widget.paused ? 'Resume agent' : 'Pause agent', size: 30, iconSize: 15, onTap: widget.onPause!),
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
