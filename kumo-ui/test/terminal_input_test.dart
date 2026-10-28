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
class _FakeShell implements TerminalSurface {
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
