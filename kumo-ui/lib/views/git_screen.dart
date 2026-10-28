import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/models.dart';
import '../data/pipelines_source.dart';
import '../data/repo_activity.dart';
import '../engine/engine_repo_activity.dart';
import '../engine/engine_scope.dart';
import '../overlays/settings_dialog.dart';
import '../shell/screen_chrome.dart';
import '../shell/sidebar.dart' show toneColor;
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/context_menu.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';

/// Git view: what happened in ONE repository, teammates' work included —
/// main's recent commits, open pull requests, pipelines across branches,
/// and its branches & worktrees. The current branch's own state (changes,
/// commits ahead, its PR and pipelines) lives next to the terminal.
///
/// The repository defaults to the one of the current worktree and can be
/// switched from the breadcrumb.
class GitScreen extends StatefulWidget {
  const GitScreen({super.key});

  @override
  State<GitScreen> createState() => _GitScreenState();
}

enum _PrFilter { all, mine, review }

class _GitScreenState extends State<GitScreen> {
  /// Repository picked in the breadcrumb; null follows the current worktree.
  String? _repoId;
  bool _allBranches = false;
  _PrFilter _prFilter = _PrFilter.all;
  bool _menuOpen = false;

  /// Expanded run per repository (by [RepoRun.key]; '' = all collapsed).
  final Map<String, String> _openRun = {};

  /// Repositories whose pipelines were retried (the banner says so).
  final Set<String> _retried = {};

  RepoActivitySource? _source;
  String? _sourceKey;

