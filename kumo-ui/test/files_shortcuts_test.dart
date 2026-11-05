import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/editor/code_editor.dart';
import 'package:kumo_ui/editor/find.dart';
import 'package:kumo_ui/editor/markdown_preview.dart';
import 'package:kumo_ui/editor/quick_open.dart';

const _repo = 'internal/discount/repository.go';
const _bulk = 'internal/discount/bulk.go';
final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

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

/// ⌘ + [key] (with ⇧ / ⌥ when asked).
Future<void> _cmd(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false, bool alt = false}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await _pumpAsync(tester);
}

/// A click with the mouse (a text field lets go of the focus on one
/// outside it, on desktop).
Future<void> _click(WidgetTester tester, Finder f) async {
  await tester.tap(f, kind: PointerDeviceKind.mouse);
  await _pumpAsync(tester);
}

EditableTextState _editor(WidgetTester tester) => tester.state<EditableTextState>(find.descendant(of: find.byType(CodeEditor), matching: find.byType(EditableText)));

Future<void> _open(WidgetTester tester, String name) => _click(tester, find.text(name).first);

void main() {
  group('shortcuts', () {
    testWidgets('⌘W closes the file even after a click outside the editor dropped its focus', (tester) async {
      final state = await _filesTab(tester);
      await _open(tester, 'repository.go');
      await _open(tester, 'bulk.go');
      _editor(tester).widget.focusNode.requestFocus();
      await _pumpAsync(tester);
      // A click in the tree: the editor's text field unfocuses (to the
      // nearest scope). The window's shortcuts must still be above it.
      await _click(tester, find.text('kafka').first);
      expect(_editor(tester).widget.focusNode.hasFocus, isFalse);
      await _cmd(tester, LogicalKeyboardKey.keyW);
      expect(state.contextFiles, [_repo], reason: '⌘W closed bulk.go');
      await _cmd(tester, LogicalKeyboardKey.digit1);
      expect(state.activeContext, isNull, reason: '⌘1 still goes to the terminals');
      expect(tester.takeException(), isNull);
    }, variant: _mac);

    testWidgets('⌘S saves and ⇧⌘] / ⇧⌘[ move between tabs without the editor focused', (tester) async {
      final state = await _filesTab(tester);
      await _open(tester, 'repository.go');
      await _open(tester, 'bulk.go');
      await tester.enterText(find.descendant(of: find.byType(CodeEditor), matching: find.byType(TextField)), 'package discount // draft\n');
      await _pumpAsync(tester);
      await _click(tester, find.text('kafka').first);
      await _cmd(tester, LogicalKeyboardKey.keyS);
      expect(state.buffers.isDirty(_bulk), isFalse);
      expect(await state.changes.read(_bulk), 'package discount // draft\n');

      await _cmd(tester, LogicalKeyboardKey.bracketLeft, shift: true);
      expect(state.contextFile, _repo);
      await _cmd(tester, LogicalKeyboardKey.bracketLeft, shift: true);
      expect(state.contextFile, _bulk, reason: 'it wraps around');
      await _cmd(tester, LogicalKeyboardKey.bracketRight, shift: true);
      expect(state.contextFile, _repo);
      expect(tester.takeException(), isNull);
    }, variant: _mac);

    testWidgets('in the full editor ⌘S saves and ⌘W closes its tab', (tester) async {
      final state = await _filesTab(tester);
      state.editFile(_bulk);
      await _pumpAsync(tester);
      expect(state.view, KumoView.files);
      final field = find.descendant(of: find.byType(CodeEditor), matching: find.byType(TextField));
      await tester.enterText(field, 'package discount\n// full editor\n');
      await _pumpAsync(tester);
      await _cmd(tester, LogicalKeyboardKey.keyS);
      expect(await state.changes.read(_bulk), 'package discount\n// full editor\n');
      await _cmd(tester, LogicalKeyboardKey.keyW);
      expect(find.byKey(const ValueKey(_bulk)), findsNothing, reason: 'its editor closed');
      expect(state.view, KumoView.files, reason: 'the Terminal view had nothing to do with it');
      expect(tester.takeException(), isNull);
    }, variant: _mac);

    testWidgets('⌘A, ⌘X, ⌘V and ⌘Z edit the code', (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        if (call.method == 'Clipboard.hasStrings') return {'value': clipboard != null};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final state = await _filesTab(tester);
      await _open(tester, 'bulk.go');
      final ctrl = state.buffers.of(_bulk);
      final original = ctrl.text;
      _editor(tester).widget.focusNode.requestFocus();
      await _pumpAsync(tester);
      // Undo keeps one step per pause in the typing: wait between edits.
      const pause = Duration(seconds: 1);
      await _cmd(tester, LogicalKeyboardKey.keyA);
      expect(ctrl.selection.textInside(ctrl.text), original);
      await _cmd(tester, LogicalKeyboardKey.keyX);
      expect(clipboard, original);
      expect(ctrl.text, isEmpty);
      await tester.pump(pause);
      await _cmd(tester, LogicalKeyboardKey.keyV);
      expect(ctrl.text, original);
      await tester.pump(pause);
      await _cmd(tester, LogicalKeyboardKey.keyV);
      expect(ctrl.text, '$original$original');
      await tester.pump(pause);
      await _cmd(tester, LogicalKeyboardKey.keyZ);
      expect(ctrl.text, original, reason: '⌘Z undid the second paste');
      await tester.pump(pause);
      await _cmd(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(ctrl.text, '$original$original', reason: '⇧⌘Z redid it');
      expect(tester.takeException(), isNull);
    }, variant: _mac);
  });

  group('find', () {
    testWidgets('⌘F finds in the file; ↵ steps through; ⌥⌘F replaces all', (tester) async {
      final state = await _filesTab(tester);
      await _open(tester, 'repository.go');
      await _click(tester, find.text('kafka').first);
      await _cmd(tester, LogicalKeyboardKey.keyF);
      expect(find.byType(FindBar), findsOneWidget);
      final ctrl = state.buffers.of(_repo);
      final count = 'ctx'.allMatches(ctrl.text).length;
      expect(count, greaterThan(1));
      await tester.enterText(find.byKey(const ValueKey('find-query')), 'ctx');
      await _pumpAsync(tester);
      expect(find.text('1 of $count'), findsOneWidget);
      expect(ctrl.highlights, hasLength(count), reason: 'every match is painted');
      expect(ctrl.selection.textInside(ctrl.text), 'ctx');
      final first = ctrl.selection.start;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _pumpAsync(tester);
      expect(find.text('2 of $count'), findsOneWidget);
      expect(ctrl.selection.start, greaterThan(first));
      await _cmd(tester, LogicalKeyboardKey.keyG, shift: true);
      expect(find.text('1 of $count'), findsOneWidget);

      await _cmd(tester, LogicalKeyboardKey.keyF, alt: true);
      await tester.enterText(find.byKey(const ValueKey('find-replacement')), 'c');
      await tester.tap(find.text('All'));
      await _pumpAsync(tester);
      expect('ctx'.allMatches(ctrl.text), isEmpty);
      expect(state.buffers.isDirty(_repo), isTrue);
      expect(find.text('No results'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _pumpAsync(tester);
      expect(find.byType(FindBar), findsNothing);
      expect(ctrl.highlights, isEmpty);
      expect(tester.takeException(), isNull);
    }, variant: _mac);

    testWidgets('in the full editor the find bar stays open across tabs and searches the one showing', (tester) async {
      final state = await _filesTab(tester);
      state.editFile(_repo);
      await _pumpAsync(tester);
      await _cmd(tester, LogicalKeyboardKey.keyF);
      await tester.enterText(find.byKey(const ValueKey('find-query')), 'func');
      await _pumpAsync(tester);
      expect(find.textContaining(RegExp(r'^1 of \d+$')), findsOneWidget);
      await _cmd(tester, LogicalKeyboardKey.bracketRight, shift: true);
      await _cmd(tester, LogicalKeyboardKey.bracketRight, shift: true);
      expect(find.byType(FindBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: _mac);
  });

  group('comments', () {
    testWidgets('⌘/ comments the selected lines out and back; ⌘Z undoes it', (tester) async {
      final state = await _filesTab(tester);
      await _open(tester, 'bulk.go');
      final ctrl = state.buffers.of(_bulk);
      final original = ctrl.text;
      _editor(tester).widget.focusNode.requestFocus();
      await _pumpAsync(tester);
      final second = original.indexOf('\n') + 1;
      ctrl.selection = TextSelection(baseOffset: 0, extentOffset: second + 1);
      await tester.pump(const Duration(seconds: 1));
      await _cmd(tester, LogicalKeyboardKey.slash);
      final lines = ctrl.text.split('\n');
      expect(lines[0], startsWith('// '));
      expect(lines[1].isEmpty || lines[1].trimLeft().startsWith('// '), isTrue);
      expect(lines.skip(2).join('\n'), original.split('\n').skip(2).join('\n'), reason: 'only the selected lines');
      await tester.pump(const Duration(seconds: 1));
      await _cmd(tester, LogicalKeyboardKey.slash);
      expect(ctrl.text, original);

      // A Spanish keyboard: / is Shift+7; the key event carries "/".
      await tester.pump(const Duration(seconds: 1));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit7, character: '/');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit7);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await _pumpAsync(tester);
      expect(ctrl.text, startsWith('// '));
      await tester.pump(const Duration(seconds: 1));
      await _cmd(tester, LogicalKeyboardKey.keyZ);
      expect(ctrl.text, original, reason: 'one ⌘Z takes it back');
      expect(tester.takeException(), isNull);
    }, variant: _mac);
  });

  group('go to file', () {
    testWidgets('⌘P finds a file by a few letters and opens it in the Files tab', (tester) async {
      final state = await _filesTab(tester);
      await _cmd(tester, LogicalKeyboardKey.digit1);
      expect(state.activeContext, isNull);
      await _cmd(tester, LogicalKeyboardKey.keyP);
      expect(find.byType(QuickOpen), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('quick-open')), 'kfkbulk');
      await _pumpAsync(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(QuickOpen), findsNothing);
      expect(state.activeContext, ContextTab.files);
      expect(state.contextFile, 'internal/kafka/bulk_consumer.go');
      expect(tester.takeException(), isNull);
    }, variant: _mac);
  });

  group('markdown', () {
    testWidgets('a .md file opens as a preview; ⇧⌘V shows its code; ⌘F finds in it', (tester) async {
      final state = await _filesTab(tester);
      await _open(tester, 'README.md');
      expect(find.byType(MarkdownPreview), findsOneWidget);
      expect(find.byType(CodeEditor), findsNothing);
      expect(find.text('Run locally'), findsOneWidget, reason: 'a heading, rendered');
      expect(find.textContaining('# price-admin'), findsNothing, reason: 'no Markdown syntax showing');

      await _cmd(tester, LogicalKeyboardKey.keyV, shift: true);
      expect(find.byType(CodeEditor), findsOneWidget);
      await _cmd(tester, LogicalKeyboardKey.keyV, shift: true);
      expect(find.byType(MarkdownPreview), findsOneWidget);

      // Edits not saved yet show in the preview.
      state.buffers.of('README.md').text = '# Changed title\n\nBody.';
      await _pumpAsync(tester);
      expect(find.text('Changed title'), findsOneWidget);

      await _cmd(tester, LogicalKeyboardKey.keyF);
      expect(find.byType(CodeEditor), findsOneWidget, reason: 'find works on the code');
      expect(find.byType(FindBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: _mac);
  });
}
