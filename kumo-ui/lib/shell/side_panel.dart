import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/changes.dart';
import '../theme/kumo_theme.dart';
import '../widgets/context_menu.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';
import 'screen_chrome.dart';

/// Left panel of the Terminal view with three tabs: the worktree's files,
/// the inspector widgets, and source control. ⌥⌘B hides / shows it.
class SidePanel extends StatelessWidget {
  const SidePanel({super.key});

  static const _icons = {
    SidePanelTab.files: KIcons.folder,
    SidePanelTab.widgets: KIcons.widgets,
    SidePanelTab.git: KIcons.git,
  };

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    return GlassPanel(
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
          child: Row(children: [
            for (final t in SidePanelTab.values)
              KPressable(
                onTap: () => s.showSidePanelTab(t),
                semanticLabel: t.label,
                tooltip: t.label,
                selected: s.sidePanelTab == t,
                builder: (context, hover, focus) {
                  final on = s.sidePanelTab == t;
                  return SizedBox(
                    width: 40,
                    height: 46,
                    child: Stack(alignment: Alignment.center, children: [
                      Icon(_icons[t], size: 18, color: on || hover ? c.text : c.text3),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 0,
                        child: Container(height: 2, decoration: BoxDecoration(color: on ? c.text : Colors.transparent, borderRadius: BorderRadius.circular(1))),
                      ),
                    ]),
                  );
                },
              ),
            const Spacer(),
            KIconButton(icon: KIcons.sidePanel, label: 'Hide side panel (⌥⌘B)', onTap: s.toggleSidePanel),
          ]),
        ),
        Expanded(
          child: switch (s.sidePanelTab) {
            SidePanelTab.files => const _FilesTab(),
            SidePanelTab.widgets => const _WidgetsTab(),
            SidePanelTab.git => const _SourceControlTab(),
          },
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Source control

class _SourceControlTab extends StatefulWidget {
  const _SourceControlTab();

  @override
  State<_SourceControlTab> createState() => _SourceControlTabState();
}

class _SourceControlTabState extends State<_SourceControlTab> {
  final _msg = TextEditingController();
  final _query = TextEditingController();
  bool _needMsg = false;
  bool _searching = false;
  final Set<String> _collapsed = {};

  /// A first message from the changed files: what changed, and where.
  static String _draft(List<ChangedFile> files) {
    String verb(String kind) => switch (kind) { 'A' || 'U' => 'Add', 'D' => 'Delete', 'R' => 'Rename', _ => 'Update' };
    if (files.length == 1) return '${verb(files.first.kind)} ${files.first.path}';
    final verbs = {for (final f in files) verb(f.kind)};
    final dirs = {for (final f in files) f.path.contains('/') ? f.path.substring(0, f.path.lastIndexOf('/')) : ''};
    final where = dirs.length == 1 && dirs.first.isNotEmpty ? ' in ${dirs.first}' : '';
    return [
      '${verbs.length == 1 ? verbs.first : 'Update'} ${files.length} files$where',
      '',
      for (final f in files) '- ${verb(f.kind)} ${f.path}',
    ].join('\n');
  }

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _msg.dispose();
    _query.dispose();
    super.dispose();
  }

  void _commit(String how) {
    final s = AppScope.read(context);
    if (s.pendingChanges.isEmpty) return;
    if (_msg.text.trim().isEmpty) {
      setState(() => _needMsg = true);
      return;
    }
    if (s.commit(_msg.text, how: how)) {
      _msg.clear();
      setState(() => _needMsg = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final pending = s.pendingChanges;
    final onBranch = s.branchChanges;
    final q = _query.text.trim().toLowerCase();
    bool match(ChangedFile f) => q.isEmpty || f.path.toLowerCase().contains(q);
    final git = s.changes;
    final ahead = git.ahead;
    final base = git.base.isEmpty ? 'its base' : git.base;

    return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), children: [
      Row(children: [
        Icon(KIcons.branch, size: 15, color: c.text2),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            git.branch.isEmpty ? 'No worktree' : git.branch,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mono(12.5, weight: FontWeight.w500, color: c.text),
          ),
        ),
        KIconButton(
          icon: KIcons.search,
          label: 'Filter files',
          color: _searching ? c.acc : null,
          onTap: () => setState(() {
            _searching = !_searching;
            if (!_searching) _query.clear();
          }),
        ),
        Builder(
          builder: (btn) => KIconButton(
            icon: KIcons.more,
            label: 'More source control actions',
            onTap: () => showKMenu(
              btn,
              position: belowOf(btn),
              alignRight: true,
              builder: (context, close) => KMenuPanel(width: 200, children: [
                for (final (icon, label, action) in [
                  (Icons.refresh_rounded, 'Fetch', s.fetch),
                  (KIcons.download, git.behind > 0 ? 'Pull ↓${git.behind}' : 'Pull', s.pull),
                  (KIcons.upload, !git.pushed ? 'Publish branch' : (ahead > 0 ? 'Push ↑$ahead' : 'Push'), s.push),
                ])
                  KMenuItem(
                    icon: icon,
                    label: label,
                    onTap: () {
                      close();
                      action();
                    },
                  ),
                const KMenuDivider(),
                KMenuItem(
                  icon: KIcons.external,
                  label: 'Open Git view',
                  onTap: () {
                    close();
                    s.view = KumoView.git;
                  },
                ),
              ]),
            ),
          ),
        ),
      ]),
      if (_searching) ...[
        const SizedBox(height: 10),
        _Field(controller: _query, hint: 'Filter changed files', autofocus: true),
      ],
      if (git.base.isNotEmpty) ...[
        const SizedBox(height: 6),
        Row(children: [
          Icon(KIcons.arrowRight, size: 13, color: c.text3),
          const SizedBox(width: 7),
          Expanded(
            child: Tooltip(
              message: 'Compared with',
              child: Text(git.base, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(12, color: c.text2)),
            ),
          ),
          Tooltip(
            message: '$ahead to push · ${git.behind} to pull${git.pushed ? '' : ' · not published yet'}',
            child: Text('↑$ahead ↓${git.behind}', style: mono(11.5, color: c.text3)),
          ),
        ]),
      ],
      const SizedBox(height: 12),
      CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): () => _commit('commit'),
          const SingleActivator(LogicalKeyboardKey.enter, control: true): () => _commit('commit'),
        },
        child: Stack(children: [
          Container(
            constraints: const BoxConstraints(minHeight: 78),
            padding: const EdgeInsets.fromLTRB(12, 10, 36, 10),
            decoration: BoxDecoration(
              color: c.chip,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _needMsg ? c.warn : c.chipBorder),
            ),
            child: Semantics(
              label: 'Commit message',
              textField: true,
              child: TextField(
                controller: _msg,
                minLines: 3,
                maxLines: 8,
                onChanged: (_) {
                  if (_needMsg) setState(() => _needMsg = false);
                },
                style: sans(12.5, color: c.text, height: 1.45),
                cursorColor: c.acc,
                decoration: InputDecoration.collapsed(hintText: 'Message (⌘↩ to commit)', hintStyle: sans(12.5, color: c.text3, height: 1.45)),
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: KIconButton(
              icon: KIcons.sparkle,
              label: 'Generate message from the changes',
              color: c.acc,
              onTap: pending.isEmpty
                  ? null
                  : () => setState(() {
                        _msg.text = _draft(pending);
                        _needMsg = false;
                      }),
            ),
          ),
        ]),
      ),
      if (_needMsg) ...[
        const SizedBox(height: 6),
        Text('Write a message, or generate one with the ✦ button.', style: sans(11.5, color: c.warn)),
      ],
      const SizedBox(height: 10),
      _CommitButton(
        enabled: pending.isNotEmpty,
        onCommit: _commit,
        // Nothing to commit: the button pushes what was committed.
        push: pending.isEmpty && s.canPush ? (!git.pushed ? 'Publish branch' : 'Push ↑$ahead') : null,
        onPush: s.push,
      ),
      if (s.commitNotice != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 3, 3, 3),
          decoration: BoxDecoration(color: c.okSoft, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(KIcons.check, size: 14, color: c.ok),
            const SizedBox(width: 6),
            Expanded(child: Text(s.commitNotice!, style: sans(12, color: c.text2))),
            if (s.canUndoCommit) KButton(label: 'Undo', kind: KButtonKind.ghost, height: 26, fontSize: 12, onTap: s.undoCommit),
          ]),
        ),
      ],
      const SizedBox(height: 14),
      _ScSection(
        title: 'Changes',
        total: pending.length,
        files: pending.where(match).toList(),
        open: !_collapsed.contains('changes'),
        onToggle: () => setState(() => _collapsed.contains('changes') ? _collapsed.remove('changes') : _collapsed.add('changes')),
        empty: q.isNotEmpty && pending.isNotEmpty ? 'No files match “$q”.' : (s.commitNotice != null ? 'Nothing to commit. Working tree clean.' : 'No changes.'),
      ),
      const SizedBox(height: 6),
      _ScSection(
        title: 'Committed on branch',
        total: onBranch.length,
        files: onBranch.where(match).toList(),
        open: !_collapsed.contains('branch'),
        onToggle: () => setState(() => _collapsed.contains('branch') ? _collapsed.remove('branch') : _collapsed.add('branch')),
        empty: q.isNotEmpty && onBranch.isNotEmpty ? 'No files match “$q”.' : 'No commits ahead of $base.',
        onViewAll: onBranch.isEmpty ? null : () => s.openAllFiles(onBranch.map((f) => f.path)),
      ),
    ]);
  }
}

