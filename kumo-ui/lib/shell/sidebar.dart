import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../overlays/namespace_dialog.dart';
import '../overlays/new_worktree_popover.dart';
import '../overlays/settings_dialog.dart';
import '../platform/window_effects.dart';
import '../theme/kumo_theme.dart';
import '../widgets/anchored_popover.dart';
import '../widgets/context_menu.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';

Color toneColor(BuildContext context, WorktreeTone t) {
  final c = context.c;
  return switch (t) {
    WorktreeTone.idle => c.text3,
    WorktreeTone.running => c.acc,
    WorktreeTone.warn => c.warn,
    WorktreeTone.ok => c.ok,
  };
}

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  static const _navIcons = {
    KumoView.terminal: KIcons.terminal,
    KumoView.files: KIcons.files,
    KumoView.agents: KIcons.agent,
    KumoView.tasks: KIcons.tasks,
    KumoView.git: KIcons.git,
    KumoView.docs: KIcons.docs,
  };

  /// (namespace id, repo) whose + answers ⇧⌘N: the current worktree's repo
  /// where it is visible in the sidebar, otherwise the first visible repo.
  static (String, String)? _signalTarget(AppState s) {
    final visible = [
      for (final n in s.namespaces)
        if (!n.collapsed)
          for (final r in n.repos) (n.id, r),
    ];
    final active = s.activeRepo?.id;
    for (final v in visible) {
      if (v.$2 == active) return v;
    }
    return visible.isEmpty ? null : visible.first;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final nativeLights = !kIsWeb && Platform.isMacOS && WindowEffects.nativeBackdrop;
    final signal = _signalTarget(s);

    return SizedBox(
      width: 252,
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Native traffic lights sit on the left of this row (macOS).
            SizedBox(
              height: 32,
              child: Row(children: [
                if (!nativeLights) ...[
                  for (final col in const [Color(0xFFFF5F57), Color(0xFFFEBC2E), Color(0xFF28C840)]) ...[
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                  ],
                ],
                const Spacer(),
                KIconButton(icon: KIcons.sidebar, label: 'Hide sidebar (⌥⌘S)', onTap: s.toggleSidebar),
              ]),
            ),
            const SizedBox(height: 12),
            const _WorkspaceSwitcher(),
            const SizedBox(height: 14),
            for (final v in KumoView.values) _NavItem(view: v, icon: _navIcons[v]!),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 2, bottom: 6),
              child: SectionTitle(
                'Namespaces',
                trailing: KIconButton(icon: KIcons.add, label: 'New namespace', onTap: () => showNamespaceDialog(context), size: 24, iconSize: 15),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final ns in s.namespaces)
                    _NamespaceGroup(key: ValueKey(ns.id), ns: ns, signalRepo: signal != null && signal.$1 == ns.id ? signal.$2 : null),
                  if (s.undo != null) _UndoToast(notice: s.undo!),
                  if (s.workspaceError != null) _ErrorToast(message: s.workspaceError!),
                  const _NewNamespaceRow(),
                ],
              ),
            ),
            Container(height: 1, color: c.divider, margin: const EdgeInsets.only(bottom: 12)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SectionTitle('Integrations', trailing: Text('${Mock.integrations.length} synced', style: sans(11, color: c.ok))),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Wrap(spacing: 4, runSpacing: 4, children: [for (final i in Mock.integrations) SourceTile(i.k, tooltip: i.name)]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              const SizedBox(width: 4),
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.accSoft, shape: BoxShape.circle),
                child: Text('M', style: sans(12, weight: FontWeight.w600, color: c.acc)),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text('Mauri', style: sans(13, weight: FontWeight.w500, color: c.text))),
              KIconButton(icon: KIcons.settings, label: 'Settings (⌘,)', onTap: () => showSettingsDialog(context)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceSwitcher extends StatelessWidget {
  const _WorkspaceSwitcher();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: () {},
      semanticLabel: 'Switch workspace, current: pricing',
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.all(8),
        decoration: chipDecoration(c, radius: 14, fill: hover ? c.tabActive : null),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accFill, borderRadius: BorderRadius.circular(9)),
            child: Text('P', style: sans(14, weight: FontWeight.w700, color: c.accText)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('pricing', style: sans(13, weight: FontWeight.w600, color: c.text)),
              Text('3 repos · 6 worktrees', style: sans(11.5, color: c.text3)),
            ]),
          ),
          Icon(KIcons.chevronUpDown, size: 16, color: c.text3),
        ]),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.view, required this.icon});

  final KumoView view;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final on = s.view == view;
    final badge = switch (view) {
      KumoView.agents => '1',
      KumoView.tasks => '12',
      _ => null,
    };
    return KPressable(
      onTap: () => s.view = view,
      semanticLabel: view.label,
      selected: on,
      tooltip: '${view.label}  ${view.shortcut}',
      builder: (context, hover, focus) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 34,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: on
            ? chipDecoration(c, radius: 10, fill: c.navActive)
            : BoxDecoration(color: hover ? c.tile : null, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, size: 17, color: on ? c.acc : c.text3),
          const SizedBox(width: 10),
          Expanded(child: Text(view.label, style: sans(13, weight: on ? FontWeight.w600 : FontWeight.w500, color: on ? c.text : c.text2))),
          if (badge != null)
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: view == KumoView.agents ? c.warnSoft : c.tile, borderRadius: BorderRadius.circular(10)),
              child: Text(badge, style: sans(11, weight: FontWeight.w600, color: view == KumoView.agents ? c.warn : c.text2)),
            ),
        ]),
      ),
    );
  }
}

