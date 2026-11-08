/// What the Git view shows beyond activity: a commit's changes, the
/// repository's releases and tags, and a pull request's review threads.
/// Models, the pure rules the view applies (which release to compare
/// with), and the design's mock data.
library;

import 'package:flutter/foundation.dart';

import 'changes.dart';

// ---------------------------------------------------------------------------
// A commit's changes
// ---------------------------------------------------------------------------

/// How a file changed in a commit.
enum CommitFileKind {
  added('A'),
  modified('M'),
  deleted('D'),
  renamed('R');

  const CommitFileKind(this.letter);
  final String letter;
}

/// One line of a hunk, with its numbers in the old and new file.
@immutable
class HunkLine {
  const HunkLine(this.kind, this.text, {this.oldNo, this.newNo});
  final DiffKind kind;
  final String text;
  final int? oldNo;
  final int? newNo;
}

/// `@@ -72,11 +72,28 @@ func …`: where it starts and its lines.
@immutable
class DiffHunk {
  const DiffHunk({required this.oldStart, required this.newStart, required this.lines, this.section = ''});
  final int oldStart;
  final int newStart;

  /// What git prints after the second `@@` (the enclosing function).
  final String section;
  final List<HunkLine> lines;

  int get oldCount => lines.where((l) => l.kind != DiffKind.added).length;
  int get newCount => lines.where((l) => l.kind != DiffKind.deleted).length;
  String get header => '@@ -$oldStart,$oldCount +$newStart,$newCount @@${section.isEmpty ? '' : ' $section'}';

  /// Lines from `+x`, `-x` and ` x` strings, numbered from where it starts.
  factory DiffHunk.parse(int oldStart, int newStart, List<String> src, {String section = ''}) {
    var o = oldStart, n = newStart;
    return DiffHunk(oldStart: oldStart, newStart: newStart, section: section, lines: [
      for (final l in src)
        switch (l.isEmpty ? ' ' : l[0]) {
          '+' => HunkLine(DiffKind.added, l.substring(1), newNo: n++),
          '-' => HunkLine(DiffKind.deleted, l.substring(1), oldNo: o++),
          _ => HunkLine(DiffKind.context, l.isEmpty ? '' : l.substring(1), oldNo: o++, newNo: n++),
        },
    ]);
  }
}

/// A file a commit touched.
@immutable
class CommitFile {
  const CommitFile({required this.path, required this.kind, this.hunks = const [], this.oldPath, this.binary = false, this.cut = false, int? added, int? deleted})
      : _added = added,
        _deleted = deleted;
  final String path;
  final CommitFileKind kind;
  final List<DiffHunk> hunks;

  /// Where a renamed file was.
  final String? oldPath;
  final bool binary;

  /// Too many lines changed to send them: only the counts came.
  final bool cut;
  final int? _added;
  final int? _deleted;

  /// Counts as the daemon reports them, else from the hunks.
  int get added => _added ?? hunks.fold(0, (s, h) => s + h.lines.where((l) => l.kind == DiffKind.added).length);
  int get deleted => _deleted ?? hunks.fold(0, (s, h) => s + h.lines.where((l) => l.kind == DiffKind.deleted).length);
  String get name => path.substring(path.lastIndexOf('/') + 1);
  String get dir => path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
}

/// Everything a commit changed.
@immutable
class CommitDetail {
  const CommitDetail({required this.sha, required this.files, this.body = '', this.parents = const [], this.time});
  final String sha;

  /// The message after the subject line.
  final String body;
  final List<String> parents;
  final List<CommitFile> files;

  /// Exact time, for the tooltip; null when unknown.
  final DateTime? time;

  int get added => files.fold(0, (s, f) => s + f.added);
  int get deleted => files.fold(0, (s, f) => s + f.deleted);
}

// ---------------------------------------------------------------------------
// Releases and tags
// ---------------------------------------------------------------------------

enum ReleaseKind {
  release,
  preRelease,
  draft,

  /// A tag nobody turned into a release.
  tagOnly,
}

/// A release, or a bare tag, of the repository.
@immutable
class RepoRelease {
  const RepoRelease({
    required this.tag,
    required this.kind,
    required this.time,
    this.name = '',
    this.notes = '',
    this.author,
    this.sha = '',
    this.url = '',
    this.checks,
    this.assets = const [],
  });
  final String tag;
  final ReleaseKind kind;
  final DateTime time;

