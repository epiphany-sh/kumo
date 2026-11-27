import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:kumo_ui/engine/daemon_endpoint.dart';
import 'package:kumo_ui/engine/generated/kumo/v1/kumo.pbgrpc.dart';
import 'package:kumo_ui/engine/grpc_terminal_surface.dart';
import 'package:kumo_ui/engine/kumo_engine.dart';

class _Core extends CoreServiceBase {
  @override
  Future<HelloResponse> hello(ServiceCall call, HelloRequest request) async => HelloResponse(serverApiVersion: kApiVersion, serverVersion: 'test');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A daemon whose `Open` waits for [opened]; it records what attaches send.
class _Terminals extends TerminalsServiceBase {
  final opened = Completer<void>();
  OpenRequest? openRequest;
  final inputs = <TerminalInput>[];

  @override
  Future<OpenResponse> open(ServiceCall call, OpenRequest request) async {
    openRequest = request;
    await opened.future;
    return OpenResponse(terminalId: 't1');
  }

  /// What the terminal prints.
  final output = StreamController<TerminalOutput>();

  @override
  Stream<TerminalOutput> attach(ServiceCall call, Stream<TerminalInput> request) {
    request.listen(inputs.add, onError: (_) {}); // the client going away
    return output.stream;
  }

  void write(String text) => output.add(TerminalOutput(output: OutputBatch(data: utf8.encode(text))));

  @override
  Future<HistoryResponse> history(ServiceCall call, HistoryRequest request) async => HistoryResponse();

  @override
  Future<CloseResponse> close(ServiceCall call, CloseRequest request) async => CloseResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Runs a frame: what the surface published by frame callback lands.
void _frame() {
  SchedulerBinding.instance
    ..handleBeginFrame(null)
    ..handleDrawFrame();
}

/// The text on [surface]'s screen.
String _screenOf(GrpcTerminalSurface surface) => [
      for (final line in surface.buffer.value.lines) line.spans.map((s) => s.text).join(),
    ].join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late Server server;
  late _Terminals terminals;
  late KumoEngine engine;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('kumo-surface-');
    terminals = _Terminals();
    server = Server.create(services: [_Core(), terminals]);
    await server.serve(address: InternetAddress.loopbackIPv4, port: 0);
    final file = File('${dir.path}/daemon.json')
      ..writeAsStringSync(jsonEncode({'api_version': kApiVersion, 'pid': pid, 'addr': '127.0.0.1:${server.port}', 'token': 't'}));
    engine = KumoEngine(discovery: DaemonDiscovery(file: file));
  });

  tearDown(() async {
    engine.dispose();
    await server.shutdown();
    dir.deleteSync(recursive: true);
  });

  test('a resize while the terminal is still opening reaches the daemon once attached', () async {
    final surface = GrpcTerminalSurface.shell(engine);
    addTearDown(surface.dispose);
    surface.resize(80, 24); // the first layout: the size it opens at
    await _until(() => terminals.openRequest != null);
    expect((terminals.openRequest!.cols, terminals.openRequest!.rows), (80, 24));

    surface.resize(120, 40); // the pane settles while Open is in flight
    await Future<void>.delayed(const Duration(milliseconds: 150));
    terminals.opened.complete();

    await _until(() => terminals.inputs.any((i) => i.hasResize()));
    final resize = terminals.inputs.lastWhere((i) => i.hasResize()).resize;
    expect((resize.cols, resize.rows), (120, 40));
  });

  test('a terminal opened at its current size gets no extra resize', () async {
    final surface = GrpcTerminalSurface.shell(engine);
    addTearDown(surface.dispose);
    surface.resize(80, 24);
    terminals.opened.complete();
    await _until(() => terminals.inputs.any((i) => i.hasAttach()));
    surface.sendBytes([0x61]);
    await _until(() => terminals.inputs.any((i) => i.hasData()));
    expect(terminals.inputs.where((i) => i.hasResize()), isEmpty);
  });

  group('visibility', () {
    late GrpcTerminalSurface surface;
    final view = Object();

    setUp(() async {
      surface = GrpcTerminalSurface.shell(engine);
      surface.resize(80, 24);
      terminals.opened.complete();
      await _until(() => terminals.inputs.any((i) => i.hasAttach()));
    });

    tearDown(() => surface.dispose());

    test('a shown terminal publishes its output once per frame', () async {
      surface.setVisible(view, true);
      terminals.write('hello');
      await _until(() {
        _frame();
        return _screenOf(surface).contains('hello');
      });
    });

    test('a hidden terminal keeps its output, publishing it all once shown', () async {
      surface.setVisible(view, true);
      terminals.write('one ');
      await _until(() {
        _frame();
        return _screenOf(surface).contains('one');
      });
      surface.setVisible(view, false);
      final shown = surface.buffer.value;
      terminals.write('two ');
      terminals.write('three');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _frame();
      expect(identical(surface.buffer.value, shown), isTrue);
      expect(SchedulerBinding.instance.hasScheduledFrame, isFalse);

      var published = 0;
      surface.buffer.addListener(() => published++);
      surface.setVisible(view, true);
      expect(published, 1);
      expect(_screenOf(surface), contains('one two three'));
    });

    test('a terminal stays shown while any of its views shows it', () async {
      final other = Object();
      surface
        ..setVisible(view, true)
        ..setVisible(other, true)
        ..setVisible(view, false);
      terminals.write('still');
      await _until(() {
        _frame();
        return _screenOf(surface).contains('still');
      });
    });
  });
}
