import 'package:flutter/foundation.dart';

/// Semantic color roles. The painter maps them to the current palette, so a
/// theme switch never touches the buffer.
enum TermRole { text, text2, text3, acc, ok, warn, err, purple, yellow, cyan }

/// A cell color: a semantic [role] (themed: the 16 ANSI colors) or an
/// exact [rgb] (256-color and truecolor output).
@immutable
class TermColor {
  const TermColor.role(TermRole this.role) : rgb = null;
  const TermColor.rgb(int this.rgb) : role = null;

  final TermRole? role;
  final int? rgb;

  @override
  bool operator ==(Object other) => other is TermColor && other.role == role && other.rgb == rgb;

  @override
  int get hashCode => Object.hash(role, rgb);
}

/// A run of consecutive cells with one style. Each code point takes one
/// cell, or two for wide glyphs (see `termCellWidth`).
@immutable
class TermSpan {
  const TermSpan(this.text, [this.role = TermRole.text, this.bold = false])
      : rgb = null,
        background = null,
        dim = false,
        italic = false,
        underline = false,
        inverse = false;

  const TermSpan.styled(
    this.text, {
    this.role = TermRole.text,
    this.rgb,
    this.background,
    this.bold = false,
    this.dim = false,
    this.italic = false,
    this.underline = false,
    this.inverse = false,
  });

  final String text;

  /// Foreground role, used unless [rgb] is set.
  final TermRole role;

  /// Exact foreground color (0xRRGGBB).
  final int? rgb;

  /// Cell background; null is the terminal background.
  final TermColor? background;

  final bool bold;
  final bool dim;
  final bool italic;
  final bool underline;

  /// Swap foreground and background (SGR 7).
  final bool inverse;
}

@immutable
class TermLine {
  const TermLine(this.spans);
  final List<TermSpan> spans;

  static const empty = TermLine([]);

  /// Shorthand: TermLine.of([('❯ ', TermRole.acc), ('ls', TermRole.text)]).
  factory TermLine.of(List<(String, TermRole)> parts, {bool bold = false}) =>
      TermLine([for (final (t, r) in parts) TermSpan(t, r, bold)]);
}

/// Last-wins snapshot of what's on screen. In M2 this becomes the emulator's
/// screen state (dirty-line diffs from the daemon); in M0/M1 raw bytes.
@immutable
class TermBuffer {
  const TermBuffer(this.lines, {this.cursorVisible = true, this.cursor, this.seq = 0});
  final List<TermLine> lines;
  final bool cursorVisible;

  /// (line index into [lines], column) of a real terminal cursor. Null for
  /// line-oriented surfaces (mocks), which get a prompt-style cursor.
  final (int, int)? cursor;

  /// Monotonic per session (OutputBatch.seq in the proto).
  final int seq;

  TermBuffer append(List<TermLine> more, {int maxLines = 5000}) {
    final all = [...lines, ...more];
    final trimmed = all.length > maxLines ? all.sublist(all.length - maxLines) : all;
    return TermBuffer(trimmed, cursorVisible: cursorVisible, cursor: cursor, seq: seq + 1);
  }
}

/// What the UI needs from a terminal session. Implemented by the mocks and
/// by the daemon-backed `GrpcTerminalSurface` (Terminals.Attach bidi stream).
abstract interface class TerminalSurface {
  String get title;
  String get cwd;

  /// Repaints are driven by this listenable — one paint per frame, never a
  /// widget rebuild per message (kumo.md §5.6).
  ValueListenable<TermBuffer> get buffer;

  /// Whether the pane takes raw keyboard input ([sendBytes]).
  bool get interactive;

  /// A line of text, e.g. from the steer bar.
  void sendText(String text);

  /// Raw input for the PTY (keystrokes, paste).
  void sendBytes(List<int> bytes);

  void resize(int cols, int rows);
  void dispose();
}
