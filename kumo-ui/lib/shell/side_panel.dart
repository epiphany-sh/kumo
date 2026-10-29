import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/agents_source.dart';
import '../data/changes.dart';
import '../data/docs_source.dart';
import '../data/models.dart';
import '../data/pipelines_source.dart';
import '../data/pull_requests_source.dart';
import '../data/repo_activity.dart';
import '../data/tasks_source.dart';
import '../data/tests_source.dart';
import '../overlays/new_agent_dialog.dart';
import '../overlays/settings_dialog.dart';
import '../platform/open_url.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/context_menu.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';
import 'screen_chrome.dart';

/// Panel beside the Terminal view's tabs, for the current worktree:
/// compact source control (stage, discard, commit), its files, or the
/// inspector widgets (agent, pipelines, changes…). The header's Files / Git
/// tabs have the full views. ⌥⌘B hides / shows it.
class SidePanel extends StatelessWidget {
  const SidePanel({super.key});

  static const _icons = {SidePanelTab.git: KIcons.branch, SidePanelTab.files: KIcons.files, SidePanelTab.widgets: KIcons.widgets};

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final tab = s.sidePanelTab;
    return GlassPanel(
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 46,
          padding: const EdgeInsets.only(left: 8, right: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final t in SidePanelTab.values)
                  KPressable(
                    onTap: () => s.showSidePanelTab(t),
                    semanticLabel: t.label,
                    tooltip: t.label,
                    selected: t == tab,
                    builder: (context, hover, focus) => AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 30,
                      height: 26,
                      decoration: t == tab ? chipDecoration(c, radius: 8, fill: c.tabActive) : BoxDecoration(borderRadius: BorderRadius.circular(8)),
                      child: Icon(_icons[t], size: 15, color: t == tab || hover ? c.text : c.text3),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: FontWeight.w600, color: c.text))),
            KIconButton(icon: KIcons.sidePanel, label: 'Hide side panel (⌥⌘B)', onTap: s.toggleSidePanel),
          ]),
        ),
        Expanded(
          child: switch (tab) {
            SidePanelTab.git => const SourceControlPanel(compact: true),
            SidePanelTab.files => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: WorktreeFilesTree(
                    selected: s.contextFile,
                    // A file opens in the Files tab, where it can be edited.
                    onOpen: (p) {
                      s.openContext(ContextTab.files);
                      s.showContextFile(p);
                    },
                  ),
                ),
                _PanelFooter(label: 'Open Files tab', tooltip: 'The tree with open files, editing and diffs', onTap: () => s.openContext(ContextTab.files)),
              ]),
            SidePanelTab.widgets => const _WidgetsTab(),
          },
        ),
      ]),
    );
  }
}

/// "Open … tab ↗" at the bottom of a compact side panel view.
class _PanelFooter extends StatelessWidget {
  const _PanelFooter({required this.label, required this.tooltip, required this.onTap, this.summary});
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
      child: Row(children: [
        Expanded(child: Text(summary ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3))),
        KPressable(
          onTap: onTap,
          semanticLabel: label,
          tooltip: tooltip,
          builder: (context, hover, focus) => Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: hover || focus ? c.accSoft : null, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: sans(12, weight: FontWeight.w500, color: c.acc)),
              const SizedBox(width: 5),
              Icon(KIcons.external, size: 12, color: c.acc),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Source control

/// Source control of the current worktree: branch, commit box, actions and
/// the changed files. In the Git context tab it also lists what's committed
/// on the branch; [compact] (the side panel) keeps to staging, discarding
/// and committing, with a way to the Git tab.
class SourceControlPanel extends StatefulWidget {
  const SourceControlPanel({super.key, this.compact = false});
  final bool compact;

  @override
  State<SourceControlPanel> createState() => _SourceControlPanelState();
}

class _SourceControlPanelState extends State<SourceControlPanel> {
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
    // Like VS Code: what is staged, or every change when nothing is.
    final staged = s.pendingChanges.any((f) => s.changes.stagedList.contains(f.path));
    if (s.commit(_msg.text, how: how, all: !staged)) {
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
    final staged = [for (final f in pending) if (git.stagedList.contains(f.path)) f];
    final unstaged = [
      for (final f in pending)
        if (!git.stagedList.contains(f.path) || git.unstagedChanges.contains(f.path) || git.untracked.contains(f.path)) f,
    ];
    final ahead = git.ahead;
    final base = git.base.isEmpty ? 'its base' : git.base;
    final compact = widget.compact;
    final paths = [for (final f in unstaged) f.path];

    final list = ListView(padding: EdgeInsets.fromLTRB(14, 12, 14, compact ? 10 : 14), children: [
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
        if (compact)
          Tooltip(
            message: '$ahead to push · ${git.behind} to pull${git.pushed ? '' : ' · not published yet'}',
            child: Text('↑$ahead ↓${git.behind}', style: mono(11.5, color: c.text3)),
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
                if (widget.compact)
                  KMenuItem(
                    icon: KIcons.external,
                    label: 'Open the Git tab',
                    onTap: () {
                      close();
                      s.openContext(ContextTab.git);
                    },
                  )
                else
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
      if (git.base.isNotEmpty && !compact) ...[
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
            constraints: BoxConstraints(minHeight: compact ? 58 : 78),
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
                minLines: compact ? 2 : 3,
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
        // Says what the commit takes: the staged files, or every change.
        label: !compact ? 'Commit' : (staged.isNotEmpty ? 'Commit ${staged.length} staged' : 'Commit all ${pending.length}'),
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
      if (staged.isNotEmpty) ...[
        _ScSection(
          title: 'Staged',
          total: staged.length,
          files: staged.where(match).toList(),
          open: !_collapsed.contains('staged'),
          onToggle: () => setState(() => _collapsed.contains('staged') ? _collapsed.remove('staged') : _collapsed.add('staged')),
          empty: 'No files match “$q”.',
          staged: true,
          actions: [
            KIconButton(icon: KIcons.remove, label: 'Unstage all', size: 24, iconSize: 14, onTap: () => git.unstage([for (final f in staged) f.path])),
          ],
        ),
        const SizedBox(height: 6),
      ],
      _ScSection(
        title: 'Changes',
        total: unstaged.length,
        files: unstaged.where(match).toList(),
        open: !_collapsed.contains('changes'),
        onToggle: () => setState(() => _collapsed.contains('changes') ? _collapsed.remove('changes') : _collapsed.add('changes')),
        empty: q.isNotEmpty && unstaged.isNotEmpty
            ? 'No files match “$q”.'
            : (staged.isNotEmpty ? 'Everything is staged.' : (s.commitNotice != null ? 'Nothing to commit. Working tree clean.' : 'No changes.')),
        staged: false,
        actions: [
          if (paths.length > 1) KIconButton(icon: KIcons.discard, label: 'Discard all changes', size: 24, iconSize: 13, onTap: () => s.discardPaths(paths)),
          if (paths.isNotEmpty) KIconButton(icon: KIcons.add, label: 'Stage all', size: 24, iconSize: 15, onTap: () => git.stage(paths)),
        ],
      ),
      if (!compact) ...[
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
      ],
    ]);
    if (!compact) return list;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: list),
      _PanelFooter(
        summary: pending.isEmpty ? 'Working tree clean' : '${staged.length} of ${pending.length} staged',
        label: 'Open Git tab',
        tooltip: 'Commits, pull request and pipelines of this branch',
        onTap: () => s.openContext(ContextTab.git),
      ),
    ]);
  }
}

/// Commit button with a ⌄ menu: Commit & Push, Amend. With nothing to
/// commit and commits to push, it pushes ([push] is its label).
class _CommitButton extends StatelessWidget {
  const _CommitButton({required this.enabled, required this.onCommit, this.push, required this.onPush, this.label = 'Commit'});
  final bool enabled;
  final String label;
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
            semanticLabel: enabled ? label : (push ?? 'Nothing to commit'),
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
                      enabled ? label : (push ?? 'Nothing to commit'),
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
  const _ScSection({required this.title, required this.total, required this.files, required this.open, required this.onToggle, required this.empty, this.onViewAll, this.staged, this.actions = const []});

