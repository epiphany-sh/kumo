import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/platform/os/host_os.dart';
import 'package:kumo_ui/platform/os/key_combo.dart';
import 'package:kumo_ui/platform/os/linux.dart';
import 'package:kumo_ui/platform/os/macos.dart';
import 'package:kumo_ui/platform/os/windows.dart';

/// Each OS's keyboard: ⌘ on macOS, Ctrl elsewhere. Tests that press the
/// app's keys run once per OS, whatever OS runs the tests.
List<(String, HostOs Function())> get keyboardOses => [
      ('macOS', () => MacOs(const {})),
      ('Windows', () => WindowsOs(const {}, (_) => false)),
      ('Linux', () => LinuxOs(const {})),
    ];

/// Runs the rest of the test as [os], and the real OS again after it.
void useHostOs(HostOs os) {
  debugHostOs = os;
  addTearDown(() => debugHostOs = null);
}

/// Presses [combo] as [hostOs] binds it: its modifiers down, the key, then
/// the modifiers up again.
Future<void> pressCombo(WidgetTester tester, KeyCombo combo) async {
  final a = hostOs.keyActivator(combo);
  final modifiers = [
    if (a.control) LogicalKeyboardKey.controlLeft,
    if (a.meta) LogicalKeyboardKey.metaLeft,
    if (a.alt) LogicalKeyboardKey.altLeft,
    if (a.shift) LogicalKeyboardKey.shiftLeft,
  ];
  for (final key in modifiers) {
    await tester.sendKeyDownEvent(key);
  }
  await tester.sendKeyEvent(a.trigger);
  for (final key in modifiers.reversed) {
    await tester.sendKeyUpEvent(key);
  }
}
