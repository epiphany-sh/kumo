import 'package:flutter/foundation.dart';

import 'agents_source.dart';
import 'models.dart';
import 'shell_activity_source.dart';

/// What a worktree's dot in the sidebar says. Later values win when
/// several apply: a failure outranks an agent asking, which outranks
/// something working.
enum WorktreeLight {
  /// Nothing new.
  idle,

  /// An agent or a command finished and you haven't looked yet.
  done,

  /// A command has been running a while (a server, a watcher): steady.
  serving,

  /// An agent is working, or a command just started.
  working,

  /// An agent is asking you something, or is quiet and can't tell whether
  /// it asks: your turn.
  asking,

  /// An agent or a command failed and you haven't looked yet.
  failed;

  WorktreeLight max(WorktreeLight other) => other.index > index ? other : this;
}

/// A worktree's light and what lit it, for the tooltip and screen readers.
@immutable
class WorktreeSignal {
  const WorktreeSignal(this.light, [this.why = '']);
  static const none = WorktreeSignal(WorktreeLight.idle);

  final WorktreeLight light;

  /// "Claude Code needs you", "npm run dev failed (exit 1)"; empty when idle.
  final String why;

  WorktreeSignal max(WorktreeSignal other) => other.light.index > light.index ? other : this;

  @override
  bool operator ==(Object other) => other is WorktreeSignal && other.light == light && other.why == why;
  @override
  int get hashCode => Object.hash(light, why);
  @override
  String toString() => 'WorktreeSignal($light, $why)';
}

/// What one agent is doing.
enum _Doing { working, asking, quiet, exited, failed, stopped }

/// The agents' and the shells' state per worktree, and what happened while
/// you looked elsewhere. [WorktreeLight.done] and [WorktreeLight.failed]
/// are news: they stay until you open the worktree ([seen]), and only
/// arrive for worktrees you aren't on.
class WorktreeLights {
  /// A command running longer than this is a server or a watcher: its dot
  /// stops pulsing.
  static const servingAfter = Duration(minutes: 3);

  final _was = <String, _Doing>{};
  final _agents = <String, WorktreeSignal>{};
  final _commands = <String, List<RunningCommand>>{};
  final _news = <String, WorktreeSignal>{};

  /// When each shell's last command finished, as last read.
  final _finished = <String, DateTime>{};
  bool _agentsPrimed = false;
  bool _shellsPrimed = false;

  /// [path]'s dot (an absolute worktree path) at [now].
  WorktreeSignal of(String path, DateTime now) {
    var signal = _agents[path] ?? WorktreeSignal.none;
    for (final c in _commands[path] ?? const <RunningCommand>[]) {
      signal = signal.max(_running(c, now));
    }
    return signal.max(_news[path] ?? WorktreeSignal.none);
  }

  /// The next time a dot changes with nothing else changing: a command
  /// turning into a server. Null: none will.
  DateTime? nextChange(DateTime now) {
    DateTime? next;
    for (final c in _commands.values.expand((list) => list)) {
      final at = c.since.add(servingAfter);
      if (at.isAfter(now) && (next == null || at.isBefore(next))) next = at;
    }
    return next;
  }

  /// You opened [path]: its news are read.
  void seen(String path) => _news.remove(path);

  /// Reads the agents and the shells again. [worktrees] are the absolute
  /// paths of every worktree, to place them in (the deepest holding their
  /// folder); news don't arrive for [looking], the one on screen. What
  /// had finished by the first read ([shellsLoaded] for the shells) isn't
  /// news: it ended before Kumo looked.
  void update({
    required List<AgentRun> runs,
    required List<TerminalAgent> handTyped,
    List<ShellActivity> shells = const [],
    bool shellsLoaded = false,
    required Iterable<String> worktrees,
    String? looking,
  }) {
    final places = [...worktrees]..sort((a, b) => b.length.compareTo(a.length));
    String? placeOf(String dir) => places.where((p) => dir == p || dir.startsWith('$p/')).firstOrNull;

    void tell(String at, WorktreeSignal news) {
      if (at != looking) _news[at] = (_news[at] ?? WorktreeSignal.none).max(news);
    }

    // ---- Agents ----
    final doing = <String, (String, _Doing, String)>{
      for (final r in runs)
        if (placeOf(r.worktreePath) case final at?) 'run:${r.id}': (at, _runDoing(r), _runSays(r)),
      for (final t in handTyped)
        if (placeOf(t.cwd) case final at?) 'terminal:${t.terminalId}': (at, _terminalDoing(t), t.name),
    };
    _agents.clear();
    for (final MapEntry(key: key, value: (at, now, who)) in doing.entries) {
      final signal = switch (now) {
        _Doing.working => WorktreeSignal(WorktreeLight.working, '$who is working'),
        _Doing.asking => WorktreeSignal(WorktreeLight.asking, '$who needs you'),
        _ => null,
      };
      if (signal != null) _agents[at] = (_agents[at] ?? WorktreeSignal.none).max(signal);

      final was = _was[key];
      final busy = was == _Doing.working || was == _Doing.asking;
      final news = switch (now) {
        _Doing.quiet || _Doing.exited when busy => WorktreeSignal(WorktreeLight.done, '$who finished'),
        // A run can fail before it was ever seen working.
        _Doing.failed when was != _Doing.failed && (busy || (was == null && _agentsPrimed)) => WorktreeSignal(WorktreeLight.failed, '$who failed'),
        _ => null,
      };
      if (news != null) tell(at, news);
    }
    _was
      ..clear()
      ..addAll({for (final MapEntry(:key, :value) in doing.entries) key: value.$2});
    _agentsPrimed = true;

    // ---- Shells ----
    // A CLI typed in a shell is an agent: what it says beats "running".
    final agentShells = {for (final t in handTyped) t.terminalId};
    _commands.clear();
    for (final shell in shells) {
      final at = placeOf(shell.cwd);
      if (at == null) continue;
      if (shell.running case final running? when !agentShells.contains(shell.terminalId)) {
        _commands.putIfAbsent(at, () => []).add(running);
      }
      final last = shell.last;
      if (last == null) continue;
      final before = _finished[shell.terminalId];
      _finished[shell.terminalId] = last.at;
      if (!_shellsPrimed || last.at == before || last.stopped) continue;
      final what = _commandSays(last.command);
      tell(at, last.failed ? WorktreeSignal(WorktreeLight.failed, '$what failed (exit ${last.exit})') : WorktreeSignal(WorktreeLight.done, '$what finished'));
    }
    final open = {for (final s in shells) s.terminalId};
    _finished.removeWhere((id, _) => !open.contains(id));
    if (shellsLoaded) _shellsPrimed = true;
  }

  static WorktreeSignal _running(RunningCommand c, DateTime now) {
    final what = _commandSays(c.command);
    final took = now.difference(c.since);
    if (took < servingAfter) return WorktreeSignal(WorktreeLight.working, '$what is running');
    final minutes = took.inMinutes;
    final time = minutes < 60 ? '$minutes min' : '${minutes ~/ 60} h ${minutes % 60} min';
    return WorktreeSignal(WorktreeLight.serving, '$what has been running for $time');
  }

  /// A command as the tooltip names it: its first line, cut short.
  static String _commandSays(String command) {
    final line = command.split('\n').first.trim();
    if (line.isEmpty) return 'A command';
    return line.length <= 40 ? line : '${line.substring(0, 39)}…';
  }

  static String _runSays(AgentRun r) => r.providerName.isEmpty ? 'An agent' : r.providerName;

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
