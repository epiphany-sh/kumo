import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/worktree_changes.dart' show CommitInfo;
import '../data/docs_source.dart';
import '../data/models.dart';
import '../data/pull_requests_source.dart';
import '../data/repo_activity.dart';
import '../data/repo_history.dart';
import '../data/tasks_source.dart' show TaskEntry;
import '../editor/quick_open.dart' show FileIndex, FileMatches, TopK, fuzzyMatch, goToFile, markedSpans, openWorktreeFile, recentFiles;
import '../engine/engine_repo_activity.dart';
import '../engine/engine_scope.dart';
import '../platform/open_url.dart';
import '../platform/os/key_combo.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../views/git_screen.dart' show showRepoCommit;
import '../views/task_labels.dart';
import '../views/task_visuals.dart';
import '../widgets/controls.dart';
import '../widgets/file_icon.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';
import 'new_agent_dialog.dart';
import 'settings_dialog.dart';

// ---- Results (pure) ----

/// Where the palette looks: everywhere, or one place.
enum SearchTab {
  all('All'),
  files('Files'),
  git('Git'),
  docs('Docs'),
  agents('Agents');

  const SearchTab(this.label);
  final String label;
}

/// The palette's sections, in the order they show, and the tab each
/// belongs to (every one shows under [SearchTab.all]).
enum SearchGroup {
  commands('Commands', SearchTab.all),
  files('Files', SearchTab.files),
  pullRequests('Open pull requests', SearchTab.git),
  commits('Commits', SearchTab.git),
  releases('Releases & tags', SearchTab.git),
  worktrees('Worktrees', SearchTab.git),
  tickets('Tickets', SearchTab.all),
  docs('Docs', SearchTab.docs),
  sessions('Sessions', SearchTab.agents),
  agents('Your agents', SearchTab.agents);

  const SearchGroup(this.label, this.tab);
  final String label;
  final SearchTab tab;

  bool shownIn(SearchTab t) => t == SearchTab.all || t == tab;
}

/// One row of the palette: what it says and what picking it does.
@immutable
class SearchResult {
  const SearchResult({
    required this.group,
    required this.id,
    required this.title,
    required this.icon,
    required this.run,
    this.detail = '',
    this.tag = '',
    this.shortcut = '',
    this.hits = const [],
    this.tint,
    this.leading,
  });

  final SearchGroup group;

  /// Unique within its group: keeps the row picked while results arrive.
  final String id;
  final String title;

  /// Grey, after the title: the repo, the source, the author.
  final String detail;

  /// Before the title, in mono: a ticket's key, a commit's sha, a PR's #.
  final String tag;

  /// A command's key, on the right.
  final String shortcut;

  /// Indexes of [title] the query matched.
  final List<int> hits;
  final IconData icon;

  /// The icon's colour, from the palette; text2 when null.
  final Color Function(KumoPalette c)? tint;

  /// In place of the icon (a file's own).
  final Widget? leading;

  /// Runs once the palette has closed.
  final VoidCallback run;
}

/// A command the palette offers.
@immutable
class PaletteCommand {
  const PaletteCommand(this.title, this.icon, this.run, {this.shortcut = ''});
  final String title;
  final IconData icon;
  final String shortcut;
  final VoidCallback run;
}

