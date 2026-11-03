import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/profiles_source.dart';
import '../platform/new_window.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';

/// "New workspace": a separate place for another company, a client or the
/// user's own projects. Nothing is shared with the current one.
Future<void> showNewWorkspaceDialog(BuildContext context) {
  final c = context.c;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: c.isDark ? const Color(0x66000000) : const Color(0x33141428),
    transitionDuration: const Duration(milliseconds: 140),
    transitionBuilder: (context, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)), child: child),
    ),
    pageBuilder: (context, _, __) => const Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 80, 24, 24),
        child: Material(type: MaterialType.transparency, child: NewWorkspaceDialog()),
      ),
    ),
  );
}

class NewWorkspaceDialog extends StatefulWidget {
  const NewWorkspaceDialog({super.key});

  @override
  State<NewWorkspaceDialog> createState() => _NewWorkspaceDialogState();
}

class _NewWorkspaceDialogState extends State<NewWorkspaceDialog> {
  final _name = TextEditingController();
  Color? _color;
  bool _copyAgents = true;
  bool _busy = false;
  String? _error;
  AppProfile? _created;
  String? _note;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  /// The first color no workspace uses yet.
  Color _defaultColor(List<AppProfile> all) =>
      profileColors.map((c) => c.$2).where((col) => !all.any((p) => p.color == col)).firstOrNull ?? profileColors.last.$2;

