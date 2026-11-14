import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/data/shell_activity_source.dart';
import 'package:kumo_ui/engine/daemon_endpoint.dart';
import 'package:kumo_ui/engine/daemon_launcher.dart';
import 'package:kumo_ui/engine/engine_shell_activity.dart';
import 'package:kumo_ui/engine/generated/kumo/v1/kumo.pbgrpc.dart' hide ShellActivity, RunningCommand, FinishedCommand;
import 'package:kumo_ui/engine/kumo_engine.dart';

/// The real `kumod`, in its own data folder: never the user's daemon.
class _Launcher extends DaemonLauncher {
  const _Launcher(this.program, this.dataDir);
  final String program;
  final String dataDir;

  @override
  Future<void> launch() => Process.start(program, ['--data-dir', dataDir], mode: ProcessStartMode.detached);
}

Future<void> _until(bool Function() done, {Duration timeout = const Duration(seconds: 20)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  final built = File('../target/debug/kumod');
  final zsh = File('/bin/zsh');
  final skip = !built.existsSync() ? 'needs `cargo build -p kumod`' : (!zsh.existsSync() ? 'needs zsh' : false);

  late Directory dir;
  late DaemonDiscovery discovery;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kumo-shells-');
    discovery = DaemonDiscovery(file: File('${dir.path}/data/daemon.json'));
  });

  tearDown(() async {
    final endpoint = await discovery.read();
    if (endpoint != null) Process.killPid(endpoint.pid);
    dir.deleteSync(recursive: true);
  });

  test('a shell’s command reaches the UI: running, then its status, where it ran', () async {
    final program = built.copySync('${dir.path}/kumod');
    final home = Directory('${dir.path}/home')..createSync();
    File('${home.path}/.zshrc').writeAsStringSync("PS1='\$ '\n");
    final engine = KumoEngine(discovery: discovery, launcher: _Launcher(program.path, '${dir.path}/data'));
    addTearDown(engine.dispose);
    final shells = EngineShellActivity(engine);
    addTearDown(shells.dispose);

    final conn = await engine.connection();
    final opened = await conn.terminals.open(OpenRequest(program: zsh.path, cwd: home.path, env: {'HOME': home.path, 'ZDOTDIR': home.path}.entries, shellIntegration: true));
    final id = opened.terminalId;
    final input = StreamController<TerminalInput>();
    addTearDown(input.close);
    final output = StringBuffer();
    conn.terminals.attach(input.stream).listen((o) {
      if (o.hasOutput()) output.write(utf8.decode(o.output.data, allowMalformed: true));
    }, onError: (_) {});
    input.add(TerminalInput(attach: AttachTo(terminalId: id)));
    ShellActivity? shell() => shells.shells.where((s) => s.terminalId == id).firstOrNull;
    await _until(() => output.toString().contains('\x1b]133;A'));

    input.add(TerminalInput(data: utf8.encode('false\n')));
    await _until(() => shell()?.last != null);
    expect(shell()!.last!.command, 'false');
    expect(shell()!.last!.exit, 1);
    expect(shell()!.last!.failed, isTrue);
    expect(Directory(shell()!.cwd).resolveSymbolicLinksSync(), home.resolveSymbolicLinksSync());

    input.add(TerminalInput(data: utf8.encode('sleep 3\n')));
    await _until(() => shell()?.running != null);
    expect(shell()!.running!.command, 'sleep 3');
    await _until(() => shell()?.last?.command == 'sleep 3');
    expect(shell()!.running, isNull);
    expect(shell()!.last!.exit, 0);

    input.add(TerminalInput(data: utf8.encode('exit\n')));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 1)));
}