  /// The release's title; empty when it has none.
  final String name;

  /// Markdown; empty when it has none.
  final String notes;
  final String? author;
  final String sha;
  final String url;

  /// The latest run on the tagged commit, when known.
  final bool? checks;

  /// (file name, size label).
  final List<(String, String)> assets;

  bool get isTag => kind == ReleaseKind.tagOnly;

  RepoRelease copyWith({String? name, String? notes, ReleaseKind? kind}) => RepoRelease(
        tag: tag,
        kind: kind ?? this.kind,
        time: time,
        name: name ?? this.name,
        notes: notes ?? this.notes,
        author: author,
        sha: sha,
        url: url,
        checks: checks,
        assets: assets,
      );
}

/// A pull request merged in a range of history: (ref, title, author, ticket).
typedef MergedPr = (String, String, String, String?);

/// What changed between two tags.
@immutable
class ReleaseRange {
  const ReleaseRange({
    required this.since,
    required this.commits,
    required this.added,
    required this.deleted,
    required this.files,
    this.prs = const [],
  });

  /// The tag it starts after; null: from the first commit.
  final String? since;
  final int commits;
  final int added;
  final int deleted;
  final int files;
  final List<MergedPr> prs;

  List<String> get tickets => [
        ...{
          for (final p in prs)
            if (p.$4 != null && p.$4!.isNotEmpty) p.$4!,
        },
      ];
  List<String> get people => [...{for (final p in prs) p.$3}];
}

/// Which release [releases] (newest first) at [index] is best compared
/// with: a pre-release or draft with the latest full release; a release or
/// tag with the release before it (bare tags and pre-releases in between
/// are folded in). Null when nothing before it is a release; with no older
/// tag at all it's the first, and is described from the project instead.
int? previousReleaseIndex(List<RepoRelease> releases, int index) {
  for (var j = index + 1; j < releases.length; j++) {
    if (releases[j].kind == ReleaseKind.release) return j;
  }
  return null;
}

/// The newest full release: what hosts call "Latest".
int? latestReleaseIndex(List<RepoRelease> releases) {
  for (var j = 0; j < releases.length; j++) {
    if (releases[j].kind == ReleaseKind.release) return j;
  }
  return null;
}

/// The tags folded into a comparison of [index] with [since] (exclusive):
/// what shows as "Includes v1.7.3 (a tag without release)".
List<RepoRelease> skippedBetween(List<RepoRelease> releases, int index, int? since) =>
    releases.sublist(index + 1, since ?? releases.length);

/// `v1.8.0` → `v1.8.1` (the hotfix after it); the tag itself when it isn't
/// semver.
String nextPatchOf(String tag) {
  final m = RegExp(r'^(v?)(\d+)\.(\d+)\.(\d+)').firstMatch(tag);
  if (m == null) return tag;
  return '${m[1]}${m[2]}.${m[3]}.${int.parse(m[4]!) + 1}';
}

// ---------------------------------------------------------------------------
// Review threads
// ---------------------------------------------------------------------------

/// What a review thread looks like it asks for (a guess from its words).
enum ThreadKind {
  change('Change'),
  nit('Nit'),
  question('Question');

  const ThreadKind(this.label);
  final String label;

  static ThreadKind of(String body) {
    final t = body.trim().toLowerCase();
    if (t.startsWith('nit') || t.startsWith('minor') || t.startsWith('optional')) return ThreadKind.nit;
    if (t.endsWith('?') && !t.contains('should') && !t.contains('could we') && !t.contains('can we')) return ThreadKind.question;
    return ThreadKind.change;
  }
}

/// An open (or resolved) review thread on a pull request.
@immutable
class ReviewThread {
  const ReviewThread({required this.id, required this.author, required this.path, required this.body, required this.time, this.line, this.resolved = false});
  final String id;
  final String author;
  final String path;
  final int? line;

  /// Its first comment.
  final String body;
  final DateTime time;
  final bool resolved;

  ThreadKind get kind => ThreadKind.of(body);
  String get where => line == null ? path : '$path:$line';
}

// ---------------------------------------------------------------------------
// Design mocks
// ---------------------------------------------------------------------------

