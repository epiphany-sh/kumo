import '../channel.dart';
import 'host_os.dart';

/// Linux (and any other desktop OS).
class LinuxOs extends HostOs {
  LinuxOs([super.env, super.exists]);

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
  List<String> shellArgsFor(String program) => const ['-l'];

  /// The usual ones that are installed, and `$SHELL` when it's another.
  /// Looked up once.
  @override
  late final List<ShellChoice> shellChoices = [
    for (final path in {'/bin/bash', '/bin/zsh', '/usr/bin/fish', shell})
      if (path == shell || programExists(path)) (value: path, label: path),
  ];

  @override
  (String, List<String>) openUrlCommand(String url) => ('xdg-open', [url]);

  /// File managers have no common "select this" flag: its folder opens.
  @override
  (String, List<String>) revealCommand(String path) {
    final cut = path.lastIndexOf('/');
    return ('xdg-open', [cut > 0 ? path.substring(0, cut) : '/']);
  }

  @override
  String get revealLabel => 'Show in File Manager';

  @override
  String get machineName => 'this computer';

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

  @override
  bool get nativeTitleBar => true;

  /// No Linux runner sets one yet.
  @override
  String? get appIconPlaces => null;
}