  /// Buttons for the whole section (Stage all, Discard all…).
  final List<Widget> actions;

  final String title;
  final int total;
  final List<ChangedFile> files;
  final bool open;
  final VoidCallback onToggle;
  final String empty;
  final VoidCallback? onViewAll;

  /// Uncommitted files get stage / unstage and discard: true for the staged
  /// ones, false for the rest, null for committed ones (no actions).
  final bool? staged;

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
        ...actions,
        if (onViewAll != null) KButton(label: 'View all', kind: KButtonKind.ghost, height: 24, fontSize: 12, onTap: onViewAll),
      ]),
      if (open) ...[
        for (final f in files) ChangedFileRow(file: f, staged: staged),
        if (files.isEmpty) Padding(padding: const EdgeInsets.fromLTRB(6, 4, 6, 6), child: Text(empty, style: sans(12, color: c.text3))),
      ],
    ]);
  }
}

/// icon · name · folder · +a −d · M/A. Click opens the file tab. With
/// [staged] set (uncommitted files), hovering shows discard and stage /
/// unstage.
class ChangedFileRow extends StatelessWidget {
  const ChangedFileRow({super.key, required this.file, this.staged});
  final ChangedFile file;
  final bool? staged;

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
          if (staged != null && (hover || focus)) ...[
            KIconButton(
              icon: KIcons.discard,
              label: file.kind == 'U' ? 'Delete ${file.name}' : 'Discard changes to ${file.name}',
              size: 22,
              iconSize: 13,
              onTap: () => s.discardChanges(file.path),
            ),
            KIconButton(
              icon: staged! ? KIcons.remove : KIcons.add,
              label: '${staged! ? 'Unstage' : 'Stage'} ${file.name}',
              size: 22,
              iconSize: 14,
              onTap: () => staged! ? s.changes.unstage([file.path]) : s.changes.stage([file.path]),
            ),
          ] else
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

/// The current worktree's folder tree with each file's change (M / A).
/// Tapping a file calls [onOpen]; [selected] is highlighted.
class WorktreeFilesTree extends StatefulWidget {
  const WorktreeFilesTree({super.key, required this.onOpen, this.selected});
  final ValueChanged<String> onOpen;
  final String? selected;

  @override
  State<WorktreeFilesTree> createState() => _WorktreeFilesTreeState();
}

class _WorktreeFilesTreeState extends State<WorktreeFilesTree> {
  final Set<String> _open = {'internal', 'internal/discount', 'internal/kafka'};
  bool _changedOnly = false;

  /// The row whose menu is open, the one being renamed, and the folder a
  /// new file is being named in ('' is the worktree's root).
  String? _menuFor;
  String? _renaming;
  String? _creatingIn;
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  String? _nameError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Clicking elsewhere gives up, like Esc.
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && !_busy) _stopNaming();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  static String _dirOf(String? path) => path == null || !path.contains('/') ? '' : path.substring(0, path.lastIndexOf('/'));

  void _focusName() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameFocus.requestFocus();
      });

  void _stopNaming() {
    if (_renaming == null && _creatingIn == null) return;
    setState(() {
      _renaming = null;
      _creatingIn = null;
      _nameError = null;
    });
  }

  /// The name is selected without its extension, ready to type over.
  void _startRename(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    _name.value = TextEditingValue(text: name, selection: TextSelection(baseOffset: 0, extentOffset: dot > 0 ? dot : name.length));
    setState(() {
      _renaming = path;
      _creatingIn = null;
      _nameError = null;
    });
    _focusName();
  }

  void _startCreate(String dir) {
    _name.clear();
    setState(() {
      _changedOnly = false; // its folder may be hidden
      _creatingIn = dir;
      _renaming = null;
      _nameError = null;
      if (dir.isNotEmpty) _openUpTo(dir);
    });
    _focusName();
  }

  void _openUpTo(String dir) {
    final parts = dir.split('/');
    for (var i = 1; i <= parts.length; i++) {
      _open.add(parts.sublist(0, i).join('/'));
    }
  }

  /// ↩ in the name field: renames, or creates the file and opens it.
  Future<void> _submitName() async {
    final s = AppScope.read(context);
    final raw = _name.text.trim();
    if (raw.isEmpty) {
      _stopNaming();
      return;
    }
    _busy = true;
    String? error;
    final renaming = _renaming;
    if (renaming != null) {
      final parent = _dirOf(renaming);
      final to = AppState.cleanPath(parent.isEmpty ? raw : '$parent/$raw');
      error = await s.movePath(renaming, to);
      if (error == null) {
        // Open folders keep showing under their new name.
        final moved = [for (final k in _open) if (k == renaming || k.startsWith('$renaming/')) k];
        _open
          ..removeAll(moved)
          ..addAll([for (final k in moved) to + k.substring(renaming.length)]);
      }
    } else {
      final dir = _creatingIn ?? '';
      final path = AppState.cleanPath(dir.isEmpty ? raw : '$dir/$raw');
      error = await s.createFile(path);
      if (error == null) {
        _openUpTo(_dirOf(path));
        widget.onOpen(path);
      }
    }
    _busy = false;
    if (!mounted) return;
    if (error != null) {
      setState(() => _nameError = error);
      _nameFocus.requestFocus();
      return;
    }
    setState(() {
      _renaming = null;
      _creatingIn = null;
      _nameError = null;
    });
  }

  void _menu(Offset at, String path, {required bool dir}) {
    setState(() => _menuFor = path);
    showKMenu(
      context,
      position: at,
      onClosed: () {
        if (mounted) setState(() => _menuFor = null);
      },
      builder: (context, close) => _FileTreeMenu(
        path: path,
        dir: dir,
        close: close,
        onOpen: dir ? null : () => widget.onOpen(path),
        onNewFile: () => _startCreate(path),
        onRename: () => _startRename(path),
      ),
    );
  }

  Widget _field(int depth, IconData icon, {required String hint}) => _NameField(
        key: const ValueKey('tree-name-field'),
        depth: depth,
        icon: icon,
        controller: _name,
        focus: _nameFocus,
        hint: hint,
        error: _nameError,
        onSubmit: _submitName,
        onCancel: _stopNaming,
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final status = {for (final f in s.pendingChanges) f.path: f.kind};
    final paths = [for (final p in s.visibleFiles) if (!_changedOnly || status.containsKey(p)) p];
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
    const newHint = 'name.ext — a/b.ext makes folders';
    final rows = <Widget>[];
    void walk(_Dir node, int depth) {
      for (final name in node.dirs.keys.toList()..sort()) {
        final d = node.dirs[name]!;
        final open = _changedOnly || _open.contains(d.key);
        final inside = status.keys.where((p) => p.startsWith('${d.key}/')).toList();
        final allAdded = inside.isNotEmpty && inside.every((p) => status[p] == 'A');
        final tone = inside.isEmpty ? null : (allAdded ? c.ok : c.warn);
        if (_renaming == d.key) {
          rows.add(_field(depth, KIcons.folder, hint: 'Folder name'));
        } else {
          rows.add(_TreeRow(
            key: ValueKey('dir:${d.key}'),
            depth: depth,
            icon: KIcons.folder,
            iconColor: c.text3,
            name: name,
            color: tone ?? c.text,
            chevron: open ? KIcons.chevronDown : KIcons.chevronRight,
            dot: !open ? tone : null,
            highlight: _menuFor == d.key,
            semantic: '${d.key}/, ${open ? 'collapse' : 'expand'}${inside.isEmpty ? '' : ', ${inside.length} changed'}',
            onTap: () => setState(() => _open.contains(d.key) ? _open.remove(d.key) : _open.add(d.key)),
            onMenu: (at) => _menu(at, d.key, dir: true),
          ));
        }
        if (open && _creatingIn == d.key) rows.add(_field(depth + 1, KIcons.file, hint: newHint));
        if (open) walk(d, depth + 1);
      }
      final files = [...node.files]..sort((a, b) => a.split('/').last.compareTo(b.split('/').last));
      for (final p in files) {
        if (_renaming == p) {
          rows.add(_field(depth, KIcons.file, hint: 'File name'));
          continue;
        }
        final k = status[p];
        final col = k == 'A' ? c.ok : (k == 'M' ? c.warn : null);
        rows.add(_TreeRow(
          key: ValueKey('file:$p'),
          depth: depth,
          icon: KIcons.file,
          iconColor: col ?? c.text3,
          name: p.split('/').last,
          color: col ?? c.text,
          kind: k,
          selected: widget.selected == p,
          highlight: _menuFor == p,
          semantic: p,
          onTap: () => widget.onOpen(p),
          onMenu: (at) => _menu(at, p, dir: false),
        ));
      }
    }

    if (_creatingIn == '') rows.add(_field(0, KIcons.file, hint: newHint));
    walk(root, 0);
    final pending = s.pendingChanges;
    final added = pending.where((f) => f.kind == 'A').length;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.activeRepo?.name ?? 'No repository', style: mono(12.5, weight: FontWeight.w600, color: c.text)),
            Text(s.activeWorktreeEntry?.path ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3)),
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
          icon: KIcons.fileAdd,
          label: 'New file (or right-click a folder)',
          onTap: () => _startCreate(_dirOf(widget.selected)),
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

