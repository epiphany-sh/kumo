import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/overlays/new_agent_dialog.dart';

Future<AppState> _files(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(demoWallpaper: true)..view = KumoView.files;
  await tester.pumpWidget(KumoApp(state: state));
  await tester.pump();
  return state;
}

void main() {
  testWidgets('New file asks for a path in the open file’s folder, creates it and opens it', (tester) async {
    await _files(tester);
    await tester.tap(find.byTooltip('New file'));
    await tester.pump();
    final start = tester.widget<TextField>(find.byKey(const ValueKey('new-path'))).controller!.text;
    expect(start, endsWith('/'), reason: 'starts in the open file’s folder');
    await tester.enterText(find.byKey(const ValueKey('new-path')), '${start}bulk_cache.go');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(find.text('bulk_cache.go'), findsWidgets, reason: 'the new file opens in a tab');
    expect(find.text('↩ creates it · Esc cancels'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('New folder explains the .gitkeep; an existing path is refused; Esc cancels', (tester) async {
    final state = await _files(tester);
    await tester.tap(find.byTooltip('New folder'));
    await tester.pump();
    expect(find.text('↩ creates it with a .gitkeep · Esc cancels'), findsOneWidget);
    await tester.tap(find.byTooltip('New file'));
    await tester.pump();
    final existing = state.changes.files.first;
    await tester.enterText(find.byKey(const ValueKey('new-path')), existing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('$existing already exists'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('$existing already exists'), findsNothing);
  });

  testWidgets('Ask agent about file opens New agent with the file in the prompt', (tester) async {
    await _files(tester);
    await tester.tap(find.text('Ask agent about file'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(NewAgentDialog), findsOneWidget);
    final prompt = find.byWidgetPredicate((w) => w is EditableText && w.controller.text.startsWith('About `'));
    expect(prompt, findsOneWidget);
  });
}
