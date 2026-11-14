import 'package:flutter/foundation.dart';

import 'terminal_surface.dart';

/// A command the daemon remembers for a repository: the same line run
/// again is the same entry.
@immutable
class HistoryItem {
  const HistoryItem(this.command, {this.runs = 1, this.lastRun, this.lastExit, this.lastCwd = ''});

  final String command;
  final int runs;
  final DateTime? lastRun;

  /// Status of its last run, when the shell reported one.
  final int? lastExit;

  /// Where it last ran; empty when the shell didn't say.
  final String lastCwd;

  bool get failed => lastExit != null && lastExit != 0;
}

/// The commands remembered for the repository a shell is in, last run
/// first, and the folder it's in.
@immutable
class CommandHistory {
  const CommandHistory(this.items, {this.cwd = '', this.repo = ''});

  static const empty = CommandHistory([]);

  final List<HistoryItem> items;
  final String cwd;

  /// The repository's main checkout; empty outside one.
  final String repo;
}

/// A terminal whose shell's commands are remembered (the daemon's shells).
abstract interface class CommandHistorySource {
  ValueListenable<CommandHistory> get history;

  /// Reads it again (a command finished, the panel opened).
  Future<void> refreshHistory();

  /// Forgets the repository's commands, or [everything]. Returns how many.
  Future<int> forgetHistory({bool everything = false});

  /// Puts [command] at the prompt, replacing what's typed there, and runs
  /// it when [run].
  void insertCommand(String command, {bool run = false});
}

/// What to suggest after [typed]: the rest of a remembered command that
/// starts with it, or null. Of those, one run in [cwd] goes first, then
/// one that worked, then the last run. A command of several lines, or with
/// control characters, is never suggested: accepting it would run it.
String? suggestCommand(String typed, CommandHistory history) {
  if (typed.trim().isEmpty) return null;
  HistoryItem? best;
  var bestScore = -1;
  for (final item in history.items) {
    final command = item.command;
    if (command.length <= typed.length || !command.startsWith(typed) || _hasControl(command)) continue;
    final score = (item.lastCwd.isNotEmpty && item.lastCwd == history.cwd ? 2 : 0) + (item.failed ? 0 : 1);
    // Items come last run first: the first with the best score wins.
    if (score > bestScore) {
      best = item;
      bestScore = score;
      if (score == 3) break;
    }
  }
  return best?.command.substring(typed.length);
}

/// What's suggested after what you typed at [b]'s prompt: nothing while a
/// command runs, with something drawn at the cursor (you moved back into
/// the line, or another tool suggests there) or with no room left on the
/// row.
String? suggestionFor(TermBuffer b, CommandHistory history) {
  final input = b.input;
  if (b.altScreen || input == null || input.trailing || input.room < 2) return null;
  return suggestCommand(input.text, history);
}

/// The next word of [rest] (and the blanks before it): what ⌥→ accepts.
String nextWord(String rest) {
  var i = 0;
  while (i < rest.length && rest[i] == ' ') {
    i++;
  }
  while (i < rest.length && rest[i] != ' ') {
    i++;
  }
  return rest.substring(0, i);
}

bool _hasControl(String s) {
  for (final unit in s.codeUnits) {
    if (unit < 0x20 || unit >= 0x7f && unit < 0xa0) return true;
  }
  return false;
}
