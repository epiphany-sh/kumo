part of 'git_screen.dart';

// ---------------------------------------------------------------------------
// Releases & tags
// ---------------------------------------------------------------------------

String? _compareUrl(RepoActivitySource source, String from, String to) {
  final base = _webBaseOf(source);
  if (base == null) return null;
  return switch (source.repo.host) {
    'GL' => '$base/-/compare/$from...$to',
    'BB' => '$base/branches/compare/$to%0D$from',
    _ => '$base/compare/$from...$to',
  };
}

enum _ReleaseFilter { all, releases, tags }

/// The repository's releases and bare tags, newest first, and the one
/// picked: its notes, what changed since the release before it, and what
/// can be done with it.
class _ReleasesView extends StatefulWidget {
  const _ReleasesView({super.key, required this.source});
  final RepoActivitySource source;

  @override
  State<_ReleasesView> createState() => _ReleasesViewState();
}

class _ReleasesViewState extends State<_ReleasesView> {
  String? _selected;
  _ReleaseFilter _filter = _ReleaseFilter.all;
  final _ranges = <String, Future<ReleaseRange>>{};
  bool _menuOpen = false;

  RepoActivitySource get source => widget.source;

  Future<ReleaseRange> _rangeOf(List<RepoRelease> all, int i) {
    final prev = previousReleaseIndex(all, i);
    final since = prev == null ? null : all[prev];
    final key = '${all[i].tag}…${since?.tag}';
    return _ranges.putIfAbsent(key, () => source.releaseRange(all[i], since: since));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!source.releasesSupported) {
      return Section(
        child: Center(child: Text('Kumo’s engine can’t list tags and releases yet: update kumod.', style: sans(12.5, color: c.text3))),
      );
    }
    final all = source.releases;
    final latest = latestReleaseIndex(all);
    final idx = all.indexWhere((r) => r.tag == _selected);
    final selected = idx >= 0 ? idx : (latest ?? (all.isEmpty ? -1 : 0));
    final shown = [
      for (var i = 0; i < all.length; i++)
        if (_filter == _ReleaseFilter.all || (_filter == _ReleaseFilter.tags) == all[i].isTag) i,
    ];
    final nTags = all.where((r) => r.isTag).length;
    final nReleases = all.length - nTags;

    // Tags still list when the host can't be read: without this they'd all
    // look like tags with no release.
    final problem = source.releasesProblem;
    final provider = CiProvider.ofHost(source.repo.host);
    final why = problem == null || provider == null ? null : describeCiProblem(problem, provider, repo: source.repo.name);
    final list = _Panel(
      icon: KIcons.tag,
      title: 'Releases & tags',
      subtitle: all.isEmpty ? '' : '$nReleases ${nReleases == 1 ? 'release' : 'releases'}${nTags == 0 ? '' : ' · $nTags ${nTags == 1 ? 'tag' : 'tags'} only'}',
      trailing: ToolbarSegments<_ReleaseFilter>(
        label: 'Show',
        value: _filter,
        onChanged: (f) => setState(() => _filter = f),
        items: const [(_ReleaseFilter.all, 'All', null, null), (_ReleaseFilter.releases, 'Releases', null, null), (_ReleaseFilter.tags, 'Tags only', null, null)],
      ),
      child: all.isEmpty
          ? _Note(why != null ? '${why.$1}. ${why.$2}' : source.releasesLoading
              ? 'Loading tags…'
              : source.repo.host == 'BB'
                  ? '${source.repo.name} has no tags yet. Bitbucket has tags but no releases: tag a version and it shows up here.'
                  : '${source.repo.name} has no tags yet. Tag a version and create its release: it shows up here, and an agent can write its notes from the project.')
          : ListView(padding: EdgeInsets.zero, children: [
              if (why != null) _Note('Releases couldn’t be read, so these may have one: ${why.$1}. ${why.$2}'),
              if (shown.isEmpty) _Note(_filter == _ReleaseFilter.tags ? 'Every tag has its release.' : 'Only bare tags here.'),
              for (final i in shown)
                _ReleaseRow(
                  release: all[i],
                  latest: i == latest,
                  first: i == all.length - 1 && source.olderReleases == 0 && previousReleaseIndex(all, i) == null,
                  selected: i == selected,
                  since: previousReleaseIndex(all, i) == null ? null : all[previousReleaseIndex(all, i)!].tag,
                  onTap: () => setState(() => _selected = all[i].tag),
                ),
              if (source.olderReleases > 0 && _filter != _ReleaseFilter.tags) _Note('${source.olderReleases} older releases on ${_hostName(source.repo.host)}'),
            ]),
    );
    final detail = selected < 0
        ? Section(child: Center(child: Text('Nothing tagged yet.', style: sans(12.5, color: c.text3))))
        : _ReleaseDetail(
            source: source,
            releases: all,
            index: selected,
            latest: selected == latest,
            range: _rangeOf(all, selected),
            menuOpen: _menuOpen,
            onMenu: (open) {
              if (mounted) setState(() => _menuOpen = open);
            },
          );
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 1000) {
        return ListView(padding: EdgeInsets.zero, children: [
          SizedBox(height: 360, child: list),
          const SizedBox(height: 10),
          SizedBox(height: 620, child: detail),
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(flex: 8, child: list),
        const SizedBox(width: 10),
        Expanded(flex: 13, child: detail),
      ]);
    });
  }
}

