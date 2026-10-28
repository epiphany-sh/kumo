import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/mock_project.dart';

void main() {
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
    expect(message, isNot(contains('PRC-412')));

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
