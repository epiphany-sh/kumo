import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show ShortcutActivator;

import 'syntax.dart';

/// How a line is commented out in [lang]: what goes before it and, for
/// languages without line comments (Markdown), after it. Null: it has none
/// (JSON, plain text).
(String, String)? commentTokens(Lang lang) => switch (lang) {
      Lang.go || Lang.rust || Lang.dart || Lang.ts || Lang.swift || Lang.kotlin || Lang.java || Lang.c || Lang.proto => ('//', ''),
      Lang.python || Lang.shell || Lang.toml || Lang.yaml || Lang.makefile || Lang.ignore => ('#', ''),
      Lang.sql => ('--', ''),
      Lang.markdown => ('<!--', '-->'),
      Lang.json || Lang.plain => null,
    };

/// ⌘/: comments out the selected lines (the caret's line with no
/// selection), or, when every one of them already is, uncomments them.
/// Blank lines are left alone; the marker goes at the block's least
/// indent, so the code keeps its shape. Returns the new value, selection
/// kept on the same text; null when there is nothing to do.
TextEditingValue? toggleLineComment(TextEditingValue value, Lang lang) {
  final tokens = commentTokens(lang);
  if (tokens == null) return null;
  final (open, close) = tokens;
  final text = value.text;
  final sel = value.selection.isValid ? value.selection : const TextSelection.collapsed(offset: 0);
  final lines = text.split('\n');
  final starts = <int>[];
  var at = 0;
  for (final l in lines) {
    starts.add(at);
    at += l.length + 1;
  }
  int lineOf(int offset) {
    var i = 0;
    while (i + 1 < starts.length && starts[i + 1] <= offset) {
      i++;
    }
    return i;
  }

  final first = lineOf(sel.start.clamp(0, text.length));
  var last = lineOf(sel.end.clamp(0, text.length));
  // A selection that ends at the start of a line doesn't take that line.
  if (!sel.isCollapsed && last > first && sel.end == starts[last]) last--;

  final picked = [
    for (var i = first; i <= last; i++)
      if (lines[i].trim().isNotEmpty) i
  ];
  if (picked.isEmpty) return null;
  bool commented(String l) {
    final t = l.trim();
    return t.startsWith(open) && (close.isEmpty || t.endsWith(close));
  }

  final uncomment = picked.every((i) => commented(lines[i]));
  final indent = picked.map((i) => lines[i].length - lines[i].trimLeft().length).reduce((a, b) => a < b ? a : b);

  // Per line: where the edit at its start happens and how much it moved
  // the text after it (to carry the selection along).
  final edits = <int, (int col, int delta)>{};
  final out = List.of(lines);
  for (final i in picked) {
    final l = lines[i];
    if (uncomment) {
      final col = l.length - l.trimLeft().length;
      final removed = open.length + (l.startsWith(' ', col + open.length) ? 1 : 0);
      var body = l.substring(col + removed);
      if (close.isNotEmpty) {
        final trimmed = body.trimRight();
        body = trimmed.substring(0, trimmed.length - close.length);
        if (body.endsWith(' ')) body = body.substring(0, body.length - 1);
      }
      out[i] = l.substring(0, col) + body;
      edits[i] = (col, -removed);
    } else {
      final head = '$open ';
      out[i] = l.substring(0, indent) + head + l.substring(indent) + (close.isEmpty ? '' : ' $close');
      edits[i] = (indent, head.length);
    }
  }

  final newText = out.join('\n');
  final newStarts = <int>[];
  at = 0;
  for (final l in out) {
    newStarts.add(at);
    at += l.length + 1;
  }
  int map(int offset) {
    final i = lineOf(offset);
    final col = offset - starts[i];
    final e = edits[i];
    var c = col;
    if (e != null) {
      final (where, delta) = e;
      if (delta > 0 && col >= where) c = col + delta;
      if (delta < 0 && col > where) c = (col + delta) < where ? where : col + delta;
    }
    return (newStarts[i] + c).clamp(newStarts[i], newStarts[i] + out[i].length);
  }

  return TextEditingValue(
    text: newText,
    selection: TextSelection(baseOffset: map(sel.baseOffset.clamp(0, text.length)), extentOffset: map(sel.extentOffset.clamp(0, text.length))),
  );
}

/// ⌘/ (Ctrl+/ elsewhere), whatever the keyboard: the `/` key of a US one
/// (by where it is), or wherever `/` is (Shift+7 on a Spanish one).
class CommentKeyActivator extends ShortcutActivator {
  const CommentKeyActivator({required this.meta});

  /// ⌘ (macOS) or Ctrl.
  final bool meta;

  @override
  Iterable<LogicalKeyboardKey>? get triggers => null;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final mod = meta ? state.isMetaPressed && !state.isControlPressed : state.isControlPressed && !state.isMetaPressed;
    if (!mod || state.isAltPressed) return false;
    return event.logicalKey == LogicalKeyboardKey.slash || event.logicalKey == LogicalKeyboardKey.numpadDivide || event.physicalKey == PhysicalKeyboardKey.slash || event.character == '/';
  }

  @override
  String debugDescribeKeys() => meta ? '⌘/' : 'Ctrl+/';

  @override
  bool operator ==(Object other) => other is CommentKeyActivator && other.meta == meta;

  @override
  int get hashCode => meta.hashCode;
}
