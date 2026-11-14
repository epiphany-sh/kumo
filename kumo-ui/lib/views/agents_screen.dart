import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/agents_source.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../engine/engine_scope.dart';
import '../overlays/new_agent_dialog.dart';
import '../shell/screen_chrome.dart';
import '../shell/sidebar.dart' show toneColor;
import '../terminal/terminal_surface.dart';
import '../terminal/terminal_view.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/controls.dart';
import '../widgets/kicons.dart';
import '../widgets/toolbar_segments.dart';
import 'agent_terminals.dart';
import 'agents_library.dart';

enum _Filter { all, running, needsYou, done }

/// What the Agents view shows: the sessions running, or your own agents.
enum AgentsMode { sessions, library, skills }

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key, this.mode});

  /// Where it opens (tests); else where it was left.
  final AgentsMode? mode;

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  List<AgentSession> _agents = Mock.agents;
  _Filter _filter = _Filter.all;
  String? _decision;

  /// The session whose terminal is open here (null: the cards).
  String? _open;
  final Set<String> _dismissed = {};
  late AgentsMode _mode = widget.mode ?? AgentsMode.sessions;
  final _libraryKey = GlobalKey<AgentLibraryState>();
  final _library = AgentLibraryMemory();
  AgentTerminals? _terminals;
  AppState? _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = EngineScope.maybeOf(context);
    if (_terminals == null || !identical(_terminals!.engine, engine)) {
      // The old ones go once nothing shows them.
      final old = _terminals;
      if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      _terminals = AgentTerminals(engine);
    }
    final app = AppScope.read(context);
    if (!identical(app, _app)) {
      _app?.agentsRequest.removeListener(_onRequest);
      final first = _app == null;
      _app = app..agentsRequest.addListener(_onRequest);
      if (first && widget.mode == null) {
        _mode = app.setting<String>('agents.mode', 'sessions') == 'library' ? AgentsMode.library : AgentsMode.sessions;
      }
      _onRequest();
    }
  }

  @override
  void dispose() {
    _app?.agentsRequest.removeListener(_onRequest);
    _terminals?.dispose();
    _library.dispose();
    super.dispose();
  }

  /// Asked from elsewhere: a session's terminal, or (for the library to
  /// take) one of your agents.
  void _onRequest() {
    final app = _app;
    final r = app?.agentsRequest.value;
    if (app == null || r == null || !mounted) return;
    if (r.session != null) {
      setState(() {
        _mode = AgentsMode.sessions;
        _filter = _Filter.all;
        _open = r.session;
      });
      app.agentsRequest.value = null;
    } else if (r.agent != null && _mode != AgentsMode.library) {
      setState(() => _mode = AgentsMode.library);
    }
  }

  void _setMode(AgentsMode m) {
    if (m == AgentsMode.skills) return;
    setState(() => _mode = m);
    AppScope.read(context).setSetting('agents.mode', m.name);
  }

  (Color, Color, String) _statusStyle(KumoPalette c, AgentStatus s) => switch (s) {
        AgentStatus.running => (c.acc, c.accSoft, 'Running'),
        AgentStatus.needsYou => (c.warn, c.warnSoft, 'Needs you'),
        AgentStatus.done => (c.ok, c.okSoft, 'Done'),
      };

  void _decide(String id, bool approve) {
    // Optimistic: same frame. The daemon will confirm (or revert) via an event.
    setState(() {
      _decision = approve ? 'approved' : 'denied';
      if (_terminals?.ofMock(id) case final t?) t.sendText(approve ? 'y' : 'n');
      _agents = [
        for (final a in _agents)
          if (a.id == id)
            a.copyWith(
              status: AgentStatus.running,
              last: approve ? 'Approved · running ${a.approvalCommand}' : 'Denied · looking for another approach',
              clearApproval: true,
            )
          else
            a,
      ];
    });
  }

  /// A daemon session as the card shows it. Tickets, plan steps and
  /// approvals come with task sources (M4).
  AgentSession _view(AgentRun r, AppState s) {
    var where = r.worktreePath;
    for (final repo in s.workspace.repos) {
      for (final w in repo.worktrees) {
        if (s.workspace.absolutePathOf(w) == r.worktreePath) where = '${repo.name} · ${w.branch}';
      }
    }
    final minutes = DateTime.now().difference(r.startedAt).inMinutes;
    return AgentSession(
      id: r.id,
      agent: r.agent.isEmpty ? r.providerName : r.agent,
      k: r.short,
      mode: r.status == AgentStatus.done ? 'exited with code ${r.exitCode}' : 'in its own terminal',
      status: r.status,
      title: r.title,
      src: '',
      key: '',
      srcName: '',
      where: where,
      whereIsDoc: false,
      step: 0,
      stepLabel: '',
      last: r.lastLine.isNotEmpty ? r.lastLine : (r.prompt.isNotEmpty ? r.prompt : 'Starting…'),
      meta: '',
      time: minutes < 1 ? 'now' : (minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h ${minutes % 60}m'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final live = s.agents.live;
    final runs = {for (final r in s.agents.runs) r.id: r};
    final agents = [
      for (final a in live ? [for (final r in runs.values) _view(r, s)] : _agents)
        if (!_dismissed.contains(a.id)) a,
    ];
    int count(AgentStatus? st) => st == null ? agents.length : agents.where((a) => a.status == st).length;
    final visible = agents
        .where((a) => switch (_filter) {
              _Filter.all => true,
              _Filter.running => a.status == AgentStatus.running,
              _Filter.needsYou => a.status == AgentStatus.needsYou,
              _Filter.done => a.status == AgentStatus.done,
            })
        .toList();
    final waiting = count(AgentStatus.needsYou);

    final open = visible.where((a) => a.id == _open).firstOrNull;
    final library = _mode == AgentsMode.library;
    final mine = s.agentDefs;
    final toolbar = ScreenToolbar(
      breadcrumb: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Breadcrumb(icon: KIcons.agent, parts: live ? const ['Agents'] : const ['Agents', 'platform workspace'])),
        const SizedBox(width: 12),
        ListenableBuilder(
          listenable: mine,
          builder: (context, _) => ToolbarSegments<AgentsMode>(
            label: 'What Agents shows',
            value: _mode,
            onChanged: _setMode,
            items: [
              (AgentsMode.sessions, 'Sessions', agents.length, null),
              (AgentsMode.library, 'Your agents', mine.supported ? mine.agents.length : null, null),
              (AgentsMode.skills, 'Skills · soon', null, 'A playground for skills comes next'),
            ],
          ),
        ),
      ]),
      primary: library
          ? KButton.primary(label: 'Create agent', icon: KIcons.add, height: 36, onTap: mine.supported ? () => _libraryKey.currentState?.create() : null)
          : KButton.primary(label: 'New agent', icon: KIcons.agent, height: 36, onTap: () => showNewAgentDialog(context)),
    );
    if (library) {
      return ScreenFrame(
        toolbar: toolbar,
        body: AgentLibrary(key: _libraryKey, terminals: _terminals!, memory: _library),
        status: [
          ListenableBuilder(
            listenable: mine,
            builder: (context, _) => StatusText(
              mine.supported ? '${mine.agents.length} agents · Claude Code subagents' : 'Your agents need a newer engine',
              color: mine.supported ? null : c.warn,
            ),
          ),
          const Spacer(),
          const StatusText('They run on Claude Code, Codex or Copilot'),
        ],
      );
    }

    return ScreenFrame(
      toolbar: toolbar,
      body: LayoutBuilder(builder: (context, box) {
        final showAside = box.maxWidth >= (open == null ? 900 : 1180) && !live;
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Section(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 10, alignment: WrapAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('Agents', style: sans(22, weight: FontWeight.w600, color: c.text, letterSpacing: -0.4)),
                    Text(
                      live
                          ? '${agents.length} ${agents.length == 1 ? 'session' : 'sessions'} · each one in its own terminal'
                          : '${agents.length} sessions across 3 repos · each one in its own worktree',
                      style: sans(12, color: c.text3),
                    ),
                  ]),
                  KSegmented<_Filter>(
                    label: 'Filter agents',
                    value: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                    items: [
                      (_Filter.all, 'All', '${count(null)}'),
                      (_Filter.running, 'Running', '${count(AgentStatus.running)}'),
                      (_Filter.needsYou, 'Needs you', '$waiting'),
                      (_Filter.done, 'Done', '${count(AgentStatus.done)}'),
                    ],
                  ),
                ]),
                const SizedBox(height: 16),
                if (live && agents.isEmpty)
                  Expanded(child: _Empty(connected: s.agents.connected.isNotEmpty))
                else if (open != null)
                  Expanded(
                    child: _SessionView(
                      session: open,
                      sessions: visible,
                      run: runs[open.id],
                      surface: runs[open.id] == null ? _terminals!.ofMock(open.id) : _terminals!.ofRun(runs[open.id]!),
                      style: (AgentSession a) => _statusStyle(c, a.status),
                      onPick: (id) => setState(() => _open = id),
                      onBack: () => setState(() => _open = null),
                      onDecide: _decide,
                      onDismiss: (id) => setState(() {
                        _dismissed.add(id);
                        _open = null;
                        _terminals?.drop('mock:$id');
                      }),
                      onDetach: (terminalId) => _terminals?.drop(terminalId),
                      onStop: (id) => setState(() {
                        _agents = [
                          for (final a in _agents)
                            if (a.id == id) a.copyWith(status: AgentStatus.done, last: 'Stopped by you', clearApproval: true) else a
                        ];
                        _terminals?.ofMock(id).sendText('Stopped by you');
                      }),
                    ),
                  )
                else
                  Expanded(
                    child: LayoutBuilder(builder: (context, inner) {
                      const minW = 270.0, gap = 12.0;
                      final cols = math.max(1, ((inner.maxWidth + gap) / (minW + gap)).floor());
                      final w = (inner.maxWidth - gap * (cols - 1)) / cols;
                      return SingleChildScrollView(
                        child: Wrap(spacing: gap, runSpacing: gap, children: [
                          for (final a in visible)
                            SizedBox(
                              width: w,
                              child: _AgentCard(
                                agent: a,
                                style: _statusStyle(c, a.status),
                                onDecide: _decide,
                                run: runs[a.id],
                                onOpen: () => setState(() => _open = a.id),
                                onDismiss: () => setState(() => _dismissed.add(a.id)),
                              ),
                            ),
                        ]),
                      );
                    }),
                  ),
              ]),
            ),
          ),
          if (showAside) ...[
            const SizedBox(width: 10),
            SizedBox(width: 330, child: _Aside(decision: _decision)),
          ],
        ]);
      }),
      status: [
        StatusText(
          waiting > 0 ? '$waiting ${waiting == 1 ? 'agent needs' : 'agents need'} you' : 'No agents waiting on you',
          color: waiting > 0 ? c.warn : c.ok,
          dot: true,
        ),
        StatusText('${count(AgentStatus.running)} agents running'),
        if (live)
          StatusText('${s.agents.connected.length} connected')
        else ...[
          const StatusText('3 of 4 agent slots in use'),
          const Spacer(),
          const StatusText('gke-staging · platform', icon: KIcons.cluster),
        ],
      ],
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent, required this.style, required this.onDecide, required this.onOpen, required this.onDismiss, this.run});

  /// Shows its terminal here, in Agents.
  final VoidCallback onOpen;

  /// Takes a finished design session off the list.
  final VoidCallback onDismiss;

  final AgentSession agent;

  /// The daemon session behind a real card (null for the design mocks).
  final AgentRun? run;
  final (Color, Color, String) style;
  final void Function(String id, bool approve) onDecide;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (fg, bg, label) = style;
    final a = agent;
    final asking = a.approvalCommand != null && a.status == AgentStatus.needsYou;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.pane,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: asking ? c.warn : c.paneBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SourceTile(a.k, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.agent, style: sans(12.5, weight: FontWeight.w600, color: c.text)),
              Text(a.mode, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3)),
            ]),
          ),
          Pill(label: label, color: fg, background: bg),
        ]),
        const SizedBox(height: 12),
        Text(a.title, style: sans(15, weight: FontWeight.w600, color: c.text, letterSpacing: -0.15, height: 1.3)),
        if (a.src.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            TagChip(a.src),
            const SizedBox(width: 6),
            Text(a.key, style: mono(11.5, color: c.text2)),
            const SizedBox(width: 6),
            Text('· ${a.srcName}', style: sans(11.5, color: c.text3)),
          ]),
        ],
        const SizedBox(height: 6),
        Row(children: [
          Icon(a.whereIsDoc ? KIcons.docs : KIcons.branch, size: 13, color: c.text3),
          const SizedBox(width: 6),
          Expanded(child: Text(a.where, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text2))),
        ]),
        if (a.step > 0) ...[
          const SizedBox(height: 12),
          Row(children: [
            for (var n = 1; n <= 4; n++) ...[
              if (n > 1) const SizedBox(width: 4),
              Expanded(child: Container(height: 4, decoration: BoxDecoration(color: n <= a.step ? fg : c.tile, borderRadius: BorderRadius.circular(2)))),
            ],
          ]),
          const SizedBox(height: 6),
          Text(a.stepLabel, style: sans(11.5, color: c.text3)),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10)),
          child: Text.rich(
            TextSpan(children: [TextSpan(text: '› ', style: TextStyle(color: fg)), TextSpan(text: a.last)]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mono(11.5, color: c.text2),
          ),
        ),
        if (asking) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.warnSoft, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(KIcons.shield, size: 14, color: c.warn),
                const SizedBox(width: 8),
                Flexible(child: Text('Approval needed · shell command', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, weight: FontWeight.w600, color: c.warn))),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(8)),
                child: Text(a.approvalCommand!, style: mono(11.5, color: c.text)),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: KButton.primary(label: 'Approve once', height: 32, fontSize: 12.5, expand: true, onTap: () => onDecide(a.id, true))),
                const SizedBox(width: 8),
                KButton(label: 'Deny', height: 32, fontSize: 12.5, onTap: () => onDecide(a.id, false)),
              ]),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(a.meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, color: c.text3))),
          Icon(KIcons.clock, size: 12, color: c.text3),
          const SizedBox(width: 4),
          Text(a.time, style: sans(11.5, color: c.text3)),
          const SizedBox(width: 10),
          if (run != null) ...[
            run!.status == AgentStatus.done
                ? KButton(label: 'Dismiss', height: 26, fontSize: 11.5, kind: KButtonKind.ghost, onTap: () => AppScope.read(context).agents.dismiss(run!.id))
                : KButton(label: 'Stop', height: 26, fontSize: 11.5, kind: KButtonKind.ghost, onTap: () => AppScope.read(context).agents.stop(run!.id)),
            const SizedBox(width: 4),
          ] else if (a.status == AgentStatus.done) ...[
            KButton(label: 'Dismiss', height: 26, fontSize: 11.5, kind: KButtonKind.ghost, onTap: onDismiss),
            const SizedBox(width: 4),
          ],
          Tooltip(
            message: 'See its whole output here, and type into it',
            child: KButton(label: 'Terminal', icon: KIcons.terminal, height: 26, fontSize: 11.5, kind: KButtonKind.ghost, onTap: onOpen),
          ),
        ]),
      ]),
    );
  }
}

