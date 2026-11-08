part of 'git_screen.dart';

// ---------------------------------------------------------------------------
// Commits: which branch, whose, and what each one changed
// ---------------------------------------------------------------------------

/// `''` is main, `'*'` every branch, anything else one branch.
const _allBranchesKey = '*';

/// The commits the panel lists for [branch] by [author] (null: anyone): a
/// branch's own first, then main's history under them (where it started).
({List<RepoCommit> own, List<RepoCommit> below}) _commitsFor(RepoActivitySource source, String branch, String? author) {
  bool by(RepoCommit k) => author == null || k.author == author;
  if (branch.isEmpty) return (own: [for (final k in source.commits()) if (by(k)) k], below: const []);
  final all = source.commits(allBranches: true);
  if (branch == _allBranchesKey) return (own: [for (final k in all) if (by(k)) k], below: const []);
  return (
    own: [for (final k in all) if (k.branch == branch && by(k)) k],
    below: [for (final k in source.commits()) if (by(k)) k],
  );
}

/// The host's web page of the repository (`https://github.com/org/repo`),
/// from a pull request's or release's link; null when there's none yet.
String? _webBaseOf(RepoActivitySource source) {
  for (final u in [for (final p in source.pullRequests) p.url, for (final r in source.releases) r.url]) {
    final m = RegExp(r'^(https?://[^/]+/.+?)/(?:pull|-/merge_requests|pull-requests|releases|-/releases|src)/').firstMatch(u);
    if (m != null) return m[1];
  }
  return null;
}

String? _commitUrl(RepoActivitySource source, String sha) {
  final base = _webBaseOf(source);
  if (base == null) return null;
  return switch (source.repo.host) {
    'GL' => '$base/-/commit/$sha',
    'BB' => '$base/commits/$sha',
    _ => '$base/commit/$sha',
  };
}

