import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/terminal/ansi_screen.dart';
import 'package:kumo_ui/terminal/terminal_keys.dart';
import 'package:kumo_ui/terminal/terminal_surface.dart';
import 'package:kumo_ui/terminal/terminal_view.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';

/// An interactive surface backed by the real parser, recording input.
class _FakeShell implements TerminalModes {
  _FakeShell() {
    _screen.feed(utf8.encode('\x1b[1;32m~\x1b[0m ❯ '));
    _buffer.value = _screen.snapshot();
  }

  final _screen = AnsiScreen(cols: 40, rows: 10);
  final _buffer = ValueNotifier(const TermBuffer([]));
  final sent = <List<int>>[];
  (int, int)? size;

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
  void resize(int cols, int rows) => size = (cols, rows);
  @override
  void dispose() => _buffer.dispose();

  /// What the program writes, e.g. to set modes.
  void feed(String output) {
    _screen.feed(utf8.encode(output));
    _buffer.value = _screen.snapshot();
  }

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

Future<_FakeShell> _pumpShell(WidgetTester tester) async {
  final shell = _FakeShell();
  await tester.pumpWidget(KumoTheme(
    mode: KumoThemeMode.dark,
    palette: KumoPalette.dark,
    terminalPalette: KumoPalette.dark,
    child: MaterialApp(home: Scaffold(body: SizedBox(width: 600, height: 300, child: TerminalCanvas(surface: shell, active: true)))),
  ));
  await tester.pump();
  return shell;
}

void main() {
  testWidgets('an active interactive pane takes the keyboard and paints the cursor', (tester) async {
    final shell = _FakeShell();
    await tester.pumpWidget(KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: SizedBox(width: 600, height: 300, child: TerminalCanvas(surface: shell, active: true)))),
    ));
    await tester.pump();
    expect(shell.buffer.value.cursor, (0, 4));
    expect(shell.size, isNotNull, reason: 'the canvas reports its grid size');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(shell.sent.map(utf8.decode).toList(), ['l', 's', '\r', '\x1b[A', '\x03']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrows carry their modifiers; ⌥← ⌥→ still jump words', (tester) async {
    final shell = await _pumpShell(tester);
    Future<void> with_(LogicalKeyboardKey modifier, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(modifier);
    }

    await with_(LogicalKeyboardKey.altLeft, LogicalKeyboardKey.arrowDown);
    await with_(LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.arrowUp);
    await with_(LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.arrowUp);
    await with_(LogicalKeyboardKey.altLeft, LogicalKeyboardKey.arrowLeft);
    expect(shell.sent.map(utf8.decode).toList(), ['\x1b[1;3B', '\x1b[1;5A', '\x1b[1;2A', '\x1bb']);
  });

  testWidgets('a program that asked for the mouse gets clicks and drags; Shift still selects', (tester) async {
    final shell = await _pumpShell(tester);
    final canvas = tester.getRect(find.byType(TerminalCanvas));
    final at = canvas.topLeft + const Offset(60, 40);

    // Without asking, a click is the terminal's own (selection).
    await tester.tapAt(at);
    expect(shell.sent, isEmpty);

    shell.feed('\x1b[?1002h\x1b[?1006h');
    final drag = await tester.startGesture(at);
    await drag.moveBy(const Offset(40, 0));
    await drag.up();
    final reports = shell.sent.map(utf8.decode).toList();
    final press = RegExp(r'^\x1b\[<0;(\d+);(\d+)M$').firstMatch(reports.first)!;
    expect(reports.sublist(1, reports.length - 1), everyElement(matches(r'^\x1b\[<32;\d+;\d+M$')));
    expect(reports.length, greaterThan(2), reason: 'the drag is reported');
    expect(reports.last, matches(r'^\x1b\[<0;\d+;\d+m$'));
    expect(int.parse(RegExp(r'<0;(\d+)').firstMatch(reports.last)!.group(1)!), greaterThan(int.parse(press.group(1)!)));

    // Shift keeps the selection, as in xterm.
    shell.sent.clear();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(at);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(shell.sent, isEmpty);

    // Only clicks (1000): no motion while dragging.
    shell.feed('\x1b[?1000h');
    final click = await tester.startGesture(at);
    await click.moveBy(const Offset(40, 0));
    await click.up();
    expect(shell.sent.map(utf8.decode), [matches(r'M$'), matches(r'm$')]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('⌘ shortcuts are left to the app', (tester) async {
    final shell = _FakeShell();
    await tester.pumpWidget(KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: TerminalCanvas(surface: shell, active: true))),
    ));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(shell.sent, isEmpty);
  });

  Future<void> holding(WidgetTester tester, List<LogicalKeyboardKey> modifiers, LogicalKeyboardKey key) async {
    for (final m in modifiers) {
      await tester.sendKeyDownEvent(m);
    }
    await tester.sendKeyEvent(key);
    for (final m in modifiers.reversed) {
      await tester.sendKeyUpEvent(m);
    }
  }

  const shift = LogicalKeyboardKey.shiftLeft;
  const alt = LogicalKeyboardKey.altLeft;
  const ctrl = LogicalKeyboardKey.controlLeft;
  const meta = LogicalKeyboardKey.metaLeft;

  testWidgets('⇧↩ and ⌥↩ break the line; ⌥⌫ ⌥⌦ and Ctrl+⌫ delete words', (tester) async {
    final shell = await _pumpShell(tester);
    await holding(tester, [shift], LogicalKeyboardKey.enter);
    await holding(tester, [alt], LogicalKeyboardKey.enter);
    await holding(tester, [alt], LogicalKeyboardKey.backspace);
    await holding(tester, [alt], LogicalKeyboardKey.delete);
    await holding(tester, [ctrl], LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(shell.sent.map(utf8.decode).toList(), ['\x1b\r', '\x1b\r', '\x1b\x7f', '\x1bd', '\x17', '\r']);
  });

  testWidgets('on macOS ⌘← ⌘→ go to the line ends and ⌘⌫ deletes to its start', (tester) async {
    final shell = await _pumpShell(tester);
    await holding(tester, [meta], LogicalKeyboardKey.arrowLeft);
    await holding(tester, [meta], LogicalKeyboardKey.arrowRight);
    await holding(tester, [meta], LogicalKeyboardKey.backspace);
    expect(shell.sent, [
      [0x01],
      [0x05],
      [0x15],
    ]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('⇧← selects from the cursor; ⌫ deletes the selection and typing replaces it', (tester) async {
    final shell = await _pumpShell(tester);
    shell.feed('hello');
    await tester.pump();

    // Leftward: two characters, echoed as the shell would.
    await holding(tester, [shift], LogicalKeyboardKey.arrowLeft);
    shell.feed('\b');
    await holding(tester, [shift], LogicalKeyboardKey.arrowLeft);
    shell.feed('\b');
    expect(shell.sent.map(utf8.decode).toList(), ['\x1b[D', '\x1b[D']);
    shell.sent.clear();

    // ⌫ goes back to the end of the selection and deletes it.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    expect(shell.sent.map(utf8.decode).toList(), ['\x1b[C\x1b[C\x7f\x7f']);
    shell.sent.clear();

    // Rightward by words, then a character replaces it.
    shell.feed("\x1b[2D"); // the cursor somewhere else in the line
    await holding(tester, [shift, alt], LogicalKeyboardKey.arrowRight);
    shell.feed('\x1b[2C');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    expect(shell.sent.map(utf8.decode).toList(), ['\x1bf', '\x7f\x7f', 'x']);
    shell.sent.clear();

    // With nothing selected the keys go through untouched.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    expect(shell.sent.map(utf8.decode).toList(), ['\x7f']);
  });

  testWidgets('a cursor move nobody asked for ends the keyboard selection', (tester) async {
    final shell = await _pumpShell(tester);
    shell.feed('hello');
    await holding(tester, [shift], LogicalKeyboardKey.arrowLeft);
    shell.feed('\b');
    shell.feed('\x1b[1;1H'); // the program redraws elsewhere
    shell.sent.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    expect(shell.sent.map(utf8.decode).toList(), ['\x7f']);
  });

  testWidgets('full-screen programs get ⇧← as is', (tester) async {
    final shell = await _pumpShell(tester);
    shell.feed('\x1b[?1049h');
    await holding(tester, [shift], LogicalKeyboardKey.arrowLeft);
    expect(shell.sent.map(utf8.decode).toList(), ['\x1b[1;2D']);
  });

  group('pasting and dropping files', () {
    const channel = MethodChannel('kumo/pasteboard');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    List<String>? onClipboard;
    setUp(() {
      onClipboard = null;
      messenger.setMockMethodCallHandler(channel, (call) async => call.method == 'paths' ? onClipboard : null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => call.method == 'Clipboard.getData' ? {'text': 'plain text'} : null);
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<void> drop(List<String> paths, Offset at) => messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(MethodCall('drop', {'paths': paths, 'x': at.dx, 'y': at.dy})),
          (_) {},
        );

    test('a paste is only text: it can neither act as keys nor end early', () {
      expect(utf8.decode(terminalPaste('a\x1b[201~b\x03c\x7fd\u009be\tf\r\ng\nh', bracketed: true)), '\x1b[200~a[201~bcde\tf\rg\rh\x1b[201~');
      expect(utf8.decode(terminalPaste('a\x1bb')), 'ab');
    });

    test('paths are escaped as a shell takes them', () {
      expect(terminalPaths(['/tmp/a b/Screenshot (1).png', r"/x/it's $HOME"]), r"/tmp/a\ b/Screenshot\ \(1\).png /x/it\'s\ \$HOME");
    });

    testWidgets('⌘V pastes copied files or a screenshot as paths, and text otherwise', (tester) async {
      final shell = await _pumpShell(tester);
      shell.feed('\x1b[?2004h');
      onClipboard = ['/Users/me/Desktop/Screen Shot.png'];
      await holding(tester, [meta], LogicalKeyboardKey.keyV);
      await tester.pump();
      onClipboard = null;
      await holding(tester, [meta], LogicalKeyboardKey.keyV);
      await tester.pump();
      expect(shell.sent.map(utf8.decode).toList(), ['\x1b[200~/Users/me/Desktop/Screen\\ Shot.png\x1b[201~', '\x1b[200~plain text\x1b[201~']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('files dropped go to the pane under the pointer, not one offstage', (tester) async {
      final shown = _FakeShell();
      final hidden = _FakeShell();
      await tester.pumpWidget(KumoTheme(
        mode: KumoThemeMode.dark,
        palette: KumoPalette.dark,
        terminalPalette: KumoPalette.dark,
        child: MaterialApp(
          home: Scaffold(
            body: IndexedStack(index: 0, children: [TerminalCanvas(surface: shown), TerminalCanvas(surface: hidden)]),
          ),
        ),
      ));
      await tester.pump();
      final at = tester.getCenter(find.byType(TerminalCanvas).first);
      await drop(['/a/one.png', '/a/two.txt'], at);
      await tester.pump();
      expect(shown.sent.map(utf8.decode).toList(), ['/a/one.png /a/two.txt']);
      expect(hidden.sent, isEmpty);

      await drop(['/a/one.png'], const Offset(-10, -10));
      expect(shown.sent, hasLength(1), reason: 'off the pane nothing goes in');
    });
  });
}
