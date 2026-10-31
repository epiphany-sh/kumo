import 'package:flutter/foundation.dart';

/// Where docs come from: Confluence through a Jira source's Atlassian
/// account, and the notes of Obsidian vault sources.
enum DocKind {
  confluence('Confluence', 'CF'),
  obsidian('Obsidian', 'OB');

  const DocKind(this.label, this.badge);
  final String label;

  /// The two-letter tile.
  final String badge;
}

/// A knowledge base, as the user knows it.
@immutable
class DocSourceInfo {
  const DocSourceInfo({required this.id, required this.kind, required this.name, this.location = ''});

  /// The task source it reads through.
  final String id;
  final DocKind kind;

  /// `acme.atlassian.net`, the vault's folder name.
  final String name;

  /// The site URL or the vault's path.
  final String location;
}

/// A page in a list.
@immutable
class DocSummary {
  const DocSummary({required this.id, required this.title, this.place = '', this.updated, this.author = '', this.url = '', this.excerpt = ''});

  /// `<source>/<external>`.
  final String id;
  final String title;

  /// The Confluence space, or the note's folder.
  final String place;
  final DateTime? updated;
  final String author;
  final String url;

  /// Text around a search match.
  final String excerpt;
}

/// One knowledge base's pages, or why they can't be read.
@immutable
class DocGroup {
  const DocGroup({required this.source, this.docs = const [], this.problem = '', this.problemIsAuth = false});
  final DocSourceInfo source;
  final List<DocSummary> docs;
  final String problem;

  /// The account's credentials: fixed in Settings › Tasks.
  final bool problemIsAuth;
}

/// A whole page.
@immutable
class DocPage {
  const DocPage({required this.summary, required this.source, required this.markdown, this.path = const [], this.file = ''});
  final DocSummary summary;
  final DocSourceInfo source;
  final String markdown;

  /// Titles above the page: the space or vault, then folders.
  final List<String> path;

  /// The note's file, for a vault.
  final String file;
}

/// One entry of a knowledge base's level (Docs › Browse): a space or
/// folder to go into, or a page, which may have pages under it.
@immutable
class DocNode {
  const DocNode({required this.key, required this.title, this.doc, this.children = 0, this.note = ''});

  /// Unique within its level; a path of keys leads to a level.
  final String key;
  final String title;

  /// The page; null for a space or a folder.
  final DocSummary? doc;

  /// How many entries are under it (0: nothing to go into).
  final int children;

  /// `archived`, …
  final String note;

  bool get isFolder => doc == null;
}

/// Pages of the knowledge bases behind the task sources, through the
/// daemon. [MockDocsSource] backs the design and tests.
abstract class DocsSource {
  /// Each knowledge base's recent pages, or the ones matching [query].
  /// [refresh] asks again even if the last answer is recent.
  Future<List<DocGroup>> list({String query = '', bool refresh = false});

  /// Throws a readable message when the page can't be read.
  Future<DocPage> read(String id);

  /// The level of [source] at [path] (node keys from its root): folders
  /// first, then pages. Big trees are walked one level at a time, never
  /// drawn whole.
  Future<List<DocNode>> browse(DocSourceInfo source, List<String> path);

  /// [browse] has the whole tree; otherwise it shows spaces (or folders)
  /// with their recently edited pages.
  bool get browsesEverything;
}

/// [DocsSource.browse] from [DocsSource.list]: the spaces or folders of the
/// recent pages, then the pages in one. Until the daemon lists children.
Future<List<DocNode>> browseByPlace(DocsSource docs, DocSourceInfo source, List<String> path) async {
  final group = (await docs.list()).where((g) => g.source.id == source.id).firstOrNull;
  if (group == null) return const [];
  if (path.isEmpty) {
    final places = <String, int>{};
    for (final d in group.docs) {
      if (d.place.isNotEmpty) places[d.place] = (places[d.place] ?? 0) + 1;
    }
    return [
      for (final p in places.keys.toList()..sort()) DocNode(key: p, title: p, children: places[p]!),
      for (final d in group.docs) if (d.place.isEmpty) DocNode(key: d.id, title: d.title, doc: d),
    ];
  }
  return [for (final d in group.docs) if (d.place == path.first) DocNode(key: d.id, title: d.title, doc: d)];
}

