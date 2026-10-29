import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/editor/code_editor.dart';
import 'package:kumo_ui/widgets/change_scrollbar.dart';

const _repo = 'internal/discount/repository.go';

/// The app with the worktree's Files tab open.
Future<AppState> _filesTab(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(demoWallpaper: true);
  await tester.pumpWidget(KumoApp(state: state));
  await tester.pump();
  await tester.tap(find.byTooltip(ContextTab.files.tooltip));
  await tester.pump();
  return state;
}

Future<void> _pumpAsync(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Future<void> _rightClick(WidgetTester tester, Finder f) async {
  await tester.tap(f, buttons: kSecondaryButton);
  await tester.pump();
}

void main() {
  test('rows of the same color make one tick, placed as fractions of the content', () {
    final ticks = changeTicks([10, 10, 10, 10], [null, Colors.green, Colors.green, Colors.red], top: 10, bottom: 10);
    expect(ticks, [const ChangeTick(20 / 60, 40 / 60, Colors.green), const ChangeTick(40 / 60, 50 / 60, Colors.red)]);
  });

  test('rename moves the tabs; delete hides, Undo brings back, and the window closing deletes', () async {
    final s = AppState();
    s.showContextFile(_repo);
    s.showContextFile('internal/discount/bulk.go');
    expect(await s.movePath(_repo, 'internal/discount/repo.go'), isNull);
    expect(s.contextFiles, ['internal/discount/repo.go', 'internal/discount/bulk.go']);
    expect(s.changes.files, contains('internal/discount/repo.go'));
    expect(s.changes.files, isNot(contains(_repo)));
    expect(await s.movePath('internal/discount/repo.go', 'internal/discount/bulk.go'), 'internal/discount/bulk.go already exists');
    expect(await s.movePath('internal', 'internal/inner'), contains('inside itself'));

    s.deletePath('internal/discount');
    expect(s.visibleFiles.where((f) => f.startsWith('internal/discount/')), isEmpty);
    expect(s.contextFiles, isEmpty, reason: 'its tabs close');
    expect(s.undo?.message, 'Deleted discount');
    s.undoLast();
    expect(s.visibleFiles, contains('internal/discount/bulk.go'));
    expect(s.contextFiles, ['internal/discount/repo.go', 'internal/discount/bulk.go']);

    s.deletePath('internal/discount/bulk.go');
    s.dismissUndo();
    await Future<void>.delayed(Duration.zero);
    expect(s.changes.files, isNot(contains('internal/discount/bulk.go')));
    expect(s.isDeleting('internal/discount/bulk.go'), isFalse);
    s.dispose();
  });

  test('new files are refused where something exists; a folder’s changes discard together', () async {
    final s = AppState();
    expect(await s.createFile(_repo), '$_repo already exists');
    expect(await s.createFile('/internal//cache/lru.go/'), isNull);
    expect(s.changes.files, contains('internal/cache/lru.go'));
    final before = s.pendingChanges.where((f) => f.path.startsWith('internal/discount/')).length;
    expect(before, greaterThan(1));
    s.discardChangesIn('internal/discount');
    expect(s.pendingChanges.where((f) => f.path.startsWith('internal/discount/')), isEmpty);
    expect(s.undo?.message, 'Discarded $before changes in discount');
    s.dispose();
  });

  testWidgets('a file in the Files tab is editable; ⌘S saves it', (tester) async {
    final state = await _filesTab(tester);
    await tester.tap(find.text('repository.go').first);
    await _pumpAsync(tester);
    expect(find.byType(CodeEditor), findsOneWidget, reason: 'the Files tab opens files in Edit');
    expect(find.byType(ChangeScrollbar), findsOneWidget);
    final bar = tester.widget<ChangeScrollbar>(find.byType(ChangeScrollbar));
    expect(bar.ticks, isNotEmpty, reason: 'the scrollbar maps the changed lines');

    final field = find.descendant(of: find.byType(CodeEditor), matching: find.byType(TextField));
    await tester.enterText(field, 'package discount\n// edited\n');
    await tester.pump();
    expect(state.buffers.isDirty(_repo), isTrue);
    expect(find.text('Save'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await _pumpAsync(tester);
    expect(state.buffers.isDirty(_repo), isFalse);
    expect(await state.changes.read(_repo), 'package discount\n// edited\n');
    expect(find.text('Save'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing a tab with unsaved edits asks first', (tester) async {
    final state = await _filesTab(tester);
    await tester.tap(find.text('repository.go').first);
    await _pumpAsync(tester);
    await tester.enterText(find.descendant(of: find.byType(CodeEditor), matching: find.byType(TextField)), 'draft');
    await tester.pump();
    await tester.tap(find.byTooltip('Close repository.go, unsaved changes (⌘W)'));
    await tester.pump();
    expect(find.text('repository.go has unsaved changes. Save them before closing?'), findsOneWidget);
    expect(state.contextFiles, [_repo], reason: 'still open');
    await tester.tap(find.text('Don’t save'));
    await _pumpAsync(tester);
    expect(state.contextFiles, isEmpty);
    expect(await state.changes.read(_repo), isNot('draft'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('right-click a file: rename it in place; its tab follows', (tester) async {
    final state = await _filesTab(tester);
    await tester.tap(find.text('repository.go').first);
    await _pumpAsync(tester);
    await _rightClick(tester, find.text('repository.go').first);
    for (final item in ['Open', 'Rename…', 'Discard changes', 'Copy path', 'Delete']) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
    await tester.tap(find.text('Rename…'));
    await tester.pump();
    await tester.pump();
    final name = tester.widget<TextField>(find.byKey(const ValueKey('tree-name')));
    expect(name.controller!.text, 'repository.go');
    expect(name.controller!.selection.textInside(name.controller!.text), 'repository', reason: 'the extension stays');
    await tester.enterText(find.byKey(const ValueKey('tree-name')), 'store.go');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _pumpAsync(tester);
    expect(state.contextFiles, ['internal/discount/store.go']);
    expect(find.text('store.go'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right-click a folder: new file inside it, then delete the folder with undo', (tester) async {
    final state = await _filesTab(tester);
    await _rightClick(tester, find.text('discount').first);
    expect(find.text('New file…'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Discard \d+ changes$')), findsOneWidget);
    expect(find.text('Delete folder'), findsOneWidget);
    await tester.tap(find.text('New file…'));
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('tree-name')), 'cache.go');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _pumpAsync(tester);
    expect(state.changes.files, contains('internal/discount/cache.go'));
    expect(state.contextFile, 'internal/discount/cache.go', reason: 'the new file opens');

    await _rightClick(tester, find.text('discount').first);
    await tester.tap(find.text('Delete folder'));
    await tester.pump();
    expect(find.text('cache.go'), findsNothing);
    expect(state.undo?.message, 'Deleted discount');
    state.undoLast();
    await tester.pump();
    expect(find.text('repository.go'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