  /// One source for the selected repository, only while the view shows:
  /// the view sits in an IndexedStack, and offstage it shouldn't poll CI.
  /// The daemon backs it in the app; the design mocks in widget tests.
  void _bind(AppState s, Repo? repo) {
    final engine = EngineScope.maybeOf(context);
    final visible = s.view == KumoView.git;
    final worktrees = repo == null ? const <Worktree>[] : s.worktreesOf(repo);
    final key = !visible || repo == null
        ? null
        : [repo.id, engine == null ? 'mock' : 'engine', for (final w in worktrees) '${w.path}@${w.branch}@${w.everPushed}'].join('|');
    if (key == _sourceKey) return;
    _sourceKey = key;
    _source
      ?..removeListener(_changed)
      ..dispose();
    _source = null;
    if (key == null || repo == null) return;
    final RepoActivitySource created;
    if (engine == null) {
      created = MockRepoActivity(repo, worktrees);
    } else {
      created = EngineRepoActivity(engine, s.workspace, repo, worktrees);
    }
    _source = created..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _source
      ?..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  /// Repositories of the sidebar's namespaces, in order.
  List<Repo> _repos(AppState s) => [
        for (final id in {for (final n in s.namespaces) ...n.repos})
          if (s.workspace.repo(id) case final r?) r,
      ];

  void _pickRepo(AppState s, Repo repo) => setState(() {
        _repoId = repo.id == s.activeRepo?.id ? null : repo.id;
        _allBranches = false;
        _prFilter = _PrFilter.all;
      });

  void _openRepoMenu(BuildContext anchor, AppState s, List<Repo> repos, Repo current) {
    setState(() => _menuOpen = true);
    final contextId = s.activeRepo?.id;
    showKMenu(
      anchor,
      position: belowOf(anchor, right: false),
      onClosed: () {
        if (mounted) setState(() => _menuOpen = false);
      },
      builder: (ctx, close) => KMenuPanel(width: 288, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 4),
          child: Text('REPOSITORIES', style: microLabel(ctx.c)),
        ),
        for (final r in repos)
          _RepoMenuItem(
            repo: r,
            selected: r.id == current.id,
            isContext: r.id == contextId,
            onTap: () {
              close();
              _pickRepo(s, r);
            },
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final repos = _repos(s);
    final contextRepo = s.activeRepo;
    final repo = repos.where((r) => r.id == _repoId).firstOrNull ?? contextRepo ?? repos.firstOrNull;
    _bind(s, repo);
    final source = _source;

    final newWorktree = KButton.primary(label: 'New worktree', icon: KIcons.add, height: 36, onTap: s.requestNewWorktree);
    if (repo == null) {
      return ScreenFrame(
        toolbar: ScreenToolbar(breadcrumb: const Breadcrumb(icon: KIcons.branch, parts: ['Git']), primary: newWorktree),
        body: Center(child: Text('Add a repository to a namespace to see its activity here.', style: sans(12.5, color: c.text3))),
        status: const [],
      );
    }

    // "Git / <host> <repo> ▾  repo of the current worktree"
    final breadcrumb = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(KIcons.branch, size: 15, color: c.acc),
      const SizedBox(width: 8),
      Text('Git', style: sans(13, weight: FontWeight.w600, color: c.text)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('/', style: sans(13, color: c.text3))),
      Flexible(
        child: Builder(
          builder: (anchor) => KPressable(
            onTap: () => _openRepoMenu(anchor, s, repos, repo),
            semanticLabel: 'Repository: ${repo.name}',
            tooltip: 'Switch repository',
            selected: _menuOpen,
            builder: (context, hover, focus) => Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _menuOpen || hover ? c.tile : null,
                borderRadius: BorderRadius.circular(13),
                border: focus ? Border.all(color: c.acc, width: 1.5) : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                TagChip(repo.host),
                const SizedBox(width: 6),
                Flexible(child: Text(repo.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13, weight: FontWeight.w500, color: c.text))),
                const SizedBox(width: 6),
                Icon(KIcons.chevronDown, size: 13, color: c.text3),
              ]),
            ),
          ),
        ),
      ),
      if (repo.id == contextRepo?.id) ...[
        const SizedBox(width: 8),
        Flexible(child: Text('repo of the current worktree', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3))),
      ],
    ]);

    final toolbar = ScreenToolbar(breadcrumb: breadcrumb, primary: newWorktree);
    if (source == null) {
      // Offstage: nothing is read until the view shows.
      return ScreenFrame(toolbar: toolbar, body: const SizedBox.shrink(), status: const []);
    }

    final terms = RepoTerms.of(repo.host);
    final provider = source.provider;
    final problem = source.runsProblem;
    final runs = source.runs;
    // Main's latest failure is what you'd look at first.
    final defaultRun = runs.where((r) => r.branch == source.mainBranch && r.state == CiState.failed).firstOrNull?.key ?? '';
    final openRun = _openRun[repo.id] ?? defaultRun;

    final commits = _CommitsSection(
      source: source,
      allBranches: _allBranches && source.allBranchesSupported,
      onScope: (all) => setState(() => _allBranches = all),
    );
    final prs = _PullRequestsSection(
      source: source,
      terms: terms,
      filter: _prFilter,
      onFilter: (f) => setState(() => _prFilter = f),
    );
    final pipelines = _PipelinesSection(
      source: source,
      runs: runs,
      openRun: openRun,
      retried: _retried.contains(repo.id),
      onToggle: (run) => setState(() => _openRun[repo.id] = run.key == openRun ? '' : run.key),
      onRetry: () {
        final id = repo.id;
        setState(() => _retried.remove(id));
        source.retryRuns().then((_) {
          if (mounted) setState(() => _retried.add(id));
        });
      },
    );
    final branches = _BranchesSection(source: source);

    final open = source.pullRequests.length;
    final noAccess = problem != null && problem.needsSettings;
    return ScreenFrame(
      toolbar: toolbar,
      body: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < 1000) {
          // Narrow window: the four sections stacked.
          return ListView(padding: EdgeInsets.zero, children: [
            SizedBox(height: 380, child: commits),
            const SizedBox(height: 10),
            SizedBox(height: 360, child: prs),
            const SizedBox(height: 10),
            SizedBox(height: 440, child: pipelines),
            const SizedBox(height: 10),
            SizedBox(height: 360, child: branches),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 13,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 100, child: commits),
              const SizedBox(height: 10),
              Expanded(flex: 135, child: pipelines),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 10,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 100, child: prs),
              const SizedBox(height: 10),
              Expanded(flex: 115, child: branches),
            ]),
          ),
        ]);
      }),
      status: [
        if (source.fetchedAt case final at?) Flexible(child: StatusText('Fetched all remotes ${_rel(at)}', flexible: true)),
        if (source.prsSupported) StatusText('$open open ${open == 1 ? terms.prOne : terms.prShort}'),
        const Spacer(),
        if (source.statusNote case final note?) Flexible(child: StatusText(note, flexible: true)),
        StatusText(
          provider == null ? 'No CI' : (noAccess ? '${provider.label} · no access' : provider.label),
          icon: KIcons.cluster,
          color: noAccess ? c.warn : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Breadcrumb menu
// ---------------------------------------------------------------------------

class _RepoMenuItem extends StatelessWidget {
  const _RepoMenuItem({required this.repo, required this.selected, required this.isContext, required this.onTap});
  final Repo repo;
  final bool selected;
  final bool isContext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final provider = CiProvider.ofHost(repo.host);
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: repo.name,
      builder: (context, hover, focus) => Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(7)),
        child: Row(children: [
          Icon(KIcons.repo, size: 14, color: c.text2),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Flexible(child: Text(repo.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: FontWeight.w500, color: c.text))),
                if (isContext) ...[
                  const SizedBox(width: 6),
                  Flexible(child: Text('current worktree', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: sans(10.5, color: c.text3))),
                ],
              ]),
              const SizedBox(height: 1),
              Text('${_hostName(repo.host)} · ${provider?.label ?? 'no CI'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3)),
            ]),
          ),
          const SizedBox(width: 9),
          TagChip(repo.host),
          const SizedBox(width: 9),
          SizedBox(width: 14, child: selected ? Icon(KIcons.check, size: 14, color: c.acc) : null),
        ]),
      ),
    );
  }
}

