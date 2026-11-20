import 'package:flutter/services.dart' show HardwareKeyboard, KeyEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show SingleActivator;

import 'host_os.dart';

/// A keyboard shortcut, said once for every OS. [primary] is ⌘ on macOS
/// and Ctrl elsewhere; [elsewhere] gives another combo off macOS when the
/// translated one would be wrong there (a key the shell needs).
///
/// [label] and [activator] both come from this one description, through
/// [hostOs], so what a tooltip says is the key that works.
class KeyCombo {
  const KeyCombo(this.key, {this.primary = false, this.shift = false, this.alt = false, this.control = false, this.keyName, this.macKey, this.elsewhere});

  final LogicalKeyboardKey key;

  /// ⌘ on macOS, Ctrl elsewhere.
  final bool primary;

  final bool shift;

  /// ⌥ on macOS, Alt elsewhere.
  final bool alt;

  /// ⌃ on macOS. Elsewhere Ctrl, or Alt next to [primary] (Ctrl already).
  final bool control;

  /// What the key is called when it isn't its own name ('1…9' for a range).
  final String? keyName;

  /// macOS's glyph for the key when it isn't the usual one ('↵' for ↩).
  final String? macKey;

  /// The combo off macOS, when it isn't this one translated.
  final KeyCombo? elsewhere;

  /// As menus, tooltips and hints show it: "⇧⌘D" on macOS, "Ctrl+Shift+D"
  /// elsewhere.
  String get label => hostOs.keyLabel(this);

  /// One cap per key, for a row of key caps.
  List<String> get caps => hostOs.keyCaps(this);

  /// The binding.
  SingleActivator get activator => hostOs.keyActivator(this);

  /// [activator], then the same keys as the other OSes bind them (⌘ and
  /// Ctrl swapped), for app-wide keys a hand used to either finds.
  List<SingleActivator> get activators => [activator, if (hostOs.commandKey) ctrlKeyActivator(this) else commandKeyActivator(this)];

  /// Whether [event] is this combo pressed (exactly these modifiers), as
  /// [activator] binds it.
  bool accepts(KeyEvent event, [HardwareKeyboard? keys]) => activator.accepts(event, keys ?? HardwareKeyboard.instance);

  /// As Windows and Linux show it ("Ctrl+Shift+Y"), for copy on macOS that
  /// names both.
  String get labelOffMac => ctrlKeyCaps(this).join('+');
}

/// The shortcuts the app shows somewhere, in one place.
abstract final class AppKeys {
  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  // Anywhere.

  /// The side-nav's view at [index] (0…4).
  static KeyCombo view(int index) => KeyCombo(_digits[index], primary: true);

  /// All of them, for Settings.
  static const views = KeyCombo(LogicalKeyboardKey.digit1, primary: true, keyName: '1…5');

  /// The workspace at [n] (1…9) in the switcher.
  static KeyCombo workspace(int n) => KeyCombo(_digits[n - 1], primary: true, control: true);

  /// All of them, for Settings.
  static const workspaces = KeyCombo(LogicalKeyboardKey.digit1, primary: true, control: true, keyName: '1…9');

  static const settings = KeyCombo(LogicalKeyboardKey.comma, primary: true);
  static const newWorktree = KeyCombo(LogicalKeyboardKey.keyN, primary: true, shift: true);
  static const toggleSidebar = KeyCombo(LogicalKeyboardKey.keyS, primary: true, alt: true);
  static const toggleSidePanel = KeyCombo(LogicalKeyboardKey.keyB, primary: true, alt: true);
  static const cycleTheme = KeyCombo(LogicalKeyboardKey.keyL, primary: true, shift: true);
  static const search = KeyCombo(LogicalKeyboardKey.keyK, primary: true);

  /// Sends a dialog or a message box.
  static const submit = KeyCombo(LogicalKeyboardKey.enter, primary: true);
  /// [submit] on a button, where room is short: "Ctrl+↵" off macOS.
  static const submitOnButton = KeyCombo(LogicalKeyboardKey.enter, primary: true, elsewhere: KeyCombo(LogicalKeyboardKey.enter, control: true, keyName: '↵'));
  static const commitAndPush = KeyCombo(LogicalKeyboardKey.enter, primary: true, shift: true);
  static const deleteNamespace = KeyCombo(LogicalKeyboardKey.backspace, primary: true);

  // The editor.

