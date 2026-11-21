import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/preferences.dart';
import 'package:kumo_ui/data/agents_source.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/data/pull_requests_source.dart';
import 'package:kumo_ui/data/todos_source.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';
import 'package:kumo_ui/views/tasks_screen.dart';
import 'package:kumo_ui/views/todos_view.dart';
import 'package:kumo_ui/widgets/controls.dart';
import 'package:kumo_ui/widgets/repo_picker.dart';

Future<AppState> _pump(WidgetTester tester, {TodosSource? todos, PullRequestsSource? pulls, AgentsSource? agents}) async {
  tester.view.physicalSize = const Size(1440, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = AppState(todos: todos ?? MockTodosSource(), pullRequests: pulls, agents: agents, prefs: Preferences.memory());
  s.setSetting(TasksScreen.viewSetting, 'todos');
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

/// Agents as the engine serves them: Codex lists its models, each with its
/// efforts; sessions are kept and can end.
class _LiveAgents extends MockAgentsSource {
  final started = <({String model, String effort, String todoId, String worktree})>[];
  final List<AgentRun> _runs = [];

  @override
  bool get live => true;

  @override
  List<AgentProviderInfo> get providers => const [
        AgentProviderInfo(
          id: 'codex',
          name: 'Codex CLI',
          short: 'CX',
          program: 'codex',
          enabled: true,
          isDefault: true,
          installed: true,
          tunable: true,
          models: [
            AgentModelChoice(id: 'gpt-6-luna', name: 'GPT-6-Luna', efforts: ['low', 'medium']),
            AgentModelChoice(id: 'gpt-6-sol', name: 'GPT-6-Sol', efforts: ['low', 'medium', 'high', 'max']),
          ],
          efforts: ['low', 'medium', 'high'],
        ),
      ];

  @override
  List<AgentRun> get runs => _runs;

  void end(String id, {int code = 1, String line = ''}) {
    final at = _runs.indexWhere((r) => r.id == id);
    final r = _runs[at];
    _runs[at] = AgentRun(id: r.id, providerId: r.providerId, providerName: r.providerName, short: r.short, worktreePath: r.worktreePath, terminalId: r.terminalId, title: r.title, status: AgentStatus.done, startedAt: r.startedAt, exitCode: code, lastLine: line);
    notifyListeners();
  }

  @override
  Future<AgentRun?> start({String? providerId, required String worktreePath, String prompt = '', String title = '', List<AgentContextItem> context = const [], String model = '', String effort = '', String todoId = ''}) async {
    started.add((model: model, effort: effort, todoId: todoId, worktree: worktreePath));
    final run = AgentRun(id: 'session-${started.length}', providerId: 'codex', providerName: 'Codex CLI', short: 'CX', worktreePath: worktreePath, terminalId: 't-${started.length}', title: title, status: AgentStatus.running, startedAt: DateTime.now());
    _runs.add(run);
    notifyListeners();
    return run;
  }
}

TodoRun _run({String agent = 'Claude Code'}) => TodoRun(
      repoPath: 'repo-a',
      worktreePath: '/wt/repo-a/retry-rate-limits',
      branch: 'fix/retry-rate-limits',
      base: 'main',
      agentName: agent,
      model: 'opus',
      effort: 'high',
    );

/// A TODO already with an agent, at [status].
Future<TodoItem> _at(MockTodosSource todos, String title, TodoStatus status, {String note = ''}) async {
  final t = (await todos.add(title, repoPath: 'repo-a'))!;
  await todos.attach(t.id, _run());
  for (final step in TodoStatus.steps) {
    if (step.index > status.index) break;
    if (step == TodoStatus.working) continue;
    await todos.setStatus(t.id, step, by: step.index <= TodoStatus.review.index ? 'Claude Code' : 'You', note: step == status ? note : '');
  }
  return todos.todo(t.id)!;
}

void main() {
  group('MockTodosSource keeps the engine’s rules', () {
    test('a status needs a run; going back drops the later steps; open can forget the run', () async {
      final todos = MockTodosSource();
      final t = (await todos.add('  Retry  '))!;
      expect(t.title, 'Retry');
      expect(await todos.setStatus(t.id, TodoStatus.testing), isNull);
      expect(todos.error, contains('agent first'));
      await todos.attach(t.id, _run());
      await todos.setStatus(t.id, TodoStatus.testing, by: 'Claude Code');
      await todos.setStatus(t.id, TodoStatus.review, by: 'Claude Code');
      final back = (await todos.setStatus(t.id, TodoStatus.working, by: 'Claude Code'))!;
      expect([for (final s in back.steps) s.status], [TodoStatus.working]);
      final pr = (await todos.setStatus(t.id, TodoStatus.pr, by: 'Kumo', prNumber: 418, prUrl: 'u'))!;
      expect(pr.run!.prNumber, 418);
      final cleaned = (await todos.setStatus(t.id, TodoStatus.open, clearRun: true))!;
      expect(cleaned.run, isNull);
      expect(cleaned.status, TodoStatus.open);
    });

    test('a prompt carries the TODO and its notes; branches follow the title', () {
      final t = TodoItem(id: 'x', title: 'Retry the pipelines widget', notes: 'Back off on 403', created: DateTime(2026));
      expect(AppState.todoPrompt(t), 'Retry the pipelines widget\n\nNotes:\nBack off on 403');
      expect(suggestTodoBranch('Retry the pipelines widget when GitHub rate-limits us'), 'fix/retry-pipelines-widget-github');
      expect(suggestTodoBranch('Write a test for rounding'), 'test/test-rounding');
      expect(suggestTodoBranch('Cache the namespace list'), 'feat/cache-namespace-list');
    });
  });

  testWidgets('Tasks switches to TODOs; adding one from the field, Return adds it', (tester) async {
    final s = await _pump(tester);
    expect(find.text('Nothing to do yet'), findsOneWidget);
    expect(find.byType(KSegmented<String>), findsOneWidget);

    final field = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Add a TODO: what needs doing, in your own words');
    await tester.enterText(field, 'Rename PRICE_API everywhere');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(s.todos.todos.single.title, 'Rename PRICE_API everywhere');
    expect(find.text('Rename PRICE_API everywhere'), findsOneWidget);
    expect(find.text('Run with agent'), findsOneWidget);

    // The board: one column per status, the new one under To do.
    for (final column in ['To do', 'With an agent', 'Needs you', 'Shipping']) {
      expect(find.text(column), findsOneWidget);
    }

    // Checking it off hides it; Show done brings a Done column.
    await tester.tap(find.bySemanticsLabel('Mark “Rename PRICE_API everywhere” done'));
    await tester.pump();
    expect(s.todos.todos.single.done, isTrue);
    expect(find.text('Rename PRICE_API everywhere'), findsNothing);
    await tester.tap(find.text('Show done'));
    await tester.pump();
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Rename PRICE_API everywhere'), findsOneWidget);

    // Back to the tickets.
    await tester.tap(find.descendant(of: find.byType(KSegmented<String>), matching: find.text('Tickets')));
    await tester.pump();
    expect(s.setting<String>(TasksScreen.viewSetting, ''), 'tickets');
    expect(find.byType(TodosView), findsNothing);
  });

  testWidgets('waiting for review: approve pushes, then the PR is opened from the TODO', (tester) async {
    final todos = MockTodosSource();
    final pulls = MockPullRequests();
    await _at(todos, 'Retry on rate limits', TodoStatus.review, note: '48 tests pass');
    final s = await _pump(tester, todos: todos, pulls: pulls);
    expect(find.text('Needs you'), findsOneWidget);
    expect(find.text('Needs your review'), findsOneWidget);

    await tester.tap(find.text('Retry on rate limits'));
    await tester.pump();
    expect(find.text('Your turn: test it and approve it'), findsOneWidget);
    expect(find.text('48 tests pass'), findsWidgets);
    expect(find.text('Claude Code · opus · high effort'), findsOneWidget);
    expect(find.text('Waiting for your review'), findsWidgets);

    await tester.tap(find.text('Approve and push'));
    await tester.pumpAndSettle();
    final pushed = s.todos.todos.single;
    expect(pushed.status, TodoStatus.pushed);
    expect(pushed.steps.last.by, 'You');
    expect(find.text('Create PR'), findsOneWidget);

    await tester.tap(find.text('Create PR'));
    await tester.pumpAndSettle();
    final withPr = s.todos.todos.single;
    expect(withPr.status, TodoStatus.pr);
    expect(withPr.run!.prNumber, 530);
    expect(pulls.created.values.single.title, 'Retry on rate limits');
    expect(find.text('PR #530'), findsOneWidget);
    expect(find.text('Shipping'), findsOneWidget);
  });

  testWidgets('merges are looked for by number while TODOs show, and not under another view', (tester) async {
    final todos = MockTodosSource();
    final pulls = MockPullRequests()..merged.add(530);
    final t = await _at(todos, 'Retry on rate limits', TodoStatus.pushed);
    await todos.setStatus(t.id, TodoStatus.pr, by: 'Kumo', note: '#530', prNumber: 530, prUrl: 'https://github.com/platform/repo-a/pull/530');
    final other = await _at(todos, 'Bump the toolchain', TodoStatus.pushed);
    await todos.setStatus(other.id, TodoStatus.pr, by: 'Kumo', note: '#531', prNumber: 531, prUrl: 'https://github.com/platform/repo-a/pull/531');
    final s = await _pump(tester, todos: todos, pulls: pulls);
    await tester.pump(const Duration(minutes: 3));
    expect(pulls.asked, isEmpty, reason: 'Tasks isn’t the view showing');

    s.view = KumoView.tasks;
    await tester.pump();
    await tester.pump();
    expect(pulls.asked.first, 'states repo-a 531,530', reason: 'one call for the repository, right away');
    expect(s.todos.todo(t.id)!.status, TodoStatus.merged);
    // 531 isn't on the host: looked up by branch, once.
    expect(pulls.asked.where((a) => a.startsWith('forBranch')), hasLength(1));

    await tester.pump(const Duration(minutes: 1));
    expect(pulls.asked.last, 'states repo-a 531');
    expect(pulls.asked.where((a) => a.startsWith('forBranch')), hasLength(1), reason: 'not by branch again');

    s.view = KumoView.terminal;
    await tester.pump();
    final asked = pulls.asked.length;
    await tester.pump(const Duration(minutes: 5));
    expect(pulls.asked, hasLength(asked), reason: 'nothing asked while another view shows');
  });

  testWidgets('merged: clean up forgets the worktree and checks it off', (tester) async {
    final todos = MockTodosSource();
    await _at(todos, 'Bump the toolchain', TodoStatus.merged);
    final s = await _pump(tester, todos: todos);
    expect(find.text('Merged · clean up'), findsOneWidget);
    await tester.tap(find.text('Bump the toolchain'));
    await tester.pump();
    expect(find.text('Clean up merged TODOs on their own'), findsWidgets);
    await tester.tap(find.widgetWithText(KPressable, 'Clean up'));
    await tester.pumpAndSettle();
    final t = s.todos.todos.single;
    expect(t.done, isTrue);
    expect(t.run, isNull);
  });

  testWidgets('the start form offers the workspace’s repos and the agent’s first prompt', (tester) async {
    final todos = MockTodosSource();
    await todos.add('Cache the namespace list', repoPath: 'repo-b');
    await _pump(tester, todos: todos);
    await tester.tap(find.text('Run with agent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run with an agent'));
    await tester.pumpAndSettle();
    expect(find.text('Start in a worktree'), findsOneWidget);
    expect(find.text('repo-b'), findsWidgets);
    expect(find.text('feat/cache-namespace-list'), findsOneWidget);
    expect(find.text('The TODO: “Cache the namespace list”'), findsOneWidget);
    expect(find.textContaining('No notes yet'), findsOneWidget);
  });

  testWidgets('the repository picker searches, groups by namespace and picks with the keyboard', (tester) async {
    final s = await _pump(tester);
    await tester.tap(find.byType(RepoPicker).first);
    await tester.pumpAndSettle();
    expect(find.text('PLATFORM'), findsOneWidget);
    expect(find.text('IDENTITY'), findsOneWidget);
    expect(find.text('Any repository'), findsWidgets);
    expect(find.text('3 repositories in 2 namespaces'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Search repositories and namespaces'), 'users');
    await tester.pump();
    expect(find.text('1 of 3 repositories'), findsOneWidget);
    expect(find.text('PLATFORM'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.textContaining('users-permissions  identity', findRichText: true), findsOneWidget, reason: 'picked: the trigger shows it and its namespace');
    expect(s.recentRepos, ['users-permissions']);

    // Nothing matches: it says where it looks.
    await tester.tap(find.byType(RepoPicker).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Search repositories and namespaces'), 'zzz');
    await tester.pump();
    expect(find.text('No repository matches “zzz”'), findsOneWidget);
  });

  testWidgets('an agent that stopped shows why and starts again in the same worktree with a listed model', (tester) async {
    final todos = MockTodosSource();
    final agents = _LiveAgents();
    final t = (await todos.add('Hacer prueba de performance', repoPath: 'repo-a'))!;
    final first = await agents.start(worktreePath: '/wt/repo-a/perf', todoId: t.id);
    await todos.attach(t.id, TodoRun(repoPath: 'repo-a', worktreePath: '/wt/repo-a/perf', branch: 'feat/perf', providerId: 'codex', agentName: 'Codex CLI', sessionId: first!.id));
    final s = await _pump(tester, todos: todos, agents: agents);
    expect(find.text('Codex CLI · working'), findsOneWidget);

    // Codex refuses the model and exits.
    agents.end(first.id, line: "The 'luna' model is not supported when using Codex with a ChatGPT account.");
    await tester.pump();
    expect(find.text('Agent stopped'), findsOneWidget);
    expect(find.descendant(of: find.ancestor(of: find.text('Needs you'), matching: find.byType(Column)).first, matching: find.text('Agent stopped')), findsOneWidget);

    await tester.tap(find.text('Hacer prueba de performance'));
    await tester.pump();
    expect(find.text('Codex CLI stopped before finishing'), findsOneWidget);
    expect(find.text('It exited with code 1.'), findsOneWidget);
    expect(find.textContaining('not supported when using Codex'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Start the agent again'), findsOneWidget);
    // Models come from the list Codex keeps: nothing to type by hand.
    expect(find.text('Its default'), findsOneWidget);
    await tester.tap(find.text('Its default'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GPT-6-Sol').last);
    await tester.pumpAndSettle();
    expect(find.text('Max'), findsOneWidget, reason: 'GPT-6-Sol goes up to max');
    await tester.tap(find.text('High'));
    await tester.pump();
    await tester.tap(find.text('Start Codex CLI again'));
    await tester.pumpAndSettle();

    final again = agents.started.last;
    expect((again.model, again.effort, again.todoId, again.worktree), ('gpt-6-sol', 'high', t.id, '/wt/repo-a/perf'));
    final now = s.todos.todo(t.id)!;
    expect(now.run!.sessionId, 'session-2');
    expect(now.run!.describe, 'Codex CLI · gpt-6-sol · high effort');
    expect(find.text('Codex CLI · working'), findsOneWidget);
  });
}