/// Right-click on a file or folder of the Files tree.
class _FileTreeMenu extends StatelessWidget {
  const _FileTreeMenu({required this.path, required this.dir, required this.close, required this.onNewFile, required this.onRename, this.onOpen});
  final String path;
  final bool dir;
  final VoidCallback close;
  final VoidCallback? onOpen;
  final VoidCallback onNewFile;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    void then(VoidCallback f) {
      close();
      f();
    }

    final changed = [for (final f in s.pendingChanges) if (dir ? f.path.startsWith('$path/') : f.path == path) f.path];
    final n = changed.length;
    final discardLabel = dir && n > 0 ? 'Discard $n ${n == 1 ? 'change' : 'changes'}' : 'Discard changes';
    return KMenuPanel(width: 248, children: [
      if (dir) KMenuItem(icon: KIcons.fileAdd, label: 'New file…', onTap: () => then(onNewFile)),
      if (onOpen != null) KMenuItem(icon: KIcons.file, label: 'Open', onTap: () => then(onOpen!)),
      KMenuItem(icon: KIcons.rename, label: 'Rename…', onTap: () => then(onRename)),
      KMenuItem(
        icon: KIcons.discard,
        label: discardLabel,
        note: n == 0 ? (dir ? 'Nothing changed in this folder' : 'This file has no changes') : null,
        onTap: n == 0 ? null : () => then(() => dir ? s.discardChangesIn(path) : s.discardChanges(path)),
      ),
      KMenuItem(icon: KIcons.copy, label: 'Copy path', onTap: () => then(() => Clipboard.setData(ClipboardData(text: path)))),
      const KMenuDivider(),
      KMenuItem(icon: KIcons.trash, label: dir ? 'Delete folder' : 'Delete', danger: true, onTap: () => then(() => s.deletePath(path))),
    ]);
  }
}

/// Inline name field of the Files tree: ↩ confirms, Esc or a click
/// elsewhere gives up.
class _NameField extends StatelessWidget {
  const _NameField({
    super.key,
    required this.depth,
    required this.icon,
    required this.controller,
    required this.focus,
    required this.hint,
    required this.onSubmit,
    required this.onCancel,
    this.error,
  });

