import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

import '../data/shell_activity_source.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart' as pb;
import 'kumo_engine.dart';

/// The shells' commands as `kumod` reads them (`Terminals.Watch`). An
/// older daemon without it leaves [shells] empty and isn't asked again.
class EngineShellActivity extends ShellActivitySource {
  EngineShellActivity(this._engine) {
    _watch();
  }

  final KumoEngine _engine;
  bool _disposed = false;
  bool _loaded = false;
  List<ShellActivity> _shells = const [];

  @override
  List<ShellActivity> get shells => _shells;
  @override
  bool get loaded => _loaded;

  Future<void> _watch() async {
    while (!_disposed) {
      try {
        final terminals = (await _engine.connection()).terminals;
        await for (final snapshot in terminals.watch(pb.WatchTerminalsRequest())) {
          if (_disposed) return;
          _shells = [for (final s in snapshot.shells) _shell(s)];
          _loaded = true;
          notifyListeners();
        }
      } on GrpcError catch (e) {
        if (_disposed || e.code == StatusCode.unimplemented) return;
      } on Object {
        if (_disposed) return;
      }
      // A restarting daemon ends every stream; the next one reconnects.
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  static DateTime _at(Int64 nanos) => DateTime.fromMicrosecondsSinceEpoch((nanos ~/ 1000).toInt());

  static ShellActivity _shell(pb.ShellActivity s) => ShellActivity(
        terminalId: s.terminalId,
        cwd: s.cwd,
        running: s.hasRunning() ? RunningCommand(command: s.running.command, since: _at(s.running.startedUnixNanos)) : null,
        last: s.hasLast()
            ? FinishedCommand(command: s.last.command, exit: s.last.hasExitCode() ? s.last.exitCode : null, at: _at(s.last.finishedUnixNanos))
            : null,
      );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