/// Commit button with a ⌄ menu: Commit & Push, Amend. With nothing to
/// commit and commits to push, it pushes ([push] is its label).
class _CommitButton extends StatelessWidget {
  const _CommitButton({required this.enabled, required this.onCommit, this.push, required this.onPush});
  final bool enabled;
  final void Function(String how) onCommit;
  final String? push;
  final VoidCallback onPush;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 34,
      decoration: chipDecoration(c, radius: 12),
      child: Row(children: [
        Expanded(
          child: KPressable(
            onTap: enabled ? () => onCommit('commit') : (push != null ? onPush : null),
            semanticLabel: enabled ? 'Commit' : (push ?? 'Nothing to commit'),
            builder: (context, hover, focus) {
              final on = enabled || push != null;
              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on && hover ? c.tile : null,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(enabled || push == null ? KIcons.check : KIcons.upload, size: 15, color: on ? c.text : c.text3),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      enabled ? 'Commit' : (push ?? 'Nothing to commit'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sans(12.5, weight: FontWeight.w600, color: on ? c.text : c.text3),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
        Container(width: 1, color: c.chipBorder),
        Builder(
          builder: (btn) => KPressable(
            onTap: () => showKMenu(
              btn,
              position: belowOf(btn),
              alignRight: true,
              builder: (context, close) => KMenuPanel(width: 220, children: [
                for (final (label, key, how) in const [('Commit & Push', '⇧⌘↩', 'push'), ('Amend last commit', null, 'amend')])
                  KMenuItem(
                    icon: how == 'amend' ? KIcons.rename : KIcons.upload,
                    label: label,
                    shortcut: key,
                    onTap: () {
                      close();
                      onCommit(how);
                    },
                  ),
              ]),
            ),
            semanticLabel: 'More commit options',
            tooltip: 'More commit options',
            builder: (context, hover, focus) => Container(
              width: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hover ? c.tile : null,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
              ),
              child: Icon(KIcons.chevronDown, size: 16, color: c.text2),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ScSection extends StatelessWidget {
  const _ScSection({required this.title, required this.total, required this.files, required this.open, required this.onToggle, required this.empty, this.onViewAll});

  final String title;
  final int total;
  final List<ChangedFile> files;
  final bool open;
  final VoidCallback onToggle;
  final String empty;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: KPressable(
            onTap: onToggle,
            semanticLabel: '$title, $total files, ${open ? 'collapse' : 'expand'}',
            builder: (context, hover, focus) => SizedBox(
              height: 28,
              child: Row(children: [
                Icon(open ? KIcons.chevronDown : KIcons.chevronRight, size: 15, color: c.text2),
                const SizedBox(width: 6),
                Flexible(child: Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: microLabel(c).copyWith(color: hover ? c.text : c.text2))),
                const SizedBox(width: 6),
                Text('$total', style: sans(11, color: c.text3)),
              ]),
            ),
          ),
        ),
        if (onViewAll != null) KButton(label: 'View all', kind: KButtonKind.ghost, height: 24, fontSize: 12, onTap: onViewAll),
      ]),
      if (open) ...[
        for (final f in files) ChangedFileRow(file: f),
        if (files.isEmpty) Padding(padding: const EdgeInsets.fromLTRB(6, 4, 6, 6), child: Text(empty, style: sans(12, color: c.text3))),
      ],
    ]);
  }
}

/// icon · name · folder · +a −d · M/A. Click opens the file tab.
class ChangedFileRow extends StatelessWidget {
  const ChangedFileRow({super.key, required this.file});
  final ChangedFile file;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final col = file.kind == 'A' ? c.ok : c.warn;
    final on = s.activeFile == file.path;
    return KPressable(
      onTap: () => s.openFile(file.path),
      semanticLabel: 'Open ${file.path} with its changes',
      tooltip: file.path,
      selected: on,
      builder: (context, hover, focus) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: on
            ? chipDecoration(c, radius: 8, fill: c.navActive)
            : BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(KIcons.file, size: 14, color: col),
          const SizedBox(width: 7),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: file.name, style: sans(12.5, color: c.text)),
                if (file.writing) TextSpan(text: '  writing…', style: sans(10.5, color: c.acc)),
                TextSpan(text: '  ${file.dir}', style: mono(11, color: c.text3)),
              ]),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text.rich(TextSpan(children: [
            TextSpan(text: '+${file.added} ', style: mono(11, color: c.ok)),
            TextSpan(text: '−${file.deleted}', style: mono(11, color: c.err)),
          ])),
          const SizedBox(width: 6),
          SizedBox(width: 12, child: Text(file.kind, textAlign: TextAlign.center, style: mono(11, weight: FontWeight.w700, color: col))),
        ]),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint, this.autofocus = false});
  final TextEditingController controller;
  final String hint;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.chipBorder)),
      child: Row(children: [
        Icon(KIcons.search, size: 14, color: c.text3),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            style: sans(12.5, color: c.text),
            cursorColor: c.acc,
            decoration: InputDecoration.collapsed(hintText: hint, hintStyle: sans(12.5, color: c.text3)),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Files

class _FilesTab extends StatefulWidget {
  const _FilesTab();

  @override
  State<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<_FilesTab> {
  final Set<String> _open = {'internal', 'internal/discount', 'internal/kafka'};
  bool _changedOnly = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final status = {for (final f in s.pendingChanges) f.path: f.kind};
    final paths = [for (final p in s.changes.files) if (!_changedOnly || status.containsKey(p)) p];
    final root = _Dir('');
    for (final p in paths) {
      final parts = p.split('/');
      var node = root;
      for (var k = 0; k < parts.length - 1; k++) {
        final key = parts.sublist(0, k + 1).join('/');
        node = node.dirs.putIfAbsent(parts[k], () => _Dir(key));
      }
      node.files.add(p);
    }
    final rows = <Widget>[];
    void walk(_Dir node, int depth) {
      for (final name in node.dirs.keys.toList()..sort()) {
        final d = node.dirs[name]!;
        final open = _changedOnly || _open.contains(d.key);
        final inside = status.keys.where((p) => p.startsWith('${d.key}/')).toList();
        final allAdded = inside.isNotEmpty && inside.every((p) => status[p] == 'A');
        final tone = inside.isEmpty ? null : (allAdded ? c.ok : c.warn);
        rows.add(_TreeRow(
          depth: depth,
          icon: KIcons.folder,
          iconColor: c.text3,
          name: name,
          color: tone ?? c.text,
          chevron: open ? KIcons.chevronDown : KIcons.chevronRight,
          dot: !open ? tone : null,
          semantic: '${d.key}/, ${open ? 'collapse' : 'expand'}${inside.isEmpty ? '' : ', ${inside.length} changed'}',
          onTap: () => setState(() => _open.contains(d.key) ? _open.remove(d.key) : _open.add(d.key)),
        ));
        if (open) walk(d, depth + 1);
      }
      final files = [...node.files]..sort((a, b) => a.split('/').last.compareTo(b.split('/').last));
      for (final p in files) {
        final k = status[p];
        final col = k == 'A' ? c.ok : (k == 'M' ? c.warn : null);
        rows.add(_TreeRow(
          depth: depth,
          icon: KIcons.file,
          iconColor: col ?? c.text3,
          name: p.split('/').last,
          color: col ?? c.text,
          kind: k,
          selected: s.activeFile == p,
          semantic: p,
          onTap: () => s.openFile(p),
        ));
      }
    }

    walk(root, 0);
    final pending = s.pendingChanges;
    final added = pending.where((f) => f.kind == 'A').length;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('price-admin', style: mono(12.5, weight: FontWeight.w600, color: c.text)),
            Text('~/wt/price-admin/PRC-412', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3)),
          ]),
        ),
        KPressable(
          onTap: () => setState(() => _changedOnly = !_changedOnly),
          semanticLabel: 'Show only changed files',
          selected: _changedOnly,
          builder: (context, hover, focus) => Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _changedOnly ? c.accSoft : (hover ? c.tile : null),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _changedOnly ? Colors.transparent : c.chipBorder),
            ),
            child: Text('Changed only', style: sans(11.5, weight: FontWeight.w500, color: _changedOnly ? c.acc : c.text2)),
          ),
        ),
        KIconButton(
          icon: KIcons.collapseAll,
          label: 'Collapse all',
          onTap: () => setState(() {
            _open.clear();
            _changedOnly = false;
          }),
        ),
      ]),
      const SizedBox(height: 8),
      ...rows,
      if (rows.isEmpty) Padding(padding: const EdgeInsets.all(6), child: Text('No changed files in this worktree.', style: sans(12, color: c.text3))),
      const SizedBox(height: 8),
      Text(
        pending.isEmpty ? 'Working tree clean' : '${pending.length} changed · $added added, ${pending.length - added} modified',
        style: sans(11.5, color: c.text3),
      ),
    ]);
  }
}