String _hostName(String host) => CiProvider.ofHost(host)?.hostName ?? (host == 'LO' ? 'Local folder' : host);

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

/// Glass section with the design's header: icon, title with a muted
/// subtitle, and an optional control on the right.
class _Panel extends StatelessWidget {
  const _Panel({required this.icon, required this.title, required this.child, this.subtitle = '', this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final trailing = this.trailing;
    return Section(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: SizedBox(
            height: 28,
            child: LayoutBuilder(
              builder: (context, box) => Row(children: [
                Icon(icon, size: 15, color: c.text3),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: title, style: sans(13, weight: FontWeight.w600, color: c.text)),
                        if (subtitle.isNotEmpty) TextSpan(text: '   $subtitle', style: sans(12, color: c.text3)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  // Scales down rather than overflow a narrow panel.
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth * 0.7),
                    child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: trailing),
                  ),
                ],
              ]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: child),
      ]),
    );
  }
}

/// Segmented filter on a tinted track, as in the design (smaller than
/// [KSegmented], with counts, and items that can be disabled with a reason).
class _Segments<T> extends StatelessWidget {
  const _Segments({required this.items, required this.value, required this.onChanged, required this.label});

  /// (value, label, count, why it's disabled; null = enabled).
  final List<(T, String, int?, String?)> items;
  final T value;
  final ValueChanged<T> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final children = <Widget>[];
    for (final (v, text, count, disabledWhy) in items) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 2));
      final enabled = disabledWhy == null;
      final on = v == value;
      children.add(KPressable(
        onTap: enabled ? () => onChanged(v) : null,
        tooltip: disabledWhy,
        semanticLabel: text,
        selected: on,
        builder: (context, hover, focus) => Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.center,
          decoration: on
              ? chipDecoration(c, radius: 8, fill: c.tabActive)
              : BoxDecoration(
                  color: hover && enabled ? c.tabActive : null,
                  borderRadius: BorderRadius.circular(8),
                  border: focus ? Border.all(color: c.acc, width: 1.5) : null,
                ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(text, style: sans(11.5, weight: on ? FontWeight.w600 : FontWeight.w500, color: !enabled ? c.text3 : (on ? c.text : c.text2))),
            if (count != null) ...[const SizedBox(width: 5), Text('$count', style: sans(10.5, weight: FontWeight.w500, color: c.text3))],
          ]),
        ),
      ));
    }
    return Semantics(
      label: label,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// Initial on a tinted circle: "you" in the accent, teammates in a stable
/// color per name.
class _Avatar extends StatelessWidget {
  const _Avatar(this.name, {required this.me, this.size = 18});
  final String name;
  final bool me;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (fg, bg) = me ? (c.acc, c.accSoft) : _personColors(c, name);
    final initial = name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(initial, style: sans(size * 0.55, weight: FontWeight.w600, color: fg, height: 1)),
    );
  }
}

/// A teammate's color, picked from the name so it's the same everywhere
/// (with the design's team: Lucía purple, Tomás cyan, Valentina pink, Nico
/// yellow).
(Color, Color) _personColors(KumoPalette c, String name) {
  final pink = c.isDark ? const Color(0xFFF5A3C7) : const Color(0xFFB4236B);
  final tones = [pink, c.purple, c.ok, c.yellow, c.cyan];
  final sum = name.codeUnits.fold<int>(0, (a, b) => a + b);
  final fg = tones[sum % tones.length];
  return (fg, fg.withAlpha(c.isDark ? 41 : 31));
}

/// Small chip next to a commit or branch (`#518`, a branch, `principal`).
class _Chip extends StatelessWidget {
  const _Chip(this.text, {required this.color, required this.background, this.monospace = true, this.size = 10.5, this.tooltip});
  final String text;
  final Color color;
  final Color background;
  final bool monospace;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final style = monospace ? mono(size, weight: FontWeight.w600, color: color, height: 1.6) : sans(size, weight: FontWeight.w600, color: color, height: 1.6);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
    );
    final tip = tooltip;
    return tip == null ? chip : Tooltip(message: tip, child: chip);
  }
}

