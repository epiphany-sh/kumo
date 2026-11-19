import 'dart:io' show Platform, Process, ProcessException, ProcessStartMode;

import 'package:flutter_acrylic/flutter_acrylic.dart';

import '../channel.dart';
import 'host_os.dart';

/// Windows.
class WindowsOs extends HostOs {
  /// [onPath] and [exists] stand in for `%PATH%` lookups in tests.
  WindowsOs([super.env, bool Function(String exe)? onPath, super.exists]) : _onPath = onPath;

  @override
  String? get home => env['HOME'] ?? env['USERPROFILE'];

  /// `%APPDATA%\Kumo\ui.json`.
  @override
  String? get preferencesPath {
    final appData = env['APPDATA'];
    return appData == null ? null : '$appData\\$settingsDirName\\ui.json';
  }

  /// `%LOCALAPPDATA%\kumo\daemon.json`.
  @override
  String get daemonDiscoveryPath {
    final dataDir = env['LOCALAPPDATA'] ?? '${env['USERPROFILE']}\\AppData\\Local';
    return '$dataDir\\$engineDirName\\daemon.json';
  }

  @override
  String get daemonExecutable => 'kumod.exe';

  @override
  String get loginName => env['USER'] ?? env['USERNAME'] ?? '';

  static const _pwsh = 'pwsh.exe';
  static const _powershell = 'powershell.exe';

  /// Whether [exe] is on `%PATH%` (injectable for tests).
  final bool Function(String exe)? _onPath;

  bool _found(String exe) => _onPath?.call(exe) ?? _searchPath(exe);

  /// Network folders (`\\server\share`) are skipped: checking one that
  /// doesn't answer blocks the UI until it times out.
  bool _searchPath(String exe) {
    final path = env['PATH'] ?? env['Path'] ?? '';
    for (final dir in path.split(';')) {
      if (dir.isEmpty || dir.startsWith(r'\\') || dir.startsWith('//')) continue;
      if (fileExists(dir.endsWith(r'\') ? '$dir$exe' : '$dir\\$exe')) return true;
    }
    return false;
  }

  /// [rest] under the folder in environment variable [variable].
  String? _under(String variable, String rest) {
    final dir = env[variable];
    return dir == null || dir.isEmpty ? null : '$dir\\$rest';
  }

  /// Where [exe] is: its installer's folder [installed] when it's there
  /// (checked first, so `%PATH%` usually isn't), else [exe] when it's on
  /// `%PATH%`; null when neither.
  String? _locate(String exe, String? installed) {
    if (installed != null && fileExists(installed)) return installed;
    return _found(exe) ? exe : null;
  }

  late final String? _pwshAt = _locate(_pwsh, _under('ProgramFiles', r'PowerShell\7\pwsh.exe'));
  late final String? _powershellAt = _locate(_powershell, _under('SystemRoot', r'System32\WindowsPowerShell\v1.0\powershell.exe'));
  String get _cmd => env['COMSPEC'] ?? 'cmd.exe';

  /// PowerShell 7, else Windows PowerShell, else cmd.exe. Not `$SHELL`:
  /// Git Bash sets it, and a POSIX path isn't a program to start here.
  @override
  String get shell => _pwshAt ?? _powershellAt ?? _cmd;

  static String _fileName(String program) => program.split(RegExp(r'[\\/]')).last.toLowerCase();

  /// No login flag here; PowerShell skips its banner.
  @override
  List<String> shellArgsFor(String program) {
    final name = _fileName(program);
    return name == _pwsh || name == _powershell ? const ['-NoLogo'] : const [];
  }

  /// Looked up once.
  @override
  late final List<ShellChoice> shellChoices = [
    if (_pwshAt case final pwsh?) (value: pwsh, label: 'PowerShell 7'),
    if (_powershellAt case final powershell?) (value: powershell, label: 'Windows PowerShell'),
    (value: _cmd, label: 'Command Prompt'),
  ];

  /// Also by file name, any case: Settings saved `cmd.exe` and `pwsh.exe`
  /// before it saved where they are.
  @override
  String? offeredShell(String chosen) {
    final name = _fileName(chosen);
    return super.offeredShell(chosen) ?? shellChoices.map((c) => c.value).where((v) => _fileName(v) == name).firstOrNull;
  }

  @override
  String get shellDescription => 'Shell for new tabs (${paneShortcutLabel(PaneShortcut.newTab)}) and splits.';

  @override
  (String, List<String>) openUrlCommand(String url) => ('rundll32', ['url.dll,FileProtocolHandler', url]);

  /// Explorer selects nothing for a path with `/` (git prints worktrees so).
  @override
  (String, List<String>) revealCommand(String path) => ('explorer.exe', ['/select,${path.replaceAll('/', r'\')}']);

  @override
  String get revealLabel => 'Show in Explorer';

  @override
  String get machineName => 'this PC';

  /// The same executable again, told its workspace by `KUMO_WORKSPACE`
  /// (`launchWorkspace`): (program, args, extra environment).
  (String, List<String>, Map<String, String>) workspaceWindowCommand(String exe, String id) => (exe, const [], {'KUMO_WORKSPACE': id});

  @override
  Future<String?> openWorkspaceWindow(String id) async {
    final (exe, args, extra) = workspaceWindowCommand(Platform.resolvedExecutable, id);
    try {
      await Process.start(exe, args, environment: extra, mode: ProcessStartMode.detached);
      return null;
    } on ProcessException catch (e) {
      return 'Windows couldn’t open another Kumo window: ${e.message}';
    }
  }

  /// Windows 11: Mica. Windows 10: Acrylic (known drag lag on Win10).
  @override
  bool get supportsNativeBackdrop => true;

  @override
  Future<void> prepareWindow() async {}

  @override
  Future<void> applyBackdrop({required bool dark}) => Window.setEffect(effect: WindowEffect.mica, dark: dark);

  @override
  bool get windowButtonsInContent => false;

  /// `WM_SETICON` on the window (`flutter_window.cpp`); a button pinned to
  /// the taskbar may keep its shortcut's icon.
  @override
  String? get appIconPlaces => 'On the window and its taskbar button while Kumo runs.';
}