  final int depth;
  final IconData icon;
  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.only(left: 6.0 + depth * 14 + 18, right: 2, top: 1, bottom: 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(7), border: Border.all(color: error == null ? c.acc : c.err)),
          child: Row(children: [
            Icon(icon, size: 14, color: c.text3),
            const SizedBox(width: 6),
            Expanded(
              child: CallbackShortcuts(
                bindings: {const SingleActivator(LogicalKeyboardKey.escape): onCancel},
                child: TextField(
                  key: const ValueKey('tree-name'),
                  controller: controller,
                  focusNode: focus,
                  onSubmitted: (_) => onSubmit(),
                  style: sans(12.5, color: c.text),
                  cursorColor: c.acc,
                  decoration: InputDecoration.collapsed(hintText: hint, hintStyle: sans(12.5, color: c.text3)),
                ),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 3, left: 2),
          child: Text(error ?? '↩ to confirm · Esc cancels', style: sans(11, color: error == null ? c.text3 : c.err)),
        ),
      ]),
    );
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
    super.key,
    required this.depth,
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.color,
    required this.semantic,
    required this.onTap,
    this.onMenu,
    this.chevron,
    this.dot,
    this.kind,
    this.selected = false,
    this.highlight = false,
  });

  final int depth;
  final IconData icon;
  final Color iconColor;
  final String name;
  final Color color;
  final String semantic;
  final VoidCallback onTap;

  /// Right-click, at the click's global position.
  final ValueChanged<Offset>? onMenu;
  final IconData? chevron;
  final Color? dot;
  final String? kind;
  final bool selected;

  /// Its menu is open.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onSecondaryTapDown: onMenu == null ? null : (d) => onMenu!(d.globalPosition),
      child: KPressable(
        onTap: onTap,
        semanticLabel: semantic,
        selected: selected,
        builder: (context, hover, focus) => Container(
          height: 26,
          padding: EdgeInsets.only(left: 6.0 + depth * 14, right: 6),
          decoration: selected
              ? chipDecoration(c, radius: 7, fill: c.navActive)
              : BoxDecoration(color: hover || focus || highlight ? c.tile : null, borderRadius: BorderRadius.circular(7)),
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
      InspectorWidget.pipelines => const PipelinesCard(),
      InspectorWidget.tests => const _TestsWidget(),
      InspectorWidget.pullRequest => const PullRequestCard(),
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
      InspectorWidget.pipelines => KIcons.cluster,
      InspectorWidget.tests => KIcons.flask,
      InspectorWidget.pullRequest => KIcons.pullRequest,
      InspectorWidget.activity => KIcons.activity,
    };

/// The selected worktree's agent: how it's doing, what it's working on and
/// how much it did, with its diff and terminal one click away.
class _AgentWidget extends StatelessWidget {
  const _AgentWidget();

  void _menu(BuildContext context, AgentRun run) {
    final s = AppScope.read(context);
    final box = context.findRenderObject() as RenderBox;
    showKMenu(
      context,
      position: box.localToGlobal(box.size.bottomRight(Offset.zero)) - const Offset(200, 0),
      builder: (context, close) => KMenuPanel(width: 200, children: [
        KMenuItem(
          icon: KIcons.terminal,
          label: 'Open terminal',
          onTap: () {
            close();
            s.openTerminal(run.terminalId, title: run.title, agent: true, directory: run.worktreePath);
          },
        ),
        KMenuItem(
          icon: KIcons.agent,
          label: 'New agent…',
          onTap: () {
            close();
            showNewAgentDialog(context);
          },
        ),
        const KMenuDivider(),
        if (run.status == AgentStatus.done)
          KMenuItem(
            icon: KIcons.close,
            label: 'Dismiss',
            onTap: () {
              close();
              s.agents.dismiss(run.id);
            },
          )
        else
          KMenuItem(
            icon: KIcons.close,
            label: 'Stop agent',
            danger: true,
            onTap: () {
              close();
              s.agents.stop(run.id);
            },
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final runs = s.worktreeAgents;
    final run = s.activeAgent ?? runs.firstOrNull;
    if (run == null) {
      return Section(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PanelHeading('Agent'),
          const SizedBox(height: 4),
          Text('No agent in this worktree yet. Start one with a prompt, or from a task.', style: sans(12, color: c.text3, height: 1.4)),
          const SizedBox(height: 10),
          KButton.primary(label: 'New agent', icon: KIcons.agent, height: 30, fontSize: 12, expand: true, onTap: () => showNewAgentDialog(context)),
        ]),
      );
    }
    final (state, color) = switch (run.status) {
      AgentStatus.running => ('Working', c.acc),
      AgentStatus.needsYou => ('Your turn', c.warn),
      AgentStatus.done => run.exitCode == 0 ? ('Finished', c.text3) : ('Exited with code ${run.exitCode}', c.err),
    };
    final task = run.context.where((i) => i.kind == AgentContextKind.task).firstOrNull;
    final done = _stepCounts(run.steps);
    final review = s.pendingChanges.isNotEmpty ? s.pendingChanges : s.branchChanges;
    final others = runs.length - 1;
    return Section(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SourceTile(run.short, size: 34, tooltip: run.providerName),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(run.providerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13, weight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 2),
              Row(children: [
                Dot(color),
                const SizedBox(width: 6),
                Flexible(child: Text('$state · started ${_clock(run.startedAt)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3))),
              ]),
            ]),
          ),
          Builder(builder: (context) => KIconButton(icon: KIcons.more, label: 'More agent actions', onTap: () => _menu(context, run))),
        ]),
        const SizedBox(height: 12),
        Text(run.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(15, weight: FontWeight.w600, color: c.text, letterSpacing: -0.2, height: 1.25)),
        if (task != null && task.detail.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(task.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text3)),
        ],
        if (run.lastLine.isNotEmpty && run.status != AgentStatus.done) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(8)),
            child: Text(run.lastLine, maxLines: 2, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text2, height: 1.4)),
          ),
        ],
        if (done.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(done, style: sans(11.5, color: c.text3)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: KButton.primary(
              label: 'Review diff',
              height: 30,
              fontSize: 12,
              expand: true,
              onTap: review.isEmpty ? null : () => s.openAllFiles(review.map((f) => f.path)),
            ),
          ),
          const SizedBox(width: 8),
          KButton(
            label: 'Terminal',
            icon: KIcons.terminal,
            height: 30,
            fontSize: 12,
            onTap: () => s.openTerminal(run.terminalId, title: run.title, agent: true, directory: run.worktreePath),
          ),
        ]),
        if (others > 0) ...[
          const SizedBox(height: 8),
          KPressable(
            onTap: () => s.view = KumoView.agents,
            semanticLabel: 'See every agent',
            builder: (context, hover, focus) => Text(
              others == 1 ? '1 more agent in this worktree' : '$others more agents in this worktree',
              style: sans(11.5, color: hover || focus ? c.acc : c.text3),
            ),
          ),
        ],
      ]),
    );
  }
}

/// "4 edits · 6 commands · 9 reads".
String _stepCounts(List<AgentStep> steps) {
  int count(bool Function(AgentStep) test) => steps.where(test).length;
  final edits = {for (final s in steps) if (s.kind == AgentStepKind.edited) s.text}.length;
  final runs = count((s) => s.kind == AgentStepKind.ran);
  final reads = count((s) => s.kind == AgentStepKind.read || s.kind == AgentStepKind.searched);
  return [
    if (edits > 0) edits == 1 ? '1 file edited' : '$edits files edited',
    if (runs > 0) runs == 1 ? '1 command' : '$runs commands',
    if (reads > 0) reads == 1 ? '1 look-up' : '$reads look-ups',
  ].join(' · ');
}

String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _ChangesWidget extends StatelessWidget {
  const _ChangesWidget();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final files = s.pendingChanges;
    final others = s.otherChangedWorktrees;
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
        Text('${files.length} uncommitted · ${s.changes.branch}', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3)),
        const SizedBox(height: 8),
        for (final f in files) ChangedFileRow(file: f),
        if (files.isEmpty) Text('Working tree clean.', style: sans(12, color: c.text3)),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('In other worktrees', style: sans(11, weight: FontWeight.w600, color: c.text3, letterSpacing: 0.2)),
          const SizedBox(height: 4),
          for (final (repo, w) in others) _OtherWorktreeRow(repo: repo, worktree: w),
        ],
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
          KButton(label: 'Commit…', height: 30, fontSize: 12, onTap: () => s.openContext(ContextTab.git)),
        ]),
      ]),
    );
  }
}

/// A worktree with uncommitted files that isn't the selected one; a click
/// switches to it.
class _OtherWorktreeRow extends StatelessWidget {
  const _OtherWorktreeRow({required this.repo, required this.worktree});
  final Repo repo;
  final Worktree worktree;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    final c = context.c;
    final w = worktree;
    final arrived = s.workspace.arrived.contains(w.path);
    return KPressable(
      onTap: () => s.selectWorktree(w.branch, path: w.path),
      semanticLabel: 'Open ${w.branch} in ${repo.name}, ${w.changed} changed',
      tooltip: s.workspace.absolutePathOf(w),
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(7)),
        child: Row(children: [
          Dot(arrived ? c.ok : c.warn),
          const SizedBox(width: 8),
          Flexible(child: Text(w.branch, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, color: c.text))),
          const SizedBox(width: 6),
          Expanded(child: Text('${repo.name} · ${w.changed} changed', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3))),
        ]),
      ),
    );
  }
}

/// What the worktree's agent works from: the tickets and pages it was
/// given, and tickets linked to the worktree it wasn't sent yet. "+" sends
/// one to the running agent, or goes to Docs for a page.
class _ContextWidget extends StatelessWidget {
  const _ContextWidget();

