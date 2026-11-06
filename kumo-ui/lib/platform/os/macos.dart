import 'dart:io' show Platform, Process, ProcessException;

import 'package:flutter_acrylic/flutter_acrylic.dart';

import '../channel.dart';
import 'host_os.dart';

/// macOS.
class MacOs extends HostOs {
  MacOs([super.env]);

  @override
  String? get home => env['HOME'] ?? env['USERPROFILE'];

  /// `~/Library/Application Support/Kumo/ui.json` (inside the app container
  /// when sandboxed).
  @override
  String? get preferencesPath {
    final home = env['HOME'];
    return home == null ? null : '$home/Library/Application Support/$settingsDirName/ui.json';
  }

  @override
  String get daemonDiscoveryPath => '${env['HOME']}/Library/Application Support/$engineDirName/daemon.json';

  @override
  String get daemonExecutable => 'kumod';

  @override
  String get loginName => env['USER'] ?? env['USERNAME'] ?? '';

  @override
  String get shell => env['SHELL'] ?? '/bin/zsh';

  @override
  List<String> get shellArgs => const ['-l'];

  @override
  List<String> get shellChoices => const ['/bin/zsh', '/bin/bash', '/opt/homebrew/bin/fish'];

  @override
  String get defaultShellChoice => '/bin/zsh';

  @override
  (String, List<String>) openUrlCommand(String url) => ('open', [url]);

  @override
  Future<String?> openWorkspaceWindow(String id) async {
    // …/Kumo.app/Contents/MacOS/Kumo → …/Kumo.app
    final exe = Platform.resolvedExecutable;
    final at = exe.indexOf('.app/');
    if (at < 0) return 'Kumo isn’t running from its app bundle, so it can’t open another window.';
    final bundle = exe.substring(0, at + 4);
    try {
      final r = await Process.run('open', ['-n', '--env', 'KUMO_WORKSPACE=$id', bundle]);
      return r.exitCode == 0 ? null : 'macOS couldn’t open another Kumo window: ${(r.stderr as Object).toString().trim()}';
    } on ProcessException catch (e) {
      return 'macOS couldn’t open another Kumo window: ${e.message}';
    }
  }

  /// NSVisualEffectView via flutter_acrylic/macos_window_utils, full-size
  /// content view with a transparent unified toolbar so the traffic lights
  /// sit inside our sidebar. Note: this is NSVisualEffectView vibrancy, not
  /// the macOS 26 NSGlassEffectView "Liquid Glass" material — the plugin
  /// doesn't expose that yet.
  @override
  bool get supportsNativeBackdrop => true;

  @override
  Future<void> prepareWindow() async {
    await Window.makeTitlebarTransparent();
    await Window.enableFullSizeContentView();
    await Window.hideTitle();
    await Window.addToolbar();
    await Window.setToolbarStyle(toolbarStyle: MacOSToolbarStyle.unified);
  }

  @override
  Future<void> applyBackdrop({required bool dark}) async {
    await Window.overrideMacOSBrightness(dark: dark);
    await Window.setEffect(effect: WindowEffect.sidebar, dark: dark);
  }

  @override
  bool get windowButtonsInContent => true;
}
