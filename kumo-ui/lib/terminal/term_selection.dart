import 'package:flutter/foundation.dart';

import 'cell_width.dart';
import 'terminal_surface.dart';

/// A position between cells: [line] indexes [TermBuffer.lines], [col] is
/// the boundary before that cell (0 … the line's width).
@immutable
class TermPoint implements Comparable<TermPoint> {
  const TermPoint(this.line, this.col);
  final int line;
  final int col;

  @override
  int compareTo(TermPoint other) => line != other.line ? line.compareTo(other.line) : col.compareTo(other.col);

  @override
  bool operator ==(Object other) => other is TermPoint && other.line == line && other.col == col;

  @override
  int get hashCode => Object.hash(line, col);

  @override
  String toString() => '($line, $col)';
}

/// Selected text of a terminal, from where the drag started ([anchor]) to
/// where it is ([extent]), in either direction.
@immutable
class TermSelection {
  const TermSelection(this.anchor, this.extent);
  final TermPoint anchor;
  final TermPoint extent;

  TermPoint get start => anchor.compareTo(extent) <= 0 ? anchor : extent;
  TermPoint get end => anchor.compareTo(extent) <= 0 ? extent : anchor;
  bool get isEmpty => anchor == extent;

  /// The same text after [by] lines were added (or, negative, dropped)
  /// above it.
  TermSelection shifted(int by) => by == 0 ? this : TermSelection(TermPoint(anchor.line + by, anchor.col), TermPoint(extent.line + by, extent.col));

  /// Selected cells of [line] as [from, to), or null when none. [width] is
  /// the line's width in cells; whole lines in the middle reach it.
  (int, int)? cellsOn(int line, int width) {
    if (isEmpty || line < start.line || line > end.line) return null;
    final from = line == start.line ? start.col : 0;
    final to = line == end.line ? end.col : width;
    return to > from ? (from, to) : (line < end.line ? (from, from) : null);
  }

  @override
  bool operator ==(Object other) => other is TermSelection && other.anchor == anchor && other.extent == extent;

  @override
  int get hashCode => Object.hash(anchor, extent);
}

/// Code points of [line] with the cell each starts at.
List<(int, int)> _cells(TermLine line) {
  final out = <(int, int)>[];
  var col = 0;
  for (final span in line.spans) {
    for (final rune in span.text.runes) {
      final w = termCellWidth(rune);
      if (w == 0) {
        // Combining marks stay with the cell before them.
        if (out.isNotEmpty) out.add((rune, out.last.$2));
        continue;
      }
      out.add((rune, col));
      col += w;
    }
  }
  return out;
}

/// Width of [line] in cells, trailing blanks excluded.
int lineWidth(TermLine line) {
  var width = 0;
  for (final (rune, col) in _cells(line)) {
    if (rune != 0x20) width = col + termCellWidth(rune).clamp(1, 2);
  }
  return width;
}

/// The selected text: lines joined with \n, trailing blanks trimmed.
String selectedText(List<TermLine> lines, TermSelection sel) {
  if (sel.isEmpty) return '';
  final out = <String>[];
  final last = sel.end.line.clamp(0, lines.length - 1);
  for (var l = sel.start.line.clamp(0, lines.length - 1); l <= last; l++) {
    final line = lines[l];
    final range = sel.cellsOn(l, 1 << 20);
    if (range == null) continue;
    final (from, to) = range;
    final buf = StringBuffer();
    for (final (rune, col) in _cells(line)) {
      if (col >= from && col < to) buf.writeCharCode(rune);
    }
    out.add(buf.toString().replaceFirst(RegExp(r' +$'), ''));
  }
  return out.join('\n');
}

bool _isWordRune(int r) {
  if (r == 0x20) return false;
  const stops = '()[]{}<>"\'`,;|│';
  return !stops.runes.contains(r);
}

/// Double-click: the word (path, URL, flag…) around [p]; nothing on blanks.
TermSelection wordAt(List<TermLine> lines, TermPoint p) {
  if (p.line < 0 || p.line >= lines.length) return TermSelection(p, p);
  final cells = _cells(lines[p.line]);
  final i = cells.lastIndexWhere((c) => c.$2 <= p.col);
  if (i < 0 || !_isWordRune(cells[i].$1)) return TermSelection(p, p);
  var a = i;
  var b = i;
  while (a > 0 && _isWordRune(cells[a - 1].$1)) {
    a--;
  }
  while (b < cells.length - 1 && _isWordRune(cells[b + 1].$1)) {
    b++;
  }
  // Sentence punctuation at the end isn't part of a path or URL.
  while (b > a && '.:'.runes.contains(cells[b].$1)) {
    b--;
  }
  final end = cells[b].$2 + termCellWidth(cells[b].$1).clamp(1, 2);
  return TermSelection(TermPoint(p.line, cells[a].$2), TermPoint(p.line, end));
}

/// Triple-click: the whole line.
TermSelection lineAt(List<TermLine> lines, int line) {
  if (line < 0 || line >= lines.length) return TermSelection(TermPoint(line, 0), TermPoint(line, 0));
  return TermSelection(TermPoint(line, 0), TermPoint(line, lineWidth(lines[line])));
}

final _url = RegExp(r'''(?:https?|obsidian|bear|todoist)://[^\s<>"'`│]+''');

/// Shift/⌘-click: the URL under [p] (`http://localhost:3000/` from a dev
/// server and the like) with the cells it covers; null off a link.
(TermSelection, String)? linkAt(List<TermLine> lines, TermPoint p) {
  if (p.line < 0 || p.line >= lines.length) return null;
  final cells = _cells(lines[p.line]);
  final text = String.fromCharCodes(cells.map((c) => c.$1));
  // Code units of [text] → cells; runes past the BMP take two units.
  final at = <int>[];
  for (final (rune, col) in cells) {
    at.add(col);
    if (rune > 0xffff) at.add(col);
  }
  for (final m in _url.allMatches(text)) {
    var url = m.group(0)!;
    // Sentence punctuation and an unbalanced closing bracket at the end
    // aren't part of it: "(see http://x/a)." opens http://x/a.
    while (url.isNotEmpty) {
      final last = url[url.length - 1];
      final unbalanced = (last == ')' && '('.allMatches(url).length < ')'.allMatches(url).length) ||
          (last == ']' && '['.allMatches(url).length < ']'.allMatches(url).length);
      if (!'.,:;!?'.contains(last) && !unbalanced) break;
      url = url.substring(0, url.length - 1);
    }
    final end = m.start + url.length;
    if (!url.contains(RegExp(r'://.')) || at[m.start] > p.col) continue;
    final to = at[end - 1] + termCellWidth(url.runes.last).clamp(1, 2);
    if (p.col >= to) continue;
    return (TermSelection(TermPoint(p.line, at[m.start]), TermPoint(p.line, to)), url);
  }
  return null;
}