  void _add(BuildContext context, AgentRun? agent, List<(TaskEntry, AgentContextItem)> unsent) {
    final s = AppScope.read(context);
    final box = context.findRenderObject() as RenderBox;
    showKMenu(
      context,
      position: box.localToGlobal(box.size.bottomRight(Offset.zero)) - const Offset(240, 0),
      builder: (context, close) => KMenuPanel(width: 240, children: [
        for (final (task, item) in unsent)
          KMenuItem(
            icon: KIcons.tasks,
            label: 'Send ${task.key}',
            note: agent == null ? 'No agent running here' : task.title,
            onTap: agent == null
                ? null
                : () {
                    close();
                    s.agents.addContext(agent.id, item, text: AppState.taskPrompt(task, detail: s.tasks.cachedDetail(task.id)));
                  },
          ),
        KMenuItem(
          icon: KIcons.docs,
          label: 'Pick a page in Docs…',
          onTap: () {
            close();
            s.view = KumoView.docs;
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final agent = s.activeAgent;
    final sent = (agent ?? s.worktreeAgents.firstOrNull)?.context ?? const <AgentContextItem>[];
    final unsent = [
      for (final task in s.worktreeTasks)
        if (s.taskContext(task) case final item when !sent.any((i) => i.title == item.title)) (task, item),
    ];
    final rows = [for (final item in sent) (item, true), for (final (_, item) in unsent) (item, false)];
    return Section(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PanelHeading(
          'Context',
          trailing: Builder(
            builder: (context) => KIconButton(icon: KIcons.add, label: 'Send context to the agent', size: 24, iconSize: 14, onTap: () => _add(context, agent, unsent)),
          ),
        ),
        const SizedBox(height: 6),
        if (rows.isEmpty) Text('Tickets linked to this worktree and pages sent to its agent show here.', style: sans(12, color: c.text3, height: 1.4)),
        for (final (item, given) in rows)
          KPressable(
            onTap: item.url.isEmpty ? null : () => openUrl(item.url),
            semanticLabel: item.title,
            builder: (context, hover, focus) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SourceTile(_contextBadge(item), tooltip: item.detail.isEmpty ? null : item.detail),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, color: hover || focus ? c.acc : c.text)),
                    Text(
                      given ? item.detail : 'Linked · not sent to the agent',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sans(11, color: c.text3),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Two letters for where [item] lives ("Jira · Story" → JI).
String _contextBadge(AgentContextItem item) {
  final from = item.detail.split(' · ').first;
  for (final kind in TaskSourceKind.values) {
    if (kind.label == from) return kind.badge;
  }
  for (final kind in DocKind.values) {
    if (kind.label == from) return kind.badge;
  }
  return item.kind == AgentContextKind.doc ? 'DC' : 'TK';
}

/// CI runs of the selected worktree's branch, from its repository's host
/// (GitHub Actions, GitLab CI, Bitbucket Pipelines). Problems — a token
/// without access, an expired one, an outage — read as plain sentences with
/// the fix one click away; the provider's own words show small underneath.
class PipelinesCard extends StatelessWidget {
  const PipelinesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final p = s.pipelines;
    final provider = p.provider;
    final run = p.latest;
    final problem = p.problem;
    final stale = problem != null && problem.keepsLastRun;
    final (pill, pillColor, pillBg) = switch (run?.state) {
      _ when stale => ('Stale', c.warn, c.warnSoft),
      CiState.running => ('Running', c.acc, c.accSoft),
      CiState.queued => ('Queued', c.text2, c.tile),
      CiState.passed => ('Passed', c.ok, c.okSoft),
      CiState.failed => ('Failed', c.err, c.errSoft),
      CiState.canceled => ('Canceled', c.text2, c.tile),
      CiState.skipped => ('Skipped', c.text2, c.tile),
      null => ('', c.text2, c.tile),
    };
    final checked = p.checkedAt == null ? 'not checked yet' : 'checked ${_ago(p.checkedAt!)}';
    void settings() => showSettingsDialog(context, initial: SettingsTab.repos);

    final actions = <Widget>[];
    void action(String label, VoidCallback? onTap, {bool primary = false}) {
      if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
      actions.add(Expanded(
        child: primary
            ? KButton.primary(label: label, height: 30, fontSize: 12, expand: true, onTap: onTap)
            : KButton(label: label, height: 30, fontSize: 12, expand: true, onTap: onTap),
      ));
    }

    final busy = p.busy;
    if (problem != null && provider != null) {
      switch (problem.kind) {
        case CiProblemKind.notConnected:
          action('Connect ${provider.hostName}', settings, primary: true);
        case CiProblemKind.unauthorized:
          action('Renew token', settings, primary: true);
          action('Retry', busy ? null : p.refresh);
        case CiProblemKind.forbidden:
          action('Fix token in Settings', settings, primary: true);
          action('Retry', busy ? null : p.refresh);
        case CiProblemKind.notPushed:
          action('Publish branch', s.canPush && !busy ? s.push : null, primary: true);
        case CiProblemKind.notFound:
        case CiProblemKind.rateLimited:
        case CiProblemKind.unreachable:
          action('Retry now', busy ? null : p.refresh);
        case CiProblemKind.unsupported:
          break;
      }
    } else if (run != null && provider != null) {
      if (run.state.finished && run.hasFailedJobs) action('Re-run failed jobs', busy ? null : p.rerunFailed, primary: true);
      action('Open in ${provider.label}', run.url.isEmpty ? null : () => openUrl(run.url));
    }

    return Section(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(KIcons.cluster, size: 15, color: pill.isEmpty ? (problem != null && problem.needsSettings ? c.err : c.text2) : pillColor),
          const SizedBox(width: 8),
          Expanded(child: Text('Pipelines', style: sans(12.5, weight: FontWeight.w600, color: c.text))),
          if (pill.isNotEmpty) ...[Pill(label: pill, color: pillColor, background: pillBg), const SizedBox(width: 4)],
          KIconButton(icon: KIcons.refresh, label: 'Refresh · $checked', size: 24, iconSize: 14, onTap: busy || provider == null ? null : p.refresh),
        ]),
        if (provider != null) ...[
          const SizedBox(height: 2),
          Row(children: [
            TagChip(provider.host),
            const SizedBox(width: 6),
            Flexible(child: Text(provider.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3))),
            Text(' · ', style: sans(11.5, color: c.text3)),
            Flexible(child: Text(p.branch, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, color: c.text3))),
          ]),
        ],
        const SizedBox(height: 8),
        if (provider == null && problem == null)
          Text('Select a worktree to see its pipelines.', style: sans(12, color: c.text3))
        else if (p.loading && run == null && problem == null)
          Text('Asking ${provider?.label ?? 'the CI'}…', style: sans(12, color: c.text3)),
        if (run != null) ...[
          // One line: a long label (`run #8812 · attempt 2`) ellipsizes
          // instead of overflowing the panel.
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '${run.label} · ${run.shortSha}', style: mono(11.5, color: c.text2)),
              const WidgetSpan(child: SizedBox(width: 8)),
              TextSpan(text: _runNote(run), style: sans(11.5, color: c.text3)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          for (final j in run.jobs) _JobRow(job: j, stale: stale),
        ],
        if (problem != null) ...[
          if (run != null) const SizedBox(height: 6),
          _ProblemBox(problem: problem, provider: provider ?? CiProvider.githubActions, repo: p.repo),
        ],
        if (busy) ...[
          const SizedBox(height: 6),
          Text(problem != null ? 'Checking ${provider?.hostName ?? ''}…' : 'Asking ${provider?.label ?? 'the CI'}…', style: sans(11.5, color: c.acc)),
        ],
        if (p.actionError != null) ...[
          const SizedBox(height: 6),
          Text(p.actionError!, style: sans(11.5, color: c.err)),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: actions),
        ],
      ]),
    );
  }

