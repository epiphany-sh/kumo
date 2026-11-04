import 'package:flutter_acrylic/flutter_acrylic.dart';

import 'host_os.dart';

/// Windows.
class WindowsOs extends HostOs {
  WindowsOs([super.env]);

  @override
  String? get home => env['HOME'] ?? env['USERPROFILE'];

  /// `%APPDATA%\Kumo\ui.json`.
  @override
  String? get preferencesPath {
    final appData = env['APPDATA'];
    return appData == null ? null : '$appData\\Kumo\\ui.json';
  }

  /// `%LOCALAPPDATA%\kumo\daemon.json`.
  @override
  String get daemonDiscoveryPath {
    final dataDir = env['LOCALAPPDATA'] ?? '${env['USERPROFILE']}\\AppData\\Local';
    return '$dataDir\\kumo\\daemon.json';
  }

  @override
  String get daemonExecutable => 'kumod.exe';

  @override
  String get loginName => env['USER'] ?? env['USERNAME'] ?? '';

  @override
  String get shell => env['SHELL'] ?? env['COMSPEC'] ?? 'cmd.exe';

  /// cmd.exe and PowerShell have no login flag.
  @override
  List<String> get shellArgs => const [];

  @override
  List<String> get shellChoices => const ['cmd.exe', 'powershell.exe', 'pwsh.exe'];

  /// What [shell] falls back to (`COMSPEC` is cmd.exe).
  @override
  String get defaultShellChoice => 'cmd.exe';

  @override
  (String, List<String>) openUrlCommand(String url) => ('rundll32', ['url.dll,FileProtocolHandler', url]);

  @override
  Future<String?> openWorkspaceWindow(String id) async => 'Opening a workspace in a new window works on macOS for now.';

  /// Windows 11: Mica. Windows 10: Acrylic (known drag lag on Win10).
  @override
  bool get supportsNativeBackdrop => true;

  @override
  Future<void> prepareWindow() async {}

  @override
  Future<void> applyBackdrop({required bool dark}) => Window.setEffect(effect: WindowEffect.mica, dark: dark);

  @override
  bool get windowButtonsInContent => false;
}