class _CommitsSection extends StatelessWidget {
  const _CommitsSection({required this.source, required this.branch, required this.author, required this.onBranch, required this.onAuthor, required this.onOpen});
  final RepoActivitySource source;
  final String branch;
  final String? author;
  final ValueChanged<String> onBranch;
  final ValueChanged<String?> onAuthor;
  final void Function(List<RepoCommit> shown, int index) onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final main = source.mainBranch;
    final me = source.currentUser;
    final error = source.error;
    final (:own, :below) = _commitsFor(source, branch, author);
    final shown = [...own, ...below];
    final one = branch.isNotEmpty && branch != _allBranchesKey;
    final branchCount = {for (final k in own) if (k.branch case final b?) b}.length;
    final rows = <Widget>[];
    if (shown.isEmpty) {
      rows.add(_Note(source.loading
          ? 'Loading history…'
          : error != null
              ? 'Couldn’t read the history: $error'
              : author != null
                  ? '$author has no commits ${one ? 'on $branch' : (branch.isEmpty ? 'on $main' : 'here')}.'
                  : 'No commits on ${one ? branch : main} yet.'));
    }
    for (var i = 0; i < shown.length; i++) {
      if (one && i == own.length && below.isNotEmpty) {
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
          child: Row(children: [
            Icon(KIcons.branch, size: 12, color: c.text3),
            const SizedBox(width: 6),
            Text(own.isEmpty ? 'No commits of its own yet. Branched from $main:' : 'Branched from $main', style: sans(11, color: c.text3)),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: c.divider)),
          ]),
        ));
      }
      final k = shown[i];
      rows.add(Opacity(
        opacity: i >= own.length ? 0.72 : 1,
        child: _CommitRow(
          commit: k,
          mine: me != null && k.author == me,
          showBranch: branch == _allBranchesKey,
          onTap: () => onOpen(shown, i),
        ),
      ));
    }
    final subtitle = [
      if (branch.isEmpty) source.repo.name else if (branch == _allBranchesKey) '$main + $branchCount ${branchCount == 1 ? 'branch' : 'branches'}' else '${own.length} ahead of $main',
      if (author != null) 'by $author',
    ].join(' · ');
    return _Panel(
      icon: Icons.commit,
      title: 'Commits',
      subtitle: subtitle,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Builder(
          builder: (anchor) => _FilterButton(
            icon: KIcons.branch,
            label: branch.isEmpty ? main : (branch == _allBranchesKey ? 'All branches' : branch),
            monospace: branch != _allBranchesKey,
            active: branch.isNotEmpty,
            semanticLabel: 'Branch',
            onTap: () => _openBranchMenu(anchor),
          ),
        ),
        const SizedBox(width: 6),
        Builder(
          builder: (anchor) => _FilterButton(
            icon: KIcons.people,
            avatar: author,
            me: author != null && author == me,
            label: author == null ? 'Everyone' : (author == me ? '$author (you)' : author!),
            active: author != null,
            semanticLabel: 'Author',
            onTap: () => _openAuthorMenu(anchor),
          ),
        ),
        if (branch.isNotEmpty || author != null) ...[
          const SizedBox(width: 2),
          KIconButton(
            icon: KIcons.close,
            label: 'Back to $main, everyone',
            size: 24,
            iconSize: 13,
            color: c.text3,
            onTap: () {
              onBranch('');
              onAuthor(null);
            },
          ),
        ],
      ]),
      child: ListView(padding: EdgeInsets.zero, children: rows),
    );
  }

  void _openBranchMenu(BuildContext anchor) {
    final main = source.mainBranch;
    final can = source.allBranchesSupported;
    final all = can ? source.commits(allBranches: true) : const <RepoCommit>[];
    int count(String b) => all.where((k) => k.branch == b).length;
    final others = [for (final b in source.branches) if (!b.isMain && b.name != main) b];
    showKMenu(
      anchor,
      position: belowOf(anchor),
      alignRight: true,
      builder: (ctx, close) {
        Widget item(String key, String label, String sub, IconData icon, {bool monospace = true, String? count, String? note}) => _BranchItem(
              label: label,
              sub: sub,
              icon: icon,
              monospace: monospace,
              count: count,
              selected: branch == key,
              note: note,
              onTap: note != null
                  ? null
                  : () {
                      close();
                      onBranch(key);
                    },
            );
        return KMenuPanel(width: 320, children: [
          item('', main, 'The default branch', KIcons.branch, count: '${source.commits().length}'),
          item(_allBranchesKey, 'All branches', '$main and ${others.length} more, newest first', KIcons.cluster,
              monospace: false, count: can ? '${all.length}' : null, note: can ? null : 'Needs a newer kumod'),
          if (others.isNotEmpty) ...[
            const KMenuDivider(),
            Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 2), child: Text('BRANCHES', style: microLabel(ctx.c))),
            for (final b in others)
              item(
                b.name,
                b.name,
                [if (b.lastAuthor case final a?) a, if (b.vsMain case final v?) v, if (b.worktree != null) 'worktree'].join(' · '),
                b.worktree != null ? KIcons.terminal : KIcons.branch,
                count: can ? '${count(b.name)}' : null,
                note: can ? null : 'Needs a newer kumod',
              ),
          ],
        ]);
      },
    );
  }

  void _openAuthorMenu(BuildContext anchor) {
    final me = source.currentUser;
    // Who has commits where the branch filter points (a branch's log includes main's).
    final (:own, :below) = _commitsFor(source, branch, null);
    final counts = <String, int>{};
    for (final k in [...own, ...below]) {
      counts[k.author] = (counts[k.author] ?? 0) + 1;
    }
    final people = counts.keys.toList()..sort((a, b) => a == me ? -1 : (b == me ? 1 : a.toLowerCase().compareTo(b.toLowerCase())));
    showKMenu(
      anchor,
      position: belowOf(anchor),
      alignRight: true,
      builder: (ctx, close) => KMenuPanel(width: 240, children: [
        _AuthorItem(
          name: null,
          label: 'Everyone',
          count: own.length + below.length,
          selected: author == null,
          onTap: () {
            close();
            onAuthor(null);
          },
        ),
        for (final p in people)
          _AuthorItem(
            name: p,
            me: p == me,
            label: p == me ? '$p (you)' : p,
            count: counts[p] ?? 0,
            selected: author == p,
            onTap: () {
              close();
              onAuthor(p);
            },
          ),
      ]),
    );
  }
}

