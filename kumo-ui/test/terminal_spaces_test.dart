import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';

void main() {
  testWidgets('each worktree has its own terminals; opening one goes to them', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(demoWallpaper: true);
    await tester.pumpWidget(KumoApp(state: state));
    await tester.pump();
    final repo = state.workspace.repos.first;
    final first = repo.worktrees.firstWhere(state.isActiveWorktree);
    final other = repo.worktrees.firstWhere((w) => !state.isActiveWorktree(w));
    expect(find.text('claude · PRC-412'), findsOneWidget);

    // Opening another worktree, from any view, shows its (empty) terminals.
    state.view = KumoView.tasks;
    await tester.pump();
    state.openWorktree(other);
    await tester.pump();
    expect(state.view, KumoView.terminal);
    expect(find.text('claude · PRC-412'), findsNothing);
    expect(find.text('No terminals open in this worktree'), findsOneWidget);

    await tester.tap(find.text('New tab'));
    await tester.pump();
    expect(find.text('No terminals open in this worktree'), findsNothing);
    expect(find.text('1 tab · 1 pane'), findsOneWidget);

    // The first worktree's terminals were kept as they were.
    state.openWorktree(first);
    await tester.pump();
    expect(find.text('claude · PRC-412'), findsOneWidget);
    expect(find.text('1 tab · 3 panes'), findsOneWidget);

    state.openWorktree(other);
    await tester.pump();
    expect(find.text('1 tab · 1 pane'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing a worktree from the app closes its terminals, once git removed it', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The mock workspace keeps the worktree after `git worktree remove`, so
    // it can be opened again to look at its terminals.
    final state = AppState(demoWallpaper: true);
    await tester.pumpWidget(KumoApp(state: state));
    await tester.pump();
    final repo = state.workspace.repos.first;
    final first = repo.worktrees.firstWhere(state.isActiveWorktree);
    final other = repo.worktrees.firstWhere((w) => !state.isActiveWorktree(w) && !w.isMain);

    state.openWorktree(other);
    await tester.pump();
    await tester.tap(find.text('New tab'));
    await tester.pump();
    expect(find.text('1 tab · 1 pane'), findsOneWidget);
    state.openWorktree(first);
    await tester.pump();

    // Undone: nothing closes.
    state.deleteWorktree(repo.id, other.branch);
    state.undoLast();
    await tester.pump();
    state.openWorktree(other);
    await tester.pump();
    expect(find.text('1 tab · 1 pane'), findsOneWidget);

    state.deleteWorktree(repo.id, other.branch);
    state.dismissUndo(); // what the toast's timer does: git removes it
    await tester.pump();
    await tester.pump();
    state.openWorktree(other);
    await tester.pump();
    expect(find.text('No terminals open in this worktree'), findsOneWidget);

    // The other worktrees keep theirs.
    state.openWorktree(first);
    await tester.pump();
    expect(find.text('claude · PRC-412'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
