import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/terminal/ansi_screen.dart';
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
}
