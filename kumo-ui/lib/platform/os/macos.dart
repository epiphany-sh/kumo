import 'dart:io' show Platform, Process, ProcessException;

import 'package:flutter/widgets.dart' show SingleActivator;
import 'package:flutter_acrylic/flutter_acrylic.dart';

import '../channel.dart';
import '../updates.dart';
import 'host_os.dart';
import 'key_combo.dart';

/// macOS.
class MacOs extends HostOs {
  MacOs([super.env, super.exists]);

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
  List<String> shellArgsFor(String program) => const ['-l'];

  /// The usual ones that are installed, and `$SHELL` when it's another.
  /// Looked up once.
  @override
  late final List<ShellChoice> shellChoices = [
    for (final path in {'/bin/zsh', '/bin/bash', '/opt/homebrew/bin/fish', shell})
      if (path == shell || programExists(path)) (value: path, label: path),
  ];

  @override
  bool get commandKey => true;

  @override
  String get altKeyName => '⌥';

  @override
  SingleActivator keyActivator(KeyCombo combo) => commandKeyActivator(combo);

  /// Glyphs in Apple's order (⌃ ⌥ ⇧ ⌘), then the key.
  @override
  List<String> keyCaps(KeyCombo combo) => [if (combo.control) '⌃', if (combo.alt) '⌥', if (combo.shift) '⇧', if (combo.primary) '⌘', combo.keyName ?? combo.macKey ?? macKeyGlyphs[combo.key] ?? plainKeyName(combo.key)];

  @override
  String keyLabel(KeyCombo combo) => keyCaps(combo).join();

  @override
  (String, List<String>) openUrlCommand(String url) => ('open', [url]);

  @override
  (String, List<String>) revealCommand(String path) => ('open', ['-R', path]);

  @override
  String get revealLabel => 'Reveal in Finder';

  @override
  String get machineName => 'this Mac';

  @override
  bool get hasBear => true;

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

  /// Sparkle, in the macOS runner: it checks and downloads by itself, so
  /// [autoUpdate] isn't read here.
  @override
  AppUpdates updates({Future<void> Function()? stopDaemon, bool Function()? autoUpdate}) => SparkleUpdates(stopDaemon: stopDaemon);

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

  /// `NSApp.applicationIconImage`: a closed app shows its bundle's icon.
  @override
  String? get appIconPlaces => 'In the Dock and the app switcher while Kumo runs.';
}