/// The design's pages: a Confluence site and a vault.
class MockDocsSource implements DocsSource {
  MockDocsSource({List<DocGroup>? groups, Map<String, String>? pages})
      : groups = groups ?? _groups,
        pages = pages ?? _pages;

  final List<DocGroup> groups;
  final Map<String, String> pages;

  /// Pages only Browse reaches (deeper than the recent ones).
  static final _more = [
    DocSummary(id: 'jira1/98200', title: 'Discount rules v2', place: 'Pricing', author: 'Lucía', updated: DateTime(2026, 3, 2)),
    DocSummary(id: 'jira1/98400', title: 'Bulk discounts · design', place: 'Pricing', author: 'Mauri', updated: DateTime(2026, 10, 22)),
    DocSummary(id: 'jira1/98401', title: 'Open questions', place: 'Pricing', author: 'Mauri', updated: DateTime(2026, 10, 23)),
    DocSummary(id: 'jira1/98103', title: 'price.discounts.v1', place: 'Pricing', author: 'Tomás', updated: DateTime(2026, 9, 30)),
    DocSummary(id: 'jira1/98104', title: 'price.lists.v2', place: 'Pricing', author: 'Tomás', updated: DateTime(2026, 9, 12)),
    DocSummary(id: 'jira1/97500', title: 'On-call · Pricing', place: 'Engineering', author: 'Nico', updated: DateTime(2026, 8, 19)),
    DocSummary(id: 'jira1/97600', title: 'Deploy checklist', place: 'Engineering', author: 'Nico', updated: DateTime(2026, 7, 4)),
  ];

  /// The sites' trees: (title, page id or null for a space / folder, under it).
  static const _trees = <String, List<_T>>{
    'jira1': [
      _T('Pricing', null, [
        _T('Engineering', null, [
          _T('Discounts', null, [
            _T('Discount rules v3', 'jira1/98311'),
            _T('Discount rules v2', 'jira1/98200', [], 'archived'),
            _T('Bulk discounts · design', 'jira1/98400', [_T('Open questions', 'jira1/98401')]),
          ]),
          _T('Kafka topics and owners', 'jira1/98102', [_T('price.discounts.v1', 'jira1/98103'), _T('price.lists.v2', 'jira1/98104')]),
        ]),
      ]),
      _T('Engineering', null, [
        _T('Runbooks', null, [_T('Incident: stale prices', 'jira1/97455'), _T('On-call · Pricing', 'jira1/97500')]),
        _T('Deploy checklist', 'jira1/97600'),
      ]),
    ],
    'ob1': [
      _T('PRC-412 scratchpad', 'ob1/PRC-412 scratchpad.md'),
      _T('eng', null, [_T('pgx CopyFrom notes', 'ob1/eng/pgx CopyFrom notes.md')]),
    ],
  };

  @override
  bool get browsesEverything => true;

  DocSummary? _summary(String id) {
    for (final g in groups) {
      for (final d in g.docs) {
        if (d.id == id) return d;
      }
    }
    return _more.where((d) => d.id == id).firstOrNull;
  }

  @override
  Future<List<DocNode>> browse(DocSourceInfo source, List<String> path) async {
    var level = _trees[source.id];
    if (level == null) return browseByPlace(this, source, path);
    for (final key in path) {
      level = level!.where((t) => (t.id ?? t.title) == key).firstOrNull?.kids;
      if (level == null) return const [];
    }
    final nodes = [
      for (final t in level!)
        DocNode(key: t.id ?? t.title, title: t.title, doc: t.id == null ? null : _summary(t.id!), children: t.kids.length, note: t.note),
    ]..sort((a, b) => a.isFolder != b.isFolder ? (a.isFolder ? -1 : 1) : a.title.compareTo(b.title));
    return nodes;
  }