class _Dir {
  _Dir(this.key);
  final String key;
  final Map<String, _Dir> dirs = {};
  final List<String> files = [];
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.depth,
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.color,
    required this.semantic,
    required this.onTap,
    this.chevron,
    this.dot,
    this.kind,
    this.selected = false,
  });

  final int depth;
  final IconData icon;
  final Color iconColor;
  final String name;
  final Color color;
  final String semantic;
  final VoidCallback onTap;
  final IconData? chevron;
  final Color? dot;
  final String? kind;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      semanticLabel: semantic,
      selected: selected,
      builder: (context, hover, focus) => Container(
        height: 26,
        padding: EdgeInsets.only(left: 6.0 + depth * 14, right: 6),
        decoration: selected
            ? chipDecoration(c, radius: 7, fill: c.navActive)
            : BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(7)),
        child: Row(children: [
          SizedBox(width: 14, child: chevron == null ? null : Icon(chevron, size: 14, color: c.text3)),
          const SizedBox(width: 4),
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, color: color))),
          if (dot != null) Dot(dot!, size: 6),
          if (kind != null) SizedBox(width: 12, child: Text(kind!, textAlign: TextAlign.center, style: mono(11, weight: FontWeight.w700, color: color))),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- Widgets

class _WidgetsTab extends StatelessWidget {
  const _WidgetsTab();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.widgets;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ReorderableListView(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
          proxyDecorator: (child, index, animation) => Material(type: MaterialType.transparency, child: child),
          onReorder: s.reorderWidget,
          children: [
            for (var i = 0; i < list.length; i++)
              Padding(
                key: ValueKey(list[i]),
                padding: const EdgeInsets.only(bottom: 10),
                child: _WidgetCard(widgetKind: list[i], index: i, count: list.length),
              ),
          ],
        ),
      ),
      const Padding(padding: EdgeInsets.fromLTRB(10, 0, 10, 10), child: _AddWidgetButton()),
    ]);
  }
}

