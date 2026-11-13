import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/terminal/ansi_screen.dart';
import 'package:kumo_ui/terminal/command_marks.dart';
import 'package:kumo_ui/terminal/row_layout.dart';
import 'package:kumo_ui/terminal/terminal_surface.dart';
import 'package:kumo_ui/terminal/terminal_view.dart';

/// Lines `0..count-1`, with prompts and commands where the shell marked
/// them.
TermBuffer _buffer(int count, {List<int> prompts = const [], List<CommandBlock> blocks = const []}) =>
    TermBuffer([for (var i = 0; i < count; i++) TermLine.empty], cursor: (count - 1, 0), prompts: prompts, blocks: blocks);

void main() {
  const e = 15.0;

  test('without marks, lines are a plain grid', () {
    final layout = RowLayout.of(_buffer(5), e);
    expect(layout.isEmpty, isTrue);
    expect(layout.lineTop(3), 3 * e);
    expect(layout.positionAt(3.5 * e), 3.5);
  });

  test('a prompt and its output get room above them', () {
    // Prompt on line 2, its command's output from line 3.
    final b = _buffer(6, prompts: [2], blocks: const [CommandBlock(start: 2, outputStart: 3, end: 5)]);
    final layout = RowLayout.of(b, e);
    expect(layout.lineTop(1), 1 * e);
    expect(layout.lineTop(2), 2 * e + commandGap);
    expect(layout.lineTop(3), 3 * e + 2 * commandGap);
    expect(layout.lineTop(4), 4 * e + 2 * commandGap);
    // The gap above a line belongs to its slot.
    expect(layout.slotTop(2), 2 * e);
    expect(layout.positionAt(2 * e + commandGap / 2), closeTo(2 + (commandGap / 2) / (e + commandGap), 1e-9));
    for (final p in [0.0, 1.5, 2.0, 2.3, 3.0, 4.75]) {
      expect(layout.positionAt(layout.yOf(p)), closeTo(p, 1e-9), reason: '$p');
    }
  });

  test('the first line gets no room above it', () {
    final layout = RowLayout.of(_buffer(3, prompts: [0]), e);
    expect(layout.isEmpty, isTrue);
  });

  test('at the bottom, the last rows still fit: the gaps push the top out', () {
    // 10 lines on a 4-row screen, a command at 7 with output from 8.
    final b = _buffer(10, prompts: [7], blocks: const [CommandBlock(start: 7, outputStart: 8)]);
    final layout = RowLayout.of(b, e);
    final top = bottomTop(b, 4, layout);
    expect(top, greaterThan(6));
    expect(layout.slotTop(10) - layout.yOf(top), closeTo(4 * e, 1e-9));
    // Without gaps, the bottom is where it always was.
    expect(bottomTop(b, 4), 6);
    expect(visibleStart(b, 4), 6);
    expect(visibleOffset(b, 4), 0);
  });

  test('the screen reports the prompts it marked', () {
    final screen = AnsiScreen(cols: 20, rows: 6);
    screen.feed(utf8.encode('\x1b]133;A\x07\$ ls\r\n\x1b]133;C\x07a b\r\n\x1b]133;D;0\x07\x1b]133;A\x07\$ \r\n\x1b]133;A\x07\$ '));
    final b = screen.snapshot();
    expect(b.prompts, [0, 2, 3]);
    expect(b.blocks.single.start, 0);
  });

  group('a two-line prompt', () {
    TermBuffer prompt(String first, String second) => TermBuffer(
          [TermLine([TermSpan(first)]), TermLine([TermSpan(second)]), TermLine.empty],
          cursor: (2, 0),
          prompts: const [0],
          blocks: const [CommandBlock(start: 0, outputStart: 2, end: 3)],
        );

    test('folds into one row when its sides don\'t overlap', () {
      final b = prompt('                    kumo  main', 'zh > ls');
      expect(foldsPrompt(b, b.blocks.single), isTrue);
      expect(foldShift(b, 0, e), e / 2);
      expect(foldShift(b, 1, e), -e / 2);
      expect(foldShift(b, 2, e), 0, reason: 'output stays put');
      // A click finds the line that has characters there.
      expect(foldedLineAt(b, 0, 2), 1);
      expect(foldedLineAt(b, 1, 22), 0);
    });

    test('stays on two lines when what you typed reaches the right side', () {
      final b = prompt('          kumo', 'zh > git commit -m "a long message"');
      expect(foldsPrompt(b, b.blocks.single), isFalse);
      expect(foldShift(b, 1, e), 0);
    });
  });
}