/// The branch / author pickers in the commits header.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.icon, required this.label, required this.active, required this.onTap, required this.semanticLabel, this.monospace = false, this.avatar, this.me = false});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool monospace;
  final String? avatar;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final avatar = this.avatar;
    return KPressable(
      onTap: onTap,
      semanticLabel: '$semanticLabel: $label',
      tooltip: semanticLabel == 'Branch' ? 'Which branch’s commits' : 'Whose commits',
      builder: (context, hover, focus) => Container(
        height: 26,
        constraints: const BoxConstraints(maxWidth: 220),
        padding: EdgeInsets.only(left: avatar != null ? 4 : 9, right: 6),
        decoration: BoxDecoration(
          color: active ? c.accSoft : (hover ? c.chip : c.tile),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: focus || active ? c.acc : const Color(0x00000000)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (avatar != null) _Avatar(avatar, me: me) else Icon(icon, size: 13, color: c.text3),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: monospace ? mono(11.5, color: c.text) : sans(12, color: c.text)),
          ),
          const SizedBox(width: 4),
          Icon(KIcons.chevronDown, size: 13, color: c.text3),
        ]),
      ),
    );
  }
}

class _BranchItem extends StatelessWidget {
  const _BranchItem({required this.label, required this.sub, required this.icon, required this.selected, required this.onTap, this.monospace = true, this.count, this.note});
  final String label;
  final String sub;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool monospace;
  final String? count;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = onTap != null;
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      tooltip: note,
      builder: (context, hover, focus) => Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: enabled && (hover || focus) ? c.tile : null, borderRadius: BorderRadius.circular(7)),
        child: Row(children: [
          Icon(icon, size: 14, color: enabled ? c.text2 : c.text3),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: monospace ? mono(12, color: enabled ? c.text : c.text3) : sans(12.5, weight: FontWeight.w500, color: enabled ? c.text : c.text3)),
              if (sub.isNotEmpty || note != null)
                Text(note ?? sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3)),
            ]),
          ),
          if (count != null) ...[const SizedBox(width: 8), Text(count!, style: sans(11, color: c.text3))],
          const SizedBox(width: 8),
          SizedBox(width: 14, child: selected ? Icon(KIcons.check, size: 14, color: c.acc) : null),
        ]),
      ),
    );
  }
}

class _AuthorItem extends StatelessWidget {
  const _AuthorItem({required this.name, required this.label, required this.count, required this.selected, required this.onTap, this.me = false});
  final String? name;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final name = this.name;
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      builder: (context, hover, focus) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(7)),
        child: Row(children: [
          if (name == null)
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.tile, shape: BoxShape.circle),
              child: Icon(KIcons.people, size: 12, color: c.text2),
            )
          else
            _Avatar(name, me: me, size: 20),
          const SizedBox(width: 9),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: FontWeight.w500, color: c.text))),
          Text('$count', style: sans(11, color: c.text3)),
          const SizedBox(width: 8),
          SizedBox(width: 14, child: selected ? Icon(KIcons.check, size: 14, color: c.acc) : null),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The commit sheet
// ---------------------------------------------------------------------------

/// What [commits]`[index]` changed, file by file, over the Git view; ↑/↓
/// (or k/j) move to the newer / older commit without closing it.
Future<void> _showCommitSheet(BuildContext context, RepoActivitySource source, List<RepoCommit> commits, int index) {
  final c = context.c;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: c.isDark ? const Color(0x66000000) : const Color(0x33141428),
    transitionDuration: const Duration(milliseconds: 140),
    transitionBuilder: (context, anim, _, child) => FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: child),
    pageBuilder: (context, _, __) => Padding(
      padding: const EdgeInsets.fromLTRB(28, 64, 28, 28),
      child: Material(type: MaterialType.transparency, child: CommitSheet(source: source, commits: commits, index: index)),
    ),
  );
}

/// The sheet's content (public for tests).
class CommitSheet extends StatefulWidget {
  const CommitSheet({super.key, required this.source, required this.commits, required this.index});
  final RepoActivitySource source;
  final List<RepoCommit> commits;
  final int index;

  @override
  State<CommitSheet> createState() => _CommitSheetState();
}

