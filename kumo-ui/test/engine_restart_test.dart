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
  KumoEngine engine() => KumoEngine(discovery: discovery, launcher: _Launcher(program.path, '${dir.path}/data'));

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kumo-restart-');
    program = built.copySync('${dir.path}/kumod');
    discovery = DaemonDiscovery(file: File('${dir.path}/data/daemon.json'));
  });

  tearDown(() async {
    final endpoint = await discovery.read();
    if (endpoint != null) Process.killPid(endpoint.pid);
    dir.deleteSync(recursive: true);
  });

  test('an updated daemon restarts on its own once no terminal runs', () async {
    final first = engine();
    final before = await first.connection();
    expect(before.outdated, isFalse);
    final terminal = await before.terminals.open(OpenRequest(program: '/bin/sh', args: ['-c', 'sleep 30']));
    first.dispose(); // the UI quits; kumod and its terminal stay

    _replace(program);
    final second = engine();
    addTearDown(second.dispose);
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
    first.dispose();

    _replace(program);
    final second = engine();
    addTearDown(second.dispose);
    await second.connection();
    await _until(() => second.runningInOutdated == 1);

    await second.restartDaemon(force: true);
    final after = await second.connection();
    expect(after.endpoint.pid, isNot(before.endpoint.pid));
    expect(after.outdated, isFalse);
    expect(await second.runningTerminals(), isEmpty);
  }, skip: skip);
}
