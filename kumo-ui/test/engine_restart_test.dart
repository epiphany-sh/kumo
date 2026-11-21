import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/engine/daemon_endpoint.dart';
import 'package:kumo_ui/engine/daemon_launcher.dart';
import 'package:kumo_ui/engine/generated/kumo/v1/kumo.pbgrpc.dart';
import 'package:kumo_ui/engine/kumo_engine.dart';

/// The real `kumod`, in its own data folder: never the user's daemon.
class _Launcher extends DaemonLauncher {
  const _Launcher(this.program, this.dataDir);
  final String program;
  final String dataDir;

  @override
  Future<void> launch() => Process.start(program, ['--data-dir', dataDir], mode: ProcessStartMode.detached);
}

/// How an update lands: the new program renamed over the old one.
void _replace(File program) {
  final next = File('${program.path}.new');
  program.copySync(next.path);
  next.renameSync(program.path);
}

/// Every `kumod` running the copy in [dir], the old program or the new
/// one: what a test may leave behind (each is started detached, and
/// outlives the test process).
List<int> _daemonsIn(Directory dir) {
  final ps = Process.runSync('ps', ['-Ao', 'pid=,command=']);
  if (ps.exitCode != 0) return const [];
  final program = '${dir.path}/kumod';
  return [
    for (final line in (ps.stdout as String).split('\n'))
      if (line.trimLeft().split(' ') case [final pid, ...final command] when command.join(' ') == program || command.join(' ').startsWith('$program '))
        if (int.tryParse(pid) case final pid?) pid,
  ];
}

/// Stops them, for good if they don't go when asked.
Future<void> _stopDaemonsIn(Directory dir) async {
  for (final pid in _daemonsIn(dir)) {
    Process.killPid(pid);
  }
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (_daemonsIn(dir).isNotEmpty && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  for (final pid in _daemonsIn(dir)) {
    Process.killPid(pid, ProcessSignal.sigkill);
  }
}

Future<void> _until(bool Function() done, {Duration timeout = const Duration(seconds: 15)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  final built = File('../target/debug/kumod');
  final skip = built.existsSync() ? false : 'needs `cargo build -p kumod`';

  late Directory dir;
  late File program;
  late DaemonDiscovery discovery;

  /// The engines a test made and hasn't quit: quit before their daemons
  /// stop, so none launches one again.
  final engines = <KumoEngine>{};
  KumoEngine engine() {
    final e = KumoEngine(discovery: discovery, launcher: _Launcher(program.path, '${dir.path}/data'));
    engines.add(e);
    return e;
  }

  void quit(KumoEngine e) {
    if (engines.remove(e)) e.dispose();
  }

  // A run cut short (stopped, killed, timed out) never tears down: its
  // daemons would run on for good. Older than any run still going.
  setUpAll(() async {
    final stale = DateTime.now().subtract(const Duration(minutes: 10));
    for (final left in Directory.systemTemp.listSync().whereType<Directory>()) {
      if (!left.path.split(Platform.pathSeparator).last.startsWith('kumo-restart-')) continue;
      if (left.statSync().modified.isAfter(stale)) continue;
      await _stopDaemonsIn(left);
      left.deleteSync(recursive: true);
    }
  });

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kumo-restart-');
    program = built.copySync('${dir.path}/kumod');
    discovery = DaemonDiscovery(file: File('${dir.path}/data/daemon.json'));
  });

  // Every daemon the test started, not just the one daemon.json names
  // last (a failed update test can leave the old one and the new).
  tearDown(() async {
    for (final e in [...engines]) {
      quit(e);
    }
    await _stopDaemonsIn(dir);
    dir.deleteSync(recursive: true);
  });

  test('an updated daemon restarts on its own once no terminal runs', () async {
    final first = engine();
    final before = await first.connection();
    expect(before.outdated, isFalse);
    final terminal = await before.terminals.open(OpenRequest(program: '/bin/sh', args: ['-c', 'sleep 30']));
    quit(first); // the UI quits; kumod and its terminal stay

    _replace(program);
    final second = engine();
    final conn = await second.connection();
    expect(conn.endpoint.pid, before.endpoint.pid, reason: 'the same daemon, now outdated');
    expect(conn.outdated, isTrue);
    await _until(() => second.runningInOutdated == 1);
    expect(second.current?.endpoint.pid, before.endpoint.pid, reason: 'a running terminal keeps it');

    await conn.terminals.close(CloseRequest(terminalId: terminal.terminalId));
    await _until(() => second.current != null && second.current!.endpoint.pid != before.endpoint.pid);
    expect(second.outdated, isFalse, reason: 'the new program runs');
    expect(second.status, EngineStatus.ready);
  }, skip: skip);

  test('restarting now ends the running terminals', () async {
    final first = engine();
    final before = await first.connection();
    await before.terminals.open(OpenRequest(program: '/bin/sh', args: ['-c', 'sleep 30']));
    quit(first);

    _replace(program);
    final second = engine();
    await second.connection();
    await _until(() => second.runningInOutdated == 1);

    await second.restartDaemon(force: true);
    final after = await second.connection();
    expect(after.endpoint.pid, isNot(before.endpoint.pid));
    expect(after.outdated, isFalse);
    expect(await second.runningTerminals(), isEmpty);
  }, skip: skip);

  test('before Kumo quits for an update, the daemon stops for good: the next Kumo starts the new one', () async {
    final first = engine();
    final before = await first.connection();
    await before.terminals.open(OpenRequest(program: '/bin/sh', args: ['-c', 'sleep 30']));

    await first.stopForUpdate();
    expect(await discovery.read(), isNull, reason: 'kumod is gone, its terminal too');
    await expectLater(first.connection(), throwsStateError, reason: 'nothing launches the old program again');
    expect(await discovery.read(), isNull);
    quit(first);

    _replace(program);
    final next = engine();
    final conn = await next.connection();
    expect(conn.endpoint.pid, isNot(before.endpoint.pid));
    expect(conn.outdated, isFalse, reason: 'no restart left to do');
  }, skip: skip);
}
