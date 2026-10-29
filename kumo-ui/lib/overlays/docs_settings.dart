import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/docs_source.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import 'settings_dialog.dart';

/// Settings › Docs: the knowledge bases Docs reads, which come from the
/// task sources (a Jira source's Atlassian account, Obsidian vaults).
class DocsSourcesPanel extends StatefulWidget {
  const DocsSourcesPanel({super.key});

  @override
  State<DocsSourcesPanel> createState() => _DocsSourcesPanelState();
}

class _DocsSourcesPanelState extends State<DocsSourcesPanel> {
  List<DocGroup>? _groups;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final groups = await AppScope.read(context).docs.list();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _error = null;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _openTasks() {
    final nav = Navigator.of(context);
    nav.pop();
    showSettingsDialog(nav.context, initial: SettingsTab.tickets);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final groups = _groups;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (groups == null && _error == null) Text('Looking at your sources…', style: sans(12.5, color: c.text3)),
      if (groups != null && groups.isEmpty)
        Text('No Jira or Obsidian source yet: add one in Tasks and its docs show up here.', style: sans(12.5, color: c.text3)),
      for (final g in groups ?? const <DocGroup>[]) ...[
        const SizedBox(height: 8),
        _SourceCard(group: g),
      ],
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: sans(12, color: c.err)),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: Text(
            'Confluence uses the email and API token of your Jira source; Obsidian, the vaults you read tasks from. Kumo only reads.',
            style: sans(12, color: c.text3, height: 1.4),
          ),
        ),
        const SizedBox(width: 12),
        KButton(label: 'Manage in Tasks', height: 30, fontSize: 12.5, onTap: _openTasks),
      ]),
    ]);
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.group});
  final DocGroup group;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ok = group.problem.isEmpty;
    final status = ok ? (group.docs.isEmpty ? 'Connected · no pages yet' : 'Connected') : (group.problemIsAuth ? 'Check the token' : 'Can’t read');
    final color = ok ? c.ok : c.warn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.paneBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SourceTile(group.source.kind.badge, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(group.source.kind.label, style: sans(13.5, weight: FontWeight.w600, color: c.text)),
              Text(group.source.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3)),
            ]),
          ),
          const SizedBox(width: 10),
          Dot(color),
          const SizedBox(width: 6),
          Text(status, style: sans(12, weight: FontWeight.w500, color: color)),
        ]),
        if (!ok) ...[
          const SizedBox(height: 8),
          Text(group.problem, style: sans(12, color: c.text3, height: 1.4)),
        ],
      ]),
    );
  }
}
