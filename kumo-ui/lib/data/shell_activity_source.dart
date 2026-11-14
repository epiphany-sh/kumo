import 'package:flutter/foundation.dart';

/// A command running in a shell.
@immutable
class RunningCommand {
  const RunningCommand({required this.command, required this.since});

  /// As typed; empty when the shell didn't sign it (a space first).
  final String command;

  /// When its output started.
  final DateTime since;
}

/// A command that ran to its end.
@immutable
class FinishedCommand {
  const FinishedCommand({required this.command, required this.at, this.exit});

  /// As typed; empty when the shell didn't sign it.
  final String command;

  /// Its status; null when the shell didn't report one.
  final int? exit;
  final DateTime at;

  /// Ctrl-C (130), Ctrl-Z (148) and a kill (143): ended by you, not failed.
  bool get stopped => exit == 130 || exit == 148 || exit == 143;

  bool get failed => exit != null && exit != 0 && !stopped;
}

/// What one shell with Kumo's integration is doing, and where.
@immutable
class ShellActivity {
  const ShellActivity({required this.terminalId, required this.cwd, this.running, this.last});
  final String terminalId;

  /// The folder its shell said it's in last (absolute); empty: unknown.
  final String cwd;
  final RunningCommand? running;
  final FinishedCommand? last;
}

/// What the shells in Kumo's terminals run, as their integration says.
abstract class ShellActivitySource extends ChangeNotifier {
  List<ShellActivity> get shells;

  /// The first answer arrived: until then [shells] is empty for lack of it,
  /// not because no shell runs anything.
  bool get loaded;
}

/// No shells to follow: the design, tests and an older daemon.
class NoShellActivity extends ShellActivitySource {
  @override
  List<ShellActivity> get shells => const [];
  @override
  bool get loaded => false;
}