  Future<void> _create() async {
    final s = AppScope.read(context);
    if (_busy || _created != null || !s.profiles.canManage) return;
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Name the workspace first.');
    setState(() => _busy = true);
    try {
      final p = await s.profiles.create(name: name, color: _color ?? _defaultColor(s.profiles.profiles), copyAgentsFrom: _copyAgents ? s.profile.id : null);
      if (mounted) setState(() => _created = p);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newWindow() async {
    final p = _created;
    if (p == null) return;
    final why = await openWorkspaceWindow(p.id);
    if (mounted) setState(() => _note = why ?? 'Opened ${p.name} in a new window. This one stays on ${AppScope.read(context).profile.displayName}.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final from = s.profile.displayName;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _create,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _create,
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: FocusScope(
        autofocus: true,
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          namesRoute: true,
          label: 'New workspace',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: GlassOverlay(
              radius: 24,
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(11)),
                    child: Icon(KIcons.namespace, size: 18, color: c.acc),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('New workspace', style: sans(16, weight: FontWeight.w600, color: c.text)),
                      Text('A separate place for another company, a client or your own projects. Nothing is shared with $from.', style: sans(12, color: c.text3, height: 1.4)),
                    ]),
                  ),
                  KIconButton(icon: KIcons.close, label: 'Close', size: 30, iconSize: 15, onTap: _close),
                ]),
                const SizedBox(height: 16),
                if (_created case final p?) ..._done(p, from) else ..._form(s),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _form(AppState s) {
    final c = context.c;
    final all = s.profiles.profiles;
    final color = _color ?? _defaultColor(all);
    final name = _name.text.trim();
    final sameColor = all.where((p) => p.color == color).firstOrNull;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return [
      if (!s.profiles.canManage) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: c.warnSoft, borderRadius: BorderRadius.circular(12)),
          child: Text(
            'This kumod keeps everything in one workspace: update it to keep workspaces apart. Until then you can name this one in Settings › Workspaces.',
            style: sans(12, color: c.text2, height: 1.45),
          ),
        ),
        const SizedBox(height: 14),
      ],
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(13)),
          child: Text(initial, style: sans(19, weight: FontWeight.w700, color: const Color(0xFF0B0D18))),
        ),
        const SizedBox(width: 12),
        Expanded(child: KField(label: 'Name', controller: _name, hint: 'e.g. Personal, or a client’s name')),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        SizedBox(width: 56, child: Text('Color', style: sans(11, color: c.text3))),
        for (final (label, col) in profileColors) ...[
          ProfileSwatch(
            color: col,
            label: [label, if (all.where((p) => p.color == col).firstOrNull case final p?) 'used by ${p.displayName}'].join(' · '),
            selected: col == color,
            onTap: () => setState(() => _color = col),
          ),
          const SizedBox(width: 8),
        ],
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            sameColor != null ? 'Same as ${sameColor.displayName}: pick another to tell them apart.' : 'Shows on its switcher, so you always know where you are.',
            maxLines: 2,
            style: sans(11.5, color: c.text3, height: 1.35),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      Text('Worktrees in', style: sans(11, color: c.text3)),
      const SizedBox(height: 4),
      Container(
        height: 34,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
        child: Text(worktreesDirFor(name), style: mono(12, color: c.text2)),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        decoration: BoxDecoration(color: c.pane, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.paneBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('YOU’LL CONNECT IN ${(name.isEmpty ? 'IT' : name).toUpperCase()}', style: microLabel(c)),
          const SizedBox(height: 6),
          for (final (icon, title, desc) in const [
            (KIcons.git, 'Git hosts and tokens', 'GitHub, GitLab or Bitbucket with this workspace’s own token.'),
            (KIcons.tasks, 'Task sources', 'Jira, GitHub Issues, Todoist or Obsidian, with their own credentials.'),
            (KIcons.docs, 'Knowledge bases', 'Confluence, Notion or a vault, only for this workspace’s agents.'),
            (KIcons.agent, 'AI agents', 'Each agent signs in again here, so plans, usage and history stay apart.'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(9)),
                  child: Icon(icon, size: 15, color: c.text2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: sans(13, weight: FontWeight.w500, color: c.text)),
                    Text(desc, style: sans(11.5, color: c.text3, height: 1.4)),
                  ]),
                ),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      KPressable(
        onTap: () => setState(() => _copyAgents = !_copyAgents),
        semanticLabel: 'Copy ${s.profile.displayName}’s agent commands, ${_copyAgents ? 'on' : 'off'}',
        selected: _copyAgents,
        builder: (context, hover, focus) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: _copyAgents ? c.accFill : null,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _copyAgents ? c.accFill : c.text3, width: 1.5),
            ),
            child: _copyAgents ? Icon(KIcons.check, size: 12, color: c.accText) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Copy ${s.profile.displayName}’s agent commands', style: sans(12.5, weight: FontWeight.w500, color: c.text)),
              Text('Which CLIs and their arguments: never their sign-ins, tokens or history.', style: sans(11.5, color: c.text3, height: 1.4)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: Text(_error ?? '', maxLines: 2, style: sans(12, color: c.warn, height: 1.35))),
        KButton(label: 'Cancel', onTap: _close),
        const SizedBox(width: 8),
        KButton.primary(
          label: _busy ? 'Creating…' : 'Create workspace',
          onTap: name.isEmpty || _busy || !s.profiles.canManage ? null : _create,
          trailing: Kbd('⌘↩', color: c.accText, background: const Color(0x33FFFFFF)),
        ),
      ]),
    ];
  }

  List<Widget> _done(AppProfile p, String from) {
    final c = context.c;
    final s = AppScope.read(context);
    final n = s.profiles.profiles.indexWhere((x) => x.id == p.id) + 1;
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.okSoft, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(12)),
            child: Text(p.initial, style: sans(17, weight: FontWeight.w700, color: const Color(0xFF0B0D18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.name} is ready', style: sans(13, weight: FontWeight.w600, color: c.ok)),
              Text(
                'Until you connect its accounts, each view says what’s missing.${n > 0 && n <= 9 ? ' Switch with ⌃⌘$n.' : ''}',
                style: sans(12.5, color: c.text2, height: 1.45),
              ),
            ]),
          ),
        ]),
      ),
      if (_note case final note?) ...[const SizedBox(height: 10), Text(note, style: sans(12.5, color: c.text2))],
      const SizedBox(height: 14),
      Row(children: [
        Flexible(child: KButton(label: 'Stay in $from', onTap: _close)),
        const SizedBox(width: 8),
        Flexible(child: KButton(label: 'Open in a new window', icon: KIcons.external, onTap: _newWindow)),
        const SizedBox(width: 8),
        const Spacer(),
        KButton.primary(
          label: 'Switch to ${p.name}',
          onTap: () {
            _close();
            s.switchProfile(p.id);
          },
        ),
      ]),
    ];
  }
}

class ProfileSwatch extends StatelessWidget {
  const ProfileSwatch({super.key, required this.color, required this.label, required this.selected, required this.onTap});
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      semanticLabel: label,
      tooltip: label,
      selected: selected,
      builder: (context, hover, focus) => Container(
        width: 24,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected || focus ? c.text : Colors.transparent, width: 2)),
        child: Container(decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      ),
    );
  }
}
