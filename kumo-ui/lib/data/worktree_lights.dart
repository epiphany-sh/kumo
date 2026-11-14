import 'agents_source.dart';
import 'models.dart';

/// What a worktree's dot in the sidebar says. Later values win when
/// several apply: a failure outranks an agent asking, which outranks one
/// working.
enum WorktreeLight {
  /// Nothing new.
  idle,

  /// An agent finished (its turn, or its run) and you haven't looked yet.
  done,

  /// An agent is working.
  working,

  /// An agent is asking you something, or is quiet and can't tell whether
  /// it asks: your turn.
  asking,

  /// An agent's run failed and you haven't looked yet.
  failed;

  WorktreeLight max(WorktreeLight other) => other.index > index ? other : this;
}

/// What one agent is doing.
enum _Doing { working, asking, quiet, exited, failed, stopped }

/// The agents' state per worktree, and what happened while you looked
/// elsewhere. [done] and [failed] are news: they stay until you open the
/// worktree ([seen]), and only arrive for worktrees you aren't on.
class WorktreeLights {
  final _was = <String, _Doing>{};
  final _now = <String, WorktreeLight>{};
  final _news = <String, WorktreeLight>{};
  bool _primed = false;

  /// [path]'s dot (an absolute worktree path).
  WorktreeLight of(String path) => (_now[path] ?? WorktreeLight.idle).max(_news[path] ?? WorktreeLight.idle);

  /// You opened [path]: its news are read.
  void seen(String path) => _news.remove(path);

  /// Reads the agents again. [worktrees] are the absolute paths of every
  /// worktree, to place the agents in; news don't arrive for [looking], the
  /// one on screen. The first read only learns where things are: what
  /// finished before Kumo opened isn't news.
  void update({required List<AgentRun> runs, required List<TerminalAgent> handTyped, required Iterable<String> worktrees, String? looking}) {
    final places = [...worktrees]..sort((a, b) => b.length.compareTo(a.length));
    String? placeOf(String dir) => places.where((p) => dir == p || dir.startsWith('$p/')).firstOrNull;

    final doing = <String, (String, _Doing)>{
      for (final r in runs)
        if (placeOf(r.worktreePath) case final at?) 'run:${r.id}': (at, _runDoing(r)),
      for (final t in handTyped)
        if (placeOf(t.cwd) case final at?) 'terminal:${t.terminalId}': (at, _terminalDoing(t)),
    };

    _now.clear();
    for (final MapEntry(key: key, value: (at, now)) in doing.entries) {
      final light = switch (now) {
        _Doing.working => WorktreeLight.working,
        _Doing.asking => WorktreeLight.asking,
        _ => null,
      };
      if (light != null) _now[at] = (_now[at] ?? WorktreeLight.idle).max(light);

      final was = _was[key];
      final busy = was == _Doing.working || was == _Doing.asking;
      final news = switch (now) {
        _Doing.quiet || _Doing.exited when busy => WorktreeLight.done,
        // A run can fail before it was ever seen working.
        _Doing.failed when was != _Doing.failed && (busy || (was == null && _primed)) => WorktreeLight.failed,
        _ => null,
      };
      if (news != null && at != looking) _news[at] = (_news[at] ?? WorktreeLight.idle).max(news);
    }

    _was
      ..clear()
      ..addAll({for (final MapEntry(:key, :value) in doing.entries) key: value.$2});
    _primed = true;
  }

  /// Ctrl-C (130) and SIGTERM (143, Stop): ended by you, not failed.
  static _Doing _runDoing(AgentRun r) => switch (r.status) {
        AgentStatus.running => _Doing.working,
        AgentStatus.needsYou => r.asked || !r.tellsAsking ? _Doing.asking : _Doing.quiet,
        AgentStatus.done => switch (r.exitCode) {
            0 => _Doing.exited,
            130 || 143 => _Doing.stopped,
            _ => _Doing.failed,
          },
      };

  static _Doing _terminalDoing(TerminalAgent t) => t.state == AgentStatus.needsYou
      ? _Doing.asking
      : t.busy
          ? _Doing.working
          : _Doing.quiet;
}
