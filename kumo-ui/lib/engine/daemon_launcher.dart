import 'dart:io';

/// Finds and starts `kumod` as a detached process, so it outlives the UI
/// (kumo.md §3, §7).
class DaemonLauncher {
  const DaemonLauncher();

  static String get _exe => Platform.isWindows ? 'kumod.exe' : 'kumod';

  /// Where to look, in order:
  /// 1. `KUMOD_PATH`.
  /// 2. Next to the app executable (the release bundle ships it there).
  /// 3. A `target/release` (then `target/debug`) of an ancestor directory:
  ///    the Cargo workspace when running from the repo (`flutter run`).
  String? locate() {
    final override = Platform.environment['KUMOD_PATH'];
    if (override != null && File(override).existsSync()) return override;

    final appDir = File(Platform.resolvedExecutable).parent;
    final bundled = File('${appDir.path}${Platform.pathSeparator}$_exe');
    if (bundled.existsSync()) return bundled.path;

    for (final start in [appDir, Directory.current]) {
      var dir = start.absolute;
      for (var i = 0; i < 12; i++) {
        for (final profile in ['release', 'debug']) {
          final candidate = File([dir.path, 'target', profile, _exe].join(Platform.pathSeparator));
          if (candidate.existsSync()) return candidate.path;
        }
        if (dir.parent.path == dir.path) break;
        dir = dir.parent;
      }
    }
    return null;
  }

  Future<void> launch() async {
    final path = locate();
    if (path == null) {
      throw StateError('kumod not found (set KUMOD_PATH or run `make` at the repo root)');
    }
    await Process.start(
      path,
      const [],
      mode: ProcessStartMode.detached,
      workingDirectory: Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'],
    );
  }
}
