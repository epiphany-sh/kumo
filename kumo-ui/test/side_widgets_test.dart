import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/data/agents_source.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/data/tests_source.dart';
import 'package:kumo_ui/shell/side_panel.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';

/// Agents as the daemon reports them; records what the panel asks for.
class _Agents extends MockAgentsSource {
  List<AgentRun> current = const [];
  final sent = <(String, AgentContextItem, String)>[];
  final stopped = <String>[];

  @override
  bool get live => true;
  @override
  List<AgentRun> get runs => current;
  @override
  Future<bool> addContext(String id, AgentContextItem item, {String text = ''}) async {
    sent.add((id, item, text));
    return true;
  }

  @override
  Future<void> stop(String id) async => stopped.add(id);

  void set(List<AgentRun> runs) {
    current = runs;
    notifyListeners();
  }
}

class _Tests extends TestsSource {
  @override
  String get command => 'make test';
  @override
  String get commandOrigin => 'Makefile';
  @override
  bool get loading => false;
  @override
  TestRunInfo? run;
  @override
  String? error;
  final ran = <String>[];
  int stops = 0;

  @override
  Future<void> runTests({String command = ''}) async {
    ran.add(command);
    run = TestRunInfo(command: command.isEmpty ? this.command : command, terminalId: 't9', state: TestRunState.running, startedAt: DateTime(2026, 10, 28, 14, 7), lastLine: 'Compiling app');
    notifyListeners();
  }

  @override
  Future<void> stop() async => stops++;

  void finish(TestRunInfo info) {
    run = info;
    notifyListeners();
  }
}

final _t0 = DateTime(2026, 10, 28, 13, 54);

AgentRun _run(String path, {AgentStatus status = AgentStatus.running, List<AgentStep> steps = const [], List<AgentContextItem> context = const []}) => AgentRun(
      id: 'a1',
      providerId: 'claude',
      providerName: 'Claude Code',
      short: 'CC',
      worktreePath: path,
      terminalId: 't1',
      title: 'PRC-412 · Bulk discounts by category',
      status: status,
      startedAt: _t0,
      lastLine: 'Editing internal/kafka/bulk_consumer.go',
      context: context,
      steps: steps,
    );

const _ticket = AgentContextItem(kind: AgentContextKind.task, title: 'PRC-412 · Bulk discounts by category', detail: 'Jira · Story', url: 'https://acme.atlassian.net/browse/PRC-412');

Future<(AppState, String)> _pump(WidgetTester tester, {required _Agents agents, _Tests? tests, List<InspectorWidget> show = const []}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(agents: agents, testsFor: tests == null ? null : (_) => tests);
  for (final w in show) {
    state.addWidget(w);
  }
  final entry = state.activeWorktreeEntry!;
  await tester.pumpWidget(AppScope(
    state: state,
    child: const KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: SidePanel())),
    ),
  ));
  await tester.pump();
  return (state, state.workspace.absolutePathOf(entry));
}