/// Muted one-liner for empty / unavailable states.
class _Note extends StatelessWidget {
  const _Note(this.text, {this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final icon = this.icon;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: c.text3), const SizedBox(width: 8)],
        Expanded(child: Text(text, style: sans(12, color: c.text3, height: 1.45))),
      ]),
    );
  }
}

/// `just now`, `24 min ago`, `2 h ago`, `3 d ago`, `2 w ago`.
String _rel(DateTime t) {
  final m = DateTime.now().difference(t).inSeconds / 60;
  if (m < 1) return 'just now';
  if (m < 60) return '${m.floor()} min ago';
  if (m < 1440) return '${(m / 60).round()} h ago';
  if (m < 10080) return '${(m / 1440).round()} d ago';
  return '${(m / 10080).round()} w ago';
}

/// `41s`, `1m 05s`, `1h 02m`.
String _dur(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds}s';
  final m = d.inMinutes, sec = d.inSeconds % 60;
  if (m < 60) return '${m}m ${sec.toString().padLeft(2, '0')}s';
  return '${d.inHours}h ${(m % 60).toString().padLeft(2, '0')}m';
}

// ---------------------------------------------------------------------------
// Recent commits
// ---------------------------------------------------------------------------

class _CommitsSection extends StatelessWidget {
  const _CommitsSection({required this.source, required this.allBranches, required this.onScope});
  final RepoActivitySource source;
  final bool allBranches;
  final ValueChanged<bool> onScope;

  @override
  Widget build(BuildContext context) {
    final main = source.mainBranch;
    final commits = source.commits(allBranches: allBranches);
    final branchCount = {for (final k in commits) if (k.branch case final b?) b}.length;
    final me = source.currentUser;
    final error = source.error;
    final rows = <Widget>[
      if (commits.isEmpty)
        _Note(source.loading ? 'Loading history…' : (error != null ? 'Couldn’t read the history: $error' : 'No commits on $main yet.')),
      for (final k in commits) _CommitRow(commit: k, mine: me != null && k.author == me),
    ];
    return _Panel(
      icon: Icons.commit,
      title: allBranches ? 'Recent commits' : 'Recent commits on $main',
      subtitle: allBranches ? '$main + $branchCount ${branchCount == 1 ? 'branch' : 'branches'}' : source.repo.name,
      trailing: _Segments<bool>(
        label: 'Commit scope',
        value: allBranches,
        onChanged: onScope,
        items: [
          (false, main, null, null),
          (true, 'all branches', null, source.allBranchesSupported ? null : 'All branches needs a newer kumod'),
        ],
      ),
      child: ListView(padding: EdgeInsets.zero, children: rows),
    );
  }
}

