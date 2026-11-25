import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/platform/os/host_os.dart';
import 'package:kumo_ui/platform/os/key_combo.dart';
import 'package:kumo_ui/platform/os/linux.dart';
import 'package:kumo_ui/platform/os/macos.dart';
import 'package:kumo_ui/platform/os/windows.dart';

/// What an activator needs pressed, comparable by value.
(LogicalKeyboardKey, bool, bool, bool, bool) _keys(SingleActivator a) => (a.trigger, a.control, a.shift, a.alt, a.meta);

void main() {
  tearDown(() => debugHostOs = null);

  group('macOS keeps its glyphs', () {
    setUp(() => debugHostOs = MacOs(const {}));

    test('labels', () {
      expect(AppKeys.view(0).label, '⌘1');
      expect(AppKeys.views.label, '⌘1…5');
      expect(AppKeys.workspace(3).label, '⌃⌘3');
      expect(AppKeys.settings.label, '⌘,');
      expect(AppKeys.toggleSidebar.label, '⌥⌘S');
      expect(AppKeys.toggleSidePanel.label, '⌥⌘B');
      expect(AppKeys.cycleTheme.label, '⇧⌘L');
      expect(AppKeys.newWorktree.label, '⇧⌘N');
      expect(AppKeys.search.label, '⌘K');
      expect(AppKeys.quickOpen.label, '⌘P');
      expect(AppKeys.save.label, '⌘S');
      expect(AppKeys.closeFile.label, '⌘W');
      expect(AppKeys.replace.label, '⌥⌘F');
      expect(AppKeys.findPrevious.label, '⇧⌘G');
      expect(AppKeys.togglePreview.label, '⇧⌘V');
      expect(AppKeys.submit.label, '⌘↩');
      expect(AppKeys.commitAndPush.label, '⇧⌘↩');
      expect(AppKeys.deleteNamespace.label, '⌘⌫');
      expect(AppKeys.askAgent.label, '⌘L');
      expect(AppKeys.terminalCopy.label, '⌘C');
      expect(AppKeys.terminalHistory.label, '⌘Y');
      expect(AppKeys.previousCommand.label, '⌘↑');
      expect(AppKeys.backToPrompt.label, '⌘End');
      expect(AppKeys.nextWord.label, '⌥→');
      expect(AppKeys.runFromHistory.label, '⌘↵');
    });

    test('caps, one per key', () {
      expect(AppKeys.workspaces.caps, ['⌃', '⌘', '1…9']);
      expect(AppKeys.newWorktree.caps, ['⇧', '⌘', 'N']);
    });

    test('bindings use ⌘', () {
      expect(_keys(AppKeys.quickOpen.activator), _keys(const SingleActivator(LogicalKeyboardKey.keyP, meta: true)));
      expect(_keys(AppKeys.workspace(1).activator), _keys(const SingleActivator(LogicalKeyboardKey.digit1, meta: true, control: true)));
      expect(_keys(AppKeys.replace.activator), _keys(const SingleActivator(LogicalKeyboardKey.keyF, meta: true, alt: true)));
      expect(_keys(AppKeys.terminalPaste.activator), _keys(const SingleActivator(LogicalKeyboardKey.keyV, meta: true)));
    });

    test('app-wide keys answer ⌘ and Ctrl, ⌘ first', () {
      expect([for (final a in AppKeys.view(0).activators) _keys(a)], [
        _keys(const SingleActivator(LogicalKeyboardKey.digit1, meta: true)),
        _keys(const SingleActivator(LogicalKeyboardKey.digit1, control: true)),
      ]);
      expect([for (final a in AppKeys.workspace(2).activators) _keys(a)], [
        _keys(const SingleActivator(LogicalKeyboardKey.digit2, meta: true, control: true)),
        _keys(const SingleActivator(LogicalKeyboardKey.digit2, control: true, alt: true)),
      ]);
      expect([for (final a in AppKeys.toggleSidebar.activators) _keys(a)], [
        _keys(const SingleActivator(LogicalKeyboardKey.keyS, meta: true, alt: true)),
        _keys(const SingleActivator(LogicalKeyboardKey.keyS, control: true, alt: true)),
      ]);
    });

    test('the label off macOS, for copy that names both', () {
      expect(AppKeys.terminalHistory.labelOffMac, 'Ctrl+Shift+Y');
    });

    testWidgets('a key event matches the combo exactly', (tester) async {
      const y = KeyDownEvent(physicalKey: PhysicalKeyboardKey.keyY, logicalKey: LogicalKeyboardKey.keyY, timeStamp: Duration.zero);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      expect(AppKeys.terminalHistory.accepts(y), isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      expect(AppKeys.terminalHistory.accepts(y), isFalse);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      expect(AppKeys.terminalHistory.accepts(y), isFalse);
    });
  });

  for (final (name, os) in [('Windows', WindowsOs(const {}, (_) => false)), ('Linux', LinuxOs(const {}))]) {
    group('$name spells keys out', () {
      setUp(() => debugHostOs = os);

      test('global, editor and terminal labels', () {
        expect(AppKeys.view(0).label, 'Ctrl+1');
        expect(AppKeys.views.label, 'Ctrl+1…5');
        expect(AppKeys.workspace(3).label, 'Ctrl+Alt+3');
        expect(AppKeys.settings.label, 'Ctrl+,');
        expect(AppKeys.toggleSidebar.label, 'Ctrl+Alt+S');
        expect(AppKeys.cycleTheme.label, 'Ctrl+Shift+L');
        expect(AppKeys.search.label, 'Ctrl+K');
        expect(AppKeys.quickOpen.label, 'Ctrl+P');
        expect(AppKeys.save.label, 'Ctrl+S');
        expect(AppKeys.closeFile.label, 'Ctrl+W');
        expect(AppKeys.replace.label, 'Ctrl+H');
        expect(AppKeys.findPrevious.label, 'Ctrl+Shift+G');
        expect(AppKeys.submit.label, 'Ctrl+Enter');
        expect(AppKeys.commitAndPush.label, 'Ctrl+Shift+Enter');
        expect(AppKeys.deleteNamespace.label, 'Ctrl+Backspace');
        expect(AppKeys.terminalCopy.label, 'Ctrl+Shift+C');
        expect(AppKeys.terminalHistory.label, 'Ctrl+Shift+Y');
        expect(AppKeys.previousCommand.label, 'Ctrl+Shift+↑');
        expect(AppKeys.backToPrompt.label, 'Shift+End');
        expect(AppKeys.nextWord.label, 'Alt+→');
        expect(AppKeys.runFromHistory.label, 'Ctrl+↵');
        // Windows splits with Ctrl+D / Ctrl+Shift+D; Linux leaves Ctrl+D to the shell.
        expect(os.paneShortcutLabel(PaneShortcut.splitDown), name == 'Windows' ? 'Ctrl+Shift+D' : 'Ctrl+Shift+E');
      });

      test('caps, one per key', () {
        expect(AppKeys.workspaces.caps, ['Ctrl', 'Alt', '1…9']);
        expect(AppKeys.newWorktree.caps, ['Ctrl', 'Shift', 'N']);
      });

      test('bindings use Ctrl, Ctrl+Shift in the terminal', () {
        expect(_keys(AppKeys.quickOpen.activator), _keys(const SingleActivator(LogicalKeyboardKey.keyP, control: true)));
        expect(_keys(AppKeys.workspace(1).activator), _keys(const SingleActivator(LogicalKeyboardKey.digit1, control: true, alt: true)));
        expect(_keys(AppKeys.replace.activator), _keys(const SingleActivator(LogicalKeyboardKey.keyH, control: true)));
        expect(_keys(AppKeys.deleteNamespace.activator), _keys(const SingleActivator(LogicalKeyboardKey.backspace, control: true)));
        expect(_keys(AppKeys.terminalPaste.activator), _keys(const SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true)));
        expect(_keys(os.paneShortcut(PaneShortcut.newTab)), _keys(const SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true)));
      });

      test('app-wide keys answer Ctrl and ⌘, Ctrl first', () {
        expect([for (final a in AppKeys.settings.activators) _keys(a)], [
          _keys(const SingleActivator(LogicalKeyboardKey.comma, control: true)),
          _keys(const SingleActivator(LogicalKeyboardKey.comma, meta: true)),
        ]);
        expect(AppKeys.terminalHistory.labelOffMac, AppKeys.terminalHistory.label);
      });

      testWidgets('a key event matches the combo exactly', (tester) async {
        const y = KeyDownEvent(physicalKey: PhysicalKeyboardKey.keyY, logicalKey: LogicalKeyboardKey.keyY, timeStamp: Duration.zero);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        expect(AppKeys.terminalHistory.accepts(y), isFalse, reason: 'Ctrl+Y is the shell’s yank');
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        expect(AppKeys.terminalHistory.accepts(y), isTrue);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      });
    });
  }
}
