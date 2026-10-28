import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/editor/file_view.dart';
import 'package:kumo_ui/overlays/namespace_dialog.dart';
import 'package:kumo_ui/overlays/settings_dialog.dart';
import 'package:kumo_ui/shell/side_panel.dart';
import 'package:kumo_ui/theme/palette.dart';

void main() {
  Future<AppState> pumpApp(WidgetTester tester, {KumoThemeMode mode = KumoThemeMode.dark}) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(mode: mode, demoWallpaper: true);
    await tester.pumpWidget(KumoApp(state: state));
    await tester.pump();
    return state;
  }

  testWidgets('boots on the terminal view and switches views', (tester) async {
    final state = await pumpApp(tester);
    expect(find.text('Claude Code'), findsWidgets);
    for (final v in KumoView.values) {
      state.view = v;
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'view ${v.name}');
    }
  });

  testWidgets('new namespace from the sidebar shows up with its repo', (tester) async {
    final state = await pumpApp(tester);
    await tester.tap(find.byTooltip('New namespace'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Create namespace'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(NamespaceDialog), matching: find.byType(TextField)).first, 'catalog');
    await tester.tap(find.text('catalog/catalog-api'));
    await tester.pump();
    await tester.tap(find.text('Create namespace'));
    await tester.pump();
    expect(find.text('Namespace created'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NamespaceDialog), findsNothing);
    expect(state.namespaces.last.name, 'catalog');
    expect(state.namespaces.last.repos, ['catalog-api']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('+ opens a new tab; splits stay inside the tab', (tester) async {
    await pumpApp(tester);
    expect(find.text('zsh'), findsNothing);
    await tester.tap(find.byTooltip('New tab (⌘T)'));
    await tester.pump();
    expect(find.text('zsh'), findsWidgets);
    // The new tab shows only its own shell, not the agent panes.
    expect(find.text('gotestsum'), findsNothing);
    await tester.tap(find.byTooltip('Split right (⌘D)').first);
    await tester.pump();
    expect(find.text('zsh 2'), findsWidgets, reason: 'the split pane, inside the same tab');
    expect(find.byTooltip('Close tab zsh 2'), findsOneWidget, reason: 'still one tab, titled by its focused pane');
    await tester.tap(find.byTooltip('Close tab zsh 2'));
    await tester.pump();
    await tester.pump();
    expect(find.text('zsh'), findsNothing);
    expect(find.text('gotestsum'), findsWidgets, reason: 'back on the first tab');
    expect(tester.takeException(), isNull);
  });

  testWidgets('⌘T opens a new terminal tab, even from another view', (tester) async {
    final state = await pumpApp(tester);
    state.view = KumoView.git;
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(state.view, KumoView.terminal);
    expect(find.byTooltip('Close tab zsh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source control: open a changed file, commit, close the tab', (tester) async {
    final state = await pumpApp(tester);
    expect(find.byType(SidePanel), findsOneWidget);
    // Source control lives in the worktree's Git tab (header icons).
    await tester.tap(find.byTooltip(ContextTab.git.tooltip));
    await tester.pump();
    expect(find.byType(SourceControlPanel), findsOneWidget);
    await tester.tap(find.byTooltip('internal/discount/repository.go').last);
    await tester.pump();
    expect(find.byType(FileView), findsOneWidget);
    expect(state.activeFile, 'internal/discount/repository.go');
    expect(state.activeContext, isNull, reason: 'a file tab shows instead');
    await tester.tap(find.byTooltip(ContextTab.git.tooltip));
    await tester.pump();
    // Nothing staged: Commit takes every change.
    state.changes.unstage(List.of(state.changes.stagedList));
    await tester.pump();
    await tester.tap(find.byTooltip('Generate message from the changes'));
    await tester.pump();
    await tester.tap(find.text('Commit').first);
    await tester.pump();
    expect(state.pendingChanges, isEmpty);
    expect(state.commitNotice, startsWith('Committed 4 files'));
    await tester.tap(find.byTooltip('Close repository.go (⌘W)'));
    await tester.pump();
    expect(find.byType(FileView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('side panel shows the widgets; the Files tab shows the tree', (tester) async {
    final state = await pumpApp(tester);
    expect(find.text('Bulk discounts by category'), findsWidgets);
    await tester.tap(find.byTooltip(ContextTab.files.tooltip));
    await tester.pump();
    expect(find.byType(WorktreeFilesTree), findsOneWidget);
    expect(find.text('No file open'), findsOneWidget);
    await tester.tap(find.text('bulk.go').first);
    await tester.pump();
    expect(state.contextFile, 'internal/discount/bulk.go');
    expect(find.byType(FileView), findsOneWidget);
    state.toggleSidePanel();
    await tester.pump();
    expect(find.byType(SidePanel), findsNothing);
    await tester.tap(find.byTooltip('Show side panel (⌥⌘B)'));
    await tester.pump();
    expect(find.byType(SidePanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings: side panel position moves the panel to the right', (tester) async {
    final state = await pumpApp(tester);
    await tester.tap(find.byTooltip('Settings (⌘,)'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SettingsDialog), findsOneWidget);
    expect(find.text('Side panel position'), findsOneWidget);
    await tester.tap(find.text('Right'));
    await tester.pump();
    expect(state.sidePanelRight, isTrue);
    await tester.tap(find.text('AI agents'));
    await tester.pump();
    expect(find.text('Claude Code'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SettingsDialog), findsNothing);
    final panel = tester.getTopLeft(find.byType(SidePanel));
    expect(panel.dx, greaterThan(700), reason: 'panel renders to the right of the terminal');
    expect(tester.takeException(), isNull);
  });

  testWidgets('all three themes render', (tester) async {
    final state = await pumpApp(tester);
    for (final m in KumoThemeMode.values) {
      state.mode = m;
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'theme ${m.name}');
    }
  });
}
