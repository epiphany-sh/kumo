import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

import '../data/tests_source.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart' as pb;
import 'kumo_engine.dart';

/// One worktree's tests as `kumod` runs them (`Tests.Watch`).
class EngineTestsSource extends TestsSource {
  EngineTestsSource(this._engine, this.worktreePath) {
    _watch();
  }

  final KumoEngine _engine;
  final String worktreePath;
  bool _disposed = false;
  bool _loading = true;
  String _command = '';
  String _origin = '';
  TestRunInfo? _run;
  String? _error;

  @override
  bool get loading => _loading;
  @override
  String get command => _command;
  @override
  String get commandOrigin => _origin;
  @override
  TestRunInfo? get run => _run;
  @override
  String? get error => _error;

  Future<pb.TestsClient> get _client async => (await _engine.connection()).tests;

  Future<void> _watch() async {
    while (!_disposed) {
      try {
        await for (final s in (await _client).watch(pb.WatchTestsRequest(worktreePath: worktreePath))) {
          if (_disposed) return;
          _loading = false;
          _command = s.command;
          _origin = s.commandOrigin;
          _run = s.hasRun() ? testRunFrom(s.run) : null;
          notifyListeners();
        }
      } on Object {
        // The daemon restarted, or doesn't know the worktree yet.
        if (_disposed) return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  @override
  Future<void> runTests({String command = ''}) => _call((c) => c.run(pb.RunTestsRequest(worktreePath: worktreePath, command: command, cols: 120, rows: 40)));

  @override
  Future<void> stop() => _call((c) => c.stop(pb.StopTestsRequest(worktreePath: worktreePath)));

  Future<void> _call(Future<Object> Function(pb.TestsClient c) call) async {
    _error = null;
    try {
      await call(await _client);
    } on Object catch (e) {
      _error = e is GrpcError ? (e.message ?? e.codeName) : '$e';
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

TestRunInfo testRunFrom(pb.TestRun r) => TestRunInfo(
      command: r.command,
      terminalId: r.terminalId,
      state: switch (r.state) {
        pb.TestRunState.TEST_RUN_STATE_PASSED => TestRunState.passed,
        pb.TestRunState.TEST_RUN_STATE_FAILED => TestRunState.failed,
        pb.TestRunState.TEST_RUN_STATE_STOPPED => TestRunState.stopped,
        _ => TestRunState.running,
      },
      startedAt: _time(r.startedUnixMs) ?? DateTime.now(),
      finishedAt: _time(r.finishedUnixMs),
      exitCode: r.exitCode,
      passed: r.passed,
      failed: r.failed,
      skipped: r.skipped,
      suites: [
        for (final s in r.suites)
          TestSuiteResult(
            name: s.name,
            passed: s.passed,
            duration: s.durationMs == Int64.ZERO ? null : Duration(milliseconds: s.durationMs.toInt()),
            tests: s.tests == 0 ? null : s.tests,
          ),
      ],
      failures: List.unmodifiable(r.failures),
      lastLine: r.lastLine,
    );

DateTime? _time(Int64 ms) => ms == Int64.ZERO ? null : DateTime.fromMillisecondsSinceEpoch(ms.toInt());
