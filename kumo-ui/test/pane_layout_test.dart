import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/terminal/pane_layout.dart';

String shape(PaneLayout l) => l.columns.map((c) => c.cells.map((p) => p.id).join('+')).join(' | ');

void main() {
  test('initial layout: agent | tests+logs', () {
    expect(shape(PaneLayout.initial), 'agent | tests+logs');
    expect(PaneLayout.initial.panes, ['agent', 'tests', 'logs']);
  });

  test('split right inserts a column after the target and halves it', () {
    final l = PaneLayout.initial.splitRight('agent', 'sh-1', columnId: 'x');
    expect(shape(l), 'agent | sh-1 | tests+logs');
    expect(l.columns[0].weight, closeTo(0.69, 1e-9));
    expect(l.columns[1].weight, closeTo(0.69, 1e-9));
  });

  test('split down inserts under the target in the same column', () {
    final l = PaneLayout.initial.splitDown('tests', 'sh-1', columnId: 'x');
    expect(shape(l), 'agent | tests+sh-1+logs');
    expect(l.columns[1].cells[0].weight, 0.5);
    expect(l.columns[1].cells[1].weight, 0.5);
  });

  test('split with no target appends', () {
    expect(shape(PaneLayout.initial.splitDown(null, 'sh-1', columnId: 'x')), 'agent | tests+logs+sh-1');
    expect(shape(PaneLayout.initial.splitRight(null, 'sh-1', columnId: 'x')), 'agent | tests+logs | sh-1');
    expect(shape(const PaneLayout([]).splitDown(null, 'sh-1', columnId: 'x')), 'sh-1');
  });

  test('remove drops empty columns and picks a neighbour for focus', () {
    final l = PaneLayout.initial;
    expect(l.focusAfterRemoving('logs'), 'tests');
    expect(l.focusAfterRemoving('tests'), 'logs');
    expect(l.focusAfterRemoving('agent'), 'tests');
    expect(shape(l.remove('agent')), 'tests+logs');
    final empty = l.remove('agent').remove('tests').remove('logs');
    expect(empty.isEmpty, isTrue);
    expect(empty.focusAfterRemoving('nope'), isNull);
  });

  test('resizing moves weight between neighbours and respects the minimum', () {
    final l = PaneLayout.initial.resizeRows(1, 1, 160, 800); // 20% of 2.0 = 0.4
    expect(l.columns[1].cells[0].weight, closeTo(1.4, 1e-9));
    expect(l.columns[1].cells[1].weight, closeTo(0.6, 1e-9));
    final squeezed = PaneLayout.initial.resizeColumns(1, 5000, 1000);
    final total = squeezed.columns.fold<double>(0, (s, c) => s + c.weight);
    expect(squeezed.columns[1].weight, closeTo(total * PaneLayout.minShare, 1e-9));
    expect(PaneLayout.initial.resizeColumns(0, 10, 100), same(PaneLayout.initial));
  });

  test('even resets weights', () {
    final l = PaneLayout.initial.resizeRows(1, 1, 100, 800).evenRows(1).evenColumns();
    expect(l.columns.every((c) => c.weight == 1), isTrue);
    expect(l.columns[1].cells.every((p) => p.weight == 1), isTrue);
  });
}
