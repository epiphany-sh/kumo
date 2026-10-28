import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/agents_source.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/kicons.dart';

/// Settings › AI agents: the coding-agent CLIs the user has (Claude Code,
/// Codex, Gemini, Copilot, Grok…) plus any custom command. Kumo runs them
/// with the user's own sign-in; connecting one is optional.
class AgentSettingsPanel extends StatefulWidget {
  const AgentSettingsPanel({super.key});

  @override
  State<AgentSettingsPanel> createState() => _AgentSettingsPanelState();
}

class _AgentSettingsPanelState extends State<AgentSettingsPanel> {
  String? _open;
  bool _adding = false;
  bool _loaded = false;

  /// Result of "Test connection" per provider: (ok, message).
  final _tests = <String, (bool, String)>{};

  @override
  void initState() {
    super.initState();
    // Detection reads the login shell's PATH: do it when the tab opens.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await AppScope.read(context).agents.loadProviders();
      if (mounted) setState(() => _loaded = true);
    });
  }

  Future<void> _connect(AgentsSource agents, AgentProviderInfo p, {required bool enabled}) async {
    await agents.saveProvider(id: p.id, name: p.name, program: p.program, args: p.args, enabled: enabled, isDefault: p.isDefault);
    if (mounted) setState(() => _open = enabled ? p.id : null);
  }

  Future<void> _test(AgentsSource agents, AgentProviderInfo p) async {
    setState(() => _tests[p.id] = (true, 'Asking ${p.program}…'));
    try {
      final version = await agents.test(p.id);
      if (mounted) setState(() => _tests[p.id] = (true, version));
    } on Object catch (e) {
      if (mounted) setState(() => _tests[p.id] = (false, '$e'));
    }
  }

  Future<void> _login(AppState s, AgentProviderInfo p) async {
    final terminal = await s.agents.login(p.id);
    if (terminal == null || !mounted) return;
    // Sign-in happens in the CLI itself, in a terminal pane.
    Navigator.of(context).maybePop();
    s.openTerminal(terminal, title: '${p.name} · sign in');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final agents = s.agents;
    final providers = agents.providers;
    final connected = agents.connected;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (providers.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(_loaded ? 'Kumo can’t reach its engine right now.' : 'Looking for agents on your PATH…', style: sans(12.5, color: c.text3)),
        ),
      for (final p in providers) ...[
        const SizedBox(height: 8),
        _ProviderCard(
          provider: p,
          expanded: p.enabled && _open == p.id,
          test: _tests[p.id],
          onToggle: () => setState(() => _open = _open == p.id ? null : p.id),
          onConnect: () => _connect(agents, p, enabled: true),
          onDisconnect: () => _connect(agents, p, enabled: false),
          onTest: () => _test(agents, p),
          onLogin: p.installed ? () => _login(s, p) : null,
          onDelete: p.custom ? () => agents.deleteProvider(p.id) : null,
          onSave: (program, args, isDefault) =>
              agents.saveProvider(id: p.id, name: p.name, program: program, args: args, enabled: true, isDefault: isDefault),
        ),
      ],
      if (agents.error != null) ...[
        const SizedBox(height: 10),
        Text(agents.error!, style: sans(12, color: c.err)),
      ],
      const SizedBox(height: 12),
      if (_adding)
        _CustomAgentForm(
          onCancel: () => setState(() => _adding = false),
          onAdd: (name, program, args) async {
            final saved = await agents.saveProvider(name: name, program: program, args: args, enabled: true);
            if (saved != null && mounted) setState(() => _adding = false);
          },
        )
      else
        Align(
          alignment: Alignment.centerLeft,
          child: KButton(label: 'Add custom agent', icon: KIcons.add, height: 30, fontSize: 12.5, onTap: () => setState(() => _adding = true)),
        ),
      if (connected.length > 1) ...[
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Default agent', style: sans(13, weight: FontWeight.w500, color: c.text)),
              Text('Used by “New agent” and when starting from a ticket.', style: sans(11.5, color: c.text3)),
            ]),
          ),
          SizedBox(
            width: 220,
            child: KSelect<String>(
              label: 'Default agent',
              value: connected.first.id,
              items: [for (final p in connected) (p.id, p.name)],
              onChanged: (id) {
                final p = connected.firstWhere((p) => p.id == id);
                agents.saveProvider(id: p.id, name: p.name, program: p.program, args: p.args, enabled: true, isDefault: true);
              },
            ),
          ),
        ]),
      ],
    ]);
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.expanded,
    required this.test,
    required this.onToggle,
    required this.onConnect,
    required this.onDisconnect,
    required this.onTest,
    required this.onSave,
    this.onLogin,
    this.onDelete,
  });

  final AgentProviderInfo provider;
  final bool expanded;
  final (bool, String)? test;
  final VoidCallback onToggle;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onTest;
  final VoidCallback? onLogin;
  final VoidCallback? onDelete;
  final Future<AgentProviderInfo?> Function(String program, String args, bool isDefault) onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = provider;
    final (status, color) = switch ((p.enabled, p.installed)) {
      (true, true) => ('Connected', c.ok),
      (true, false) => ('Not found', c.warn),
      (false, true) => ('Not connected', c.text3),
      (false, false) => ('Not installed', c.text3),
    };
    final meta = switch ((p.enabled, p.installed)) {
      (_, true) => p.resolvedPath.isEmpty ? p.program : p.resolvedPath,
      (true, false) => 'Not on your PATH${p.installHint.isEmpty ? '' : ' · ${p.installHint}'}',
      (false, false) => p.installHint.isEmpty ? 'Not on your PATH' : p.installHint,
    };
    final Widget action;
    if (p.enabled) {
      action = KButton(label: expanded ? 'Done' : 'Configure', height: 30, fontSize: 12.5, onTap: onToggle);
    } else if (p.installed || p.custom) {
      action = KButton.primary(label: 'Connect', height: 30, fontSize: 12.5, onTap: onConnect);
    } else {
      action = KButton(
        label: 'Copy install command',
        icon: KIcons.copy,
        height: 30,
        fontSize: 12.5,
        onTap: p.installHint.isEmpty ? null : () => Clipboard.setData(ClipboardData(text: p.installHint)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.codeBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: expanded ? c.accSoft : c.paneBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.enabled ? c.accSoft : c.tile, borderRadius: BorderRadius.circular(10)),
              child: Text(p.short, style: mono(11, weight: FontWeight.w700, color: p.enabled ? c.acc : c.text3)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13.5, weight: FontWeight.w600, color: c.text))),
                  if (p.isDefault && p.enabled) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(6)),
                      child: Text('Default', style: sans(10.5, weight: FontWeight.w600, color: c.acc, height: 1.6)),
                    ),
                  ],
                  if (p.custom) ...[
                    const SizedBox(width: 8),
                    Text('custom', style: sans(10.5, color: c.text3)),
                  ],
                ]),
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3)),
              ]),
            ),
            const SizedBox(width: 10),
            Dot(color),
            const SizedBox(width: 6),
            Text(status, style: sans(12, weight: FontWeight.w500, color: color)),
            const SizedBox(width: 12),
            action,
          ]),
        ),
        if (expanded) ...[
          _ProviderEditor(key: ValueKey('${p.id}:${p.program}:${p.args}:${p.isDefault}'), provider: p, onSave: onSave),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
            child: Row(children: [
              KButton(label: 'Test connection', height: 30, fontSize: 12.5, onTap: onTest),
              if (onLogin != null) ...[
                const SizedBox(width: 8),
                KButton(label: 'Log in', icon: KIcons.terminal, height: 30, fontSize: 12.5, kind: KButtonKind.ghost, onTap: onLogin),
              ],
              if (test != null) ...[
                const SizedBox(width: 10),
                Icon(test!.$1 ? KIcons.check : KIcons.warning, size: 14, color: test!.$1 ? c.ok : c.err),
                const SizedBox(width: 6),
                Flexible(child: Text(test!.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(12, color: test!.$1 ? c.ok : c.err))),
              ],
              const Spacer(),
              if (onDelete != null) _DangerLink(label: 'Delete', onTap: onDelete!),
              _DangerLink(label: 'Disconnect', onTap: onDisconnect),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Command, arguments and default for a connected provider.
class _ProviderEditor extends StatefulWidget {
  const _ProviderEditor({super.key, required this.provider, required this.onSave});
  final AgentProviderInfo provider;
  final Future<AgentProviderInfo?> Function(String program, String args, bool isDefault) onSave;

  @override
  State<_ProviderEditor> createState() => _ProviderEditorState();
}

class _ProviderEditorState extends State<_ProviderEditor> {
  late final _program = TextEditingController(text: widget.provider.program)..addListener(_changed);
  late final _args = TextEditingController(text: widget.provider.args)..addListener(_changed);
  bool _dirty = false;

  void _changed() {
    final dirty = _program.text != widget.provider.program || _args.text != widget.provider.args;
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  @override
  void dispose() {
    _program.dispose();
    _args.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = widget.provider;
    final promptNote = p.custom
        ? 'Write {prompt} where the prompt goes; without it, Kumo types the prompt in when the agent is ready.'
        : (p.takesPrompt ? 'The prompt is passed when the agent starts.' : 'Kumo types the prompt in once the agent is ready.');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: KField(label: 'Command', controller: _program, monospace: true)),
          const SizedBox(width: 10),
          Expanded(flex: 3, child: KField(label: 'Arguments', controller: _args, monospace: true, hint: p.custom ? '--task {prompt}' : '--model …')),
        ]),
        const SizedBox(height: 6),
        Text(promptNote, style: sans(11.5, color: c.text3)),
        const SizedBox(height: 10),
        Row(children: [
          KSwitch(value: p.isDefault, label: 'Default agent', onChanged: (v) => widget.onSave(p.program, p.args, v)),
          const SizedBox(width: 8),
          Text('Default agent', style: sans(12.5, color: c.text2)),
          const Spacer(),
          if (_dirty) KButton.primary(label: 'Save', height: 28, fontSize: 12, onTap: () => widget.onSave(_program.text.trim(), _args.text.trim(), p.isDefault)),
        ]),
      ]),
    );
  }
}

