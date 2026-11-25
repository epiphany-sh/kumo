import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/platform/os/host_os.dart';
import 'package:kumo_ui/platform/os/linux.dart';
import 'package:kumo_ui/platform/os/macos.dart';
import 'package:kumo_ui/platform/os/windows.dart';
import 'package:kumo_ui/terminal/ansi_screen.dart';
import 'package:kumo_ui/terminal/terminal_surface.dart';
import 'package:kumo_ui/terminal/terminal_text_input.dart';
import 'package:kumo_ui/terminal/terminal_view.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';

/// An interactive surface backed by the real parser, recording input.
class _FakeShell implements TerminalModes, ShellProgram {
  _FakeShell() {
    _screen.feed(utf8.encode('~ ❯ '));
    _buffer.value = _screen.snapshot();
  }

  final _screen = AnsiScreen(cols: 40, rows: 10);
  final _buffer = ValueNotifier(const TermBuffer([]));
  final sent = <List<int>>[];

  @override
  String get program => 'zsh';
  @override
  String get title => 'zsh';
  @override
  String get cwd => '~';
  @override
  ValueListenable<TermBuffer> get buffer => _buffer;
  @override
  bool get interactive => true;
  @override
  void sendText(String text) => sendBytes(utf8.encode('$text\r'));
  @override
  void sendBytes(List<int> bytes) => sent.add(bytes);
  @override
  void resize(int cols, int rows) {}
  @override
  void dispose() => _buffer.dispose();

  @override
  bool get applicationCursorKeys => _screen.applicationCursorKeys;
  @override
  bool get bracketedPaste => _screen.bracketedPaste;
  @override
  bool get mouseTracking => _screen.mouseTracking;
  @override
  bool get mouseDrags => _screen.mouseDrags;
  @override
  bool get mouseHover => _screen.mouseHover;
  @override
  bool get sgrMouse => _screen.sgrMouse;
}

/// A focused terminal next to another focusable widget, to take the focus away.
Future<_FakeShell> _pumpShell(WidgetTester tester, {FocusNode? elsewhere}) async {
  final shell = _FakeShell();
  await tester.pumpWidget(KumoTheme(
    mode: KumoThemeMode.dark,
    palette: KumoPalette.dark,
    terminalPalette: KumoPalette.dark,
    child: MaterialApp(
      home: Scaffold(
        body: Column(children: [
          SizedBox(width: 600, height: 300, child: TerminalCanvas(surface: shell, active: true)),
          if (elsewhere != null) Focus(focusNode: elsewhere, child: const SizedBox(width: 10, height: 10)),
        ]),
      ),
    ),
  ));
  await tester.pump();
  return shell;
}

const _composingTilde = TextEditingValue(text: '˜', composing: TextRange(start: 0, end: 1), selection: TextSelection.collapsed(offset: 1));
const _composingN = TextEditingValue(text: 'n', composing: TextRange(start: 0, end: 1), selection: TextSelection.collapsed(offset: 1));
const _committedEnye = TextEditingValue(text: 'ñ', selection: TextSelection.collapsed(offset: 1));

/// Sends [selector] to the current text input client, as AppKit does.
Future<void> _performSelector(WidgetTester tester, String selector) async {
  final setClient = tester.testTextInput.log.lastWhere((call) => call.method == 'TextInput.setClient');
  final clientId = (setClient.arguments as List).first as int;
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.textInput.name,
    SystemChannels.textInput.codec.encodeMethodCall(MethodCall('TextInputClient.performSelectors', [
      clientId,
      [selector],
    ])),
    (_) {},
  );
}

