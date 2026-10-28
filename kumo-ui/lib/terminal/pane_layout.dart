import 'package:flutter/foundation.dart';

/// Split layout of the Terminal view: columns side by side, each one a stack
/// of panes. ⌘D adds a column to the right of the focused pane, ⌘⇧D adds a
/// pane under it, ⌘W removes it. Weights are relative sizes; splitter drags
/// move weight between the two neighbours only, so the rest stay put.
///
/// Immutable: every operation returns a new layout (cheap, a handful of
/// panes), which keeps undo and tests trivial.
@immutable
class PaneLayout {
  const PaneLayout(this.columns);

  final List<PaneColumn> columns;

  /// No pane may shrink below this share of its row / column.
  static const minShare = 0.14;

  static const initial = PaneLayout([
    PaneColumn('c1', 1.38, [PaneCell('agent', 1)]),
    PaneColumn('c2', 1, [PaneCell('tests', 1), PaneCell('logs', 1)]),
  ]);

  bool get isEmpty => columns.isEmpty;

  /// Pane ids in reading order (left to right, top to bottom).
  List<String> get panes => [for (final c in columns) for (final p in c.cells) p.id];

  bool contains(String id) => locate(id) != null;

  /// (column index, row index) of [id].
  (int, int)? locate(String id) {
    for (var ci = 0; ci < columns.length; ci++) {
      final ri = columns[ci].cells.indexWhere((p) => p.id == id);
      if (ri >= 0) return (ci, ri);
    }
    return null;
  }

  /// New column with [newId] right after the column of [target] (or at the
  /// end). The target column gives up half its width.
  PaneLayout splitRight(String? target, String newId, {required String columnId}) {
    final at = target == null ? null : locate(target);
    final cols = [...columns];
    if (at == null) {
      final w = cols.isEmpty ? 1.0 : cols.map((c) => c.weight).reduce((a, b) => a + b) / cols.length;
      cols.add(PaneColumn(columnId, w, [PaneCell(newId, 1)]));
    } else {
      final src = cols[at.$1];
      final half = src.weight / 2;
      cols[at.$1] = src.copyWith(weight: half);
      cols.insert(at.$1 + 1, PaneColumn(columnId, half, [PaneCell(newId, 1)]));
    }
    return PaneLayout(cols);
  }

  /// [newId] right under [target] in the same column (or at the bottom of
  /// the last column). The target pane gives up half its height.
  PaneLayout splitDown(String? target, String newId, {required String columnId}) {
    final at = target == null ? null : locate(target);
    final cols = [...columns];
    if (at == null) {
      if (cols.isEmpty) return PaneLayout([PaneColumn(columnId, 1, [PaneCell(newId, 1)])]);
      final last = cols.last;
      cols[cols.length - 1] = last.copyWith(cells: [...last.cells, PaneCell(newId, 1)]);
    } else {
      final col = cols[at.$1];
      final cells = [...col.cells];
      final half = cells[at.$2].weight / 2;
      cells[at.$2] = PaneCell(cells[at.$2].id, half);
      cells.insert(at.$2 + 1, PaneCell(newId, half));
      cols[at.$1] = col.copyWith(cells: cells);
    }
    return PaneLayout(cols);
  }

  /// Removes [id]; an emptied column goes away too.
  PaneLayout remove(String id) {
    final at = locate(id);
    if (at == null) return this;
    final cols = [...columns];
    final cells = [...cols[at.$1].cells]..removeAt(at.$2);
    if (cells.isEmpty) {
      cols.removeAt(at.$1);
    } else {
      cols[at.$1] = cols[at.$1].copyWith(cells: cells);
    }
    return PaneLayout(cols);
  }

  /// Where focus goes after closing [id]: the pane above it, else below it,
  /// else the first pane of the neighbouring column.
  String? focusAfterRemoving(String id) {
    final at = locate(id);
    if (at == null) return panes.isEmpty ? null : panes.first;
    final cells = columns[at.$1].cells;
    if (cells.length > 1) return cells[at.$2 > 0 ? at.$2 - 1 : 1].id;
    if (columns.length == 1) return null;
    final ci = at.$1 > 0 ? at.$1 - 1 : 1;
    return columns[ci].cells.first.id;
  }

  /// Splitter between column [index] - 1 and [index] moved by [delta] pixels
  /// out of [extent] pixels of total width.
  PaneLayout resizeColumns(int index, double delta, double extent) {
    if (index <= 0 || index >= columns.length || extent <= 0) return this;
    final total = columns.fold<double>(0, (s, c) => s + c.weight);
    final (a, b) = _shift(columns[index - 1].weight, columns[index].weight, delta / extent * total, total * minShare);
    final cols = [...columns];
    cols[index - 1] = cols[index - 1].copyWith(weight: a);
    cols[index] = cols[index].copyWith(weight: b);
    return PaneLayout(cols);
  }

  /// Splitter between rows [index] - 1 and [index] of [column] moved by
  /// [delta] pixels out of [extent] pixels of column height.
  PaneLayout resizeRows(int column, int index, double delta, double extent) {
    if (column < 0 || column >= columns.length) return this;
    final cells = [...columns[column].cells];
    if (index <= 0 || index >= cells.length || extent <= 0) return this;
    final total = cells.fold<double>(0, (s, c) => s + c.weight);
    final (a, b) = _shift(cells[index - 1].weight, cells[index].weight, delta / extent * total, total * minShare);
    cells[index - 1] = PaneCell(cells[index - 1].id, a);
    cells[index] = PaneCell(cells[index].id, b);
    final cols = [...columns];
    cols[column] = cols[column].copyWith(cells: cells);
    return PaneLayout(cols);
  }

  /// Double-click on a splitter: equal shares again.
  PaneLayout evenColumns() => PaneLayout([for (final c in columns) c.copyWith(weight: 1)]);

  PaneLayout evenRows(int column) {
    if (column < 0 || column >= columns.length) return this;
    final cols = [...columns];
    cols[column] = cols[column].copyWith(cells: [for (final p in cols[column].cells) PaneCell(p.id, 1)]);
    return PaneLayout(cols);
  }

  static (double, double) _shift(double a, double b, double d, double min) {
    final pair = a + b;
    final lo = min < pair / 2 ? min : pair / 2;
    var na = a + d;
    if (na < lo) na = lo;
    if (na > pair - lo) na = pair - lo;
    return (na, pair - na);
  }
}

@immutable
class PaneColumn {
  const PaneColumn(this.id, this.weight, this.cells);
  final String id;
  final double weight;
  final List<PaneCell> cells;

  PaneColumn copyWith({double? weight, List<PaneCell>? cells}) => PaneColumn(id, weight ?? this.weight, cells ?? this.cells);
}

@immutable
class PaneCell {
  const PaneCell(this.id, this.weight);
  final String id;
  final double weight;
}