/// "Add custom agent": any command that runs an agent in a terminal.
class _CustomAgentForm extends StatefulWidget {
  const _CustomAgentForm({required this.onAdd, required this.onCancel});
  final Future<void> Function(String name, String program, String args) onAdd;
  final VoidCallback onCancel;

  @override
  State<_CustomAgentForm> createState() => _CustomAgentFormState();
}

class _CustomAgentFormState extends State<_CustomAgentForm> {
  final _name = TextEditingController();
  final _program = TextEditingController();
  final _args = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _program.dispose();
    _args.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.accSoft)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Custom agent', style: sans(13.5, weight: FontWeight.w600, color: c.text)),
        const SizedBox(height: 4),
        Text('Any CLI works: Kumo runs it in the worktree’s terminal with your own sign-in.', style: sans(12, color: c.text3)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: KField(label: 'Name', controller: _name, hint: 'My agent')),
          const SizedBox(width: 10),
          Expanded(child: KField(label: 'Command', controller: _program, monospace: true, hint: 'my-agent')),
        ]),
        const SizedBox(height: 10),
        KField(label: 'Arguments', controller: _args, monospace: true, hint: '--task {prompt}'),
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: Listenable.merge([_name, _program]),
          builder: (context, _) => Row(children: [
            const Spacer(),
            KButton(label: 'Cancel', height: 30, fontSize: 12.5, onTap: widget.onCancel),
            const SizedBox(width: 8),
            KButton.primary(
              label: 'Add agent',
              height: 30,
              fontSize: 12.5,
              onTap: _name.text.trim().isEmpty || _program.text.trim().isEmpty
                  ? null
                  : () => widget.onAdd(_name.text.trim(), _program.text.trim(), _args.text.trim()),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _DangerLink extends StatelessWidget {
  const _DangerLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, hover, focus) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: hover || focus ? c.errSoft : null, borderRadius: BorderRadius.circular(15)),
        child: Text(label, style: sans(12.5, weight: FontWeight.w500, color: c.err)),
      ),
    );
  }
}