/// Frame of one inspector widget: hover grip to drag (reorder), right-click
/// for Move up / Move down / Remove.
class _WidgetCard extends StatefulWidget {
  const _WidgetCard({required this.widgetKind, required this.index, required this.count});
  final InspectorWidget widgetKind;
  final int index;
  final int count;

  @override
  State<_WidgetCard> createState() => _WidgetCardState();
}

class _WidgetCardState extends State<_WidgetCard> {
  bool _hover = false;

  void _menu(Offset at) {
    final s = AppScope.read(context);
    final w = widget.widgetKind;
    showKMenu(
      context,
      position: at,
      builder: (context, close) => KMenuPanel(width: 200, children: [
        KMenuItem(
          icon: KIcons.chevronUp,
          label: 'Move up',
          onTap: widget.index == 0
              ? null
              : () {
                  close();
                  s.moveWidget(w, -1);
                },
        ),
        KMenuItem(
          icon: KIcons.chevronDown,
          label: 'Move down',
          onTap: widget.index == widget.count - 1
              ? null
              : () {
                  close();
                  s.moveWidget(w, 1);
                },
        ),
        const KMenuDivider(),
        KMenuItem(
          icon: KIcons.close,
          label: 'Remove widget',
          danger: true,
          onTap: () {
            close();
            s.removeWidget(w);
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onSecondaryTapDown: (d) => _menu(d.globalPosition),
        child: Semantics(
          label: '${widget.widgetKind.label} widget. Right-click for Move up, Move down, Remove',
          child: Stack(children: [
            _widgetBody(widget.widgetKind),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: ReorderableDragStartListener(
                  index: widget.index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Tooltip(
                      message: 'Drag to reorder · right-click for options',
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _hover ? 0.75 : 0,
                        child: Container(
                          width: 44,
                          height: 14,
                          alignment: Alignment.center,
                          child: Container(width: 30, height: 4, decoration: BoxDecoration(color: c.text3, borderRadius: BorderRadius.circular(2))),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

Widget _widgetBody(InspectorWidget w) => switch (w) {
      InspectorWidget.agent => const _AgentWidget(),
      InspectorWidget.changes => const _ChangesWidget(),
      InspectorWidget.context => const _ContextWidget(),
      InspectorWidget.tests => const _TestsWidget(),
      InspectorWidget.pullRequest => const _PrWidget(),
      InspectorWidget.activity => const _ActivityWidget(),
    };

class _AddWidgetButton extends StatelessWidget {
  const _AddWidgetButton();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    return KPressable(
      onTap: () {
        final box = context.findRenderObject() as RenderBox;
        final at = box.localToGlobal(Offset.zero);
        showKMenu(
          context,
          position: at,
          builder: (context, close) => KMenuPanel(width: box.size.width, children: [
            Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 6), child: Text('ADD TO THIS PANEL', style: microLabel(c))),
            for (final w in s.availableWidgets)
              KMenuItem(
                icon: _iconOf(w),
                label: w.label,
                note: w.description,
                onTap: () {
                  close();
                  s.addWidget(w);
                },
              ),
            if (s.availableWidgets.isEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 8), child: Text('Every widget is already on the panel.', style: sans(12, color: c.text3))),
          ]),
        );
      },
      semanticLabel: 'Add widget',
      builder: (context, hover, focus) => Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hover || focus ? c.tile : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.chipBorder, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(KIcons.add, size: 15, color: c.text2),
          const SizedBox(width: 8),
          Text('Add widget', style: sans(12.5, weight: FontWeight.w500, color: c.text2)),
        ]),
      ),
    );
  }
}

IconData _iconOf(InspectorWidget w) => switch (w) {
      InspectorWidget.agent => KIcons.agent,
      InspectorWidget.changes => KIcons.file,
      InspectorWidget.context => KIcons.docs,
      InspectorWidget.tests => KIcons.flask,
      InspectorWidget.pullRequest => KIcons.pullRequest,
      InspectorWidget.activity => KIcons.activity,
    };

class _AgentWidget extends StatelessWidget {
  const _AgentWidget();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    const steps = [('Plan', '4 steps', 2), ('Implement', '3 of 4', 1), ('Test', '', 0), ('Open PR', 'GitHub', 0)];
    final review = s.pendingChanges.isNotEmpty ? s.pendingChanges : s.branchChanges;
    return Section(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(11)),
            child: Icon(KIcons.agent, size: 18, color: c.acc),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Claude Code', style: sans(13, weight: FontWeight.w600, color: c.text)),
              Text('Started 13:54 · auto-approve edits', style: sans(11.5, color: c.text3)),
            ]),
          ),
          KIconButton(icon: KIcons.more, label: 'More agent actions', onTap: () {}),
        ]),
        const SizedBox(height: 14),
        Text('Bulk discounts by category', style: sans(17, weight: FontWeight.w600, color: c.text, letterSpacing: -0.2, height: 1.25)),
        const SizedBox(height: 6),
        Row(children: [
          const TagChip('JI'),
          const SizedBox(width: 6),
          Text('PRC-412', style: mono(12, weight: FontWeight.w500, color: c.text)),
          const SizedBox(width: 6),
          Flexible(child: Text('Jira · Story · Sprint 44', overflow: TextOverflow.ellipsis, style: sans(12, color: c.text3))),
        ]),
        const SizedBox(height: 14),
        for (final (label, meta, st) in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: st == 2 ? c.okSoft : null,
                  border: Border.all(color: st == 2 ? c.ok : (st == 1 ? c.acc : c.chipBorder), width: 1.5),
                ),
                child: st == 2 ? Icon(KIcons.check, size: 12, color: c.ok) : (st == 1 ? Center(child: Dot(c.acc)) : null),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: sans(13, weight: st == 1 ? FontWeight.w600 : FontWeight.w500, color: st == 0 ? c.text3 : c.text))),
              Text(meta, style: sans(11.5, color: c.text3)),
            ]),
          ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: KButton.primary(label: 'Review diff', expand: true, onTap: () => s.openAllFiles(review.map((f) => f.path)))),
          const SizedBox(width: 8),
          KButton(label: s.agentPaused ? 'Resume' : 'Pause', onTap: s.toggleAgentPaused),
        ]),
      ]),
    );
  }
}