/// A commit's changes as the design has them: three written out, the rest
/// made from the subject so every commit opens to something.
CommitDetail mockCommitDetail(String sha, String subject, {String parent = ''}) {
  final written = _writtenCommits[sha];
  if (written != null) return written;
  final type = RegExp(r'^(\w+)').firstMatch(subject)?.group(1) ?? 'chore';
  final words = subject.replaceFirst(RegExp(r'^\w+(\(.+?\))?!?: '), '').split(' ');
  final slug = words.length < 2 ? (words.firstOrNull ?? 'change').toLowerCase() : words.sublist(words.length - 2).join('_').replaceAll(RegExp(r'[^A-Za-z0-9_]'), '').toLowerCase();
  final s = subject.toLowerCase();
  final area = s.contains('discount')
      ? 'discount'
      : (s.contains('price') || s.contains('currency'))
          ? 'price'
          : s.contains('rule')
              ? 'rules'
              : (s.contains('role') || s.contains('scope') || s.contains('perm'))
                  ? 'authz'
                  : s.contains('cache')
                      ? 'cache'
                      : 'core';
  final phrase = words.join(' ');
  final files = <CommitFile>[];
  if (s.contains('bump') || s.contains(' go 1.')) {
    files.add(CommitFile(path: 'go.mod', kind: CommitFileKind.modified, hunks: [
      DiffHunk.parse(3, 3, [' ', '-go 1.22', '+go 1.23', ' '], section: 'module'),
    ]));
    files.add(CommitFile(path: 'go.sum', kind: CommitFileKind.modified, hunks: [
      DiffHunk.parse(40, 40, ['-github.com/jackc/pgx/v5 v5.6.0 h1:Zq3…=', '+github.com/jackc/pgx/v5 v5.7.1 h1:Kd8…=']),
    ]));
  } else if (type == 'docs') {
    files.add(CommitFile(path: 'docs/runbooks/$slug.md', kind: CommitFileKind.added, hunks: [
      DiffHunk.parse(0, 1, ['+# $phrase', '+', '+1. Check the import job in Grafana.', '+2. Roll back with `make rollback IMPORT=<id>`.']),
    ]));
  } else if (type == 'refactor') {
    files.add(CommitFile(path: 'internal/$area/engine/$slug.go', oldPath: 'internal/$area/$slug.go', kind: CommitFileKind.renamed, hunks: [
      DiffHunk.parse(1, 1, ['-package $area', '+package engine', ' ']),
    ]));
    files.add(CommitFile(path: 'internal/$area/service.go', kind: CommitFileKind.modified, hunks: [
      DiffHunk.parse(5, 5, [' import (', '+\t"price-admin/internal/$area/engine"', ' )'], section: 'import ('),
    ]));
  } else {
    final added = type == 'feat';
    final fn = slug.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join();
    files.add(CommitFile(
      path: 'internal/$area/$slug.go',
      kind: added ? CommitFileKind.added : CommitFileKind.modified,
      hunks: [
        added
            ? DiffHunk.parse(0, 1, ['+package $area', '+', '+// $fn: $phrase.', '+func $fn(ctx context.Context) error {', '+\treturn nil', '+}'])
            : DiffHunk.parse(30, 30, [' \tif err != nil {', '-\t\treturn nil', '+\t\treturn fmt.Errorf("$phrase: %w", err)', ' \t}'], section: 'func (s *Service) Apply(ctx context.Context) error {'),
      ],
    ));
    files.add(CommitFile(path: 'internal/$area/${slug}_test.go', kind: added ? CommitFileKind.added : CommitFileKind.modified, hunks: [
      DiffHunk.parse(added ? 0 : 14, added ? 1 : 14, ['+func Test$fn(t *testing.T) {', '+\t// $phrase', '+}']),
    ]));
  }
  return CommitDetail(sha: sha, parents: [if (parent.isNotEmpty) parent], files: files);
}

