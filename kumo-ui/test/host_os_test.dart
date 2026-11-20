import 'dart:io' show ProcessException, ProcessStartMode;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/preferences.dart';
import 'package:kumo_ui/engine/daemon_endpoint.dart';
import 'package:kumo_ui/platform/os/host_os.dart';
import 'package:kumo_ui/platform/os/linux.dart';
import 'package:kumo_ui/platform/os/macos.dart';
import 'package:kumo_ui/platform/os/windows.dart';
import 'package:kumo_ui/platform/updates.dart';
import 'package:kumo_ui/platform/updates_windows.dart';

/// The url opener as (program, args) with the args as a plain list, so
/// `expect` compares them by value.
(String, String) _open(HostOs os) {
  final (program, args) = os.openUrlCommand('https://example.com');
  return (program, args.join(' '));
}

/// The file manager's command, the same way.
(String, String) _reveal(HostOs os, String path) {
  final (program, args) = os.revealCommand(path);
  return (program, args.join(' '));
}

/// An activator's key and modifiers (it has no `==`).
(LogicalKeyboardKey, bool, bool, bool, bool) _keys(SingleActivator a) => (a.trigger, a.control, a.meta, a.shift, a.alt);

/// The shells Settings offers, without their labels.
List<String> _values(HostOs os) => [for (final c in os.shellChoices) c.value];