/// [items] whose [text] fuzzily matches [query], best first, with the
/// indexes matched; all of them, in order, when the query is empty.
List<(T, List<int>)> rankFuzzy<T>(String query, Iterable<T> items, String Function(T) text) {
  if (query.trim().isEmpty) return [for (final i in items) (i, const <int>[])];
  final scored = <(int, int, T, List<int>)>[];
  var n = 0;
  for (final i in items) {
    final m = fuzzyMatch(query, text(i));
    if (m != null) scored.add((m.$1, n, i, m.$2));
    n++;
  }
  scored.sort((a, b) {
    final c = b.$1.compareTo(a.$1);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  return [for (final s in scored) (s.$3, s.$4)];
}

final _spaces = RegExp(r'\s+');

/// The words of [query], lower case, as [wordHits] looks for them.
List<String> queryWords(String query) => [
      for (final w in query.toLowerCase().split(_spaces))
        if (w.isNotEmpty) w
    ];

/// Where each word of [query] first shows in [text] (case ignored), or
/// null when one doesn't: the words, not their letters scattered, so a
/// ticket or a page matches what was typed.
List<int>? wordHits(String query, String text) => _hitsOf(queryWords(query), text.toLowerCase());

/// [wordHits] with the [words] split and the text already in [lower] case.
List<int>? _hitsOf(List<String> words, String lower) {
  final at = <int>{};
  for (final w in words) {
    final i = lower.indexOf(w);
    if (i < 0) return null;
    for (var k = 0; k < w.length; k++) {
      at.add(i + k);
    }
  }
  return at.toList()..sort();
}

/// Whether every one of [words] shows in [lower].
bool _hasAll(List<String> words, String lower) {
  for (final w in words) {
    if (!lower.contains(w)) return false;
  }
  return true;
}

/// [items] where every word of [query] shows in their [key], [title] or
/// [rest], best first: the key itself, keys and titles that start with the
/// query, then titles with every word. Hits are on the title. All of them,
/// in order, when the query is empty.
List<(T, List<int>)> rankText<T>(String query, Iterable<T> items, {required String Function(T) key, required String Function(T) title, Iterable<String> Function(T)? rest}) =>
    TextIndex<T>(items.toList(), key: key, title: title, rest: rest).rank(query).top;

/// What [TextIndex.rank] found: the best [top], and how many matched in all.
typedef TextMatches<T> = ({List<(T, List<int>)> top, int total});

/// [items] made ready for [rankText] as the query is typed: each one's key,
/// title and searchable text in lower case, once; and what the last query
/// matched, so a query that only adds to it looks at those alone (text that
/// lacks `ab` lacks `abc` too).
class TextIndex<T> {
  TextIndex(this.items, {required String Function(T) key, required String Function(T) title, Iterable<String> Function(T)? rest})
      : _key = List.filled(items.length, ''),
        _title = List.filled(items.length, ''),
        _titleLower = List.filled(items.length, ''),
        _hay = List.filled(items.length, '') {
    for (final (n, item) in items.indexed) {
      final k = key(item).toLowerCase();
      final t = title(item);
      _key[n] = k;
      _title[n] = t;
      _titleLower[n] = t.toLowerCase();
      _hay[n] = [k, t, ...?rest?.call(item)].join(' ').toLowerCase();
    }
  }

  final List<T> items;
  final List<String> _key;
  final List<String> _title;
  final List<String> _titleLower;
  final List<String> _hay;

  String? _lastQ;
  List<int> _lastHits = const [];
  int? _lastLimit;
  TextMatches<T>? _last;

  /// Whether [other] holds the same items, so this index still serves it.
  bool serves(List<T> other) {
    if (identical(other, items)) return true;
    if (other.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      final a = other[i], b = items[i];
      if (!identical(a, b) && a != b) return false;
    }
    return true;
  }

  /// The best [limit] (all when null) for [query].
  TextMatches<T> rank(String query, {int? limit}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      _lastQ = null;
      return (top: [for (final i in limit == null ? items : items.take(limit)) (i, const <int>[])], total: items.length);
    }
    if (q == _lastQ && limit == _lastLimit) return _last!;
    final words = queryWords(q);
    final prev = _lastQ;
    final narrow = prev != null && q.startsWith(prev);
    final hits = <int>[];
    final scored = <(int, int, List<int>)>[];
    final best = limit == null ? null : TopK<(int, int, List<int>)>(limit, _better);
    void look(int n) {
      if (!_hasAll(words, _hay[n])) return;
      hits.add(n);
      final k = _key[n];
      final inTitle = _hitsOf(words, _titleLower[n]);
      final score = k == q
          ? 100
          : k.startsWith(q)
              ? 80
              : _titleLower[n].startsWith(q)
                  ? 60
                  : inTitle != null
                      ? 40
                      : 20;
      final e = (score, n, inTitle ?? const <int>[]);
      best == null ? scored.add(e) : best.add(e);
    }

    if (narrow) {
      for (final n in _lastHits) {
        look(n);
      }
    } else {
      for (var n = 0; n < items.length; n++) {
        look(n);
      }
    }
    final ranked = best?.sorted() ?? (scored..sort(_better));
    _lastQ = q;
    _lastHits = hits;
    _lastLimit = limit;
    return _last = (top: [for (final (_, n, at) in ranked) (items[n], at)], total: hits.length);
  }

  /// Higher score first, then in the order given.
  static int _better((int, int, List<int>) a, (int, int, List<int>) b) {
    final c = b.$1.compareTo(a.$1);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  }
}

/// What the palette can run, for [s] as it is now.
List<PaletteCommand> paletteCommands(BuildContext context, AppState s) {
  IconData iconOf(KumoView v) => switch (v) {
        KumoView.terminal => KIcons.terminal,
        KumoView.files => KIcons.files,
        KumoView.agents => KIcons.agent,
        KumoView.tasks => KIcons.tasks,
        KumoView.git => KIcons.git,
        KumoView.docs => KIcons.docs,
      };
  return [
    for (final v in KumoView.values) PaletteCommand('Go to ${v.label}', iconOf(v), () => s.view = v, shortcut: v.shortcut),
    PaletteCommand('Go to file…', KIcons.file, () => goToFile(context, s), shortcut: AppKeys.quickOpen.label),
    PaletteCommand('New agent…', KIcons.sparkle, () => showNewAgentDialog(context)),
    PaletteCommand('New worktree…', KIcons.branch, () {
      // Its popover lives in the sidebar: shown first if hidden.
      if (s.sidebarVisible) {
        s.requestNewWorktree();
      } else {
        s.toggleSidebar();
        WidgetsBinding.instance.addPostFrameCallback((_) => s.requestNewWorktree());
      }
    }, shortcut: AppKeys.newWorktree.label),
    if (s.activeRepo != null) ...[
      PaletteCommand('Git: Pull', KIcons.download, s.pull),
      if (s.canPush) PaletteCommand('Git: Push', KIcons.upload, s.push),
      PaletteCommand('Git: Fetch', KIcons.refresh, s.fetch),
    ],
    if (s.tasks.sources.isNotEmpty) PaletteCommand('Sync tasks', KIcons.refresh, () => s.tasks.sync()),
    PaletteCommand(s.sidebarVisible ? 'Hide sidebar' : 'Show sidebar', KIcons.sidebar, s.toggleSidebar, shortcut: AppKeys.toggleSidebar.label),
    PaletteCommand(s.sidePanelOpen ? 'Hide side panel' : 'Show side panel', KIcons.sidePanel, s.toggleSidePanel, shortcut: AppKeys.toggleSidePanel.label),
    PaletteCommand('Switch theme', KIcons.hybrid, s.cycleTheme, shortcut: AppKeys.cycleTheme.label),
    PaletteCommand('Settings…', KIcons.settings, () => showSettingsDialog(context), shortcut: AppKeys.settings.label),
  ];
}

// ---- Palette ----

/// ⌘K: finds a command, a file, a pull request, commit or release, a
/// worktree, a ticket, a doc page or an agent, and goes there.
Future<void> showGlobalSearch(BuildContext context, AppState s, {SearchTab tab = SearchTab.all}) async {
  final c = context.c;
  final commands = paletteCommands(context, s);
  // The current worktree's repository: its releases and tags (and its
  // history when the worktree has none to give, asked only then). Lives
  // while the palette is open; follows no worktree's pipelines. Its pull
  // requests aren't asked: the palette lists every repository's itself.
  final repo = s.activeRepo;
  final engine = EngineScope.maybeOf(context);
  final RepoActivitySource? activity = repo == null ? null : (engine == null ? MockRepoActivity(repo, s.worktreesOf(repo)) : EngineRepoActivity(engine, s.workspace, repo, const [], history: false, loadPullRequests: false));
  try {
    final picked = await showGeneralDialog<SearchResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: c.isDark ? const Color(0x4D000000) : const Color(0x22141428),
      transitionDuration: const Duration(milliseconds: 110),
      transitionBuilder: (context, anim, _, child) => FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: child),
      pageBuilder: (dialogContext, _, __) => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 84, 24, 24),
          child: Material(
            type: MaterialType.transparency,
            child: GlobalSearch(
              app: s,
              commands: commands,
              activity: activity,
              tab: tab,
              openCommit: repo == null ? null : (commits, i) => showRepoCommit(context, repo, commits, i),
              onPick: (r) => Navigator.of(dialogContext).pop(r),
            ),
          ),
        ),
      ),
    );
    if (picked != null && context.mounted) picked.run();
  } finally {
    activity?.dispose();
  }
}

