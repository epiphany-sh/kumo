import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/data/mock_tasks.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/data/tasks_source.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';
import 'package:kumo_ui/views/task_detail.dart';
import 'package:kumo_ui/views/task_detail/markdown.dart';
import 'package:kumo_ui/widgets/controls.dart';

const _all = {TaskColumn.todo, TaskColumn.doing, TaskColumn.review, TaskColumn.done};

const _task = TaskEntry(
  id: 'ji/PRC-1',
  sourceId: 'ji',
  kind: TaskSourceKind.jira,
  key: 'PRC-1',
  title: 'Bulk discounts',
  column: TaskColumn.doing,
  sourceStatus: 'In Progress',
  url: 'https://acme.atlassian.net/browse/PRC-1',
  suggestedBranch: 'feat/PRC-1-bulk-discounts',
);

/// A source whose details are set by the test: answered, stale, failing.
class _Source extends TasksSource {
  _Source({this.detail, this.fail});

  TaskDetail? detail;
  String? fail;
  int asked = 0;

  @override
  bool get live => true;
  @override
  List<TaskSourceInfo> get sources => [TaskSourceInfo(id: 'ji', kind: TaskSourceKind.jira, name: 'Acme Jira', writable: _all, lastSynced: DateTime.now())];
  @override
  List<TaskEntry> tasks = [_task];
  @override
  List<TaskLinkInfo> links = [];
  @override
  String? get error => null;
  @override
  Future<List<DetectedSourceInfo>> detect() async => const [];
  @override
  Future<String> test({String? id, required TaskSourceKind kind, required Map<String, String> options, String secret = ''}) async => '';
  @override
  Future<TaskSourceInfo> saveSource({String? id, required TaskSourceKind kind, String name = '', required Map<String, String> options, bool enabled = true, String secret = ''}) async =>
      throw UnimplementedError();
  @override
  Future<void> deleteSource(String id) async {}
  @override
  Future<void> sync([String? id]) async {}
  @override
  Future<bool> setStatus(String taskId, TaskColumn column) async => true;
  @override
  Future<void> link(String taskId, {required String worktreePath, required String branch}) async {}
  @override
  Future<void> unlink(String taskId, String worktreePath) async {}

  @override
  Future<TaskDetail> getTask(String id, {bool refresh = false}) async {
    asked++;
    if (fail != null) throw fail!;
    return detail ?? TaskDetail(task: tasks.firstWhere((t) => t.id == id));
  }

  @override
  TaskDetail? cachedDetail(String id) => null;
}

class _Calls {
  final opened = <String>[];
  final expanded = <bool>[];
  final steps = <int>[];
  var backs = 0;
  var closes = 0;
}

