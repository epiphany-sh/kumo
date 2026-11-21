import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/models.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import 'anchored_popover.dart';
import 'controls.dart';
import 'glass.dart';
import 'kicons.dart';
import 'search_marks.dart';

/// Picks one of the workspace's repositories: a search field on top, then
/// the ones picked last and every namespace with its repositories (repos
/// no namespace groups come last). Arrows move, Return picks, Esc closes.
///
/// [value] is a repository id; null is "any" when [allowAny], else nothing
/// picked yet.
class RepoPicker extends StatelessWidget {
  const RepoPicker({super.key, required this.value, required this.onChanged, this.allowAny = false, this.label, this.compact = false});

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowAny;

  /// Shown above, like the other fields; none in a toolbar.
  final String? label;

  /// 28 px high (a toolbar), else 34 like the other fields.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final repo = value == null ? null : s.workspace.repo(value!);
    final ns = repo == null ? null : s.workspace.namespaces.where((n) => n.repos.contains(repo.id)).firstOrNull;
    final height = compact ? 28.0 : 34.0;
    final picker = AnchoredPopover(
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, 6),
      triggerBuilder: (context, toggle, open) => KPressable(
        onTap: toggle,
        semanticLabel: 'Repository: ${repo?.name ?? (allowAny ? 'any' : 'none')}',
        builder: (context, hover, focus) => Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: hover ? Color.alphaBlend(c.tile, c.chip) : c.chip,
            borderRadius: BorderRadius.circular(compact ? 9 : 10),
            border: Border.all(color: open || focus ? c.acc : c.chipBorder),
          ),
          child: Row(children: [
            if (repo != null) ...[
              SourceTile(repo.host, size: compact ? 18 : 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: repo.name, style: mono(compact ? 11.5 : 12, weight: FontWeight.w500, color: c.text)),
                    if (ns != null) TextSpan(text: '  ${ns.name}', style: sans(11.5, color: c.text3)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else ...[
              Icon(KIcons.repo, size: 14, color: c.text3),
              const SizedBox(width: 8),
              Expanded(child: Text(allowAny ? 'Any repository' : 'Pick a repository', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, color: c.text2))),
            ],
            const SizedBox(width: 4),
            Icon(KIcons.chevronUpDown, size: 14, color: c.text3),
          ]),
        ),
      ),
      popoverBuilder: (context, close) => _RepoList(
        value: value,
        allowAny: allowAny,
        onPick: (id) {
          close();
          if (id != null) s.rememberRepo(id);
          onChanged(id);
        },
      ),
    );
    if (label == null) return picker;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label!, style: sans(11, color: c.text3)),
      const SizedBox(height: 4),
      picker,
    ]);
  }
}

/// A row of the list: a repository under a heading, or "any".
class _Row {
  const _Row(this.repo, {this.any = false});
  final Repo? repo;
  final bool any;
  String? get id => any ? null : repo!.id;
}

class _Group {
  _Group(this.key, this.title, this.icon, this.rows, {this.foldable = true});
  final String key;
  final String title;
  final IconData icon;
  final List<_Row> rows;
  final bool foldable;
}

class _RepoList extends StatefulWidget {
  const _RepoList({required this.value, required this.allowAny, required this.onPick});

  final String? value;
  final bool allowAny;
  final ValueChanged<String?> onPick;

  @override
  State<_RepoList> createState() => _RepoListState();
}

class _RepoListState extends State<_RepoList> {
  final _query = TextEditingController();
  final _folded = <String>{};

