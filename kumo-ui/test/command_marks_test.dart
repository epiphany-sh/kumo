import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/app/preferences.dart';
import 'package:kumo_ui/overlays/settings_dialog.dart';
import 'package:kumo_ui/overlays/your_lines_settings.dart';
import 'package:kumo_ui/terminal/ansi_screen.dart';
import 'package:kumo_ui/terminal/command_marks.dart';
import 'package:kumo_ui/terminal/terminal_surface.dart';
import 'package:kumo_ui/terminal/terminal_view.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';
import 'package:kumo_ui/widgets/controls.dart';

/// What Kumo's zsh integration prints around a prompt and a command.
const a = '\x1b]133;A\x07';
const c = '\x1b]133;C\x07';
String d(int exit) => '\x1b]133;D;$exit\x07';

/// A screen fed [input], timed by a clock that moves only when told.
class _Clock {
  int now = 0;
  int call() => now;
}

AnsiScreen screen({int cols = 30, int rows = 10, int maxScrollback = 5000, _Clock? clock}) =>
    AnsiScreen(cols: cols, rows: rows, maxScrollback: maxScrollback, clock: (clock ?? _Clock()).call);

void main() {
  group('shell marks (OSC 133)', () {
    test('a prompt, its output and its exit make a command', () {
      final s = screen()
        ..feed(utf8.encode('$a\$ ls\r\n${c}a\r\nb\r\n${d(0)}$a\$ false\r\n$c${d(1)}$a\$ '));
      final b = s.snapshot().blocks;
      expect(b, [
        const CommandBlock(start: 0, outputStart: 1, end: 3, exit: 0, took: Duration.zero),
        const CommandBlock(start: 3, outputStart: 4, end: 4, exit: 1, took: Duration.zero),
      ]);
      expect(b[1].failed, isTrue);
      // The last prompt hasn't run anything: no command yet.
      expect(blockAt(b, 4), isNull);
      expect(blockAt(b, 0), b[0]);
      expect(blockAt(b, 1), isNull, reason: 'output is not what you ran');
    });

    test('a command still running has no end; the time comes from the clock', () {
      final clock = _Clock();
      final s = screen(clock: clock)..feed(utf8.encode('$a\$ make lint\r\n${c}linting'));
      expect(s.snapshot().blocks.single.running, isTrue);
      clock.now = 12400;
      s.feed(utf8.encode('\r\n${d(2)}$a\$ '));
      final b = s.snapshot().blocks.single;
      expect(b.end, 2);
      expect(b.took, const Duration(milliseconds: 12400));
      expect(commandMeta(b), 'exit 2 · 12s');
    });

    test('marks split across reads, ended by ST, still count', () {
      final s = screen();
      for (final part in ['\x1b]13', '3;A\x1b', '\\\$ ls\r\n\x1b]133', ';C\x1b\\out\r\n\x1b]133;D;0', '\x07']) {
        s.feed(utf8.encode(part));
      }
      expect(s.snapshot().blocks, [const CommandBlock(start: 0, outputStart: 1, end: 2, exit: 0, took: Duration.zero)]);
      expect(s.snapshot().lines.first.spans.map((x) => x.text).join(), r'$ ls', reason: 'no OSC text on screen');
    });

    test('VS Code’s 633 counts the same; other OSCs are ignored', () {
      final s = screen()..feed(utf8.encode('\x1b]0;title\x07\x1b]633;A\x07\$ ls\r\n\x1b]633;C\x07x\r\n\x1b]633;D;0\x07'));
      expect(s.snapshot().blocks.single.exit, 0);
    });

    test('two integrations marking the same prompt make one command', () {
      final s = screen()..feed(utf8.encode('$a$a\$ ls\r\n$c${c}x\r\n${d(0)}${d(0)}$a$a'));
      expect(s.snapshot().blocks, hasLength(1));
    });

    test('clearing the screen forgets the commands on it; a line redraw doesn’t', () {
      final s = screen()..feed(utf8.encode('$a\$ ls\r\n${c}x\r\n${d(0)}$a\$ gi\r\x1b[K\$ git status\r\n${c}clean\r\n${d(0)}$a'));
      expect(s.snapshot().blocks, hasLength(2));
      s.feed(utf8.encode('\x1b[H\x1b[2J'));
      expect(s.snapshot().blocks, isEmpty);
    });

    test('⌃L clears the screen and redraws the prompt unmarked: the next command still counts', () {
      final s = screen()..feed(utf8.encode('$a\$ ls\r\n${c}x\r\n${d(0)}$a\$ \x1b[H\x1b[2J\$ pwd\r\n${c}/tmp\r\n${d(0)}$a'));
      final b = s.snapshot();
      expect(b.blocks, [const CommandBlock(start: 0, outputStart: 1, end: 2, exit: 0, took: Duration.zero)]);
      expect(b.lines[0].spans.map((x) => x.text).join(), r'$ pwd');
    });

    test('commands keep their marks in the scrollback, when trimmed and when re-wrapped', () {
      final s = screen(cols: 20, rows: 4, maxScrollback: 6);
      for (var i = 0; i < 3; i++) {
        s.feed(utf8.encode('$a\$ cmd $i\r\n${c}out $i\r\n${d(0)}'));
      }
      s.feed(utf8.encode(a));
      final before = s.snapshot();
      expect(before.blocks, hasLength(3));
      expect(before.blocks.map((b) => before.lines[b.start].spans.map((x) => x.text).join()), [r'$ cmd 0', r'$ cmd 1', r'$ cmd 2']);
      for (var i = 3; i < 6; i++) {
        s.feed(utf8.encode('$a\$ cmd $i\r\n${c}out $i\r\n${d(0)}'));
      }
      expect(s.snapshot().blocks.length, lessThan(6), reason: 'the oldest were trimmed with their lines');
      s.resize(12, 4);
      final after = s.snapshot();
      expect(after.blocks, isNotEmpty);
      for (final b in after.blocks) {
        expect(after.lines[b.start].spans.map((x) => x.text).join(), startsWith(r'$ cmd'));
      }
    });

    test('a full-screen program has no commands', () {
      final s = screen()..feed(utf8.encode('$a\$ vim\r\n$c\x1b[?1049h'));
      expect(s.snapshot().blocks, isEmpty);
      s.feed(utf8.encode('\x1b[?1049l'));
      expect(s.snapshot().blocks, hasLength(1));
    });
  });

  test('what a finished command shows on its line', () {
    CommandBlock done(int exit, int seconds) => CommandBlock(start: 0, outputStart: 1, end: 2, exit: exit, took: Duration(seconds: seconds));
    expect(commandMeta(done(0, 3)), isNull);
    expect(commandMeta(done(0, 14)), '14s');
    expect(commandMeta(done(1, 0)), 'exit 1');
    expect(commandMeta(done(130, 2)), 'interrupted · 2s');
    expect(done(130, 2).failed, isFalse);
    expect(commandMeta(const CommandBlock(start: 0, outputStart: 1)), isNull, reason: 'still running');
    expect(formatTook(const Duration(seconds: 65)), '1m 05s');
    expect(formatTook(const Duration(minutes: 62)), '1h 02m');
  });

  test('the pinned command: while its output fills the top, pushed by the next', () {
    const blocks = [CommandBlock(start: 0, outputStart: 1, end: 10), CommandBlock(start: 10, outputStart: 12)];
    expect(stickyCommand(blocks, 0, 0), isNull, reason: 'its line shows');
    expect(stickyCommand(blocks, 5, 0), (block: blocks[0], lines: 1, shift: 0.0));
    expect(stickyCommand(blocks, 9, 0.5), (block: blocks[0], lines: 1, shift: -0.5));
    expect(stickyCommand(blocks, 10, 0), isNull, reason: 'the next one shows itself');
    expect(stickyCommand(blocks, 13, 0), (block: blocks[1], lines: 2, shift: 0.0));
    expect(stickyCommand([const CommandBlock(start: -3, outputStart: 1)], 4, 0), isNull, reason: 'trimmed away');
    expect(previousBlock(blocks, 10)?.start, 0);
    expect(nextBlock(blocks, 0)?.start, 10);
    expect(nextBlock(blocks, 10), isNull);
  });

  test('a mock’s message to the agent closes the running block and opens one', () {
    final b = const TermBuffer([TermLine.empty, TermLine.empty], blocks: [CommandBlock(start: 0, outputStart: 1)]).append([TermLine.empty, TermLine.empty], block: true);
    expect(b.blocks, [const CommandBlock(start: 0, outputStart: 1, end: 2), const CommandBlock(start: 2, outputStart: 3)]);
    final trimmed = b.append([TermLine.empty], maxLines: 3);
    expect(trimmed.blocks, [const CommandBlock(start: 0, outputStart: 1)], reason: 'the one that scrolled away is gone');
  });

  group('colors', () {
    test('light terminals get the same hue, darkened to 3:1', () {
      final bg = terminalBackground(KumoPalette.light);
      for (final (name, color) in yourLinesPresets) {
        final light = forLightTerminal(color, bg);
        expect(contrastRatio(light, bg), greaterThanOrEqualTo(markContrast), reason: name);
        expect((HSLColor.fromColor(light).hue - HSLColor.fromColor(color).hue).abs(), lessThan(3), reason: name);
      }
      // Already dark enough: unchanged.
      expect(forLightTerminal(const Color(0xFF1B4FD8), bg), const Color(0xFF1B4FD8));
    });

    test('the terminal’s background decides, not the theme', () {
      const yl = YourLines(dark: Color(0xFFFFA43D));
      expect(yl.colorFor(KumoPalette.dark), const Color(0xFFFFA43D));
      expect(yl.colorFor(KumoPalette.hybridTerminal), const Color(0xFFFFA43D), reason: 'Hybrid’s terminal is dark');
      expect(yl.colorFor(KumoPalette.light), isNot(const Color(0xFFFFA43D)));
      const own = YourLines(dark: Color(0xFFFFA43D), light: Color(0xFF7C3AED));
      expect(own.colorFor(KumoPalette.light), const Color(0xFF7C3AED));
    });

    test('hex in and out', () {
      expect(parseHexColor('ffa43d'), const Color(0xFFFFA43D));
      expect(parseHexColor(' #FFA43D '), const Color(0xFFFFA43D));
      expect(parseHexColor('#FFA4'), isNull);
      expect(parseHexColor('#GGGGGG'), isNull);
      expect(hexOf(const Color(0xFF0A0B0C)), '#0A0B0C');
    });

    test('settings: defaults, and what a broken value falls back to', () {
      expect(YourLines.from(Preferences.memory()), const YourLines());
      final p = Preferences.memory()
        ..set(YourLines.keyDark, 'nope')
        ..set(YourLines.keyLightMode, 'own')
        ..set(YourLines.keyStyle, 'bar')
        ..set(YourLines.keyBand, 99)
        ..set(YourLines.keyBar, 4);
      final yl = YourLines.from(p);
      expect(yl.dark, YourLines.defaultColor);
      expect(yl.light, isNull, reason: 'own, but none picked yet: auto');
      expect(yl.band, isFalse);
      expect(yl.bandAlpha, 0.30);
      expect(yl.bar, 4);
      expect(lowContrastNote(const Color(0xFF222233), KumoPalette.dark), contains('hard to see'));
      expect(lowContrastNote(YourLines.defaultColor, KumoPalette.dark), isNull);
    });
  });

  testWidgets('Settings → Appearance tunes your lines, and terminals follow', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(mode: KumoThemeMode.dark, demoWallpaper: true);
    await tester.pumpWidget(KumoApp(state: state));
    await tester.pump();
    await tester.tap(find.byTooltip('Settings (⌘,)'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SettingsDialog), findsOneWidget);
    await tester.tap(find.text('Appearance'));
    await tester.pump();
    expect(find.text('Mark what you ran'), findsOneWidget);
    expect(find.text('Band strength'), findsOneWidget);
    expect(find.byType(YourLinesPreview), findsOneWidget);

    // Bar only: no band, no band slider.
    await tester.ensureVisible(find.text('Bar only'));
    await tester.tap(find.text('Bar only'));
    await tester.pump();
    expect(state.yourLines.value.band, isFalse);
    expect(find.text('Band strength'), findsNothing);

    // A swatch, then a hex typed in.
    final mint = find.byTooltip('Mint  #5EE09A');
    await tester.ensureVisible(mint);
    await tester.tap(mint);
    await tester.pump();
    expect(state.yourLines.value.dark, const Color(0xFF5EE09A));
    await tester.enterText(find.descendant(of: find.byType(MarkSwatches), matching: find.byType(TextField)).first, '#12AB34');
    await tester.pump();
    expect(state.setting<String>(YourLines.keyDark, ''), '#12AB34');

    // Light terminals: their own color.
    expect(find.text('Color on light terminals'), findsNothing);
    await tester.ensureVisible(find.text('Own color'));
    await tester.tap(find.text('Own color'));
    await tester.pump();
    expect(find.text('Color on light terminals'), findsOneWidget);

    // Marks off: only the switch and the pinned command are left.
    final marks = find.byWidgetPredicate((w) => w is KSwitch && w.label == 'Mark what you ran');
    await tester.ensureVisible(marks);
    await tester.pump();
    await tester.tap(marks);
    await tester.pump();
    expect(state.yourLines.value.marks, isFalse);
    expect(find.text('Style'), findsNothing);
    expect(find.text('Keep the command on top'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('⌘↑ / ⌘↓ go from command to command, and paint without errors', (tester) async {
    final shell = _Shell();
    await tester.pumpWidget(KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: SizedBox(width: 600, height: 200, child: TerminalCanvas(surface: shell, active: true)))),
    ));
    await tester.pump();
    expect(shell.buffer.value.blocks, hasLength(5));
    expect(find.text('Jump to bottom'), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    // Two commands back, and the arrows never reached the shell.
    expect(shell.sent.map(utf8.decode).where((k) => k.contains('\x1b[A') || k.contains('\x1bOA')), isEmpty);
    expect(find.text('Jump to bottom'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.text('Jump to bottom'), findsNothing, reason: 'past the last one: back at the prompt');
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}

/// Five commands of twelve lines of output each, then a prompt.
class _Shell implements TerminalSurface {
  _Shell() {
    for (var i = 0; i < 5; i++) {
      final out = [for (var k = 0; k < 12; k++) 'out $i.$k'].join('\r\n');
      _screen.feed(utf8.encode('$a\$ cmd $i\r\n$c$out\r\n${d(i == 3 ? 1 : 0)}'));
    }
    _screen.feed(utf8.encode('$a\$ '));
    _buffer.value = _screen.snapshot();
  }

  final _screen = AnsiScreen(cols: 60, rows: 8);
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
