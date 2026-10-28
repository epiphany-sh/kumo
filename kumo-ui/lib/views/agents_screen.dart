import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/agents_source.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../overlays/new_agent_dialog.dart';
import '../shell/screen_chrome.dart';
import '../shell/sidebar.dart' show toneColor;
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/controls.dart';
import '../widgets/kicons.dart';

enum _Filter { all, running, needsYou, done }

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  List<AgentSession> _agents = Mock.agents;
  _Filter _filter = _Filter.all;
  String? _decision;

  (Color, Color, String) _statusStyle(KumoPalette c, AgentStatus s) => switch (s) {
        AgentStatus.running => (c.acc, c.accSoft, 'Running'),
        AgentStatus.needsYou => (c.warn, c.warnSoft, 'Needs you'),
        AgentStatus.done => (c.ok, c.okSoft, 'Done'),
      };

  void _decide(String id, bool approve) {
    // Optimistic: same frame. The daemon will confirm (or revert) via an event.
    setState(() {
      _decision = approve ? 'approved' : 'denied';
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
      agent: r.providerName,
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
    final agents = live ? [for (final r in runs.values) _view(r, s)] : _agents;
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

    return ScreenFrame(
      toolbar: ScreenToolbar(
        breadcrumb: Breadcrumb(icon: KIcons.agent, parts: live ? const ['Agents'] : const ['Agents', 'pricing workspace']),
        primary: KButton.primary(label: 'New agent', icon: KIcons.agent, height: 36, onTap: () => showNewAgentDialog(context)),
      ),
      body: LayoutBuilder(builder: (context, box) {
        final showAside = box.maxWidth >= 900 && !live;
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
          const StatusText('gke-staging · pricing', icon: KIcons.cluster),
        ],
      ],
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent, required this.style, required this.onDecide, this.run});

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
                Text('Approval needed · shell command', style: sans(12, weight: FontWeight.w600, color: c.warn)),
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
          Text(a.meta, style: mono(11.5, color: c.text3)),
          const Spacer(),
          Icon(KIcons.clock, size: 12, color: c.text3),
          const SizedBox(width: 4),
          Text(a.time, style: sans(11.5, color: c.text3)),
          const SizedBox(width: 10),
          if (run != null) ...[
            run!.status == AgentStatus.done
                ? KButton(label: 'Dismiss', height: 26, fontSize: 11.5, kind: KButtonKind.ghost, onTap: () => AppScope.read(context).agents.dismiss(run!.id))
                : KButton(label: 'Stop', height: 26, fontSize: 11.5, kind: KButtonKind.ghost, onTap: () => AppScope.read(context).agents.stop(run!.id)),
            const SizedBox(width: 4),
          ],
          KButton(
            label: 'Terminal',
            icon: KIcons.terminal,
            height: 26,
            fontSize: 11.5,
            kind: KButtonKind.ghost,
            onTap: () {
              final s = AppScope.read(context);
              final r = run;
              r == null ? s.view = KumoView.terminal : s.openTerminal(r.terminalId, title: r.title, agent: true, directory: r.worktreePath);
            },
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