/// One namespace: header (⋮ menu, right-click, inline rename) + its repos.
class _NamespaceGroup extends StatefulWidget {
  const _NamespaceGroup({super.key, required this.ns, required this.signalRepo});
  final Namespace ns;
  final String? signalRepo;

  @override
  State<_NamespaceGroup> createState() => _NamespaceGroupState();
}

class _NamespaceGroupState extends State<_NamespaceGroup> {
  bool _menuOpen = false;
  bool _renaming = false;
  final _name = TextEditingController();
  final _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && _renaming) _commitRename();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _startRename() {
    _name.text = widget.ns.name;
    _name.selection = TextSelection(baseOffset: 0, extentOffset: _name.text.length);
    setState(() => _renaming = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  void _commitRename() {
    if (!_renaming) return;
    setState(() => _renaming = false);
    AppScope.read(context).renameNamespace(widget.ns.id, _name.text);
  }

  void _cancelRename() {
    setState(() => _renaming = false);
    _nameFocus.unfocus();
  }

  void _openMenu(Offset at, {bool alignRight = false}) {
    setState(() => _menuOpen = true);
    final sidebarContext = context;
    showKMenu(
      context,
      position: at,
      alignRight: alignRight,
      onClosed: () {
        if (mounted) setState(() => _menuOpen = false);
      },
      builder: (context, close) => _NamespaceMenu(
        ns: widget.ns,
        close: close,
        onAddRepos: () => showNamespaceDialog(sidebarContext, edit: widget.ns),
        onRename: _startRename,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final ns = widget.ns;
    final repos = [for (final id in ns.repos) s.workspace.repo(id)].whereType<Repo>().toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GestureDetector(
          onSecondaryTapDown: (d) => _openMenu(d.globalPosition),
          child: Semantics(
            label: 'Namespace ${ns.name}, ${repos.length} repos. Right-click for actions',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              height: 30,
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.only(left: 8, right: 2),
              decoration: BoxDecoration(color: _menuOpen || _renaming ? c.tile : null, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(KIcons.namespace, size: 14, color: c.text3),
                const SizedBox(width: 7),
                if (_renaming)
                  Expanded(
                    child: CallbackShortcuts(
                      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancelRename},
                      child: Container(
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(6), border: Border.all(color: c.acc)),
                        child: TextField(
                          controller: _name,
                          focusNode: _nameFocus,
                          onSubmitted: (_) => _commitRename(),
                          style: sans(12, weight: FontWeight.w600, color: c.text),
                          cursorColor: c.acc,
                          decoration: const InputDecoration.collapsed(hintText: 'Namespace name'),
                        ),
                      ),
                    ),
                  )
                else ...[
                  Flexible(child: Text(ns.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, weight: FontWeight.w600, color: c.text2))),
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(8)),
                    child: Text('${repos.length}', style: sans(10.5, color: c.text3)),
                  ),
                  const Spacer(),
                ],
                const SizedBox(width: 4),
                Builder(
                  builder: (btn) => KIconButton(
                    icon: KIcons.moreVert,
                    label: 'Actions for ${ns.name} (or right-click)',
                    size: 22,
                    iconSize: 15,
                    color: _menuOpen ? c.text : c.text3,
                    onTap: () => _openMenu(belowOf(btn), alignRight: true),
                  ),
                ),
              ]),
            ),
          ),
        ),
        if (!ns.collapsed)
          for (final r in repos) _RepoGroup(key: ValueKey('${ns.id}/${r.name}'), repo: r, signal: widget.signalRepo == r.name),
      ]),
    );
  }
}