class GlobalSearch extends StatefulWidget {
  const GlobalSearch({super.key, required this.app, required this.commands, required this.onPick, this.activity, this.openCommit, this.tab = SearchTab.all});
  final AppState app;
  final List<PaletteCommand> commands;
  final ValueChanged<SearchResult> onPick;

  /// The current repository's history and releases.
  final RepoActivitySource? activity;

  /// Shows [commits]`[index]` (the commit sheet).
  final void Function(List<RepoCommit> commits, int index)? openCommit;
  final SearchTab tab;

  @override
  State<GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends State<GlobalSearch> {
  static const _rowH = 36.0;
  static const _headerH = 28.0;

  /// Rows a group shows under All; a tab of its own shows [_tabLimit].
  static const _allLimit = 5;
  static const _tabLimit = 60;

  final _query = TextEditingController();
  final _field = FocusNode(debugLabel: 'Global search');
  final _scroll = ScrollController();
  late SearchTab _tab = widget.tab;

  /// Every group's best matches (as many as a tab shows), before the tab
  /// cuts them, and how many each found in all.
  Map<SearchGroup, List<SearchResult>> _matches = const {};
  Map<SearchGroup, int> _totals = const {};

  /// The worktree's files and the tickets, made ready to rank once (and
  /// again only when they change), with their last rows.
  FileIndex? _fileIndex;
  FileMatches? _fileFound;
  List<SearchResult> _fileRows = const [];
  TextIndex<TaskEntry>? _ticketIndex;
  TextMatches<TaskEntry>? _ticketFound;
  List<SearchResult> _ticketRows = const [];
  List<SearchResult> _results = const [];

  /// The row picked: a notifier, so moving it (the mouse over the rows)
  /// repaints two rows' backgrounds, not the whole list.
  final _picked = ValueNotifier<int>(0);
  int get _selected => _picked.value;
  set _selected(int i) => _picked.value = i;

  // ---- What loads ----

  /// The worktree's log; null until it answers, or when it has none (the
  /// repository's history stands in).
  List<CommitInfo>? _log;
  bool _logRead = false;

  /// Open pull requests of every repository; null until they answer.
  List<(Repo, PullRequestInfo)>? _prs;

  /// Docs come from the daemon: asked a moment after typing stops.
  Timer? _debounce;
  int _docsSeq = 0;
  bool _docsPending = false;
  List<DocSummary> _docs = const [];
  String? _docsFor;

  AppState get _s => widget.app;

  @override
  void initState() {
    super.initState();
    widget.activity?.addListener(_reload);
    _query.addListener(_changed);
    _readLog();
    _readPrs();
    _askDocs('');
    _rank();
  }

  @override
  void dispose() {
    widget.activity?.removeListener(_reload);
    _debounce?.cancel();
    _query.dispose();
    _field.dispose();
    _scroll.dispose();
    _picked.dispose();
    super.dispose();
  }

  Future<void> _readLog() async {
    List<CommitInfo>? log;
    try {
      log = await _s.changes.log(limit: 300);
    } catch (_) {
      log = null;
    }
    if (!mounted) return;
    _log = log;
    _logRead = true;
    // No log of its own: the repository's history stands in.
    if (log == null) widget.activity?.loadHistory();
    _reload();
  }

  Future<void> _readPrs() async {
    final repos = {for (final r in _s.workspace.repos) r.path ?? r.id: r};
    final found = <(Repo, PullRequestInfo)>[];
    final seen = <String>{};
    await Future.wait([
      for (final MapEntry(key: path, value: repo) in repos.entries)
        _s.pullRequests.list(path).then((list) {
          for (final pr in list.pullRequests) {
            // A repository with no host, or no access, just has none.
            if (pr.state != PrOpenState.open) continue;
            if (seen.add(pr.url.isNotEmpty ? pr.url : '${repo.id}#${pr.number}')) found.add((repo, pr));
          }
        }, onError: (_) {}),
    ]);
    if (!mounted) return;
    _prs = found;
    _reload();
  }

  void _changed() {
    final q = _query.text.trim();
    _debounce?.cancel();
    if (q != (_docsFor ?? '')) {
      _docsPending = true;
      _debounce = Timer(const Duration(milliseconds: 250), () => _askDocs(q));
    } else {
      _docsPending = false;
    }
    setState(() {
      _rank();
      _selected = 0;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  /// Docs matching [q], or the recent ones for an empty query.
  Future<void> _askDocs(String q) async {
    final seq = ++_docsSeq;
    _docsPending = true;
    List<DocSummary> found;
    try {
      final groups = await _s.docs.list(query: q);
      found = [for (final g in groups) ...g.docs];
    } catch (_) {
      // A source that can't be read says so in Docs; here it just finds nothing.
      found = const [];
    }
    if (!mounted || seq != _docsSeq) return;
    _docs = found;
    _docsFor = q;
    _docsPending = q != _query.text.trim();
    _reload();
  }

  /// Results arrived: ranked again, keeping the row picked.
  void _reload() {
    if (!mounted) return;
    final picked = _selected < _results.length ? _results[_selected] : null;
    setState(() {
      _rank();
      final at = picked == null ? -1 : _results.indexWhere((r) => r.group == picked.group && r.id == picked.id);
      _selected = at < 0 ? 0 : at;
    });
  }

  void _setTab(SearchTab t) {
    if (t == _tab) return;
    setState(() {
      _tab = t;
      _cut();
      _selected = 0;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
    _field.requestFocus();
  }

  void _cycleTab(int delta) => _setTab(SearchTab.values[(_tab.index + delta) % SearchTab.values.length]);

  // ---- Ranking ----

  /// The commits of the current worktree, newest first.
  List<RepoCommit> get _commits {
    final log = _log;
    if (log != null) {
      final branch = _s.activeWorktree;
      return [for (final k in log) RepoCommit(sha: k.sha, shortSha: k.shortSha, subject: k.subject, author: k.author, time: k.time, branch: branch)];
    }
    return _logRead ? widget.activity?.commits() ?? const [] : const [];
  }

  bool get _commitsLoading => !_logRead || (_log == null && (widget.activity?.loading ?? false));
  bool get _releasesLoading => widget.activity?.releasesLoading ?? false;

  /// Whether a group of [tab] is still waiting on its source.
  bool _loading(SearchTab tab) => switch (tab) {
        SearchTab.all => _commitsLoading || _prs == null || _releasesLoading || _docsPending,
        SearchTab.git => _commitsLoading || _prs == null || _releasesLoading,
        SearchTab.docs => _docsPending,
        SearchTab.files || SearchTab.agents => false,
      };

  /// Ranks every group for the query, keeping the [_tabLimit] best of each
  /// (rows are made for those alone) and the count of the rest. The files
  /// and tickets, the long lists, are ranked again only when the query or
  /// they changed (a pull request arriving doesn't touch them), and a query
  /// that adds letters looks only at what the last one found.
  void _rank() {
    final s = _s;
    final q = _query.text.trim();
    final m = <SearchGroup, List<SearchResult>>{};
    final totals = <SearchGroup, int>{};

    /// The best of [ranked] as rows, and how many there were.
    List<SearchResult> top<E>(SearchGroup g, List<E> ranked, SearchResult Function(E) row) {
      totals[g] = ranked.length;
      return [for (final e in ranked.take(_tabLimit)) row(e)];
    }

    m[SearchGroup.commands] = top(SearchGroup.commands, rankFuzzy(q, widget.commands, (c) => c.title),
        (e) => SearchResult(group: SearchGroup.commands, id: e.$1.title, title: e.$1.title, icon: e.$1.icon, shortcut: e.$1.shortcut, hits: e.$2, run: e.$1.run));

    final files = s.visibleFiles;
    if (!(_fileIndex?.serves(files) ?? false)) _fileIndex = FileIndex(files);
    final fileFound = _fileIndex!.rank(q, recent: recentFiles(s), limit: _tabLimit);
    if (!identical(fileFound, _fileFound)) {
      _fileFound = fileFound;
      _fileRows = [
        for (final (path, at) in fileFound.top)
          () {
            final base = path.lastIndexOf('/') + 1;
            return SearchResult(
              group: SearchGroup.files,
              id: path,
              title: path.substring(base),
              detail: base == 0 ? '' : path.substring(0, base - 1),
              icon: KIcons.file,
              leading: FileIcon(path, size: 15),
              hits: [for (final i in at) if (i >= base) i - base],
              run: () => openWorktreeFile(s, path),
            );
          }(),
      ];
    }
    m[SearchGroup.files] = _fileRows;
    totals[SearchGroup.files] = fileFound.total;

    final prs = rankText(q, _prs ?? const <(Repo, PullRequestInfo)>[], key: (e) => e.$2.label, title: (e) => e.$2.title, rest: (e) => [e.$2.branch, e.$2.author, e.$1.name]);
    m[SearchGroup.pullRequests] = top(SearchGroup.pullRequests, prs, (e) {
      final ((repo, pr), hits) = e;
      return SearchResult(
        group: SearchGroup.pullRequests,
        id: pr.url.isNotEmpty ? pr.url : '${repo.id}#${pr.number}',
        title: pr.title,
        tag: pr.label,
        detail: [repo.name, pr.author, if (pr.draft) 'draft'].join(' · '),
        icon: KIcons.pullRequest,
        tint: (c) => pr.draft ? c.text3 : c.ok,
        hits: hits,
        run: () => openUrl(pr.url),
      );
    });

    final commits = _commits;
    final shas = {for (final (i, k) in commits.indexed) k.sha: i};
    m[SearchGroup.commits] = top(SearchGroup.commits, rankText(q, commits, key: (k) => k.sha, title: (k) => k.subject, rest: (k) => [k.author]), (e) {
      final (k, hits) = e;
      return SearchResult(
        group: SearchGroup.commits,
        id: k.sha,
        title: k.subject,
        tag: k.shortSha,
        detail: '${k.author} · ${relativeTime(k.time)}',
        icon: KIcons.commit,
        hits: hits,
        run: () => widget.openCommit?.call(commits, shas[k.sha]!),
      );
    });

    final releases = rankText(q, widget.activity?.releases ?? const <RepoRelease>[], key: (r) => r.tag, title: (r) => r.name.isNotEmpty ? r.name : r.tag);
    m[SearchGroup.releases] = top(SearchGroup.releases, releases, (e) {
      final (r, hits) = e;
      return SearchResult(
        group: SearchGroup.releases,
        id: r.tag,
        title: r.name.isNotEmpty ? r.name : r.tag,
        tag: r.name.isNotEmpty && r.name != r.tag ? r.tag : '',
        detail: '${switch (r.kind) {
          ReleaseKind.release => 'Release',
          ReleaseKind.preRelease => 'Pre-release',
          ReleaseKind.draft => 'Draft',
          ReleaseKind.tagOnly => 'Tag',
        }} · ${relativeTime(r.time)}',
        icon: KIcons.tag,
        hits: hits,
        run: () => s.showRelease(r.tag),
      );
    });

    final worktrees = [
      for (final r in s.workspace.repos)
        for (final w in s.worktreesOf(r)) (r, w),
    ];
    m[SearchGroup.worktrees] = top(SearchGroup.worktrees, rankFuzzy(q, worktrees, (e) => e.$2.branch), (e) {
      final ((repo, w), hits) = e;
      return SearchResult(
          group: SearchGroup.worktrees, id: w.path.isNotEmpty ? w.path : '${repo.id}:${w.branch}', title: w.branch, detail: repo.name, icon: KIcons.branch, hits: hits, run: () => s.openWorktree(w));
    });

    if (q.isEmpty) {
      m[SearchGroup.tickets] = const [];
      totals[SearchGroup.tickets] = 0;
    } else {
      final tasks = s.tasks.tasks;
      if (!(_ticketIndex?.serves(tasks) ?? false)) {
        _ticketIndex = TextIndex<TaskEntry>(tasks, key: (t) => t.key, title: (t) => t.title, rest: (t) => [...t.labels, t.assignee?.name ?? '']);
      }
      final found = _ticketIndex!.rank(q, limit: _tabLimit);
      if (!identical(found, _ticketFound)) {
        _ticketFound = found;
        final columns = {for (final (col, label) in taskColumns) col: label};
        _ticketRows = [
          for (final (t, hits) in found.top)
            SearchResult(
              group: SearchGroup.tickets,
              id: t.id,
              title: t.title,
              tag: t.key,
              detail: '${s.tasks.source(t.sourceId)?.name ?? t.kind.label} · ${t.sourceStatus.isNotEmpty ? t.sourceStatus : columns[t.column] ?? ''}',
              icon: taskTypeIcon(t.type),
              tint: (c) => taskTypeColor(c, t.type),
              hits: hits,
              run: () => s.showTicket(t.id),
            ),
        ];
      }
      m[SearchGroup.tickets] = _ticketRows;
      totals[SearchGroup.tickets] = found.total;
    }

    // The docs answered for this query: the recent ones for none, the
    // last query's while the next is asked.
    final docsFor = _docsFor;
    final docs = docsFor == null || (docsFor != q && (docsFor.isEmpty || q.isEmpty)) ? const <DocSummary>[] : _docs;
    m[SearchGroup.docs] = top(
      SearchGroup.docs,
      docs,
      (d) => SearchResult(
        group: SearchGroup.docs,
        id: d.id,
        title: d.title,
        detail: [d.place, d.author].where((x) => x.isNotEmpty).join(' · '),
        icon: KIcons.page,
        hits: wordHits(docsFor!, d.title) ?? const [],
        run: () => s.showDoc(d.id),
      ),
    );

    // Waiting on you first, then running, then done.
    final runs = [...s.agents.runs]..sort((a, b) => _statusOrder(a.status).compareTo(_statusOrder(b.status)));
    m[SearchGroup.sessions] = top(SearchGroup.sessions, rankText(q, runs, key: (r) => r.agent, title: (r) => r.title, rest: (r) => [r.providerName, r.prompt]), (e) {
      final (r, hits) = e;
      return SearchResult(
        group: SearchGroup.sessions,
        id: r.id,
        title: r.title.isNotEmpty ? r.title : r.providerName,
        detail: [r.providerName, _statusLabel(r.status)].join(' · '),
        icon: KIcons.agent,
        tint: (c) => switch (r.status) {
          AgentStatus.needsYou => c.warn,
          AgentStatus.running => c.acc,
          AgentStatus.done => c.text3,
        },
        hits: r.title.isNotEmpty ? hits : const [],
        run: () => s.showInAgents(AgentsRequest.session(r.id)),
      );
    });
    m[SearchGroup.agents] = top(SearchGroup.agents, rankText(q, s.agentDefs.agents, key: (d) => d.name, title: (d) => d.name, rest: (d) => [d.description]), (e) {
      final (d, hits) = e;
      return SearchResult(
        group: SearchGroup.agents,
        id: d.key,
        title: d.name,
        detail: d.description,
        icon: KIcons.sparkle,
        hits: hits,
        run: () => s.showInAgents(AgentsRequest.agent(d.key)),
      );
    });

    _matches = m;
    _totals = totals;
    _cut();
  }

  static int _statusOrder(AgentStatus s) => switch (s) {
        AgentStatus.needsYou => 0,
        AgentStatus.running => 1,
        AgentStatus.done => 2,
      };

  static String _statusLabel(AgentStatus s) => switch (s) {
        AgentStatus.needsYou => 'needs you',
        AgentStatus.running => 'running',
        AgentStatus.done => 'done',
      };

  /// What the tab shows of [_matches]: under All with no query only the
  /// commands, and a few of each group once typing; a tab, all of its own.
  void _cut() {
    final q = _query.text.trim();
    _results = [
      for (final g in SearchGroup.values)
        if (g.shownIn(_tab) && (_tab != SearchTab.all || q.isNotEmpty || g == SearchGroup.commands))
          ...(_matches[g] ?? const []).take(_tab == SearchTab.all && q.isNotEmpty ? _allLimit : _tabLimit),
    ];
  }

  /// How many [tab] would find for the query.
  int _count(SearchTab tab) => [
        for (final g in SearchGroup.values)
          if (g.tab == tab || (tab == SearchTab.all && g.shownIn(tab))) _totals[g] ?? 0,
      ].fold(0, (a, b) => a + b);

  /// The list's rows: a header before each group's first result.
  List<(SearchGroup?, int)> get _rows {
    final rows = <(SearchGroup?, int)>[];
    SearchGroup? last;
    for (final (i, r) in _results.indexed) {
      if (r.group != last) rows.add((r.group, -1));
      last = r.group;
      rows.add((null, i));
    }
    return rows;
  }

  void _move(int delta) {
    if (_results.isEmpty) return;
    _selected = (_selected + delta).clamp(0, _results.length - 1);
    if (!_scroll.hasClients) return;
    var top = 4.0;
    for (final (header, i) in _rows) {
      if (i == _selected) break;
      top += header != null ? _headerH : _rowH;
    }
    final pos = _scroll.position;
    // The group's header comes into view with its first row.
    final first = _selected == 0 || _results[_selected - 1].group != _results[_selected].group;
    final from = first ? top - _headerH : top;
    if (from < pos.pixels) {
      _scroll.jumpTo(from.clamp(0, pos.maxScrollExtent));
    } else if (top + _rowH > pos.pixels + pos.viewportDimension) {
      _scroll.jumpTo((top + _rowH - pos.viewportDimension).clamp(0, pos.maxScrollExtent));
    }
  }

  void _open([int? i]) {
    final at = i ?? _selected;
    if (at < _results.length) widget.onPick(_results[at]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final q = _query.text.trim();
    final loading = _loading(_tab);
    void close() => Navigator.of(context).maybePop();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () => _move(8),
        const SingleActivator(LogicalKeyboardKey.pageUp): () => _move(-8),
        if (mac) const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => _move(1),
        if (mac) const SingleActivator(LogicalKeyboardKey.keyP, control: true): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.tab): () => _cycleTab(1),
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): () => _cycleTab(-1),
        const SingleActivator(LogicalKeyboardKey.enter): _open,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _open,
        const SingleActivator(LogicalKeyboardKey.escape): close,
        // ⌘K again closes it.
        for (final a in AppKeys.search.activators) a: close,
      },
      child: GlassOverlay(
        width: 680,
        radius: 16,
        padding: const EdgeInsets.all(6),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Icon(KIcons.search, size: 17, color: c.text3),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const ValueKey('global-search'),
                  controller: _query,
                  focusNode: _field,
                  autofocus: true,
                  style: sans(14.5, color: c.text),
                  cursorColor: c.acc,
                  onSubmitted: (_) => _open(),
                  decoration: InputDecoration.collapsed(hintText: _hint, hintStyle: sans(14.5, color: c.text3)),
                ),
              ),
              if (loading) SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: c.text3)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              // A click on a tab leaves the focus (and the typing) in the field.
              child: ExcludeFocus(child: KSegmented<SearchTab>(
                label: 'Search in',
                height: 26,
                value: _tab,
                onChanged: _setTab,
                items: [
                  for (final t in SearchTab.values) (t, t.label, q.isEmpty ? null : '${_count(t)}'),
                ],
              )),
            ),
          ),
          Container(height: 1, color: c.divider, margin: const EdgeInsets.symmetric(horizontal: 6)),
          if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(child: Text(_emptyNote(q, loading), style: sans(12.5, color: c.text3))),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _rowH * 11 + 8),
              child: ListView(
                controller: _scroll,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final (header, i) in _rows) header != null ? _header(context, header) : _row(context, i),
                ],
              ),
            ),
          Container(height: 1, color: c.divider, margin: const EdgeInsets.symmetric(horizontal: 6)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
            child: Text('Tab to search in · ↑↓ to move · ↵ to open · Esc to close', style: sans(11, color: c.text3)),
          ),
        ]),
      ),
    );
  }

  String get _hint => switch (_tab) {
        SearchTab.all => 'Search commands, files, git, tickets, docs, agents…',
        SearchTab.files => 'Search files of ${_s.activeWorktree}…',
        SearchTab.git => 'Search pull requests, commits, releases, worktrees…',
        SearchTab.docs => 'Search docs…',
        SearchTab.agents => 'Search sessions and your agents…',
      };

  String _emptyNote(String q, bool loading) {
    if (loading) return 'Searching…';
    if (q.isNotEmpty) return 'Nothing matches “$q”${_tab == SearchTab.all ? '' : ' in ${_tab.label}'}';
    return switch (_tab) {
      SearchTab.all => 'Type to search',
      SearchTab.files => 'No files in this worktree',
      SearchTab.git => 'No pull requests, commits or releases found',
      SearchTab.docs => 'No docs: connect Confluence or an Obsidian vault in Settings › Tasks',
      SearchTab.agents => 'No sessions or agents yet',
    };
  }

  Widget _header(BuildContext context, SearchGroup g) {
    final c = context.c;
    final total = _totals[g] ?? 0;
    final shown = _results.where((r) => r.group == g).length;
    return SizedBox(
      height: _headerH,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Row(children: [
          Text(g.label.toUpperCase(), style: microLabel(c)),
          const Spacer(),
          if (shown < total) Text('$shown of $total', style: sans(11, color: c.text3)),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, int i) {
    final c = context.c;
    final r = _results[i];
    final hit = r.hits.toSet();
    final titleStyle = sans(13, weight: FontWeight.w500, color: c.text);
    final strong = titleStyle.copyWith(color: c.acc, fontWeight: FontWeight.w700);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onHover: (_) {
        if (_selected != i) _selected = i;
      },
      child: GestureDetector(
        onTap: () => _open(i),
        // Only the background follows the pick; the row's content is built once.
        child: ValueListenableBuilder<int>(
          valueListenable: _picked,
          builder: (context, picked, content) => Container(
            height: _rowH,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: picked == i ? c.navActive : null, borderRadius: BorderRadius.circular(9)),
            child: content,
          ),
          child: Row(children: [
            SizedBox(width: 18, child: Center(child: r.leading ?? Icon(r.icon, size: 15, color: r.tint?.call(c) ?? c.text2))),
            const SizedBox(width: 10),
            if (r.tag.isNotEmpty) ...[
              Text(r.tag, style: mono(11.5, weight: FontWeight.w600, color: c.text2)),
              const SizedBox(width: 8),
            ],
            Expanded(child: MatchLine(title: r.title, hits: hit, detail: r.detail, style: titleStyle, strong: strong, detailStyle: sans(12, color: c.text3))),
            if (r.shortcut.isNotEmpty) ...[const SizedBox(width: 8), Kbd(r.shortcut)],
          ]),
        ),
      ),
    );
  }
}

