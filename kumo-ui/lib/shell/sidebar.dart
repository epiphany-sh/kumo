import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/agents_source.dart';
import '../data/ai_usage_source.dart';
import '../data/models.dart';
import '../overlays/namespace_dialog.dart';
import '../overlays/new_worktree_popover.dart';
import '../overlays/settings_dialog.dart';
import '../platform/git_user.dart';
import '../platform/window_effects.dart';
import '../theme/kumo_theme.dart';
import '../widgets/anchored_popover.dart';
import '../widgets/context_menu.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';
import '../widgets/usage_meter.dart';

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
      width: s.sidebarWidth,
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
            for (final v in KumoView.nav) _NavItem(view: v, icon: _navIcons[v]!),
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
                  if (s.arrivedWorktree case (final repo, final worktree)) _ArrivedToast(repo: repo, worktree: worktree),
                  for (final ns in s.namespaces)
                    _NamespaceGroup(key: ValueKey(ns.id), ns: ns, signalRepo: signal != null && signal.$1 == ns.id ? signal.$2 : null),
                  if (s.undo != null) _UndoToast(notice: s.undo!),
                  if (s.workspaceError != null) _ErrorToast(message: s.workspaceError!),
                  const _NewNamespaceRow(),
                ],
              ),
            ),
            Container(height: 1, color: c.divider, margin: const EdgeInsets.only(bottom: 12)),
            // Never more than 40% of the window: past that it scrolls, so
            // the namespaces keep their room.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
              child: const SingleChildScrollView(child: _AiUsage()),
            ),
            const SizedBox(height: 10),
            Row(children: [
              const SizedBox(width: 4),
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.accSoft, shape: BoxShape.circle),
                child: Text(_initial(gitUserName), style: sans(12, weight: FontWeight.w600, color: c.acc)),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text(gitUserName, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13, weight: FontWeight.w500, color: c.text))),
              KIconButton(icon: KIcons.settings, label: 'Settings (⌘,)', onTap: () => showSettingsDialog(context)),
            ]),
          ],
        ),
      ),
    );
  }
}

/// The namespace being worked in (the selected worktree's), with its real
/// counts; the menu jumps to another namespace or creates one.
class _WorkspaceSwitcher extends StatelessWidget {
  const _WorkspaceSwitcher();

  /// Selects the namespace's first repository's main checkout.
  static void _enter(AppState s, Namespace ns) {
    for (final id in ns.repos) {
      final main = s.workspace.repo(id)?.worktrees.where((w) => w.isMain).firstOrNull;
      if (main != null) return s.selectWorktree(main.branch, path: main.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final active = s.activeRepo;
    final ns = s.namespaces.where((n) => active != null && n.repos.contains(active.id)).firstOrNull ?? s.namespaces.firstOrNull;
    final repos = [for (final id in ns?.repos ?? const <String>[]) s.workspace.repo(id)].whereType<Repo>().toList();
    final worktrees = repos.fold<int>(0, (n, r) => n + s.worktreesOf(r).length);
    final name = ns?.name ?? 'Kumo';
    final detail = ns == null ? 'No namespaces yet' : '${repos.length} ${repos.length == 1 ? 'repo' : 'repos'} · $worktrees ${worktrees == 1 ? 'worktree' : 'worktrees'}';
    return Builder(
      builder: (anchor) => KPressable(
        onTap: () => showKMenu(
          anchor,
          position: belowOf(anchor, right: false),
          builder: (context, close) => KMenuPanel(width: 240, children: [
            for (final n in s.namespaces)
              KMenuItem(
                icon: n.id == ns?.id ? KIcons.check : KIcons.namespace,
                label: n.name,
                note: '${n.repos.length} ${n.repos.length == 1 ? 'repo' : 'repos'}',
                onTap: () {
                  close();
                  _enter(s, n);
                },
              ),
            if (s.namespaces.isNotEmpty) const KMenuDivider(),
            KMenuItem(
              icon: KIcons.add,
              label: 'New namespace',
              onTap: () {
                close();
                showNamespaceDialog(context);
              },
            ),
          ]),
        ),
        semanticLabel: 'Switch namespace, current: $name',
        builder: (context, hover, focus) => Container(
          padding: const EdgeInsets.all(8),
          decoration: chipDecoration(c, radius: 14, fill: hover ? c.tabActive : null),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accFill, borderRadius: BorderRadius.circular(9)),
              child: Text(_initial(name), style: sans(14, weight: FontWeight.w700, color: c.accText)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13, weight: FontWeight.w600, color: c.text)),
                Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3)),
              ]),
            ),
            Icon(KIcons.chevronUpDown, size: 16, color: c.text3),
          ]),
        ),
      ),
    );
  }
}