void main() {
  group('macOS', () {
    final os = MacOs(const {'HOME': '/Users/user-1', 'USER': 'user-1'}, (_) => true);

    test('files live under ~/Library/Application Support', () {
      expect(os.home, '/Users/user-1');
      expect(os.preferencesPath, '/Users/user-1/Library/Application Support/Kumo/ui.json');
      expect(os.daemonDiscoveryPath, '/Users/user-1/Library/Application Support/kumo/daemon.json');
      expect(MacOs(const {}).preferencesPath, isNull);
    });

    test('daemon, login and url opener', () {
      expect(os.daemonExecutable, 'kumod');
      expect(os.loginName, 'user-1');
      expect(MacOs(const {}).loginName, '');
      expect(_open(os), ('open', 'https://example.com'));
    });

    test('a login shell: \$SHELL, else zsh', () {
      expect(os.shell, '/bin/zsh');
      expect(MacOs(const {'SHELL': '/bin/bash'}).shell, '/bin/bash');
      expect(os.shellArgsFor(os.shell), ['-l']);
      expect(_values(os), ['/bin/zsh', '/bin/bash', '/opt/homebrew/bin/fish']);
      expect([for (final c in os.shellChoices) c.label], _values(os), reason: 'a path is its own label');
      expect(os.shellDescription, 'Login shell for new tabs (⌘T) and splits.');
    });

    test('Settings preselects \$SHELL, what a new terminal ran before the setting was read', () {
      final nu = MacOs(const {'SHELL': '/usr/local/bin/nu'}, (_) => true);
      expect(nu.shell, '/usr/local/bin/nu');
      expect(_values(nu), contains('/usr/local/bin/nu'), reason: 'the dropdown can show it');
      expect(nu.resolveShell(null), '/usr/local/bin/nu');
      expect(nu.resolveShell('/bin/bash'), '/bin/bash');
      expect(nu.resolveShell('/gone/sh'), '/usr/local/bin/nu', reason: 'one no longer offered falls back');
    });

    test('only shells that are installed, and \$SHELL always', () {
      final checked = <String>[];
      bool exists(String path) {
        checked.add(path);
        return path == '/bin/zsh' || path == '/usr/bin/xonsh';
      }

      final mac = MacOs(const {'SHELL': '/usr/local/bin/nu', 'PATH': '/usr/local/bin:/usr/bin'}, exists);
      expect(_values(mac), ['/bin/zsh', '/usr/local/bin/nu'], reason: 'no bash or fish here');
      expect(checked, isNot(contains('/usr/local/bin/nu')), reason: '\$SHELL is offered unchecked');
      expect(mac.resolveShell('/opt/homebrew/bin/fish'), '/usr/local/bin/nu', reason: 'a saved fish that isn’t installed keeps \$SHELL -l');
      expect(mac.resolveShell('/bin/zsh'), '/bin/zsh');
      expect(mac.programExists('xonsh'), isTrue, reason: 'a bare name is looked up on \$PATH');
      expect(mac.programExists('fish'), isFalse);
      expect(mac.programExists('/bin/zsh'), isTrue);
    });

    test('pane keys use ⌘', () {
      expect(_keys(os.paneShortcut(PaneShortcut.newTab)), _keys(const SingleActivator(LogicalKeyboardKey.keyT, meta: true)));
      expect(_keys(os.paneShortcut(PaneShortcut.closePane)), _keys(const SingleActivator(LogicalKeyboardKey.keyW, meta: true)));
      expect(_keys(os.paneShortcut(PaneShortcut.splitRight)), _keys(const SingleActivator(LogicalKeyboardKey.keyD, meta: true)));
      expect(_keys(os.paneShortcut(PaneShortcut.splitDown)), _keys(const SingleActivator(LogicalKeyboardKey.keyD, meta: true, shift: true)));
      expect(os.paneShortcutLabel(PaneShortcut.newTab), '⌘T');
      expect(os.paneShortcutLabel(PaneShortcut.closePane), '⌘W');
      expect(os.paneShortcutLabel(PaneShortcut.splitRight), '⌘D');
      expect(os.paneShortcutLabel(PaneShortcut.splitDown), '⇧⌘D');
    });

    test('Finder, and this Mac', () {
      expect(_reveal(os, '/Users/user-1/wt/x'), ('open', '-R /Users/user-1/wt/x'));
      expect(os.revealLabel, 'Reveal in Finder');
      expect(os.machineName, 'this Mac');
      expect(os.hasBear, isTrue);
    });

    test('native backdrop with the traffic lights inside the content', () {
      expect(os.supportsNativeBackdrop, isTrue);
      expect(os.windowButtonsInContent, isTrue);
    });
  });

  group('Windows', () {
    final os = WindowsOs(const {
      'USERPROFILE': r'C:\Users\user-1',
      'APPDATA': r'C:\Users\user-1\AppData\Roaming',
      'LOCALAPPDATA': r'C:\Users\user-1\AppData\Local',
      'USERNAME': 'user-1',
      'COMSPEC': r'C:\Windows\system32\cmd.exe',
    });

    test('files live under %APPDATA% and %LOCALAPPDATA%', () {
      expect(os.home, r'C:\Users\user-1');
      expect(os.preferencesPath, r'C:\Users\user-1\AppData\Roaming\Kumo\ui.json');
      expect(os.daemonDiscoveryPath, r'C:\Users\user-1\AppData\Local\kumo\daemon.json');
      expect(WindowsOs(const {'USERPROFILE': r'C:\Users\user-2'}).daemonDiscoveryPath, r'C:\Users\user-2\AppData\Local\kumo\daemon.json');
      expect(WindowsOs(const {}).preferencesPath, isNull);
    });

    test('daemon, login and url opener', () {
      expect(os.daemonExecutable, 'kumod.exe');
      expect(os.loginName, 'user-1');
      expect(_open(os), ('rundll32', 'url.dll,FileProtocolHandler https://example.com'));
    });

    test('shell: PowerShell 7, else Windows PowerShell, else %COMSPEC%', () {
      const env = {'COMSPEC': r'C:\Windows\system32\cmd.exe', 'SHELL': '/usr/bin/bash'};
      final both = WindowsOs(env, (exe) => true);
      expect(both.shell, 'pwsh.exe', reason: 'a Git Bash \$SHELL doesn’t win');
      expect([for (final c in both.shellChoices) (c.value, c.label)], [
        ('pwsh.exe', 'PowerShell 7'),
        ('powershell.exe', 'Windows PowerShell'),
        (r'C:\Windows\system32\cmd.exe', 'Command Prompt'),
      ]);
      final legacy = WindowsOs(env, (exe) => exe == 'powershell.exe');
      expect(legacy.shell, 'powershell.exe');
      expect(_values(legacy), ['powershell.exe', r'C:\Windows\system32\cmd.exe'], reason: 'PowerShell 7 only once installed');
      expect(WindowsOs(env, (exe) => false).shell, r'C:\Windows\system32\cmd.exe');
      expect(WindowsOs(const {}, (exe) => false).shell, 'cmd.exe');
      expect(_values(both), contains(both.shell));
    });

    test('shell: the one chosen while it’s offered, with -NoLogo for PowerShell', () {
      final legacy = WindowsOs(const {'COMSPEC': r'C:\Windows\system32\cmd.exe'}, (exe) => exe == 'powershell.exe');
      expect(legacy.resolveShell(null), 'powershell.exe');
      expect(legacy.resolveShell(r'C:\Windows\system32\cmd.exe'), r'C:\Windows\system32\cmd.exe');
      expect(legacy.resolveShell('pwsh.exe'), 'powershell.exe', reason: 'PowerShell 7 was uninstalled');
      expect(legacy.shellArgsFor('pwsh.exe'), ['-NoLogo']);
      expect(legacy.shellArgsFor(r'C:\Program Files\PowerShell\7\PWSH.EXE'), ['-NoLogo']);
      expect(legacy.shellArgsFor('powershell.exe'), ['-NoLogo']);
      expect(legacy.shellArgsFor(r'C:\Windows\system32\cmd.exe'), isEmpty);
      expect(legacy.shellDescription, 'Shell for new tabs (Ctrl+Shift+T) and splits.');
    });

    test('a shell saved by name before still picks the same one', () {
      final os = WindowsOs(
        const {'COMSPEC': r'C:\Windows\system32\cmd.exe', 'ProgramFiles': r'C:\Program Files'},
        (exe) => exe == 'powershell.exe',
        (path) => path == r'C:\Program Files\PowerShell\7\pwsh.exe',
      );
      expect(os.resolveShell('cmd.exe'), r'C:\Windows\system32\cmd.exe', reason: 'Command Prompt was saved as cmd.exe');
      expect(os.resolveShell('CMD.EXE'), r'C:\Windows\system32\cmd.exe');
      expect(os.resolveShell('pwsh.exe'), r'C:\Program Files\PowerShell\7\pwsh.exe');
      expect(os.resolveShell('PowerShell.exe'), 'powershell.exe');
      expect(os.resolveShell('bash.exe'), os.shell, reason: 'never offered');
    });

    test('PowerShell in its install folder first, then %PATH% without network shares', () {
      final checked = <String>[];
      bool Function(String) existsAt(Set<String> there) => (path) {
            checked.add(path);
            return there.contains(path);
          };
      const env = {
        'ProgramFiles': r'C:\Program Files',
        'SystemRoot': r'C:\Windows',
        'PATH': r'\\server\share\bin;C:\tools',
      };
      final installed = WindowsOs(env, null, existsAt({r'C:\Program Files\PowerShell\7\pwsh.exe', r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'}));
      expect(installed.shell, r'C:\Program Files\PowerShell\7\pwsh.exe');
      expect(_values(installed), [r'C:\Program Files\PowerShell\7\pwsh.exe', r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe', 'cmd.exe']);
      expect(checked, isNot(contains(startsWith(r'C:\tools'))), reason: 'the install folders answered');
      checked.clear();
      final onPath = WindowsOs(env, null, existsAt({r'C:\tools\pwsh.exe'}));
      expect(onPath.shell, 'pwsh.exe');
      expect(checked, isNot(contains(startsWith(r'\\'))), reason: 'a UNC entry can hang the UI');
      expect(checked, contains(r'C:\tools\pwsh.exe'));
    });

    test('looks for PowerShell on %PATH%', () {
      bool exists(String path) => path == r'C:\Program Files\PowerShell\7\pwsh.exe';
      expect(WindowsOs(const {'PATH': r'C:\a;C:\Program Files\PowerShell\7'}, null, exists).shell, 'pwsh.exe');
      expect(WindowsOs(const {'Path': r'C:\a;C:\Program Files\PowerShell\7\'}, null, exists).shell, 'pwsh.exe');
      expect(WindowsOs(const {'PATH': r'C:\a', 'COMSPEC': 'cmd'}, null, exists).shell, 'cmd');
    });

    test('pane keys use Ctrl+Shift, leaving Ctrl+D / T / W to the shell', () {
      expect(_keys(os.paneShortcut(PaneShortcut.newTab)), _keys(const SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true)));
      expect(_keys(os.paneShortcut(PaneShortcut.closePane)), _keys(const SingleActivator(LogicalKeyboardKey.keyW, control: true, shift: true)));
      expect(_keys(os.paneShortcut(PaneShortcut.splitRight)), _keys(const SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true)));
      expect(_keys(os.paneShortcut(PaneShortcut.splitDown)), _keys(const SingleActivator(LogicalKeyboardKey.keyE, control: true, shift: true)));
      expect(os.paneShortcutLabel(PaneShortcut.newTab), 'Ctrl+Shift+T');
      expect(os.paneShortcutLabel(PaneShortcut.splitRight), 'Ctrl+Shift+D');
      expect(os.paneShortcutLabel(PaneShortcut.splitDown), 'Ctrl+Shift+E');
    });

    test('Explorer, and this PC', () {
      expect(_reveal(os, r'C:\Users\user-1\wt\x'), ('explorer.exe', r'/select,C:\Users\user-1\wt\x'));
      expect(_reveal(os, 'C:/Users/user-1/wt/x'), ('explorer.exe', r'/select,C:\Users\user-1\wt\x'), reason: 'git prints worktree paths with /');
      expect(os.revealLabel, 'Show in Explorer');
      expect(os.machineName, 'this PC');
      expect(os.hasBear, isFalse);
    });

    test('Mica backdrop, native window buttons outside the content', () {
      expect(os.supportsNativeBackdrop, isTrue);
      expect(os.windowButtonsInContent, isFalse);
    });

    test('a new window runs the same executable with KUMO_WORKSPACE', () {
      final (exe, args, env) = os.workspaceWindowCommand(r'C:\Kumo\kumo_ui.exe', 'workspace-1');
      expect(exe, r'C:\Kumo\kumo_ui.exe');
      expect(args, isEmpty);
      expect(env, {'KUMO_WORKSPACE': 'workspace-1'});
    });

    test('relaunch: a hidden PowerShell waits for this Kumo to exit, then starts it again', () async {
      const powershell = r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe';
      final os = WindowsOs(const {'SystemRoot': r'C:\Windows'}, null, (path) => path == powershell);
      // A quote and spaces: the path reaches PowerShell as data, not code.
      const exe = r"C:\Users\O'Brien Q\AppData\Local\Programs\Kumo\Kumo.exe";
      final started = <(String, List<String>, Map<String, String>?, ProcessStartMode)>[];
      final exits = <int>[];
      final relaunched = await os.relaunchAfterExit(
        pid: 4242,
        exe: exe,
        start: (program, args, {environment, mode = ProcessStartMode.normal}) async => started.add((program, args, environment, mode)),
        exit: exits.add,
      );
      expect(relaunched, isTrue);
      expect(started, hasLength(1));
      final (program, args, environment, mode) = started.single;
      expect(program, powershell);
      expect(args.sublist(0, args.length - 1), ['-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-Command']);
      expect(args.last, contains(r'Wait-Process -Id $env:KUMO_RELAUNCH_PID'));
      expect(args.last, contains(r'Start-Process -FilePath $env:KUMO_RELAUNCH_EXE'));
      expect(args.last, isNot(contains('Brien')), reason: 'the path goes in the environment');
      expect(environment, {'KUMO_RELAUNCH_PID': '4242', 'KUMO_RELAUNCH_EXE': exe});
      expect(mode, ProcessStartMode.detached);
      expect(exits, [0], reason: 'Kumo quits once the helper is waiting for it');
    });

    test('relaunch: PowerShell from %PATH% when its folder isn’t known', () async {
      final os = WindowsOs(const {}, (exe) => false);
      final programs = <String>[];
      await os.relaunchAfterExit(pid: 1, exe: r'C:\Kumo\Kumo.exe', start: (program, args, {environment, mode = ProcessStartMode.normal}) async => programs.add(program), exit: (_) {});
      expect(programs, ['powershell.exe']);
    });

    test('relaunch: Kumo stays open when the helper can’t start', () async {
      final os = WindowsOs(const {}, (exe) => false);
      final exits = <int>[];
      final relaunched = await os.relaunchAfterExit(
        pid: 1,
        exe: r'C:\Kumo\Kumo.exe',
        start: (program, args, {environment, mode = ProcessStartMode.normal}) async => throw const ProcessException('powershell.exe', [], 'not found'),
        exit: exits.add,
      );
      expect(relaunched, isFalse);
      expect(exits, isEmpty);
    });
  });

  group('Linux', () {
    final os = LinuxOs(const {'HOME': '/home/user-1', 'USER': 'user-1'});

    test('files follow XDG', () {
      expect(os.home, '/home/user-1');
      expect(os.preferencesPath, '/home/user-1/.config/kumo/ui.json');
      expect(os.daemonDiscoveryPath, '/home/user-1/.local/share/kumo/daemon.json');
      expect(LinuxOs(const {'HOME': '/home/user-1', 'XDG_DATA_HOME': '/data'}).daemonDiscoveryPath, '/data/kumo/daemon.json');
    });

    test('daemon, login and url opener', () {
      expect(os.daemonExecutable, 'kumod');
      expect(os.loginName, 'user-1');
      expect(_open(os), ('xdg-open', 'https://example.com'));
    });

    test('a login shell', () {
      expect(os.shell, '/bin/zsh');
      expect(os.shellArgsFor(os.shell), ['-l']);
      expect(_values(os), contains(os.shell));
      expect(_values(LinuxOs(const {'SHELL': '/usr/bin/nu'})), contains('/usr/bin/nu'));
      expect(os.shellDescription, 'Login shell for new tabs (Ctrl+Shift+T) and splits.');
    });

    test('pane keys use Ctrl+Shift', () {
      expect(_keys(os.paneShortcut(PaneShortcut.newTab)), _keys(const SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true)));
      expect(os.paneShortcutLabel(PaneShortcut.closePane), 'Ctrl+Shift+W');
    });

    test('the file manager, and this computer', () {
      expect(_reveal(os, '/home/user-1/wt/x'), ('xdg-open', '/home/user-1/wt'));
      expect(os.revealLabel, 'Show in File Manager');
      expect(os.machineName, 'this computer');
      expect(os.hasBear, isFalse);
    });

    test('no native backdrop or new windows', () async {
      expect(os.supportsNativeBackdrop, isFalse);
      expect(os.windowButtonsInContent, isFalse);
      expect(await os.openWorkspaceWindow('workspace-1'), contains('macOS'));
    });
  });

  test('macOS (Sparkle) and Linux start no relaunch helper and don’t quit', () async {
    for (final os in [MacOs(const {}), LinuxOs(const {})]) {
      final started = <String>[];
      final exits = <int>[];
      final relaunched = await os.relaunchAfterExit(pid: 1, exe: '/k', start: (program, args, {environment, mode = ProcessStartMode.normal}) async => started.add(program), exit: exits.add);
      expect(relaunched, isFalse, reason: '$os');
      expect(started, isEmpty);
      expect(exits, isEmpty);
    }
  });

  group('callers read the chosen OS', () {
    tearDown(() => debugHostOs = null);

    test('ui.json and daemon.json', () {
      debugHostOs = WindowsOs(const {'APPDATA': r'C:\A', 'LOCALAPPDATA': r'C:\L'});
      expect(Preferences.defaultFile()?.path, r'C:\A\Kumo\ui.json');
      expect(DaemonDiscovery.defaultPath(), r'C:\L\kumo\daemon.json');
      debugHostOs = MacOs(const {});
      expect(Preferences.defaultFile(), isNull);
    });
  });

  group('updates', () {
    test('Sparkle on macOS, Kumo’s own on Windows, none on Linux', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final mac = MacOs(const {}).updates();
      final windows = WindowsOs(const {}).updates();
      final linux = LinuxOs(const {}).updates();
      addTearDown(() {
        mac.dispose();
        windows.dispose();
        linux.dispose();
      });
      expect(mac, isA<SparkleUpdates>());
      expect(mac.canCheck, isFalse, reason: 'Sparkle checks by itself');
      expect(windows, isA<WindowsUpdates>());
      expect(windows.canCheck, isFalse, reason: 'a debug build never updates itself');
      expect(linux.runtimeType, AppUpdates);
      expect(linux.canCheck, isFalse);
    });

    test('Windows reads "Download updates automatically" each time it would check', () {
      var auto = true;
      final updates = WindowsOs(const {}).updates(autoUpdate: () => auto) as WindowsUpdates;
      addTearDown(updates.dispose);
      expect(updates.autoUpdate(), isTrue);
      auto = false;
      expect(updates.autoUpdate(), isFalse);
    });
  });
}
