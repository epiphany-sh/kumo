import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';

import 'daemon_endpoint.dart';
import 'daemon_launcher.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart';

/// API version this UI speaks (`ApiVersion::CURRENT` in the daemon).
const kApiVersion = 1;

enum EngineStatus { connecting, ready, failed }

/// An authenticated connection to `kumod`.
class EngineConnection {
  EngineConnection._(this.channel, this.endpoint, this.serverVersion, CallOptions auth)
      : core = CoreClient(channel, options: auth),
        terminals = TerminalsClient(channel, options: auth),
        workspace = WorkspaceClient(channel, options: auth),
        git = GitClient(channel, options: auth),
        agents = AgentsClient(channel, options: auth),
        tasks = TasksClient(channel, options: auth);

  final ClientChannel channel;
  final DaemonEndpoint endpoint;
  final String serverVersion;
  final CoreClient core;
  final TerminalsClient terminals;
  final WorkspaceClient workspace;
  final GitClient git;
  final AgentsClient agents;
  final TasksClient tasks;
}

/// Discovers or launches the daemon, handshakes and hands out the
/// connection. The UI never blocks on it: callers await [connection].
class KumoEngine extends ChangeNotifier {
  KumoEngine({DaemonDiscovery? discovery, this.launcher = const DaemonLauncher()}) : discovery = discovery ?? DaemonDiscovery();

  final DaemonDiscovery discovery;
  final DaemonLauncher launcher;

  EngineStatus _status = EngineStatus.connecting;
  EngineStatus get status => _status;

  String? _error;
  String? get error => _error;

  EngineConnection? _connection;
  EngineConnection? get current => _connection;

  Future<EngineConnection>? _connecting;

  /// The live connection, connecting (and launching `kumod`) if needed.
  /// After a failure, the next call tries again.
  Future<EngineConnection> connection() {
    final ready = _connection;
    if (ready != null) return Future.value(ready);
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<EngineConnection> _connect() async {
    _set(EngineStatus.connecting);
    final started = Stopwatch()..start();
    try {
      final advertised = await discovery.read();
      if (advertised != null) {
        try {
          return _ready(await _handshake(advertised), started, launched: false);
        } on Object {
          // Stale file: the daemon died without cleaning up. Launch a new one.
        }
      }
      await launcher.launch();
      final endpoint = await discovery.waitFor(stalePid: advertised?.pid);
      return _ready(await _handshake(endpoint), started, launched: true);
    } on Object catch (e) {
      _error = '$e';
      _set(EngineStatus.failed);
      rethrow;
    }
  }

  EngineConnection _ready(EngineConnection connection, Stopwatch started, {required bool launched}) {
    _connection = connection;
    _error = null;
    debugPrint('kumo: connected to kumod ${connection.serverVersion} at '
        '${connection.endpoint.host}:${connection.endpoint.port} '
        '(${launched ? 'launched' : 'already running'}, ${started.elapsedMilliseconds} ms)');
    _set(EngineStatus.ready);
    return connection;
  }

  Future<EngineConnection> _handshake(DaemonEndpoint endpoint) async {
    final channel = ClientChannel(
      endpoint.host,
      port: endpoint.port,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure(), connectTimeout: Duration(seconds: 2)),
    );
    final auth = CallOptions(metadata: {'authorization': 'Bearer ${endpoint.token}'});
    try {
      final hello = await CoreClient(channel, options: auth).hello(
        HelloRequest(clientApiVersion: kApiVersion, clientName: 'kumo-ui'),
        options: CallOptions(timeout: const Duration(seconds: 2)),
      );
      if (hello.serverApiVersion != kApiVersion) {
        throw StateError('kumod speaks API v${hello.serverApiVersion}, this UI needs v$kApiVersion. Restart the daemon.');
      }
      return EngineConnection._(channel, endpoint, hello.serverVersion, auth);
    } on Object {
      await channel.shutdown();
      rethrow;
    }
  }

  /// Terminals the daemon is still running (e.g. from a previous UI run).
  Future<List<TerminalInfo>> runningTerminals() async {
    final conn = await connection();
    final list = await conn.terminals.list(ListRequest());
    return [for (final t in list.terminals) if (!t.exited) t];
  }

  void _set(EngineStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _connection?.channel.shutdown();
    super.dispose();
  }
}
