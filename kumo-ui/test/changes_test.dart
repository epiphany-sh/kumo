import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/data/changes.dart';

void main() {
  final repo = MockChanges.byPath('internal/discount/repository.go')!;

  test('counts and line numbers follow the diff', () {
    expect(repo.added, 19);
    expect(repo.deleted, 7);
    expect(hunkCount(repo), 3);
    final rows = diffRows(repo);
    expect(rows.where((r) => r.isFold), isEmpty);
    expect(rows.length, repo.lines.length);
    final firstAdd = rows.firstWhere((r) => r.line!.kind == DiffKind.added);
    expect(firstAdd.oldNo, isNull);
    expect(firstAdd.newNo, 5);
    expect(firstAdd.hunk, 0);
    final lastRow = rows.last;
    expect(lastRow.newNo, repo.lines.length - repo.deleted);
  });

  test('changes-only folds unchanged runs but keeps every change', () {
    final rows = diffRows(repo, changesOnly: true);
    final folds = rows.where((r) => r.isFold).map((r) => r.fold).toList();
    expect(folds, isNotEmpty);
    final shown = rows.where((r) => !r.isFold).length;
    expect(shown + folds.fold<int>(0, (a, b) => a + b), repo.lines.length);
    expect(rows.where((r) => r.hunk != null).length, 3);
  });

  test('added files never fold', () {
    final f = MockChanges.byPath('internal/discount/bulk.go')!;
    expect(diffRows(f, changesOnly: true).where((r) => r.isFold), isEmpty);
    expect(hunkCount(f), 1);
  });

  test('file tabs open, focus and close', () {
    final s = AppState();
    s.openFile('a.go');
    s.openAllFiles(['b.go', 'c.go']);
    expect(s.openFiles, ['a.go', 'b.go', 'c.go']);
    expect(s.activeFile, 'b.go');
    s.closeFile('b.go');
    expect(s.activeFile, 'a.go');
    s.showTerminals();
    expect(s.activeFile, isNull);
    s.dispose();
  });

  test('file and context tabs belong to their worktree', () {
    final s = AppState();
    s.selectWorktree('feat/PRC-412-bulk-discounts', path: '~/wt/price-admin/PRC-412');
    s.openAllFiles(['src/DashboardContext.tsx', 'src/api.ts']);
    s.openContext(ContextTab.git);
    s.showContextFile('src/api.ts');

    s.selectWorktree('fix/PRC-398-rounding', path: '~/wt/price-admin/PRC-398');
    expect(s.openFiles, isEmpty, reason: 'those paths are inside the other worktree');
    expect(s.contextTabs, isEmpty);
    expect((s.activeFile, s.contextFile), (null, null));
    s.openFile('internal/rounding.go');

    s.selectWorktree('feat/PRC-412-bulk-discounts', path: '~/wt/price-admin/PRC-412');
    expect(s.openFiles, ['src/DashboardContext.tsx', 'src/api.ts']);
    expect((s.activeContext, s.contextFile), (ContextTab.git, 'src/api.ts'));
    s.dispose();
  });

  test('commit moves pending files onto the branch; undo restores', () {
    final s = AppState();
    expect(s.pendingChanges.length, 4);
    expect(s.branchChanges.length, 2);
    expect(s.commitsAhead, 2);
    expect(s.commit('   '), isFalse);
    expect(s.commit('feat: x', how: 'push'), isTrue);
    expect(s.pendingChanges, isEmpty);
    expect(s.branchChanges.length, 6);
    expect(s.commitsAhead, 0);
    s.undoCommit();
    expect(s.pendingChanges.length, 4);
    expect(s.commitsAhead, 2);
    s.dispose();
  });

  test('widgets reorder like ReorderableListView', () {
    final s = AppState();
    s.reorderWidget(0, 4); // agent to the end
    expect(s.widgets, [InspectorWidget.pipelines, InspectorWidget.changes, InspectorWidget.context, InspectorWidget.agent]);
    s.moveWidget(InspectorWidget.agent, -1);
    expect(s.widgets.last, InspectorWidget.context);
    s.addWidget(InspectorWidget.tests);
    s.removeWidget(InspectorWidget.changes);
    expect(s.widgets, [InspectorWidget.pipelines, InspectorWidget.agent, InspectorWidget.context, InspectorWidget.tests]);
    expect(s.availableWidgets, containsAll([InspectorWidget.changes, InspectorWidget.pullRequest, InspectorWidget.activity]));
    s.dispose();
  });
}
