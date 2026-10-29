import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/terminal/ansi_screen.dart';
import 'package:kumo_ui/terminal/term_selection.dart';
import 'package:kumo_ui/terminal/terminal_surface.dart';
import 'package:kumo_ui/terminal/terminal_view.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';

final _lines = [
  TermLine.of([('~/dev/kumo ', TermRole.acc), ('❯ git status', TermRole.text)]),
  const TermLine([]),
  TermLine.of([('modified:   crates/grpc/src/server.rs.', TermRole.warn)]),
];

class _Shell implements TerminalSurface {
  _Shell() {
    _screen.feed(utf8.encode('hello world\r\nsecond line\r\n❯ '));
    _buffer.value = _screen.snapshot();
  }

  final _screen = AnsiScreen(cols: 40, rows: 6);
  final _buffer = ValueNotifier(const TermBuffer([]));
  final sent = <List<int>>[];

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
}

void main() {
  test('selected text spans lines, keeps empty ones and trims trailing blanks', () {
    final sel = TermSelection(const TermPoint(2, 12), const TermPoint(0, 11));
    expect(selectedText(_lines, sel), '❯ git status\n\nmodified:');
  });

  test('double-click takes a path without the full stop; triple-click the line', () {
    expect(selectedText(_lines, wordAt(_lines, const TermPoint(2, 20))), 'crates/grpc/src/server.rs');
    expect(selectedText(_lines, wordAt(_lines, const TermPoint(0, 3))), '~/dev/kumo');
    expect(wordAt(_lines, const TermPoint(0, 10)).isEmpty, isTrue, reason: 'a blank selects nothing');
    expect(selectedText(_lines, lineAt(_lines, 0)), '~/dev/kumo ❯ git status');
  });

  testWidgets('drag selects in the terminal; Ctrl+Shift+C copies, typing clears it', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final shell = _Shell();
    await tester.pumpWidget(KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: SizedBox(width: 600, height: 200, child: TerminalCanvas(surface: shell, active: true)))),
    ));
    await tester.pump();
    final box = tester.getTopLeft(find.byType(TerminalCanvas));
    // Padding 14/12; measure a cell from the canvas's own layout.
    final tp = TextPainter(text: TextSpan(text: 'M', style: mono(12, height: 1.25)), textDirection: TextDirection.ltr)..layout();
    final cw = tp.width;
    final lh = tp.height;
    tp.dispose();
    Offset at(int line, int col) => box + Offset(14 + col * cw, 12 + line * lh + lh / 2);

    final gesture = await tester.startGesture(at(0, 0), buttons: kPrimaryButton);
    await gesture.moveTo(at(0, 5));
    await gesture.up();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(copied, 'hello');
    expect(shell.sent, isEmpty, reason: 'copying sends nothing to the shell');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.pump();
    expect(shell.sent.map(utf8.decode), ['x']);
    expect(tester.takeException(), isNull);
  });
}
