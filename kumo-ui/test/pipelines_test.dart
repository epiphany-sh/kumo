import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/data/pipelines_source.dart';

MockPipelinesSource _mock(MockPipelinesScenario scenario) => MockPipelinesSource(scenario: scenario, latency: Duration.zero);

Future<void> _pumpWidgets(WidgetTester tester, MockPipelinesScenario scenario) async {
  tester.view.physicalSize = const Size(1440, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(
    demoWallpaper: true,
    pipelinesFor: ({required Repo repo, required Worktree worktree, required String worktreePath}) => _mock(scenario),
  );
  await tester.pumpWidget(KumoApp(state: state));
  state.showSidePanelTab(SidePanelTab.widgets);
  await tester.pump();
}

void main() {
  test('the widget is on the panel by default, right after the agent', () {
    final s = AppState();
    expect(s.widgets.take(2), [InspectorWidget.agent, InspectorWidget.pipelines]);
    expect(s.pipelines.provider, CiProvider.githubActions);
    expect(s.pipelines.branch, s.activeWorktree);
    s.dispose();
  });

  test('a branch that was never pushed has no pipelines until it is', () async {
    final p = MockPipelinesSource(scenario: MockPipelinesScenario.notPushed, latency: Duration.zero, unpushed: 1);
    expect(p.latest, isNull);
    expect(p.problem?.kind, CiProblemKind.notPushed);
    final (_, body) = describeCiProblem(p.problem!, CiProvider.githubActions);
    expect(body, contains('1 commit is waiting'));
    await p.refresh();
    expect(p.problem?.kind, CiProblemKind.notPushed, reason: 'only a push starts pipelines');
    p.branchPushed();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(p.problem, isNull);
    expect(p.latest?.state, CiState.running);
    p.dispose();
  });

  test('a failed run re-runs, and the next look finds it passed', () async {
    final p = _mock(MockPipelinesScenario.failed);
    expect(p.latest!.hasFailedJobs, isTrue);
    expect(p.latest!.jobs.firstWhere((j) => j.state == CiState.failed).failure, contains('TestBulkUpsert'));
    await p.rerunFailed();
    expect(p.latest!.state, CiState.running);
    await p.refresh();
    expect(p.latest!.state, CiState.passed);
    p.dispose();
  });

  test('problems read as plain sentences per provider', () {
    expect(describeCiProblem(const CiProblem(CiProblemKind.forbidden), CiProvider.githubActions).$2, contains('read access to Actions'));
    expect(describeCiProblem(const CiProblem(CiProblemKind.forbidden), CiProvider.gitlabCi).$2, contains('read_api'));
    expect(describeCiProblem(const CiProblem(CiProblemKind.forbidden, missingScope: 'pipeline'), CiProvider.bitbucketPipelines).$2, contains('“pipeline”'));
    expect(describeCiProblem(const CiProblem(CiProblemKind.unauthorized), CiProvider.gitlabCi).$1, 'Your GitLab token stopped working');
    expect(const CiProblem(CiProblemKind.unreachable).keepsLastRun, isTrue);
    expect(const CiProblem(CiProblemKind.forbidden).needsSettings, isTrue);
    expect(CiProvider.ofHost('LO'), isNull);
  });

  test('a repository without a supported CI says so', () {
    final p = MockPipelinesSource(provider: null);
    expect(p.problem?.kind, CiProblemKind.unsupported);
    p.dispose();
  });

  testWidgets('a token without access: the message, the provider’s answer and the fix', (tester) async {
    await _pumpWidgets(tester, MockPipelinesScenario.forbidden);
    expect(find.text('Pipelines'), findsWidgets);
    expect(find.text('Your GitHub token can’t read pipelines'), findsOneWidget);
    expect(find.text('HTTP 403 · Resource not accessible by personal access token'), findsOneWidget);
    expect(find.text('Fix token in Settings'), findsOneWidget);

    // The widget's actions sit below the panel's fold: scroll to them, then
    // back to the top to read the run.
    final panel = tester.state<ScrollableState>(find.ancestor(of: find.text('Retry'), matching: find.byType(Scrollable)).first);
    await tester.ensureVisible(find.text('Retry'));
    await tester.pump();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    panel.position.jumpTo(0);
    await tester.pump();
    expect(find.text('Your GitHub token can’t read pipelines'), findsNothing);
    expect(find.text('Running'), findsWidgets);
    expect(find.text('integration · testcontainers'), findsOneWidget);
  });

  testWidgets('a failed job shows its first error line and re-runs', (tester) async {
    await _pumpWidgets(tester, MockPipelinesScenario.failed);
    expect(find.text('Failed'), findsWidgets);
    expect(find.text('TestBulkUpsert · bulk_test.go:88 · expected 3 rows, got 2'), findsOneWidget);
    await tester.ensureVisible(find.text('Re-run failed jobs'));
    await tester.pump();
    await tester.tap(find.text('Re-run failed jobs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Running'), findsWidgets);
  });

  testWidgets('an outage keeps the last run, marked stale', (tester) async {
    await _pumpWidgets(tester, MockPipelinesScenario.unreachable);
    expect(find.text('Stale'), findsOneWidget);
    expect(find.text('GitHub isn’t answering'), findsOneWidget);
    expect(find.text('build'), findsWidgets);
    expect(find.text('Retry now'), findsOneWidget);
  });
}