void main() {
  testWidgets('the Agent widget shows this worktree’s agent, not a design', (tester) async {
    final agents = _Agents();
    final (state, path) = await _pump(tester, agents: agents);
    expect(find.textContaining('No agent in this worktree yet'), findsOneWidget);
    expect(find.text('New agent'), findsOneWidget);

    agents.set([
      _run('/elsewhere'),
      _run(path, context: const [_ticket], steps: [
        AgentStep(at: _t0, kind: AgentStepKind.started, text: 'Claude Code'),
        AgentStep(at: _t0, kind: AgentStepKind.edited, text: 'a.go'),
        AgentStep(at: _t0, kind: AgentStepKind.edited, text: 'b.go'),
        AgentStep(at: _t0, kind: AgentStepKind.edited, text: 'a.go'),
        AgentStep(at: _t0, kind: AgentStepKind.ran, text: 'go test ./...'),
      ]),
    ]);
    await tester.pump();
    expect(find.text('Claude Code'), findsOneWidget);
    expect(find.text('Working · started 13:54'), findsOneWidget);
    expect(find.text('PRC-412 · Bulk discounts by category'), findsWidgets);
    expect(find.text('Jira · Story'), findsWidgets);
    expect(find.text('Editing internal/kafka/bulk_consumer.go'), findsOneWidget);
    expect(find.text('2 files edited · 1 command'), findsOneWidget);
    expect(find.textContaining('more agent'), findsNothing, reason: 'the other one is in another worktree');

    await tester.tap(find.byTooltip('More agent actions'));
    await tester.pump();
    await tester.tap(find.text('Stop agent'));
    await tester.pump();
    expect(agents.stopped, ['a1']);

    agents.set([_run(path, status: AgentStatus.needsYou)]);
    await tester.pump();
    expect(find.text('Your turn · started 13:54'), findsOneWidget);
    expect(state.activeAgent?.id, 'a1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Context lists what the agent got; + sends a linked ticket', (tester) async {
    final agents = _Agents();
    final (state, path) = await _pump(tester, agents: agents);
    final linked = state.worktreeTasks;
    expect(linked, isNotEmpty, reason: 'the design board links tasks to this worktree');
    final task = linked.first;
    expect(find.text('${task.key} · ${task.title}'), findsOneWidget);
    expect(find.text('Linked · not sent to the agent'), findsWidgets);

    const page = AgentContextItem(kind: AgentContextKind.doc, title: 'Discount rules v3', detail: 'Confluence · Pricing');
    agents.set([_run(path, context: const [page])]);
    await tester.pump();
    expect(find.text('Discount rules v3'), findsOneWidget);
    expect(find.text('Confluence · Pricing'), findsOneWidget);
    expect(find.text('CF'), findsOneWidget);

    await tester.tap(find.byTooltip('Send context to the agent'));
    await tester.pump();
    await tester.tap(find.text('Send ${task.key}'));
    await tester.pump();
    expect(agents.sent.single.$1, 'a1');
    expect(agents.sent.single.$2.title, '${task.key} · ${task.title}');
    expect(agents.sent.single.$3, contains(task.title), reason: 'the ticket is typed in');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tests runs the worktree’s command and reads the result', (tester) async {
    final tests = _Tests();
    final (state, _) = await _pump(tester, agents: _Agents(), tests: tests, show: const [InspectorWidget.tests]);
    expect(find.text('make test'), findsNothing, reason: 'shown with its origin');
    expect(find.textContaining('from Makefile'), findsOneWidget);
    await tester.tap(find.text('Run tests'));
    await tester.pump();
    expect(tests.ran, ['']);
    expect(find.text('Running…'), findsOneWidget);
    expect(find.text('Compiling app'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(tests.stops, 1);

    tests.finish(TestRunInfo(
      command: 'make test',
      terminalId: 't9',
      state: TestRunState.failed,
      startedAt: DateTime(2026, 10, 28, 14, 7),
      finishedAt: DateTime(2026, 10, 28, 14, 7, 3, 100),
      exitCode: 2,
      passed: 146,
      failed: 2,
      suites: const [
        TestSuiteResult(name: 'internal/http', passed: true, duration: Duration(milliseconds: 1210)),
        TestSuiteResult(name: 'internal/discount', passed: false, duration: Duration(milliseconds: 412)),
      ],
      failures: const ['TestBulk'],
    ));
    await tester.pump();
    expect(find.text('2 failed'), findsOneWidget);
    expect(find.text(' · 3.1s'), findsOneWidget);
    expect(find.text('internal/discount'), findsOneWidget);
    expect(find.text('412ms'), findsOneWidget);
    expect(find.text('TestBulk'), findsOneWidget);

    // A command of the user's own, kept for the repository.
    await tester.tap(find.byTooltip('Change the test command'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'go test ./internal/...');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(state.testCommand, 'go test ./internal/...');
    await tester.tap(find.text('Run again'));
    await tester.pump();
    expect(tests.ran.last, 'go test ./internal/...');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Activity is the agent’s steps and the test runs, newest first', (tester) async {
    final agents = _Agents();
    final tests = _Tests();
    final (_, path) = await _pump(tester, agents: agents, tests: tests, show: const [InspectorWidget.activity]);
    expect(find.textContaining('What agents and test runs do'), findsOneWidget);

    AgentStep step(int minute, AgentStepKind kind, String text) => AgentStep(at: _t0.add(Duration(minutes: minute)), kind: kind, text: text);
    agents.set([
      _run(path, steps: [
        step(0, AgentStepKind.started, 'Claude Code'),
        step(1, AgentStepKind.context, 'Discount rules v3'),
        step(4, AgentStepKind.read, 'Read 3 files'),
        step(9, AgentStepKind.edited, 'internal/kafka/bulk_consumer.go'),
        step(11, AgentStepKind.waiting, 'Done. Want me to open the PR?'),
      ]),
    ]);
    tests.finish(TestRunInfo(command: 'make test', terminalId: 't9', state: TestRunState.passed, startedAt: _t0.add(const Duration(minutes: 10)), finishedAt: _t0.add(const Duration(minutes: 10, seconds: 30)), passed: 148));
    await tester.pump();
    final texts = [
      for (final t in tester.widgetList<Text>(find.descendant(of: find.byType(Row), matching: find.byType(Text))))
        if (t.data case final d? when RegExp(r'^\d\d:\d\d$').hasMatch(d)) d,
    ];
    expect(texts.take(3), ['14:05', '14:04', '14:04'], reason: 'newest first');
    expect(find.text('Waiting for you · Done. Want me to open the PR?'), findsOneWidget);
    expect(find.text('Tests passed · 148'), findsOneWidget);
    expect(find.text('Edited internal/kafka/bulk_consumer.go'), findsOneWidget);
    expect(find.text('Got Discount rules v3'), findsOneWidget);
    expect(find.text('Started Claude Code'), findsNothing, reason: 'six shown');
    await tester.tap(find.text('Show all 7'));
    await tester.pump();
    expect(find.text('Started Claude Code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
