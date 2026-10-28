import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/data/tasks_source.dart';
import 'package:kumo_ui/overlays/task_settings.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';
import 'package:kumo_ui/views/task_detail.dart';
import 'package:kumo_ui/views/tasks_screen.dart';
import 'package:kumo_ui/widgets/controls.dart';

/// A daemon-like source that records what the UI asks for.
class _FakeTasks extends TasksSource {
  _FakeTasks({this.sources = const [], this.tasks = const [], this.detected = const []});

  @override
  List<TaskSourceInfo> sources;
  @override
  List<TaskEntry> tasks;
  @override
  List<TaskLinkInfo> links = [];
  final List<DetectedSourceInfo> detected;
  final moved = <(String, TaskColumn)>[];
  final saved = <(String?, TaskSourceKind, Map<String, String>, String)>[];
  final tested = <TaskSourceKind>[];

  @override
  bool get live => true;
  @override
  String? get error => null;
  @override
  Future<List<DetectedSourceInfo>> detect() async => detected;

  @override
  Future<String> test({String? id, required TaskSourceKind kind, required Map<String, String> options, String secret = ''}) async {
    tested.add(kind);
    return 'signed in as Ana';
  }

  @override
  Future<TaskSourceInfo> saveSource({String? id, required TaskSourceKind kind, String name = '', required Map<String, String> options, bool enabled = true, String secret = ''}) async {
    saved.add((id, kind, options, secret));
    return TaskSourceInfo(id: id ?? 'new', kind: kind, name: name, options: options);
  }

  @override
  Future<void> deleteSource(String id) async {}
  @override
  Future<void> sync([String? id]) async {}

  @override
  Future<bool> setStatus(String taskId, TaskColumn column) async {
    moved.add((taskId, column));
    tasks = [for (final t in tasks) if (t.id == taskId) t.withColumn(column) else t];
    notifyListeners();
    return true;
  }

  @override
  Future<void> link(String taskId, {required String worktreePath, required String branch}) async {
    links = [...links, TaskLinkInfo(taskId: taskId, worktreePath: worktreePath, branch: branch)];
    notifyListeners();
  }

  @override
  Future<void> unlink(String taskId, String worktreePath) async {}

  @override
  Future<TaskDetail> getTask(String id, {bool refresh = false}) async => TaskDetail(task: tasks.firstWhere((t) => t.id == id));

  @override
  TaskDetail? cachedDetail(String id) => null;
}

const _all = {TaskColumn.todo, TaskColumn.doing, TaskColumn.review, TaskColumn.done};

_FakeTasks _board() => _FakeTasks(
      sources: [
        TaskSourceInfo(id: 'ji', kind: TaskSourceKind.jira, name: 'Acme Jira', writable: _all, hasSecret: true, lastSynced: DateTime.now(), taskCount: 2),
        const TaskSourceInfo(id: 'br', kind: TaskSourceKind.bear, name: 'Bear', taskCount: 1, error: 'macOS didn’t let Kumo read Bear’s notes'),
      ],
      tasks: const [
        TaskEntry(id: 'ji/PRC-1', sourceId: 'ji', kind: TaskSourceKind.jira, key: 'PRC-1', title: 'Bulk discounts', column: TaskColumn.todo, priority: TaskPriority.high, suggestedBranch: 'feat/PRC-1-bulk-discounts'),
        TaskEntry(id: 'ji/PRC-2', sourceId: 'ji', kind: TaskSourceKind.jira, key: 'PRC-2', title: 'Rounding error', column: TaskColumn.review, labels: ['backend']),
        TaskEntry(id: 'br/n#1', sourceId: 'br', kind: TaskSourceKind.bear, key: 'Groceries', title: 'Buy milk', column: TaskColumn.todo),
      ],
    );

Future<AppState> pump(WidgetTester tester, Widget child, TasksSource tasks) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(tasks: tasks);
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
  return state;
}

