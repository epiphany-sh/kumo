/// Worktrees that showed up while the app was open and that the app didn't
/// create: `git worktree add` in a terminal, or an agent making its own.
/// The ones there at start are not new.
class WorktreeArrivals {
  Set<String>? _seen;
  final Set<String> _arrived = {};

  /// `<repo id>|<branch>` the app asked for and git hasn't listed yet.
  final Set<String> _expected = {};

  /// Paths ([Worktree.path]) not looked at yet.
  Set<String> get arrived => Set.unmodifiable(_arrived);

  /// The app is creating [branch] in [repoId]: it is not news when it shows.
  void expect(String repoId, String branch) => _expected.add('$repoId|${branch.trim()}');

  /// Creating failed: nothing to wait for.
  void forget(String repoId, String branch) => _expected.remove('$repoId|${branch.trim()}');

  /// The worktrees git lists now, as (repo id, branch, path). Returns the
  /// paths that arrived with this update.
  Set<String> update(Iterable<(String, String, String)> worktrees) {
    final now = {for (final (_, _, path) in worktrees) path};
    final seen = _seen;
    _seen = now;
    _arrived.retainAll(now);
    if (seen == null) return const {};
    final arrived = <String>{};
    for (final (repo, branch, path) in worktrees) {
      if (seen.contains(path)) continue;
      if (_expected.remove('$repo|$branch')) continue;
      arrived.add(path);
    }
    _arrived.addAll(arrived);
    return arrived;
  }

  /// The user looked at it.
  void acknowledge(String path) => _arrived.remove(path);
}