String _initial(String name) => name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();

/// What's left on the connected agents' plans, one row per agent with the
/// limit closest to its end; a click shows every window and when it
/// resets. Past [AppState.usageRows] agents, the last row folds the rest
/// into "+N more", which still says when a folded one runs low. Hidden when
/// nothing is reported, or turned off in Settings › AI agents.
class _AiUsage extends StatefulWidget {
  const _AiUsage();

  @override
  State<_AiUsage> createState() => _AiUsageState();
}

class _AiUsageState extends State<_AiUsage> {
  String? _open;
  bool _all = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // "Resets in 1 h 48 min" and "Updated 2 min ago" stay true.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    if (!s.usageInSidebar || !s.usage.supported) return const SizedBox.shrink();
    final rows = [
      for (final p in s.agents.connected)
        if (s.usage.planOf(p.id) case final plan?) (p, plan),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    final style = s.usageStyle;
    final now = DateTime.now();
    final limit = s.usageRows ?? rows.length;
    final fold = rows.length > limit;
    final shown = fold && !_all ? rows.take(limit - 1).toList() : rows;
    final hidden = fold && !_all ? rows.skip(limit - 1).toList() : const <(AgentProviderInfo, AgentPlanUsage)>[];
    final low = [
      for (final (p, plan) in hidden)
        if (plan.tightest case final w? when style.tone(c, w.fractionLeft) != null) (p, w),
    ];
    final out = low.any((x) => style.tone(c, x.$2.fractionLeft) == c.err);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 3),
        child: SectionTitle(
          'AI usage',
          trailing: KPressable(
            onTap: s.usage.refresh,
            semanticLabel: 'Refresh AI usage',
            tooltip: 'Read from each agent’s own CLI or account · click to refresh',
            builder: (context, hover, focus) => Text(_updated(s.usage.updatedAt, now), style: sans(11, color: hover || focus ? c.text2 : c.text3)),
          ),
        ),
      ),
      for (final (p, plan) in shown)
        _UsageRow(
          key: ValueKey('usage-${p.id}'),
          agent: p,
          plan: plan,
          style: style,
          now: now,
          open: _open == p.id,
          onTap: () => setState(() => _open = _open == p.id ? null : p.id),
        ),
      if (fold)
        KPressable(
          key: const ValueKey('usage-more'),
          onTap: () => setState(() => _all = !_all),
          semanticLabel: _all ? 'Show fewer agents' : 'Show ${hidden.length} more agents${low.isEmpty ? '' : ', ${low.length} running low'}',
          tooltip: _all
              ? null
              : [for (final (p, plan) in hidden) '${p.name}: ${plan.tightest == null ? 'can’t read its usage' : style.value(plan.tightest!)}'].join('\n'),
          builder: (context, hover, focus) => Container(
            height: 26,
            padding: const EdgeInsets.only(left: 32, right: 4),
            decoration: BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(child: Text(_all ? 'Show less' : '+${hidden.length} more', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text2))),
              if (low.isNotEmpty) ...[
                Dot(out ? c.err : c.warn, size: 6),
                const SizedBox(width: 5),
                Flexible(
                  flex: 3,
                  child: Text(
                    low.length == 1 ? '${low.first.$1.name} ${out ? 'almost out' : 'low'}' : '${low.length} running low',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: sans(11.5, color: out ? c.err : c.warn),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(_all ? KIcons.chevronUp : KIcons.chevronDown, size: 14, color: c.text3),
            ]),
          ),
        ),
    ]);
  }
}

