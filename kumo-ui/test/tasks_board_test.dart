import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/preferences.dart';
import 'package:kumo_ui/data/mock_tasks.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/data/tasks_source.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';
import 'package:kumo_ui/views/task_detail.dart';
import 'package:kumo_ui/views/task_visuals.dart';
import 'package:kumo_ui/views/tasks_screen.dart';
import 'package:kumo_ui/widgets/controls.dart';

Future<AppState> _pump(WidgetTester tester, {TasksSource? tasks, AppState? state, Size size = const Size(1440, 960)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = state ?? AppState(tasks: tasks ?? MockTasksSource(), prefs: Preferences.memory());
  await tester.pumpWidget(AppScope(
    state: s,
    child: const KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: TasksScreen())),
    ),
  ));
  await tester.pump();
  return s;
}

/// The card showing [title] on the board.
Finder _card(String title) => find.ancestor(of: find.text(title).first, matching: find.byType(KPressable)).first;

Finder _inCard(String title, Finder what) => find.descendant(of: _card(title), matching: what);

TaskDetailPanel _panel(WidgetTester tester) => tester.widget<TaskDetailPanel>(find.byType(TaskDetailPanel));

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// Jira with nothing of yours, and a Todoist to-do.
TasksSource _nothingMine() => _Fake(
      sources: [
        TaskSourceInfo(id: 'ji', kind: TaskSourceKind.jira, name: 'Acme Jira', lastSynced: DateTime.now()),
        TaskSourceInfo(id: 'td', kind: TaskSourceKind.todoist, name: 'Todoist', lastSynced: DateTime.now()),
      ],
      tasks: const [
        TaskEntry(id: 'ji/A-1', sourceId: 'ji', kind: TaskSourceKind.jira, key: 'A-1', title: 'Theirs', column: TaskColumn.todo, mine: false, assignee: TaskPerson(id: 'ana', name: 'Ana Gómez')),
        TaskEntry(id: 'ji/A-2', sourceId: 'ji', kind: TaskSourceKind.jira, key: 'A-2', title: 'Nobody’s', column: TaskColumn.doing, mine: false),
        TaskEntry(id: 'td/1', sourceId: 'td', kind: TaskSourceKind.todoist, key: 'Inbox', title: 'Water the plants', column: TaskColumn.todo, type: TaskType.todo),
      ],
    );