Future<_Calls> _pump(
  WidgetTester tester,
  TasksSource source,
  String id, {
  bool expanded = false,
  bool canGoBack = false,
  KumoPalette palette = KumoPalette.dark,
}) async {
  tester.view.physicalSize = Size(expanded ? 1200 : 600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final calls = _Calls();
  final state = AppState(tasks: source);
  await tester.pumpWidget(AppScope(
    state: state,
    child: KumoTheme(
      mode: palette.isDark ? KumoThemeMode.dark : KumoThemeMode.light,
      palette: palette,
      terminalPalette: palette,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: expanded ? 1100 : 440,
              height: 860,
              child: TaskDetailPanel(
                taskId: id,
                expanded: expanded,
                canGoBack: canGoBack,
                onBack: () => calls.backs++,
                onOpen: calls.opened.add,
                onExpand: calls.expanded.add,
                onClose: () => calls.closes++,
                onStep: calls.steps.add,
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  return calls;
}

/// Taps [finder] after scrolling it into view.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  final story = MockTasks.id('PRC-11355');

  testWidgets('shows a skeleton while the source answers, then the ticket', (tester) async {
    await _pump(tester, MockTasksSource(latency: const Duration(milliseconds: 400)), story);
    expect(find.text('Loading PRC-11355 from Jira…'), findsOneWidget);
    expect(find.text('migraciones'), findsOneWidget, reason: 'the card is shown at once');
    expect(find.text('Move to'), findsOneWidget, reason: 'actions work while loading');
    expect(find.text('Acceptance criteria'), findsNothing);

    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Loading PRC-11355 from Jira…'), findsNothing);
    expect(find.text('Acceptance criteria'), findsOneWidget);
    expect(find.text('1 of 4 met'), findsOneWidget);
    expect(find.text('The agent gets these as its definition of done.'), findsOneWidget);
    expect(find.text('Ana Gómez'), findsWidgets, reason: 'the reporter');
    expect(find.text('Pricing 2026.22'), findsOneWidget);
    expect(find.text('1 of 4 done · 1 in progress'), findsOneWidget);
    expect(find.text('Is blocked by'), findsOneWidget);
    expect(find.text('Done, so it no longer blocks this one'), findsOneWidget);
    expect(find.text('graviton-rollout.png'), findsWidgets, reason: 'attachment and image');
    expect(find.text('Logged 1d 4h'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline: the saved copy with a notice, and moving waits', (tester) async {
    final src = _Source(detail: TaskDetail(task: _task, description: 'Saved description.', stale: true, fetched: DateTime.now().subtract(const Duration(minutes: 12))));
    await _pump(tester, src, _task.id);
    await tester.pump();
    expect(find.text('Showing the copy Kumo saved.'), findsOneWidget);
    expect(find.text('Can’t reach Jira right now. Last synced 12 min ago.'), findsOneWidget);
    expect(find.text('Saved description.'), findsOneWidget);
    expect(find.text('Moving needs Jira. Try again when it’s reachable.'), findsOneWidget);

    // Retry asks the source again.
    src.detail = const TaskDetail(task: _task, description: 'Fresh description.');
    await tester.tap(find.widgetWithText(KButton, 'Retry'));
    await tester.pump();
    await tester.pump();
    expect(src.asked, 2);
    expect(find.text('Showing the copy Kumo saved.'), findsNothing);
    expect(find.text('Fresh description.'), findsOneWidget);
  });

  testWidgets('never fetched and unreachable: the card, and what will arrive', (tester) async {
    await _pump(tester, _Source(fail: 'Jira didn’t answer'), _task.id);
    await tester.pump();
    expect(find.text('Showing what Kumo saved.'), findsOneWidget);
    expect(find.text('Not saved on this Mac yet'), findsOneWidget);
    expect(find.text('Bulk discounts'), findsOneWidget);
  });

  testWidgets('nothing to show: a readable error and retry', (tester) async {
    await _pump(tester, _Source(fail: 'Unknown task ji/PRC-404'), 'ji/PRC-404');
    await tester.pump();
    expect(find.text('Couldn’t open PRC-404'), findsOneWidget);
    expect(find.text('Unknown task ji/PRC-404'), findsOneWidget);
    expect(find.widgetWithText(KButton, 'Retry'), findsOneWidget);
    expect(find.text('Move to'), findsNothing);
  });

  testWidgets('header: back, step, expand and close call the board', (tester) async {
    final calls = await _pump(tester, MockTasksSource(), story, canGoBack: true);
    await tester.pump();
    await tester.tap(find.text('Back'));
    await tester.tap(find.byTooltip('Next ticket (↓)'));
    await tester.tap(find.byTooltip('Previous ticket (↑)'));
    await tester.tap(find.byTooltip('Expand to a large view'));
    await tester.tap(find.byTooltip('Close (Esc)'));
    expect(calls.backs, 1);
    expect(calls.steps, [1, -1]);
    expect(calls.expanded, [true]);
    expect(calls.closes, 1);
  });

  testWidgets('no back without history', (tester) async {
    await _pump(tester, MockTasksSource(), story);
    expect(find.text('Back'), findsNothing);
  });

  testWidgets('epics, linked issues and keys in the text open in the panel', (tester) async {
    final calls = await _pump(tester, MockTasksSource(), story);
    await tester.pump();
    // The epic chip in the header.
    await tester.tap(find.byTooltip('Open PRC-11300 · Migración a Graviton (back returns here)').first);
    // A linked issue.
    await _tap(tester, find.text('Limpieza de ofertas de canales'));
    // A sub-task.
    await _tap(tester, find.text('Analisis'));
    // A key in the description.
    await _tap(tester, find.descendant(of: find.byType(MarkdownView), matching: find.text('PRC-11356')).first);
    expect(calls.opened, ['mock-JI/PRC-11300', 'mock-JI/PRC-11340', 'mock-JI/PRC-11357', 'mock-JI/PRC-11356']);
  });

  testWidgets('a ref without an id opens by the source and its key', (tester) async {
    final src = _Source(detail: const TaskDetail(task: _task, links: [
      LinkedTask(kind: LinkKind.relates, relation: 'relates to', task: TaskRef(key: 'PRC-9', title: 'Old pricing', column: TaskColumn.done)),
    ]));
    final calls = await _pump(tester, src, _task.id);
    await tester.pump();
    await _tap(tester, find.text('Old pricing'));
    expect(calls.opened, ['ji/PRC-9']);
  });

  testWidgets('the actions stay pinned while the ticket scrolls', (tester) async {
    await _pump(tester, MockTasksSource(), story);
    await tester.pump();
    final body = find.byKey(const ValueKey('task-detail-body'));
    final footer = find.byKey(const ValueKey('task-detail-footer'));
    final before = tester.getRect(footer);
    await tester.drag(body, const Offset(0, -2500));
    await tester.pump();
    expect(find.text('Comments'.toUpperCase()).hitTestable(), findsOneWidget, reason: 'scrolled to the end');
    expect(tester.getRect(footer), before);
    expect(find.text('Move to').hitTestable(), findsOneWidget);
    expect(find.text('Start in a worktree').hitTestable(), findsOneWidget);
    expect(find.text('Doing').hitTestable(), findsOneWidget);
  });

  testWidgets('the start form opens from the footer and closes with Cancel', (tester) async {
    await _pump(tester, MockTasksSource(), story);
    await tester.pump();
    expect(find.text('Create worktree and start agent'), findsNothing);
    await tester.tap(find.text('Start in a worktree'));
    await tester.pump();
    expect(find.text('Repository'), findsOneWidget);
    expect(find.text('New branch'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Repository'), findsNothing);
  });

  testWidgets('the last 3 comments, then all of them', (tester) async {
    await _pump(tester, MockTasksSource(), story);
    await tester.pump();
    expect(find.text('Latest 3 of 6'), findsOneWidget);
    expect(find.textContaining('Te lo asigno', findRichText: true), findsNothing);
    await _tap(tester, find.text('Show all 6 comments'));
    expect(find.text('All 6, oldest first'), findsOneWidget);
    expect(find.textContaining('Te lo asigno', findRichText: true), findsOneWidget);
    expect(find.text('Show the latest 3'), findsOneWidget);
  });

  testWidgets('expanded: two columns, the form open in the right one', (tester) async {
    final calls = await _pump(tester, MockTasksSource(), story, expanded: true);
    await tester.pump();
    expect(find.text('Create worktree and start agent'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Show more'), findsNothing, reason: 'the whole description shows');
    final ac = tester.getRect(find.text('Acceptance criteria'));
    final move = tester.getRect(find.text('Move to'));
    expect(move.left, greaterThan(ac.right), reason: 'actions on the right');
    expect(move.top, lessThan(tester.getRect(find.text('Assignee')).top), reason: 'actions on top of the fields');
    await tester.tap(find.byTooltip('Back to the side panel (Esc)'));
    expect(calls.expanded, [false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the side panel collapses a long description', (tester) async {
    await _pump(tester, MockTasksSource(), story);
    await tester.pump();
    await _tap(tester, find.text('Show more'));
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('what the agent gets', (tester) async {
    await _pump(tester, MockTasksSource(), story);
    await tester.pump();
    await tester.tap(find.text('What the agent gets'));
    await tester.pump();
    expect(find.text('Starting from this ticket, the agent’s first prompt includes:'), findsOneWidget);
    expect(find.text('· 4 items'), findsOneWidget);
    expect(find.text('· all 6'), findsOneWidget);
  });

  testWidgets('light theme renders', (tester) async {
    await _pump(tester, MockTasksSource(), MockTasks.id('PRC-10599'), palette: KumoPalette.light);
    await tester.pump();
    expect(find.text('Unassigned'), findsOneWidget);
    expect(find.textContaining('2 days overdue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every designed ticket opens without errors', (tester) async {
    final src = MockTasksSource();
    for (final t in [...src.tasks, ...MockTasks.offBoard()]) {
      await _pump(tester, src, t.id);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: t.id);
      expect(find.textContaining('Couldn’t open'), findsNothing, reason: t.id);
    }
  });

  group('Markdown', () {
    test('parses the blocks tickets use', () {
      final blocks = parseMarkdown('## Title\nSome **bold** text\nand more.\n\n1. one\n2. two\n- [x] done\n- [ ] not\n```sql\nSELECT 1;\n```\n| a | b |\n| --- | --- |\n| 1 | 2 |\n![Alt text](pic.png)\n- bullet');
      expect(blocks.map((b) => b.runtimeType.toString()), ['MdHeading', 'MdParagraph', 'MdList', 'MdChecklist', 'MdCode', 'MdTable', 'MdImage', 'MdList']);
      expect((blocks[1] as MdParagraph).text, 'Some **bold** text and more.');
      expect((blocks[3] as MdChecklist).items, [(true, 'done'), (false, 'not')]);
      expect((blocks[4] as MdCode).lang, 'sql');
      expect((blocks[5] as MdTable).rows, [
        ['1', '2'],
      ]);
      expect(checklistOf('- [x] a\n- [ ] b\n- [ ] c'), hasLength(3));
    });

    test('inline: bold, code, links, mentions and keys', () {
      final spans = parseInline('See **this**, `code`, [Runbook](https://x.local/r) and @Ana Gómez on PRC-11300 (not UTF-8 nor OPS-1).', mentions: ['Ana Gómez'], keys: true, keyProjects: {'PRC'});
      expect([for (final s in spans) if (s.$1 != MdInline.text) (s.$1, s.$2)], [
        (MdInline.bold, 'this'),
        (MdInline.code, 'code'),
        (MdInline.link, 'Runbook'),
        (MdInline.mention, '@Ana Gómez'),
        (MdInline.key, 'PRC-11300'),
      ]);
      expect(parseInline('snake_case_name and a@b.com').where((s) => s.$1 != MdInline.text), isEmpty);
      expect(parseInline('UTF-8 and OPS-1', keys: true).where((s) => s.$1 == MdInline.key).map((s) => s.$2), ['OPS-1']);
    });

    testWidgets('renders code with colors, tables and checkboxes', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, MockTasksSource(), story, expanded: true);
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('^SQL code')), findsOneWidget);
      final code = tester.widget<Text>(find.descendant(of: find.byType(CodeBlockView), matching: find.byType(Text)).last);
      final colors = <Color?>{};
      code.textSpan!.visitChildren((s) {
        colors.add(s.style?.color);
        return true;
      });
      expect(colors.length, greaterThan(2), reason: 'keywords, strings and comments are colored');
      expect(find.byType(Table), findsOneWidget);
      expect(find.textContaining('m7g.xlarge', findRichText: true), findsOneWidget);
      // 4 criteria + 3 checks in the description.
      expect(find.byType(CheckMark), findsNWidgets(7));
      expect(find.bySemanticsLabel(RegExp('^Image: Diagrama del rollout, 1280×720')), findsOneWidget);
      semantics.dispose();
    });
  });

  group('the agent prompt', () {
    test('keeps working with the card only', () {
      final p = AppState.taskPrompt(_task);
      expect(p, contains('Bulk discounts'));
      expect(p, contains('Task PRC-1 (Jira)'));
      expect(p, isNot(contains('## Description')));
    });

    test('has the description, acceptance criteria and comments of the detail', () {
      final p = AppState.taskPrompt(
        _task,
        detail: TaskDetail(
          task: _task,
          description: 'Admins set a discount for a whole category.',
          acceptanceCriteria: '- [ ] One event per SKU',
          comments: [
            TaskComment(author: const TaskPerson(id: 'ana', name: 'Ana Gómez'), created: DateTime(2026, 10, 23), body: 'Remember the 30% cap.'),
            const TaskComment(author: TaskPerson(id: 'me', name: 'Mauri', you: true), body: 'Consumer done.'),
          ],
        ),
      );
      expect(p, contains('Task PRC-1 (Jira)'));
      expect(p, contains('Status: In Progress.'));
      expect(p, contains('## Description\n\nAdmins set a discount for a whole category.'));
      expect(p, contains('## Acceptance criteria'));
      expect(p, contains('- [ ] One event per SKU'));
      expect(p, contains('Ana Gómez, 2026-10-23:\nRemember the 30% cap.'));
      expect(p, contains('Mauri (the user):\nConsumer done.'));
      expect(p, contains('https://acme.atlassian.net/browse/PRC-1'));
    });
  });
}