class _NamespaceMenu extends StatefulWidget {
  const _NamespaceMenu({required this.ns, required this.close, required this.onAddRepos, required this.onRename});
  final Namespace ns;
  final VoidCallback close;
  final VoidCallback onAddRepos;
  final VoidCallback onRename;

  @override
  State<_NamespaceMenu> createState() => _NamespaceMenuState();
}

class _NamespaceMenuState extends State<_NamespaceMenu> {
  bool _confirm = false;

  void _do(VoidCallback f) {
    widget.close();
    f();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    final ns = widget.ns;
    final n = ns.repos.length;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.backspace, meta: true): () => setState(() => _confirm = true),
        const SingleActivator(LogicalKeyboardKey.delete): () => setState(() => _confirm = true),
      },
      child: KMenuPanel(children: _confirm
          ? [
              KMenuConfirm(
                title: 'Delete “${ns.name}”?',
                body: 'Only the group goes away. Its $n ${n == 1 ? 'repo' : 'repos'} and their worktrees stay on disk.',
                confirmLabel: 'Delete',
                onCancel: () => setState(() => _confirm = false),
                onConfirm: () => _do(() => s.deleteNamespace(ns.id)),
              ),
            ]
          : [
              KMenuItem(icon: KIcons.add, label: 'Add repositories…', onTap: () => _do(widget.onAddRepos)),
              KMenuItem(icon: KIcons.rename, label: 'Rename', shortcut: '↩', onTap: () => _do(widget.onRename)),
              KMenuItem(
                icon: ns.collapsed ? KIcons.expand : KIcons.collapse,
                label: ns.collapsed ? 'Expand' : 'Collapse',
                onTap: () => _do(() => s.toggleNamespaceCollapsed(ns.id)),
              ),
              const KMenuDivider(),
              KMenuItem(icon: KIcons.trash, label: 'Delete namespace…', shortcut: '⌘⌫', danger: true, onTap: () => setState(() => _confirm = true)),
            ]),
    );
  }
}

/// A daemon error about the workspace (e.g. git refused to remove a worktree
/// with uncommitted changes).
class _ErrorToast extends StatelessWidget {
  const _ErrorToast({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 6),
        padding: const EdgeInsets.fromLTRB(10, 6, 3, 6),
        decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(message, maxLines: 4, overflow: TextOverflow.ellipsis, style: sans(12, color: c.err))),
          KIconButton(icon: KIcons.close, label: 'Dismiss', size: 22, iconSize: 12, color: c.text3, onTap: s.dismissWorkspaceError),
        ]),
      ),
    );
  }
}

class _UndoToast extends StatelessWidget {
  const _UndoToast({required this.notice});
  final UndoNotice notice;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 6),
        padding: const EdgeInsets.fromLTRB(10, 3, 3, 3),
        decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(child: Text(notice.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text2))),
          KPressable(
            onTap: s.undoLast,
            semanticLabel: 'Undo',
            builder: (context, hover, focus) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: hover || focus ? c.accSoft : null, borderRadius: BorderRadius.circular(6)),
              child: Text('Undo', style: sans(12, weight: FontWeight.w600, color: c.acc)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _NewNamespaceRow extends StatelessWidget {
  const _NewNamespaceRow();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: () => showNamespaceDialog(context),
      semanticLabel: 'New namespace',
      builder: (context, hover, focus) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(KIcons.add, size: 14, color: c.text3),
          const SizedBox(width: 8),
          Text('New namespace', style: sans(12, weight: FontWeight.w500, color: c.text3)),
        ]),
      ),
    );
  }
}

class _RepoGroup extends StatefulWidget {
  const _RepoGroup({super.key, required this.repo, this.signal = false});
  final Repo repo;

  /// This row's + also answers ⇧⌘N.
  final bool signal;

  @override
  State<_RepoGroup> createState() => _RepoGroupState();
}

class _RepoGroupState extends State<_RepoGroup> {
  bool _open = true;
  String? _menuFor;

