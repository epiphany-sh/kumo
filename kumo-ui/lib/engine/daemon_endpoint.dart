import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// What the daemon advertises in its discovery file (`daemon.json`).
class DaemonEndpoint {
  const DaemonEndpoint({required this.apiVersion, required this.pid, required this.host, required this.port, required this.token});

  final int apiVersion;
  final int pid;
  final String host;
  final int port;
  final String token;

  /// Parses `{ api_version, pid, addr: "127.0.0.1:1234", token }`.
  factory DaemonEndpoint.fromJson(Map<String, Object?> json) {
    final addr = json['addr']! as String;
    final colon = addr.lastIndexOf(':');
    var host = addr.substring(0, colon);
    if (host.startsWith('[') && host.endsWith(']')) host = host.substring(1, host.length - 1);
    return DaemonEndpoint(
      apiVersion: json['api_version']! as int,
      pid: json['pid']! as int,
      host: host,
      port: int.parse(addr.substring(colon + 1)),
      token: json['token']! as String,
    );
  }
}

/// Reads the discovery file at the same per-user location `kumod` writes it
/// (Rust `dirs::data_local_dir()/kumo/daemon.json`).
class DaemonDiscovery {
  DaemonDiscovery({File? file}) : file = file ?? File(defaultPath());

  final File file;

  static String defaultPath() {
    final env = Platform.environment;
    final sep = Platform.pathSeparator;
    final String dataDir;
    if (Platform.isMacOS) {
      dataDir = '${env['HOME']}/Library/Application Support';
    } else if (Platform.isWindows) {
      dataDir = env['LOCALAPPDATA'] ?? '${env['USERPROFILE']}\\AppData\\Local';
    } else {
      dataDir = env['XDG_DATA_HOME'] ?? '${env['HOME']}/.local/share';
    }
    return '$dataDir${sep}kumo${sep}daemon.json';
  }

  /// The advertised endpoint, or null if there is none (or it is unreadable).
  Future<DaemonEndpoint?> read() async {
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      return DaemonEndpoint.fromJson(json);
    } on Object {
      return null;
    }
  }

  /// Polls until a *new* endpoint shows up (pid differs from [stalePid]).
  Future<DaemonEndpoint> waitFor({int? stalePid, Duration timeout = const Duration(seconds: 5)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final endpoint = await read();
      if (endpoint != null && endpoint.pid != stalePid) return endpoint;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw TimeoutException('kumod did not write ${file.path} within ${timeout.inMilliseconds} ms');
  }
}
