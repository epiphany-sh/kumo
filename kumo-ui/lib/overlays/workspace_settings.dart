import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/profiles_source.dart';
import '../platform/new_window.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/kicons.dart';
import '../widgets/profile_tile.dart';
import 'new_workspace_dialog.dart';

/// Settings › Workspaces: each workspace with what belongs only to it, its
/// name, color, folders, git identity, SSH key and `gh` accounts.
/// [onOpenTab] shows another Settings tab ('repos', 'tickets', 'ai').
class WorkspacesSettingsPanel extends StatefulWidget {
  const WorkspacesSettingsPanel({super.key, required this.onOpenTab});
  final ValueChanged<String> onOpenTab;

  @override
  State<WorkspacesSettingsPanel> createState() => _WorkspacesSettingsPanelState();
}

class _WorkspacesSettingsPanelState extends State<WorkspacesSettingsPanel> {
  String? _open;
  String? _note;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final all = s.profiles.profiles;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!s.profiles.canManage) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(12)),
            child: Text(
              'This kumod keeps everything in one workspace: update it to keep workspaces apart. You can name this one already.',
              style: sans(12, color: c.text2, height: 1.45),
            ),
          ),
          const SizedBox(height: 8),
        ],
        for (final p in all) ...[
          _ProfileCard(
            key: ValueKey('ws-card-${p.id}'),
            profile: p,
            current: p.id == s.profile.id,
            expanded: _open == p.id,
            onToggle: () => setState(() => _open = _open == p.id ? null : p.id),
            onOpenTab: widget.onOpenTab,
            onNote: (n) => setState(() => _note = n),
          ),
          const SizedBox(height: 8),
        ],
        if (_note case final n?) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(n, style: sans(12.5, color: c.text2))),
        Align(
          alignment: Alignment.centerLeft,
          child: KButton(
            label: 'New workspace',
            icon: KIcons.add,
            height: 30,
            fontSize: 12.5,
            onTap: s.profiles.canManage ? () => showNewWorkspaceDialog(context) : null,
          ),
        ),
      ]),
    );
  }
}

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({
    super.key,
    required this.profile,
    required this.current,
    required this.expanded,
    required this.onToggle,
    required this.onOpenTab,
    required this.onNote,
  });
  final AppProfile profile;
  final bool current;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onOpenTab;
  final ValueChanged<String?> onNote;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _dir = TextEditingController(text: widget.profile.worktreesDir);
  late final _gitName = TextEditingController(text: widget.profile.gitName);
  late final _gitEmail = TextEditingController(text: widget.profile.gitEmail);
  String? _error;
  bool _confirming = false;
  Future<List<SshKeyInfo>>? _keys;
  Future<List<(String, String)>>? _gh;

  @override
  void didUpdateWidget(_ProfileCard old) {
    super.didUpdateWidget(old);
    // The daemon's values, unless one is being typed.
    void sync(TextEditingController t, String v, String was) {
      if (v != was && t.text == was) t.text = v;
    }

    sync(_name, widget.profile.name, old.profile.name);
    sync(_dir, widget.profile.worktreesDir, old.profile.worktreesDir);
    sync(_gitName, widget.profile.gitName, old.profile.gitName);
    sync(_gitEmail, widget.profile.gitEmail, old.profile.gitEmail);
    if (!widget.expanded) _confirming = false;
  }

  @override
  void dispose() {
    for (final t in [_name, _dir, _gitName, _gitEmail]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _save(ProfileChanges ch) async {
    final s = AppScope.read(context);
    try {
      await s.profiles.update(widget.profile.id, ch);
      if (mounted) setState(() => _error = null);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _delete() async {
    final s = AppScope.read(context);
    final name = widget.profile.displayName;
    try {
      await s.profiles.delete(widget.profile.id);
      widget.onNote('$name deleted. Its tokens left the Keychain; its repositories and worktrees stay on disk.');
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final p = widget.profile;
    final manage = s.profiles.canManage;
    if (widget.expanded && manage) {
      _keys ??= s.profiles.sshKeys();
      _gh ??= s.profiles.ghAccounts();
    }
    final (runText, runColor) = p.agentsWaiting > 0 ? (p.activity, c.warn) : (p.activity, p.agentsRunning > 0 ? c.acc : c.text3);
    return Container(
      decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: widget.expanded ? c.accSoft : c.paneBorder)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            ProfileTile(profile: p, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(p.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13.5, weight: FontWeight.w600, color: c.text))),
                  if (widget.current) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(6)),
                      child: Text('This window', style: sans(10.5, weight: FontWeight.w600, color: c.acc)),
                    ),
                  ],
                ]),
                Text(p.summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text3)),
              ]),
            ),
            Dot(runColor),
            const SizedBox(width: 6),
            Text(runText, style: sans(12, weight: FontWeight.w500, color: runColor)),
            const SizedBox(width: 12),
            if (!widget.current && manage) ...[
              KButton(
                label: 'Open in new window',
                height: 30,
                fontSize: 12.5,
                onTap: () async {
                  final why = await openWorkspaceWindow(p.id);
                  widget.onNote(why ?? 'Opened ${p.displayName} in a new window.');
                },
              ),
              const SizedBox(width: 8),
            ],
            KButton(label: widget.expanded ? 'Done' : 'Configure', height: 30, fontSize: 12.5, onTap: widget.onToggle),
          ]),
        ),
        if (widget.expanded) _details(s, p, manage),
      ]),
    );
  }

  Widget _details(AppState s, AppProfile p, bool manage) {
    final c = context.c;
    final owns = [
      ('repos', KIcons.git, 'Git hosts and their tokens', 'Repositories'),
      ('tickets', KIcons.tasks, 'Task sources and knowledge bases', 'Tasks'),
      ('ai', KIcons.agent, 'AI agents, each with this workspace’s own sign-in', 'AI agents'),
      ('', KIcons.namespace, p.summary, ''),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: _field('Name', _name, onDone: () => _save(ProfileChanges(name: _name.text)), hint: p.isDefault ? 'e.g. your company’s name' : null)),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Color', style: sans(11, color: c.text3)),
            const SizedBox(height: 6),
            Row(children: [
              for (final (label, col) in profileColors) ...[
                ProfileSwatch(color: col, label: label, selected: col == p.color, onTap: () => _save(ProfileChanges(color: col))),
                const SizedBox(width: 6),
              ],
            ]),
          ]),
        ]),
        if (manage) ...[
          const SizedBox(height: 12),
          _field('Worktrees in', _dir, monospace: true, onDone: () => _save(ProfileChanges(worktreesDir: _dir.text))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field('Commit as (name)', _gitName, hint: 'Your git config', onDone: () => _save(ProfileChanges(gitName: _gitName.text)))),
            const SizedBox(width: 10),
            Expanded(child: _field('Email', _gitEmail, hint: 'Your git config', onDone: () => _save(ProfileChanges(gitEmail: _gitEmail.text)))),
          ]),
          const SizedBox(height: 12),
          FutureBuilder<List<SshKeyInfo>>(
            future: _keys,
            builder: (context, snap) {
              final keys = snap.data ?? const <SshKeyInfo>[];
              final options = ['', ...keys.map((k) => k.path), if (p.sshKey.isNotEmpty && !keys.any((k) => k.path == p.sshKey)) p.sshKey];
              return Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('SSH key', style: sans(11, color: c.text3)),
                    const SizedBox(height: 4),
                    _Select(
                      value: p.sshKey,
                      options: options,
                      labelOf: (v) {
                        if (v.isEmpty) return 'None: SSH remotes go over HTTPS with this workspace’s token';
                        final k = keys.where((k) => k.path == v).firstOrNull;
                        return k == null ? v : '${k.name}${k.kind.isEmpty ? '' : ' · ${k.kind}'}${k.agentOnly ? ' · in an agent' : ''}';
                      },
                      onChanged: (v) => _save(ProfileChanges(sshKey: v)),
                    ),
                  ]),
                ),
                const SizedBox(width: 14),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(children: [
                    KSwitch(
                      value: p.signCommits && p.sshKey.isNotEmpty,
                      label: 'Sign commits with this key',
                      onChanged: (v) {
                        if (p.sshKey.isNotEmpty) _save(ProfileChanges(signCommits: v));
                      },
                    ),
                    const SizedBox(width: 8),
                    Text('Sign commits', style: sans(12.5, color: p.sshKey.isEmpty ? c.text3 : c.text2)),
                  ]),
                ),
              ]);
            },
          ),
          FutureBuilder<List<(String, String)>>(
            future: _gh,
            builder: (context, snap) {
              final accounts = snap.data ?? const <(String, String)>[];
              final hosts = {for (final (h, _) in accounts) h, for (final (h, _) in p.ghAccounts) h}.toList()..sort();
              if (hosts.isEmpty) return const SizedBox.shrink();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final host in hosts) ...[
                  const SizedBox(height: 12),
                  Text('gh account on $host', style: sans(11, color: c.text3)),
                  const SizedBox(height: 4),
                  _Select(
                    value: p.ghAccounts.where((a) => a.$1 == host).firstOrNull?.$2 ?? '',
                    options: ['', ...{for (final (h, l) in accounts) if (h == host) l, for (final (h, l) in p.ghAccounts) if (h == host) l}],
                    labelOf: (v) => v.isEmpty ? 'Whichever gh has active' : v,
                    onChanged: (v) => _save(ProfileChanges(ghAccounts: [
                      for (final a in p.ghAccounts) if (a.$1 != host) a,
                      if (v.isNotEmpty) (host, v),
                    ])),
                  ),
                ],
              ]);
            },
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('WHAT BELONGS ONLY TO ${p.displayName.toUpperCase()}', style: microLabel(c)),
            const SizedBox(height: 2),
            Text(
              widget.current ? 'Switching to another workspace never brings these along.' : 'Switching to another workspace never brings these along. Switch to ${p.displayName} to edit them.',
              style: sans(11.5, color: c.text3, height: 1.4),
            ),
            for (final (tab, icon, text, link) in owns)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Icon(icon, size: 14, color: c.text2),
                  const SizedBox(width: 8),
                  Expanded(child: Text(text, style: sans(12.5, color: c.text2))),
                  if (widget.current && tab.isNotEmpty)
                    KPressable(
                      onTap: () => widget.onOpenTab(tab),
                      semanticLabel: 'Open $link settings',
                      builder: (context, hover, focus) => Text('$link ›', style: sans(12, weight: FontWeight.w600, color: hover || focus ? c.text : c.acc)),
                    ),
                ]),
              ),
          ]),
        ),
        if (_error case final e?) ...[const SizedBox(height: 10), Text(e, style: sans(12, color: c.warn, height: 1.4))],
        const SizedBox(height: 12),
        if (_confirming)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: c.err)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Delete ${p.displayName}?', style: sans(13, weight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 4),
              Text(
                '${p.agentsRunning + p.agentsWaiting + p.terminalsOpen > 0 ? 'Its running terminals and agents stop. ' : ''}Kumo removes its tokens from the Keychain and forgets its namespaces, task sources and docs. Repositories and worktrees on disk stay where they are.',
                style: sans(12, color: c.text2, height: 1.45),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                KButton(label: 'Cancel', height: 30, fontSize: 12.5, onTap: () => setState(() => _confirming = false)),
                const SizedBox(width: 8),
                KButton.primary(label: 'Delete ${p.displayName}', height: 30, fontSize: 12.5, onTap: _delete),
              ]),
            ]),
          )
        else
          Row(children: [
            Expanded(
              child: Text(
                p.isDefault
                    ? 'The first workspace holds what Kumo had before workspaces: it stays.'
                    : widget.current
                        ? 'This window is on ${p.displayName}: switch to another workspace to delete it.'
                        : 'Its namespaces, task sources, docs and sign-ins go with it.',
                style: sans(12, color: c.text3, height: 1.4),
              ),
            ),
            KPressable(
              onTap: p.isDefault || widget.current || !manage ? null : () => setState(() => _confirming = true),
              semanticLabel: 'Delete ${p.displayName}',
              builder: (context, hover, focus) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  'Delete workspace…',
                  style: sans(12.5, weight: FontWeight.w500, color: p.isDefault || widget.current || !manage ? c.text3 : (hover || focus ? c.text : c.err)),
                ),
              ),
            ),
          ]),
      ]),
    );
  }

  Widget _field(String label, TextEditingController t, {required VoidCallback onDone, bool monospace = false, String? hint}) {
    final c = context.c;
    final style = monospace ? mono(12.5, color: c.text) : sans(13, color: c.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: sans(11, color: c.text3)),
      const SizedBox(height: 4),
      Container(
        height: 34,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.chipBorder)),
        child: Focus(
          onFocusChange: (on) {
            if (!on) onDone();
          },
          child: TextField(
            controller: t,
            style: style,
            cursorColor: c.acc,
            onSubmitted: (_) => onDone(),
            decoration: InputDecoration.collapsed(hintText: hint, hintStyle: style.copyWith(color: c.text3)),
          ),
        ),
      ),
    ]);
  }

}

/// A compact dropdown of [options], shown through [labelOf].
class _Select extends StatelessWidget {
  const _Select({required this.value, required this.options, required this.labelOf, required this.onChanged});
  final String value;
  final List<String> options;
  final String Function(String) labelOf;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = sans(12.5, color: c.text);
    final opts = options.contains(value) ? options : [value, ...options];
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(9), border: Border.all(color: c.chipBorder)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          focusColor: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Color.alphaBlend(c.pop, c.isDark ? const Color(0xFF181A24) : const Color(0xFFF7F8FB)),
          icon: Icon(Icons.unfold_more_rounded, size: 16, color: c.text3),
          style: style,
          items: [for (final o in opts) DropdownMenuItem<String>(value: o, child: Text(labelOf(o), style: style, overflow: TextOverflow.ellipsis))],
          onChanged: (v) {
            if (v != null && v != value) onChanged(v);
          },
        ),
      ),
    );
  }
}
