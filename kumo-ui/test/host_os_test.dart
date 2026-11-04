import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/preferences.dart';
import 'package:kumo_ui/engine/daemon_endpoint.dart';
import 'package:kumo_ui/platform/os/host_os.dart';
import 'package:kumo_ui/platform/os/linux.dart';
import 'package:kumo_ui/platform/os/macos.dart';
import 'package:kumo_ui/platform/os/windows.dart';

/// The url opener as (program, args) with the args as a plain list, so
/// `expect` compares them by value.
(String, String) _open(HostOs os) {
  final (program, args) = os.openUrlCommand('https://example.com');
  return (program, args.join(' '));
}

void main() {
  group('macOS', () {
    final os = MacOs(const {'HOME': '/Users/user-1', 'USER': 'user-1'});

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
      expect(os.shellArgs, ['-l']);
      expect(os.shellChoices, ['/bin/zsh', '/bin/bash', '/opt/homebrew/bin/fish']);
      expect(os.defaultShellChoice, '/bin/zsh');
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

    test('shell: %COMSPEC%, else cmd.exe, with no login flag', () {
      expect(os.shell, r'C:\Windows\system32\cmd.exe');
      expect(WindowsOs(const {}).shell, 'cmd.exe');
      expect(os.shellArgs, isEmpty);
      expect(os.shellChoices, ['cmd.exe', 'powershell.exe', 'pwsh.exe']);
      expect(os.shellChoices, contains(os.defaultShellChoice));
    });

    test('Mica backdrop, native window buttons outside the content', () async {
      expect(os.supportsNativeBackdrop, isTrue);
      expect(os.windowButtonsInContent, isFalse);
      expect(await os.openWorkspaceWindow('workspace-1'), contains('macOS'));
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
      expect(os.shellArgs, ['-l']);
      expect(os.shellChoices, contains(os.defaultShellChoice));
    });

    test('no native backdrop or new windows', () async {
      expect(os.supportsNativeBackdrop, isFalse);
      expect(os.windowButtonsInContent, isFalse);
      expect(await os.openWorkspaceWindow('workspace-1'), contains('macOS'));
    });
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
}
