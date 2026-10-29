import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/agents_source.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';
import 'settings_dialog.dart';

/// "New agent": pick one of the connected agents, a worktree and a prompt.
/// The agent's terminal opens in the Terminal view.
/// [prompt] starts the prompt field (e.g. about the file being read);
/// [about] is the ticket or page it hands the agent, for the record.
Future<void> showNewAgentDialog(BuildContext context, {String prompt = '', List<AgentContextItem> about = const []}) {
  final c = context.c;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: c.isDark ? const Color(0x66000000) : const Color(0x33141428),
    transitionDuration: const Duration(milliseconds: 140),
    transitionBuilder: (context, anim, _, child) => FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: child),
    pageBuilder: (context, _, __) => Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
        child: Material(type: MaterialType.transparency, child: NewAgentDialog(prompt: prompt, about: about)),
      ),
    ),
  );
}

class NewAgentDialog extends StatefulWidget {
  const NewAgentDialog({super.key, this.prompt = '', this.about = const []});

  /// What the prompt field starts with.
  final String prompt;

  /// The ticket or page the prompt hands the agent.
  final List<AgentContextItem> about;

  @override
  State<NewAgentDialog> createState() => _NewAgentDialogState();
}

class _NewAgentDialogState extends State<NewAgentDialog> {
  late final _prompt = TextEditingController(text: widget.prompt);
  String? _provider;
  String? _worktree;
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).agents.loadProviders();
    });
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  /// Every worktree in the workspace: (absolute path, "repo · branch").
  List<(String, String)> _worktrees(AppState s) => [
        for (final r in s.workspace.repos)
          for (final w in s.worktreesOf(r)) (s.workspace.absolutePathOf(w), '${r.name} · ${w.branch}'),
      ];

  Future<void> _start(AppState s, String provider, String worktree) async {
    setState(() {
      _starting = true;
      _error = null;
    });
    final run = await s.agents.start(providerId: provider, worktreePath: worktree, prompt: _prompt.text.trim(), context: widget.about);
    if (!mounted) return;
    if (run == null && s.agents.live) {
      setState(() {
        _starting = false;
        _error = s.agents.error ?? 'The agent didn’t start.';
      });
      return;
    }
    Navigator.of(context).maybePop();
    if (run != null) s.openTerminal(run.terminalId, title: run.title, agent: true, directory: run.worktreePath);
  }

  void _openSettings() {
    final navigator = Navigator.of(context);
    navigator.maybePop().then((_) {
      if (navigator.mounted) showSettingsDialog(navigator.context, initial: SettingsTab.ai);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final connected = s.agents.connected;
    final worktrees = _worktrees(s);
    final active = s.activeWorktreeEntry;
    final provider = _provider ?? connected.firstOrNull?.id;
    final worktree = _worktree ??
        (active != null && worktrees.any((w) => w.$1 == s.workspace.absolutePathOf(active)) ? s.workspace.absolutePathOf(active) : worktrees.firstOrNull?.$1);
    final canStart = provider != null && worktree != null && !_starting;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
          if (canStart) _start(s, provider, worktree);
        },
      },
      child: GlassOverlay(
        width: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(10)),
              child: Icon(KIcons.agent, size: 16, color: c.acc),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('New agent', style: sans(14, weight: FontWeight.w600, color: c.text))),
            KIconButton(icon: KIcons.close, label: 'Close', onTap: () => Navigator.of(context).maybePop()),
          ]),
          const SizedBox(height: 14),
          if (connected.isEmpty) ...[
            Text('No agent connected yet', style: sans(13, weight: FontWeight.w600, color: c.text)),
            const SizedBox(height: 4),
            Text(
              'Connect the CLI you use (Claude Code, Codex, Gemini, Copilot, Grok…) or any custom command in Settings › AI agents.',
              style: sans(12.5, color: c.text2, height: 1.4),
            ),
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerRight, child: KButton.primary(label: 'Open AI agents settings', height: 32, onTap: _openSettings)),
          ] else if (worktrees.isEmpty) ...[
            Text('Add a repository to a namespace first: agents run inside its worktrees.', style: sans(12.5, color: c.text2)),
          ] else ...[
            Row(children: [
              Expanded(
                child: KSelect<String>(
                  label: 'Agent',
                  value: provider!,
                  items: [for (final p in connected) (p.id, p.name)],
                  onChanged: (v) => setState(() => _provider = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KSelect<String>(
                  label: 'Worktree',
                  value: worktree!,
                  items: worktrees,
                  onChanged: (v) => setState(() => _worktree = v),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text('Prompt', style: sans(11, color: c.text3)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(11), border: Border.all(color: c.chipBorder)),
              child: TextField(
                controller: _prompt,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                style: sans(12.5, color: c.text, height: 1.4),
                cursorColor: c.acc,
                decoration: const InputDecoration.collapsed(hintText: 'What should it do? (optional: you can also talk to it in its terminal)'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, maxLines: 4, overflow: TextOverflow.ellipsis, style: sans(12, color: c.err)),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Text('Runs in its own terminal, in the worktree', style: sans(11, color: c.text3))),
              KButton(label: 'Cancel', onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 8),
              KButton.primary(
                label: _starting ? 'Starting…' : 'Start',
                onTap: canStart ? () => _start(s, provider, worktree) : null,
                trailing: Kbd('⌘↩', color: c.accText, background: const Color(0x26000000)),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