final _writtenCommits = <String, CommitDetail>{
  '7be2f41': CommitDetail(
    sha: '7be2f41',
    parents: const ['2c9a0e5'],
    body: 'Bulk discounts are copied in batches of 500 into a temp table with pgx.CopyFrom,\nthen upserted from it in one statement per batch.\n\nPRC-412',
    files: [
      CommitFile(path: 'internal/discount/repository.go', kind: CommitFileKind.modified, hunks: [
        DiffHunk.parse(72, 72, section: 'func (r *Repository) UpsertBulk(ctx context.Context, ds []BulkDiscount) error {', [
          ' func (r *Repository) UpsertBulk(ctx context.Context, ds []BulkDiscount) error {',
          '-\tfor _, d := range ds {',
          '-\t\tif _, err := r.db.Exec(ctx, upsertSQL, d.SKU, d.Percent, d.From, d.To); err != nil {',
          '-\t\t\treturn fmt.Errorf("upsert %s: %w", d.SKU, err)',
          '-\t\t}',
          '-\t}',
          '-\treturn nil',
          '+\tfor _, batch := range chunk(ds, r.batchSize) {',
          '+\t\tif err := r.copyBatch(ctx, batch); err != nil {',
          '+\t\t\treturn fmt.Errorf("batch of %d: %w", len(batch), err)',
          '+\t\t}',
          '+\t}',
          '+\treturn nil',
          ' }',
          ' ',
          '+// copyBatch writes one batch: CopyFrom into a temp table, then one upsert.',
          '+func (r *Repository) copyBatch(ctx context.Context, ds []BulkDiscount) error {',
          '+\treturn pgx.BeginFunc(ctx, r.db, func(tx pgx.Tx) error {',
          '+\t\tif _, err := tx.Exec(ctx, createTempSQL); err != nil {',
          '+\t\t\treturn err',
          '+\t\t}',
          '+\t\trows := pgx.CopyFromSlice(len(ds), func(i int) ([]any, error) {',
          '+\t\t\td := ds[i]',
          '+\t\t\treturn []any{d.SKU, d.Category, d.Percent, d.From, d.To}, nil',
          '+\t\t})',
          '+\t\tif _, err := tx.CopyFrom(ctx, pgx.Identifier{"bulk_tmp"}, bulkColumns, rows); err != nil {',
          '+\t\t\treturn err',
          '+\t\t}',
          '+\t\t_, err := tx.Exec(ctx, upsertFromTempSQL)',
          '+\t\treturn err',
          '+\t})',
          '+}',
          ' ',
          ' func (r *Repository) ByCategory(ctx context.Context, cat string) ([]BulkDiscount, error) {',
        ]),
      ]),
      CommitFile(path: 'internal/discount/repository_test.go', kind: CommitFileKind.modified, hunks: [
        DiffHunk.parse(40, 40, section: 'func TestUpsertBulk(t *testing.T) {', [
          ' func TestUpsertBulk(t *testing.T) {',
          ' \trepo := newTestRepo(t)',
          '-\tds := fixtures(t, 3)',
          '+\tds := fixtures(t, 1203) // three batches of 500, the last one short',
          ' \trequire.NoError(t, repo.UpsertBulk(ctx, ds))',
          '+\tgot, err := repo.Count(ctx)',
          '+\trequire.NoError(t, err)',
          '+\trequire.Equal(t, 1203, got)',
          ' }',
        ]),
      ]),
      CommitFile(path: 'config/app.yaml', kind: CommitFileKind.modified, hunks: [
        DiffHunk.parse(18, 18, section: 'discounts:', [' discounts:', '   cache_ttl: 5m', '+  batch_size: 500', '   max_percent: 90']),
      ]),
    ],
  ),
  'a3f9c12': CommitDetail(
    sha: 'a3f9c12',
    parents: const ['9d02e1f'],
    body: 'GET /v2/prices/{sku}/history?from=&to= returns every price a SKU had,\nwith who changed it. Paginated, newest first.\n\nCloses PRC-401',
    files: [
      CommitFile(path: 'internal/api/history.go', kind: CommitFileKind.added, hunks: [
        DiffHunk.parse(0, 1, [
          '+package api',
          '+',
          '+// History lists every price a SKU had between from and to, newest first.',
          '+func (h *Handler) History(w http.ResponseWriter, r *http.Request) {',
          '+\tsku := chi.URLParam(r, "sku")',
          '+\tfrom, to, err := parseRange(r.URL.Query())',
          '+\tif err != nil {',
          '+\t\th.fail(w, http.StatusBadRequest, err)',
          '+\t\treturn',
          '+\t}',
          '+\titems, next, err := h.prices.History(r.Context(), sku, from, to, pageOf(r))',
          '+\tif err != nil {',
          '+\t\th.fail(w, http.StatusInternalServerError, err)',
          '+\t\treturn',
          '+\t}',
          '+\th.json(w, historyPage{Items: items, Next: next})',
          '+}',
        ]),
      ]),
      CommitFile(path: 'internal/api/router.go', kind: CommitFileKind.modified, hunks: [
        DiffHunk.parse(31, 31, section: 'func (h *Handler) Routes() http.Handler {', [
          ' \tr.Get("/v2/prices/{sku}", h.Price)',
          '+\tr.Get("/v2/prices/{sku}/history", h.History)',
          ' \tr.Put("/v2/prices/{sku}", h.SetPrice)',
        ]),
      ]),
      CommitFile(path: 'internal/price/repository.go', kind: CommitFileKind.modified, hunks: [
        DiffHunk.parse(104, 104, section: 'func (r *Repository) Set(ctx context.Context, p Price) error {', [
          ' }',
          ' ',
          '+func (r *Repository) History(ctx context.Context, sku string, from, to time.Time, p Page) ([]Change, string, error) {',
          '+\trows, err := r.db.Query(ctx, historySQL, sku, from, to, p.After, p.Size+1)',
          '+\tif err != nil {',
          '+\t\treturn nil, "", err',
          '+\t}',
          '+\treturn scanChanges(rows, p.Size)',
          '+}',
        ]),
      ]),
    ],
  ),
  '9d02e1f': CommitDetail(
    sha: '9d02e1f',
    parents: const ['4b81d07'],
    body: 'Exports rounded each line, then summed: totals were off by a cent.\nRound once, after summing, half-even like the price reader.',
    files: [
      CommitFile(path: 'internal/export/csv.go', kind: CommitFileKind.modified, hunks: [
        DiffHunk.parse(56, 56, section: 'func (e *Exporter) row(p Price) []string {', [
          ' func (e *Exporter) row(p Price) []string {',
          '-\tamount := math.Round(p.Amount*100) / 100',
          '+\tamount := p.Amount.RoundBank(2)',
          ' \treturn []string{',
          ' \t\tp.SKU,',
          "-\t\tstrconv.FormatFloat(amount, 'f', 2, 64),",
          '+\t\tamount.StringFixed(2),',
          ' \t\tp.Currency,',
        ]),
      ]),
      CommitFile(path: 'internal/export/csv_test.go', kind: CommitFileKind.modified, hunks: [
        DiffHunk.parse(22, 22, section: 'func TestRow(t *testing.T) {', [
          ' \t{"plain", price("10.00"), "10.00"},',
          '+\t{"half-even down", price("10.125"), "10.12"},',
          '+\t{"half-even up", price("10.135"), "10.14"},',
          ' }',
        ]),
      ]),
    ],
  ),
};

