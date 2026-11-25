import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'os/host_os.dart';

/// Where checking for a new version is.
sealed class UpdateStatus {
  const UpdateStatus();
}

/// Not checked yet.
final class UpdateIdle extends UpdateStatus {
  const UpdateIdle();
}

/// Asking for the newest version.
final class UpdateChecking extends UpdateStatus {
  const UpdateChecking();
}

/// The newest version is this one.
final class UpdateUpToDate extends UpdateStatus {
  const UpdateUpToDate();
}

/// Downloading [version].
final class UpdateDownloading extends UpdateStatus {
  const UpdateDownloading(this.version);
  final String version;
}

/// [version] is downloaded and checked: a restart installs it.
final class UpdateReady extends UpdateStatus {
  const UpdateReady(this.version);
  final String version;
}

/// The last check or install failed, said for the user.
final class UpdateFailed extends UpdateStatus {
  const UpdateFailed(this.message);
  final String message;
}

/// New versions of Kumo. This one has none (tests, `flutter run`, Linux);
/// [HostOs.updates] picks the one for this OS.
class AppUpdates extends ChangeNotifier {
  /// The version downloaded and ready to install, or null.
  String? get ready => null;

  /// Whether Settings offers "Check for Updates…" ([check], [status]):
  /// only a build that updates itself (never a local or debug one).
  bool get canCheck => false;

  /// Where checking is, for Settings.
  ValueListenable<UpdateStatus> get status => _status;
  final _status = ValueNotifier<UpdateStatus>(const UpdateIdle());

  /// Sets [status].
  @protected
  void setStatus(UpdateStatus value) => _status.value = value;

  /// Checks for a new version now, and downloads it.
  Future<void> check() async {}

  /// Quits, installs [ready] and opens it.
  Future<void> installAndRelaunch() async {}

  /// Quits and opens Kumo again, with a fresh daemon.
  Future<void> relaunch() async {}

  @override
  void dispose() {
    _status.dispose();
    super.dispose();
  }
}

/// [status] as Settings says it.
String describeUpdateStatus(UpdateStatus status) => switch (status) {
      UpdateIdle() => 'Kumo checks for a new version every hour while automatic downloads are on.',
      UpdateChecking() => 'Checking…',
      UpdateUpToDate() => 'Kumo is up to date.',
      UpdateDownloading(:final version) => 'Downloading Kumo $version…',
      UpdateReady(:final version) => 'Kumo $version is ready: restart to install it.',
      UpdateFailed(:final message) => message,
    };

/// Sparkle, in the macOS runner (`AppDelegate.swift`): release builds check
/// and download in the background, and an update ready to install shows
/// here. Nobody clicks? It installs when Kumo quits. Without the macOS
/// runner, [relaunch] goes to [HostOs.relaunchAfterExit].
///
/// The runner says "available" once Sparkle runs (a release build, with a
/// feed): then Settings offers [check], which opens Sparkle's own window
/// with how the check went.
///
/// [stopDaemon] runs before Kumo quits: the daemon outlives the UI, so
/// without it the relaunched Kumo would find the old `kumod` still running.
class SparkleUpdates extends AppUpdates {
  SparkleUpdates({this.stopDaemon}) {
    _channel.setMethodCallHandler(_onCall);
    _askAvailable();
  }

  /// Whether Sparkle runs already; if it starts later, the runner says so.
  Future<void> _askAvailable() async {
    try {
      if (await _channel.invokeMethod<bool>('available') == true && !_available) {
        _available = true;
        notifyListeners();
      }
    } on MissingPluginException {
      // Not the macOS runner.
    } on PlatformException {
      // An older runner, without "available".
    }
  }

  final Future<void> Function()? stopDaemon;

  static const _channel = MethodChannel('kumo/updates');
  String? _ready;
  var _available = false;

  @override
  String? get ready => _ready;

  @override
  bool get canCheck => _available;

  Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'ready':
        _ready = call.arguments as String?;
        notifyListeners();
      case 'available':
        _available = call.arguments == true;
        notifyListeners();
    }
    return null;
  }

  @override
  Future<void> check() async {
    try {
      await _channel.invokeMethod<void>('check');
    } on MissingPluginException {
      // Not the macOS runner: nothing checks.
    }
  }

  @override
  Future<void> installAndRelaunch() => _quitFor('install');

  @override
  Future<void> relaunch() => _quitFor('relaunch');

  Future<void> _quitFor(String method) async {
    await stopDaemon?.call();
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Not the macOS runner: the OS starts Kumo again once it has quit
      // (Windows); installing is Sparkle's, so macOS only.
      if (method == 'relaunch' && !kIsWeb) await hostOs.relaunchAfterExit();
    }
  }
}
