import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/mock_data.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';

enum _Source { ticket, fresh, existing }

/// "New worktree" popover anchored to the sidebar +. Mirrors the canvas:
/// start from a ticket / new branch / existing branch, optional agent, ⌘↩.
class NewWorktreePopover extends StatefulWidget {
  const NewWorktreePopover({super.key, required this.onClose, this.repo = 'price-admin'});

  final VoidCallback onClose;

  /// Repo the popover opens on (the sidebar row whose + was pressed).
  final String repo;

  @override
  State<NewWorktreePopover> createState() => _NewWorktreePopoverState();
}

class _NewWorktreePopoverState extends State<NewWorktreePopover> {
  _Source _src = _Source.ticket;
  late String _repo = widget.repo;
  String _base = 'main';
  String _ticket = 'PRC-421';
  String _existing = 'origin/fix/PRC-377-export-rounding';
  String _agent = 'claude';
  bool _agentOn = true;
  bool _created = false;
  final _branch = TextEditingController();
  final _path = TextEditingController();

  static const _tickets = <(String, String)>[
    ('PRC-421', 'PRC-421 · Expose price history in admin API'),
    ('CU-2302', 'CU-2302 · Role templates for store managers'),
    ('TD-ROT', 'Todoist · Rotate staging Kafka credentials'),
  ];

  /// Repos the user has put in a namespace, plus the one we opened on.
  List<String> get _repoOptions {
    final names = <String>{widget.repo};
    for (final n in AppScope.read(context).namespaces) {
      names.addAll(n.repos);
    }
    return names.toList();
  }

  @override
  void initState() {
    super.initState();
    _fillNames();
  }

  @override
  void dispose() {
    _branch.dispose();
    _path.dispose();
    super.dispose();
  }

  void _fillNames() {
    final (b, p) = switch (_src) {
      _Source.ticket => switch (_ticket) {
          'PRC-421' => ('feat/PRC-421-price-history', '~/wt/$_repo/PRC-421'),
          'CU-2302' => ('feat/CU-2302-role-templates', '~/wt/$_repo/CU-2302'),
          _ => ('chore/rotate-kafka-creds', '~/wt/$_repo/kafka-creds'),
        },
      _Source.fresh => ('feat/', '~/wt/$_repo/'),
      _Source.existing => ('fix/PRC-377-export-rounding', '~/wt/$_repo/PRC-377'),
    };
    _branch.text = b;
    _path.text = p;
  }

  void _create() {
    // Optimistic: flip the UI now; the daemon (M3) will confirm or revert.
    setState(() => _created = true);
    AppScope.read(context).selectWorktree(_branch.text);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _create,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _create,
      },
      child: GlassOverlay(
        width: 384,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(10)),
              child: Icon(KIcons.branch, size: 16, color: c.acc),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('New worktree', style: sans(14, weight: FontWeight.w600, color: c.text)),
                Text('$_repo · ${Mock.hostNames[Mock.repoNamed(_repo)?.host] ?? 'Local'}', style: sans(11.5, color: c.text3)),
              ]),
            ),
            KIconButton(icon: KIcons.close, label: 'Close', onTap: widget.onClose),
          ]),
          const SizedBox(height: 14),
          if (!_created) ..._form() else ..._done(),
        ]),
      ),
    );
  }

  List<Widget> _form() {
    final p = context.c;
    return [
      Text('Start from', style: sans(11, color: p.text3)),
      const SizedBox(height: 6),
      KSegmented<_Source>(
        expand: true,
        label: 'Start from',
        value: _src,
        onChanged: (v) => setState(() {
          _src = v;
          _fillNames();
        }),
        items: const [(_Source.ticket, 'From ticket', null), (_Source.fresh, 'New branch', null), (_Source.existing, 'Existing', null)],
      ),
      const SizedBox(height: 12),
      KSelect<String>(
        label: 'Repository',
        value: _repo,
        items: [
          for (final r in _repoOptions) (r, r),
        ],
        onChanged: (v) => setState(() {
          _repo = v;
          _fillNames();
        }),
      ),
      const SizedBox(height: 10),
      if (_src == _Source.ticket) ...[
        KSelect<String>(
          label: 'Ticket',
          value: _ticket,
          items: _tickets,
          onChanged: (v) => setState(() {
            _ticket = v;
            _fillNames();
          }),
        ),
        const SizedBox(height: 10),
      ],
      if (_src == _Source.existing) ...[
        KSelect<String>(
          label: 'Existing branch',
          monospace: true,
          value: _existing,
          items: const [
            ('origin/fix/PRC-377-export-rounding', 'origin/fix/PRC-377-export-rounding'),
            ('origin/chore/pgx-v5.7', 'origin/chore/pgx-v5.7'),
            ('origin/spike/price-cache', 'origin/spike/price-cache'),
          ],
          onChanged: (v) => setState(() => _existing = v),
        ),
        const SizedBox(height: 10),
      ],
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: KSelect<String>(
            label: 'Base branch',
            monospace: true,
            value: _base,
            items: const [('main', 'main'), ('release/2026.11', 'release/2026.11')],
            onChanged: (v) => setState(() => _base = v),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: KField(label: 'Branch', controller: _branch, monospace: true)),
      ]),
      const SizedBox(height: 10),
      KField(label: 'Path', controller: _path, monospace: true),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: p.tile, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Start an agent', style: sans(12.5, weight: FontWeight.w600, color: p.text)),
                Text(
                  !_agentOn ? 'Just a shell in the new path' : (_src == _Source.ticket ? 'Gets the ticket, comments and linked docs' : 'Runs in the new worktree'),
                  style: sans(11, color: p.text3),
                ),
              ]),
            ),
            KSwitch(value: _agentOn, onChanged: (v) => setState(() => _agentOn = v), label: 'Start an agent'),
          ]),
          if (_agentOn) ...[
            const SizedBox(height: 10),
            KSelect<String>(
              label: 'Agent',
              value: _agent,
              items: const [('claude', 'Claude Code · auto-approve edits'), ('codex', 'Codex · ask before shell'), ('gemini', 'Gemini CLI')],
              onChanged: (v) => setState(() => _agent = v),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: Text('Opens a terminal tab in the new path', style: sans(11, color: p.text3))),
        KButton(label: 'Cancel', onTap: widget.onClose),
        const SizedBox(width: 8),
        KButton.primary(label: 'Create', onTap: _create, trailing: Kbd('⌘↩', color: p.accText, background: const Color(0x26000000))),
      ]),
    ];
  }

  List<Widget> _done() {
    final p = context.c;
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: p.okSoft, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(KIcons.check, size: 16, color: p.ok),
            const SizedBox(width: 8),
            Text('Worktree created', style: sans(13, weight: FontWeight.w600, color: p.ok)),
          ]),
          const SizedBox(height: 8),
          Text(_branch.text, style: mono(11.5, color: p.text)),
          Text(_path.text, style: mono(11.5, color: p.text2)),
          const SizedBox(height: 6),
          Text(
            _agentOn ? 'The agent is reading the ticket. A terminal tab is open in the new path.' : 'A terminal tab is open in the new path.',
            style: sans(12, color: p.text2),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        KButton(label: 'Create another', onTap: () => setState(() => _created = false)),
        const SizedBox(width: 8),
        Expanded(
          child: KButton.primary(
            label: 'Open terminal',
            expand: true,
            onTap: () {
              AppScope.read(context).view = KumoView.terminal;
              widget.onClose();
            },
          ),
        ),
      ]),
    ];
  }
}
