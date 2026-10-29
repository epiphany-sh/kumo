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
  EngineConnection._(this.channel, this.endpoint, this.serverVersion, CallOptions auth, {this.outdated = false})
      : core = CoreClient(channel, options: auth),
        terminals = TerminalsClient(channel, options: auth),
        workspace = WorkspaceClient(channel, options: auth),
        git = GitClient(channel, options: auth),
        agents = AgentsClient(channel, options: auth),
        tasks = TasksClient(channel, options: auth),
        pipelines = PipelinesClient(channel, options: auth),
        pulls = PullRequestsClient(channel, options: auth),
        docs = DocsClient(channel, options: auth),
        tests = TestsClient(channel, options: auth);

  final ClientChannel channel;
  final DaemonEndpoint endpoint;
  final String serverVersion;

  /// The daemon's program was replaced on disk (an update or a rebuild):
  /// it runs the old one until restarted.
  final bool outdated;
  final CoreClient core;
  final TerminalsClient terminals;
  final WorkspaceClient workspace;
  final GitClient git;
  final AgentsClient agents;
  final TasksClient tasks;
  final PipelinesClient pipelines;
  final PullRequestsClient pulls;
  final DocsClient docs;
  final TestsClient tests;
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

  /// The daemon runs an old program (see [EngineConnection.outdated]). It
  /// restarts on its own once no terminal runs; [restartDaemon] does it now.
  bool get outdated => _connection?.outdated ?? false;

  /// Terminals running in an [outdated] daemon: they end with it.
  int get runningInOutdated => _running;
  int _running = 0;

  /// The daemon is restarting: its streams end, and that's no error.
  bool get restarting => _restarting;
  bool _restarting = false;
  Timer? _idleCheck;

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
    if (connection.outdated) _watchIdle();
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
      return EngineConnection._(channel, endpoint, hello.serverVersion, auth, outdated: hello.outdated);
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

  /// Checks every few seconds whether the outdated daemon is idle, and
  /// restarts it then.
  void _watchIdle() {
    _idleCheck?.cancel();
    _idleCheck = Timer.periodic(const Duration(seconds: 3), (_) => _restartIfIdle());
    _restartIfIdle();
  }

  Future<void> _restartIfIdle() async {
    final conn = _connection;
    if (conn == null || !conn.outdated || _restarting) return;
    try {
      final running = (await runningTerminals()).length;
      if (running != _running) {
        _running = running;
        notifyListeners();
      }
      if (running == 0) await restartDaemon();
    } on Object catch (e) {
      debugPrint('kumo: checking the outdated daemon failed: $e');
    }
  }

  /// Stops the daemon and starts the new program in its place. [force]
  /// ends its running terminals; without it the daemon refuses while one
  /// runs. Calls for the connection meanwhile get the new daemon's.
  Future<void> restartDaemon({bool force = false}) async {
    final old = _connection;
    if (old == null || _restarting) return;
    _restarting = true;
    _idleCheck?.cancel();
    _connection = null;
    _set(EngineStatus.connecting);
    final restarted = _restart(old, force);
    _connecting = restarted.whenComplete(() => _connecting = null);
    try {
      await _connecting;
    } on Object {
      // Reported through [status] and [error].
    } finally {
      _restarting = false;
      notifyListeners();
    }
  }

  Future<EngineConnection> _restart(EngineConnection old, bool force) async {
    try {
      await old.core.shutdown(ShutdownRequest(ifIdle: !force));
    } on GrpcError catch (e) {
      if (e.code != StatusCode.failedPrecondition) rethrow;
      // A terminal started since we looked: keep the daemon, look again.
      _connection = old;
      _set(EngineStatus.ready);
      _watchIdle();
      return old;
    }
    debugPrint('kumo: restarting kumod ${old.serverVersion} (pid ${old.endpoint.pid}) to run its update');
    await old.channel.shutdown();
    await discovery.waitGone(old.endpoint.pid);
    _running = 0;
    return _connect();
  }

  void _set(EngineStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _idleCheck?.cancel();
    _connection?.channel.shutdown();
    super.dispose();
  }
}
