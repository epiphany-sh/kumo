import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:kumo_ui/engine/daemon_endpoint.dart';
import 'package:kumo_ui/engine/engine_workspace_source.dart';
import 'package:kumo_ui/engine/generated/kumo/v1/kumo.pbgrpc.dart';
import 'package:kumo_ui/engine/kumo_engine.dart';

class _Core extends CoreServiceBase {
  @override
  Future<HelloResponse> hello(ServiceCall call, HelloRequest request) async => HelloResponse(serverApiVersion: kApiVersion, serverVersion: 'test');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A daemon that records who watches and what presence it hears.
class _Workspace extends WorkspaceServiceBase {
  final watchers = <String?>[];
  final told = <(String?, SetPresenceRequest)>[];
  StreamController<WorkspaceSnapshot>? _stream;

  @override
  Stream<WorkspaceSnapshot> watch(ServiceCall call, WatchWorkspaceRequest request) {
    watchers.add(call.clientMetadata?['kumo-client']);
    final stream = _stream = StreamController<WorkspaceSnapshot>()..add(WorkspaceSnapshot());
    return stream.stream;
  }

  /// Ends the current watch, as a restarting daemon does.
  Future<void> drop() async => _stream?.close();

  @override
  Future<SetPresenceResponse> setPresence(ServiceCall call, SetPresenceRequest request) async {
    told.add((call.clientMetadata?['kumo-client'], request));
    return SetPresenceResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _until(bool Function() done, {Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

String _said(SetPresenceRequest p) => '${p.focused ? 'focused' : 'unfocused'} ${p.visible ? 'visible' : 'hidden'}';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('the daemon hears whether the window is in front, behind or out of sight', () {
    String told(AppLifecycleState state) => _said(presenceOf(state));

    expect(told(AppLifecycleState.resumed), 'focused visible');
    expect(told(AppLifecycleState.inactive), 'unfocused visible');
    expect(told(AppLifecycleState.hidden), 'unfocused hidden');
    expect(told(AppLifecycleState.paused), 'unfocused hidden');
    expect(told(AppLifecycleState.detached), 'unfocused hidden');
  });

  group('on connect', () {
    late Directory dir;
    late Server server;
    late _Workspace workspace;
    late KumoEngine engine;
    EngineWorkspaceSource? source;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('kumo-presence-');
      workspace = _Workspace();
      server = Server.create(services: [_Core(), workspace]);
      await server.serve(address: InternetAddress.loopbackIPv4, port: 0);
      final file = File('${dir.path}/daemon.json')
        ..writeAsStringSync(jsonEncode({'api_version': kApiVersion, 'pid': pid, 'addr': '127.0.0.1:${server.port}', 'token': 't'}));
      engine = KumoEngine(discovery: DaemonDiscovery(file: file));
    });

    tearDown(() async {
      source?.dispose();
      source = null;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await workspace.drop();
      await engine.current?.channel.shutdown();
      engine.dispose();
      await server.shutdown();
      dir.deleteSync(recursive: true);
    });

    test('the daemon hears the current presence without waiting for a change, as the client that watches', () async {
      // Already behind other windows when Kumo connects: no transition.
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      source = EngineWorkspaceSource(engine);

      await _until(() => workspace.told.isNotEmpty);
      final (client, presence) = workspace.told.single;
      expect(_said(presence), 'unfocused visible');
      expect(client, isNotEmpty);
      expect(workspace.watchers, [client], reason: 'the presence belongs to the watch');
    });

    test('a reconnect tells the presence again', () async {
      source = EngineWorkspaceSource(engine);
      await _until(() => workspace.told.length == 1);

      await workspace.drop();
      await _until(() => workspace.told.length == 2, timeout: const Duration(seconds: 10));
      expect(workspace.watchers, hasLength(2));
      expect(_said(workspace.told.last.$2), 'focused visible');
      expect(workspace.told.last.$1, workspace.watchers.last);
    });
  });
}
