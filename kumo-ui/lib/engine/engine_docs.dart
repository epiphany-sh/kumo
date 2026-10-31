import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

import '../data/docs_source.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart' as pb;
import 'kumo_engine.dart';

/// Docs over `Docs` (List / Browse / Read).
class EngineDocs implements DocsSource {
  EngineDocs(this._engine);
  final KumoEngine _engine;

  Future<T> _call<T>(Future<T> Function(pb.DocsClient client) call) async {
    try {
      return await call((await _engine.connection()).docs);
    } on GrpcError catch (e) {
      throw e.message ?? e.codeName;
    }
  }

  @override
  Future<List<DocGroup>> list({String query = '', bool refresh = false}) async {
    final answer = await _call((c) => c.list(pb.ListDocsRequest(query: query, refresh: refresh)));
    return [
      for (final g in answer.groups)
        DocGroup(
          source: docSourceFrom(g.source),
          docs: [for (final d in g.docs) docSummaryFrom(d)],
          problem: g.problem,
          problemIsAuth: g.problemIsAuth,
        ),
    ];
  }

  /// [path] holds keys from the top; the engine's are self-contained, so
  /// only the last one is sent.
  @override
  Future<List<DocNode>> browse(DocSourceInfo source, List<String> path) async {
    final level = await _call((c) => c.browse(pb.BrowseDocsRequest(
          sourceId: source.id,
          parent: path.isEmpty ? '' : path.last,
        )));
    return [
      for (final n in level.nodes)
        DocNode(
          key: n.key,
          title: n.title,
          doc: n.hasDoc() ? docSummaryFrom(n.doc) : null,
          children: n.children,
          note: n.note,
        ),
    ];
  }

  @override
  bool get browsesEverything => true;

  @override
  Future<DocPage> read(String id) async {
    final d = await _call((c) => c.read(pb.ReadDocRequest(id: id)));
    return DocPage(summary: docSummaryFrom(d.summary), source: docSourceFrom(d.source), markdown: d.markdown, path: d.path, file: d.file);
  }
}

DocSourceInfo docSourceFrom(pb.DocSource s) => DocSourceInfo(
      id: s.id,
      kind: s.kind == pb.DocKind.DOC_KIND_OBSIDIAN ? DocKind.obsidian : DocKind.confluence,
      name: s.name,
      location: s.location,
    );

DocSummary docSummaryFrom(pb.DocSummary d) => DocSummary(
      id: d.id,
      title: d.title,
      place: d.place,
      updated: d.updatedAt <= Int64.ZERO ? null : DateTime.fromMillisecondsSinceEpoch(d.updatedAt.toInt()),
      author: d.author,
      url: d.url,
      excerpt: d.excerpt,
    );