  /// The row arrows and Return act on, in [_flat] order; -1: none yet.
  int _active = -1;
  List<_Row> _flat = const [];

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() => _active = _query.text.trim().isEmpty ? -1 : 0));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<String> get _words => searchWords(_query.text);

  List<_Group> _groups(AppState s) {
    final words = _words;
    final searching = words.isNotEmpty;
    final namespaces = s.workspace.namespaces;
    bool matches(Repo r, String ns) => words.every((w) => r.name.toLowerCase().contains(w) || ns.toLowerCase().contains(w));
    final groups = <_Group>[];
    if (!searching) {
      if (widget.allowAny) groups.add(_Group('any', '', KIcons.repo, [const _Row(null, any: true)], foldable: false));
      final recent = [for (final id in s.recentRepos.take(3)) s.workspace.repo(id)].whereType<Repo>().toList();
      if (recent.isNotEmpty) groups.add(_Group('recent', 'Recent', KIcons.clock, [for (final r in recent) _Row(r)], foldable: false));
    }
    final grouped = <String>{};
    for (final n in namespaces) {
      final repos = [for (final id in n.repos) s.workspace.repo(id)].whereType<Repo>().toList();
      grouped.addAll(repos.map((r) => r.id));
      final shown = [
        for (final r in repos)
          if (matches(r, n.name)) _Row(r)
      ];
      if (shown.isNotEmpty || (!searching && repos.isEmpty)) groups.add(_Group('ns:${n.id}', n.name, KIcons.namespace, shown));
    }
    final loose = [
      for (final r in s.workspace.repos)
        if (!grouped.contains(r.id) && matches(r, '')) _Row(r)
    ];
    if (loose.isNotEmpty) groups.add(_Group('loose', 'Not in a namespace', KIcons.folder, loose));
    return groups;
  }

  bool _open(_Group g) => !g.foldable || _words.isNotEmpty || !_folded.contains(g.key);

  void _move(int delta) {
    if (_flat.isEmpty) return;
    setState(() {
      final from = _active < 0 ? _flat.indexWhere((r) => r.id == widget.value) : _active;
      _active = ((from < 0 ? (delta > 0 ? -1 : 0) : from) + delta) % _flat.length;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      _move(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_active >= 0 && _active < _flat.length) widget.onPick(_flat[_active].id);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final groups = _groups(s);
    final flat = <_Row>[];
    for (final g in groups) {
      if (_open(g)) flat.addAll(g.rows);
    }
    _flat = flat;
    final total = s.workspace.repos.length;
    final matching = {
      for (final r in flat)
        if (!r.any) r.id
    }.length;
    final searching = _words.isNotEmpty;
    var index = 0;
    return GlassOverlay(
      width: 380,
      blur: false,
      radius: 16,
      padding: EdgeInsets.zero,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(color: c.tile, border: Border(bottom: BorderSide(color: c.divider))),
          child: Row(children: [
            Icon(KIcons.search, size: 15, color: c.text3),
            const SizedBox(width: 8),
            Expanded(
              child: Focus(
                onKeyEvent: _onKey,
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  style: sans(13, color: c.text),
                  cursorColor: c.acc,
                  decoration: InputDecoration.collapsed(hintText: 'Search repositories and namespaces', hintStyle: sans(13, color: c.text3)),
                ),
              ),
            ),
            if (_query.text.isNotEmpty) KIconButton(icon: KIcons.close, label: 'Clear search', size: 24, iconSize: 12, onTap: _query.clear),
          ]),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: groups.isEmpty || (searching && matching == 0)
              ? _empty(c, searching)
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(6),
                  children: [
                    for (final g in groups) ...[
                      if (g.title.isNotEmpty) _heading(c, g),
                      if (_open(g))
                        for (final r in g.rows) _row(c, r, index++),
                    ],
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
          decoration: BoxDecoration(color: c.tile, border: Border(top: BorderSide(color: c.divider))),
          child: Row(children: [
            Expanded(
              child: Text(
                searching ? '$matching of $total repositories' : '$total repositories in ${s.workspace.namespaces.length} namespaces',
                style: sans(11, color: c.text3),
              ),
            ),
            const Kbd('↑'),
            const SizedBox(width: 3),
            const Kbd('↓'),
            const SizedBox(width: 5),
            Text('move', style: sans(11, color: c.text3)),
            const SizedBox(width: 10),
            const Kbd('↩'),
            const SizedBox(width: 5),
            Text('pick', style: sans(11, color: c.text3)),
          ]),
        ),
      ]),
    );
  }

  Widget _empty(KumoPalette c, bool searching) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(searching ? 'No repository matches “${_query.text.trim()}”' : 'No repositories yet', style: sans(13, weight: FontWeight.w600, color: c.text)),
          const SizedBox(height: 4),
          Text(
            searching ? 'Search looks at repository and namespace names.' : 'Put a repository in a namespace from the sidebar to pick it here.',
            textAlign: TextAlign.center,
            style: sans(12, color: c.text3, height: 1.45),
          ),
        ]),
      );

  Widget _heading(KumoPalette c, _Group g) {
    final open = _open(g);
    final searching = _words.isNotEmpty;
    final head = Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      child: Row(children: [
        if (g.foldable && !searching) ...[
          AnimatedRotation(turns: open ? 0.25 : 0, duration: const Duration(milliseconds: 120), child: Icon(KIcons.chevronRight, size: 11, color: c.text3)),
          const SizedBox(width: 5),
        ],
        Icon(g.icon, size: 12, color: c.text3),
        const SizedBox(width: 6),
        Flexible(
            child: Text(g.key.startsWith('ns:') ? g.title.toUpperCase() : g.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, weight: FontWeight.w600, color: c.text3, letterSpacing: 0.4))),
        if (g.foldable) ...[const SizedBox(width: 6), Text('${g.rows.length}', style: sans(11, color: c.text3))],
      ]),
    );
    if (!g.foldable || searching) return head;
    return KPressable(
      onTap: () => setState(() => open ? _folded.add(g.key) : _folded.remove(g.key)),
      semanticLabel: '${open ? 'Fold' : 'Unfold'} ${g.title}',
      builder: (context, hover, focus) => head,
    );
  }

  Widget _row(KumoPalette c, _Row r, int at) {
    final selected = r.id == widget.value;
    final active = at == _active;
    final repo = r.repo;
    return MouseRegion(
      onEnter: (_) {
        if (_active != at) setState(() => _active = at);
      },
      child: KPressable(
        onTap: () => widget.onPick(r.id),
        semanticLabel: r.any ? 'Any repository' : repo!.name,
        selected: selected,
        builder: (context, hover, focus) => Container(
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? c.accSoft : (active || hover ? c.tile : null),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            if (r.any) const SourceTile('∗', size: 22) else SourceTile(repo!.host, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (r.any) Text('Any repository', style: sans(12.5, weight: FontWeight.w500, color: c.text)) else markedText(c, repo!.name, _words, mono(12.5, weight: FontWeight.w500, color: c.text)),
                Text(
                  r.any ? 'Not tied to one: you pick when you run it' : _meta(repo!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sans(11, color: c.text3),
                ),
              ]),
            ),
            if (selected) Icon(KIcons.check, size: 14, color: c.acc),
          ]),
        ),
      ),
    );
  }

  static String _meta(Repo r) {
    final n = r.worktrees.length;
    return n == 1 ? '1 worktree' : '$n worktrees';
  }
}
