import 'dart:io' show File, Platform, Process, ProcessException, ProcessStartMode;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart' show SingleActivator;

import 'key_combo.dart';
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
  /// [exists] stands in for the file system in tests.
  HostOs([Map<String, String>? env, bool Function(String path)? exists])
      : env = env ?? Platform.environment,
        fileExists = exists ?? ((path) => File(path).existsSync());

  /// The process environment (injectable for tests).
  final Map<String, String> env;

  /// Whether a file is at the path (injectable for tests).
  final bool Function(String path) fileExists;

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

  /// The shell a new terminal runs while Settings → Terminal has none.
  String get shell;

  /// Arguments for [program], one of the shells (a login shell where that
  /// exists).
  List<String> shellArgsFor(String program);

  /// Shells offered in Settings → Terminal: the ones installed here, and
  /// [shell] always (what Settings preselects).
  List<ShellChoice> get shellChoices;

  /// Whether [program] is there to run: the file, for a path; else a file
  /// of that name in a `$PATH` folder.
  bool programExists(String program) {
    if (program.contains('/')) return fileExists(program);
    return (env['PATH'] ?? '').split(':').any((dir) => dir.isNotEmpty && fileExists('$dir/$program'));
  }

  /// The offered shell a saved [chosen] stands for, or null when none is.
  String? offeredShell(String chosen) => shellChoices.any((c) => c.value == chosen) ? chosen : null;

  /// What a new terminal runs for the shell [chosen] in Settings: that one
  /// while it's offered (so installed), else [shell].
  String resolveShell(String? chosen) => (chosen == null ? null : offeredShell(chosen)) ?? shell;

  /// Settings → Terminal → Shell, said for the user.
  String get shellDescription => 'Login shell for new tabs (${paneShortcutLabel(PaneShortcut.newTab)}) and splits.';

  // Keys.

  /// Whether the app's primary modifier is ⌘ (macOS), not Ctrl.
  bool get commandKey => false;

  /// What the Option / Alt key is called.
  String get altKeyName => 'Alt';

  /// [combo] as this OS binds it: [KeyCombo.primary] is Ctrl, and
  /// [KeyCombo.control] next to it Alt.
  SingleActivator keyActivator(KeyCombo combo) => ctrlKeyActivator(combo);

  /// [combo]'s keys, one per cap: ['Ctrl', 'Shift', 'D'].
  List<String> keyCaps(KeyCombo combo) => ctrlKeyCaps(combo);

  /// [combo] as menus and tooltips show it: "Ctrl+Shift+D".
  String keyLabel(KeyCombo combo) => keyCaps(combo).join('+');

  /// The key for a terminal pane command: Ctrl+Shift off macOS, like
  /// Windows Terminal and GNOME Terminal, so the shell keeps Ctrl+D / T / W.
  SingleActivator paneShortcut(PaneShortcut command) => keyActivator(AppKeys.pane(command));

  /// [paneShortcut] as menus and tooltips show it.
  String paneShortcutLabel(PaneShortcut command) => keyLabel(AppKeys.pane(command));

  // Desktop integration.

  /// The program (and its arguments) that opens [url] in the app the OS picks.
  (String, List<String>) openUrlCommand(String url);

  /// The program (and its arguments) that shows [path] in the file manager.
  (String, List<String>) revealCommand(String path);

  /// What a menu calls [revealCommand].
  String get revealLabel;

  /// Shows [path] in the file manager. Null when it opened; otherwise why
  /// it couldn't.
  Future<String?> revealInFileManager(String path) async {
    final (program, args) = revealCommand(path);
    try {
      await Process.start(program, args, mode: ProcessStartMode.detached);
      return null;
    } on ProcessException catch (e) {
      return 'Couldn’t open the file manager: ${e.message}';
    }
  }

  /// The computer Kumo runs on, as copy names it ("on this Mac").
  String get machineName;

  /// Whether Bear (a macOS app) can be a task source here.
  bool get hasBear => false;

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

/// [combo] bound as macOS binds it: [KeyCombo.primary] is ⌘.
SingleActivator commandKeyActivator(KeyCombo combo) => SingleActivator(combo.key, meta: combo.primary, control: combo.control, alt: combo.alt, shift: combo.shift);

/// [combo] bound as Windows and Linux bind it: [KeyCombo.primary] is Ctrl,
/// and [KeyCombo.control] next to it Alt.
SingleActivator ctrlKeyActivator(KeyCombo combo) {
  final k = combo.elsewhere ?? combo;
  return SingleActivator(k.key, control: k.primary || k.control, alt: k.alt || (k.primary && k.control), shift: k.shift);
}

/// [combo]'s keys as Windows and Linux spell them: ['Ctrl', 'Shift', 'D'].
List<String> ctrlKeyCaps(KeyCombo combo) {
  final k = combo.elsewhere ?? combo;
  final a = ctrlKeyActivator(combo);
  return [if (a.control) 'Ctrl', if (a.alt) 'Alt', if (a.shift) 'Shift', k.keyName ?? spelledKeyNames[k.key] ?? plainKeyName(k.key)];
}

/// A shell Settings › Terminal offers: what runs, and what the menu says.
typedef ShellChoice = ({String value, String label});

/// Terminal pane commands with a key of their own ([HostOs.paneShortcut]).
enum PaneShortcut { newTab, closePane, splitRight, splitDown }

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
