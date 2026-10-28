import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../shell/screen_chrome.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/kicons.dart';

/// One board for Jira, Trello, ClickUp and Todoist. Selected ticket on the
/// right with the "start in a worktree" flow.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<TaskItem> _tasks = Mock.tasks;
  String _src = 'all';
  bool _started = false;
  bool _sendTicket = true;
  bool _attachDocs = true;
  final _ac = <bool>[false, false, false];
  String _repo = 'price-admin';
  String _base = 'main';
  String _agent = 'claude';
  final _branch = TextEditingController(text: 'feat/PRC-421-price-history');

  @override
  void dispose() {
    _branch.dispose();
    super.dispose();
  }

  void _start() {
    // Optimistic move to In progress; the core confirms after creating the worktree.
    setState(() {
      _started = true;
      _tasks = [
        for (final t in _tasks)
          if (t.key == 'PRC-421') t.copyWith(col: TaskColumn.doing, agent: 'Claude · planning', branch: _branch.text) else t,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final counts = <String, int>{'all': _tasks.length};
    for (final t in _tasks) {
      counts[t.src] = (counts[t.src] ?? 0) + 1;
    }
    final visible = _tasks.where((t) => _src == 'all' || t.src == _src).toList();
    const columns = [
      (TaskColumn.todo, 'To do'),
      (TaskColumn.doing, 'In progress'),
      (TaskColumn.review, 'In review'),
      (TaskColumn.done, 'Done'),
    ];
    Color colColor(TaskColumn col) => switch (col) {
          TaskColumn.todo => c.text3,
          TaskColumn.doing => c.acc,
          TaskColumn.review => c.warn,
          TaskColumn.done => c.ok,
        };

    return ScreenFrame(
      toolbar: ScreenToolbar(
        breadcrumb: const Breadcrumb(icon: KIcons.tasks, parts: ['Tasks', 'Sprint 44 + personal inbox']),
        primary: KButton.primary(label: 'New task', icon: KIcons.add, height: 36, onTap: () {}),
      ),
      body: LayoutBuilder(builder: (context, box) {
        final showDetail = box.maxWidth >= 900;
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Section(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('Tasks', style: sans(22, weight: FontWeight.w600, color: c.text, letterSpacing: -0.4)),
                    Text('One board for Jira, Trello, ClickUp and Todoist · synced 1 min ago', style: sans(12, color: c.text3)),
                  ]),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final (k, label) in const [('all', 'All'), ('JI', 'Jira'), ('TR', 'Trello'), ('CU', 'ClickUp'), ('TD', 'Todoist')])
                      _SourceChip(
                        k: k == 'all' ? '∗' : k,
                        label: label,
                        count: counts[k] ?? 0,
                        selected: _src == k,
                        onTap: () => setState(() => _src = k),
                      ),
                  ]),
                ]),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (var i = 0; i < columns.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                          child: _Column(
                            label: columns[i].$2,
                            color: colColor(columns[i].$1),
                            tasks: [for (final t in visible) if (t.col == columns[i].$1) t],
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          if (showDetail) ...[const SizedBox(width: 10), SizedBox(width: 360, child: _detail(context))],
        ]);
      }),
      status: [
        StatusText('${_tasks.length} tasks · ${_tasks.where((t) => t.agent != null).length} with agents'),
        const StatusText('Jira synced 1 min ago'),
        const StatusText('Todoist synced 4 min ago'),
        const Spacer(),
        const StatusText('Moving a card updates the source app'),
      ],
    );
  }

  Widget _detail(BuildContext context) {
    final c = context.c;
    return ListView(padding: EdgeInsets.zero, children: [
      Section(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const TagChip('JI'),
            const SizedBox(width: 8),
            Text('PRC-421', style: mono(12, weight: FontWeight.w500, color: c.text)),
            const SizedBox(width: 8),
            Text('Jira · Story', style: sans(12, color: c.text3)),
            const Spacer(),
            KIconButton(icon: KIcons.external, label: 'Open PRC-421 in Jira', onTap: () {}),
          ]),
          const SizedBox(height: 10),
          Text('Expose price history in admin API', style: sans(19, weight: FontWeight.w600, color: c.text, letterSpacing: -0.3, height: 1.25)),
          const SizedBox(height: 14),
          Wrap(runSpacing: 10, children: [
            for (final (k, v, hi) in [
              ('Status', _started ? 'In progress' : 'To do', _started),
              ('Priority', 'High', false),
              ('Sprint', 'Sprint 44', false),
              ('Assignee', 'Mauri', false),
            ])
              FractionallySizedBox(
                widthFactor: 0.5,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(k, style: sans(11, color: c.text3)),
                  Text(v, style: sans(13, weight: FontWeight.w500, color: hi ? c.acc : c.text)),
                ]),
              ),
          ]),
          const SizedBox(height: 14),
          Text(
            'Store managers need to see how a SKU’s list price changed over time. Add a paginated history endpoint backed by the price_events table.',
            style: sans(13, color: c.text2, height: 1.55),
          ),
          const SizedBox(height: 14),
          Text('Acceptance criteria', style: sans(12, weight: FontWeight.w600, color: c.text)),
          const SizedBox(height: 8),
          for (final (i, label) in const [
            (0, 'Newest first, 50 events per page'),
            (1, 'Each event shows who changed it and from which system'),
            (2, 'p95 under 120 ms for one year of history'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KCheck(value: _ac[i], label: label, onChanged: (v) => setState(() => _ac[i] = v)),
            ),
          const SizedBox(height: 6),
          Text('Linked docs', style: sans(12, weight: FontWeight.w600, color: c.text)),
          const SizedBox(height: 8),
          for (final (k, title) in const [('CF', 'Discount rules v3'), ('NO', 'ADR-009 · Pagination conventions')])
            KPressable(
              onTap: () => AppScope.read(context).view = KumoView.docs,
              semanticLabel: 'Open $title',
              builder: (context, hover, focus) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SourceTile(k, size: 22),
                  const SizedBox(width: 8),
                  Text(title, style: sans(12.5, color: hover ? c.acc : c.text)),
                ]),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Section(
        strong: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(KIcons.agent, size: 16, color: c.acc),
            const SizedBox(width: 8),
            Text('Start in a worktree', style: sans(13, weight: FontWeight.w600, color: c.text)),
          ]),
          const SizedBox(height: 12),
          if (!_started) ...[
            Row(children: [
              Expanded(
                child: KSelect<String>(
                  label: 'Repository',
                  value: _repo,
                  items: const [('price-admin', 'price-admin'), ('price-reader-v2', 'price-reader-v2'), ('users-permissions', 'users-permissions')],
                  onChanged: (v) => setState(() => _repo = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KSelect<String>(
                  label: 'Base branch',
                  monospace: true,
                  value: _base,
                  items: const [('main', 'main'), ('release/2026.11', 'release/2026.11')],
                  onChanged: (v) => setState(() => _base = v),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            KField(label: 'New branch', controller: _branch, monospace: true),
            const SizedBox(height: 10),
            KSelect<String>(
              label: 'Agent',
              value: _agent,
              items: const [('claude', 'Claude Code · auto-approve edits'), ('codex', 'Codex · ask before shell'), ('gemini', 'Gemini CLI'), ('none', 'No agent, just a shell')],
              onChanged: (v) => setState(() => _agent = v),
            ),
            const SizedBox(height: 10),
            KCheck(value: _sendTicket, label: 'Send ticket and comments as context', onChanged: (v) => setState(() => _sendTicket = v)),
            const SizedBox(height: 6),
            KCheck(value: _attachDocs, label: 'Attach 2 linked docs', onChanged: (v) => setState(() => _attachDocs = v)),
            const SizedBox(height: 12),
            KButton.primary(label: 'Create worktree and start agent', expand: true, height: 36, onTap: _start),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.okSoft, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(KIcons.check, size: 15, color: c.ok),
                  const SizedBox(width: 8),
                  Text('Worktree ready · Claude is planning', style: sans(13, weight: FontWeight.w600, color: c.ok)),
                ]),
                const SizedBox(height: 6),
                Text('~/wt/$_repo/PRC-421', style: mono(11.5, color: c.text2)),
                const SizedBox(height: 4),
                Text('Jira moved to In progress and the branch is linked to the ticket.', style: sans(12, color: c.text2)),
              ]),
            ),
            const SizedBox(height: 10),
            KButton(label: 'Open in terminal', expand: true, height: 36, onTap: () => AppScope.read(context).view = KumoView.terminal),
          ],
        ]),
      ),
    ]);
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.k, required this.label, required this.count, required this.selected, required this.onTap});
  final String k;
  final String label;
  final int count;
  final bool selected;
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
          Text('$count', style: sans(11, color: c.text3)),
        ]),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.label, required this.color, required this.tasks});
  final String label;
  final Color color;
  final List<TaskItem> tasks;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Row(children: [
          Dot(color, size: 8, ring: true),
          const SizedBox(width: 8),
          Text(label, style: sans(12.5, weight: FontWeight.w600, color: c.text)),
          const SizedBox(width: 8),
          Text('${tasks.length}', style: sans(11.5, color: c.text3)),
        ]),
      ),
      for (final t in tasks) Padding(padding: const EdgeInsets.only(bottom: 8), child: _TaskCard(task: t)),
    ]);
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});
  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = task;
    final selected = t.key == 'PRC-421';
    final prioColor = t.prio == 'High' ? c.warn : c.text3;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.pane,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? c.acc : c.paneBorder),
        boxShadow: selected ? [BoxShadow(color: c.accSoft, spreadRadius: 3)] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          TagChip(t.src),
          const SizedBox(width: 6),
          Flexible(child: Text(t.key, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text2))),
          const Spacer(),
          Text(t.prio, style: sans(11, weight: FontWeight.w600, color: prioColor)),
        ]),
        const SizedBox(height: 8),
        Text(t.title, style: sans(13, weight: FontWeight.w500, color: c.text, height: 1.35)),
        if (t.agent != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Dot(t.agentNeedsYou ? c.warn : c.acc, size: 6),
                const SizedBox(width: 6),
                Text(t.agent!, style: sans(11.5, weight: FontWeight.w600, color: t.agentNeedsYou ? c.warn : c.acc)),
              ]),
              if (t.branch != null) Text(t.branch!, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(10.5, color: c.text3)),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.tile, shape: BoxShape.circle),
            child: Text('M', style: sans(9.5, weight: FontWeight.w600, color: c.text2)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(t.meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3))),
        ]),
      ]),
    );
  }
}
