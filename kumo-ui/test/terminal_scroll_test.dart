import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/terminal/ansi_screen.dart';
import 'package:kumo_ui/terminal/terminal_surface.dart';
import 'package:kumo_ui/terminal/terminal_view.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';

/// A shell that printed `line 1` … `line 200`.
class _Shell implements TerminalSurface {
  _Shell({int maxScrollback = 5000}) : _screen = AnsiScreen(cols: 40, rows: 6, maxScrollback: maxScrollback) {
    feed([for (var i = 1; i <= 200; i++) 'line $i'].join('\r\n'));
  }

  final AnsiScreen _screen;
  final _buffer = ValueNotifier(const TermBuffer([]));
  final sent = <List<int>>[];

  void feed(String text) {
    _screen.feed(utf8.encode(text));
    _buffer.value = _screen.snapshot();
  }

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

TermBuffer _buffer(int lines, {int dropped = 0, int reflows = 0, bool alt = false}) =>
    TermBuffer([for (var i = 0; i < lines; i++) TermLine.empty], cursor: (lines - 1, 0), dropped: dropped, reflows: reflows, altScreen: alt);

void main() {
  test('a scrolled view stays on its lines while old ones are dropped', () {
    expect(visibleStart(_buffer(100), 10), 90, reason: 'follows the output');
    expect(visibleStart(_buffer(100), 10, top: 40), 40);
    // 15 lines dropped from the top: the same line is now 15 earlier.
    expect(visibleStart(_buffer(100, dropped: 15), 10, top: 40), 25);
    expect(visibleStart(_buffer(100, dropped: 60), 10, top: 40), 0, reason: 'gone: the oldest left');
    expect(visibleStart(_buffer(100, alt: true), 10, top: 40), 90, reason: 'full-screen programs have no history');
    expect(visibleStart(_buffer(100, reflows: 1), 10, top: 40), 90, reason: 're-wrapped: back to the bottom');
  });

  test('in the history the view can sit part of a line down; at the bottom it can’t', () {
    expect(visibleOffset(_buffer(100), 10, top: 40, frac: 0.25), 0.25);
    expect(visibleOffset(_buffer(100), 10, frac: 0.25), 0, reason: 'follows the output');
    expect(visibleOffset(_buffer(100), 10, top: 95, frac: 0.25), 0, reason: 'clamped to the bottom');
    expect(visibleOffset(_buffer(100, alt: true), 10, top: 40, frac: 0.25), 0);
  });

  testWidgets('the wheel moves by pixels: half a line shows half a line, clicks hit the line under them', (tester) async {
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
    final tp = TextPainter(text: TextSpan(text: 'M', style: mono(12, height: 1.25)), textDirection: TextDirection.ltr)..layout();
    final cw = tp.width;
    final lh = tp.height;
    tp.dispose();
    final fit = ((200 - 24) / lh).floor();

    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    mouse.hover(box + const Offset(100, 100));
    await tester.sendEventToBinding(mouse.scroll(Offset(0, -lh * 20.5)));
    await tester.pump();
    // Line 200 - fit + 1 - 21 is on top, half of it scrolled off: a click
    // three quarters of a line below the padding is on the next one.
    final g = await tester.startGesture(box + Offset(14, 12 + lh * 0.75), buttons: kPrimaryButton);
    await g.moveTo(box + Offset(14 + 12 * cw, 12 + lh * 0.75));
    await g.up();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(copied, 'line ${200 - fit + 1 - 21 + 1}');
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  test('wheel reports follow xterm', () {
    expect(utf8.decode(wheelReport(up: true, col: 4, row: 2, sgr: true)), '\x1b[<64;5;3M');
    expect(wheelReport(up: false, col: 0, row: 0), [0x1b, 0x5b, 0x4d, 32 + 65, 33, 33]);
  });

  testWidgets('the wheel reads the history; output doesn’t move it; typing goes back', (tester) async {
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
    final tp = TextPainter(text: TextSpan(text: 'M', style: mono(12, height: 1.25)), textDirection: TextDirection.ltr)..layout();
    final cw = tp.width;
    final lh = tp.height;
    tp.dispose();
    Offset at(int row, int col) => box + Offset(14 + col * cw, 12 + row * lh + lh / 2);

    /// The text of the first row on screen, through select + copy.
    Future<String?> firstRow() async {
      final g = await tester.startGesture(at(0, 0), buttons: kPrimaryButton);
      await g.moveTo(at(0, 12));
      await g.up();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      return copied;
    }

    final fit = ((200 - 24) / lh).floor();
    expect(await firstRow(), 'line ${200 - fit + 1}');
    expect(find.text('Jump to bottom'), findsNothing);

    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    mouse.hover(at(2, 2));
    await tester.sendEventToBinding(mouse.scroll(Offset(0, -lh * 50)));
    await tester.pump();
    expect(await firstRow(), 'line ${200 - fit + 1 - 50}');
    expect(find.text('Jump to bottom'), findsOneWidget);

    shell.feed('\r\nmore\r\nand more');
    await tester.pump();
    expect(await firstRow(), 'line ${200 - fit + 1 - 50}', reason: 'new output doesn’t pull the view');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(await firstRow(), 'line ${200 - fit + 1 - 50 - (fit - 1)}');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.pump();
    expect(shell.sent.map(utf8.decode), ['x']);
    expect(find.text('Jump to bottom'), findsNothing, reason: 'typing goes back to the prompt');
    expect(await firstRow(), 'line ${200 - fit + 3}');

    await tester.sendEventToBinding(mouse.scroll(Offset(0, -lh * 5000)));
    await tester.pump();
    expect(await firstRow(), 'line 1', reason: 'stops at the oldest line');
    await tester.tap(find.text('Jump to bottom'));
    await tester.pump();
    expect(find.text('Jump to bottom'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a full-screen program gets arrows from the wheel, not history', (tester) async {
    final shell = _Shell()..feed('\x1b[?1049hless');
    await tester.pumpWidget(KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: SizedBox(width: 600, height: 200, child: TerminalCanvas(surface: shell, active: true)))),
    ));
    await tester.pump();
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    mouse.hover(tester.getCenter(find.byType(TerminalCanvas)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -200)));
    await tester.pump();
    expect(find.text('Jump to bottom'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
