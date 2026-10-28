import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/terminal/ansi_screen.dart';
import 'package:kumo_ui/terminal/drawn_glyphs.dart';
import 'package:kumo_ui/terminal/grid_renderer.dart';
import 'package:kumo_ui/terminal/terminal_surface.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';

TerminalGridRenderer renderer() => TerminalGridRenderer()
  ..configure(palette: KumoPalette.dark, style: mono(12, height: 1.25), cellWidth: 7.2, lineExtent: 15);

/// An oh-my-posh-like prompt: bubbles with truecolor backgrounds and icons.
const bubble = '\x1b[38;2;137;180;250m\x1b[48;2;137;180;250;38;2;17;17;27m  ~/kumo \x1b[0m'
    '\x1b[38;2;137;180;250m\x1b[0m \x1b[38;2;166;227;161m\x1b[48;2;166;227;161;38;2;17;17;27m  main ✓ \x1b[0m'
    '\x1b[38;2;166;227;161m\x1b[0m ';

void main() {
  test('cellAt maps columns through wide glyphs', () {
    final line = (AnsiScreen(cols: 10, rows: 1)..feed(utf8.encode('a漢b'))).snapshot().lines.first;
    expect(TerminalGridRenderer.cellAt(line, 0)!.$1, 'a'.runes.first);
    expect(TerminalGridRenderer.cellAt(line, 1)!.$1, '漢'.runes.first);
    expect(TerminalGridRenderer.cellAt(line, 2)!.$1, '漢'.runes.first);
    expect(TerminalGridRenderer.cellAt(line, 3)!.$1, 'b'.runes.first);
  });

  test('powerline, box and block glyphs are drawn, letters are not', () {
    final canvas = ui.Canvas(ui.PictureRecorder());
    const cell = Rect.fromLTWH(0, 0, 8, 16);
    for (final rune in [0xE0B0, 0xE0B4, 0xE0B6, 0x2500, 0x2502, 0x256D, 0x2588, 0x2591, 0x259F]) {
      expect(paintDrawnGlyph(canvas, rune, cell, const Color(0xFFFFFFFF), stroke: 1), isTrue, reason: rune.toRadixString(16));
    }
    expect(paintDrawnGlyph(canvas, 0x61, cell, const Color(0xFFFFFFFF), stroke: 1), isFalse);
  });

  test('rows are cached until the line or the configuration changes', () {
    final r = renderer();
    const line = TermLine([TermSpan('hello')]);
    final first = r.row(line);
    expect(identical(r.row(line), first), isTrue);
    r.configure(palette: KumoPalette.light, style: mono(12, height: 1.25), cellWidth: 7.2, lineExtent: 15);
    expect(identical(r.row(line), first), isFalse);
  });

  test('render cost: full 200×50 screen vs. one dirty row', () {
    final screen = AnsiScreen(cols: 200, rows: 50);
    for (var i = 0; i < 50; i++) {
      screen.feed(utf8.encode('$bubble\x1b[33mwarn\x1b[0m line $i ─── \x1b[1;31merror\x1b[0m ${'x' * 80}\r\n'));
    }
    final lines = screen.snapshot().lines;
    final r = renderer();

    final cold = Stopwatch()..start();
    for (final line in lines) {
      r.row(line);
    }
    cold.stop();

    screen.feed(utf8.encode('one more line\r\n'));
    final next = screen.snapshot().lines;
    final warm = Stopwatch()..start();
    for (final line in next.sublist(next.length - 50)) {
      r.row(line);
    }
    warm.stop();

    // flutter test runs in debug (JIT, asserts): an upper bound for release.
    // ignore: avoid_print
    print('render: full screen ${cold.elapsedMicroseconds / 1000} ms, after a scroll ${warm.elapsedMicroseconds / 1000} ms');
    expect(warm.elapsedMicroseconds, lessThan(cold.elapsedMicroseconds));
  });
}
