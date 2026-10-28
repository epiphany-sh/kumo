import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/mock_data.dart';
import 'package:kumo_ui/data/pipelines_source.dart';
import 'package:kumo_ui/data/repo_activity.dart';
import 'package:kumo_ui/widgets/context_menu.dart';

Future<AppState> _pumpGit(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(demoWallpaper: true);
  await tester.pumpWidget(KumoApp(state: state));
  state.view = KumoView.git;
  await tester.pump();
  return state;
}

/// The breadcrumb's repository button.
Finder get _repoButton => find.byTooltip('Switch repository');

void main() {
  test('the mock has the design’s activity per repository', () {
    final repo = Mock.repoNamed('price-admin')!;
    final a = MockRepoActivity(repo, repo.worktrees);
    expect(a.commits().every((k) => k.branch == null), isTrue, reason: 'main only');
    expect(a.commits(allBranches: true).length, greaterThan(a.commits().length));
    expect(a.pullRequests.where((p) => p.mine).map((p) => p.number), ['#521']);
    expect(a.runs.first.label, 'run #8816', reason: 'newest first');
    expect(a.branches.first.isMain, isTrue);
    expect(a.branches.where((b) => b.worktree == null).map((b) => b.name), contains('feat/PRC-415-csv-validation'));
    a.dispose();

    final users = Mock.repoNamed('users-permissions')!;
    final b = MockRepoActivity(users, users.worktrees);
    expect(b.runsProblem?.kind, CiProblemKind.forbidden);
    expect(b.runs, isEmpty);
    b.dispose();
  });

  testWidgets('the breadcrumb shows the repo of the current worktree', (tester) async {
    await _pumpGit(tester);
    expect(_repoButton, findsOneWidget);
    expect(find.descendant(of: _repoButton, matching: find.text('price-admin')), findsOneWidget);
    expect(find.text('repo of the current worktree'), findsOneWidget);
    expect(find.text('chore: bump pgx to v5.7'), findsOneWidget, reason: 'main’s history');
    expect(find.text('Fetched all remotes 2 min ago'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching repository from the menu changes the commits', (tester) async {
    await _pumpGit(tester);
    await tester.tap(_repoButton);
    await tester.pump();
    expect(find.byType(KMenuPanel), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(KMenuPanel), matching: find.text('price-reader-v2')));
    await tester.pump();
    expect(find.byType(KMenuPanel), findsNothing);
    expect(find.descendant(of: _repoButton, matching: find.text('price-reader-v2')), findsOneWidget);
    expect(find.text('repo of the current worktree'), findsNothing);
    expect(find.text('perf: batch Mongo lookups for price lists'), findsOneWidget);
    expect(find.text('chore: bump pgx to v5.7'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all branches adds commits not on main yet', (tester) async {
    await _pumpGit(tester);
    expect(find.text('refactor: extract rule interfaces', skipOffstage: false), findsNothing);
    await tester.tap(find.text('all branches'));
    await tester.pump();
    // Low in the list: it may sit below the visible part of the panel.
    expect(find.text('refactor: extract rule interfaces', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pull requests: Mine shows only yours', (tester) async {
    await _pumpGit(tester);
    expect(find.text('feat: validate CSV imports before apply'), findsOneWidget);
    expect(find.text('feat: bulk discounts by category'), findsOneWidget);
    await tester.tap(find.text('Mine'));
    await tester.pump();
    expect(find.text('feat: bulk discounts by category'), findsOneWidget);
    expect(find.text('feat: validate CSV imports before apply'), findsNothing);
    expect(find.text('feat: margin guardrails on price edits'), findsNothing);
    await tester.tap(find.text('Review requested').first);
    await tester.pump();
    expect(find.text('feat: validate CSV imports before apply'), findsOneWidget);
    expect(find.text('feat: bulk discounts by category'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pipelines: tapping a run shows its jobs', (tester) async {
    await _pumpGit(tester);
    // Main's failed run is open to start with.
    expect(find.text('3 of 5 jobs passed · commit a3f9c12'), findsOneWidget);
    expect(find.text('TestPriceHistory/range_query: expected 12 rows, got 0'), findsOneWidget);
    expect(find.text('4 of 4 jobs passed · commit 5e0b9a8'), findsNothing);
    await tester.tap(find.text('run #8813'));
    await tester.pump();
    expect(find.text('4 of 4 jobs passed · commit 5e0b9a8'), findsOneWidget);
    expect(find.text('3 of 5 jobs passed · commit a3f9c12'), findsNothing, reason: 'one run open at a time');
    await tester.tap(find.text('run #8813'));
    await tester.pump();
    expect(find.text('4 of 4 jobs passed · commit 5e0b9a8'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pipelines: a token problem shows once, with the way to fix it', (tester) async {
    await _pumpGit(tester);
    await tester.tap(_repoButton);
    await tester.pump();
    await tester.tap(find.descendant(of: find.byType(KMenuPanel), matching: find.text('users-permissions')));
    await tester.pump();
    expect(find.text('Your Bitbucket token can’t read pipelines'), findsOneWidget);
    expect(find.text('Fix token in Settings'), findsOneWidget);
    expect(find.text('Bitbucket Pipelines · no access'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Checked again just now · still HTTP 403'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a worktree row opens its terminal', (tester) async {
    final state = await _pumpGit(tester);
    await tester.tap(find.byTooltip('Open terminal in fix/PRC-398-rounding'));
    await tester.pump();
    expect(state.view, KumoView.terminal);
    expect(state.activeWorktree, 'fix/PRC-398-rounding');
    expect(tester.takeException(), isNull);
  });
}
