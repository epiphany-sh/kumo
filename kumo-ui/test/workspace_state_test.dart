import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/data/workspace_source.dart';

/// The mock workspace, recording what would reach the daemon.
class _RecordingSource extends MockWorkspaceSource {
  final removed = <String>[];
  final deletedNamespaces = <String>[];

  /// What git answers; the default removes it.
  WorktreeRemoval answer = const WorktreeRemoval();
  final forced = <bool>[];
  final branchesToo = <bool>[];

  @override
  Future<WorktreeRemoval> removeWorktree(Repo repo, Worktree worktree, {bool force = false, bool deleteBranch = false}) async {
    removed.add(worktree.path);
    forced.add(force);
    branchesToo.add(deleteBranch);
    return answer;
  }

  @override
  void deleteNamespace(String id) {
    deletedNamespaces.add(id);
    super.deleteNamespace(id);
  }
}

void main() {
  const feature = 'feat/PRC-412-bulk-discounts';

  test('removing a worktree reaches git only when the undo window closes', () async {
    final source = _RecordingSource();
    final s = AppState(workspace: source);
    final repo = source.repo('price-admin')!;

    s.deleteWorktree('price-admin', feature);
    expect(s.worktreesOf(repo).map((w) => w.branch), isNot(contains(feature)), reason: 'hidden at once');
    expect(source.removed, isEmpty, reason: 'nothing destructive while undo is possible');

    s.undoLast();
    expect(source.removed, isEmpty);
    expect(s.worktreesOf(repo).map((w) => w.branch), contains(feature));

    s.deleteWorktree('price-admin', feature);
    s.dismissUndo(); // what the 8 s timer does
    await Future<void>.delayed(Duration.zero);
    expect(source.removed, ['~/wt/price-admin/PRC-412']);
    s.dispose();
  });

  test('a worktree with changes comes back with an offer to delete it anyway', () async {
    final source = _RecordingSource()..answer = const WorktreeRemoval(removed: false, changedFiles: 2);
    final s = AppState(workspace: source);
    final repo = source.repo('price-admin')!;

    s.deleteWorktree('price-admin', feature, deleteBranch: true);
    s.dismissUndo();
    await Future<void>.delayed(Duration.zero);
    expect(s.worktreesOf(repo).map((w) => w.branch), contains(feature), reason: 'git kept it');
    expect(s.undo?.message, '“$feature” has 2 changed files');
    expect(s.undo?.action, 'Delete anyway');

    source.answer = const WorktreeRemoval();
    s.undoLast(); // "Delete anyway": hidden again, with its own undo window
    expect(s.worktreesOf(repo).map((w) => w.branch), isNot(contains(feature)));
    expect(s.undo?.action, 'Undo');
    s.dismissUndo();
    await Future<void>.delayed(Duration.zero);
    expect(source.forced, [false, true]);
    expect(source.branchesToo, [true, true], reason: 'the branch choice carries over');
    s.dispose();
  });

  test('a branch git keeps is said, with nothing to undo', () async {
    final source = _RecordingSource()..answer = const WorktreeRemoval(branchKept: "branch $feature has commits that aren't merged");
    final s = AppState(workspace: source);
    s.deleteWorktree('price-admin', feature, deleteBranch: true);
    s.dismissUndo();
    await Future<void>.delayed(Duration.zero);
    expect(s.undo?.message, "Branch $feature has commits that aren't merged: kept");
    expect(s.undo?.action, isNull);
    s.dispose();
  });

  test('a new undoable action commits the previous one', () {
    final source = _RecordingSource();
    final s = AppState(workspace: source);
    s.deleteNamespace('pricing');
    expect(source.deletedNamespaces, isEmpty);
    s.deleteNamespace('identity');
    expect(source.deletedNamespaces, ['pricing']);
    s.undoLast();
    expect(source.deletedNamespaces, ['pricing'], reason: 'identity was restored, never deleted');
    expect(s.namespaces.map((n) => n.id), ['identity']);
    s.dispose();
  });

  test('worktrees are selected by path: the same branch in two repos is not ambiguous', () {
    final s = AppState();
    final reader = s.workspace.repo('price-reader-v2')!;
    final main = reader.worktrees.firstWhere((w) => w.isMain);
    s.selectWorktree(main.branch, path: main.path);
    expect(s.activeRepo?.name, 'price-reader-v2');
    final adminMain = s.workspace.repo('price-admin')!.worktrees.firstWhere((w) => w.isMain);
    expect(s.isActiveWorktree(adminMain), isFalse, reason: 'also "main", other repo');
    s.dispose();
  });
}
