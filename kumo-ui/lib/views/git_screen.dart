import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../editor/diff_colors.dart';
import '../editor/syntax.dart';
import '../shell/screen_chrome.dart';
import '../shell/sidebar.dart' show toneColor;
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';

/// Git view. Everything on the right is scoped to the *current* worktree
/// (AppState.activeWorktree): pull requests of its repo only, and pipelines
/// of its branch only — including the "not pushed yet" states.
class GitScreen extends StatefulWidget {
  const GitScreen({super.key});

  @override
  State<GitScreen> createState() => _GitScreenState();
}

class _GitScreenState extends State<GitScreen> {
  /// Worktree paths pushed during this session (optimistic; the core will
  /// confirm and stream the new pipeline run).
  final Set<String> _pushed = {};

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final repo = s.activeRepo;
    final wt = s.activeWorktreeEntry ?? repo?.worktrees.firstOrNull;
    if (repo == null || wt == null) {
      return ScreenFrame(
        toolbar: const ScreenToolbar(breadcrumb: Breadcrumb(icon: KIcons.branch, parts: ['Git'])),
        body: Center(child: Text('Add a repository to a namespace to see its worktrees here.', style: sans(12.5, color: c.text3))),
        status: const [],
      );
    }
    final prs = Mock.prs.where((p) => p.repo == repo.name).toList();
    final open = prs.where((p) => p.state != PrState.merged).length;

    return ScreenFrame(
      toolbar: ScreenToolbar(
        breadcrumb: Breadcrumb(icon: KIcons.branch, parts: ['Git', repo.name, wt.branch]),
        primary: KButton.primary(label: 'New worktree', icon: KIcons.add, height: 36, onTap: s.requestNewWorktree),
      ),
      body: LayoutBuilder(builder: (context, box) {
        final showAside = box.maxWidth >= 940;
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _WorktreeTable(pushed: _pushed),
              const SizedBox(height: 10),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
                  Expanded(flex: 10, child: _History()),
                  SizedBox(width: 10),
                  Expanded(flex: 13, child: _Diff()),
                ]),
              ),
            ]),
          ),
          if (showAside) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 330,
              child: ListView(padding: EdgeInsets.zero, children: [
                _PullRequests(repo: repo, prs: prs, currentBranch: wt.branch),
                const SizedBox(height: 10),
                _Pipelines(
                  repo: repo,
                  worktree: wt,
                  pushedNow: _pushed.contains(wt.path),
                  onPush: () => setState(() => _pushed.add(wt.path)),
                ),
              ]),
            ),
          ],
        ]);
      }),
      status: [
        const StatusText('Fetched all remotes 2 min ago'),
        StatusText('$open open ${open == 1 ? 'PR' : 'PRs'} in ${repo.name}'),
        const Spacer(),
        StatusText('${Mock.ciNames[repo.host]}', icon: KIcons.cluster),
      ],
    );
  }
}

