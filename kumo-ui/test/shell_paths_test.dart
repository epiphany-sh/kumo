import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/platform/os/linux.dart';
import 'package:kumo_ui/platform/os/macos.dart';
import 'package:kumo_ui/platform/os/windows.dart';
import 'package:kumo_ui/terminal/terminal_keys.dart';

void main() {
  const posix = ['/tmp/a b/Screenshot (1).png', r"/x/it's $HOME"];

  test('macOS and Linux escape with backslashes, whatever the shell', () {
    for (final os in [MacOs(const {}), LinuxOs(const {})]) {
      for (final shell in [null, '/bin/zsh', '/bin/bash', 'fish']) {
        expect(os.shellPaths(posix, shell: shell), terminalPaths(posix), reason: '${os.runtimeType} $shell');
      }
    }
  });

  group('Windows', () {
    final os = WindowsOs(const {});

    test('PowerShell: single quotes, a quote in the path doubled', () {
      for (final shell in [r'C:\Program Files\PowerShell\7\pwsh.exe', r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe', 'pwsh.exe', 'POWERSHELL', 'pwsh']) {
        expect(os.shellPaths([r'C:\Users\me\AppData\Local\Temp\kumo-paste\image-1.png'], shell: shell), r'C:\Users\me\AppData\Local\Temp\kumo-paste\image-1.png', reason: '$shell: nothing to quote');
        expect(os.shellPaths([r'C:\My Files\it' "'" r's.png', r'D:\a&b\$x (1).txt'], shell: shell), r"'C:\My Files\it''s.png' 'D:\a&b\$x (1).txt'", reason: shell);
      }
    });

    test('PowerShell also reads typographic single quotes as quotes', () {
      expect(os.shellPaths(['C:\\Bob\u2019s\\a.png'], shell: 'pwsh.exe'), "'C:\\Bob\u2019\u2019s\\a.png'");
    });

    test('cmd.exe: double quotes around a path that needs them', () {
      for (final shell in [r'C:\Windows\system32\cmd.exe', 'cmd.exe', 'CMD']) {
        expect(os.shellPaths([r'C:\Users\me\a.png'], shell: shell), r'C:\Users\me\a.png', reason: shell);
        expect(os.shellPaths([r'C:\My Files\it' "'" r's.png', r'D:\a&b\x^(1).txt'], shell: shell), r'''"C:\My Files\it's.png" "D:\a&b\x^(1).txt"''', reason: shell);
      }
    });

    test('any other program (an agent, or unknown) gets double quotes as Windows Terminal drops them', () {
      for (final shell in [null, 'claude', r'C:\Users\me\.local\bin\claude.exe']) {
        expect(os.shellPaths([r'C:\My Files\a.png', r'C:\b.png'], shell: shell), r'"C:\My Files\a.png" C:\b.png', reason: shell);
      }
    });

    // A forged drop (another process posting WM_DROPFILES) can carry any
    // UTF-16 "path"; no Windows path holds `"` or a control character.
    test('a path no file can have (a quote, a control character) is left out, whatever the shell', () {
      const forged = [
        r'x" & calc & "',
        'x\ncalc\n',
        'x\rcalc',
        'C:\\a\x1b[201~calc',
        'C:\\a\u009bcalc',
        'C:\\a\x7fcalc',
        'C:\\a\tb',
      ];
      for (final shell in [null, 'cmd.exe', 'claude', 'pwsh.exe', 'powershell.exe']) {
        for (final p in forged) {
          expect(os.shellPaths([p], shell: shell), isEmpty, reason: '$shell ${p.codeUnits}');
        }
        final kept = os.shellPaths([forged[0], r'C:\b.png', forged[1]], shell: shell);
        expect(kept, r'C:\b.png', reason: '$shell: the real paths stay');
      }
    });
  });
}
