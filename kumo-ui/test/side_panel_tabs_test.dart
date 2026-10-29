import 'package:flutter/material.dart';
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

Finder _inPanel(Finder f) => find.descendant(of: find.byType(SidePanel), matching: f);

void main() {
  testWidgets('the side panel switches between source control, files and widgets', (tester) async {
    final state = await _pump(tester);
    expect(state.sidePanelTab, SidePanelTab.widgets, reason: 'widgets by default');
    expect(_inPanel(find.text('Widgets')), findsOneWidget);

    await tester.tap(find.byTooltip('Source control'));
    await tester.pump();
    expect(_inPanel(find.byType(SourceControlPanel)), findsOneWidget);
    expect(_inPanel(find.text('Commit 2 staged')), findsOneWidget, reason: 'it says what the commit takes');
    expect(_inPanel(find.text('2 of 4 staged')), findsOneWidget);
    expect(_inPanel(find.text('COMMITTED ON BRANCH')), findsNothing, reason: 'compact: that lives in the Git tab');

    await tester.tap(_inPanel(find.byTooltip('Stage all')));
    await tester.pump();
    expect(_inPanel(find.text('Commit 4 staged')), findsOneWidget);

    await tester.tap(_inPanel(find.text('Open Git tab')));
    await tester.pump();
    expect(state.activeContext, ContextTab.git);

    await tester.tap(find.byTooltip('Files'));
    await tester.pump();
    expect(_inPanel(find.byType(WorktreeFilesTree)), findsOneWidget);
    await tester.tap(_inPanel(find.text('repository.go')).first);
    await tester.pump();
    expect(state.activeContext, ContextTab.files, reason: 'a file opens in the Files tab');
    expect(state.contextFile, 'internal/discount/repository.go');
    expect(tester.takeException(), isNull);
  });
}
