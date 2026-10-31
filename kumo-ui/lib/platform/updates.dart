import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// New versions of Kumo. This one has none (tests, `flutter run`); the app
/// uses [SparkleUpdates].
class AppUpdates extends ChangeNotifier {
  /// The version downloaded and ready to install, or null.
  String? get ready => null;

  /// Quits, installs [ready] and opens it.
  Future<void> installAndRelaunch() async {}

  /// Quits and opens Kumo again, with a fresh daemon.
  Future<void> relaunch() async {}
}

/// Sparkle, in the macOS runner (`AppDelegate.swift`): release builds check
/// and download in the background, and an update ready to install shows
/// here. Nobody clicks? It installs when Kumo quits.
///
/// [stopDaemon] runs before Kumo quits: the daemon outlives the UI, so
/// without it the relaunched Kumo would find the old `kumod` still running.
class SparkleUpdates extends AppUpdates {
  SparkleUpdates({this.stopDaemon}) {
    _channel.setMethodCallHandler(_onCall);
  }

  final Future<void> Function()? stopDaemon;

  static const _channel = MethodChannel('kumo/updates');
  String? _ready;

  @override
  String? get ready => _ready;

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method == 'ready') {
      _ready = call.arguments as String?;
      notifyListeners();
    }
    return null;
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
      // Not the macOS runner.
    }
  }
}
