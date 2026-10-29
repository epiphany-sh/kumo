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

  testWidgets('Files tab: each file opened from the tree gets a tab; ⌘W closes it', (tester) async {
    final state = await _pump(tester);
    await tester.tap(find.byTooltip(ContextTab.files.tooltip));
    await tester.pump();
    await tester.tap(find.text('bulk.go').first);
    await tester.pump();
    await tester.tap(find.text('repository.go').first);
    await tester.pump();
    expect(state.contextFiles, ['internal/discount/bulk.go', 'internal/discount/repository.go']);
    expect(state.contextFile, 'internal/discount/repository.go');
    expect(find.byTooltip('Close bulk.go (⌘W)'), findsOneWidget);
    // Back to the first file through its tab.
    await tester.tap(find.byTooltip('internal/discount/bulk.go').last);
    await tester.pump();
    expect(state.contextFile, 'internal/discount/bulk.go');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(state.contextFiles, ['internal/discount/repository.go']);
    expect(state.contextFile, 'internal/discount/repository.go');
    expect(state.activeContext, ContextTab.files, reason: 'the Files tab stays while it has files');
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

  test('Files tab: close others keeps the file showing; close all empties it', () {
    final s = AppState();
    for (final p in ['go.mod', 'internal/discount/bulk.go', 'internal/http/routes.go']) {
      s.showContextFile(p);
    }
    s.showContextFile('internal/discount/bulk.go');
    s.closeOtherContextFiles();
    expect(s.contextFiles, ['internal/discount/bulk.go']);
    expect(s.contextFile, 'internal/discount/bulk.go');
    s.closeAllContextFiles();
    expect(s.contextFiles, isEmpty);
    expect(s.contextFile, isNull);
    s.dispose();
  });

  testWidgets('Files tab with many files: the strip scrolls, “N open” lists them all and closes others', (tester) async {
    final state = await _pump(tester);
    await tester.tap(find.byTooltip(ContextTab.files.tooltip));
    await tester.pump();
    const many = [
      'cmd/price-admin/main.go', 'config/app.yaml', 'deploy/k8s/values.yaml', 'go.mod',
      'internal/discount/bulk.go', 'internal/discount/bulk_test.go', 'internal/discount/discount.go',
      'internal/discount/legacy_v1.go', 'internal/discount/repository.go', 'internal/discount/service.go',
      'internal/http/handler.go', 'internal/http/routes.go', 'internal/kafka/bulk_consumer.go',
      'migrations/0042_discount_category.sql',
    ];
    for (final p in many) {
      state.showContextFile(p);
    }
    await tester.pump();
    // The scroll animation starts on the frame after the one that asked
    // for it: one frame to start, one to finish.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('14 open'), findsOneWidget);
    // The last file opened is the one showing, and its tab was scrolled into view.
    final strip = tester.widget<SingleChildScrollView>(
      find.ancestor(of: find.byTooltip('Close 0042_discount_category.sql (⌘W)'), matching: find.byType(SingleChildScrollView)).first,
    );
    expect(strip.controller!.offset, greaterThan(0));

    await tester.tap(find.text('14 open'));
    await tester.pump();
    expect(find.text('Close others'), findsOneWidget);
    expect(find.text('Close all'), findsOneWidget);
    await tester.tap(find.text('Close others'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.contextFiles, ['migrations/0042_discount_category.sql']);
    expect(find.text('1 open'), findsOneWidget);
    expect(find.text('Close others'), findsNothing, reason: 'the menu closed');
    expect(tester.takeException(), isNull);
  });
}
