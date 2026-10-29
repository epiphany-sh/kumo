import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/data/docs_source.dart';
import 'package:kumo_ui/engine/engine_docs.dart';
import 'package:kumo_ui/engine/generated/kumo/v1/kumo.pb.dart' as pb;
import 'package:kumo_ui/overlays/docs_settings.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';
import 'package:kumo_ui/views/docs_screen.dart';

/// Counts reads, so tests see what the screen asked for.
class _Docs extends MockDocsSource {
  _Docs({super.groups});
  final reads = <String>[];
  final queries = <String>[];

  @override
  Future<List<DocGroup>> list({String query = '', bool refresh = false}) {
    queries.add(query);
    return super.list(query: query, refresh: refresh);
  }

  @override
  Future<DocPage> read(String id) {
    reads.add(id);
    return super.read(id);
  }
}

Future<AppState> _pump(WidgetTester tester, Widget child, {DocsSource? docs, KumoView view = KumoView.docs}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(docs: docs)..view = view;
  await tester.pumpWidget(AppScope(
    state: state,
    child: KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  ));
  await tester.pump();
  await tester.pump();
  await tester.pump();
  return state;
}

void main() {
  test('docs come over the wire with their source', () {
    final source = docSourceFrom(pb.DocSource(id: 'ob1', kind: pb.DocKind.DOC_KIND_OBSIDIAN, name: 'work', location: '/notes/work'));
    expect((source.kind, source.name, source.location), (DocKind.obsidian, 'work', '/notes/work'));
    final doc = docSummaryFrom(pb.DocSummary(id: 'jira1/98311', title: 'Discount rules v3', place: 'Pricing', updatedAt: Int64(1761660191000), author: 'Lucía'));
    expect((doc.id, doc.place, doc.author), ('jira1/98311', 'Pricing', 'Lucía'));
    expect(doc.updated, DateTime.fromMillisecondsSinceEpoch(1761660191000));
    expect(docSummaryFrom(pb.DocSummary()).updated, isNull, reason: '0 is unknown');
  });

  testWidgets('Docs lists each source’s pages and reads the one picked', (tester) async {
    final docs = _Docs();
    await _pump(tester, const DocsScreen(), docs: docs);
    expect(find.text('fravega.atlassian.net'), findsOneWidget);
    expect(find.text('PRC-412 scratchpad'), findsOneWidget);
    // The first page opens by itself, rendered from Markdown.
    expect(docs.reads, ['jira1/98311']);
    expect(find.text('Precedence'), findsOneWidget);
    expect(find.text('Open in Confluence'), findsOneWidget);
    expect(find.text('Start agent with this page'), findsOneWidget);

    await tester.tap(find.text('pgx CopyFrom notes'));
    await tester.pump();
    await tester.pump();
    expect(docs.reads.last, 'ob1/eng/pgx CopyFrom notes.md');
    expect(find.text('Open in Obsidian'), findsOneWidget);
    expect(find.text('This page is empty.'), findsOneWidget);
    expect(find.text('~/notes/work/eng/pgx CopyFrom notes.md'), findsOneWidget, reason: 'the note’s file');
    expect(tester.takeException(), isNull);
  });

  testWidgets('search asks again after typing stops', (tester) async {
    final docs = _Docs();
    await _pump(tester, const DocsScreen(), docs: docs);
    await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Search docs'), 'round');
    await tester.pump(const Duration(milliseconds: 100));
    expect(docs.queries, ['']);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(docs.queries.last, 'round');
    expect(find.text('Discount rules v3'), findsWidgets, reason: 'its text says rounding');
    expect(find.text('Kafka topics and owners'), findsNothing);
    expect(find.text('Nothing matches'), findsOneWidget, reason: 'the vault has no match');
  });

  testWidgets('Docs waits until it’s open to read anything', (tester) async {
    final docs = _Docs();
    final state = await _pump(tester, const DocsScreen(), docs: docs, view: KumoView.git);
    expect(docs.queries, isEmpty);
    state.view = KumoView.docs;
    await tester.pump();
    await tester.pump();
    expect(docs.queries, ['']);
  });

  testWidgets('without sources Docs says where to add one', (tester) async {
    await _pump(tester, const DocsScreen(), docs: _Docs(groups: const []));
    expect(find.text('No docs yet'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
  });

  testWidgets('a rejected token shows where to fix it', (tester) async {
    const confluence = DocSourceInfo(id: 'jira1', kind: DocKind.confluence, name: 'acme.atlassian.net', location: 'https://acme.atlassian.net');
    await _pump(tester, const DocsScreen(), docs: _Docs(groups: const [DocGroup(source: confluence, problem: 'Confluence rejected the credentials', problemIsAuth: true)]));
    expect(find.text('Confluence rejected the credentials'), findsOneWidget);
    expect(find.text('Fix in Settings'), findsOneWidget);
    expect(find.text('Pick a page to read it here.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings › Docs shows the sources Docs reads through', (tester) async {
    const confluence = DocSourceInfo(id: 'jira1', kind: DocKind.confluence, name: 'acme.atlassian.net', location: 'https://acme.atlassian.net');
    const vault = DocSourceInfo(id: 'ob1', kind: DocKind.obsidian, name: 'work', location: '/notes/work');
    await _pump(
      tester,
      const SingleChildScrollView(child: DocsSourcesPanel()),
      docs: _Docs(groups: const [DocGroup(source: confluence, problem: 'Confluence rejected the credentials', problemIsAuth: true), DocGroup(source: vault)]),
    );
    expect(find.text('https://acme.atlassian.net'), findsOneWidget);
    expect(find.text('Check the token'), findsOneWidget);
    expect(find.text('/notes/work'), findsOneWidget);
    expect(find.text('Connected · no pages yet'), findsOneWidget);
    expect(find.text('Manage in Tasks'), findsOneWidget);
  });
}
