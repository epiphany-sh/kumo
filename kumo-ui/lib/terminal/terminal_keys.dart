import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bytes a key press sends to the PTY (xterm conventions), or null when the
/// terminal does not handle it, so it bubbles up to app shortcuts (⌘…).
List<int>? terminalInputFor(KeyEvent event, {bool applicationCursorKeys = false}) {
  if (event is KeyUpEvent) return null;
  final keys = HardwareKeyboard.instance;
  final key = event.logicalKey;
  if (keys.isMetaPressed) return _macLineEdit(key, keys);

  final arrow = _arrows[key];
  if (arrow != null) {
    // ⌥← / ⌥→ jump words, like macOS Terminal.
    if (keys.isAltPressed && !keys.isControlPressed && !keys.isShiftPressed && (arrow == 'C' || arrow == 'D')) {
      return [0x1b, arrow == 'C' ? 0x66 : 0x62];
    }
    // With modifiers, xterm's `ESC [1;<1 + ⇧1 + ⌥2 + ⌃4><arrow>`: ⌥↓ is
    // what Claude Code scrolls its diff panel with.
    final mods = (keys.isShiftPressed ? 1 : 0) + (keys.isAltPressed ? 2 : 0) + (keys.isControlPressed ? 4 : 0);
    if (mods > 0) return utf8.encode('\x1b[1;${1 + mods}$arrow');
    return utf8.encode(applicationCursorKeys ? '\x1bO$arrow' : '\x1b[$arrow');
  }
  if (key == LogicalKeyboardKey.tab && keys.isShiftPressed) return utf8.encode('\x1b[Z');
  // ⇧↩ / ⌥↩ start a new line instead of submitting: ESC CR is what Claude
  // Code, Codex and zsh (self-insert-unmeta) read as a line break.
  if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) && (keys.isShiftPressed || keys.isAltPressed) && !keys.isControlPressed) {
    return [0x1b, 0x0d];
  }
  // ⌥⌫ deletes the word before the cursor and ⌥⌦ the one after (readline's
  // backward-kill-word and kill-word); Ctrl+⌫ is ^W, as on Linux and Windows.
  if (key == LogicalKeyboardKey.backspace) {
    if (keys.isAltPressed) return [0x1b, 0x7f];
    if (keys.isControlPressed) return [0x17];
  }
  if (key == LogicalKeyboardKey.delete && keys.isAltPressed) return [0x1b, 0x64];
  final special = _special[key];
  if (special != null) return utf8.encode(special);

  if (keys.isControlPressed) {
    final label = key.keyLabel.toLowerCase();
    if (label.length == 1) {
      final c = label.codeUnitAt(0);
      if (c >= 0x61 && c <= 0x7a) return [c - 0x60]; // ^A…^Z
      if (label == '[') return [0x1b];
      if (label == r'\') return [0x1c];
      if (label == ']') return [0x1d];
    }
    if (key == LogicalKeyboardKey.space) return [0x00];
  }

  final char = event.character;
  if (char == null || char.isEmpty) return null;
  return utf8.encode(char);
}

/// ⌘ on macOS edits the line like a text field: ⌘← / ⌘→ to its start and
/// end (^A, ^E) and ⌘⌫ deletes back to the start (^U). Other ⌘ keys are
/// the app's.
List<int>? _macLineEdit(LogicalKeyboardKey key, HardwareKeyboard keys) {
  if (defaultTargetPlatform != TargetPlatform.macOS || keys.isShiftPressed || keys.isAltPressed || keys.isControlPressed) return null;
  if (key == LogicalKeyboardKey.arrowLeft) return [0x01];
  if (key == LogicalKeyboardKey.arrowRight) return [0x05];
  if (key == LogicalKeyboardKey.backspace) return [0x15];
  return null;
}

/// Text from the clipboard, wrapped when the program asked for it.
List<int> terminalPaste(String text, {bool bracketed = false}) {
  final normalized = text.replaceAll('\r\n', '\r').replaceAll('\n', '\r');
  return utf8.encode(bracketed ? '\x1b[200~$normalized\x1b[201~' : normalized);
}

final _arrows = {
  LogicalKeyboardKey.arrowUp: 'A',
  LogicalKeyboardKey.arrowDown: 'B',
  LogicalKeyboardKey.arrowRight: 'C',
  LogicalKeyboardKey.arrowLeft: 'D',
};

final _special = {
  LogicalKeyboardKey.enter: '\r',
  LogicalKeyboardKey.numpadEnter: '\r',
  LogicalKeyboardKey.backspace: '\x7f',
  LogicalKeyboardKey.tab: '\t',
  LogicalKeyboardKey.escape: '\x1b',
  LogicalKeyboardKey.home: '\x1b[H',
  LogicalKeyboardKey.end: '\x1b[F',
  LogicalKeyboardKey.insert: '\x1b[2~',
  LogicalKeyboardKey.delete: '\x1b[3~',
  LogicalKeyboardKey.pageUp: '\x1b[5~',
  LogicalKeyboardKey.pageDown: '\x1b[6~',
  LogicalKeyboardKey.f1: '\x1bOP',
  LogicalKeyboardKey.f2: '\x1bOQ',
  LogicalKeyboardKey.f3: '\x1bOR',
  LogicalKeyboardKey.f4: '\x1bOS',
};
