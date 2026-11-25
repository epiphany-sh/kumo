import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/platform/os/host_os.dart';
import 'package:kumo_ui/platform/os/linux.dart';
import 'package:kumo_ui/platform/os/macos.dart';
import 'package:kumo_ui/platform/os/windows.dart';
import 'package:kumo_ui/terminal/terminal_keys.dart';

const _ctrl = (LogicalKeyboardKey.controlLeft, PhysicalKeyboardKey.controlLeft);
const _shift = (LogicalKeyboardKey.shiftLeft, PhysicalKeyboardKey.shiftLeft);
const _meta = (LogicalKeyboardKey.metaLeft, PhysicalKeyboardKey.metaLeft);

const _c = (LogicalKeyboardKey.keyC, PhysicalKeyboardKey.keyC);
const _v = (LogicalKeyboardKey.keyV, PhysicalKeyboardKey.keyV);

/// [key] pressed while [modifiers] are held, on a keyboard of its own (not
/// the app's), and the keyboard's state.
(KeyEvent, HardwareKeyboard) _press(List<(LogicalKeyboardKey, PhysicalKeyboardKey)> modifiers, (LogicalKeyboardKey, PhysicalKeyboardKey) key) {
  final keys = HardwareKeyboard();
  for (final (logical, physical) in modifiers) {
    keys.handleKeyEvent(KeyDownEvent(physicalKey: physical, logicalKey: logical, timeStamp: Duration.zero));
  }
  final event = KeyDownEvent(physicalKey: key.$2, logicalKey: key.$1, timeStamp: Duration.zero);
  keys.handleKeyEvent(event);
  return (event, keys);
}

TerminalClipboardKey? _clipboard(HostOs os, List<(LogicalKeyboardKey, PhysicalKeyboardKey)> modifiers, (LogicalKeyboardKey, PhysicalKeyboardKey) key, {bool selection = false, bool canPaste = true}) {
  final (event, keys) = _press(modifiers, key);
  return terminalClipboardKey(event, os: os, hasSelection: selection, canPaste: canPaste, keys: keys);
}

void main() {
  group('clipboard keys', () {
    final windows = WindowsOs(const {}, (_) => false);
    final linux = LinuxOs(const {});
    final mac = MacOs(const {});

    test('on Windows Ctrl+C copies a selection and clears it; without one it is ^C', () {
      expect(_clipboard(windows, [_ctrl], _c, selection: true), TerminalClipboardKey.copyAndClear);
      expect(_clipboard(windows, [_ctrl], _c), isNull, reason: 'no selection: the shell gets its interrupt');
    });

    test('on Windows Ctrl+V pastes', () {
      expect(_clipboard(windows, [_ctrl], _v), TerminalClipboardKey.paste);
      expect(_clipboard(windows, [_ctrl], _v, canPaste: false), isNull, reason: 'a pane nobody types into');
    });

    test('on Windows Ctrl+Shift+C / V still copy and paste', () {
      expect(_clipboard(windows, [_ctrl, _shift], _c, selection: true), TerminalClipboardKey.copy);
      expect(_clipboard(windows, [_ctrl, _shift], _c), isNull);
      expect(_clipboard(windows, [_ctrl, _shift], _v), TerminalClipboardKey.paste);
    });

    test('on Linux Ctrl+C / V stay the shell’s; Ctrl+Shift+C / V copy and paste', () {
      expect(_clipboard(linux, [_ctrl], _c, selection: true), isNull);
      expect(_clipboard(linux, [_ctrl], _v), isNull);
      expect(_clipboard(linux, [_ctrl, _shift], _c, selection: true), TerminalClipboardKey.copy);
      expect(_clipboard(linux, [_ctrl, _shift], _v), TerminalClipboardKey.paste);
    });

    test('on macOS ⌘C / ⌘V; Ctrl+C / V stay the shell’s', () {
      expect(_clipboard(mac, [_meta], _c, selection: true), TerminalClipboardKey.copy);
      expect(_clipboard(mac, [_meta], _v), TerminalClipboardKey.paste);
      expect(_clipboard(mac, [_ctrl], _c, selection: true), isNull);
      expect(_clipboard(mac, [_ctrl], _v), isNull);
    });

    test('a key going up does nothing', () {
      final keys = HardwareKeyboard();
      keys.handleKeyEvent(const KeyDownEvent(physicalKey: PhysicalKeyboardKey.controlLeft, logicalKey: LogicalKeyboardKey.controlLeft, timeStamp: Duration.zero));
      const up = KeyUpEvent(physicalKey: PhysicalKeyboardKey.keyV, logicalKey: LogicalKeyboardKey.keyV, timeStamp: Duration.zero);
      expect(terminalClipboardKey(up, os: windows, hasSelection: true, canPaste: true, keys: keys), isNull);
    });
  });

  group('composed text (dead keys, input methods)', () {
    test('nothing goes to the shell while a character is being composed', () {
      expect(terminalComposedText(const TextEditingValue(text: '˜', composing: TextRange(start: 0, end: 1))), isNull);
    });

    test('the composed character goes in once committed', () {
      expect(terminalComposedText(const TextEditingValue(text: 'ñ', selection: TextSelection.collapsed(offset: 1))), 'ñ');
      expect(terminalComposedText(const TextEditingValue(text: 'é')), 'é');
    });

    test('an empty value (a cancelled composition) sends nothing', () {
      expect(terminalComposedText(TextEditingValue.empty), isNull);
    });

    test('editing commands the input method sends are keys', () {
      expect(terminalSelectorInput('insertNewline:'), [0x0d]);
      expect(terminalSelectorInput('insertTab:'), [0x09]);
      expect(terminalSelectorInput('deleteBackward:'), [0x7f]);
      expect(terminalSelectorInput('cancelOperation:'), isNull, reason: 'Esc during a composition only cancels it');
      expect(terminalSelectorInput('moveWordLeft:'), isNull);
    });
  });
}
