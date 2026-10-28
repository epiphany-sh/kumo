import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/data/pipelines_source.dart';
import 'package:kumo_ui/data/pull_requests_source.dart';
import 'package:kumo_ui/data/repo_activity.dart';
import 'package:kumo_ui/engine/engine_pull_requests.dart';
import 'package:kumo_ui/engine/generated/kumo/v1/kumo.pb.dart' as pb;
import 'package:kumo_ui/shell/side_panel.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';

Future<AppState> _panel(WidgetTester tester, {PullRequestsSource? prs}) async {
  tester.view.physicalSize = const Size(600, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(pullRequests: prs);
  await tester.pumpWidget(AppScope(
    state: state,
    child: const KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 420, child: PullRequestCard())))),
    ),
  ));
  await tester.pump();
  await tester.pump();
  return state;
}

void main() {
  test('a pull request comes over the wire as the Git view and the card show it', () {
    final pr = pullRequestFrom(pb.PullRequest(
      number: Int64(518),
      label: '#518',
      title: 'fix: rounding',
      author: pb.Person(id: 'tomas', name: 'Tomás'),
      branch: 'fix/PRC-398-rounding',
      base: 'main',
      review: pb.ReviewState.REVIEW_STATE_CHANGES_REQUESTED,
      reviewRequestedFromYou: true,
      reviewers: [pb.Person(name: 'Mauri', you: true), pb.Person(name: 'Nico')],
      checksPassed: 1,
      checksTotal: 2,
      checksState: pb.CiState.CI_STATE_FAILED,
      state: pb.PrState.PR_STATE_OPEN,
      createdAt: Int64(1761660191000),
    ));
    expect((pr.label, pr.author, pr.authorIsYou, pr.review, pr.checksState), ('#518', 'Tomás', false, PrReview.changesRequested, CiState.failed));
    expect(pr.reviewers, ['Mauri', 'Nico']);
    expect(pr.created, DateTime.fromMillisecondsSinceEpoch(1761660191000));
    final row = pr.toRepo();
    expect((row.number, row.state, row.reviewRequestedFromMe, row.mine), ('#518', RepoPrState.changesRequested, true, false));
    expect(pullRequestFrom(pb.PullRequest(draft: true, review: pb.ReviewState.REVIEW_STATE_APPROVED)).toRepo().state, RepoPrState.draft);
    expect(pullRequestFrom(pb.PullRequest()).checksState, isNull, reason: 'no checks ran');
  });

  testWidgets('the card shows the branch’s pull request with its review and checks', (tester) async {
    await _panel(tester);
    expect(find.text('feat: bulk discounts by category', findRichText: true), findsNothing);
    expect(find.textContaining('#521', findRichText: true), findsOneWidget);
    expect(find.textContaining('into main · Lucía requested as reviewer'), findsOneWidget);
    expect(find.text('2 of 3 checks passed · running'), findsOneWidget);
    expect(find.text('Open in GitHub'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without one, it offers to create it from the branch', (tester) async {
    final prs = MockPullRequests();
    final state = await _panel(tester, prs: prs);
    final repo = state.workspace.repos.first;
    final main = repo.worktrees.firstWhere((w) => w.isMain);
    state.selectWorktree(main.branch, path: main.path);
    await tester.pump();
    await tester.pump();
    expect(find.text('No PR for ${main.branch} yet.'), findsOneWidget);
    await tester.tap(find.text('Create pull request'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isNotEmpty, reason: 'a title from the branch');
    await tester.enterText(find.byType(TextField), 'chore: tidy up');
    await tester.tap(find.text('Create PR'));
    await tester.pump();
    await tester.pump();
    expect(prs.created.values.single.title, 'chore: tidy up');
    expect(prs.created.values.single.draft, isTrue, reason: 'drafts by default');
    expect(find.textContaining('chore: tidy up', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