class _CommitSheetState extends State<CommitSheet> {
  late int _index = widget.index;
  final _details = <String, Future<CommitDetail>>{};
  final _folded = <String>{};
  final _fileKeys = <String, GlobalKey>{};
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'commit sheet');
  String? _current;
  String? _note;

  /// Lines per file before "View file" takes over.
  static const _maxLines = 400;

  RepoCommit get commit => widget.commits[_index];

  Future<CommitDetail> _detail(RepoCommit k) => _details.putIfAbsent(k.sha, () => widget.source.commitDetail(k));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.commits.length) return;
    setState(() {
      _index = next;
      _current = null;
      _note = null;
      _fileKeys.clear();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _jumpTo(String path) {
    setState(() => _current = path);
    final ctx = _fileKeys[path]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _say(String note) => setState(() => _note = note);

  Future<void> _ask(AppState s) async {
    final k = commit;
    if (!s.agents.live) return _say('Agents run once Kumo’s engine is connected.');
    if (s.agents.connected.isEmpty) return _say('Connect an agent in Settings › AI agents first.');
    final main = s.worktreesOf(widget.source.repo).where((w) => w.isMain).firstOrNull;
    final dir = main == null ? widget.source.repo.path : s.workspace.absolutePathOf(main);
    if (dir == null) return _say('${widget.source.repo.name} has no checkout on this Mac.');
    final run = await s.agents.start(
      worktreePath: dir,
      prompt: commitExplainPrompt(repoName: widget.source.repo.name, sha: k.sha, subject: k.subject),
      title: '${k.shortSha} · Explain',
    );
    if (!mounted) return;
    if (run == null) return _say(s.agents.error ?? 'The agent didn’t start.');
    Navigator.of(context).maybePop();
    s.openTerminal(run.terminalId, title: run.title, agent: true, directory: run.worktreePath);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final k = commit;
    final url = _commitUrl(widget.source, k.sha);
    final me = widget.source.currentUser;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.keyK): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.keyJ): () => _go(1),
      },
      child: Focus(
        focusNode: _focus,
        child: GlassPanel(
          padding: EdgeInsets.zero,
          fill: c.panelStrong,
          child: FutureBuilder<CommitDetail>(
            // Keyed: the previous commit's files never show under this one.
            key: ValueKey(k.sha),
            future: _detail(k),
            builder: (context, snap) {
              final d = snap.data;
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _header(context, s, k, d, url, me),
                Container(height: 1, color: c.divider),
                Expanded(child: _body(context, snap)),
              ]);
            },
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppState s, RepoCommit k, CommitDetail? d, String? url, String? me) {
    final c = context.c;
    final body = d?.body.trim() ?? '';
    final parent = d?.parents.firstOrNull;
    final note = _note;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          KIconButton(icon: KIcons.chevronUp, label: 'Newer commit (↑)', size: 28, iconSize: 15, onTap: _index > 0 ? () => _go(-1) : null),
          const SizedBox(width: 2),
          KIconButton(icon: KIcons.chevronDown, label: 'Older commit (↓)', size: 28, iconSize: 15, onTap: _index < widget.commits.length - 1 ? () => _go(1) : null),
          const SizedBox(width: 8),
          KPressable(
            onTap: () {
              Clipboard.setData(ClipboardData(text: k.sha));
              _say('Copied ${k.sha}');
            },
            semanticLabel: 'Copy ${k.sha}',
            tooltip: 'Copy ${k.sha}',
            builder: (context, hover, focus) => Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: hover ? c.chip : c.tile, borderRadius: BorderRadius.circular(7)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(k.shortSha, style: mono(11.5, color: c.text2)),
                const SizedBox(width: 5),
                Icon(KIcons.copy, size: 12, color: c.text3),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(k.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(15, weight: FontWeight.w600, color: c.text))),
          const SizedBox(width: 10),
          KButton(label: 'Ask an agent', icon: KIcons.sparkle, height: 28, fontSize: 12, onTap: () => _ask(s)),
          const SizedBox(width: 6),
          KIconButton(icon: KIcons.external, label: url == null ? 'No address on the host yet' : 'Open on ${_hostName(widget.source.repo.host)}', onTap: url == null ? null : () => openUrl(url)),
          Builder(
            builder: (anchor) => KIconButton(
              icon: KIcons.more,
              label: 'More for ${k.shortSha}',
              onTap: () => showKMenu(
                anchor,
                position: belowOf(anchor),
                alignRight: true,
                builder: (ctx, close) => KMenuPanel(width: 240, children: [
                  KMenuItem(
                    icon: KIcons.copy,
                    label: 'Copy SHA',
                    onTap: () {
                      close();
                      Clipboard.setData(ClipboardData(text: k.sha));
                      _say('Copied ${k.sha}');
                    },
                  ),
                  KMenuItem(
                    icon: KIcons.link,
                    label: 'Copy link',
                    onTap: url == null
                        ? null
                        : () {
                            close();
                            Clipboard.setData(ClipboardData(text: url));
                            _say('Copied the link to ${k.shortSha}');
                          },
                  ),
                  const KMenuDivider(),
                  KMenuItem(
                    icon: KIcons.add,
                    label: 'New worktree from here…',
                    onTap: () {
                      close();
                      Clipboard.setData(ClipboardData(text: k.sha));
                      Navigator.of(context).maybePop();
                      s.requestNewWorktree();
                      s.notify('Copied ${k.shortSha}: paste it as the base');
                    },
                  ),
                ]),
              ),
            ),
          ),
          KIconButton(icon: KIcons.close, label: 'Close (esc)', onTap: () => Navigator.of(context).maybePop()),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 66),
          child: Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              _Avatar(k.author, me: k.author == me),
              const SizedBox(width: 6),
              Text(k.author == me ? '${k.author} (you)' : k.author, style: sans(12, color: c.text2)),
            ]),
            Tooltip(message: (d?.time ?? k.time).toLocal().toString().substring(0, 16), child: Text(_rel(k.time), style: sans(12, color: c.text3))),
            if (k.prRef case final pr?) _Chip(pr, color: c.acc, background: c.accSoft),
            _Chip(k.branch ?? widget.source.mainBranch, color: c.text2, background: c.tile),
            if (parent != null) Text.rich(TextSpan(children: [TextSpan(text: 'parent ', style: sans(12, color: c.text3)), TextSpan(text: parent, style: mono(11, color: c.text3))])),
            if (d != null)
              Text.rich(TextSpan(children: [
                TextSpan(text: '+${d.added}', style: mono(11, color: c.ok)),
                TextSpan(text: ' −${d.deleted}', style: mono(11, color: c.err)),
                TextSpan(text: ' in ${d.files.length} ${d.files.length == 1 ? 'file' : 'files'}', style: sans(12, color: c.text3)),
              ])),
          ]),
        ),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 66),
            child: Text(body, maxLines: 6, overflow: TextOverflow.ellipsis, style: sans(12.5, color: c.text2, height: 1.5)),
          ),
        ],
        if (note != null) ...[
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.only(left: 66), child: Text(note, style: sans(12, color: c.acc))),
        ],
      ]),
    );
  }

  Widget _body(BuildContext context, AsyncSnapshot<CommitDetail> snap) {
    final c = context.c;
    if (snap.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('${snap.error}', textAlign: TextAlign.center, style: sans(12.5, color: c.text2, height: 1.5)),
        ),
      );
    }
    final d = snap.data;
    if (d == null) return Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.acc)));
    if (d.files.isEmpty) return Center(child: Text('No file changes (a merge, or an empty commit).', style: sans(12.5, color: c.text3)));
    final current = _current ?? d.files.first.path;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        width: 270,
        child: ListView(padding: const EdgeInsets.all(8), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
            child: Text('${d.files.length} ${d.files.length == 1 ? 'FILE' : 'FILES'}', style: microLabel(c)),
          ),
          for (final f in d.files) _FileListItem(file: f, selected: f.path == current, onTap: () => _jumpTo(f.path)),
        ]),
      ),
      Container(width: 1, color: c.divider),
      Expanded(
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final f in d.files) ...[
              _FileDiff(
                key: _fileKeys.putIfAbsent(f.path, GlobalKey.new),
                file: f,
                selected: f.path == current,
                folded: _folded.contains(f.path),
                maxLines: _maxLines,
                onFold: () => setState(() => _folded.contains(f.path) ? _folded.remove(f.path) : _folded.add(f.path)),
              ),
              const SizedBox(height: 12),
            ],
          ]),
        ),
      ),
    ]);
  }
}

