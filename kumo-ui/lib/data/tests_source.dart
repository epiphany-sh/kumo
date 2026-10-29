import 'package:flutter/foundation.dart';

enum TestRunState { running, passed, failed, stopped }

/// One package, crate or file of tests.
@immutable
class TestSuiteResult {
  const TestSuiteResult({required this.name, required this.passed, this.duration, this.tests});
  final String name;
  final bool passed;
  final Duration? duration;

  /// Tests in it, when the runner says.
  final int? tests;
}

/// The latest test run of a worktree, as its output reads so far.
@immutable
class TestRunInfo {
  const TestRunInfo({
    required this.command,
    required this.terminalId,
    required this.state,
    required this.startedAt,
    this.finishedAt,
    this.exitCode = 0,
    this.passed = 0,
    this.failed = 0,
    this.skipped = 0,
    this.suites = const [],
    this.failures = const [],
    this.lastLine = '',
  });

  final String command;

  /// Where it runs: open it for the whole output.
  final String terminalId;
  final TestRunState state;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int exitCode;
  final int passed;
  final int failed;
  final int skipped;
  final List<TestSuiteResult> suites;

  /// Names of the failing tests.
  final List<String> failures;

  /// The latest line printed.
  final String lastLine;

  /// How long it took (so far, while running).
  Duration elapsed([DateTime? now]) => (finishedAt ?? now ?? DateTime.now()).difference(startedAt);
}

/// The tests of the selected worktree: the command its files point to and
/// its latest run (`Tests.Watch`).
abstract class TestsSource extends ChangeNotifier {
  /// Until the first answer.
  bool get loading;

  /// The detected command; empty when none was found.
  String get command;

  /// Why it was picked, e.g. "Makefile".
  String get commandOrigin;
  TestRunInfo? get run;

  /// Last failure to run or stop, readable.
  String? get error;

  /// Runs [command] (empty: the detected one).
  Future<void> runTests({String command = ''});
  Future<void> stop();
}

/// No worktree, or no daemon: nothing to run.
class NoTests extends TestsSource {
  @override
  bool get loading => false;
  @override
  String get command => '';
  @override
  String get commandOrigin => '';
  @override
  TestRunInfo? get run => null;
  @override
  String? get error => null;
  @override
  Future<void> runTests({String command = ''}) async {}
  @override
  Future<void> stop() async {}
}