class _CommitRow extends StatelessWidget {
  const _CommitRow({required this.commit, required this.mine});
  final RepoCommit commit;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final k = commit;
    final pr = k.prRef;
    final branch = k.branch;
    return Container(
      constraints: const BoxConstraints(minHeight: 33),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
      child: Row(children: [
        SizedBox(width: 52, child: Text(k.shortSha, maxLines: 1, overflow: TextOverflow.clip, style: mono(11, color: c.text3))),
        const SizedBox(width: 10),
        Expanded(
          child: Row(children: [
            Flexible(
              child: Tooltip(
                message: k.subject,
                waitDuration: const Duration(milliseconds: 900),
                child: Text(k.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, color: c.text)),
              ),
            ),
            if (pr != null) ...[
              const SizedBox(width: 6),
              _Chip(pr, color: c.acc, background: c.accSoft, tooltip: 'Merged from $pr'),
            ],
            if (branch != null) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: _Chip(branch, color: c.text2, background: c.tile, tooltip: branch),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 112,
          child: Row(children: [
            _Avatar(k.author, me: mine),
            const SizedBox(width: 6),
            Expanded(child: Text(mine ? '${k.author} (you)' : k.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text2))),
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 66, child: Text(_rel(k.time), textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Pipelines
// ---------------------------------------------------------------------------

(String, Color, Color) _runTone(KumoPalette c, CiState s) => switch (s) {
      CiState.running => ('Running', c.acc, c.accSoft),
      CiState.queued => ('Queued', c.text2, c.tile),
      CiState.passed => ('Passed', c.ok, c.okSoft),
      CiState.failed => ('Failed', c.err, c.errSoft),
      CiState.canceled => ('Canceled', c.text2, c.tile),
      CiState.skipped => ('Skipped', c.text2, c.tile),
    };

class _PipelinesSection extends StatelessWidget {
  const _PipelinesSection({
    required this.source,
    required this.runs,
    required this.openRun,
    required this.retried,
    required this.onToggle,
    required this.onRetry,
  });
  final RepoActivitySource source;
  final List<RepoRun> runs;
  final String openRun;
  final bool retried;
  final ValueChanged<RepoRun> onToggle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final provider = source.provider;
    final problem = source.runsProblem;
    final inProgress = runs.where((r) => r.state == CiState.running || r.state == CiState.queued).length;
    final failed = runs.where((r) => r.state == CiState.failed).length;
    final rows = <Widget>[];
    if (provider == null || !source.runsSupported) {
      rows.add(const _Note('Kumo reads pipelines from GitHub Actions, GitLab CI and Bitbucket Pipelines.'));
    } else {
      if (problem != null) {
        rows.add(_ProblemBanner(problem: problem, provider: provider, repo: source.repo.name, retried: retried, onRetry: onRetry));
      }
      for (final r in runs) {
        rows
          ..add(_RunRow(run: r, open: r.key == openRun, onTap: () => onToggle(r)))
          ..add(const SizedBox(height: 2));
      }
      if (runs.isEmpty && problem == null) rows.add(_Note(source.runsLoading ? 'Loading pipelines…' : 'No pipeline runs yet.'));
    }
    return _Panel(
      icon: KIcons.cluster,
      title: 'Pipelines',
      subtitle: provider == null ? 'no CI for this host' : '${provider.label} · ${source.runsScope}, newest first',
      trailing: runs.isEmpty ? null : Text('$inProgress in progress · $failed failed', style: sans(11.5, color: c.text3)),
      child: ListView(padding: EdgeInsets.zero, children: rows),
    );
  }
}

/// Why runs can't be read, once for the whole section, with the way out.
class _ProblemBanner extends StatelessWidget {
  const _ProblemBanner({required this.problem, required this.provider, required this.repo, required this.retried, required this.onRetry});
  final CiProblem problem;
  final CiProvider provider;
  final String repo;
  final bool retried;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (title, body) = describeCiProblem(problem, provider, repo: repo);
    final status = problem.detail.isEmpty ? 'Checked again just now' : 'Checked again just now · still ${problem.detail.split(' · ').first}';
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 2, 4, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: c.warnSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.chipBorder)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(9)),
            child: Icon(problem.needsSettings ? Icons.vpn_key_outlined : KIcons.warning, size: 16, color: c.warn),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: sans(13, weight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 4),
              Text(body, style: sans(12, color: c.text2, height: 1.45)),
              if (problem.detail.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(problem.detail, style: mono(11, color: c.text3)),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (problem.needsSettings)
                  KButton.primary(
                    label: 'Fix token in Settings',
                    icon: KIcons.settings,
                    height: 30,
                    fontSize: 12,
                    onTap: () => showSettingsDialog(context, initial: SettingsTab.repos),
                  ),
                KButton(label: 'Retry', icon: KIcons.refresh, height: 30, fontSize: 12, onTap: onRetry),
                if (retried) Text(status, style: sans(11.5, color: c.text3)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One branch's latest run; tapping it shows its jobs.
class _RunRow extends StatelessWidget {
  const _RunRow({required this.run, required this.open, required this.onTap});
  final RepoRun run;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (status, fg, bg) = _runTone(c, run.state);
    final d = run.duration;
    final dur = switch (run.state) {
      CiState.running => d == null ? 'running' : 'running ${_dur(d)}',
      CiState.queued => 'waiting for runner',
      _ => d == null ? '' : _dur(d),
    };
    final started = run.startedAt;
    return Container(
      decoration: open ? chipDecoration(c, radius: 12, fill: c.tabActive) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KPressable(
          onTap: onTap,
          selected: open,
          semanticLabel: '${run.label} on ${run.branch}: $status',
          builder: (context, hover, focus) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: hover && !open ? c.tile : null,
              borderRadius: BorderRadius.circular(12),
              border: focus ? Border.all(color: c.acc, width: 1.5) : null,
            ),
            child: Row(children: [
              SizedBox(width: 84, child: Align(alignment: Alignment.centerLeft, child: _StatusPill(label: status, color: fg, background: bg))),
              const SizedBox(width: 2),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(run.branch, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, weight: FontWeight.w500, color: c.text, height: 1.35))),
                    const SizedBox(width: 8),
                    Text(run.label, style: mono(10.5, color: c.text3, height: 1.35)),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Flexible(child: Text(run.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text2))),
                    if (run.author.isNotEmpty) Text(' · ${run.author}', style: sans(11.5, color: c.text3)),
                  ]),
                ]),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(dur, style: mono(11, color: run.state == CiState.running ? c.acc : c.text2, height: 1.35)),
                const SizedBox(height: 2),
                Text(started == null ? '' : _rel(started), style: sans(11, color: c.text3)),
              ]),
              const SizedBox(width: 8),
              Icon(open ? KIcons.chevronUp : KIcons.chevronDown, size: 14, color: c.text3),
            ]),
          ),
        ),
        if (open) _Jobs(run: run),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color, required this.background});
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Dot(color, size: 6),
          const SizedBox(width: 5),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(10.5, weight: FontWeight.w600, color: color))),
        ]),
      );
}

