import 'package:flutter/foundation.dart';

import 'mock_data.dart';
import 'models.dart';

/// Where namespaces, repositories and worktrees come from: the daemon in the
/// app, the design mocks in tests. Repos are referred to by [Repo.id].
///
/// Mutations return at once and apply optimistically (kumo.md §5.2); the
/// daemon confirms with a new snapshot or the change is reverted and
/// [error] is set.
abstract class WorkspaceSource extends ChangeNotifier {
  List<Namespace> get namespaces;

  /// Repositories referenced by namespaces, sidebar order.
  List<Repo> get repos;

  Repo? repo(String id);

  /// Repositories that can be added to a namespace.
  List<RepoCandidate> get candidates;

  /// Last failure reported by the daemon, for a notice.
  String? get error;

  /// Whether the first state arrived (or failed to): until then [repos] is
  /// empty because it isn't known yet, not because there are none.
  bool get loaded => true;

  /// Looks for repositories on disk ([candidates] updates when done).
  Future<void> discover();

  /// Creates (no [id]) or replaces a namespace; returns its id.
  String saveNamespace({String? id, required String name, required List<String> repos, bool collapsed = false, int? position});

  void deleteNamespace(String id);

  /// `git worktree add`: a new [branch] from [base], or an existing one.
  Future<void> createWorktree(Repo repo, {required String branch, required bool createBranch, String base = '', String path = ''});

  /// `git worktree remove`; the branch stays.
  Future<void> removeWorktree(Repo repo, Worktree worktree);

  /// Re-reads git state.
  void refresh();

  /// Branches of [repo]; null when this source has none (mocks).
  Future<RepoBranches?> branches(Repo repo);

  /// Where [worktree] is on disk ([Worktree.path] may be shortened to `~/…`).
  String absolutePathOf(Worktree worktree) => worktree.path;
}

/// Branches to start a worktree from or check out.
class RepoBranches {
  const RepoBranches({required this.current, required this.local, required this.remote});

  /// Checked out in the main checkout; empty if detached.
  final String current;
  final List<String> local;

  /// `origin/feat/x`…
  final List<String> remote;
}

/// The design mocks, editable in memory.
class MockWorkspaceSource extends WorkspaceSource {
  List<Namespace> _namespaces = List.of(Mock.initialNamespaces);
  var _seq = 0;

  @override
  List<Namespace> get namespaces => List.unmodifiable(_namespaces);

  @override
  List<Repo> get repos => [
        for (final id in {for (final n in _namespaces) ...n.repos})
          if (repo(id) case final r?) r,
      ];

  @override
  Repo? repo(String id) => Mock.repoNamed(id);

  @override
  List<RepoCandidate> get candidates => Mock.candidates;

  @override
  String? get error => null;

  @override
  Future<void> discover() async {}

  @override
  String saveNamespace({String? id, required String name, required List<String> repos, bool collapsed = false, int? position}) {
    final namespace = Namespace(id: id ?? 'ns-${++_seq}', name: name, repos: repos, collapsed: collapsed);
    final at = _namespaces.indexWhere((n) => n.id == namespace.id);
    final list = [..._namespaces];
    if (at >= 0) list.removeAt(at);
    list.insert((position ?? (at >= 0 ? at : list.length)).clamp(0, list.length), namespace);
    _namespaces = list;
    notifyListeners();
    return namespace.id;
  }

  @override
  void deleteNamespace(String id) {
    _namespaces = [for (final n in _namespaces) if (n.id != id) n];
    notifyListeners();
  }

  @override
  Future<void> createWorktree(Repo repo, {required String branch, required bool createBranch, String base = '', String path = ''}) async {}

  @override
  Future<void> removeWorktree(Repo repo, Worktree worktree) async {}

  @override
  void refresh() {}

  @override
  Future<RepoBranches?> branches(Repo repo) async => null;
}