(String, Color, Color)? _badgeOf(KumoPalette c, RepoRelease r, {required bool latest, bool first = false}) => switch (r.kind) {
      _ when latest => ('Latest', c.ok, c.okSoft),
      ReleaseKind.preRelease => ('Pre-release', c.warn, c.warnSoft),
      ReleaseKind.draft => ('Draft', c.text2, c.tile),
      ReleaseKind.tagOnly => ('Tag only', c.text2, c.tile),
      _ when first => ('First', c.acc, c.accSoft),
      _ => null,
    };

class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({required this.release, required this.latest, required this.first, required this.selected, required this.since, required this.onTap});
  final RepoRelease release;
  final bool latest;
  final bool first;
  final bool selected;
  final String? since;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = release;
    final badge = _badgeOf(c, r, latest: latest, first: first);
    final firstLine = r.notes.split('\n').where((l) => l.startsWith('- ')).map((l) => l.substring(2).replaceAll('`', '')).firstOrNull;
    final name = r.isTag ? 'No release' : (r.name.isNotEmpty ? r.name : (firstLine ?? 'No release notes'));
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: r.tag,
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.navActive : (hover ? c.tile : null),
          borderRadius: BorderRadius.circular(12),
          border: focus ? Border.all(color: c.acc, width: 1.5) : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(r.isTag ? KIcons.tag : (latest ? KIcons.star : KIcons.package), size: 13, color: latest ? c.ok : (r.kind == ReleaseKind.preRelease ? c.warn : c.text3)),
            const SizedBox(width: 7),
            Text(r.tag, style: mono(12.5, weight: FontWeight.w600, color: c.text)),
            if (badge != null) ...[const SizedBox(width: 7), _Chip(badge.$1, color: badge.$2, background: badge.$3, monospace: false)],
            const Spacer(),
            Text(_rel(r.time), style: sans(11.5, color: c.text3)),
          ]),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Row(children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sans(12, color: r.name.isNotEmpty ? c.text : c.text3).copyWith(fontStyle: r.name.isEmpty && r.notes.isEmpty ? FontStyle.italic : null),
                ),
              ),
              if (since != null) Text('since $since', style: sans(11, color: c.text3)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ReleaseDetail extends StatelessWidget {
  const _ReleaseDetail({required this.source, required this.releases, required this.index, required this.latest, required this.range, required this.menuOpen, required this.onMenu});
  final RepoActivitySource source;
  final List<RepoRelease> releases;
  final int index;
  final bool latest;
  final Future<ReleaseRange> range;
  final bool menuOpen;
  final ValueChanged<bool> onMenu;

  RepoRelease get release => releases[index];

  int? get _prev => previousReleaseIndex(releases, index);
  bool get _first => _prev == null && index == releases.length - 1 && source.olderReleases == 0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final r = release;
    final prev = _prev == null ? null : releases[_prev!];
    final badge = _badgeOf(c, r, latest: latest, first: _first);
    final skipped = skippedBetween(releases, index, _prev);
    final host = _hostName(source.repo.host);
    final me = source.currentUser;
    final author = r.author;
    return Section(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(r.tag, style: mono(19, weight: FontWeight.w600, color: c.text)),
                if (badge != null) _Chip(badge.$1, color: badge.$2, background: badge.$3, monospace: false, size: 11),
              ]),
              const SizedBox(height: 4),
              Text(
                r.isTag ? 'A tag, not a release' : (r.name.isEmpty ? 'No name' : r.name),
                style: sans(14, weight: FontWeight.w500, color: r.name.isEmpty ? c.text3 : c.text).copyWith(fontStyle: r.name.isEmpty ? FontStyle.italic : null),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (author != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _Avatar(author, me: author == me),
                    const SizedBox(width: 6),
                    Text('$author ${r.isTag ? 'tagged it' : 'released it'} ${_rel(r.time)}', style: sans(12, color: c.text3)),
                  ])
                else
                  Text(_rel(r.time), style: sans(12, color: c.text3)),
                if (r.sha.isNotEmpty) Text(r.sha.length > 7 ? r.sha.substring(0, 7) : r.sha, style: mono(11, color: c.text3)),
                if (r.checks case final ok?)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(ok ? KIcons.check : KIcons.close, size: 12, color: ok ? c.ok : c.err),
                    const SizedBox(width: 4),
                    Text(ok ? 'Checks passed' : 'Checks failed', style: sans(12, color: ok ? c.ok : c.err)),
                  ]),
              ]),
            ]),
          ),
          const SizedBox(width: 10),
          KButton(
            label: r.isTag ? 'Create a release' : (r.notes.trim().isEmpty ? 'Write notes' : 'Rewrite notes'),
            icon: KIcons.sparkle,
            height: 32,
            fontSize: 12.5,
            onTap: () => showReleaseNotesDialog(context, source: source, releases: releases, index: index),
          ),
          const SizedBox(width: 6),
          KIconButton(icon: KIcons.external, label: r.url.isEmpty ? 'No address on $host' : 'Open ${r.tag} on $host', onTap: r.url.isEmpty ? null : () => openUrl(r.url)),
          Builder(
            builder: (anchor) => KIconButton(
              icon: KIcons.more,
              label: 'Actions for ${r.tag}',
              filled: menuOpen,
              onTap: () => _openMenu(anchor, s, prev),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        FutureBuilder<ReleaseRange>(
          // Keyed: another release's numbers never show for a frame.
          key: ValueKey('range ${r.tag}'),
          future: range,
          builder: (context, snap) => _RangeStrip(
            range: snap.data,
            error: snap.hasError ? '${snap.error}' : null,
            first: _first,
            prev: prev?.tag,
            preRelease: r.kind == ReleaseKind.preRelease || r.kind == ReleaseKind.draft,
            skipped: [for (final x in skipped) x.tag + (x.isTag ? ' (a tag without release)' : (x.kind == ReleaseKind.preRelease ? ' (pre-release)' : ''))],
            compareUrl: prev == null ? null : _compareUrl(source, prev.tag, r.tag),
            prWord: RepoTerms.of(source.repo.host).prs,
          ),
        ),
        if (r.isTag) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: c.warnSoft, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(KIcons.tag, size: 14, color: c.warn),
              const SizedBox(width: 10),
              Expanded(child: Text('${r.tag} is a tag without a release: nobody wrote down what’s in it.', style: sans(12.5, color: c.text, height: 1.4))),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            if (r.notes.trim().isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: MarkdownPreview(source: r.notes, path: '${r.tag}.md'),
              )
            else if (!r.isTag)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: c.chipBorder)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(KIcons.rename, size: 14, color: c.text3),
                    const SizedBox(width: 8),
                    Text('No release notes yet', style: sans(13, weight: FontWeight.w600, color: c.text)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    _first
                        ? 'It’s the first release, so there’s nothing to compare with: an agent can read the project and write what it is, what this version does and how to run it.'
                        : 'An agent can write them from what changed since ${prev?.tag ?? 'the previous release'}: the commits, the merged ${RepoTerms.of(source.repo.host).prs} and the tickets they close.',
                    style: sans(12.5, color: c.text2, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  KButton.primary(label: 'Write them with an agent', icon: KIcons.sparkle, height: 30, fontSize: 12.5, onTap: () => showReleaseNotesDialog(context, source: source, releases: releases, index: index)),
                ]),
              ),
            const SizedBox(height: 14),
            FutureBuilder<ReleaseRange>(
              key: ValueKey('prs ${r.tag}'),
              future: range,
              builder: (context, snap) {
                final prs = snap.data?.prs ?? const <MergedPr>[];
                final word = RepoTerms.of(source.repo.host).prs;
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(
                    '${_first ? 'MERGED ${word.toUpperCase()} IN IT' : 'MERGED ${word.toUpperCase()}${prev == null ? '' : ' SINCE ${prev.tag}'}'} · ${prs.length}',
                    style: microLabel(c),
                  ),
                  const SizedBox(height: 4),
                  if (snap.data != null && prs.isEmpty) Text('Commits pushed straight to ${source.mainBranch}, no $word.', style: sans(12, color: c.text3)),
                  for (final p in prs)
                    SizedBox(
                      height: 26,
                      child: Row(children: [
                        SizedBox(width: 44, child: Text(p.$1, style: mono(11.5, color: c.text3))),
                        Expanded(child: Text(p.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, color: c.text))),
                        if (p.$4 case final t?) ...[const SizedBox(width: 6), _Chip(t, color: c.text2, background: c.tile)],
                        const SizedBox(width: 6),
                        _Avatar(p.$3, me: p.$3 == me),
                      ]),
                    ),
                ]);
              },
            ),
            if (r.assets.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('ASSETS', style: microLabel(c)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (name, size) in r.assets)
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.chipBorder)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(KIcons.package, size: 13, color: c.text3),
                      const SizedBox(width: 6),
                      Text(name, style: sans(12, color: c.text2)),
                      const SizedBox(width: 6),
                      Text(size, style: sans(11, color: c.text3)),
                    ]),
                  ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  void _openMenu(BuildContext anchor, AppState s, RepoRelease? prev) {
    final r = release;
    final host = _hostName(source.repo.host);
    final compare = prev == null ? null : _compareUrl(source, prev.tag, r.tag);
    onMenu(true);
    showKMenu(
      anchor,
      position: belowOf(anchor),
      alignRight: true,
      onClosed: () => onMenu(false),
      builder: (ctx, close) {
        void agent(ReleaseAgentJob job) {
          close();
          _startReleaseAgent(anchor, s, job, prev);
        }

        return KMenuPanel(width: 288, children: [
          Padding(padding: const EdgeInsets.fromLTRB(8, 5, 8, 4), child: Text('WITH AN AGENT', style: microLabel(ctx.c))),
          KMenuItem(
            icon: KIcons.sparkle,
            label: r.isTag ? 'Create a release with notes…' : '${r.notes.trim().isEmpty ? 'Write' : 'Rewrite'} the release notes…',
            onTap: () {
              close();
              showReleaseNotesDialog(anchor, source: source, releases: releases, index: index);
            },
          ),
          KMenuItem(icon: KIcons.chat, label: _first ? 'Explain the project at ${r.tag}' : 'Explain what changed', onTap: () => agent(ReleaseAgentJob.explain)),
          if (!r.isTag) KMenuItem(icon: KIcons.megaphone, label: 'Draft an announcement for the team', onTap: () => agent(ReleaseAgentJob.announce)),
          const KMenuDivider(),
          KMenuItem(
            icon: KIcons.external,
            label: 'Open on $host',
            onTap: r.url.isEmpty
                ? null
                : () {
                    close();
                    openUrl(r.url);
                  },
          ),
          KMenuItem(
            icon: KIcons.link,
            label: 'Copy link',
            onTap: r.url.isEmpty
                ? null
                : () {
                    close();
                    Clipboard.setData(ClipboardData(text: r.url));
                    s.notify('Copied the link to ${r.tag}');
                  },
          ),
          if (prev != null)
            KMenuItem(
              icon: KIcons.compare,
              label: 'Compare with ${prev.tag}',
              onTap: compare == null
                  ? null
                  : () {
                      close();
                      openUrl(compare);
                    },
            ),
          KMenuItem(
            icon: latest ? KIcons.wrench : KIcons.add,
            label: latest ? 'Start a hotfix from ${r.tag}…' : 'New worktree from ${r.tag}…',
            onTap: () {
              close();
              Clipboard.setData(ClipboardData(text: r.tag));
              s.requestNewWorktree();
              s.notify(latest ? 'Copied ${r.tag}: base fix/${nextPatchOf(r.tag)} on it' : 'Copied ${r.tag}: paste it as the base');
            },
          ),
          if ((r.kind == ReleaseKind.preRelease || r.kind == ReleaseKind.draft) && source.releasesEditable) ...[
            const KMenuDivider(),
            KMenuItem(
              icon: KIcons.star,
              label: 'Publish as the latest release',
              onTap: () async {
                close();
                try {
                  await source.editRelease(r, publish: true);
                  s.notify('${r.tag} is the latest release');
                } on Object catch (e) {
                  s.notify('Couldn’t publish ${r.tag}: $e');
                }
              },
            ),
          ],
        ]);
      },
    );
  }

  Future<void> _startReleaseAgent(BuildContext context, AppState s, ReleaseAgentJob job, RepoRelease? prev) async {
    if (!s.agents.live) return s.notify('Agents run once Kumo’s engine is connected');
    if (s.agents.connected.isEmpty) return s.notify('Connect an agent in Settings › AI agents');
    final dir = mainCheckoutOf(s, source);
    if (dir == null) return s.notify('${source.repo.name} has no checkout on this Mac');
    final r = release;
    final run = await s.agents.start(
      worktreePath: dir,
      prompt: releaseAgentPrompt(
        job,
        ReleaseTarget(
          repoName: source.repo.name,
          host: source.repo.host,
          tag: r.tag,
          since: prev?.tag,
          first: _first,
          preRelease: r.kind == ReleaseKind.preRelease,
          skipped: [for (final x in skippedBetween(releases, index, _prev)) if (x.notes.trim().isEmpty) x.tag],
        ),
      ),
      title: '${r.tag} · ${job.label}',
    );
    if (run == null) return s.notify(s.agents.error ?? 'The agent didn’t start');
    s.openTerminal(run.terminalId, title: run.title, agent: true, directory: run.worktreePath);
  }
}