/// One release of the design, with what changed since the entry listed
/// below it (whatever that is).
class MockRelease {
  const MockRelease(this.release, {required this.commits, required this.added, required this.deleted, required this.files, this.prs = const []});
  final RepoRelease release;
  final int commits;
  final int added;
  final int deleted;
  final int files;
  final List<MergedPr> prs;
}

/// What changed from [index] back to [since] (exclusive; null: everything
/// listed), adding up each entry's own changes.
ReleaseRange mockRangeOf(List<MockRelease> list, int index, int? since) {
  final span = list.sublist(index, since ?? list.length);
  return ReleaseRange(
    since: since == null || since >= list.length ? null : list[since].release.tag,
    commits: span.fold(0, (s, r) => s + r.commits),
    added: span.fold(0, (s, r) => s + r.added),
    deleted: span.fold(0, (s, r) => s + r.deleted),
    files: span.fold(0, (s, r) => s + r.files),
    prs: [for (final r in span) ...r.prs],
  );
}

/// The design's releases, newest first, [now] being "now".
List<MockRelease> mockReleases(String repoName, String host, DateTime now) {
  DateTime ago(Duration d) => now.subtract(d);
  String url(String tag) => switch (host) {
        'GL' => 'https://gitlab.com/pricing/$repoName/-/releases/$tag',
        'BB' => 'https://bitbucket.org/pricing/$repoName/src/$tag',
        _ => 'https://github.com/pricing/$repoName/releases/tag/$tag',
      };
  const src = [('Source code (zip)', '1.4 MB'), ('Source code (tar.gz)', '1.1 MB')];
  switch (repoName) {
    case 'price-admin':
      return [
        MockRelease(
          RepoRelease(tag: 'v1.9.0-rc.1', kind: ReleaseKind.preRelease, time: ago(const Duration(hours: 2)), author: 'Mauri', sha: 'b41e9d0', url: url('v1.9.0-rc.1'), assets: src),
          commits: 6, added: 412, deleted: 96, files: 12,
          prs: const [('#528', 'feat: CSV imports report the rows that fail', 'Lucía', 'PRC-415'), ('#527', 'fix: round discounts half-even', 'Mauri', 'PRC-419')],
        ),
        MockRelease(
          RepoRelease(
            tag: 'v1.8.0',
            kind: ReleaseKind.release,
            time: ago(const Duration(days: 3)),
            name: 'Bulk discounts',
            author: 'Mauri',
            sha: '7f3a2c1',
            url: url('v1.8.0'),
            checks: true,
            assets: src,
            notes: '## Highlights\n- Discounts by category: one discount for every product in a category, sent over Kafka (`price.discounts.bulk.v1`).\n'
                '- Batch writes with `CopyFrom`, 500 discounts per transaction.\n## Fixes\n- The cache key includes the sales channel (#516).\n'
                '## Removed\n- The legacy v1 endpoints (#518).\n## Upgrade notes\n- New flag `bulkDiscounts`, off by default in production.',
          ),
          commits: 17, added: 1104, deleted: 352, files: 33,
          prs: const [
            ('#521', 'feat: bulk discounts by category', 'Mauri', 'PRC-412'),
            ('#519', 'feat(kafka): bulk discount consumer', 'Mauri', 'PRC-412'),
            ('#518', 'chore: drop the legacy v1 endpoints', 'Tomás', null),
            ('#516', 'fix: cache key includes the sales channel', 'Lucía', 'PRC-409'),
            ('#514', 'docs: bulk discount runbook', 'Valentina', null),
          ],
        ),
        MockRelease(
          RepoRelease(tag: 'v1.7.3', kind: ReleaseKind.tagOnly, time: ago(const Duration(days: 5)), author: 'Tomás', sha: '3c09e1a', url: url('v1.7.3'), checks: true),
          commits: 2, added: 18, deleted: 4, files: 2,
          prs: const [('#515', 'fix: nil price on deleted SKUs', 'Tomás', 'PRC-411')],
        ),
        MockRelease(
          RepoRelease(tag: 'v1.7.2', kind: ReleaseKind.release, time: ago(const Duration(days: 14)), author: 'Lucía', sha: 'e81d4f2', url: url('v1.7.2'), checks: true, assets: src),
          commits: 4, added: 61, deleted: 22, files: 5,
          prs: const [('#511', 'fix: timezone of scheduled prices', 'Lucía', 'PRC-402'), ('#510', 'chore: bump pgx to v5.7', 'Nico', null)],
        ),
        MockRelease(
          RepoRelease(
            tag: 'v1.7.1',
            kind: ReleaseKind.release,
            time: ago(const Duration(days: 21)),
            author: 'Mauri',
            sha: '5aa01c8',
            url: url('v1.7.1'),
            checks: true,
            assets: src,
            notes: '## Fixes\n- Margin rounding on prices with three decimals (#507).',
          ),
          commits: 3, added: 27, deleted: 9, files: 3,
          prs: const [('#507', 'fix: margin rounding with three decimals', 'Mauri', 'PRC-398')],
        ),
        MockRelease(
          RepoRelease(
            tag: 'v1.7.0',
            kind: ReleaseKind.release,
            time: ago(const Duration(days: 38)),
            name: 'Margin guardrails',
            author: 'Mauri',
            sha: '0d77b3e',
            url: url('v1.7.0'),
            checks: true,
            assets: src,
            notes: '## Highlights\n- Prices can’t go below their category’s minimum margin (#503).\n- Margin alerts on Slack for the pricing team (#501).',
          ),
          commits: 21, added: 1890, deleted: 640, files: 47,
          prs: const [
            ('#503', 'feat: block prices below the minimum margin', 'Mauri', 'PRC-381'),
            ('#501', 'feat: margin alerts on Slack', 'Valentina', 'PRC-384'),
            ('#499', 'refactor: pricing rules package', 'Tomás', null),
          ],
        ),
        MockRelease(
          RepoRelease(tag: 'v1.6.4', kind: ReleaseKind.release, time: ago(const Duration(days: 52)), author: 'Nico', sha: '1b9e0a4', url: url('v1.6.4'), checks: true, assets: src, notes: '## Fixes\n- Exports of more than 100,000 prices no longer time out.'),
          commits: 2, added: 40, deleted: 12, files: 2,
          prs: const [('#496', 'fix: stream large exports', 'Nico', 'PRC-377')],
        ),
      ];
    case 'price-reader-v2':
      return [
        MockRelease(
          RepoRelease(tag: 'v0.1.0', kind: ReleaseKind.release, time: ago(const Duration(days: 1)), author: 'Nico', sha: '9d2e417', url: url('v0.1.0'), checks: true, assets: src),
          commits: 87, added: 6210, deleted: 0, files: 64,
          prs: const [
            ('!226', 'feat: read-through cache for promo prices', 'Valentina', 'PRR-12'),
            ('!224', 'perf: batch Mongo lookups for price lists', 'Lucía', 'PRR-9'),
            ('!219', 'feat: expose p95 latency metric', 'Nico', null),
          ],
        ),
      ];
    default:
      return const [];
  }
}