  static String _runNote(CiRun run) {
    final total = run.jobs.length;
    final at = run.createdAt == null ? '' : 'started ${_ago(run.createdAt!)}';
    final progress = switch (run.state) {
      CiState.running || CiState.queued => '${run.done} of $total jobs done',
      CiState.failed => run.finishedAt != null && run.createdAt != null ? 'failed after ${_dur(run.finishedAt!.difference(run.createdAt!))}' : 'failed',
      CiState.passed => run.finishedAt != null && run.createdAt != null ? 'took ${_dur(run.finishedAt!.difference(run.createdAt!))}' : 'passed',
      _ => run.state.name,
    };
    return [if (at.isNotEmpty) at, progress].join(' · ');
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job, required this.stale});
  final CiJob job;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (color, bg, glyph) = switch (job.state) {
      CiState.passed => (c.ok, c.okSoft, KIcons.check),
      CiState.failed => (c.err, c.errSoft, KIcons.close),
      CiState.running => (c.acc, c.accSoft, null),
      _ => (c.text3, c.tile, null),
    };
    final time = switch (job.state) {
      CiState.running => job.startedAt == null || stale ? 'running' : 'running ${_dur(DateTime.now().difference(job.startedAt!))}',
      CiState.queued => 'waiting',
      CiState.skipped => 'skipped',
      CiState.canceled => 'canceled',
      _ => job.duration == null ? '' : _dur(job.duration!),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: glyph != null ? Icon(glyph, size: 11, color: color) : (job.state == CiState.running ? Dot(color, size: 5) : null),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(job.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, color: c.text2))),
          const SizedBox(width: 8),
          Text(time, style: mono(11, color: job.state == CiState.failed ? c.err : (job.state == CiState.running ? c.acc : c.text3))),
        ]),
        if (job.state == CiState.failed && (job.failure ?? '').isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 24, top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: c.errSoft, borderRadius: BorderRadius.circular(8)),
            child: Text(job.failure!, style: mono(11, color: c.text2, height: 1.45)),
          ),
      ]),
    );
  }
}

class _ProblemBox extends StatelessWidget {
  const _ProblemBox({required this.problem, required this.provider, required this.repo});
  final CiProblem problem;
  final CiProvider provider;
  final String repo;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (title, body) = describeCiProblem(problem, provider, repo: repo);
    final (color, bg, icon) = switch (problem.kind) {
      CiProblemKind.unauthorized || CiProblemKind.forbidden => (c.err, c.errSoft, KIcons.lock),
      CiProblemKind.rateLimited || CiProblemKind.unreachable => (c.warn, c.warnSoft, KIcons.cloudOff),
      CiProblemKind.notConnected => (c.text, c.tile, KIcons.plug),
      CiProblemKind.notPushed => (c.text, c.tile, KIcons.upload),
      _ => (c.text, c.tile, KIcons.info),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 15, color: color)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: sans(12, weight: FontWeight.w600, color: color)),
              const SizedBox(height: 3),
              Text(body, style: sans(12, color: c.text2, height: 1.45)),
              if (problem.detail.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(problem.detail, style: mono(10.5, color: c.text3)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 10) return 'just now';
  if (d.inSeconds < 60) return '${d.inSeconds} s ago';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

String _dur(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds}s';
  final m = d.inMinutes, sec = d.inSeconds % 60;
  if (m < 60) return sec == 0 ? '${m}m' : '${m}m ${sec.toString().padLeft(2, '0')}s';
  return '${d.inHours}h ${(m % 60).toString().padLeft(2, '0')}m';
}

/// The worktree's tests: the command its files point to (or the one the
/// user typed), run in a terminal, with what the runner's output says.
class _TestsWidget extends StatefulWidget {
  const _TestsWidget();

  @override
  State<_TestsWidget> createState() => _TestsWidgetState();
}

class _TestsWidgetState extends State<_TestsWidget> {
  bool _editing = false;
  final _command = TextEditingController();

  @override
  void dispose() {
    _command.dispose();
    super.dispose();
  }

  void _edit(String current) {
    _command.value = TextEditingValue(text: current, selection: TextSelection(baseOffset: 0, extentOffset: current.length));
    setState(() => _editing = true);
  }

  void _save(AppState s) {
    // The detected one again: nothing of the user's to keep.
    s.testCommand = _command.text.trim() == s.tests.command ? '' : _command.text;
    setState(() => _editing = false);
  }

  void _output(AppState s, TestRunInfo run) {
    final entry = s.activeWorktreeEntry;
    s.openTerminal(run.terminalId, title: 'Tests · ${s.activeWorktree}', directory: entry == null ? null : s.workspace.absolutePathOf(entry));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final tests = s.tests;
    final run = tests.run;
    final mine = s.testCommand;
    final command = mine.isNotEmpty ? mine : tests.command;
    final running = run?.state == TestRunState.running;
    final (icon, status) = switch (run) {
      null => (c.text3, ''),
      TestRunInfo(state: TestRunState.running) => (c.acc, 'Running…'),
      TestRunInfo(state: TestRunState.passed, :final passed) => (c.ok, passed > 0 ? '$passed passed' : 'Passed'),
      TestRunInfo(state: TestRunState.failed, :final failed) => (c.err, failed > 0 ? '$failed failed' : 'Failed'),
      TestRunInfo(state: TestRunState.stopped) => (c.text3, 'Stopped'),
    };
    final suites = run == null ? const <TestSuiteResult>[] : [...run.suites.where((s) => !s.passed), ...run.suites.where((s) => s.passed)];
    return Section(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(KIcons.flask, size: 15, color: icon),
          const SizedBox(width: 8),
          Expanded(child: Text('Tests', style: sans(12.5, weight: FontWeight.w600, color: c.text))),
          if (run != null) ...[
            Text(status, style: sans(11.5, weight: FontWeight.w600, color: icon)),
            if (!running) Text(' · ${_testDur(run.elapsed())}', style: sans(11.5, color: c.text3)),
          ],
        ]),
        const SizedBox(height: 6),
        if (_editing)
          Row(children: [
            Expanded(
              child: TextField(
                controller: _command,
                autofocus: true,
                style: mono(11.5, color: c.text),
                cursorColor: c.acc,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: tests.command.isEmpty ? 'e.g. make test' : tests.command,
                  hintStyle: mono(11.5, color: c.text3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.chipBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.acc)),
                ),
                onSubmitted: (_) => _save(s),
              ),
            ),
            const SizedBox(width: 6),
            KButton(label: 'Save', height: 28, fontSize: 12, onTap: () => _save(s)),
          ])
        else
          Row(children: [
            Expanded(
              child: tests.loading
                  ? Text('Looking for the test command…', style: sans(12, color: c.text3))
                  : command.isEmpty
                      ? Text('No test command found in this worktree.', style: sans(12, color: c.text3))
                      : Text.rich(
                          TextSpan(children: [
                            TextSpan(text: command, style: mono(11.5, color: c.text2)),
                            TextSpan(text: mine.isNotEmpty ? '  yours' : '  from ${tests.commandOrigin}', style: sans(11, color: c.text3)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
            ),
            if (!tests.loading) KIconButton(icon: KIcons.rename, label: 'Change the test command', size: 24, iconSize: 13, onTap: () => _edit(command)),
          ]),
        if (run != null) ...[
          const SizedBox(height: 8),
          for (final suite in suites.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Text(suite.passed ? '✓ ' : '✗ ', style: mono(11.5, color: suite.passed ? c.ok : c.err)),
                Expanded(child: Text(suite.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, color: c.text2))),
                if (suite.duration case final d?) Text(_testDur(d), style: mono(11.5, color: c.text3)),
              ]),
            ),
          if (suites.length > 6) Text('and ${suites.length - 6} more', style: sans(11.5, color: c.text3)),
          for (final name in run.failures.take(5))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: mono(11, color: c.err, height: 1.35)),
            ),
          if (run.failures.length > 5) Text('and ${run.failures.length - 5} more failing', style: sans(11.5, color: c.text3)),
          if (running && run.lastLine.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(run.lastLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3)),
            ),
          if (run.skipped > 0 && !running)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('${run.skipped} skipped', style: sans(11.5, color: c.text3))),
        ],
        if (tests.error case final error?) ...[
          const SizedBox(height: 6),
          Text(error, style: sans(11.5, color: c.err, height: 1.35)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: running
                ? KButton(label: 'Stop', height: 30, fontSize: 12, expand: true, onTap: tests.stop)
                : KButton.primary(
                    label: run == null ? 'Run tests' : 'Run again',
                    height: 30,
                    fontSize: 12,
                    expand: true,
                    onTap: command.isEmpty ? null : () => tests.runTests(command: mine),
                  ),
          ),
          if (run != null) ...[
            const SizedBox(width: 8),
            KButton(label: 'Output', icon: KIcons.terminal, height: 30, fontSize: 12, onTap: () => _output(s, run)),
          ],
        ]),
      ]),
    );
  }
}

