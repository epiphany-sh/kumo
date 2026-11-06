/// Columns, tab stops and indentation guides of a code buffer.
///
/// Flutter draws a tab as wide as one space, so code indented with tabs
/// (Go, Makefiles) loses its shape. The editor widens each tab to the next
/// stop and draws a vertical guide per indentation level; this file holds
/// the arithmetic, kept apart from the widgets so it can be tested.
library;

/// Columns between tab stops.
const kTabSize = 4;

/// Columns a tab at [column] takes: up to the next stop.
int tabAdvance(int column, {int tabSize = kTabSize}) => tabSize - column % tabSize;

/// Width of [line] in columns, with tabs expanded to their stops.
int visualWidth(String line, {int tabSize = kTabSize}) {
  var col = 0;
  for (final u in line.codeUnits) {
    col += u == 0x09 ? tabAdvance(col, tabSize: tabSize) : 1;
  }
  return col;
}

/// Leading whitespace of [line] in columns; null when the line is blank.
int? indentOf(String line, {int tabSize = kTabSize}) {
  var col = 0;
  for (final u in line.codeUnits) {
    if (u == 0x09) {
      col += tabAdvance(col, tabSize: tabSize);
    } else if (u == 0x20) {
      col++;
    } else {
      return col;
    }
  }
  return null;
}

/// A vertical guide: at [column], from line [first] to [last] (0-based,
/// inclusive).
typedef Guide = ({int column, int first, int last});

/// The indentation of every line, and the guides it draws.
class IndentGuides {
  IndentGuides._(this.unit, this.depth);

  factory IndentGuides.of(List<String> lines, {int tabSize = kTabSize}) {
    final raw = [for (final l in lines) indentOf(l, tabSize: tabSize)];
    // Blank lines take the shallower of their neighbours, so a blank line
    // inside a block keeps its guides and one between blocks has none.
    final depth = List<int>.filled(lines.length, 0);
    int? prev;
    for (var i = 0; i < lines.length; i++) {
      if (raw[i] != null) prev = raw[i];
      depth[i] = raw[i] ?? prev ?? 0;
    }
    int? next;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (raw[i] != null) {
        next = raw[i];
      } else {
        depth[i] = next == null ? 0 : (depth[i] < next ? depth[i] : next);
      }
    }
    return IndentGuides._(_unitOf(lines, raw, tabSize), depth);
  }

  /// Columns per indentation level.
  final int unit;

  /// Indentation of each line in columns.
  final List<int> depth;

  /// The columns of the guides that cross line [i].
  Iterable<int> columnsAt(int i) sync* {
    for (var col = 0; col < depth[i]; col += unit) {
      yield col;
    }
  }

  /// The guide of the block around line [line]: the body it opens, the one
  /// it closes, or the one it sits in. Null at the top level.
  Guide? activeAt(int line) {
    if (line < 0 || line >= depth.length) return null;
    final d = depth[line];
    // A line followed by deeper ones opens that block (`if x {`).
    if (line + 1 < depth.length && depth[line + 1] > d) return _span(d, line + 1);
    // A line after deeper ones closes it (`}`).
    if (line > 0 && depth[line - 1] > d) return _span(d, line - 1);
    if (d == 0) return null;
    return _span((d - 1) ~/ unit * unit, line);
  }

  /// The run of lines deeper than [column] around [from].
  Guide _span(int column, int from) {
    var first = from;
    var last = from;
    while (first > 0 && depth[first - 1] > column) {
      first--;
    }
    while (last + 1 < depth.length && depth[last + 1] > column) {
      last++;
    }
    return (column: column, first: first, last: last);
  }

  /// Tabs indent by [tabSize]; spaces by the smallest indentation used,
  /// within reason (2 to 8). One space is the ` *` of a block comment, not
  /// a level.
  static int _unitOf(List<String> lines, List<int?> raw, int tabSize) {
    var smallest = 0;
    for (var i = 0; i < lines.length; i++) {
      final d = raw[i];
      if (d == null || d == 0) continue;
      if (lines[i].startsWith('\t')) return tabSize;
      if (d >= 2 && (smallest == 0 || d < smallest)) smallest = d;
    }
    return smallest == 0 || smallest > 8 ? tabSize : smallest;
  }
}