class _Aside extends StatelessWidget {
  const _Aside({required this.decision});
  final String? decision;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final events = [
      if (decision == null)
        const ActivityEvent('Codex asked to run make migrate-up', 'now', 'Codex', WorktreeTone.warn)
      else
        ActivityEvent('You $decision make migrate-up', 'now', 'Codex', decision == 'approved' ? WorktreeTone.ok : WorktreeTone.warn),
      ...Mock.activity,
    ];
    const policy = [
      ('Edits inside the worktree', 'Auto'),
      ('Tests, linters, go build', 'Auto'),
      ('git push, open PR', 'Ask'),
      ('Migrations, kubectl apply', 'Ask'),
      ('Production contexts', 'Block'),
    ];
    (Color, Color) rule(String r) => switch (r) {
          'Auto' => (c.ok, c.okSoft),
          'Ask' => (c.warn, c.warnSoft),
          _ => (c.err, c.errSoft),
        };
    return ListView(padding: EdgeInsets.zero, children: [
      Section(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PanelHeading('Activity'),
          const SizedBox(height: 12),
          for (var i = 0; i < events.length; i++)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Column(children: [
                  const SizedBox(height: 5),
                  Dot(toneColor(context, events[i].tone), size: 8),
                  if (i < events.length - 1) Expanded(child: Container(width: 1, margin: const EdgeInsets.only(top: 4), color: c.divider)),
                ]),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(events[i].text, style: sans(12.5, color: c.text)),
                      Text('${events[i].time} · ${events[i].who}', style: sans(11, color: c.text3)),
                    ]),
                  ),
                ),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Section(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PanelHeading('Approval policy', trailing: Text('workspace default', style: sans(11, color: c.text3))),
          const SizedBox(height: 8),
          for (final (label, r) in policy)
            SizedBox(
              height: 30,
              child: Row(children: [
                Expanded(child: Text(label, style: sans(12.5, color: c.text2))),
                Pill(label: r, color: rule(r).$1, background: rule(r).$2, dot: false),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

/// No agents yet: start one, or connect one first.
class _Empty extends StatelessWidget {
  const _Empty({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(KIcons.agent, size: 26, color: c.text3),
        const SizedBox(height: 12),
        Text(connected ? 'No agents running' : 'No agent connected yet', style: sans(13.5, weight: FontWeight.w600, color: c.text2)),
        const SizedBox(height: 4),
        Text(
          connected ? 'Start one in a worktree: it gets its own terminal.' : 'Connect Claude Code, Codex, Gemini, Copilot, Grok… in Settings › AI agents. Optional.',
          style: sans(12.5, color: c.text3),
        ),
        const SizedBox(height: 14),
        KButton.primary(label: connected ? 'New agent' : 'Connect an agent', icon: KIcons.agent, height: 32, onTap: () => showNewAgentDialog(context)),
      ]),
    );
  }
}

/// A session's terminal, right in Agents: every session as a tab, what it
/// works on, and its whole output, which takes typing. The Terminal view
/// shows the same session; opening it there is optional.
class _SessionView extends StatelessWidget {
  const _SessionView({
    required this.session,
    required this.sessions,
    required this.surface,
    required this.style,
    required this.onPick,
    required this.onBack,
    required this.onDecide,
    required this.onDismiss,
    required this.onStop,
    required this.onDetach,
    this.run,
  });

  final AgentSession session;
  final ValueChanged<String> onStop;

  /// Lets go of a terminal that's done with.
  final ValueChanged<String> onDetach;
  final List<AgentSession> sessions;

  /// The daemon session behind it (null: the design).
  final AgentRun? run;
  final TerminalSurface surface;
  final (Color, Color, String) Function(AgentSession) style;
  final ValueChanged<String> onPick;
  final VoidCallback onBack;
  final void Function(String id, bool approve) onDecide;
  final ValueChanged<String> onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final a = session;
    final (fg, bg, label) = style(a);
    final done = a.status == AgentStatus.done;
    final r = run;
    final asking = r != null ? r.asked : a.status == AgentStatus.needsYou;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onBack},
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Every session, to switch without going back.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            Tooltip(message: 'Back to the cards (Esc)', child: KButton(label: 'All', icon: KIcons.back, height: 30, fontSize: 12, kind: KButtonKind.ghost, onTap: onBack)),
            for (final x in sessions) ...[
              const SizedBox(width: 4),
              _SessionTab(session: x, selected: x.id == a.id, dot: style(x).$1, onTap: () => onPick(x.id)),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(15, weight: FontWeight.w600, color: c.text, letterSpacing: -0.15))),
                const SizedBox(width: 8),
                Pill(label: label, color: fg, background: bg),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                if (a.src.isNotEmpty) ...[TagChip(a.src), const SizedBox(width: 6), Text(a.key, style: mono(11.5, color: c.text2)), const SizedBox(width: 6)],
                Text('${a.agent} · ', style: sans(11.5, color: c.text3)),
                Icon(a.whereIsDoc ? KIcons.docs : KIcons.branch, size: 12, color: c.text3),
                const SizedBox(width: 4),
                Flexible(child: Text(a.where, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text2))),
              ]),
            ]),
          ),
          if (a.step > 0)
            SizedBox(
              width: 180,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  for (var n = 1; n <= 4; n++) ...[
                    if (n > 1) const SizedBox(width: 4),
                    Expanded(child: Container(height: 4, decoration: BoxDecoration(color: n <= a.step ? fg : c.tile, borderRadius: BorderRadius.circular(2)))),
                  ],
                ]),
                const SizedBox(height: 4),
                Text('${a.stepLabel} · ${a.time}', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3)),
              ]),
            ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: TerminalPane(
            key: ValueKey('agent-term-${a.id}'),
            surface: surface,
            icon: KIcons.terminal,
            iconColor: fg,
            active: true,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Tooltip(
                message: 'Optional: the same session, next to the worktree’s other terminals',
                child: KButton(
                  label: 'Terminal view',
                  icon: KIcons.external,
                  height: 26,
                  fontSize: 11.5,
                  kind: KButtonKind.ghost,
                  onTap: () => r == null ? s.view = KumoView.terminal : s.openTerminal(r.terminalId, title: r.title, agent: true, directory: r.worktreePath),
                ),
              ),
              const SizedBox(width: 4),
              done
                  ? KButton(
                      label: 'Dismiss',
                      height: 26,
                      fontSize: 11.5,
                      onTap: () {
                        if (r == null) {
                          onDismiss(a.id);
                        } else {
                          onDetach(r.terminalId);
                          s.agents.dismiss(r.id);
                        }
                      },
                    )
                  : KButton(label: 'Stop', height: 26, fontSize: 11.5, onTap: () => r == null ? onStop(a.id) : s.agents.stop(r.id)),
            ]),
            footer: done
                ? null
                : SizedBox(
                    height: kAgentNoteSpace,
                    child: asking
                        ? Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                              decoration: BoxDecoration(color: c.warnSoft, borderRadius: BorderRadius.circular(10)),
                              child: Row(children: [
                                Icon(KIcons.shield, size: 14, color: c.warn),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    a.approvalCommand == null ? 'It’s asking you something: answer it in its terminal.' : '${a.agent} wants to run ${a.approvalCommand}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: sans(12, weight: FontWeight.w600, color: c.warn),
                                  ),
                                ),
                                if (a.approvalCommand != null) ...[
                                  KButton.primary(label: 'Approve once', height: 28, fontSize: 12, onTap: () => onDecide(a.id, true)),
                                  const SizedBox(width: 6),
                                  KButton(label: 'Deny', height: 28, fontSize: 12, onTap: () => onDecide(a.id, false)),
                                ],
                              ]),
                            ),
                          )
                        : null,
                  ),
          ),
        ),
      ]),
    );
  }
}

class _SessionTab extends StatelessWidget {
  const _SessionTab({required this.session, required this.selected, required this.dot, required this.onTap});
  final AgentSession session;
  final bool selected;
  final Color dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = session;
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '${a.agent}, ${a.title}',
      tooltip: '${a.title} · ${a.where}',
      builder: (context, hover, focus) => Container(
        height: 30,
        padding: const EdgeInsets.only(left: 10, right: 12),
        decoration: BoxDecoration(
          color: selected ? c.accSoft : (hover ? c.tabActive : c.chip),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: selected || focus ? c.acc : c.chipBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Dot(dot),
          const SizedBox(width: 7),
          Text(a.agent, style: sans(12, weight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? c.text : c.text2)),
          if (a.key.isNotEmpty) ...[const SizedBox(width: 6), Text(a.key, style: mono(11, color: c.text3))],
        ]),
      ),
    );
  }
}
