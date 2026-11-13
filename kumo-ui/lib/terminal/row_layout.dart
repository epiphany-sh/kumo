import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'command_marks.dart';
import 'term_selection.dart';
import 'terminal_surface.dart';

/// Room above each prompt and between a command and its output, so the
/// mark on what you ran never touches the lines around it.
const commandGap = 10.0;

/// A prompt on two lines, the first with something only on its right
/// (oh-my-posh, a right prompt) and the second with what you typed on its
/// left: the two are drawn as one row, centered in the command's mark,
/// when they don't overlap (a long command keeps them apart). A blank
/// first line just centers the second.
bool foldsPrompt(TermBuffer b, CommandBlock block) {
  if (block.commandLines != 2 || block.start < 0 || block.start + 1 >= b.lines.length) return false;
  final right = firstInk(b.lines[block.start]);
  return right == null || lineWidth(b.lines[block.start + 1]) + 2 <= right;
}

/// How far line [i] is drawn from its place (see [foldsPrompt]): half a
/// line down for a folded prompt's first line, half up for its second.
double foldShift(TermBuffer b, int i, double lineExtent) {
  final block = blockAt(b.blocks, i);
  if (block == null || !foldsPrompt(b, block)) return 0;
  return i == block.start ? lineExtent / 2 : -lineExtent / 2;
}

/// The line drawn at cell [col] of line [i], which is the other one of a
/// folded prompt where that one has its characters (see [foldsPrompt]).
int foldedLineAt(TermBuffer b, int i, int col) {
  final block = blockAt(b.blocks, i);
  if (block == null || !foldsPrompt(b, block)) return i;
  final right = firstInk(b.lines[block.start]);
  return right != null && col >= right - 1 ? block.start : block.start + 1;
}

/// Where the lines of a buffer sit, top to bottom, when the commands you
/// ran get room around them ([commandGap]). The shell's grid doesn't
/// change: only where its lines are drawn.
///
/// A line's slot is its gap, if it has one, then the line. A position is a
/// line and how far into its slot (0 at the top of its gap): the view's
/// top is one, so scrolling stays in lines as without gaps.
@immutable
class RowLayout {
  const RowLayout.none(this.lineExtent)
      : gap = 0,
        _gaps = const [];

  const RowLayout._(this.lineExtent, this.gap, this._gaps);

  /// [b]'s lines, with a gap above every prompt and above every command's
  /// output (none above the first line).
  factory RowLayout.of(TermBuffer b, double lineExtent, {double gap = commandGap}) {
    if (gap <= 0 || (b.blocks.isEmpty && b.prompts.isEmpty)) return RowLayout.none(lineExtent);
    final lines = <int>{
      ...b.prompts,
      for (final block in b.blocks) ...[block.start, block.outputStart],
    }.where((line) => line > 0).toList()
      ..sort();
    return lines.isEmpty ? RowLayout.none(lineExtent) : RowLayout._(lineExtent, gap, lines);
  }

  final double lineExtent;
  final double gap;

  /// Lines with a gap above, in order.
  final List<int> _gaps;

  bool get isEmpty => _gaps.isEmpty;

  /// Gaps above lines before [line].
  int _before(int line) {
    var lo = 0, hi = _gaps.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_gaps[mid] < line) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  bool hasGap(int line) {
    final i = _before(line);
    return i < _gaps.length && _gaps[i] == line;
  }

  /// Top of [line]'s slot (its gap), from the top of line 0.
  double slotTop(int line) => line * lineExtent + gap * _before(line);

  double slotExtent(int line) => lineExtent + (hasGap(line) ? gap : 0);

  /// Top of [line] itself, past its gap.
  double lineTop(int line) => slotTop(line) + (hasGap(line) ? gap : 0);

  /// Where [position] is, from the top of line 0.
  double yOf(num position) {
    final line = position.floor();
    return slotTop(line) + (position - line) * slotExtent(line);
  }

  /// The position at [y] from the top of line 0 (the inverse of [yOf]).
  double positionAt(double y) {
    if (y <= 0) return y / lineExtent;
    // Slots are at least a line tall: the line is at most y / lineExtent.
    var lo = 0, hi = (y / lineExtent).floor() + 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (slotTop(mid) <= y) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo + math.min(1.0, (y - slotTop(lo)) / slotExtent(lo));
  }
}