void main() {
  testWidgets('the Tasks view renders in the app with the design mocks', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(demoWallpaper: true)..view = KumoView.tasks;
    await tester.pumpWidget(KumoApp(state: state));
    await tester.pump();
    expect(find.text('Tasks'), findsWidgets);
    expect(find.text('Mine · 4 sources'), findsOneWidget);
    expect(find.text('migraciones'), findsWidgets);
    await tester.tap(find.text('migraciones').first);
    await tester.pump();
    expect(tester.widget<TaskDetailPanel>(find.byType(TaskDetailPanel)).taskId, 'mock-JI/PRC-11355');
    expect(find.text('↑ ↓ switch tickets · Esc closes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the board shows every source in its columns and filters', (tester) async {
    await pump(tester, const TasksScreen(), _board());
    expect(find.text('Bulk discounts'), findsOneWidget);
    expect(find.text('Rounding error'), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.textContaining('macOS didn’t let Kumo read'), findsOneWidget, reason: 'sync errors are shown with the cached tasks');

    await tester.tap(find.text('Acme Jira'));
    await tester.pump();
    expect(find.text('Buy milk'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Filter tasks'), 'backend');
    await tester.pump();
    expect(find.text('Bulk discounts'), findsNothing);
    expect(find.text('Rounding error'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a task moves through the columns its tool allows', (tester) async {
    final tasks = _board();
    await pump(tester, const TasksScreen(), tasks);
    await tester.tap(find.text('Bulk discounts'));
    await tester.pump();
    expect(find.text('Start in a worktree'), findsOneWidget);
    expect(find.textContaining('feat/PRC-1-bulk-discounts'), findsOneWidget, reason: 'the branch it will use');

    await tester.tap(find.descendant(of: find.byType(KSegmented<TaskColumn>), matching: find.text('Done')));
    await tester.pump();
    expect(tasks.moved, [('ji/PRC-1', TaskColumn.done)]);

    // Bear is read only.
    await tester.tap(find.text('Buy milk'));
    await tester.pump();
    expect(find.textContaining('read only here'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starting from a task links its worktree and moves it to In progress', (tester) async {
    final tasks = _board();
    final state = await pump(tester, const TasksScreen(), tasks);
    final task = tasks.tasks.first;
    final repo = state.workspace.repos.first;
    final error = await state.startTask(task, repo: repo, branch: task.suggestedBranch, agent: false);
    expect(error, isNull);
    expect(tasks.links.single.branch, 'feat/PRC-1-bulk-discounts');
    expect(tasks.moved, [('ji/PRC-1', TaskColumn.doing)]);
    expect(AppState.taskPrompt(task), contains('Task PRC-1 (Jira)'));
  });

  testWidgets('no sources: the board says how to connect one', (tester) async {
    await pump(tester, const TasksScreen(), _FakeTasks());
    expect(find.text('Bring your tasks in'), findsOneWidget);
    expect(find.text('Connect a source'), findsWidgets);
  });

  testWidgets('settings offers sources found on this Mac and asks API sources for a token', (tester) async {
    final tasks = _FakeTasks(detected: const [
      DetectedSourceInfo(kind: TaskSourceKind.obsidian, name: 'Notes', options: {'vault': '/Users/ana/Notes'}),
    ]);
    await pump(tester, const SingleChildScrollView(child: TaskSourceSettingsPanel()), tasks);
    await tester.pump();
    expect(find.text('Obsidian · Notes'), findsOneWidget);
    await tester.tap(find.widgetWithText(KButton, 'Add'));
    await tester.pump();
    expect(tasks.saved.single.$3, {'vault': '/Users/ana/Notes'});

    await tester.tap(find.widgetWithText(KButton, 'Jira'));
    await tester.pump();
    expect(find.text('Add Jira'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'https://acme.atlassian.net');
    await tester.enterText(fields.at(2), 'ana@acme.com');
    await tester.pump();
    await tester.tap(find.text('Add source'));
    await tester.pump();
    expect(tasks.saved, hasLength(1), reason: 'no token yet');

    await tester.enterText(fields.at(4), 'secret-token');
    await tester.pump();
    await tester.tap(find.text('Add source'));
    await tester.pump();
    final (id, kind, options, secret) = tasks.saved.last;
    expect((id, kind, secret), (null, TaskSourceKind.jira, 'secret-token'));
    expect(options['site'], 'https://acme.atlassian.net');
    expect(tester.takeException(), isNull);
  });
}
