import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/agent_defs.dart';
import '../data/agent_defs_source.dart';
import '../data/agents_source.dart';
import '../theme/kumo_theme.dart';
import '../views/agents_library.dart' show AgentAvatar, riskColors, worktreeContext;
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';
import 'settings_dialog.dart';

/// "New agent": one of the connected CLIs or one of your agents, a
/// worktree, what it should know and a prompt. Its terminal opens in Agents.
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

  /// `cli:<provider>` or `def:<agent key>`.
  String? _agent;
  String? _worktree;
  bool _picking = false;
  bool _starting = false;
  String? _error;
  List<AgentContextItem> _found = const [];
  String? _foundFor;
  final _removed = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppScope.read(context);
      s.agents.loadProviders();
      s.agentDefs.load();
    });
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  /// Every worktree in the workspace: (absolute path, "repo · branch", repo).
  List<(String, String, String)> _worktrees(AppState s) => [
        for (final r in s.workspace.repos)
          for (final w in s.worktreesOf(r)) (s.workspace.absolutePathOf(w), '${r.name} · ${w.branch}', r.name),
      ];

  void _lookUp(AppState s, String path) {
    if (_foundFor == path) return;
    _foundFor = path;
    _found = const [];
    _removed.clear();
    worktreeContext(s, path).then((items) {
      if (mounted && _foundFor == path) setState(() => _found = items);
    });
  }

  Future<void> _start(AppState s, String agent, (String, String, String) worktree, List<AgentContextItem> context) async {
    setState(() {
      _starting = true;
      _error = null;
    });
    final prompt = _prompt.text.trim();
    if (agent.startsWith('def:')) {
      final def = s.agentDefs.agents.where((a) => 'def:${a.key}' == agent).firstOrNull;
      final run = def == null ? null : await s.agentDefs.run(def, AgentWhere.worktree(worktree.$1, repo: worktree.$3), prompt: prompt, context: context);
      if (!mounted) return;
      if (run == null) {
        setState(() {
          _starting = false;
          _error = s.agentDefs.error ?? s.agents.error ?? 'The agent didn’t start.';
        });
        return;
      }
      Navigator.of(this.context).maybePop();
      s.showInAgents(AgentsRequest.agent(def!.key, run: run.id));
      return;
    }
    final run = await s.agents.start(providerId: agent.substring(4), worktreePath: worktree.$1, prompt: prompt, context: context);
    if (!mounted) return;
    if (run == null && s.agents.live) {
      setState(() {
        _starting = false;
        _error = s.agents.error ?? 'The agent didn’t start.';
      });
      return;
    }
    Navigator.of(this.context).maybePop();
    // Its whole output, in Agents (the Terminal view has it too).
    if (run != null) s.showInAgents(AgentsRequest.session(run.id));
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
    final mine = s.agentDefs.supported && connected.any((p) => p.id == 'claude') ? s.agentDefs.agents : const <AgentDef>[];
    final worktrees = _worktrees(s);
    final active = s.activeWorktreeEntry;
    final agent = _agent ?? (connected.isEmpty ? null : 'cli:${connected.first.id}');
    final worktree = worktrees.where((w) => w.$1 == _worktree).firstOrNull ??
        (active != null ? worktrees.where((w) => w.$1 == s.workspace.absolutePathOf(active)).firstOrNull : null) ??
        worktrees.firstOrNull;
    if (worktree != null) _lookUp(s, worktree.$1);
    final def = agent != null && agent.startsWith('def:') ? mine.where((a) => 'def:${a.key}' == agent).firstOrNull : null;
    final context0 = [
      ...widget.about,
      for (final i in _found) if (!_removed.contains(i.title) && !widget.about.contains(i)) i,
    ];
    final canStart = agent != null && worktree != null && !_starting && (def != null || agent.startsWith('cli:'));
    final provider = connected.where((p) => 'cli:${p.id}' == agent).firstOrNull;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
          if (canStart) _start(s, agent!, worktree!, context0);
        },
      },
      child: GlassOverlay(
        width: 560,
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
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Agent', style: sans(11, color: c.text3)),
                  const SizedBox(height: 4),
                  _PickerButton(
                    name: def?.name ?? provider?.name ?? '',
                    short: def == null ? provider?.short ?? '' : '',
                    color: def?.color,
                    monospace: def != null,
                    open: _picking,
                    onTap: () => setState(() => _picking = !_picking),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KSelect<String>(
                  label: 'Worktree',
                  value: worktree!.$1,
                  items: [for (final w in worktrees) (w.$1, w.$2)],
                  onChanged: (v) => setState(() => _worktree = v),
                ),
              ),
            ]),
            if (_picking) ...[
              const SizedBox(height: 8),
              _AgentList(
                connected: connected,
                mine: mine,
                selected: agent,
                onPick: (v) => setState(() {
                  _agent = v;
                  _picking = false;
                }),
                onCreate: () {
                  Navigator.of(context).maybePop();
                  s.showInAgents(const AgentsRequest.agent('', tab: 'new'));
                },
              ),
            ],
            if (def != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Text(agentToolsKind(def.tools).$2, style: sans(11.5, weight: FontWeight.w600, color: riskColors(c, agentToolsKind(def.tools).$1).$1)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '· ${[...def.tools, ...def.mcpServers].join(', ')} · ${agentModelLabel(def.model)}${def.maxTurns == null ? '' : ' · ${def.maxTurns} turns'}${def.maxMinutes == null ? '' : ' · ${def.maxMinutes} min'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sans(11.5, color: c.text2),
                    ),
                  ),
                  KButton(
                    label: 'Edit',
                    height: 24,
                    fontSize: 11.5,
                    kind: KButtonKind.ghost,
                    onTap: () {
                      Navigator.of(context).maybePop();
                      s.showInAgents(AgentsRequest.agent(def.key, tab: 'edit'));
                    },
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            Text('Context · saved next to the run: nothing lands in the repo', style: sans(11, color: c.text3)),
            const SizedBox(height: 5),
            Wrap(spacing: 5, runSpacing: 5, children: [
              for (final i in context0)
                _ContextChip(
                  item: i,
                  onRemove: widget.about.contains(i) ? null : () => setState(() => _removed.add(i.title)),
                ),
              if (def != null)
                for (final k in def.knowledge) _ContextChip(item: AgentContextItem(kind: AgentContextKind.files, title: k), note: 'always'),
              if (context0.isEmpty && (def?.knowledge.isEmpty ?? true)) Text('Nothing found for this branch.', style: sans(11.5, color: c.text3)),
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
              Expanded(child: Text('Its terminal opens in Agents, with all its output', style: sans(11, color: c.text3))),
              KButton(label: 'Cancel', onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 8),
              KButton.primary(
                label: _starting ? 'Starting…' : 'Start',
                onTap: canStart ? () => _start(s, agent!, worktree!, context0) : null,
                trailing: Kbd('⌘↩', color: c.accText, background: const Color(0x26000000)),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({required this.name, required this.short, required this.color, required this.monospace, required this.open, required this.onTap});
  final String name;
  final String short;
  final String? color;
  final bool monospace;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      selected: open,
      semanticLabel: 'Agent: $name',
      builder: (context, hover, focus) => Container(
        height: 34,
        padding: const EdgeInsets.only(left: 8, right: 6),
        decoration: BoxDecoration(color: hover ? c.tabActive : c.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: focus || open ? c.acc : c.chipBorder)),
        child: Row(children: [
          if (color != null) AgentAvatar(name: name, color: color!, size: 20) else SourceTile(short, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: monospace ? mono(12, color: c.text) : sans(12.5, color: c.text))),
          Icon(Icons.unfold_more_rounded, size: 16, color: c.text3),
        ]),
      ),
    );
  }
}