class _ChangesWidget extends StatelessWidget {
  const _ChangesWidget();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final files = s.pendingChanges;
    final add = files.fold<int>(0, (n, f) => n + f.added);
    final del = files.fold<int>(0, (n, f) => n + f.deleted);
    return Section(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PanelHeading(
          'Changes',
          trailing: Text.rich(TextSpan(children: [
            TextSpan(text: '+$add ', style: mono(11.5, color: c.ok)),
            TextSpan(text: '−$del', style: mono(11.5, color: c.err)),
          ])),
        ),
        const SizedBox(height: 2),
        Text('${files.length} uncommitted · feat/PRC-412-bulk-discounts', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3)),
        const SizedBox(height: 8),
        for (final f in files) ChangedFileRow(file: f),
        if (files.isEmpty) Text('Working tree clean.', style: sans(12, color: c.text3)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: KButton(
              label: 'Review all in tabs',
              height: 30,
              fontSize: 12,
              expand: true,
              onTap: files.isEmpty ? null : () => s.openAllFiles(files.map((f) => f.path)),
            ),
          ),
          const SizedBox(width: 8),
          KButton(label: 'Commit…', height: 30, fontSize: 12, onTap: () => s.showSidePanelTab(SidePanelTab.git)),
        ]),
      ]),
    );
  }
}

