import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/terminal/ansi_screen.dart';
import 'package:kumo_ui/terminal/terminal_surface.dart';

String text(TermLine line) => line.spans.map((s) => s.text).join();

List<String> screenText(AnsiScreen screen) => screen.snapshot().lines.map(text).toList();

AnsiScreen fed(String input, {int cols = 20, int rows = 4}) => AnsiScreen(cols: cols, rows: rows)..feed(utf8.encode(input));

void main() {
  test('prints, wraps lines and tracks the cursor', () {
    final screen = fed('hello\r\nworld');
    expect(screenText(screen), ['hello', 'world', '', '']);
    expect(screen.snapshot().cursor, (1, 5));
  });

  test('lines scrolled off the top go to scrollback', () {
    final screen = fed('1\r\n2\r\n3\r\n4\r\n5', rows: 3);
    expect(screenText(screen), ['1', '2', '3', '4', '5']);
    expect(screen.snapshot().cursor, (4, 1));
  });

  test('SGR colors map to semantic roles, bold included', () {
    final line = fed('\x1b[1;32mok\x1b[0m \x1b[31merr\x1b[2m dim').snapshot().lines.first;
    expect([for (final s in line.spans) (s.text, s.role, s.bold)], [
      ('ok', TermRole.ok, true),
      (' ', TermRole.text, false),
      ('err', TermRole.err, false),
      (' dim', TermRole.err, false),
    ]);
  });

  test('backgrounds, truecolor and inverse are kept per span', () {
    final spans = fed('\x1b[48;2;137;180;250;38;5;16m zh \x1b[0m\x1b[44mx\x1b[7my').snapshot().lines.first.spans;
    expect(spans[0].text, ' zh ');
    expect(spans[0].background, const TermColor.rgb(0x89b4fa));
    expect(spans[0].rgb, 0x000000);
    expect(spans[1].background, const TermColor.role(TermRole.acc));
    expect(spans[2].inverse, isTrue);
  });

  test('erase uses the current background (BCE)', () {
    final spans = fed('\x1b[41m\x1b[K').snapshot().lines.first.spans;
    expect(spans.single.text, ' ' * 20);
    expect(spans.single.background, const TermColor.role(TermRole.err));
  });

  test('wide glyphs take two cells and move the cursor by two', () {
    final screen = fed('a漢b');
    expect(screenText(screen).first, 'a漢b');
    expect(screen.snapshot().cursor, (0, 4));
  });

  test('a wide glyph that does not fit wraps to the next line', () {
    final screen = fed('abc漢', cols: 4);
    expect(screenText(screen).take(2), ['abc', '漢']);
  });

  test('carriage return + erase line redraws a prompt', () {
    expect(screenText(fed('abc\r\x1b[Kxy')).first, 'xy');
  });

  test('cursor addressing and erase display', () {
    final screen = fed('\x1b[2J\x1b[3;5Hx');
    expect(screenText(screen)[2], '    x');
    expect(screen.snapshot().cursor, (2, 5));
  });

  test('backspace and delete characters', () {
    expect(screenText(fed('abcd\b\b\x1b[P')).first, 'abd');
  });

  test('alternate screen restores the main screen', () {
    final screen = fed('main\x1b[?1049hTUI');
    expect(screenText(screen).first, 'TUI');
    screen.feed(utf8.encode('\x1b[?1049l'));
    expect(screenText(screen).first, 'main');
  });

  test('UTF-8 split across feeds', () {
    final screen = AnsiScreen(cols: 10, rows: 2);
    final bytes = utf8.encode('ñ→');
    screen.feed(bytes.sublist(0, 1));
    screen.feed(bytes.sublist(1));
    expect(screenText(screen).first, 'ñ→');
  });

  test('ignores OSC titles and private modes', () {
    final screen = fed('\x1b]0;title\x07\x1b[?2004hok\x1b[?25l');
    expect(screenText(screen).first, 'ok');
    expect(screen.bracketedPaste, isTrue);
    expect(screen.snapshot().cursorVisible, isFalse);
  });

  test('answers cursor position reports', () {
    final replies = <String>[];
    AnsiScreen(cols: 10, rows: 3, onReply: (b) => replies.add(utf8.decode(b))).feed(utf8.encode('ab\x1b[6n'));
    expect(replies, ['\x1b[1;3R']);
  });

  test('resize keeps the cursor row on screen', () {
    final screen = fed('1\r\n2\r\n3\r\n4', rows: 4)..resize(20, 2);
    expect(screenText(screen), ['1', '2', '3', '4']);
    expect(screen.snapshot().cursor, (3, 1));
  });

  test('scroll region scrolls only inside the margins', () {
    final screen = fed('top\x1b[2;3r\x1b[2;1Ha\r\nb\r\nc', rows: 4);
    expect(screenText(screen), ['top', 'b', 'c', '']);
  });
}
