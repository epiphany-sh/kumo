import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/worktree_arrivals.dart';
import 'package:kumo_ui/data/workspace_source.dart';

/// The mock workspace with worktrees that "appeared" from a terminal.
class _ArrivingSource extends MockWorkspaceSource {
  final Set<String> _arrived = {};

  void arrive(String path) {
    _arrived.add(path);
    notifyListeners();
  }

  @override
  Set<String> get arrived => Set.unmodifiable(_arrived);

  @override
  void acknowledge(String path) {
    if (_arrived.remove(path)) notifyListeners();
  }
}

void main() {
  const repo = '/dev/engine';

  test('worktrees there at start, or made by the app, are not news', () {
    final arrivals = WorktreeArrivals();
    expect(arrivals.update([(repo, 'main', '/dev/engine'), (repo, 'feat/old', '/wt/old')]), isEmpty);

    arrivals.expect(repo, 'feat/mine ');
    final arrived = arrivals.update([
      (repo, 'main', '/dev/engine'),
      (repo, 'feat/old', '/wt/old'),
      (repo, 'feat/mine', '/wt/mine'),
      (repo, 'feat/delete', '/dev/engine-delete'),
    ]);
    expect(arrived, {'/dev/engine-delete'}, reason: 'made in a terminal');
    expect(arrivals.arrived, {'/dev/engine-delete'});

    expect(arrivals.update([(repo, 'main', '/dev/engine'), (repo, 'feat/delete', '/dev/engine-delete')]), isEmpty, reason: 'announced once');
    arrivals.acknowledge('/dev/engine-delete');
    expect(arrivals.arrived, isEmpty);
  });

  test('a worktree that disappears is no longer news', () {
    final arrivals = WorktreeArrivals()..update([(repo, 'main', '/dev/engine')]);
    arrivals.update([(repo, 'main', '/dev/engine'), (repo, 'x', '/dev/x')]);
    arrivals.update([(repo, 'main', '/dev/engine')]);
    expect(arrivals.arrived, isEmpty);
  });

  test('a creation that failed is news if git lists it later anyway', () {
    final arrivals = WorktreeArrivals()..update([(repo, 'main', '/dev/engine')]);
    arrivals
      ..expect(repo, 'feat/x')
      ..forget(repo, 'feat/x');
    expect(arrivals.update([(repo, 'main', '/dev/engine'), (repo, 'feat/x', '/dev/x')]), {'/dev/x'});
  });

  test('an arrival is announced, and opening it selects it and clears the news', () {
    final source = _ArrivingSource();
    final s = AppState(workspace: source);
    expect(s.arrivedWorktree, isNull);

    source.arrive('~/wt/price-admin/PRC-398');
    final (r, w) = s.arrivedWorktree!;
    expect((r.name, w.branch), ('price-admin', 'fix/PRC-398-rounding'));

    s.openArrivedWorktree();
    expect(s.activeWorktreeEntry?.path, '~/wt/price-admin/PRC-398');
    expect(source.arrived, isEmpty);
    expect(s.arrivedWorktree, isNull);
  });

  test('a dismissed arrival keeps its badge but leaves the toast', () {
    final source = _ArrivingSource();
    final s = AppState(workspace: source);
    source.arrive('~/wt/price-admin/PRC-398');
    s.dismissArrivedWorktree();
    expect(s.arrivedWorktree, isNull);
    expect(source.arrived, {'~/wt/price-admin/PRC-398'});
  });

  test('Changes lists the other worktrees with uncommitted files', () {
    final s = AppState();
    s.selectWorktree('feat/PRC-412-bulk-discounts', path: '~/wt/price-admin/PRC-412');
    final others = [for (final (r, w) in s.otherChangedWorktrees) '${r.name} ${w.branch} ${w.changed}'];
    expect(others, ['price-admin fix/PRC-398-rounding 2'], reason: 'not the selected one, not clean ones');
  });

  testWidgets('the sidebar announces the arrival and Changes points at it', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = _ArrivingSource();
    final s = AppState(demoWallpaper: true, workspace: source);
    await tester.pumpWidget(KumoApp(state: s));
    await tester.pump();
    s.selectWorktree('feat/PRC-412-bulk-discounts', path: '~/wt/price-admin/PRC-412');

    source.arrive('~/wt/price-admin/PRC-398');
    await tester.pump();
    expect(find.text('New worktree in price-admin'), findsOneWidget);
    expect(find.text('new'), findsOneWidget, reason: 'badge on the sidebar row');
    expect(find.text('In other worktrees'), findsOneWidget);
    expect(find.text('price-admin · 2 changed'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(s.activeWorktreeEntry?.branch, 'fix/PRC-398-rounding');
    expect(find.text('New worktree in price-admin'), findsNothing);
    expect(find.text('new'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