/// The jobs of an expanded run, with the failing line of failed ones.
class _Jobs extends StatelessWidget {
  const _Jobs({required this.run});
  final RepoRun run;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.fromLTRB(86, 9, 0, 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final j in run.jobs) ...[
          _JobRow(job: j),
          const SizedBox(height: 6),
        ],
        Text(
          '${run.passed} of ${run.jobs.length} jobs passed${run.shortSha.isEmpty ? '' : ' · commit ${run.shortSha}'}',
          style: sans(11, color: c.text3),
        ),
      ]),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job});
  final CiJob job;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (Color fg, Color bg, IconData? icon) = switch (job.state) {
      CiState.passed => (c.ok, c.okSoft, KIcons.check),
      CiState.failed => (c.err, c.errSoft, KIcons.close),
      CiState.running => (c.acc, c.accSoft, null),
      CiState.queued => (c.text3, c.tile, null),
      CiState.skipped => (c.text3, c.tile, KIcons.remove),
      CiState.canceled => (c.text3, c.tile, KIcons.close),
    };
    final d = job.duration;
    final dur = d != null
        ? _dur(d)
        : switch (job.state) {
            CiState.running => 'running',
            CiState.queued => 'queued',
            CiState.skipped => 'skipped',
            CiState.canceled => 'canceled',
            CiState.passed || CiState.failed => '',
          };
    final quiet = job.state == CiState.skipped || job.state == CiState.queued;
    final failure = job.failure;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: icon == null ? Dot(fg, size: 5) : Icon(icon, size: 10, color: fg),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(job.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: quiet ? c.text3 : c.text2))),
        const SizedBox(width: 8),
        Text(dur, style: mono(11, color: job.state == CiState.failed ? c.err : (job.state == CiState.running ? c.acc : c.text3), height: 1.35)),
      ]),
      if (failure != null && failure.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(left: 24, top: 3),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: c.errSoft, borderRadius: BorderRadius.circular(7)),
          child: Text(failure, style: mono(10.5, color: c.err, height: 1.45)),
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Pull requests
// ---------------------------------------------------------------------------

class _PullRequestsSection extends StatelessWidget {
  const _PullRequestsSection({required this.source, required this.terms, required this.filter, required this.onFilter});
  final RepoActivitySource source;
  final RepoTerms terms;
  final _PrFilter filter;
  final ValueChanged<_PrFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final repo = source.repo.name;
    final title = 'Open ${terms.prs}';
    if (!source.prsSupported) {
      // A host Kumo doesn't read pull requests from: say so instead of showing nothing.
      final what = '${terms.prs[0].toUpperCase()}${terms.prs.substring(1)}';
      return _Panel(
        icon: KIcons.pullRequest,
        title: title,
        child: ListView(padding: EdgeInsets.zero, children: [
          _Note('$what show up here for repositories on GitHub, GitLab and Bitbucket. ${source.repo.name} is on ${_hostName(source.repo.host)}.'),
        ]),
      );
    }
    final problem = source.prsProblem;
    final provider = CiProvider.ofHost(source.repo.host);
    if (problem != null && provider != null) {
      return _Panel(
        icon: KIcons.pullRequest,
        title: title,
        child: ListView(padding: EdgeInsets.zero, children: [
          _PrProblem(problem: problem, provider: provider, terms: terms, repo: repo, onRetry: source.retryPrs),
        ]),
      );
    }
    final all = source.pullRequests;
    final shown = [
      for (final p in all)
        if (switch (filter) {
          _PrFilter.all => true,
          _PrFilter.mine => p.mine,
          _PrFilter.review => p.reviewRequestedFromMe,
        })
          p,
    ];
    var empty = 'No open ${terms.prs} in $repo.';
    if (all.isNotEmpty && filter == _PrFilter.mine) empty = 'You have no open ${terms.prs} in $repo.';
    if (all.isNotEmpty && filter == _PrFilter.review) empty = 'Nothing is waiting for your review in $repo.';
    return _Panel(
      icon: KIcons.pullRequest,
      title: title,
      trailing: _Segments<_PrFilter>(
        label: 'Filter ${terms.prs}',
        value: filter,
        onChanged: onFilter,
        items: [
          (_PrFilter.all, 'All', all.length, null),
          (_PrFilter.mine, 'Mine', all.where((p) => p.mine).length, null),
          (_PrFilter.review, 'Review requested', all.where((p) => p.reviewRequestedFromMe).length, null),
        ],
      ),
      child: ListView(padding: EdgeInsets.zero, children: [
        for (final p in shown) _PrRow(pr: p),
        if (shown.isEmpty) _Note(source.prsLoading ? 'Loading ${terms.prs}…' : empty, icon: KIcons.check),
      ]),
    );
  }
}