/// The CLIs, then your agents (Claude Code), then "Create an agent…".
class _AgentList extends StatelessWidget {
  const _AgentList({required this.connected, required this.mine, required this.selected, required this.onPick, required this.onCreate});
  final List<AgentProviderInfo> connected;
  final List<AgentDef> mine;
  final String? selected;
  final ValueChanged<String> onPick;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget row({required String id, required Widget lead, required String name, required String hint, String tag = '', Color? tagColor, bool monospace = false}) => KPressable(
          onTap: () => onPick(id),
          selected: id == selected,
          semanticLabel: name,
          builder: (context, hover, focus) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: id == selected ? c.accSoft : (hover || focus ? c.tile : null), borderRadius: BorderRadius.circular(9)),
            child: Row(children: [
              lead,
              const SizedBox(width: 9),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: monospace ? mono(12, weight: FontWeight.w500, color: c.text) : sans(12.5, weight: FontWeight.w500, color: c.text)),
                  Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3)),
                ]),
              ),
              if (tag.isNotEmpty) Text(tag, style: sans(10.5, weight: FontWeight.w600, color: tagColor ?? c.text3)),
            ]),
          ),
        );
    Widget head(String t) => Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 4), child: Text(t.toUpperCase(), style: sans(10.5, weight: FontWeight.w600, color: c.text3, letterSpacing: 0.5)));
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: c.pane, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.paneBorder)),
      child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
        head('Agent CLIs'),
        for (final p in connected) row(id: 'cli:${p.id}', lead: SourceTile(p.short, size: 22), name: p.name, hint: 'A plain session, with your prompt'),
        if (mine.isNotEmpty) ...[
          const SizedBox(height: 4),
          head('Your agents · Claude Code'),
          for (final a in mine)
            row(
              id: 'def:${a.key}',
              lead: AgentAvatar(name: a.name, color: a.color, size: 22),
              name: a.name,
              hint: a.description,
              tag: agentToolsKind(a.tools).$2,
              tagColor: riskColors(c, agentToolsKind(a.tools).$1).$1,
              monospace: true,
            ),
        ],
        Container(height: 1, color: c.divider, margin: const EdgeInsets.symmetric(vertical: 4)),
        KPressable(
          onTap: onCreate,
          semanticLabel: 'Create an agent',
          builder: (context, hover, focus) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(9)),
            child: Row(children: [
              Icon(KIcons.add, size: 14, color: c.acc),
              const SizedBox(width: 8),
              Text('Create an agent…', style: sans(12.5, weight: FontWeight.w600, color: c.acc)),
              const SizedBox(width: 6),
              Text('in Agents › Your agents', style: sans(11, color: c.text3)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.item, this.onRemove, this.note});
  final AgentContextItem item;
  final VoidCallback? onRemove;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 26,
      padding: EdgeInsets.only(left: 6, right: onRemove == null ? 9 : 2),
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(13), border: Border.all(color: c.chipBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        TagChip(agentContextTag(item.kind)),
        const SizedBox(width: 6),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text))),
        if (note != null) ...[const SizedBox(width: 5), Text(note!, style: sans(10.5, color: c.text3))],
        if (onRemove != null) KIconButton(icon: KIcons.close, label: 'Remove ${item.title}', size: 22, iconSize: 11, onTap: onRemove),
      ]),
    );
  }
}