class _WorktreeTable extends StatelessWidget {
  const _WorktreeTable({required this.pushed});
  final Set<String> pushed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final rows = [for (final r in s.workspace.repos) ...s.worktreesOf(r)];
    TextStyle head() => sans(11, weight: FontWeight.w500, color: c.text3);
    Widget cell(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), child: child);
    String syncOf(Worktree w) {
      if (!pushed.contains(w.path)) return w.sync;
      return w.sync == 'local only' ? 'up to date' : w.sync.replaceFirst(RegExp(r'↑\d+'), '↑0');
    }

    return Section(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('Worktrees', style: sans(22, weight: FontWeight.w600, color: c.text, letterSpacing: -0.4)),
          const SizedBox(width: 10),
          Flexible(child: Text('${rows.length} checkouts · click a path to make it current', overflow: TextOverflow.ellipsis, style: sans(12, color: c.text3))),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: box.maxWidth < 720 ? 720 : box.maxWidth,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                columnWidths: const {0: FlexColumnWidth(1.4), 1: FlexColumnWidth(1.6)},
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
                    children: [for (final h in ['Path', 'Branch', 'vs remote', 'Agent', 'Changes', '']) cell(Text(h, style: head()))],
                  ),
                  for (final w in rows)
                    TableRow(
                      decoration: BoxDecoration(
                        color: s.isActiveWorktree(w) ? c.accSoft : null,
                        border: Border(bottom: BorderSide(color: c.divider)),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                          child: KPressable(
                            onTap: () => s.selectWorktree(w.branch, path: w.path),
                            selected: s.isActiveWorktree(w),
                            semanticLabel: 'Make ${w.path} the current worktree',
                            tooltip: 'Make this the current worktree',
                            builder: (context, hover, focus) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(color: hover ? c.tile : null, borderRadius: BorderRadius.circular(6)),
                              child: Text(w.path, style: mono(11.5, color: c.text2)),
                            ),
                          ),
                        ),
                        cell(Text(w.branch, style: mono(11.5, color: c.text))),
                        cell(Builder(builder: (context) {
                          final sync = syncOf(w);
                          final warn = sync.contains('behind') || sync == 'local only';
                          return Text(sync, style: mono(11.5, color: warn ? c.warn : c.text2));
                        })),
                        cell(Row(mainAxisSize: MainAxisSize.min, children: [
                          Dot(toneColor(context, w.tone), size: 6),
                          const SizedBox(width: 6),
                          Text(w.agent, style: sans(12.5, weight: FontWeight.w500, color: toneColor(context, w.tone))),
                        ])),
                        cell(Text(w.changes, style: sans(12.5, color: c.text3))),
                        Align(
                          alignment: Alignment.centerRight,
                          child: KIconButton(
                            icon: KIcons.terminal,
                            label: 'Open terminal in ${w.branch}',
                            filled: true,
                            onTap: () {
                              s.selectWorktree(w.branch, path: w.path);
                              s.view = KumoView.terminal;
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Commit graph for price-admin: main + two feature lanes.
class _History extends StatelessWidget {
  const _History();

  static const commits = [
    (1, 'feat: batch upsert with CopyFrom', 'Claude · 2m'),
    (1, 'feat: BulkDiscount aggregate', 'Claude · 9m'),
    (2, 'fix: round half-up after discount', 'Codex · 6m'),
    (0, 'Merge #518 currency rounding in exports', '2h'),
    (0, 'chore: bump pgx to v5.7', '1d'),
    (0, 'Merge #509 remove v1 price endpoints', '2d'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lanes = [c.text3, c.acc, c.warn];
    return Section(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('History', style: sans(13, weight: FontWeight.w600, color: c.text)),
          const SizedBox(width: 8),
          Text('price-admin', style: sans(12, color: c.text3)),
          const Spacer(),
          for (final (i, name) in const [(0, 'main'), (1, 'PRC-412'), (2, 'PRC-398')]) ...[
            Dot(lanes[i], size: 8),
            const SizedBox(width: 5),
            Text(name, style: sans(11, color: c.text3)),
            const SizedBox(width: 10),
          ],
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Semantics(
              label: 'Commit graph: two feature branches off main, PRC-412 with two commits and PRC-398 with one',
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 104,
                  height: commits.length * 32.0,
                  child: CustomPaint(painter: _GraphPainter(lanes: lanes, dotFill: c.isDark ? const Color(0xFF171923) : const Color(0xFFFFFFFF))),
                ),
                Expanded(
                  child: Column(children: [
                    for (final (_, msg, meta) in commits)
                      SizedBox(
                        height: 32,
                        child: Row(children: [
                          Expanded(child: Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, color: c.text))),
                          Text(meta, style: sans(11, color: c.text3)),
                        ]),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({required this.lanes, required this.dotFill});
  final List<Color> lanes;
  final Color dotFill;

  @override
  void paint(Canvas canvas, Size size) {
    const x = [12.0, 48.0, 84.0];
    double y(int row) => row * 32.0 + 16;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x[0], 0), Offset(x[0], size.height), stroke..color = lanes[0]);
    final fork = y(3);
    canvas.drawPath(
      Path()
        ..moveTo(x[0], fork)
        ..cubicTo(x[0], fork - 18, x[1], fork - 10, x[1], fork - 28)
        ..lineTo(x[1], y(0)),
      stroke..color = lanes[1],
    );
    canvas.drawPath(
      Path()
        ..moveTo(x[0], fork)
        ..cubicTo(x[0], fork - 12, x[2], fork - 6, x[2], fork - 20)
        ..lineTo(x[2], y(2)),
      stroke..color = lanes[2],
    );
    for (var i = 0; i < _History.commits.length; i++) {
      final lane = _History.commits[i].$1;
      final p = Offset(x[lane], y(i));
      canvas.drawCircle(p, 5, Paint()..color = dotFill);
      canvas.drawCircle(p, 5, stroke..color = lanes[lane]);
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => old.lanes != lanes || old.dotFill != dotFill;
}

/// Diff-only syntax colors. They avoid green and red hues so code reads
/// clearly on added/removed rows, and the row tint stays a hint: the solid
/// bar and the +/− sign carry the add/remove signal.
class _Diff extends StatelessWidget {
  const _Diff();

  static const lines = [
    ('h', '', '@@ -48,12 +48,37 @@ Repository'),
    ('c', '48', 'func (r *Repository) UpsertMany(ctx context.Context, ds []Discount) error {'),
    ('d', '49', '    for _, d := range ds {'),
    ('d', '50', '        if err := r.Upsert(ctx, d); err != nil {'),
    ('d', '51', '            return err'),
    ('d', '52', '        }'),
    ('d', '53', '    }'),
    ('d', '54', '    return nil'),
    ('a', '49', '    rows := make([][]any, 0, len(ds))'),
    ('a', '50', '    for _, d := range ds {'),
    ('a', '51', '        rows = append(rows, []any{d.SKU, d.Percent, d.StartsAt, d.EndsAt})'),
    ('a', '52', '    }'),
    ('a', '53', '    _, err := r.db.CopyFrom(ctx,'),
    ('a', '54', '        pgx.Identifier{"discounts_staging"},'),
    ('a', '55', '        []string{"sku", "percent", "starts_at", "ends_at"},'),
    ('a', '56', '        pgx.CopyFromRows(rows),'),
    ('a', '57', '    )'),
    ('a', '58', '    return err'),
    ('c', '59', '}'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = DiffColors.of(c);
    // (row background, bar, sign, sign color)
    (Color?, Color?, String, Color) rowStyle(String k) => switch (k) {
          'h' => (c.hunkBg, null, '', c.text3),
          'a' => (d.add, c.ok, '+', c.ok),
          'd' => (d.del, c.err, '−', c.err),
          _ => (null, null, ' ', c.text3),
        };
    final base = mono(11.5, height: 1);
    return GlassPanel(
      fill: c.term,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
          child: Row(children: [
            Icon(KIcons.file, size: 15, color: c.text3),
            const SizedBox(width: 8),
            Expanded(child: Text('internal/discount/repository.go', maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(12, weight: FontWeight.w500, color: c.text))),
            Text('+31', style: mono(11.5, color: c.ok)),
            const SizedBox(width: 6),
            Text('−6', style: mono(11.5, color: c.err)),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final (k, n, t) in lines)
                  Builder(builder: (context) {
                    final (bg, bar, sign, signColor) = rowStyle(k);
                    final code = k == 'h'
                        ? <InlineSpan>[TextSpan(text: t, style: TextStyle(color: c.acc, fontWeight: FontWeight.w500))]
                        : <InlineSpan>[for (final (text, tok) in Syntax.line(Lang.go, t)) TextSpan(text: text, style: d.styleFor(tok))];
                    return Container(
                      color: bg,
                      height: 20,
                      padding: const EdgeInsets.only(right: 16),
                      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Container(width: 3, color: bar),
                        SizedBox(
                          width: 41,
                          child: Align(alignment: Alignment.centerRight, child: Text(n, style: base.copyWith(color: c.text3))),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(width: 14, child: Align(alignment: Alignment.centerLeft, child: Text(sign, style: base.copyWith(color: signColor, fontWeight: FontWeight.w700)))),
                        Align(alignment: Alignment.centerLeft, child: Text.rich(TextSpan(style: base, children: code))),
                      ]),
                    );
                  }),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Pull requests of the current worktree's repo only.
class _PullRequests extends StatelessWidget {
  const _PullRequests({required this.repo, required this.prs, required this.currentBranch});
  final Repo repo;
  final List<PullRequest> prs;
  final String currentBranch;

  (String, Color) _state(KumoPalette c, PrState s) => switch (s) {
        PrState.ready => ('Ready', c.ok),
        PrState.draft => ('Draft', c.acc),
        PrState.reviewRequested => ('Review requested', c.warn),
        PrState.changesRequested => ('Changes requested', c.err),
        PrState.merged => ('Merged', c.text3),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Section(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: PanelHeading(
            'Pull requests',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              TagChip(repo.host),
              const SizedBox(width: 5),
              Text('${repo.name} · current worktree', style: sans(11, color: c.text3)),
            ]),
          ),
        ),
        if (prs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text('No pull requests in ${repo.name} yet.', style: sans(12, color: c.text3)),
          ),
        for (final p in prs)
          Builder(builder: (context) {
            final on = p.branch == currentBranch;
            final (label, col) = _state(c, p.state);
            return KPressable(
              onTap: () {},
              selected: on,
              semanticLabel: '${p.number} ${p.title}, $label',
              builder: (context, hover, focus) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(10),
                decoration: on ? chipDecoration(c, radius: 14, fill: c.tabActive) : BoxDecoration(color: hover ? c.tile : null, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    TagChip(p.host),
                    const SizedBox(width: 6),
                    Flexible(child: Text(p.branch, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3))),
                    const SizedBox(width: 6),
                    Text(p.number, style: mono(11, color: c.text2)),
                  ]),
                  const SizedBox(height: 5),
                  Text(p.title, style: sans(13, weight: FontWeight.w500, color: c.text, height: 1.3)),
                  const SizedBox(height: 5),
                  Row(children: [
                    Dot(col, size: 6),
                    const SizedBox(width: 6),
                    Text(label, style: sans(11.5, weight: FontWeight.w600, color: col)),
                    const SizedBox(width: 4),
                    Flexible(child: Text('· ${p.note}', overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3))),
                  ]),
                ]),
              ),
            );
          }),
      ]),
    );
  }
}

/// Pipelines of the current branch only, with the two "nothing ran yet"
/// cases: branch never pushed, and local commits not pushed.
class _Pipelines extends StatelessWidget {
  const _Pipelines({required this.repo, required this.worktree, required this.pushedNow, required this.onPush});
  final Repo repo;
  final Worktree worktree;
  final bool pushedNow;
  final VoidCallback onPush;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = worktree;
    final ci = Mock.ciNames[repo.host] ?? 'CI';
    final unpushed = pushedNow ? 0 : w.unpushed;
    final neverPushed = !w.everPushed && !pushedNow;
    final run = pushedNow
        ? PipelineRun(
            id: '${w.everPushed ? 'run #8813' : 'run #1'} · just now',
            commit: w.everPushed ? 'feat: batch upsert with CopyFrom · pushed just now' : 'First push of ${w.branch}',
            status: RunStatus.queued,
            checks: const [
              ('build', 'queued', CheckState.waiting),
              ('unit tests', 'queued', CheckState.waiting),
              ('golangci-lint', 'queued', CheckState.waiting),
              ('integration · testcontainers', 'queued', CheckState.waiting),
            ],
          )
        : Mock.runs[w.path];
    final canPush = neverPushed || unpushed > 0;
    final (runLabel, runFg, runBg) = switch (run?.status) {
      RunStatus.passed => ('Passed', c.ok, c.okSoft),
      RunStatus.running => ('Running', c.acc, c.accSoft),
      _ => ('Queued', c.text2, c.tile),
    };
    (Color, Color) checkColors(CheckState s) => switch (s) {
          CheckState.ok => (c.ok, c.okSoft),
          CheckState.running => (c.acc, c.accSoft),
          CheckState.waiting => (c.text3, c.tile),
        };
    final commits = unpushed == 1 ? '1 commit' : '$unpushed commits';

    return Section(
      strong: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('$ci · pipelines for this branch', style: sans(11, color: c.text3)),
        const SizedBox(height: 2),
        Text(w.branch, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(12.5, weight: FontWeight.w600, color: c.text)),
        const SizedBox(height: 12),
        if (run == null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.chipBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(KIcons.upload, size: 15, color: c.text3),
                const SizedBox(width: 8),
                Text('No pipelines yet', style: sans(13, weight: FontWeight.w600, color: c.text)),
              ]),
              const SizedBox(height: 6),
              Text(
                neverPushed
                    ? (unpushed > 0
                        ? 'This branch only exists locally. $commits waiting; pipelines start after the first push.'
                        : 'This branch only exists locally and has no commits yet. Pipelines start after the first push.')
                    : 'Nothing has run for this branch on $ci yet.',
                style: sans(12, color: c.text2, height: 1.5),
              ),
            ]),
          )
        else ...[
          Row(children: [
            Pill(label: runLabel, color: runFg, background: runBg),
            const SizedBox(width: 8),
            Flexible(child: Text(run.id, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3))),
          ]),
          const SizedBox(height: 6),
          Text(run.commit, style: sans(12, color: c.text2)),
          const SizedBox(height: 10),
          for (final (name, time, state) in run.checks)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(color: checkColors(state).$2, shape: BoxShape.circle),
                  child: state == CheckState.ok ? Icon(KIcons.check, size: 11, color: checkColors(state).$1) : Center(child: Dot(checkColors(state).$1, size: 6)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(name, style: sans(12.5, color: c.text2))),
                Text(time, style: mono(11, color: c.text3)),
              ]),
            ),
        ],
        if (!neverPushed && unpushed > 0) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: c.warnSoft, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(KIcons.upload, size: 15, color: c.warn),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$commits not pushed. ', style: TextStyle(color: c.warn, fontWeight: FontWeight.w600)),
                    TextSpan(text: 'No pipeline has run for ${unpushed == 1 ? 'it' : 'them'} yet.', style: TextStyle(color: c.text2)),
                  ]),
                  style: sans(12, height: 1.45),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          if (canPush) ...[
            Expanded(child: KButton.primary(label: neverPushed ? 'Push branch' : 'Push $commits', expand: true, onTap: onPush)),
            const SizedBox(width: 8),
          ],
          Expanded(child: KButton(label: 'All runs in $ci', expand: true, onTap: () {})),
        ]),
      ]),
    );
  }
}
