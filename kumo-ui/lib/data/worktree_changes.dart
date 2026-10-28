import 'package:flutter/foundation.dart';

import '../editor/working_copy.dart';
import 'changes.dart';
import 'mock_project.dart';

/// A commit in the history.
@immutable
class CommitInfo {
  const CommitInfo({required this.sha, required this.shortSha, required this.subject, required this.author, required this.time});
  final String sha;
  final String shortSha;
  final String subject;
  final String author;
  final DateTime time;
}

/// Git and files of the selected worktree: what the Files view, the side
/// panel (Files, Source control) and the Git view show, and their actions.
/// The daemon streams it in the app; the design mocks back it in tests.
abstract class WorktreeChanges extends ChangeNotifier {
  String get branch;

  /// What committed changes are measured against (e.g. `origin/main`).
  String get base;
  int get ahead;
  int get behind;

  /// The branch has been pushed (it has an upstream).
  bool get pushed;

  /// Increases whenever the status changes (to refresh derived data).
  int get version;

  /// Last failure reported by the daemon.
  String? get error;

  // ---- Files ----

  /// Every file (tracked and untracked, not ignored), relative paths.
  List<String> get files;

  /// Text of a file; null when it can't be shown (binary, missing).
  Future<String?> read(String path);
  Future<void> write(String path, String text);

  // ---- Status ----

  GitStatus? statusOf(String path);

  /// Aggregate for a folder: conflict wins, then "has changes".
  GitStatus? dirStatus(String dir) {
    GitStatus? aggregate;
    for (final p in changed) {
      if (!p.startsWith('$dir/')) continue;
      final s = statusOf(p);
      if (s == GitStatus.conflict) return GitStatus.conflict;
      if (s != null) aggregate = GitStatus.modified;
    }
    return aggregate;
  }

  List<String> get changed;
  List<String> get conflicts;
  List<String> get stagedList;
  List<String> get unstagedChanges;
  List<String> get untracked;
  bool get canCommit => conflicts.isEmpty && stagedList.isNotEmpty;

  /// Uncommitted changes, for the side panel.
  List<ChangedFile> get pending;

  /// Committed on the branch since it left [base].
  List<ChangedFile> get onBranch;

  /// [path] with its changed lines loaded.
  Future<ChangedFile?> diff(String path);

  /// Changed lines of [path] for the editor gutter: line number (1-based)
  /// → true when added, false when modified.
  Future<Map<int, bool>> marks(String path);

  // ---- Actions ----

  void stage(String path);
  void unstage(String path);

  /// Back to HEAD (restores a deleted file).
  Future<void> restore(String path);

  /// Writes the resolved text ([keep]: current / incoming / both) and stages.
  Future<void> resolveConflict(String path, String keep, String text);

  /// Commits staged changes ([all]: every change) and optionally pushes.
  /// Returns the short sha, or null if it failed ([error] says why).
  Future<String?> commit(String message, {bool all = false, bool amend = false, bool push = false});

  Future<void> push();
  Future<void> undoLastCommit();

  /// Latest commits; null when the source has no history (mocks).
  Future<List<CommitInfo>?> log({int limit = 30});
}

/// The design mocks: [MockChanges] for the side panel, [MockProject] and a
/// [WorkingCopy] for the Files view. Effects are synchronous, like the
/// optimistic UI they stand in for.
class MockWorktreeChanges extends WorktreeChanges {
  MockWorktreeChanges() {
    _wc.addListener(notifyListeners);
  }

  final _wc = WorkingCopy();
  final _texts = <String, String>{};
  bool _committed = false;
  bool _pushed = false;

  @override
  String get branch => 'feat/PRC-412-bulk-discounts';
  @override
  String get base => 'origin/main';
  @override
  int get ahead => _pushed ? 0 : 2 + _wc.commits + (_committed ? 1 : 0);
  @override
  int get behind => 0;
  @override
  bool get pushed => _pushed;
  @override
  int get version => 0;
  @override
  String? get error => null;

  @override
  List<String> get files => {...MockProject.files.keys, ...MockChanges.tree}.toList();

  @override
  Future<String?> read(String path) async => _texts[path] ?? MockProject.files[path];

  @override
  Future<void> write(String path, String text) async => _texts[path] = text;