/// `412ms`, `3.1s`, `2m 05s`.
String _testDur(Duration d) {
  if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
  if (d.inSeconds < 60) return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
  return _dur(d);
}

/// The pull request of the selected worktree's branch, from its host:
/// review, reviewers and checks; "Create pull request" when it has none and
/// "Publish branch" while it isn't pushed.
class PullRequestCard extends StatefulWidget {
  const PullRequestCard({super.key});

  @override
  State<PullRequestCard> createState() => _PullRequestCardState();
}

class _PullRequestCardState extends State<PullRequestCard> {
  /// The worktree whose pull request is shown.
  String? _path;
  BranchPullRequest? _answer;
  String? _error;
  bool _loading = false;
  bool _creating = false;
  bool _busy = false;
  bool _draft = true;
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    final path = _path;
    if (path == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final answer = await AppScope.read(context).pullRequests.forBranch(path, refresh: refresh);
      if (!mounted || path != _path) return;
      setState(() => _answer = answer);
    } on Object catch (e) {
      if (mounted && path == _path) setState(() => _error = '$e');
    }
    if (mounted && path == _path) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final path = _path;
    if (path == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pr = await AppScope.read(context).pullRequests.create(worktreePath: path, title: _title.text, draft: _draft);
      if (!mounted || path != _path) return;
      setState(() {
        _answer = BranchPullRequest(provider: _answer?.provider, pullRequest: pr);
        _creating = false;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  /// `feat/PRC-412-bulk-discounts` → `feat: PRC-412 bulk discounts`.
  static String _titleFor(String branch) {
    final slash = branch.indexOf('/');
    final rest = (slash < 0 ? branch : branch.substring(slash + 1)).replaceAll('-', ' ').replaceAll('_', ' ');
    final key = RegExp(r'^([A-Za-z]+) (\d+)').firstMatch(rest);
    final body = key == null ? rest : '${key[1]!.toUpperCase()}-${key[2]}${rest.substring(key.end)}';
    return slash < 0 ? body : '${branch.substring(0, slash)}: $body';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final entry = s.activeWorktreeEntry;
    final path = entry == null ? null : s.workspace.absolutePathOf(entry);
    if (path != _path) {
      _path = path;
      _answer = null;
      _error = null;
      _creating = false;
      if (path != null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final repo = s.activeRepo;
    final terms = RepoTerms.of(repo?.host ?? 'GH');
    final title = terms.prOne == 'MR' ? 'Merge request' : 'Pull request';
    final answer = _answer;
    final pr = answer?.pullRequest;
    final provider = answer?.provider ?? (repo == null ? null : CiProvider.ofHost(repo.host));
    final host = provider?.hostName ?? 'its host';
    final branch = entry?.branch ?? '';

    Widget body;
    if (entry == null) {
      body = Text('Select a worktree to see its ${terms.prOne}.', style: sans(12, color: c.text3));
    } else if (provider == null) {
      body = Text('Kumo reads ${terms.prs} from GitHub, GitLab and Bitbucket.', style: sans(12, color: c.text3));
    } else if (answer == null && _error == null) {
      body = Text('Looking for the ${terms.prOne} of $branch…', style: sans(12, color: c.text3));
    } else if (pr != null) {
      body = _pullRequest(context, pr, host);
    } else if (_creating) {
      body = _form(context, branch, terms);
    } else {
      body = _missing(context, s, answer?.problem, host, branch, terms);
    }

    return Section(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(KIcons.pullRequest, size: 15, color: c.acc),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: sans(12.5, weight: FontWeight.w600, color: c.text))),
          if (pr != null) _stateChip(c, pr),
          KIconButton(icon: KIcons.refresh, label: 'Check again', size: 24, iconSize: 14, onTap: _loading || _path == null ? null : () => _load(refresh: true)),
        ]),
        const SizedBox(height: 8),
        body,
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!, style: sans(11.5, color: c.err)),
        ],
      ]),
    );
  }

  Widget _stateChip(KumoPalette c, PullRequestInfo pr) {
    final (label, color) = switch (pr) {
      PullRequestInfo(state: PrOpenState.merged) => ('Merged', c.acc),
      PullRequestInfo(state: PrOpenState.closed) => ('Closed', c.text3),
      PullRequestInfo(draft: true) => ('Draft', c.text2),
      PullRequestInfo(review: PrReview.approved) => ('Approved', c.ok),
      PullRequestInfo(review: PrReview.changesRequested) => ('Changes requested', c.err),
      PullRequestInfo(review: PrReview.required) => ('Review requested', c.warn),
      _ => ('Open', c.acc),
    };
    return TagChip(label, color: color);
  }

  Widget _pullRequest(BuildContext context, PullRequestInfo pr, String host) {
    final s = AppScope.read(context);
    final c = context.c;
    final who = pr.reviewers.isEmpty
        ? ''
        : ' · ${pr.reviewers.join(', ')} ${pr.review == PrReview.required ? (pr.reviewers.length == 1 ? 'requested as reviewer' : 'requested as reviewers') : 'reviewing'}';
    final (checks, color) = switch (pr.checksState) {
      null => ('No checks ran', c.text3),
      CiState.failed => ('${pr.checksPassed} of ${pr.checksTotal} checks passed · failing', c.err),
      CiState.running || CiState.queued => ('${pr.checksPassed} of ${pr.checksTotal} checks passed · running', c.acc),
      CiState.passed => ('${pr.checksTotal == 1 ? 'Checks' : 'All ${pr.checksTotal} checks'} passed', c.ok),
      _ => ('Checks ${pr.checksState!.name}', c.text3),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text.rich(
        TextSpan(children: [
          TextSpan(text: '${pr.label} ', style: mono(12, color: c.text3)),
          TextSpan(text: pr.title, style: sans(12.5, weight: FontWeight.w500, color: c.text)),
        ]),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      Text(
        '$host · into ${pr.base.isEmpty ? 'the default branch' : pr.base}$who${pr.reviewRequestedFromYou ? ' · your review' : ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: sans(11.5, color: c.text3),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Dot(color),
        const SizedBox(width: 8),
        Expanded(child: Text(checks, style: sans(11.5, color: color))),
        if (pr.commentCount > 0) ...[
          Icon(Icons.chat_bubble_outline_rounded, size: 12, color: c.text3),
          const SizedBox(width: 4),
          Text('${pr.commentCount}', style: sans(11.5, color: c.text3)),
        ],
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: KButton(label: 'Open in $host', height: 30, fontSize: 12, expand: true, onTap: pr.url.isEmpty ? null : () => openUrl(pr.url))),
        const SizedBox(width: 8),
        Expanded(child: KButton(label: 'Open in Git', height: 30, fontSize: 12, expand: true, onTap: () => s.view = KumoView.git)),
      ]),
    ]);
  }

  Widget _missing(BuildContext context, AppState s, CiProblem? problem, String host, String branch, RepoTerms terms) {
    final c = context.c;
    final (String text, Widget? action) = switch (problem?.kind) {
      null => (
          'No ${terms.prOne} for $branch yet.',
          KButton.primary(
            label: 'Create ${terms.prOne == 'MR' ? 'merge request' : 'pull request'}',
            height: 30,
            fontSize: 12,
            expand: true,
            onTap: () => setState(() {
              _creating = true;
              _title.text = _titleFor(branch);
            }),
          ),
        ),
      CiProblemKind.notPushed => (
          '$branch isn’t on $host yet: publish it to open a ${terms.prOne}.',
          KButton.primary(label: 'Publish branch', height: 30, fontSize: 12, expand: true, onTap: s.canPush ? s.push : null),
        ),
      CiProblemKind.notConnected || CiProblemKind.unauthorized || CiProblemKind.forbidden => (
          problem!.kind == CiProblemKind.notConnected ? '$host isn’t connected.' : 'Your $host token can’t read ${terms.prs}${problem.detail.isEmpty ? '' : ' (${problem.detail})'}.',
          KButton(label: 'Open Settings', height: 30, fontSize: 12, expand: true, onTap: () => showSettingsDialog(context, initial: SettingsTab.repos)),
        ),
      _ => ('Couldn’t ask $host${problem!.detail.isEmpty ? '' : ': ${problem.detail}'}.', null),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(text, style: sans(12, color: c.text2)),
      if (action != null) ...[const SizedBox(height: 10), action],
    ]);
  }

  Widget _form(BuildContext context, String branch, RepoTerms terms) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KField(label: 'Title', controller: _title),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text('Open as draft', style: sans(12, color: c.text2))),
        KSwitch(value: _draft, onChanged: (v) => setState(() => _draft = v), label: 'Open as draft'),
      ]),
      const SizedBox(height: 4),
      Text('From $branch into the default branch.', style: sans(11, color: c.text3)),
      const SizedBox(height: 10),
      Row(children: [
        KButton(label: 'Cancel', height: 30, fontSize: 12, onTap: _busy ? null : () => setState(() => _creating = false)),
        const SizedBox(width: 8),
        Expanded(child: KButton.primary(label: _busy ? 'Creating…' : 'Create ${terms.prOne}', height: 30, fontSize: 12, expand: true, onTap: _busy ? null : _create)),
      ]),
    ]);
  }
}

