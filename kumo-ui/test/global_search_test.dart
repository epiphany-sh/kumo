import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/models.dart' show TaskColumn;
import 'package:kumo_ui/data/tasks_source.dart';
import 'package:kumo_ui/overlays/global_search.dart';
import 'package:kumo_ui/platform/os/host_os.dart';
import 'package:kumo_ui/platform/os/macos.dart';
import 'package:kumo_ui/views/git_screen.dart' show CommitSheet;
import 'package:kumo_ui/views/task_detail.dart';

final _palette = find.byKey(const ValueKey('global-search'));

TaskEntry _task(String key, String title, {List<String> labels = const []}) =>
    TaskEntry(id: 'src/$key', sourceId: 'src', kind: TaskSourceKind.jira, key: key, title: title, column: TaskColumn.todo, labels: labels);

Future<AppState> _app(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(demoWallpaper: true);
  await tester.pumpWidget(KumoApp(state: state));
  await tester.pump();
  return state;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _cmdK(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await _settle(tester);
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(_palette, query);
  // Past the docs' debounce, and their answer.
  await tester.pump(const Duration(milliseconds: 300));
  await _settle(tester);
}

/// A row of the palette's list (not the query in its field).
/// (By the row's whole title: a long one shows cut, see [MatchLine].)
Finder _row(String title) => find.descendant(
    of: find.descendant(of: find.byType(GlobalSearch), matching: find.byType(ListView)), matching: find.byWidgetPredicate((w) => w is MatchLine && w.title == title));

List<(TaskEntry, List<int>)> _tickets(String q, List<TaskEntry> tasks) => rankText(q, tasks, key: (t) => t.key, title: (t) => t.title, rest: (t) => t.labels);

Future<void> _tab(WidgetTester tester, {bool back = false}) async {
  if (back) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  if (back) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await _settle(tester);
}

Future<void> _enter(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await _settle(tester);
}

void main() {
  setUp(() => debugHostOs = MacOs());
  tearDown(() => debugHostOs = null);

  group('ranking', () {
    final tasks = [
      _task('TSK-1', 'Migracion a Envoy'),
      _task('TSK-12', 'Bulk discounts'),
      _task('TSK-120', 'Retry on 502', labels: ['api']),
    ];

    test('a ticket key comes before keys that start with it', () {
      expect([for (final (t, _) in _tickets('tsk-12', tasks)) t.key], ['TSK-12', 'TSK-120']);
    });

    test('every word must show, in the title or the labels', () {
      expect([for (final (t, _) in _tickets('retry api', tasks)) t.key], ['TSK-120']);
      expect(_tickets('retry envoy', tasks), isEmpty);
    });

    test('an empty query lists them all, in order', () {
      expect([for (final (t, _) in _tickets('  ', tasks)) t.key], ['TSK-1', 'TSK-12', 'TSK-120']);
    });

    test('a commit by the start of its sha or words of its subject', () {
      final shas = ['a3f9c12', '9d02e1f'];
      final subjects = {'a3f9c12': 'feat: price history endpoint', '9d02e1f': 'fix: currency rounding'};
      List<String> find(String q) => [for (final (x, _) in rankText(q, shas, key: (x) => x, title: (x) => subjects[x]!)) x];
      expect(find('9d0'), ['9d02e1f']);
      expect(find('history price'), ['a3f9c12']);
    });

    test('word hits mark the letters matched', () {
      expect(wordHits('bulk', 'Bulk discounts'), [0, 1, 2, 3]);
      expect(wordHits('nope', 'Bulk discounts'), isNull);
    });

    test('with no query every command shows, in order', () {
      final all = ['a', 'b', 'c'];
      expect([for (final (x, _) in rankFuzzy('', all, (x) => x)) x], all);
    });
  });

  group('palette', () {
    testWidgets('⌘K opens it and runs a command', (tester) async {
      final state = await _app(tester);
      expect(_palette, findsNothing);
      await _cmdK(tester);
      expect(_palette, findsOneWidget);
      await _search(tester, 'go to tasks');
      await _enter(tester);
      expect(_palette, findsNothing);
      expect(state.view, KumoView.tasks);
    });

    testWidgets('⌘K again and Esc close it', (tester) async {
      await _app(tester);
      await _cmdK(tester);
      await _cmdK(tester);
      expect(_palette, findsNothing);
      await _cmdK(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(_palette, findsNothing);
    });

    testWidgets('the toolbar field opens it', (tester) async {
      await _app(tester);
      await tester.tap(find.text('Search commands, tickets, docs…').first);
      await _settle(tester);
      expect(_palette, findsOneWidget);
    });

    testWidgets('a ticket opens in the Tasks panel', (tester) async {
      final state = await _app(tester);
      final ticket = state.tasks.tasks.firstWhere((t) => t.key == 'TSK-11354');
      await _cmdK(tester);
      await _search(tester, 'TSK-11354');
      expect(find.text('TSK-11354'), findsWidgets);
      await _enter(tester);
      expect(state.view, KumoView.tasks);
      expect(state.ticketRequest.value, isNull, reason: 'the view took it');
      expect(tester.widget<TaskDetailPanel>(find.byType(TaskDetailPanel)).taskId, ticket.id);
    });

    testWidgets('a doc page opens in Docs', (tester) async {
      final state = await _app(tester);
      await _cmdK(tester);
      await _search(tester, 'kafka topics');
      expect(find.text('DOCS'), findsOneWidget);
      // Docs come last: past the tickets and commands that match too.
      final docRow = _row('Kafka topics and owners');
      expect(docRow, findsOneWidget);
      await tester.tap(docRow);
      await _settle(tester);
      expect(state.view, KumoView.docs);
      expect(state.docRequest.value, isNull, reason: 'the view took it');
      expect(find.text('Kafka topics and owners'), findsWidgets);
    });

    testWidgets('a worktree switches to it', (tester) async {
      final state = await _app(tester);
      final other = [for (final r in state.workspace.repos) ...state.worktreesOf(r)].firstWhere((w) => w.branch == 'fix/TSK-398-rounding');
      expect(state.isActiveWorktree(other), isFalse);
      await _cmdK(tester);
      await _search(tester, 'rounding');
      expect(find.text('WORKTREES'), findsOneWidget);
      await tester.tap(_row(other.branch));
      await _settle(tester);
      expect(state.isActiveWorktree(other), isTrue);
      expect(state.view, KumoView.terminal);
    });

    testWidgets('a file of the worktree opens in its Files tab', (tester) async {
      final state = await _app(tester);
      await _cmdK(tester);
      await _search(tester, 'repository.go');
      expect(find.text('FILES'), findsOneWidget);
      await tester.tap(_row('repository.go'));
      await _settle(tester);
      expect(state.activeContext, ContextTab.files);
      expect(state.contextFile, 'internal/discount/repository.go');
    });

    testWidgets('Tab narrows it to one place, and ⇧Tab goes back', (tester) async {
      await _app(tester);
      await _cmdK(tester);
      await _search(tester, 'discount');
      // All: a few of each group (the files first).
      expect(find.text('FILES'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^5 of \d+$')), findsOneWidget);
      await _tab(tester);
      // Files: only files, all of them.
      expect(find.text('FILES'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^5 of \d+$')), findsNothing);
      await _tab(tester);
      await _tab(tester);
      // Docs: only pages.
      expect(find.text('DOCS'), findsOneWidget);
      expect(find.text('FILES'), findsNothing);
      await _tab(tester, back: true);
      await _tab(tester, back: true);
      await _tab(tester, back: true);
      expect(find.textContaining(RegExp(r'^5 of \d+$')), findsOneWidget, reason: 'back in All');
    });

    testWidgets('a tab can be picked with the mouse, and typing goes on', (tester) async {
      await _app(tester);
      await _cmdK(tester);
      await tester.tap(find.descendant(of: find.byType(GlobalSearch), matching: find.text('Agents')));
      await _settle(tester);
      expect(find.text('YOUR AGENTS'), findsOneWidget);
      expect(find.text('COMMANDS'), findsNothing);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Global search', reason: 'the field kept the focus');
    });

    testWidgets('Git finds open pull requests, the worktree’s commits and its releases', (tester) async {
      final state = await _app(tester);
      await _cmdK(tester);
      await _tab(tester);
      await _tab(tester);
      // Git with no query: what there is.
      expect(find.text('OPEN PULL REQUESTS'), findsOneWidget);
      expect(find.text('COMMITS'), findsOneWidget);
      await _search(tester, 'bulk discounts by category');
      expect(_row('feat: bulk discounts by category'), findsOneWidget);
      await _search(tester, 'price history');
      expect(_row('feat: price history endpoint'), findsOneWidget);
      await _search(tester, 'v1.9.0-rc.1');
      expect(_row('v1.9.0-rc.1'), findsOneWidget);
      await _enter(tester);
      expect(state.view, KumoView.git);
      expect(state.releaseRequest.value, isNull, reason: 'the view took it');
    });

    testWidgets('a commit opens its sheet', (tester) async {
      await _app(tester);
      await _cmdK(tester);
      await _search(tester, 'price history');
      await tester.tap(_row('feat: price history endpoint'));
      await _settle(tester);
      expect(find.byType(CommitSheet), findsOneWidget);
    });

    testWidgets('an agent of yours opens in the library', (tester) async {
      final state = await _app(tester);
      await _cmdK(tester);
      await _search(tester, 'researcher');
      await tester.tap(_row('researcher'));
      await _settle(tester);
      expect(state.view, KumoView.agents);
    });

    testWidgets('nothing found says so', (tester) async {
      await _app(tester);
      await _cmdK(tester);
      await _search(tester, 'zzzzqqq');
      expect(find.text('Nothing matches “zzzzqqq”'), findsOneWidget);
    });
  });

  group('match line', () {
    const title = 'Merge pull request #99 from epiphany-sh/release/0.8.3';
    final hits = {for (var k = title.indexOf('release'); k < title.length; k++) k};

    Future<String> shown(WidgetTester tester, double width, {String detail = 'MDellag · yesterday'}) async {
      tester.view.physicalSize = const Size(1440, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: width,
            child: MatchLine(title: title, hits: hits, detail: detail, style: const TextStyle(fontSize: 13), strong: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), detailStyle: const TextStyle(fontSize: 12)),
          ),
        ),
      ));
      return tester.widget<RichText>(find.descendant(of: find.byType(MatchLine), matching: find.byType(RichText)).first).text.toPlainText();
    }

    testWidgets('a short detail leaves the title whole', (tester) async {
      expect(await shown(tester, 1200), title);
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('it measures with the style the text inherits', (tester) async {
      tester.view.physicalSize = const Size(1440, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Room for the whole title and detail, as Material's body style
      // (letter spacing 0.25) draws them, at a fractional size.
      const inherited = TextStyle(fontSize: 13.3, letterSpacing: 0.25);
      double widthOf(String text, double size) => (text.length * (size + 0.25)).ceilToDouble();
      final room = widthOf(title, 13.3) + 10 + widthOf('MDellag · yesterday', 12.1);
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: room,
            child: DefaultTextStyle(
              style: inherited,
              child: MatchLine(title: title, hits: hits, detail: 'MDellag · yesterday', style: const TextStyle(fontSize: 13.3), strong: const TextStyle(fontSize: 13.3, fontWeight: FontWeight.w700), detailStyle: const TextStyle(fontSize: 12.1)),
            ),
          ),
        ),
      ));
      final paragraphs = tester.renderObjectList<RenderParagraph>(find.descendant(of: find.byType(MatchLine), matching: find.byType(RichText))).toList();
      expect(paragraphs.first.text.toPlainText(), title);
      expect(paragraphs.first.didExceedMaxLines, isFalse, reason: 'the title is drawn whole, no "…"');
    });

    testWidgets('a title too long is cut in front, so the match shows', (tester) async {
      final text = await shown(tester, 420);
      expect(text, startsWith('…'));
      expect(text, endsWith('release/0.8.3'));
      expect(find.byType(Tooltip), findsOneWidget, reason: 'the whole title on hover');
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, startsWith(title));
    });
  });
}