  static const _confluence = DocSourceInfo(id: 'jira1', kind: DocKind.confluence, name: 'fravega.atlassian.net', location: 'https://fravega.atlassian.net');
  static const _vault = DocSourceInfo(id: 'ob1', kind: DocKind.obsidian, name: 'work', location: '~/notes/work');

  static final _groups = [
    DocGroup(source: _confluence, docs: [
      DocSummary(id: 'jira1/98311', title: 'Discount rules v3', place: 'Pricing', author: 'Lucía', updated: DateTime(2026, 10, 25), url: 'https://fravega.atlassian.net/wiki/spaces/PRC/pages/98311'),
      DocSummary(id: 'jira1/98102', title: 'Kafka topics and owners', place: 'Pricing', author: 'Tomás', updated: DateTime(2026, 10, 20), url: 'https://fravega.atlassian.net/wiki/spaces/PRC/pages/98102'),
      DocSummary(id: 'jira1/97455', title: 'Incident: stale prices', place: 'Engineering', author: 'Nico', updated: DateTime(2026, 10, 2), url: 'https://fravega.atlassian.net/wiki/spaces/ENG/pages/97455'),
    ]),
    DocGroup(source: _vault, docs: [
      DocSummary(id: 'ob1/PRC-412 scratchpad.md', title: 'PRC-412 scratchpad', place: 'work', updated: DateTime(2026, 10, 27), url: 'obsidian://open?vault=work&file=PRC-412%20scratchpad'),
      DocSummary(id: 'ob1/eng/pgx CopyFrom notes.md', title: 'pgx CopyFrom notes', place: 'eng', updated: DateTime(2026, 10, 12), url: 'obsidian://open?vault=work&file=eng/pgx%20CopyFrom%20notes'),
    ]),
  ];

  static const _pages = {
    'jira1/98311': '''These rules cover list-price discounts stored by price-admin. Installment and financing prices are derived later by price-reader-v2 and are never stored with a discount applied.

## Precedence

1. SKU discount
2. Category discount, including bulk
3. Campaign discount

> Only the highest-precedence rule applies. Rules never stack.

## Rounding

Round half-up to two decimals after applying the discount, never before.

```go
final := list.Mul(one.Sub(pct)).Round(2)
```

## Events

Every change publishes `price.discounts.v1` with the previous and the new value, keyed by SKU.''',
  };

  @override
  Future<List<DocGroup>> list({String query = '', bool refresh = false}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return groups;
    return [
      for (final g in groups)
        DocGroup(
          source: g.source,
          problem: g.problem,
          problemIsAuth: g.problemIsAuth,
          docs: [for (final d in g.docs) if (d.title.toLowerCase().contains(q) || (pages[d.id] ?? '').toLowerCase().contains(q)) d],
        ),
    ];
  }

  @override
  Future<DocPage> read(String id) async {
    for (final g in groups) {
      for (final d in [...g.docs, for (final m in _more) if (m.id.startsWith('${g.source.id}/')) m]) {
        if (d.id != id) continue;
        return DocPage(
          summary: d,
          source: g.source,
          markdown: pages[id] ?? '',
          path: [if (g.source.kind == DocKind.obsidian) g.source.name, if (d.place.isNotEmpty && d.place != g.source.name) d.place],
          file: g.source.kind == DocKind.obsidian ? '${g.source.location}/${id.substring(id.indexOf('/') + 1)}' : '',
        );
      }
    }
    throw 'unknown doc: $id';
  }
}

/// A node of the mock trees.
class _T {
  const _T(this.title, this.id, [this.kids = const [], this.note = '']);
  final String title;
  final String? id;
  final List<_T> kids;
  final String note;
}
