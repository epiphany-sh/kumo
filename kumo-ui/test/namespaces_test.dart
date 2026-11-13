import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/data/mock_data.dart';

void main() {
  test('starts with platform and identity', () {
    final s = AppState();
    expect(s.namespaces.map((n) => n.name), ['platform', 'identity']);
    s.dispose();
  });

  test('create, rename, collapse, edit repos', () {
    final s = AppState();
    final id = s.createNamespace('  catalog ', ['catalog-api']);
    expect(s.namespaceById(id)!.name, 'catalog');
    s.renameNamespace(id, 'catalog-team');
    expect(s.namespaceById(id)!.name, 'catalog-team');
    s.renameNamespace(id, '   ');
    expect(s.namespaceById(id)!.name, 'catalog-team', reason: 'blank names are ignored');
    s.toggleNamespaceCollapsed(id);
    expect(s.namespaceById(id)!.collapsed, isTrue);
    s.updateNamespace(id, repos: ['catalog-api', 'kumo']);
    expect(s.namespaceById(id)!.repos, ['catalog-api', 'kumo']);
    expect(Mock.repoNamed('kumo'), isNotNull);
    s.dispose();
  });

  test('delete namespace is undoable and keeps its position', () {
    final s = AppState();
    s.deleteNamespace('platform');
    expect(s.namespaces.map((n) => n.id), ['identity']);
    expect(s.undo, isNotNull);
    s.undoLast();
    expect(s.namespaces.map((n) => n.id), ['platform', 'identity']);
    expect(s.undo, isNull);
    s.dispose();
  });

  test('delete worktree hides it, main is protected, undo restores', () {
    final s = AppState();
    final repo = Mock.repoNamed('repo-a')!;
    s.deleteWorktree('repo-a', 'main');
    expect(s.worktreesOf(repo).length, 3);
    s.deleteWorktree('repo-a', 'feat/TSK-412-bulk-discounts');
    expect(s.worktreesOf(repo).map((w) => w.branch), ['main', 'fix/TSK-398-rounding']);
    expect(s.activeWorktree, 'main', reason: 'active worktree falls back to the principal checkout');
    s.undoLast();
    expect(s.worktreesOf(repo).length, 3);
    s.dispose();
  });
}