void main() {
  group('TerminalTextInput', () {
    late List<String> texts;
    late List<List<int>> bytes;
    late TerminalTextInput input;

    setUp(() {
      texts = [];
      bytes = [];
      input = TerminalTextInput(onText: texts.add, onBytes: bytes.add);
    });

    testWidgets('attach opens a connection and detach closes it', (tester) async {
      expect(input.attached, isFalse);
      input.attach();
      expect(input.attached, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      input.detach();
      expect(input.attached, isFalse);
      expect(tester.testTextInput.hasAnyClients, isFalse);
    });

    testWidgets('attaching twice keeps the one connection', (tester) async {
      input.attach();
      tester.testTextInput.log.clear();
      input.attach();
      expect(tester.testTextInput.log.where((call) => call.method == 'TextInput.setClient'), isEmpty);
      input.detach();
    });

    testWidgets('committed text goes out once and the editing state starts over', (tester) async {
      input.attach();
      input.updateEditingValue(_committedEnye);
      expect(texts, ['ñ']);
      expect(input.composing, isFalse);
      expect(input.currentTextEditingValue, TextEditingValue.empty);
      expect(tester.testTextInput.editingState?['text'], '', reason: 'the input method sees an empty field again');
      input.detach();
    });

    testWidgets('a value still being composed is held, not sent', (tester) async {
      input.attach();
      input.updateEditingValue(_composingTilde);
      expect(texts, isEmpty);
      expect(input.composing, isTrue);
      expect(input.currentTextEditingValue, _composingTilde);

      input.updateEditingValue(_committedEnye);
      expect(texts, ['ñ']);
      expect(input.composing, isFalse);
      input.detach();
    });

    testWidgets('a cancelled composition (empty value) sends nothing', (tester) async {
      input.attach();
      input.updateEditingValue(_composingTilde);
      input.updateEditingValue(TextEditingValue.empty);
      expect(texts, isEmpty);
      expect(input.composing, isFalse);
      input.detach();
    });

    testWidgets('detached, nothing counts as composing', (tester) async {
      input.updateEditingValue(_composingTilde);
      expect(input.composing, isFalse);
    });

    testWidgets('detaching drops a composition in progress', (tester) async {
      input.attach();
      input.updateEditingValue(_composingTilde);
      input.detach();
      expect(input.composing, isFalse);
      expect(input.currentTextEditingValue, TextEditingValue.empty);
    });

    testWidgets('the system closing the connection leaves it detached', (tester) async {
      input.attach();
      input.updateEditingValue(_composingTilde);
      input.connectionClosed();
      expect(input.attached, isFalse);
      expect(input.composing, isFalse);
      expect(input.currentTextEditingValue, TextEditingValue.empty);
    });

    test('insertNewline: sends a carriage return; unknown selectors send nothing', () {
      input.performSelector('insertNewline:');
      input.performSelector('moveWordLeft:');
      input.performSelector('noop:');
      expect(bytes, [
        [0x0d],
      ]);
      expect(texts, isEmpty);
    });
  });

  group('the terminal on macOS', () {
    setUp(() => debugHostOs = MacOs(const {}));
    tearDown(() => debugHostOs = null);

    testWidgets('a focused pane listens to the text input system; losing the focus stops it', (tester) async {
      final elsewhere = FocusNode();
      addTearDown(elsewhere.dispose);
      await _pumpShell(tester, elsewhere: elsewhere);
      expect(tester.testTextInput.hasAnyClients, isTrue);

      elsewhere.requestFocus();
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a dead key then its letter types the composed character once', (tester) async {
      final shell = await _pumpShell(tester);
      tester.testTextInput.updateEditingValue(_composingN);
      await tester.pump();
      expect(shell.sent, isEmpty);
      tester.testTextInput.updateEditingValue(_committedEnye);
      await tester.pump();
      expect(shell.sent.map(utf8.decode).toList(), ['ñ']);

      // The field was reset: a later key types on its own, without the ñ.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      expect(shell.sent.map(utf8.decode).toList(), ['ñ', 'x']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Ctrl keys still reach the shell while composing', (tester) async {
      final shell = await _pumpShell(tester);
      tester.testTextInput.updateEditingValue(_composingTilde);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(shell.sent, [
        [0x03],
      ]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('↩ sent by the input method as insertNewline: reaches the shell', (tester) async {
      final shell = await _pumpShell(tester);
      await _performSelector(tester, 'insertNewline:');
      await _performSelector(tester, 'centerSelectionInVisibleArea:');
      expect(shell.sent, [
        [0x0d],
      ]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  for (final (name, os) in [('Windows', () => WindowsOs(const {})), ('Linux', () => LinuxOs(const {}))]) {
    testWidgets('on $name the focused pane opens no text input connection', (tester) async {
      debugHostOs = os();
      addTearDown(() => debugHostOs = null);
      final shell = await _pumpShell(tester);
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(tester.testTextInput.log.where((call) => call.method == 'TextInput.setClient'), isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      expect(shell.sent.map(utf8.decode).toList(), ['a'], reason: 'keys still type from key events');
    });
  }
}
