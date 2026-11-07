import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/changes.dart';
import 'package:kumo_ui/data/git_agent_prompts.dart';
import 'package:kumo_ui/data/mock_data.dart';
import 'package:kumo_ui/data/pr_agent_prompts.dart';
import 'package:kumo_ui/data/repo_activity.dart';
import 'package:kumo_ui/data/repo_history.dart';
import 'package:kumo_ui/overlays/release_notes_dialog.dart';
import 'package:kumo_ui/overlays/resolve_comments_dialog.dart';
import 'package:kumo_ui/views/git_screen.dart';
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

RepoRelease _r(String tag, ReleaseKind kind) => RepoRelease(tag: tag, kind: kind, time: DateTime(2026, 11, 1));

Finder _inMenu(String text) => find.descendant(of: find.byType(KMenuPanel), matching: find.text(text));

void main() {
  group('which release to compare with', () {
    final list = [
      _r('v1.9.0-rc.1', ReleaseKind.preRelease),
      _r('v1.8.0', ReleaseKind.release),
      _r('v1.7.3', ReleaseKind.tagOnly),
      _r('v1.7.2', ReleaseKind.release),
      _r('v1.7.1', ReleaseKind.release),
    ];

    test('a pre-release: the latest full release', () => expect(previousReleaseIndex(list, 0), 1));
    test('a release: the release before it, bare tags folded in', () {
      expect(previousReleaseIndex(list, 1), 3);
      expect(skippedBetween(list, 1, 3).map((r) => r.tag), ['v1.7.3']);
    });
    test('a bare tag: the release before it', () => expect(previousReleaseIndex(list, 2), 3));
    test('the oldest: nothing (the first release)', () => expect(previousReleaseIndex(list, 4), isNull));
    test('latest skips pre-releases', () => expect(latestReleaseIndex(list), 1));
    test('the next patch', () {
      expect(nextPatchOf('v1.8.0'), 'v1.8.1');
      expect(nextPatchOf('2.0.9-rc.1'), '2.0.10');
      expect(nextPatchOf('nightly'), 'nightly');
    });
  });

  test('a hunk numbers its lines and writes its header', () {
    final h = DiffHunk.parse(72, 72, [' a', '-b', '-c', '+d', ' e'], section: 'func f()');
    expect(h.header, '@@ -72,4 +72,3 @@ func f()');
    expect([for (final l in h.lines) (l.oldNo, l.newNo)], [(72, 72), (73, null), (74, null), (null, 73), (75, 74)]);
    expect(h.lines[3].kind, DiffKind.added);
    final f = CommitFile(path: 'internal/x/y.go', kind: CommitFileKind.modified, hunks: [h]);
    expect((f.added, f.deleted, f.name, f.dir), (1, 2, 'y.go', 'internal/x'));
  });

  test('every mock commit opens to some change', () {
    expect(mockCommitDetail('7be2f41', 'feat: batch upsert with CopyFrom').files.map((f) => f.path), contains('internal/discount/repository.go'));
    for (final subject in ['chore: bump pgx to v5.7', 'docs: rollback runbook', 'refactor: extract rule interfaces', 'fix: nil pointer on empty price list', 'feat: role templates']) {
      final d = mockCommitDetail('0000000', subject);
      expect(d.files, isNotEmpty, reason: subject);
      expect(d.added + d.deleted, greaterThan(0), reason: subject);
    }
    expect(mockCommitDetail('1', 'refactor: extract rule interfaces').files.first.oldPath, isNotNull);
  });

  test('a thread’s kind is guessed from its words', () {
    expect(ThreadKind.of('nit: rename this'), ThreadKind.nit);
    expect(ThreadKind.of('Why is it on in staging?'), ThreadKind.question);
    expect(ThreadKind.of('Should we retry the batch?'), ThreadKind.change);
    expect(ThreadKind.of('The offset is committed too early.'), ThreadKind.change);
  });

  test('the agent’s answers file is read leniently', () {
    final a = ThreadAnswer.parse('[{"thread":"t1","changed":"Retries","commit":"a91c4e2","reply":"Done"},{"nope":1},{"thread":"t4","reply":"Because QA"}]');
    expect(a.map((x) => (x.thread, x.commit, x.reply)), [('t1', 'a91c4e2', 'Done'), ('t4', '', 'Because QA')]);
    expect(ThreadAnswer.parse('not json'), isEmpty);
    expect(ThreadAnswer.parse('{"thread":"t1"}'), isEmpty);
  });

  group('prompts', () {
    test('release notes: since the previous release, into the draft file', () {
      final p = releaseNotesPrompt(
        const ReleaseTarget(repoName: 'price-admin', host: 'GH', tag: 'v1.8.0', since: 'v1.7.2', skipped: ['v1.7.3']),
        draftPath: '/tmp/n.md',
        namePath: '/tmp/n.name.txt',
        prs: const [('#521', 'feat: bulk discounts by category', 'Mauri', 'PRC-412')],
        styleOf: 'v1.7.2',
        style: ReleaseNotesStyle.highlights,
      );
      expect(p, contains('git log --format=\'%h %s%n%b\' v1.7.2..v1.8.0'));
      expect(p, contains('That includes v1.7.3, which has no notes of its own.'));
      expect(p, contains('- #521 feat: bulk discounts by category (Mauri, PRC-412)'));
      expect(p, contains('gh release view v1.7.2'));
      expect(p, contains(ReleaseNotesStyle.highlights.hint));
      expect(p, contains('`/tmp/n.name.txt`'));
      expect(p, contains('`/tmp/n.md`'));
      expect(p, contains('don’t edit the release'));
    });

    test('the first release is written from the project', () {
      final p = releaseNotesPrompt(const ReleaseTarget(repoName: 'price-reader-v2', host: 'GL', tag: 'v0.1.0', first: true), draftPath: '/tmp/n.md');
      expect(p, contains('the first release of price-reader-v2'));
      expect(p, contains('nothing before v0.1.0 to compare with'));
      expect(p, contains('README'));
      expect(p, isNot(contains('..v0.1.0')));
    });

    test('an oldest listed release that isn’t the first: git finds the tag before it', () {
      final p = releaseNotesPrompt(const ReleaseTarget(repoName: 'price-admin', host: 'GH', tag: 'v1.6.4'), draftPath: '/tmp/n.md');
      expect(p, isNot(contains('first release')));
      expect(p, contains(r'$(git describe --tags --abbrev=0 v1.6.4^)..v1.6.4'));
    });

    test('resolve comments lists the threads and asks for the answers file', () {
      const t = PrAgentTarget(
        pr: RepoPullRequest(number: '#521', title: 'feat: bulk discounts', author: 'Mauri', branch: 'feat/PRC-412', state: RepoPrState.draft, mine: true),
        repoName: 'price-admin',
        host: 'GH',
        base: 'main',
        inWorktree: true,
      );
      final threads = [ReviewThread(id: 't2', author: 'Tomás', path: 'internal/kafka/bulk_consumer.go', line: 42, body: 'The offset is committed before the write.', time: DateTime(2026))];
      final p = resolveCommentsPrompt(t, threads, answersPath: '/tmp/a.json');
      expect(p, contains('- [t2] Tomás on `internal/kafka/bulk_consumer.go:42`: The offset is committed before the write.'));
      expect(p, contains('`/tmp/a.json`'));
      expect(p, contains('don’t push'));
      expect(p, contains('"thread": "t2"'));
      expect(resolveCommentsPrompt(t, threads, answersPath: '/a', mode: ResolveMode.codeOnly), isNot(contains('Write each reply')));
    });

    test('a commit is explained, not changed', () {
      final p = commitExplainPrompt(repoName: 'price-admin', sha: '7be2f41', subject: 'feat: batch upsert');
      expect(p, contains('git show 7be2f41'));
      expect(p, contains('Don’t change any file.'));
    });
  });

  test('the mock: ranges add up, releases and threads change', () async {
    final repo = Mock.repoNamed('price-admin')!;
    final a = MockRepoActivity(repo, repo.worktrees);
    final all = a.releases;
    expect(all.first.tag, 'v1.9.0-rc.1');
    final v180 = all.firstWhere((r) => r.tag == 'v1.8.0');
    final range = await a.releaseRange(v180, since: all.firstWhere((r) => r.tag == 'v1.7.2'));
    expect(range.commits, 19, reason: 'v1.8.0 and the bare v1.7.3');
    expect(range.prs.length, 6);
    expect(range.tickets, ['PRC-412', 'PRC-409', 'PRC-411']);
    await a.editRelease(all.first, publish: true, notes: '## Hi');
    expect(a.releases.first.kind, ReleaseKind.release);
    expect(a.releases.first.notes, '## Hi');
    final pr = a.pullRequests.firstWhere((p) => p.number == '#521');
    expect(a.openThreadsOf(pr), 4);
    final t1 = (await a.reviewThreads(pr)).firstWhere((t) => t.id == 't1');
    await a.answerThread(pr, t1, reply: 'Done', resolve: true);
    expect(a.openThreadsOf(pr), 3);
    expect((await a.commitDetail(a.commits().first)).files, isNotEmpty);
    a.dispose();
  });

  testWidgets('commits: one branch, one author, and what a commit changed', (tester) async {
    await _pumpGit(tester);
    await tester.tap(find.byTooltip('Which branch’s commits'));
    await tester.pump();
    await tester.tap(_inMenu('feat/PRC-412-bulk-discounts'));
    await tester.pump();
    // (Its subject is also a pipeline run's title: the row is found by its tooltip.)
    expect(find.byTooltip('Show what 7be2f41 changed'), findsOneWidget);
    expect(find.byTooltip('Show what 2c9a0e5 changed'), findsOneWidget);
    expect(find.byTooltip('Show what d41f7c3 changed'), findsNothing, reason: 'another branch');
    expect(find.text('Branched from main'), findsOneWidget);

    await tester.tap(find.byTooltip('Whose commits'));
    await tester.pump();
    await tester.tap(_inMenu('Lucía'));
    await tester.pump();
    expect(find.byTooltip('Show what 7be2f41 changed'), findsNothing);
    expect(find.byTooltip('Show what 9d02e1f changed'), findsOneWidget, reason: 'main’s history under the branch');

    await tester.tap(find.byTooltip('Back to main, everyone'));
    await tester.pump();
    await tester.tap(find.byTooltip('Show what a3f9c12 changed'));
    await tester.pumpAndSettle();
    expect(find.byType(CommitSheet), findsOneWidget);
    expect(find.text('history.go'), findsWidgets);
    expect(find.text('router.go'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('csv.go'), findsWidgets, reason: 'the next (older) commit');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CommitSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('releases: the list, a release’s actions, and notes by an agent', (tester) async {
    final state = await _pumpGit(tester);
    await tester.tap(find.text('Releases & tags'));
    await tester.pump();
    expect(find.textContaining('6 releases · 1 tag only'), findsOneWidget);
    expect(find.text('Latest'), findsWidgets);
    expect(find.text('Bulk discounts'), findsWidgets, reason: 'the latest is picked');

    await tester.tap(find.text('v1.9.0-rc.1'));
    await tester.pump();
    await tester.pump();
    expect(find.text('A pre-release: compared with the latest full release, v1.8.0.'), findsOneWidget);
    await tester.tap(find.byTooltip('Actions for v1.9.0-rc.1'));
    await tester.pump();
    for (final item in ['Write the release notes…', 'Explain what changed', 'Draft an announcement for the team', 'Compare with v1.8.0', 'Publish as the latest release']) {
      expect(_inMenu(item), findsOneWidget, reason: item);
    }
    await tester.tap(_inMenu('Write the release notes…'));
    await tester.pumpAndSettle();
    expect(find.byType(ReleaseNotesDialog), findsOneWidget);
    expect(find.text('previous release · suggested'), findsOneWidget);
    await tester.tap(find.text('Write the notes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();
    final update = find.textContaining('Update v1.9.0-rc.1');
    expect(update, findsOneWidget);
    await tester.tap(update);
    await tester.pumpAndSettle();
    expect(find.byType(ReleaseNotesDialog), findsNothing);
    expect(state.undo?.message, 'Updated the notes of v1.9.0-rc.1');
    state.dismissUndo();
    expect(tester.takeException(), isNull);
  });

  testWidgets('resolve comments: the agent’s changes and replies, then push and post', (tester) async {
    final state = await _pumpGit(tester);
    expect(find.byTooltip('4 open review threads · Resolve comments…'), findsOneWidget);
    await tester.tap(find.byTooltip('Actions for #521'));
    await tester.pump();
    await tester.tap(_inMenu('Resolve comments…'));
    await tester.pumpAndSettle();
    expect(find.byType(ResolveCommentsDialog), findsOneWidget);
    expect(find.text('4 OPEN THREADS'), findsOneWidget);
    expect(find.text('2 already resolved'), findsOneWidget);
    await tester.tap(find.text('Work on 4 threads'));
    for (var i = 0; i < 7; i++) {
      await tester.pump(const Duration(milliseconds: 700));
    }
    expect(find.text('Push 2 commits and post 4 replies'), findsOneWidget);
    expect(find.text('Commits the offset after the write'), findsOneWidget);
    await tester.tap(find.text('Push 2 commits and post 4 replies'));
    await tester.pumpAndSettle();
    expect(find.byType(ResolveCommentsDialog), findsNothing);
    expect(state.undo?.message, 'Pushed 2 commits, 4 replies, 4 resolved on #521');
    expect(find.byTooltip('Every review thread is resolved'), findsOneWidget);
    state.dismissUndo();
    expect(tester.takeException(), isNull);
  });
}