/// What happened in the worktree, newest first: each agent's steps (read
/// from its terminal) and the test runs.
class _ActivityWidget extends StatefulWidget {
  const _ActivityWidget();

  @override
  State<_ActivityWidget> createState() => _ActivityWidgetState();
}

class _ActivityWidgetState extends State<_ActivityWidget> {
  static const _shown = 6;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final agents = s.worktreeAgents;
    final events = <(DateTime, String, Color)>[
      for (final run in agents)
        for (final step in run.steps) (step.at, '${agents.length > 1 ? '${run.short} · ' : ''}${_stepText(step)}', _stepColor(c, step)),
      if (s.tests.run case final run?) ...[
        (run.startedAt, 'Ran tests: ${run.command}', c.text3),
        if (run.finishedAt case final at?)
          switch (run.state) {
            TestRunState.passed => (at, run.passed > 0 ? 'Tests passed · ${run.passed}' : 'Tests passed', c.ok),
            TestRunState.failed => (at, run.failed > 0 ? '${run.failed} tests failed' : 'Tests failed', c.err),
            _ => (at, 'Tests stopped', c.text3),
          },
      ],
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    final shown = _all ? events.take(40) : events.take(_shown);
    final who = switch (agents) {
      [] => '',
      [final run] => run.providerName,
      _ => '${agents.length} agents',
    };
    return Section(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(KIcons.activity, size: 15, color: c.acc),
          const SizedBox(width: 8),
          Expanded(child: Text('Activity', style: sans(12.5, weight: FontWeight.w600, color: c.text))),
          if (who.isNotEmpty) Flexible(child: Text(who, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3))),
        ]),
        const SizedBox(height: 10),
        if (events.isEmpty) Text('What agents and test runs do in this worktree shows here, step by step.', style: sans(12, color: c.text3, height: 1.4)),
        for (final (at, text, color) in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 38, child: Text(_clock(at), style: mono(11, color: c.text3))),
              Padding(padding: const EdgeInsets.only(top: 5), child: Dot(color)),
              const SizedBox(width: 10),
              Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text2))),
            ]),
          ),
        if (events.length > _shown)
          KPressable(
            onTap: () => setState(() => _all = !_all),
            semanticLabel: _all ? 'Show less' : 'Show all activity',
            builder: (context, hover, focus) => Text(
              _all ? 'Show less' : 'Show all ${events.length > 40 ? 'latest 40' : events.length}',
              style: sans(11.5, color: hover || focus ? c.acc : c.text3),
            ),
          ),
      ]),
    );
  }
}

String _stepText(AgentStep step) => switch (step.kind) {
      AgentStepKind.started => 'Started ${step.text}',
      AgentStepKind.edited => 'Edited ${step.text}',
      AgentStepKind.ran => 'Ran ${step.text}',
      AgentStepKind.read => step.text.startsWith('Read ') ? step.text : 'Read ${step.text}',
      AgentStepKind.searched => step.text.startsWith('Searched ') || step.text.startsWith('Listed ') ? step.text : 'Searched ${step.text}',
      AgentStepKind.tool => step.text,
      AgentStepKind.waiting => step.text.isEmpty ? 'Waiting for you' : 'Waiting for you · ${step.text}',
      AgentStepKind.context => 'Got ${step.text}',
      AgentStepKind.exited => step.text,
    };

Color _stepColor(KumoPalette c, AgentStep step) => switch (step.kind) {
      AgentStepKind.edited => c.acc,
      AgentStepKind.ran => c.text2,
      AgentStepKind.waiting => c.warn,
      AgentStepKind.exited => switch (step.text) {
        'Finished' => c.ok,
        'Stopped' => c.text3,
        _ => c.err,
      },
      _ => c.text3,
    };