Color _kindColor(KumoPalette c, CommitFileKind k) => switch (k) {
      CommitFileKind.added => c.ok,
      CommitFileKind.deleted => c.err,
      CommitFileKind.renamed => c.acc,
      CommitFileKind.modified => c.warn,
    };

class _FileListItem extends StatelessWidget {
  const _FileListItem({required this.file, required this.selected, required this.onTap});
  final CommitFile file;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final f = file;
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: f.path,
      tooltip: f.path,
      builder: (context, hover, focus) => Container(
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? c.navActive : (hover ? c.tile : null),
          borderRadius: BorderRadius.circular(8),
          border: focus ? Border.all(color: c.acc, width: 1.5) : null,
        ),
        child: Row(children: [
          SizedBox(width: 12, child: Text(f.kind.letter, style: mono(10.5, weight: FontWeight.w700, color: _kindColor(c, f.kind)))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, color: c.text)),
              if (f.dir.isNotEmpty) Text(f.dir, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(10.5, color: c.text3)),
            ]),
          ),
          const SizedBox(width: 6),
          Text.rich(TextSpan(children: [
            TextSpan(text: '+${f.added}', style: mono(10.5, color: c.ok)),
            TextSpan(text: ' −${f.deleted}', style: mono(10.5, color: c.err)),
          ])),
        ]),
      ),
    );
  }
}

