// Terminal render benchmark, meant for profile mode (AOT, like release):
//   flutter run -d macos --profile -t benchmark/render_bench.dart
// Records full screens through the grid renderer and prints per-frame cost.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:kumo_ui/terminal/ansi_screen.dart';
import 'package:kumo_ui/terminal/grid_renderer.dart';
import 'package:kumo_ui/terminal/terminal_surface.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';

const _bubble = '\x1b[38;2;137;180;250m\x1b[48;2;137;180;250;38;2;17;17;27m  ~/kumo \x1b[0m'
    '\x1b[38;2;137;180;250m\x1b[0m \x1b[38;2;166;227;161m\x1b[48;2;166;227;161;38;2;17;17;27m  main ✓ \x1b[0m'
    '\x1b[38;2;166;227;161m\x1b[0m ';

List<TermLine> _screen(String Function(int row) content) {
  final screen = AnsiScreen(cols: 200, rows: 50);
  for (var i = 0; i < 50; i++) {
    screen.feed(utf8.encode('${content(i)}\r\n'));
  }
  return screen.snapshot().lines.sublist(1); // the 50 visible rows
}

/// Median ms to record every row from scratch (worst case: all rows dirty).
double _fullScreen(List<TermLine> lines) {
  final samples = <double>[];
  for (var i = 0; i < 30; i++) {
    final renderer = TerminalGridRenderer()
      ..configure(palette: KumoPalette.dark, style: mono(12, height: 1.25), cellWidth: 7.2, lineExtent: 15);
    final sw = Stopwatch()..start();
    for (final line in lines) {
      renderer.row(line);
    }
    samples.add(sw.elapsedMicroseconds / 1000);
    renderer.dispose();
  }
  samples.sort();
  return samples[samples.length ~/ 2];
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final cases = {
    'plain text (1 run/row)': _screen((i) => 'x' * 190),
    'colored (10 runs/row)': _screen((i) => List.generate(10, (k) => '\x1b[3${k % 7 + 1}m${'y' * 18}').join()),
    'prompt bubbles + text': _screen((i) => '$_bubble\x1b[33mwarn\x1b[0m line $i ─── \x1b[1;31merror\x1b[0m ${'x' * 80}'),
    'TUI box (vim/htop-like)': _screen((i) => '│\x1b[44m ${'·' * 60} \x1b[0m│ \x1b[32m${'█' * (i % 40)}\x1b[0m ${'░' * 20}│'),
  };
  for (final MapEntry(:key, :value) in cases.entries) {
    _fullScreen(value); // warm-up
    // ignore: avoid_print
    print('render-bench: ${key.padRight(26)} full 200×50 screen: ${_fullScreen(value).toStringAsFixed(2)} ms (median of 30)');
  }
  Future<void>.delayed(const Duration(seconds: 1), () => exit(0));
}
