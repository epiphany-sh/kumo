import '../channel.dart';
import 'host_os.dart';

/// Linux (and any other desktop OS).
class LinuxOs extends HostOs {
  LinuxOs([super.env]);

  @override
  String? get home => env['HOME'] ?? env['USERPROFILE'];

  /// `~/.config/kumo/ui.json`.
  @override
  String? get preferencesPath {
    final home = env['HOME'];
    return home == null ? null : '$home/.config/$engineDirName/ui.json';
  }

  /// `$XDG_DATA_HOME/kumo/daemon.json`, else `~/.local/share/kumo/daemon.json`.
  @override
  String get daemonDiscoveryPath {
    final dataDir = env['XDG_DATA_HOME'] ?? '${env['HOME']}/.local/share';
    return '$dataDir/$engineDirName/daemon.json';
  }

  @override
  String get daemonExecutable => 'kumod';

  @override
  String get loginName => env['USER'] ?? env['USERNAME'] ?? '';

  @override
  String get shell => env['SHELL'] ?? '/bin/zsh';

  @override
  List<String> get shellArgs => const ['-l'];

  @override
  List<String> get shellChoices => const ['/bin/bash', '/bin/zsh', '/usr/bin/fish'];

  /// What [shell] falls back to.
  @override
  String get defaultShellChoice => '/bin/zsh';

  @override
  (String, List<String>) openUrlCommand(String url) => ('xdg-open', [url]);

  @override
  Future<String?> openWorkspaceWindow(String id) async => 'Opening a workspace in a new window works on macOS for now.';

  @override
  bool get supportsNativeBackdrop => false;

  @override
  Future<void> prepareWindow() async {}

  @override
  Future<void> applyBackdrop({required bool dark}) async {}

  @override
  bool get windowButtonsInContent => false;

  /// No Linux runner sets one yet.
  @override
  String? get appIconPlaces => null;
}