/// A row's title, its matched letters marked, then its detail in grey.
/// The title gets the room it needs and the detail gives way first (it
/// keeps at least a third when both are long). A title that still doesn't
/// fit is cut in front, so what matched shows ("…sh/release/0.8.3"). A
/// row cut anywhere shows its whole title (and detail) on hover.
class MatchLine extends StatefulWidget {
  const MatchLine({super.key, required this.title, required this.hits, required this.detail, required this.style, required this.strong, required this.detailStyle});

  final String title;
  final Set<int> hits;
  final String detail;
  final TextStyle style;
  final TextStyle strong;
  final TextStyle detailStyle;

  @override
  State<MatchLine> createState() => _MatchLineState();
}

/// Keeps what it measured (the title's and detail's widths, and where a
/// cut title starts for the room it had) until the text, its styles or the
/// room change: a row built again as it was isn't laid out again to measure.
class _MatchLineState extends State<MatchLine> {
  static const _gap = 10.0;
  static const _ellipsis = '…';

  /// What the widths below were measured under.
  (TextStyle, TextScaler, TextDirection)? _measuredUnder;
  double _titleW = 0;
  double _detailW = 0;

  /// The room the cut was found for, and where it starts.
  double? _cutRoom;
  int _from = 0;

  @override
  void didUpdateWidget(MatchLine old) {
    super.didUpdateWidget(old);
    final w = widget;
    if (w.title != old.title || w.detail != old.detail || w.style != old.style || w.strong != old.strong || w.detailStyle != old.detailStyle || !setEquals(w.hits, old.hits)) {
      _measuredUnder = null;
    }
  }