/// "Since v1.7.2: 19 commits · 6 pull requests · …" with what's folded in.
class _RangeStrip extends StatelessWidget {
  const _RangeStrip({required this.range, required this.error, required this.first, required this.prev, required this.preRelease, required this.skipped, required this.compareUrl, required this.prWord});
  final ReleaseRange? range;
  final String? error;
  final bool first;
  final String? prev;
  final bool preRelease;
  final List<String> skipped;
  final String? compareUrl;
  final String prWord;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = range;
    Widget stat(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: c.text3),
          const SizedBox(width: 5),
          Text(text, style: sans(12, color: c.text2)),
        ]);
    final note = first
        ? 'The first release: nothing before it to compare with.'
        : preRelease && prev != null
            ? 'A pre-release: compared with the latest full release, $prev.'
            : skipped.isNotEmpty
                ? 'Includes ${skipped.join(', ')}.'
                : null;
    final url = compareUrl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(first ? 'Since the first commit' : (prev == null ? 'Changes' : 'Since $prev'), style: sans(12, weight: FontWeight.w600, color: c.text)),
              if (r == null)
                Text(error ?? 'Counting…', style: sans(12, color: error == null ? c.text3 : c.err))
              else ...[
                stat(KIcons.commit, '${r.commits} commits'),
                stat(KIcons.pullRequest, '${r.prs.length} $prWord'),
                if (r.tickets.isNotEmpty) stat(KIcons.tasks, '${r.tickets.length} ${r.tickets.length == 1 ? 'ticket' : 'tickets'}'),
                stat(KIcons.people, '${r.people.length} ${r.people.length == 1 ? 'person' : 'people'}'),
                stat(KIcons.files, '+${r.added} −${r.deleted} in ${r.files} files'),
              ],
            ]),
          ),
          if (url != null) KButton(label: 'Compare', icon: KIcons.external, kind: KButtonKind.ghost, height: 26, fontSize: 12, onTap: () => openUrl(url)),
        ]),
        if (note != null) ...[const SizedBox(height: 6), Text(note, style: sans(11.5, color: c.text3))],
      ]),
    );
  }
}