/// Why pull requests can't be read, and the way out (Settings or retry).
class _PrProblem extends StatelessWidget {
  const _PrProblem({required this.problem, required this.provider, required this.terms, required this.repo, required this.onRetry});
  final CiProblem problem;
  final CiProvider provider;
  final RepoTerms terms;
  final String repo;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final host = provider.hostName;
    final (title, body) = switch (problem.kind) {
      CiProblemKind.notConnected => ('$host isn’t connected', 'Add a token${provider == CiProvider.githubActions ? ' or sign in with the GitHub CLI' : ''} in Settings › Repositories to see the ${terms.prs} of $repo.'),
      CiProblemKind.unauthorized => ('Your $host token stopped working', '$host rejected it. Paste a new one in Settings › Repositories.'),
      CiProblemKind.forbidden => (
          'Your $host token can’t read ${terms.prs}',
          problem.missingScope.isNotEmpty ? 'Give it the “${problem.missingScope}” permission, then retry.' : 'Give it read access to ${terms.prs} of $repo, then retry.',
        ),
      CiProblemKind.notFound => ('$host has nothing for $repo', 'Either the repository moved, or the token can’t see it.'),
      CiProblemKind.rateLimited => ('$host asked Kumo to slow down', 'Try again in a moment.'),
      _ => ('$host isn’t answering', 'Try again in a moment.'),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 2, 4, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.warnSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.chipBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: sans(13, weight: FontWeight.w600, color: c.text)),
        const SizedBox(height: 4),
        Text(body, style: sans(12, color: c.text2)),
        if (problem.detail.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(problem.detail, style: mono(11, color: c.text3)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          if (problem.needsSettings) ...[
            KButton.primary(label: 'Open Settings', height: 28, fontSize: 12, onTap: () => showSettingsDialog(context, initial: SettingsTab.repos)),
            const SizedBox(width: 8),
          ],
          KButton(label: 'Retry', height: 28, fontSize: 12, onTap: () => onRetry()),
        ]),
      ]),
    );
  }
}