class _FileDiff extends StatelessWidget {
  const _FileDiff({super.key, required this.file, required this.selected, required this.folded, required this.maxLines, required this.onFold});
  final CommitFile file;
  final bool selected;
  final bool folded;
  final int maxLines;
  final VoidCallback onFold;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dc = DiffColors.of(c);
    final f = file;
    final rows = <Widget>[];
    var shown = 0, total = 0;
    for (final h in f.hunks) {
      total += h.lines.length + 1;
      if (shown >= maxLines) continue;
      rows.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        color: c.accSoft,
        child: Text(h.header, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3)),
      ));
      shown++;
      for (final l in h.lines) {
        if (shown >= maxLines) break;
        shown++;
        final (bg, sign, fg) = switch (l.kind) {
          DiffKind.added => (dc.add, '+', c.ok),
          DiffKind.deleted => (dc.del, '−', c.err),
          DiffKind.context => (const Color(0x00000000), '', c.text),
        };
        rows.add(Container(
          color: bg,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 44, child: Text(l.oldNo?.toString() ?? '', textAlign: TextAlign.right, style: mono(11, color: c.text3))),
            SizedBox(width: 44, child: Text(l.newNo?.toString() ?? '', textAlign: TextAlign.right, style: mono(11, color: c.text3))),
            SizedBox(width: 22, child: Text(sign, textAlign: TextAlign.center, style: mono(11.5, color: fg))),
            Expanded(child: Text(l.text.replaceAll('\t', '    '), softWrap: false, overflow: TextOverflow.fade, style: mono(11.5, color: l.kind == DiffKind.context ? c.text : fg, height: 1.6))),
          ]),
        ));
      }
    }
    final more = total - shown;
    return Container(
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? c.acc : c.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 34,
          padding: const EdgeInsets.only(left: 4, right: 10),
          color: c.tile,
          child: Row(children: [
            KIconButton(icon: folded ? KIcons.chevronRight : KIcons.chevronDown, label: folded ? 'Unfold ${f.name}' : 'Fold ${f.name}', size: 24, iconSize: 14, color: c.text3, onTap: onFold),
            const SizedBox(width: 4),
            Text(f.kind.letter, style: mono(10.5, weight: FontWeight.w700, color: _kindColor(c, f.kind))),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  if (f.dir.isNotEmpty) TextSpan(text: '${f.dir}/', style: mono(12, color: c.text3)),
                  TextSpan(text: f.name, style: mono(12, color: c.text)),
                  if (f.oldPath case final from?) TextSpan(text: '  ← $from', style: mono(12, color: c.text3)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text.rich(TextSpan(children: [
              TextSpan(text: '+${f.added}', style: mono(11, color: c.ok)),
              TextSpan(text: ' −${f.deleted}', style: mono(11, color: c.err)),
            ])),
          ]),
        ),
        if (!folded) ...[
          if (f.binary)
            Padding(padding: const EdgeInsets.all(12), child: Text('Binary file', style: sans(12, color: c.text3)))
          else if (f.hunks.isEmpty)
            Padding(padding: const EdgeInsets.all(12), child: Text(f.kind == CommitFileKind.renamed ? 'Renamed, content unchanged' : 'No changes to show', style: sans(12, color: c.text3)))
          else
            Padding(padding: const EdgeInsets.only(top: 2, bottom: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows)),
          if (more > 0) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: Text('$more more lines', style: sans(11.5, color: c.text3))),
        ],
      ]),
    );
  }
}
