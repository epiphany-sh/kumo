import 'package:flutter/services.dart';

import 'terminal_keys.dart';

/// A terminal's line to the OS text input system, while it has the focus
/// ([HostOs.terminalComposesText]).
///
/// Key events carry no composed character: on macOS AppKit composes a dead
/// key (⌥N) and the letter after it (N → ñ) only for a text input client.
/// The terminal leaves those keys to it ([composing]), and what it commits
/// goes to the shell through [onText].
class TerminalTextInput with TextInputClient {
  TerminalTextInput({required this.onText, required this.onBytes});

  /// Committed text, for the shell.
  final void Function(String text) onText;

  /// An editing command the input method sent as a key ([terminalSelectorInput]).
  final void Function(List<int> bytes) onBytes;

  TextInputConnection? _connection;
  TextEditingValue _value = TextEditingValue.empty;

  /// Whether a character is being composed: keys are the input method's
  /// until it commits or cancels.
  bool get composing => _connection != null && _value.composing.isValid && !_value.composing.isCollapsed;

  bool get attached => _connection?.attached ?? false;

  void attach() {
    if (attached) return;
    _value = TextEditingValue.empty;
    _connection = TextInput.attach(
      this,
      const TextInputConfiguration(
        inputType: TextInputType.text,
        inputAction: TextInputAction.none,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
      ),
    )
      ..setEditingState(_value)
      ..show();
  }

  void detach() {
    _connection?.close();
    _connection = null;
    _value = TextEditingValue.empty;
  }

  @override
  TextEditingValue? get currentTextEditingValue => _value;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    final text = terminalComposedText(value);
    if (text == null) {
      _value = value;
      return;
    }
    onText(text);
    // Empty again, so the next composition starts from nothing.
    _value = TextEditingValue.empty;
    _connection?.setEditingState(_value);
  }

  @override
  void performSelector(String selectorName) {
    final bytes = terminalSelectorInput(selectorName);
    if (bytes != null) onBytes(bytes);
  }

  @override
  void performAction(TextInputAction action) {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void connectionClosed() {
    _connection = null;
    _value = TextEditingValue.empty;
  }
}