class _ContextWidget extends StatelessWidget {
  const _ContextWidget();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const items = [('JI', 'PRC-412 · Bulk discounts by category', 'Jira · ticket + 3 comments'), ('CF', 'Discount rules v3', 'Confluence · Pricing space'), ('NO', 'ADR-014 · Kafka topic naming', 'Notion · Eng handbook')];
    return Section(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PanelHeading('Context sent to agent', trailing: KIconButton(icon: KIcons.add, label: 'Add context', size: 24, iconSize: 14, onTap: () {})),
        const SizedBox(height: 8),
        for (final (k, title, src) in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SourceTile(k),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, color: c.text)),
                  Text(src, style: sans(11, color: c.text3)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _TestsWidget extends StatelessWidget {
  const _TestsWidget();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const pkgs = [('internal/discount', '412ms'), ('internal/http', '1.21s'), ('internal/kafka', '838ms'), ('internal/store/pg', '2.04s')];
    return Section(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(KIcons.flask, size: 15, color: c.ok),
          const SizedBox(width: 8),
          Expanded(child: Text('Tests', style: sans(12.5, weight: FontWeight.w600, color: c.text))),
          Text('148 passed', style: sans(11.5, weight: FontWeight.w600, color: c.ok)),
          Text(' · 3.1s', style: sans(11.5, color: c.text3)),
        ]),
        const SizedBox(height: 8),
        for (final (pkg, t) in pkgs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Text('✓ ', style: mono(11.5, color: c.ok)),
              Expanded(child: Text(pkg, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, color: c.text2))),
              Text(t, style: mono(11.5, color: c.text3)),
            ]),
          ),
        const SizedBox(height: 6),
        Text('gotestsum --watch · re-runs on save', style: sans(11.5, color: c.text3)),
      ]),
    );
  }
}