  /// [title] from [from] (with "…" in front when cut) up to [to].
  TextSpan _spans(int from, [int? to]) => TextSpan(children: [
        if (from > 0) TextSpan(text: _ellipsis, style: widget.style),
        ...markedSpans(widget.title, widget.hits, widget.style, widget.strong, from: from, to: to),
      ]);

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final title = w.title, detail = w.detail, hits = w.hits;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // Measured as Text draws it: under the inherited style (Material's
    // body style brings letter spacing), rounded up, so a title that
    // measures as fitting isn't cut by a fraction of a pixel.
    final inherited = DefaultTextStyle.of(context).style;
    double widthOf(InlineSpan span) {
      final p = TextPainter(text: TextSpan(style: inherited, children: [span]), textDirection: direction, textScaler: scaler, maxLines: 1)..layout();
      final w = p.width.ceilToDouble();
      p.dispose();
      return w;
    }

    final under = (inherited, scaler, direction);
    if (_measuredUnder != under) {
      _measuredUnder = under;
      _titleW = widthOf(_spans(0));
      _detailW = detail.isEmpty ? 0.0 : widthOf(TextSpan(text: detail, style: w.detailStyle)) + _gap;
      _cutRoom = null;
    }
    final titleW = _titleW, detailW = _detailW;

