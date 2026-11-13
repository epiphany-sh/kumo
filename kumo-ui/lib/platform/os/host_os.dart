import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'linux.dart';
import 'macos.dart';
import 'windows.dart';

/// Everything Kumo does differently per operating system, behind one
/// interface. Each OS has its own file ([MacOs], [WindowsOs], [LinuxOs]),
/// so a fix for one can't change another's behavior.
///
/// [hostOs] picks the implementation; it is the only place in `lib/` that
/// reads `Platform.isMacOS` / `isWindows` / `isLinux`. It throws on the web
/// (`dart:io` isn't there): callers keep their `!kIsWeb &&` guard first.
abstract class HostOs {
  HostOs([Map<String, String>? env]) : env = env ?? Platform.environment;

  /// The process environment (injectable for tests).
  final Map<String, String> env;

  // Files and directories.

  /// The user's home directory, or null when the environment doesn't say.
  String? get home;

  /// Where the UI keeps its settings (`ui.json`), or null when unknown.
  String? get preferencesPath;

  /// The discovery file `kumod` writes: Rust `dirs::data_local_dir()/kumo/daemon.json`.
  String get daemonDiscoveryPath;

  /// The daemon's executable file name.
  String get daemonExecutable;

  /// The OS login name, or '' when unknown.
  String get loginName;

  // Terminal.

  /// The shell a new terminal runs.
  String get shell;

  /// Arguments for [shell] (a login shell where that exists).
  List<String> get shellArgs;

  /// Shells offered in Settings → Terminal, and the one preselected.
  List<String> get shellChoices;
  String get defaultShellChoice;

  // Desktop integration.

  /// The program (and its arguments) that opens [url] in the app the OS picks.
  (String, List<String>) openUrlCommand(String url);

  /// Opens Kumo again, in its own window, on workspace [id]. Null when it
  /// started; otherwise why it couldn't.
  Future<String?> openWorkspaceWindow(String id);

  // Window.

  /// Whether the OS can draw a translucent backdrop behind Flutter.
  bool get supportsNativeBackdrop;

  /// One-time window setup after the backdrop plugin initialized.
  Future<void> prepareWindow();

  /// Applies the native backdrop for a light or dark theme.
  Future<void> applyBackdrop({required bool dark});

  /// Whether the native window buttons (traffic lights) sit inside our
  /// content once the native backdrop is on, so the layout leaves room.
  bool get windowButtonsInContent;

  /// Where the icon chosen in Settings › Appearance shows, said for the
  /// user; null when the app can't change its own icon here.
  String? get appIconPlaces;
}

HostOs? _override;
HostOs? _detected;

/// The running OS. Chosen once.
HostOs get hostOs => _override ?? (_detected ??= _detect());

/// Replaces [hostOs] in tests; null restores the real one.
@visibleForTesting
set debugHostOs(HostOs? os) => _override = os;

HostOs _detect() {
  if (Platform.isMacOS) return MacOs();
  if (Platform.isWindows) return WindowsOs();
  return LinuxOs();
}