class _PrRow extends StatelessWidget {
  const _PrRow({required this.pr});
  final RepoPullRequest pr;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = switch (pr.state) {
      RepoPrState.draft => c.acc,
      RepoPrState.reviewRequested => c.warn,
      RepoPrState.changesRequested => c.err,
      RepoPrState.ready || RepoPrState.approved => c.ok,
    };
    final checks = '${pr.checksPassed}/${pr.checksTotal} checks';
    final (String ckText, Color ckColor, IconData ckIcon, String ckTip) = switch (pr.checksState) {
      null => ('no checks', c.text3, KIcons.remove, 'No runs yet'),
      CiState.failed => (checks, c.err, KIcons.close, 'Checks failed'),
      CiState.running => (checks, c.acc, KIcons.clock, 'Checks running'),
      CiState.queued => (checks, c.text3, KIcons.clock, 'Checks queued'),
      CiState.passed => (checks, c.ok, KIcons.check, 'All checks passed'),
      CiState.canceled || CiState.skipped => (checks, c.text3, KIcons.remove, 'Checks canceled'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(pr.number, style: mono(11.5, color: c.text2, height: 1.35)),
          const SizedBox(width: 8),
          Expanded(
            child: Row(children: [
              Flexible(child: Text(pr.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: FontWeight.w500, color: c.text))),
              if (pr.mine) ...[
                const SizedBox(width: 8),
                _Chip('you', color: c.acc, background: c.accSoft, monospace: false, size: 10),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Dot(color, size: 6),
          const SizedBox(width: 5),
          Text(pr.state.label, style: sans(11.5, weight: FontWeight.w600, color: color)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: Row(children: [
              _Avatar(pr.author, me: pr.mine, size: 16),
              const SizedBox(width: 7),
              Text(pr.author, style: sans(11.5, color: c.text2)),
              const SizedBox(width: 7),
              Flexible(child: Text(pr.branch, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3, height: 1.35))),
              if (pr.reviewRequestedFromMe) Text(' · your review', style: sans(11.5, weight: FontWeight.w500, color: c.warn)),
            ]),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: ckTip,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ckIcon, size: 12, color: ckColor),
              const SizedBox(width: 4),
              Text(ckText, style: sans(11.5, color: ckColor)),
            ]),
          ),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Branches & worktrees
// ---------------------------------------------------------------------------

const _lastW = 112.0;
const _vsW = 78.0;
const _actionW = 36.0;

class _BranchesSection extends StatelessWidget {
  const _BranchesSection({required this.source});
  final RepoActivitySource source;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = source.branches;
    final trees = rows.where((b) => b.worktree != null).length;
    final remote = rows.length - trees;
    final head = sans(11, weight: FontWeight.w500, color: c.text3);
    return _Panel(
      icon: KIcons.branch,
      title: 'Branches & worktrees',
      subtitle: '$trees ${trees == 1 ? 'worktree' : 'worktrees'} · $remote ${remote == 1 ? 'remote branch' : 'remote branches'}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
          child: Row(children: [
            Expanded(child: Text('Branch', style: head)),
            SizedBox(width: _lastW, child: Text('Last commit', style: head)),
            SizedBox(width: _vsW, child: Text('vs ${source.mainBranch}', maxLines: 1, overflow: TextOverflow.ellipsis, style: head)),
            const SizedBox(width: _actionW),
          ]),
        ),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            for (final b in rows) _BranchRow(branch: b, me: source.currentUser),
            if (rows.isEmpty) _Note(source.loading ? 'Loading branches…' : (source.error ?? 'No branches yet.')),
          ]),
        ),
      ]),
    );
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({required this.branch, required this.me});
  final RepoBranch branch;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final b = branch;
    final w = b.worktree;
    final agent = w == null || w.agent.isEmpty || w.agent == 'No agent' ? null : w.agent;
    final vs = b.vsMain;
    final vsColor = vs == null || vs == 'up to date' ? c.text3 : (b.isMain && RegExp(r'↓[1-9]').hasMatch(vs) ? c.warn : c.text2);
    final author = b.lastAuthor;
    final last = b.lastTime;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Tooltip(
                  message: b.name,
                  waitDuration: const Duration(milliseconds: 900),
                  child: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, color: c.text, height: 1.35)),
                ),
              ),
              if (b.isMain) ...[const SizedBox(width: 6), _Chip('principal', color: c.acc, background: c.accSoft, monospace: false, size: 9.5)],
              if (b.localOnly) ...[const SizedBox(width: 6), _Chip('local only', color: c.warn, background: c.warnSoft, monospace: false, size: 9.5)],
            ]),
            const SizedBox(height: 2),
            Row(children: [
              if (agent != null && w != null) ...[
                Dot(toneColor(context, w.tone), size: 6),
                const SizedBox(width: 5),
                Flexible(child: Text(agent, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, weight: FontWeight.w500, color: toneColor(context, w.tone)))),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: w == null
                    ? Text('remote only · no worktree', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3))
                    : Text(w.path, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3, height: 1.35)),
              ),
            ]),
          ]),
        ),
        SizedBox(
          width: _lastW,
          child: author == null
              ? Text('—', style: sans(11.5, color: c.text3))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _Avatar(author, me: author == me, size: 15),
                    const SizedBox(width: 5),
                    Expanded(child: Text(author, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text2))),
                  ]),
                  const SizedBox(height: 2),
                  Text(last == null ? 'no commits yet' : _rel(last), maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3)),
                ]),
        ),
        SizedBox(width: _vsW, child: Text(vs ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: vsColor, height: 1.35))),
        SizedBox(
          width: _actionW,
          child: Align(
            alignment: Alignment.centerRight,
            child: w != null
                ? KIconButton(icon: KIcons.terminal, label: 'Open terminal in ${b.name}', size: 26, iconSize: 13, filled: true, color: c.text, onTap: () => s.openWorktree(w))
                : KIconButton(icon: KIcons.add, label: 'Create a worktree for ${b.name}', size: 26, iconSize: 13, onTap: s.requestNewWorktree),
          ),
        ),
      ]),
    );
  }
}
