import 'dart:io' as io show exit, pid;
import 'dart:io' show Platform, Process, ProcessException, ProcessStartMode;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_acrylic/flutter_acrylic.dart';

import '../channel.dart';
import '../updates.dart';
import '../updates_windows.dart';
import 'host_os.dart';
import 'key_combo.dart';

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

  /// Quoted only when a path has more than letters, digits and `_-.:\/`:
  /// in single quotes for PowerShell (a quote inside doubled, typographic
  /// ones too, which PowerShell also reads as quotes); in double quotes for
  /// cmd.exe and anything else, as Windows Terminal drops files (a Windows
  /// path can't hold `"`). A path with `"` or a control character is left
  /// out: no file has one, so it's forged, and a quote or line break would
  /// end the quoting or run a command.
  @override
  String shellPaths(List<String> paths, {String? shell}) {
    final name = shell == null ? '' : _fileName(shell).replaceFirst(RegExp(r'\.exe$'), '');
    final powerShell = name == 'pwsh' || name == 'powershell';
    return [
      for (final p in paths.where((p) => !_notAPath.hasMatch(p)))
        if (!_needsQuotes.hasMatch(p))
          p
        else if (powerShell)
          "'${p.replaceAllMapped(_powerShellQuote, (m) => '${m[0]}${m[0]}')}'"
        else
          '"$p"',
    ].join(' ');
  }

  static final _notAPath = RegExp('["\\x00-\\x1f\\x7f-\\x9f]');
  static final _needsQuotes =RegExp(r'[^A-Za-z0-9_\-.:\\/]');
  static final _powerShellQuote = RegExp('[\'‘’‚‛]');

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

  /// Splits as on macOS (⌘D right, ⇧⌘D down) with Ctrl: Ctrl+D no longer
  /// reaches the shell as EOF here.
  @override
  KeyCombo paneKey(PaneShortcut command) => switch (command) {
        PaneShortcut.splitRight => const KeyCombo(LogicalKeyboardKey.keyD, primary: true),
        PaneShortcut.splitDown => const KeyCombo(LogicalKeyboardKey.keyD, primary: true, shift: true),
        _ => super.paneKey(command),
      };

  /// As Windows Terminal: Ctrl+C copies a selection (^C without one) and
  /// Ctrl+V pastes.
  @override
  bool get terminalCtrlClipboard => true;

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

  /// A hidden Windows PowerShell waits for Kumo to exit, then starts it
  /// again: the files it was running can be swapped by then (an update).
  /// The pid and the path go in its environment, so a path with quotes or
  /// spaces stays data, never PowerShell code.
  (String, List<String>, Map<String, String>) relaunchCommand(int pid, String exe) => (
        _powershellAt ?? _powershell,
        const [
          '-NoProfile',
          '-NonInteractive',
          '-WindowStyle',
          'Hidden',
          '-Command',
          r'Wait-Process -Id $env:KUMO_RELAUNCH_PID -Timeout 60 -ErrorAction SilentlyContinue; Start-Process -FilePath $env:KUMO_RELAUNCH_EXE',
        ],
        {'KUMO_RELAUNCH_PID': '$pid', 'KUMO_RELAUNCH_EXE': exe},
      );

  @override
  Future<bool> relaunchAfterExit({int? pid, String? exe, ProcessStarter start = Process.start, void Function(int code) exit = io.exit}) async {
    final (program, args, extra) = relaunchCommand(pid ?? io.pid, exe ?? Platform.resolvedExecutable);
    try {
      await start(program, args, environment: extra, mode: ProcessStartMode.detached);
    } on ProcessException {
      return false;
    }
    exit(0);
    return true;
  }

  /// Kumo's own updater ([WindowsUpdates]): GitHub releases and their
  /// signed `-setup.exe`, run silently.
  @override
  AppUpdates updates({Future<void> Function()? stopDaemon, bool Function()? autoUpdate}) =>
      WindowsUpdates(config: UpdateConfig.fromEnvironment(env), stopDaemon: stopDaemon, autoUpdate: autoUpdate);

  /// Windows 11: Mica. Windows 10: Acrylic (known drag lag on Win10).
  @override
  bool get supportsNativeBackdrop => true;

  @override
  Future<void> prepareWindow() async {}

  @override
  Future<void> applyBackdrop({required bool dark}) => Window.setEffect(effect: WindowEffect.mica, dark: dark);

  @override
  bool get windowButtonsInContent => false;

  @override
  bool get nativeTitleBar => true;

  /// `WM_SETICON` on the window (`flutter_window.cpp`); a button pinned to
  /// the taskbar may keep its shortcut's icon.
  @override
  String? get appIconPlaces => 'On the window and its taskbar button while Kumo runs.';
}