  static const quickOpen = KeyCombo(LogicalKeyboardKey.keyP, primary: true);
  static const save = KeyCombo(LogicalKeyboardKey.keyS, primary: true);
  static const closeFile = KeyCombo(LogicalKeyboardKey.keyW, primary: true);
  static const find = KeyCombo(LogicalKeyboardKey.keyF, primary: true);
  static const replace = KeyCombo(LogicalKeyboardKey.keyF, primary: true, alt: true, elsewhere: KeyCombo(LogicalKeyboardKey.keyH, control: true));
  static const findNext = KeyCombo(LogicalKeyboardKey.keyG, primary: true);
  static const findPrevious = KeyCombo(LogicalKeyboardKey.keyG, primary: true, shift: true);
  static const togglePreview = KeyCombo(LogicalKeyboardKey.keyV, primary: true, shift: true);
  static const nextTab = KeyCombo(LogicalKeyboardKey.bracketRight, primary: true, shift: true);
  static const previousTab = KeyCombo(LogicalKeyboardKey.bracketLeft, primary: true, shift: true);
  static const askAgent = KeyCombo(LogicalKeyboardKey.keyL, primary: true);
  static const replaceAll = KeyCombo(LogicalKeyboardKey.enter, primary: true, keyName: '↵');
  static const findPreviousByEnter = KeyCombo(LogicalKeyboardKey.enter, shift: true, keyName: '↵');

  // The terminal: Ctrl+Shift off macOS, so the shell keeps Ctrl+C, V, Y…

  static KeyCombo _terminal(LogicalKeyboardKey key) => KeyCombo(key, primary: true, elsewhere: KeyCombo(key, control: true, shift: true));

  static final terminalCopy = _terminal(LogicalKeyboardKey.keyC);
  static final terminalPaste = _terminal(LogicalKeyboardKey.keyV);
  static final terminalHistory = _terminal(LogicalKeyboardKey.keyY);
  static final previousCommand = _terminal(LogicalKeyboardKey.arrowUp);
  static final nextCommand = _terminal(LogicalKeyboardKey.arrowDown);

  /// macOS only: Ctrl+Shift+A is the shell's.
  static const terminalSelectAll = KeyCombo(LogicalKeyboardKey.keyA, primary: true);
  static const backToPrompt = KeyCombo(LogicalKeyboardKey.end, primary: true, elsewhere: KeyCombo(LogicalKeyboardKey.end, shift: true));
  static const nextWord = KeyCombo(LogicalKeyboardKey.arrowRight, alt: true);

  /// In the command history: runs the one picked.
  static const runFromHistory = KeyCombo(LogicalKeyboardKey.enter, primary: true, keyName: '↵');

  /// The terminal's pane keys ([HostOs.paneShortcut]).
  static KeyCombo pane(PaneShortcut command) => switch (command) {
        PaneShortcut.newTab => const KeyCombo(LogicalKeyboardKey.keyT, primary: true, elsewhere: KeyCombo(LogicalKeyboardKey.keyT, control: true, shift: true)),
        PaneShortcut.closePane => const KeyCombo(LogicalKeyboardKey.keyW, primary: true, elsewhere: KeyCombo(LogicalKeyboardKey.keyW, control: true, shift: true)),
        PaneShortcut.splitRight => const KeyCombo(LogicalKeyboardKey.keyD, primary: true, elsewhere: KeyCombo(LogicalKeyboardKey.keyD, control: true, shift: true)),
        PaneShortcut.splitDown => const KeyCombo(LogicalKeyboardKey.keyD, primary: true, shift: true, elsewhere: KeyCombo(LogicalKeyboardKey.keyE, control: true, shift: true)),
      };
}

/// Names of keys as shown off macOS, where [LogicalKeyboardKey.keyLabel]
/// isn't what people read on the key cap.
final Map<LogicalKeyboardKey, String> spelledKeyNames = {
  LogicalKeyboardKey.enter: 'Enter',
  LogicalKeyboardKey.numpadEnter: 'Enter',
  LogicalKeyboardKey.backspace: 'Backspace',
  LogicalKeyboardKey.delete: 'Delete',
  LogicalKeyboardKey.escape: 'Esc',
  LogicalKeyboardKey.arrowUp: '↑',
  LogicalKeyboardKey.arrowDown: '↓',
  LogicalKeyboardKey.arrowLeft: '←',
  LogicalKeyboardKey.arrowRight: '→',
  LogicalKeyboardKey.end: 'End',
  LogicalKeyboardKey.home: 'Home',
  LogicalKeyboardKey.tab: 'Tab',
};

/// macOS's glyphs for the same keys.
final Map<LogicalKeyboardKey, String> macKeyGlyphs = {
  LogicalKeyboardKey.enter: '↩',
  LogicalKeyboardKey.numpadEnter: '↩',
  LogicalKeyboardKey.backspace: '⌫',
  LogicalKeyboardKey.delete: '⌦',
  LogicalKeyboardKey.escape: 'Esc',
  LogicalKeyboardKey.arrowUp: '↑',
  LogicalKeyboardKey.arrowDown: '↓',
  LogicalKeyboardKey.arrowLeft: '←',
  LogicalKeyboardKey.arrowRight: '→',
  LogicalKeyboardKey.end: 'End',
  LogicalKeyboardKey.home: 'Home',
  LogicalKeyboardKey.tab: '⇥',
};

/// A letter, digit or punctuation key as its cap shows it.
String plainKeyName(LogicalKeyboardKey key) => key.keyLabel.toUpperCase();
