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

/// Pages of the knowledge bases behind the task sources, through the
/// daemon. [MockDocsSource] backs the design and tests.
abstract class DocsSource {
  /// Each knowledge base's recent pages, or the ones matching [query].
  /// [refresh] asks again even if the last answer is recent.
  Future<List<DocGroup>> list({String query = '', bool refresh = false});

  /// Throws a readable message when the page can't be read.
  Future<DocPage> read(String id);
}

/// The design's pages: a Confluence site and a vault.
class MockDocsSource implements DocsSource {
  MockDocsSource({List<DocGroup>? groups, Map<String, String>? pages})
      : groups = groups ?? _groups,
        pages = pages ?? _pages;

  final List<DocGroup> groups;
  final Map<String, String> pages;

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
      for (final d in g.docs) {
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
