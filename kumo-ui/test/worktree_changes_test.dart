import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/data/workspace_source.dart';
import 'package:kumo_ui/data/worktree_changes.dart';

/// A real-looking workspace: two repos whose main checkouts are both "main".
class _TwoRepos extends MockWorkspaceSource {
  static const _a = Repo(name: 'a', host: 'LO', path: '/r/a', worktrees: [
    Worktree(branch: 'main', note: '', tone: WorktreeTone.idle, path: '/r/a', principal: true),
    Worktree(branch: 'feat/x', note: '', tone: WorktreeTone.idle, path: '/wt/a/x', principal: false),
  ]);
  static const _b = Repo(name: 'b', host: 'LO', path: '/r/b', worktrees: [
    Worktree(branch: 'main', note: '', tone: WorktreeTone.idle, path: '/r/b', principal: true),
  ]);

  _TwoRepos() {
    saveNamespace(name: 'team', repos: ['/r/a', '/r/b']);
  }

  @override
  Repo? repo(String id) => {'/r/a': _a, '/r/b': _b}[id];
}

class _Recorded extends NoWorktreeChanges {
  _Recorded(this.path);
  final String path;
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  test('builds a folder tree: folders first, then files, by name', () {
    final tree = buildTree(['b.txt', 'src/z.rs', 'src/a/m.rs', 'a.txt']);
    expect([for (final n in tree) n.name], ['src', 'a.txt', 'b.txt']);
    expect([for (final n in tree.first.children!) n.name], ['a', 'z.rs']);
    expect(tree.first.children!.first.children!.single.name, 'm.rs');
  });

  test('each selected worktree gets its own changes; the previous one is disposed', () {
    final created = <_Recorded>[];
    final s = AppState(
      workspace: _TwoRepos(),
      changesFor: (path) => _Recorded(path)..also(created.add),
    );
    s.workspace.notifyListeners(); // the first snapshot arrives
    expect(created.map((c) => c.path), ['/r/a'], reason: 'first main checkout is selected');

    s.selectWorktree('main', path: '/r/b');
    expect(created.map((c) => c.path), ['/r/a', '/r/b'], reason: 'same branch name, other repo');
    expect(created.first.disposed, isTrue);
    expect(identical(s.changes, created.last), isTrue);

    s.selectWorktree('main', path: '/r/b');
    expect(created.length, 2, reason: 'reselecting keeps the same one');
    s.dispose();
    expect(created.last.disposed, isTrue);
  });
}

extension<T> on T {
  T also(void Function(T) f) {
    f(this);
    return this;
  }
}