    return LayoutBuilder(builder: (context, box) {
      final room = box.maxWidth;
      // The title first; the detail keeps a third when both are long.
      final titleRoom = titleW + detailW <= room ? titleW : (room - detailW).clamp(math.min(titleW, room * 2 / 3), room).toDouble();
      final cut = titleW > titleRoom + 0.5;

      // Cut in front when the last match would fall past the end: the
      // fewest letters dropped that bring the matches into view.
      if (_cutRoom != titleRoom) {
        _cutRoom = titleRoom;
        var from = 0;
        if (cut && hits.isNotEmpty) {
          final first = hits.reduce(math.min);
          final last = hits.reduce(math.max) + 1;
          bool fits(int f) => widthOf(_spans(f, last)) <= titleRoom;
          if (!fits(0)) {
            var lo = 1, hi = first;
            if (!fits(hi)) {
              from = first;
            } else {
              while (lo < hi) {
                final mid = (lo + hi) ~/ 2;
                if (fits(mid)) {
                  hi = mid;
                } else {
                  lo = mid + 1;
                }
              }
              from = lo;
            }
          }
        }
        _from = from;
      }

      final line = Row(children: [
        SizedBox(width: math.min(titleRoom, room), child: Text.rich(_spans(_from), maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis)),
        if (detail.isNotEmpty) ...[
          const SizedBox(width: _gap),
          Expanded(child: Text(detail, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: w.detailStyle)),
        ],
      ]);
      // The whole of it on hover when anything is cut, or near the edge
      // (a few pixels of slack in case the measure and the drawing differ).
      final detailCut = detailW > room - math.min(titleRoom, room) + 0.5;
      if (!cut && !detailCut && titleW + detailW <= room - 4) return line;
      return Tooltip(message: detailCut && detail.isNotEmpty ? '$title\n$detail' : title, waitDuration: const Duration(milliseconds: 500), child: line);
    });
  }
}