/// The design's review threads, newest last.
List<ReviewThread> mockThreads(String prNumber, DateTime now) {
  DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));
  return switch (prNumber) {
    '#521' => [
        ReviewThread(id: 't0', author: 'Valentina', path: 'docs/runbooks/bulk-discounts.md', line: 5, body: 'Link the Grafana dashboard here.', time: ago(1800), resolved: true),
        ReviewThread(id: 't00', author: 'Lucía', path: 'internal/discount/bulk_test.go', line: 61, body: 'Table test?', time: ago(1740), resolved: true),
        ReviewThread(
          id: 't1',
          author: 'Lucía',
          path: 'internal/discount/repository.go',
          line: 88,
          body: 'If one CopyFrom batch fails we lose all 500 rows. Should we retry the batch on its own before failing the whole run?',
          time: ago(1560),
        ),
        ReviewThread(id: 't2', author: 'Tomás', path: 'internal/kafka/bulk_consumer.go', line: 42, body: 'The offset is committed before the write. If the pod dies in between we skip those discounts.', time: ago(1200)),
        ReviewThread(id: 't3', author: 'Lucía', path: 'internal/discount/bulk.go', line: 17, body: 'nit: MaxPercent → maxPercent, nothing outside the package uses it.', time: ago(1140)),
        ReviewThread(id: 't4', author: 'Tomás', path: 'deploy/k8s/values.yaml', line: 31, body: 'Why is bulkDiscounts on in staging by default?', time: ago(1080)),
      ],
    '#517' => [
        ReviewThread(id: 'u1', author: 'Mauri', path: 'internal/rules/engine.go', line: 120, body: 'This loses the rule order.', time: ago(2880)),
        ReviewThread(id: 'u2', author: 'Mauri', path: 'internal/rules/engine_test.go', line: 12, body: 'Why skip this test?', time: ago(2870)),
      ],
    _ => const [],
  };
}

/// What the design's agent did for each of #521's threads: (summary of
/// the change or '' for none, commit, reply).
const mockThreadWork = <String, (String, String, String)>{
  't1': ('Retries a failed batch up to 3 times before giving up', 'a91c4e2', 'Good catch: each batch now retries up to 3 times (a91c4e2), and only that batch fails if it still can’t be written.'),
  't2': ('Commits the offset after the write', '5d03b7f', 'Moved the commit after the write (5d03b7f). A crash in between now replays the message, and the upsert makes that safe.'),
  't3': ('Unexports MaxPercent', 'a91c4e2', 'Done.'),
  't4': ('', '', 'So QA can try it with the pricing team this sprint. It stays off in production until they sign off; the flag is per environment.'),
};
