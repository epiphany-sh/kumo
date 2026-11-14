import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/mock_data.dart';
import 'package:kumo_ui/data/pr_agent_prompts.dart';
import 'package:kumo_ui/data/pull_requests_source.dart';
import 'package:kumo_ui/data/repo_activity.dart';
import 'package:kumo_ui/overlays/pr_description_dialog.dart';
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

const _mine = RepoPullRequest(
  number: '#521',
  title: 'feat: bulk discounts by category',
  author: 'Mauri',
  branch: 'feat/TSK-412-bulk-discounts',
  state: RepoPrState.draft,
  mine: true,
  base: 'main',
);

PrAgentTarget _target({String host = 'GH', bool inWorktree = true, RepoPullRequest pr = _mine}) =>
    PrAgentTarget(pr: pr, repoName: 'repo-a', host: host, base: 'main', inWorktree: inWorktree);

void main() {
  group('prompts', () {
    test('a review reads the diff and changes nothing', () {
      final p = prAgentPrompt(PrAgentJob.review, _target());
      expect(p, contains('git diff origin/main...HEAD'));
      expect(p, contains('gh pr diff 521'));
      expect(p, contains('Don’t change any file and don’t post anything'));
      expect(p, contains('You are in its worktree.'));
    });

    test('without the PR’s worktree it reads the branch from origin', () {
      final p = prAgentPrompt(PrAgentJob.explain, _target(inWorktree: false));
      expect(p, contains('git diff origin/main...origin/feat/TSK-412-bulk-discounts'));
      expect(p, contains('don’t check it out'));
    });

    test('GitLab says merge request and uses glab', () {
      final p = prAgentPrompt(PrAgentJob.addressComments, _target(host: 'GL'));
      expect(p, startsWith('Merge request #521'));
      expect(p, contains('glab mr view 521 --comments'));
      expect(p, isNot(contains('gh ')));
    });

    test('fixing checks commits but doesn’t push', () {
      final p = prAgentPrompt(PrAgentJob.fixChecks, _target());
      expect(p, contains('gh pr checks 521'));
      expect(p, contains('don’t push until I say so'));
    });

    test('the description goes to the draft file, with what was picked', () {
      final p = prDescriptionPrompt(
        _target(),
        draftPath: '/tmp/kumo-pr/repo-a-521.md',
        titlePath: '/tmp/kumo-pr/repo-a-521.title.txt',
        ticket: 'Bulk discounts by category\n\nTask TSK-412 (Jira).',
        templatePath: '.github/pull_request_template.md',
        length: PrDescriptionLength.short,
        extra: 'the flag stays off in production',
      );
      expect(p, contains('`/tmp/kumo-pr/repo-a-521.md`'));
      expect(p, contains('`/tmp/kumo-pr/repo-a-521.title.txt`'));
      expect(p, contains('.github/pull_request_template.md'));
      expect(p, contains('gh pr view 521 --json body'));
      expect(p, contains('Length: ${PrDescriptionLength.short.hint}'));
      expect(p, contains('Also: the flag stays off in production'));
      expect(p, contains('don’t edit the pull request'));
      expect(p, endsWith('Task TSK-412 (Jira).'));
    });

    test('without a ticket or commits, it isn’t told to read them', () {
      final p = prDescriptionPrompt(_target(host: 'BB'), draftPath: '/d.md', commits: false);
      expect(p, isNot(contains('The ticket')));
      expect(p, isNot(contains('git log')));
      expect(p, isNot(contains('current description')), reason: 'Bitbucket has no CLI to read it');
      expect(p, isNot(contains('better title')));
    });

    test('a revision rewrites the same file', () {
      expect(prDescriptionRevision('/d.md', 'shorter '), contains('`/d.md` as follows, and save it to the same file: shorter.'));
    });

    test('the ticket key comes from the branch', () {
      expect(ticketKeyIn('feat/TSK-412-bulk-discounts'), 'TSK-412');
      expect(ticketKeyIn('chore/golangci-1.61'), isNull);
    });
  });

  test('the mock edits pull requests in place', () async {
    final repo = Mock.repoNamed('repo-a')!;
    final a = MockRepoActivity(repo, repo.worktrees);
    final pr = a.pullRequests.firstWhere((p) => p.number == '#521');
    expect(pr.url, 'https://github.com/platform/repo-a/pull/521');
    expect(a.prsEditable, isTrue);
    await a.editPr(pr, draft: false, body: 'Hello');
    expect(a.pullRequests.firstWhere((p) => p.number == '#521').state, RepoPrState.reviewRequested);
    expect(a.descriptions['#521'], 'Hello');
    await a.editPr(a.pullRequests.firstWhere((p) => p.number == '#521'), title: 'feat: bulk discounts');
    expect(a.pullRequests.firstWhere((p) => p.number == '#521').title, 'feat: bulk discounts');
    a.dispose();

    final source = MockPullRequests();
    expect(source.canEdit, isTrue);
    final edited = await source.edit(repoPath: '/r', number: 521, draft: false);
    expect(edited.draft, isFalse);
    expect(source.edited[521]?.draft, isFalse);
  });

  testWidgets('each PR has open-on-host and an actions menu that fits it', (tester) async {
    await _pumpGit(tester);
    expect(find.byTooltip('Open #521 on GitHub'), findsOneWidget);

    await tester.tap(find.byTooltip('Actions for #521'));
    await tester.pump();
    final menu = find.byType(KMenuPanel);
    expect(menu, findsOneWidget);
    for (final item in ['Write the description…', 'Explain the changes', 'Open on GitHub', 'Copy link', 'Open its worktree', 'Mark ready for review']) {
      expect(find.descendant(of: menu, matching: find.text(item)), findsOneWidget, reason: item);
    }
    expect(find.descendant(of: menu, matching: find.text('Review it…')), findsNothing, reason: 'it’s yours');
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    await tester.tap(find.byTooltip('Actions for #525'));
    await tester.pump();
    expect(find.descendant(of: find.byType(KMenuPanel), matching: find.text('Review it…')), findsOneWidget);
    expect(find.descendant(of: find.byType(KMenuPanel), matching: find.text('Write the description…')), findsNothing);
    expect(find.descendant(of: find.byType(KMenuPanel), matching: find.text('New worktree…')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mark ready for review changes the PR and says so', (tester) async {
    final state = await _pumpGit(tester);
    await tester.tap(find.byTooltip('Actions for #521'));
    await tester.pump();
    await tester.tap(find.text('Mark ready for review'));
    await tester.pump();
    await tester.pump();
    expect(state.undo?.message, '#521 is ready for review');
    expect(find.text('Draft'), findsNothing);
    state.dismissUndo();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an agent’s draft becomes the description only on Update', (tester) async {
    final state = await _pumpGit(tester);
    await tester.tap(find.byTooltip('Actions for #521'));
    await tester.pump();
    await tester.tap(find.text('Write the description…'));
    await tester.pumpAndSettle();
    expect(find.byType(PrDescriptionDialog), findsOneWidget);
    expect(find.text('Write a description for #521'), findsOneWidget);
    expect(find.text('Changes against main'), findsOneWidget);

    await tester.tap(find.text('Write description'));
    await tester.pump();
    expect(state.undo, isNull, reason: 'nothing changed yet');
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();
    expect(find.text('Preview'), findsOneWidget);
    final update = find.text('Update #521 and its title');
    expect(update, findsOneWidget);

    await tester.tap(update);
    await tester.pumpAndSettle();
    expect(find.byType(PrDescriptionDialog), findsNothing);
    expect(state.undo?.message, 'Updated #521 on GitHub');
    state.dismissUndo();
    expect(tester.takeException(), isNull);
  });
}