String _updated(DateTime? at, DateTime now) {
  if (at == null) return '';
  final m = now.difference(at).inMinutes;
  return m < 1 ? 'Updated just now' : (m < 60 ? 'Updated $m min ago' : 'Updated ${m ~/ 60} h ago');
}

/// One agent in "AI usage": its tightest window as a bar and a share, and
/// every window with its reset when open.
class _UsageRow extends StatelessWidget {
  const _UsageRow({super.key, required this.agent, required this.plan, required this.style, required this.now, required this.open, required this.onTap});
  final AgentProviderInfo agent;
  final AgentPlanUsage plan;
  final UsageStyle style;
  final DateTime now;
  final bool open;
  final VoidCallback onTap;

  String _lower(String text) => text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = plan.tightest;
    final tone = w == null ? null : style.tone(c, w.fractionLeft);
    final summary = plan.problem ?? [for (final x in plan.windows) '${x.label}: ${style.value(x)} · ${_lower(resetLabel(x.resets, now))}'].join('\n');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KPressable(
        onTap: onTap,
        selected: open,
        semanticLabel: '${agent.name}, ${plan.problem ?? (w == null ? 'usage not reported' : '${style.value(w)} of the ${_lower(w.label)}')}${open ? ', expanded' : ''}',
        tooltip: '${agent.name} · ${plan.plan}\n$summary\nClick for details',
        builder: (context, hover, focus) => Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(color: open ? c.navActive : (hover || focus ? c.tile : null), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            SourceTile(agent.short, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(agent.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, color: c.text))),
            if (w == null) ...[
              Dot(c.warn, size: 6),
              const SizedBox(width: 5),
              Text('Can’t read', style: sans(11.5, color: c.warn)),
            ] else ...[
              const SizedBox(width: 6),
              UsageBar(width: 40, fill: style.fill(w), color: tone ?? c.acc),
              SizedBox(
                width: 34,
                child: Text(
                  style.percent(w),
                  textAlign: TextAlign.right,
                  style: sans(11.5, weight: FontWeight.w600, color: tone ?? c.text2).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
              const SizedBox(width: 5),
              SizedBox(width: 22, child: Text(w.short, maxLines: 1, style: sans(10.5, color: c.text3))),
            ],
          ]),
        ),
      ),
      if (open)
        Container(
          margin: const EdgeInsets.fromLTRB(32, 2, 0, 6),
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(plan.plan, style: sans(11.5, color: c.text3)),
            for (final x in plan.windows) ...[const SizedBox(height: 9), UsageWindowView(window: x, style: style, now: now, track: c.divider)],
            if (plan.problem != null) ...[
              const SizedBox(height: 6),
              Text(plan.problem!, style: sans(11.5, color: c.text2, height: 1.4)),
              if (plan.fix != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: KPressable(
                    onTap: () => showSettingsDialog(context, initial: SettingsTab.ai),
                    semanticLabel: plan.fix,
                    builder: (context, hover, focus) => Text(plan.fix!, style: sans(12, weight: FontWeight.w600, color: c.acc)),
                  ),
                ),
              ],
            ],
          ]),
        ),
    ]);
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
    // Agents: those waiting on you, else those running. Tasks: your open ones.
    final waiting = s.agents.runs.where((r) => r.status == AgentStatus.needsYou).length;
    final running = s.agents.runs.where((r) => r.status == AgentStatus.running).length;
    final open = s.tasks.tasks.where((t) => t.mine && t.column != TaskColumn.done).length;
    final badge = switch (view) {
      KumoView.agents when waiting > 0 => '$waiting',
      KumoView.agents when running > 0 => '$running',
      KumoView.tasks when open > 0 => '$open',
      _ => null,
    };
    // Terminal opens Home: shells in ~ that belong to no repository; a
    // worktree's terminals are one click away on the worktree itself.
    final home = view == KumoView.terminal;
    return KPressable(
      onTap: home ? s.showHome : () => s.view = view,
      semanticLabel: home ? 'Terminal in your home folder' : view.label,
      selected: on,
      tooltip: home ? 'Terminal in ~, not tied to a repository  ${view.shortcut}' : '${view.label}  ${view.shortcut}',
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
    // The namespace you're standing in (its worktree is the context) gets
    // a soft outline; the border is always there so nothing shifts.
    final here = !s.inHome && repos.any((r) => s.worktreesOf(r).any(s.isActiveWorktree));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: here ? c.acc.withValues(alpha: 0.04) : null,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: here ? c.acc.withValues(alpha: 0.32) : Colors.transparent),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GestureDetector(
          onSecondaryTapDown: (d) => _openMenu(d.globalPosition),
          child: Semantics(
            label: 'Namespace ${ns.name}, ${repos.length} repos. Right-click for actions',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              height: 30,
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.only(left: 4, right: 2),
              decoration: BoxDecoration(color: _menuOpen || _renaming ? c.tile : null, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                if (_renaming) ...[
                  const SizedBox(width: 18),
                  Icon(KIcons.namespace, size: 14, color: c.text3),
                  const SizedBox(width: 7),
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
                  ),
                ] else
                  // The chevron, icon and name fold or unfold the namespace.
                  Expanded(
                    child: KPressable(
                      onTap: () => s.toggleNamespaceCollapsed(ns.id),
                      semanticLabel: '${ns.collapsed ? 'Expand' : 'Collapse'} ${ns.name}',
                      // The whole name, however narrow the sidebar.
                      tooltip: '${ns.name} · click to ${ns.collapsed ? 'expand' : 'collapse'}',
                      builder: (context, hover, focus) => SizedBox(
                        height: 30,
                        child: Row(children: [
                          Icon(ns.collapsed ? KIcons.chevronRight : KIcons.chevronDown, size: 14, color: hover || focus ? c.text2 : c.text3),
                          const SizedBox(width: 4),
                          Icon(KIcons.namespace, size: 14, color: c.text3),
                          const SizedBox(width: 7),
                          Flexible(child: Text(ns.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, weight: FontWeight.w600, color: hover || focus ? c.text : c.text2))),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(8)),
                            child: Text('${repos.length}', style: sans(10.5, color: c.text3)),
                          ),
                          const Spacer(),
                        ]),
                      ),
                    ),
                  ),
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

