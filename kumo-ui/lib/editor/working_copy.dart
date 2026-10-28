import 'package:flutter/foundation.dart';

import '../data/mock_project.dart';

/// Git state of the mock worktree: status per file, staging, conflict
/// resolution, restore and commit. Pure logic, unit-tested.
class WorkingCopy extends ChangeNotifier {
  WorkingCopy({Set<String>? staged}) : staged = staged ?? {'internal/discount/bulk.go', 'internal/discount/repository.go'};

  final Set<String> staged;
  final Set<String> committed = {};
  String? resolution;
  bool restored = false;
  int commits = 0;
  int? lastCommitSize;

  Iterable<String> get allPaths => MockProject.files.keys;

  GitStatus? statusOf(String path) {
    if (committed.contains(path)) return null;
    if (path == MockProject.conflictPath && resolution != null) return GitStatus.modified;
    if (path == MockProject.deletedPath && restored) return null;
    return MockProject.status[path];
  }

  /// Aggregate for a folder: conflict wins, then "has changes".
  GitStatus? dirStatus(String dir) {
    GitStatus? agg;
    for (final p in allPaths) {
      if (!p.startsWith('$dir/')) continue;
      final s = statusOf(p);
      if (s == GitStatus.conflict) return GitStatus.conflict;
      if (s != null) agg = GitStatus.modified;
    }
    return agg;
  }

  List<String> get changed => [for (final p in allPaths) if (statusOf(p) != null) p];
  List<String> get conflicts => [for (final p in changed) if (statusOf(p) == GitStatus.conflict) p];
  List<String> get stagedList => [for (final p in changed) if (staged.contains(p) && statusOf(p) != GitStatus.conflict) p];
  List<String> get unstagedChanges => [
        for (final p in changed)
          if (!staged.contains(p) && const {GitStatus.modified, GitStatus.added, GitStatus.deleted}.contains(statusOf(p))) p
      ];
  List<String> get untracked => [for (final p in changed) if (!staged.contains(p) && statusOf(p) == GitStatus.untracked) p];

  bool get canCommit => conflicts.isEmpty && stagedList.isNotEmpty;
  int get ahead => 2 + commits;

  void stage(String p) {
    staged.add(p);
    notifyListeners();
  }

  void unstage(String p) {
    staged.remove(p);
    notifyListeners();
  }

  void resolve(String keep) {
    resolution = keep;
    notifyListeners();
  }

  void restore() {
    restored = true;
    notifyListeners();
  }

  /// Returns false (and changes nothing) when there is a conflict or nothing staged.
  bool commit() {
    if (!canCommit) return false;
    final batch = stagedList;
    committed.addAll(batch);
    staged.removeAll(batch);
    lastCommitSize = batch.length;
    commits++;
    notifyListeners();
    return true;
  }
}
