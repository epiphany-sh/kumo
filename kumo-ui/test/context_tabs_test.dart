import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/shell/side_panel.dart';

Future<AppState> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(demoWallpaper: true);
  await tester.pumpWidget(KumoApp(state: state));
  await tester.pump();
  return state;
}

void main() {
  test('Files is not in the side-nav, and ⌘1…⌘5 follow the nav', () {
    expect(KumoView.nav, [KumoView.terminal, KumoView.agents, KumoView.tasks, KumoView.git, KumoView.docs]);
    expect(KumoView.nav.map((v) => v.shortcut), ['⌘1', '⌘2', '⌘3', '⌘4', '⌘5']);
  });

  test('context tabs: open, go to a file tab and back, close', () {
    final s = AppState();
    s.openContext(ContextTab.git);
    expect(s.contextTabs, [ContextTab.git]);
    expect(s.activeContext, ContextTab.git);
    s.openFile('internal/discount/bulk.go');
    expect(s.activeContext, isNull);
    expect(s.activeFile, 'internal/discount/bulk.go');
    s.openContext(ContextTab.files);
    expect(s.activeFile, isNull, reason: 'the context tab shows instead');
    expect(s.contextTabs, [ContextTab.git, ContextTab.files]);
    s.showTerminals();
    expect(s.activeContext, isNull);
    expect(s.activeFile, isNull);
    s.closeContext(ContextTab.git);
    expect(s.contextTabs, [ContextTab.files]);
    // Home has no context tabs; a worktree brings them back.
    s.showHome();
    expect(s.inHome, isTrue);
    expect(s.contextTabs, isEmpty);
    s.selectWorktree(s.activeWorktree, path: s.activeWorktreePath);
    expect(s.inHome, isFalse);
    expect(s.contextTabs, [ContextTab.files]);
    s.dispose();
  });

  testWidgets('header icons open the Files and Git tabs; ⌘W closes them', (tester) async {
    final state = await _pump(tester);
    await tester.tap(find.byTooltip(ContextTab.files.tooltip));
    await tester.pump();
    expect(find.byType(WorktreeFilesTree), findsOneWidget);
    expect(find.text('Files · PRC-412'), findsOneWidget);

    await tester.tap(find.byTooltip(ContextTab.git.tooltip));
    await tester.pump();
    expect(find.byType(SourceControlPanel), findsOneWidget);
    expect(find.text('Commits on this branch'), findsOneWidget);
    expect(find.text('Git · PRC-412'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(state.contextTabs, [ContextTab.files]);
    expect(find.byType(SourceControlPanel), findsNothing);

    await tester.tap(find.byTooltip('Terminal of this worktree'));
    await tester.pump();
    expect(state.activeContext, isNull);
    expect(find.text('Claude Code'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Terminal in the side-nav opens Home: a shell in ~, no widgets', (tester) async {
    final state = await _pump(tester);
    await tester.tap(find.byTooltip('Terminal in ~, not tied to a repository  ⌘1'));
    await tester.pump();
    expect(state.inHome, isTrue);
    expect(find.text('Home'), findsWidgets);
    expect(find.byType(SidePanel), findsNothing);
    expect(find.byTooltip(ContextTab.files.tooltip), findsNothing);
    expect(find.byTooltip('Close tab zsh'), findsOneWidget, reason: 'Home starts with one shell');
    expect(find.text('Claude Code'), findsNothing, reason: 'the worktree’s terminals stay in its space');

    // A worktree in the sidebar takes you back to its context.
    await tester.tap(find.text('feat/PRC-412-bulk-discounts').first);
    await tester.pump();
    expect(state.inHome, isFalse);
    expect(find.byType(SidePanel), findsOneWidget);
    expect(find.text('Claude Code'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