  @override
  GitStatus? statusOf(String path) => _wc.statusOf(path);
  @override
  GitStatus? dirStatus(String dir) => _wc.dirStatus(dir);
  @override
  List<String> get changed => _wc.changed;
  @override
  List<String> get conflicts => _wc.conflicts;
  @override
  List<String> get stagedList => _wc.stagedList;
  @override
  List<String> get unstagedChanges => _wc.unstagedChanges;
  @override
  List<String> get untracked => _wc.untracked;
  @override
  bool get canCommit => _wc.canCommit;

  @override
  List<ChangedFile> get pending => _committed ? const [] : [for (final f in MockChanges.files) if (!f.committed) f];

  @override
  List<ChangedFile> get onBranch => [
        for (final f in MockChanges.files) if (f.committed) f,
        if (_committed) ...[for (final f in MockChanges.files) if (!f.committed) f],
      ];

  @override
  Future<ChangedFile?> diff(String path) async => MockChanges.byPath(path);

  @override
  Future<Map<int, bool>> marks(String path) async => {
        for (final (from, to, add) in MockProject.marks[path] ?? const <(int, int, bool)>[])
          for (var n = from; n <= to; n++) n: add,
      };

  @override
  void stage(String path) => _wc.stage(path);
  @override
  void unstage(String path) => _wc.unstage(path);

  @override
  Future<void> restore(String path) async => _wc.restore();

  @override
  Future<void> resolveConflict(String path, String keep, String text) async {
    _texts[path] = text;
    _wc.resolve(keep);
  }

  @override
  Future<String?> commit(String message, {bool all = false, bool amend = false, bool push = false}) async {
    if (all) {
      _committed = true;
    } else if (!_wc.commit()) {
      return null;
    }
    if (push) _pushed = true;
    notifyListeners();
    return '3f9c2ab';
  }

  @override
  Future<void> push() async {
    _pushed = true;
    notifyListeners();
  }

  @override
  Future<void> undoLastCommit() async {
    _committed = false;
    _pushed = false;
    notifyListeners();
  }

  @override
  Future<List<CommitInfo>?> log({int limit = 30}) async => null;

  @override
  void dispose() {
    _wc.dispose();
    super.dispose();
  }
}

/// Folder tree of [paths]: folders first, then files, by name.
List<TreeNode> buildTree(Iterable<String> paths) {
  final root = <String, dynamic>{};
  for (final path in paths) {
    var node = root;
    final parts = path.split('/');
    for (var i = 0; i < parts.length; i++) {
      final isFile = i == parts.length - 1;
      if (isFile) {
        node.putIfAbsent(parts[i], () => null);
      } else {
        node = (node[parts[i]] ??= <String, dynamic>{}) as Map<String, dynamic>;
      }
    }
  }
  List<TreeNode> nodes(Map<String, dynamic> map) {
    final dirs = [for (final e in map.entries) if (e.value != null) e.key]..sort();
    final files = [for (final e in map.entries) if (e.value == null) e.key]..sort();
    return [
      for (final d in dirs) TreeNode(d, nodes(map[d] as Map<String, dynamic>)),
      for (final f in files) TreeNode(f),
    ];
  }

  return nodes(root);
}

/// No worktree selected yet: nothing to show, nothing to do.
class NoWorktreeChanges extends WorktreeChanges {
  @override
  String get branch => '';
  @override
  String get base => '';
  @override
  int get ahead => 0;
  @override
  int get behind => 0;
  @override
  bool get pushed => false;
  @override
  int get version => 0;
  @override
  String? get error => null;
  @override
  List<String> get files => const [];
  @override
  Future<String?> read(String path) async => null;
  @override
  Future<void> write(String path, String text) async {}
  @override
  GitStatus? statusOf(String path) => null;
  @override
  List<String> get changed => const [];
  @override
  List<String> get conflicts => const [];
  @override
  List<String> get stagedList => const [];
  @override
  List<String> get unstagedChanges => const [];
  @override
  List<String> get untracked => const [];
  @override
  List<ChangedFile> get pending => const [];
  @override
  List<ChangedFile> get onBranch => const [];
  @override
  Future<ChangedFile?> diff(String path) async => null;
  @override
  Future<Map<int, bool>> marks(String path) async => const {};
  @override
  void stage(String path) {}
  @override
  void unstage(String path) {}
  @override
  Future<void> restore(String path) async {}
  @override
  Future<void> resolveConflict(String path, String keep, String text) async {}
  @override
  Future<String?> commit(String message, {bool all = false, bool amend = false, bool push = false}) async => null;
  @override
  Future<void> push() async {}
  @override
  Future<void> undoLastCommit() async {}
  @override
  Future<List<CommitInfo>?> log({int limit = 30}) async => const [];
}
