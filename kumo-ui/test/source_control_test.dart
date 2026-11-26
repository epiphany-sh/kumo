import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/mock_project.dart';
import 'package:kumo_ui/data/pipelines_source.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/data/pull_requests_source.dart';
import 'package:kumo_ui/data/workspace_source.dart';
import 'package:kumo_ui/widgets/context_menu.dart';

/// The design's host, where no branch has a pull request yet.
class _NoPullRequests extends MockPullRequests {
  @override
  Future<BranchPullRequest> forBranch(String worktreePath, {bool refresh = false}) async => const BranchPullRequest(provider: CiProvider.githubActions);
}

/// The design's repositories, whose remote has release branches.
class _WithReleases extends MockWorkspaceSource {
  @override
  Future<RepoBranches?> branches(Repo repo) async =>
      const RepoBranches(current: 'main', local: ['main'], remote: ['origin/main', 'origin/release/0.9.0', 'origin/release/0.10.0', 'origin/release/0.8.3']);
}

/// What the app puts on the clipboard.
List<String> _clipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return copied;
}

/// The design's worktree with its Git tab open.
Future<AppState> _gitTab(WidgetTester tester, {PullRequestsSource? pullRequests, WorkspaceSource? workspace}) async {
  tester.view.physicalSize = const Size(1440, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(demoWallpaper: true, pullRequests: pullRequests, workspace: workspace);
  await tester.pumpWidget(KumoApp(state: state));
  await tester.pump();
  state.openContext(ContextTab.git);
  await tester.pump();
  return state;
}

/// Publishes the design's branch, and waits for its pull request.
Future<void> _publish(WidgetTester tester, AppState state) async {
  state.push();
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  expect(state.changes.pushed, isTrue);
}

/// [text] in the open menu.
Finder _inMenu(String text) => find.descendant(of: find.byType(KMenuPanel), matching: find.text(text));

void main() {
  testWidgets('source control: a pushed branch links to its open pull request', (tester) async {
    final state = await _gitTab(tester);
    final copied = _clipboard(tester);
    expect(state.branchLinks, isNull, reason: 'not published yet');
    expect(find.byTooltip('Open pull request #521 on GitHub'), findsNothing);

    await _publish(tester, state);
    expect(state.branchLinks?.primaryUrl, 'https://github.com/platform/repo-a/pull/521');
    expect(find.byTooltip('Open pull request #521 on GitHub'), findsOneWidget);
    expect(state.commitNotice, 'Pushed ${state.changes.branch}');
    expect(find.text('Open #521'), findsOneWidget, reason: 'the push notice links to it');

    await tester.tap(find.byTooltip('More source control actions'));
    await tester.pumpAndSettle();
    expect(_inMenu('Open pull request #521'), findsOneWidget);
    expect(_inMenu('Open branch on GitHub'), findsOneWidget);
    expect(_inMenu('Create pull request'), findsNothing);
    await tester.tap(_inMenu('Copy pull request link'));
    await tester.pumpAndSettle();
    expect(copied, ['https://github.com/platform/repo-a/pull/521']);
    expect(state.undo?.message, 'Copied the link to #521');
    await tester.pump(const Duration(seconds: 9));
    expect(tester.takeException(), isNull);
  });

  testWidgets('source control: a pushed branch without one offers to create its pull request', (tester) async {
    final state = await _gitTab(tester, pullRequests: _NoPullRequests());
    final copied = _clipboard(tester);
    await tester.tap(find.byTooltip('More source control actions'));
    await tester.pumpAndSettle();
    expect(_inMenu('Create pull request'), findsNothing, reason: 'nothing on the host before publishing');
    expect(_inMenu('Copy branch link'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await _publish(tester, state);
    expect(state.branchLinks?.primaryUrl, 'https://github.com/platform/repo-a/compare/main...feat/TSK-412-bulk-discounts?expand=1');
    expect(find.byTooltip('Create pull request on GitHub'), findsOneWidget);
    expect(find.text('Create PR'), findsOneWidget, reason: 'the push notice offers it');

    await tester.tap(find.byTooltip('More source control actions'));
    await tester.pumpAndSettle();
    expect(_inMenu('Create pull request'), findsOneWidget);
    expect(_inMenu('Open branch on GitHub'), findsOneWidget);
    await tester.tap(_inMenu('Copy branch link'));
    await tester.pumpAndSettle();
    expect(copied, ['https://github.com/platform/repo-a/tree/feat/TSK-412-bulk-discounts']);
    await tester.pump(const Duration(seconds: 9));
    expect(tester.takeException(), isNull);
  });

  testWidgets('source control: the pull request to create targets the open release branch', (tester) async {
    final state = await _gitTab(tester, pullRequests: _NoPullRequests(), workspace: _WithReleases());
    await _publish(tester, state);
    expect(state.branchLinks?.primaryUrl, 'https://github.com/platform/repo-a/compare/release/0.10.0...feat/TSK-412-bulk-discounts?expand=1');
    expect(tester.takeException(), isNull);
  });

  test('stage all, commit what is staged, then push: nothing left to undo', () async {
    final s = AppState();
    final git = s.changes;
    await git.resolveConflict(MockProject.conflictPath, 'current', MockProject.files[MockProject.conflictPath]!);
    git.stage([...git.unstagedChanges, ...git.untracked]);
    expect(git.unstagedChanges, isEmpty);
    expect(git.untracked, isEmpty);
    final staged = git.stagedList.length;

    expect(s.commit('   ', all: false), isFalse);
    expect(s.commit('chore: x', all: false), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(s.commitNotice, 'Committed $staged files as 3f9c2ab · not pushed yet');
    expect(s.canUndoCommit, isTrue);

    expect(s.canPush, isTrue);
    s.push();
    await Future<void>.delayed(Duration.zero);
    expect(s.commitNotice, 'Pushed ${git.branch}');
    expect(s.canUndoCommit, isFalse, reason: 'a pushed commit is not undone from here');
    expect(s.canPush, isFalse);
    s.dispose();
  });

  testWidgets('side panel: the branch is the real one, and after committing the button publishes it', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(demoWallpaper: true);
    await tester.pumpWidget(KumoApp(state: state));
    await tester.pump();
    // Source control lives in the worktree's Git tab.
    state.openContext(ContextTab.git);
    await tester.pump();
    expect(find.text('PR #521'), findsNothing);
    expect(find.text(state.changes.branch), findsWidgets);

    // Nothing staged: Commit takes every change.
    state.changes.unstage(List.of(state.changes.stagedList));
    await tester.pump();
    await tester.tap(find.byTooltip('Generate message from the changes'));
    await tester.pump();
    final field = find.byWidgetPredicate((w) => w is EditableText && w.controller.text.contains(' files'));
    final message = tester.widget<EditableText>(field).controller.text;
    expect(message, matches(RegExp(r'^(Add|Update|Delete|Rename) 4 files')));
    expect(message, isNot(contains('TSK-412')));

    await tester.tap(find.text('Commit').first);
    await tester.pump();
    expect(state.pendingChanges, isEmpty);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Publish branch'));
    await tester.pump();
    await tester.pump();
    expect(state.changes.pushed, isTrue);
    expect(state.commitNotice, 'Pushed ${state.changes.branch}');
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Nothing to commit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('side panel: each changed file can be staged, or discarded with an undo', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(demoWallpaper: true);
    await tester.pumpWidget(KumoApp(state: state));
    await tester.pump();
    // Source control lives in the worktree's Git tab.
    state.openContext(ContextTab.git);
    await tester.pump();
    const path = 'internal/kafka/bulk_consumer.go';
    // Hover highlights only show in mouse mode, which a test doesn't start in.
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    Future<void> hover() async {
      await mouse.moveTo(tester.getCenter(find.byTooltip(path).last));
      await tester.pump();
    }

    expect(state.changes.stagedList, isNot(contains(path)));
    await hover();
    await tester.tap(find.byTooltip('Stage bulk_consumer.go'));
    await tester.pump();
    expect(state.changes.stagedList, contains(path));
    expect(find.text('STAGED'), findsOneWidget);

    await hover();
    await tester.tap(find.byTooltip('Discard changes to bulk_consumer.go'));
    await tester.pump();
    expect(state.pendingChanges.map((f) => f.path), isNot(contains(path)), reason: 'hidden during the undo window');
    expect(find.byTooltip(path), findsNothing, reason: 'gone from the Git tab and from the Changes widget');
    expect(state.undo?.message, 'Discarded changes to bulk_consumer.go');

    state.undoLast();
    await tester.pump();
    expect(state.pendingChanges.map((f) => f.path), contains(path));
    expect(tester.takeException(), isNull);
  });
}