class _PrWidget extends StatelessWidget {
  const _PrWidget();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final checks = [('build', 'passed', c.ok), ('golangci-lint', 'passed', c.ok), ('test · integration', 'running', c.acc)];
    return Section(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(KIcons.pullRequest, size: 15, color: c.acc),
          const SizedBox(width: 8),
          Expanded(child: Text('Pull request', style: sans(12.5, weight: FontWeight.w600, color: c.text))),
          TagChip('Draft', color: c.text2),
        ]),
        const SizedBox(height: 8),
        Text.rich(TextSpan(children: [
          TextSpan(text: '#521 ', style: mono(12, color: c.text3)),
          TextSpan(text: 'feat: bulk discounts by category', style: sans(12.5, weight: FontWeight.w500, color: c.text)),
        ])),
        Text('GitHub · into main · Lucía requested as reviewer', style: sans(11.5, color: c.text3)),
        const SizedBox(height: 8),
        for (final (name, state, col) in checks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Dot(col),
              const SizedBox(width: 8),
              Expanded(child: Text(name, style: mono(11.5, color: c.text2))),
              Text(state, style: sans(11.5, color: col)),
            ]),
          ),
        const SizedBox(height: 8),
        KButton(label: 'Open in Git', height: 30, fontSize: 12, expand: true, onTap: () => s.view = KumoView.git),
      ]),
    );
  }
}

class _ActivityWidget extends StatelessWidget {
  const _ActivityWidget();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final events = [
      ('14:05', 'Editing internal/kafka/bulk_consumer.go', c.acc),
      ('14:03', 'go test ./internal/discount/... passed', c.ok),
      ('13:58', 'Read Confluence › Discount rules v3', c.text3),
      ('13:54', 'Started from Jira PRC-412', c.text3),
    ];
    return Section(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(KIcons.activity, size: 15, color: c.acc),
          const SizedBox(width: 8),
          Expanded(child: Text('Activity', style: sans(12.5, weight: FontWeight.w600, color: c.text))),
          Text('Claude · PRC-412', style: sans(11.5, color: c.text3)),
        ]),
        const SizedBox(height: 10),
        for (final (t, text, col) in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 38, child: Text(t, style: mono(11, color: c.text3))),
              Padding(padding: const EdgeInsets.only(top: 5), child: Dot(col)),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: sans(12, color: c.text2))),
            ]),
          ),
      ]),
    );
  }
}