  void _openMenu(Worktree w, Offset at) {
    setState(() => _menuFor = w.branch);
    showKMenu(
      context,
      position: at,
      onClosed: () {
        if (mounted) setState(() => _menuFor = null);
      },
      builder: (context, close) => _WorktreeMenu(repo: widget.repo, wt: w, close: close),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final r = widget.repo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KPressable(
          onTap: () => setState(() => _open = !_open),
          semanticLabel: '${r.name}, ${_open ? 'collapse' : 'expand'}',
          builder: (context, hover, focus) => Container(
            height: 28,
            padding: const EdgeInsets.only(left: 8, right: 2),
            decoration: BoxDecoration(color: hover ? c.tile : null, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(_open ? KIcons.chevronDown : KIcons.chevronRight, size: 14, color: c.text3),
              const SizedBox(width: 6),
              Icon(KIcons.repo, size: 15, color: c.text2),
              const SizedBox(width: 8),
              Expanded(child: Text(r.name, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: FontWeight.w600, color: c.text))),
              TagChip(r.host, color: c.text2),
              const SizedBox(width: 2),
              AnchoredPopover(
                openSignal: widget.signal ? s.newWorktreeRequests : null,
                floating: true,
                positionKey: NewWorktreePopover,
                triggerBuilder: (context, toggle, open) => KIconButton(
                  icon: KIcons.add,
                  label: widget.signal ? 'New worktree in ${r.name} (⇧⌘N)' : 'New worktree in ${r.name}',
                  onTap: toggle,
                  size: 22,
                  iconSize: 14,
                  color: open ? c.acc : c.text3,
                ),
                popoverBuilder: (context, close) => NewWorktreePopover(onClose: close, repo: r.id),
              ),
            ]),
          ),
        ),
        if (_open)
          for (final w in s.worktreesOf(r))
            GestureDetector(
              onSecondaryTapDown: (d) => _openMenu(w, d.globalPosition),
              child: KPressable(
                onTap: () => s.selectWorktree(w.branch, path: w.path),
                semanticLabel: '${w.branch}, ${w.note}${w.isMain ? ', principal checkout' : ''}',
                tooltip: w.isMain ? 'Principal checkout · right-click for actions' : null,
                selected: s.isActiveWorktree(w),
                builder: (context, hover, focus) {
                  final sel = s.isActiveWorktree(w);
                  final menu = _menuFor == w.branch;
                  return Container(
                    margin: const EdgeInsets.only(top: 1),
                    padding: const EdgeInsets.fromLTRB(28, 5, 8, 5),
                    decoration: sel && !menu
                        ? chipDecoration(c, radius: 9, fill: c.navActive)
                        : BoxDecoration(color: hover || menu ? c.tile : null, borderRadius: BorderRadius.circular(9)),
                    child: Row(children: [
                      Dot(toneColor(context, w.tone)),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(w.branch, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, color: c.text, height: 1.35))),
                            if (w.isMain) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(5)),
                                child: Text('principal', style: sans(9.5, weight: FontWeight.w600, color: c.acc, height: 1.6, letterSpacing: 0.2)),
                              ),
                            ],
                          ]),
                          Text(w.note, style: sans(11, color: w.tone == WorktreeTone.warn ? c.warn : c.text3)),
                        ]),
                      ),
                    ]),
                  );
                },
              ),
            ),
      ]),
    );
  }
}

class _WorktreeMenu extends StatefulWidget {
  const _WorktreeMenu({required this.repo, required this.wt, required this.close});
  final Repo repo;
  final Worktree wt;
  final VoidCallback close;

  @override
  State<_WorktreeMenu> createState() => _WorktreeMenuState();
}

class _WorktreeMenuState extends State<_WorktreeMenu> {
  bool _confirm = false;

  void _do(VoidCallback f) {
    widget.close();
    f();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    final w = widget.wt;
    final isMain = w.isMain;
    final running = w.tone == WorktreeTone.running && w.note.contains('running');
    final agent = w.note.split(' · ').first;
    return KMenuPanel(children: _confirm
        ? [
            KMenuConfirm(
              title: 'Delete this worktree?',
              detail: w.path,
              body: '${running ? '$agent is running here and will be stopped. ' : ''}Runs git worktree remove. The branch stays in the repo.',
              confirmLabel: 'Delete',
              onCancel: () => setState(() => _confirm = false),
              onConfirm: () => _do(() => s.deleteWorktree(widget.repo.id, w.branch)),
            ),
          ]
        : [
            KMenuItem(
              icon: KIcons.terminal,
              label: 'Open in terminal',
              onTap: () => _do(() {
                s.selectWorktree(w.branch, path: w.path);
                s.view = KumoView.terminal;
              }),
            ),
            KMenuItem(icon: KIcons.reveal, label: 'Reveal in Finder', onTap: () => _do(() {})),
            KMenuItem(icon: KIcons.copy, label: 'Copy path', onTap: () => _do(() => Clipboard.setData(ClipboardData(text: w.path)))),
            const KMenuDivider(),
            if (isMain)
              const KMenuItem(icon: KIcons.trash, label: 'Delete worktree', note: 'This is the principal checkout, not a worktree.')
            else
              KMenuItem(icon: KIcons.trash, label: 'Delete worktree…', danger: true, onTap: () => setState(() => _confirm = true)),
          ]);
  }
}