/// A worktree that appeared from a terminal or an agent, one click away.
class _ArrivedToast extends StatelessWidget {
  const _ArrivedToast({required this.repo, required this.worktree});
  final Repo repo;
  final Worktree worktree;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final changed = worktree.changed;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 6),
        padding: const EdgeInsets.fromLTRB(10, 6, 3, 6),
        decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('New worktree in ${repo.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text2)),
              Text(changed == 0 ? worktree.branch : '${worktree.branch} · $changed changed', maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3)),
            ]),
          ),
          KPressable(
            onTap: s.openArrivedWorktree,
            semanticLabel: 'Open ${worktree.branch}',
            builder: (context, hover, focus) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: hover || focus ? c.accSoft : null, borderRadius: BorderRadius.circular(6)),
              child: Text('Open', style: sans(12, weight: FontWeight.w600, color: c.acc)),
            ),
          ),
          KIconButton(icon: KIcons.close, label: 'Dismiss', size: 22, iconSize: 12, color: c.text3, onTap: s.dismissArrivedWorktree),
        ]),
      ),
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
          if (notice.action case final action?)
            KPressable(
              onTap: s.undoLast,
              semanticLabel: action,
              builder: (context, hover, focus) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: hover || focus ? c.accSoft : null, borderRadius: BorderRadius.circular(6)),
                child: Text(action, style: sans(12, weight: FontWeight.w600, color: c.acc)),
              ),
            )
          else
            KIconButton(icon: KIcons.close, label: 'Dismiss', size: 22, iconSize: 12, color: c.text3, onTap: s.dismissUndo),
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

  /// (worktree path, what) just copied: its status line says so briefly.
  (String, String)? _copied;
  Timer? _copiedTimer;

  void _flashCopied(Worktree w, String what) {
    _copiedTimer?.cancel();
    setState(() => _copied = (w.path, what));
    _copiedTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = null);
    });
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  void _openMenu(Worktree w, Offset at) {
    setState(() => _menuFor = w.branch);
    showKMenu(
      context,
      position: at,
      onClosed: () {
        if (mounted) setState(() => _menuFor = null);
      },
      builder: (context, close) => _WorktreeMenu(repo: widget.repo, wt: w, close: close, onCopied: (what) => _flashCopied(w, what)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final r = widget.repo;
    return Padding(
      // Projects breathe apart; their worktrees stay close together.
      padding: const EdgeInsets.only(bottom: 14, left: 4),
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
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Tooltip(message: r.name, child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: FontWeight.w600, color: c.text))),
                ),
              ),
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
                // From Docs, Tasks, Git or Agents a worktree takes you to its
                // terminals; in the Terminal view it switches the context.
                onTap: () => s.view == KumoView.terminal ? s.selectWorktree(w.branch, path: w.path) : s.openWorktree(w),
                semanticLabel: '${w.branch}, ${w.note}${w.isMain ? ', principal checkout' : ''}',
                // Long branch names are cut: the whole name and where it lives.
                tooltip: '${w.branch}${w.isMain ? ' · principal checkout' : ''}\n${s.workspace.absolutePathOf(w)}\nRight-click for actions',
                selected: s.isActiveWorktree(w) && !s.inHome,
                builder: (context, hover, focus) {
                  // The worktree you're standing on: a soft accent background.
                  final sel = s.isActiveWorktree(w) && !s.inHome;
                  final menu = _menuFor == w.branch;
                  return Container(
                    margin: const EdgeInsets.only(top: 1),
                    padding: const EdgeInsets.fromLTRB(28, 5, 8, 5),
                    decoration: BoxDecoration(color: menu ? c.tile : (sel ? c.accSoft : (hover ? c.tile : null)), borderRadius: BorderRadius.circular(9)),
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
                            if (s.workspace.arrived.contains(w.path)) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Made outside Kumo (a terminal or an agent)',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  decoration: BoxDecoration(color: c.okSoft, borderRadius: BorderRadius.circular(5)),
                                  child: Text('new', style: sans(9.5, weight: FontWeight.w600, color: c.ok, height: 1.6, letterSpacing: 0.2)),
                                ),
                              ),
                            ],
                          ]),
                          if (_copied?.$1 == w.path)
                            Text('Copied ${_copied!.$2}', style: sans(11, color: c.ok))
                          else
                            Text(w.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: w.tone == WorktreeTone.warn ? c.warn : c.text3)),
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
  const _WorktreeMenu({required this.repo, required this.wt, required this.close, required this.onCopied});
  final Repo repo;
  final Worktree wt;
  final VoidCallback close;

  /// After a copy: what was copied ("full path", "branch name").
  final ValueChanged<String> onCopied;

  @override
  State<_WorktreeMenu> createState() => _WorktreeMenuState();
}