void main() {
  testWidgets('Mine by default, Everyone on request, with counts; the choice is remembered', (tester) async {
    final state = await _pump(tester);
    final scope = find.byType(KSegmented<bool>);
    expect(find.descendant(of: scope, matching: find.text('11')), findsOneWidget);
    expect(find.descendant(of: scope, matching: find.text('17')), findsOneWidget);
    expect(find.text('Mine · 4 sources'), findsOneWidget);
    expect(find.text('Jira · Pricing, GitHub, Obsidian, Todoist · synced 1 min ago'), findsOneWidget);
    expect(find.text('11 yours of 17 · 3 in worktrees'), findsOneWidget);
    expect(find.text('⌘K finds a ticket by key or title'), findsOneWidget);
    expect(find.text('migraciones'), findsWidgets);
    expect(find.text('Generación automática de precios para los canales (Hijas)'), findsNothing, reason: 'unassigned: not mine');

    // Source chips count within the scope.
    expect(find.descendant(of: find.widgetWithText(KPressable, 'Jira · Pricing'), matching: find.text('7')), findsOneWidget);

    await tester.tap(find.descendant(of: scope, matching: find.text('Everyone')));
    await tester.pump();
    expect(state.setting<String>(TasksScreen.scopeSetting, 'mine'), 'everyone');
    expect(find.text('Everyone · 4 sources'), findsOneWidget);
    expect(find.text('17 tasks · 11 yours · 3 in worktrees'), findsOneWidget);
    expect(find.text('Generación automática de precios para los canales (Hijas)'), findsOneWidget);
    expect(find.descendant(of: find.widgetWithText(KPressable, 'Jira · Pricing'), matching: find.text('13')), findsOneWidget);

    // A new board opens where the user left it.
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, state: state);
    expect(find.text('Everyone · 4 sources'), findsOneWidget);
    expect(find.text('Generación automática de precios para los canales (Hijas)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing of yours in a source: says so and offers Everyone', (tester) async {
    await _pump(tester, tasks: _nothingMine());
    expect(find.text('Water the plants'), findsOneWidget);
    await tester.tap(find.text('Acme Jira'));
    await tester.pump();
    expect(find.text('Nothing assigned to you in Jira'), findsOneWidget);
    expect(find.text('Acme Jira has 2 tasks for other people or nobody. Everyone shows them all.'), findsOneWidget);
    expect(find.widgetWithText(KButton, 'All sources'), findsOneWidget);

    await tester.tap(find.widgetWithText(KButton, 'Show everyone'));
    await tester.pump();
    expect(find.text('Theirs'), findsOneWidget);
    expect(find.text('Nobody’s'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a filter that leaves nothing of yours points at teammates’ tasks', (tester) async {
    await _pump(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Filter tasks'), 'envoy');
    await tester.pump();
    expect(find.text('No tasks match “envoy”'), findsOneWidget);
    expect(find.text('Nothing of yours has that word. 1 teammate’s task does.'), findsOneWidget);

    await tester.tap(find.widgetWithText(KButton, 'Search everyone (1)'));
    await tester.pump();
    expect(find.text('Analisis: Migracion a Envoy'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'envoy'), 'zzz');
    await tester.pump();
    expect(find.text('No tasks match “zzz”'), findsOneWidget);
    expect(find.textContaining('Try another word'), findsOneWidget);
    await tester.tap(find.widgetWithText(KButton, 'Clear filter'));
    await tester.pump();
    expect(find.text('migraciones'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cards: rich for a Jira story, degraded for an Obsidian to-do', (tester) async {
    await _pump(tester);
    // PRC-11355: epic, labels, points, subtasks, comments; its status is
    // the column's, so it doesn't repeat.
    const story = 'migraciones';
    expect(_inCard(story, find.text('PRC-11355')), findsOneWidget);
    expect(_inCard(story, find.text('Low')), findsOneWidget);
    expect(_inCard(story, find.text('Migración a Graviton')), findsOneWidget);
    expect(_inCard(story, find.text('graviton')), findsOneWidget);
    expect(_inCard(story, find.text('db')), findsOneWidget);
    expect(_inCard(story, find.text('5 pts')), findsOneWidget);
    expect(_inCard(story, find.text('1/4')), findsOneWidget);
    expect(_inCard(story, find.text('6')), findsOneWidget);
    expect(_inCard(story, find.text('In Progress')), findsNothing);
    expect(_inCard(story, find.text('You')), findsNothing, reason: 'no assignee in Mine');

    // The Obsidian to-do: note name, title and date, nothing else.
    const note = 'Revisar costos de AWS';
    expect(_inCard(note, find.text('Weekly.md')), findsOneWidget);
    final due = dueInfo(MockTasks.tasks().firstWhere((t) => t.title == note).due)!;
    expect(_inCard(note, find.text(due.text)), findsOneWidget);
    expect(_inCard(note, find.textContaining('pts')), findsNothing);
    expect(_inCard(note, find.byType(TagChip)), findsOneWidget, reason: 'just the OB badge');

    // A sub-task of a story shows its parent; a linked worktree its agent.
    expect(_inCard('Migrar job de precios', find.text('PRC-11355')), findsOneWidget);
    expect(_inCard('Bulk discounts by category', find.text('Claude Code · working')), findsOneWidget);
    expect(_inCard('Bulk discounts by category', find.text('feat/PRC-412-bulk-discounts')), findsOneWidget);
    expect(_inCard('Bulk discounts by category', find.text('Descuentos por volumen')), findsOneWidget);
    expect(_inCard('Rounding error on installment prices', find.text('Codex CLI · needs you')), findsOneWidget);
    expect(_inCard('Warm cache on deploy', find.text('Claude Code · finished')), findsOneWidget);
    expect(_inCard('Rotate staging Kafka credentials', find.text('Due today')), findsOneWidget);
    expect(_inCard('Fix currency rounding in exports', find.text('2026.21 · closed')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked, source status beyond the column, overdue and assignees in Everyone', (tester) async {
    final state = await _pump(tester, size: const Size(1440, 1500));
    state.setSetting(TasksScreen.scopeSetting, 'everyone');
    await tester.pump();

    expect(_inCard('Migracion a Graviton (Parte 4/4)', find.text('Blocked')), findsOneWidget);
    expect(_inCard('Migracion a Graviton (Parte 4/4)', find.text('Migración a Graviton')), findsOneWidget, reason: 'a sub-task under an epic shows the epic');
    expect(_inCard('migraciones', find.text('Blocked')), findsNothing, reason: 'its blocker is done');

    // "Code Review" and "QA" say more than In review; "In Progress" doesn't.
    expect(_inCard('Warm cache on deploy', find.text('Code Review')), findsOneWidget);
    expect(_inCard('Validación de márgenes en carga masiva', find.text('QA')), findsOneWidget);
    expect(_inCard('Analisis: Migracion a Envoy', find.text('Backlog')), findsOneWidget);
    expect(_inCard('Analisis: Migracion a Envoy', find.text('2026.23 · next')), findsOneWidget);
    expect(_inCard('Bulk discounts by category', find.text('In Progress')), findsNothing);
    expect(_inCard('Retry on 502 from pricing API', find.text('Open')), findsNothing);

    // The overdue bug: closed sprint, two labels and +1, overdue with an icon.
    const bug = 'Generación automática de precios para los canales (Hijas)';
    expect(_inCard(bug, find.text('2026.21 · closed')), findsOneWidget);
    expect(_inCard(bug, find.text('canales')), findsOneWidget);
    expect(_inCard(bug, find.text('hotfix')), findsOneWidget);
    expect(_inCard(bug, find.text('marketplace')), findsNothing);
    expect(_inCard(bug, find.text('+1')), findsOneWidget);
    expect(_inCard(bug, find.text('3 pts')), findsOneWidget);
    expect(_inCard(bug, find.text('14')), findsOneWidget);
    expect(_inCard(bug, find.text('2 days overdue')), findsOneWidget);
    expect(_inCard(bug, find.byIcon(Icons.warning_amber_rounded)), findsOneWidget);

    // Assignees: "You", "Unassigned", a teammate's initials; none on
    // personal to-dos.
    expect(_inCard(bug, find.text('Unassigned')), findsOneWidget);
    expect(_inCard('migraciones', find.text('You')), findsOneWidget);
    expect(_inCard('Validación de márgenes en carga masiva', find.text('AG')), findsOneWidget);
    expect(_inCard('Validación de márgenes en carga masiva', find.text('You')), findsNothing);
    expect(_inCard('Revisar costos de AWS', find.byType(PersonAvatar)), findsNothing);
    expect(_inCard('Rotate staging Kafka credentials', find.byType(PersonAvatar)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the board owns the selection: ↑/↓ walk the visible tickets, Esc steps back', (tester) async {
    await _pump(tester);
    expect(find.byType(TaskDetailPanel), findsNothing);
    await tester.tap(find.text('migraciones').first);
    await tester.pump();
    expect(_panel(tester).taskId, 'mock-JI/PRC-11355');
    expect(find.text('↑ ↓ switch tickets · Esc closes'), findsOneWidget);

    // In progress is sorted High, High, Low; In review comes next.
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_panel(tester).taskId, 'mock-JI/PRC-405');
    await _key(tester, LogicalKeyboardKey.arrowUp);
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(_panel(tester).taskId, 'mock-JI/PRC-398');
    _panel(tester).onStep!(-1);
    await tester.pump();
    expect(_panel(tester).taskId, 'mock-JI/PRC-412');

    // Opening a linked ticket keeps a way back; ↓ walks on from the board.
    _panel(tester).onOpen('mock-JI/PRC-11280');
    await tester.pump();
    expect(_panel(tester).taskId, 'mock-JI/PRC-11280');
    expect(_panel(tester).canGoBack, isTrue);
    _panel(tester).onBack!();
    await tester.pump();
    expect(_panel(tester).taskId, 'mock-JI/PRC-412');
    expect(_panel(tester).canGoBack, isFalse);
    _panel(tester).onOpen('mock-JI/PRC-11280');
    await tester.pump();
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_panel(tester).taskId, 'mock-JI/PRC-398');
    expect(_panel(tester).canGoBack, isFalse);

    // Expanded: the panel takes the view; Esc goes back to the side panel,
    // then closes it.
    _panel(tester).onExpand(true);
    await tester.pump();
    expect(_panel(tester).expanded, isTrue);
    expect(find.widgetWithText(TextField, 'Filter tasks'), findsNothing);
    expect(find.text('↑ ↓ switch tickets · Esc back to the panel'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(_panel(tester).expanded, isFalse);
    expect(find.widgetWithText(TextField, 'Filter tasks'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.byType(TaskDetailPanel), findsNothing);

    // The card toggles; the panel's close clears everything.
    await tester.tap(find.text('migraciones').first);
    await tester.pump();
    _panel(tester).onClose();
    await tester.pump();
    expect(find.byType(TaskDetailPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrows in the filter field stay in the field', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('migraciones').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextField, 'Filter tasks'));
    await tester.pump();
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_panel(tester).taskId, 'mock-JI/PRC-11355');
    // Esc leaves the field first, then closes.
    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.byType(TaskDetailPanel), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.byType(TaskDetailPanel), findsNothing);
  });

  testWidgets('the board renders in the light theme and at the minimum window', (tester) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = AppState(tasks: MockTasksSource(), prefs: Preferences.memory());
    await tester.pumpWidget(AppScope(
      state: s,
      child: const KumoTheme(
        mode: KumoThemeMode.light,
        palette: KumoPalette.light,
        terminalPalette: KumoPalette.light,
        child: MaterialApp(home: Scaffold(body: TasksScreen())),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Bulk discounts by category'));
    await tester.pump();
    expect(find.byType(TaskDetailPanel), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_panel(tester).taskId, 'mock-JI/PRC-398');
    expect(tester.takeException(), isNull);
  });
}

class _Fake extends TasksSource {
  _Fake({required this.sources, required this.tasks});
  @override
  final List<TaskSourceInfo> sources;
  @override
  final List<TaskEntry> tasks;
  @override
  List<TaskLinkInfo> get links => const [];
  @override
  bool get live => true;
  @override
  String? get error => null;
  @override
  Future<List<DetectedSourceInfo>> detect() async => const [];
  @override
  Future<String> test({String? id, required TaskSourceKind kind, required Map<String, String> options, String secret = ''}) async => '';
  @override
  Future<TaskSourceInfo> saveSource({String? id, required TaskSourceKind kind, String name = '', required Map<String, String> options, bool enabled = true, String secret = ''}) async =>
      TaskSourceInfo(id: id ?? 'x', kind: kind, name: name);
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
  Future<TaskDetail> getTask(String id, {bool refresh = false}) async => TaskDetail(task: tasks.firstWhere((t) => t.id == id));
  @override
  TaskDetail? cachedDetail(String id) => null;
}