class _WorktreeMenuState extends State<_WorktreeMenu> {
  bool _confirm = false;
  bool _deleteBranch = false;

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
              body: '${running ? '$agent is running here and will be stopped. ' : ''}Runs git worktree remove. '
                  'If it has uncommitted changes, Kumo asks before dropping them.',
              extra: KCheck(
                value: _deleteBranch,
                onChanged: (v) => setState(() => _deleteBranch = v),
                label: 'Also delete branch ${w.branch} (if it’s merged)',
              ),
              confirmLabel: 'Delete',
              onCancel: () => setState(() => _confirm = false),
              onConfirm: () => _do(() => s.deleteWorktree(widget.repo.id, w.branch, deleteBranch: _deleteBranch)),
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
            KMenuItem(
              icon: KIcons.copy,
              label: 'Copy full path',
              onTap: () => _do(() {
                Clipboard.setData(ClipboardData(text: s.workspace.absolutePathOf(w)));
                widget.onCopied('full path');
              }),
            ),
            KMenuItem(
              icon: KIcons.branch,
              label: 'Copy branch name',
              onTap: () => _do(() {
                Clipboard.setData(ClipboardData(text: w.branch));
                widget.onCopied('branch name');
              }),
            ),
            const KMenuDivider(),
            if (isMain)
              const KMenuItem(icon: KIcons.trash, label: 'Delete worktree', note: 'This is the principal checkout, not a worktree.')
            else
              KMenuItem(icon: KIcons.trash, label: 'Delete worktree…', danger: true, onTap: () => setState(() => _confirm = true)),
          ]);
  }
}
