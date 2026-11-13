import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

import '../app/preferences.dart';
import '../theme/palette.dart';

/// One command the shell ran, from its shell-integration marks (OSC 133:
/// A prompt, B command, C output, D;exit done). Lines are indices into
/// `TermBuffer.lines`.
@immutable
class CommandBlock {
  const CommandBlock({required this.start, required this.outputStart, this.end, this.exit, this.took});

  /// First line of the command: where its prompt starts.
  final int start;

  /// First line of its output. The command (prompt and what was typed,
  /// wrapped or continued) is [start] up to here.
  final int outputStart;

  /// The line after its output; null while it runs.
  final int? end;

  /// Exit status, once it's done (when the shell reported one).
  final int? exit;

  /// From output start to done, when both were seen as they happened (not
  /// replayed on reattach).
  final Duration? took;

  bool get running => end == null;

  /// Ctrl-C (130) and Ctrl-Z (148): stopped by you, not failed.
  bool get interrupted => exit == 130 || exit == 148;

  bool get failed => exit != null && exit != 0 && !interrupted;

  int get commandLines => outputStart - start;

  CommandBlock shifted(int by) => by == 0
      ? this
      : CommandBlock(start: start + by, outputStart: outputStart + by, end: end == null ? null : end! + by, exit: exit, took: took);

  @override
  bool operator ==(Object other) =>
      other is CommandBlock && other.start == start && other.outputStart == outputStart && other.end == end && other.exit == exit && other.took == took;

  @override
  int get hashCode => Object.hash(start, outputStart, end, exit, took);

  @override
  String toString() => 'CommandBlock($start, $outputStart, $end, exit: $exit, took: $took)';
}

/// What shows on a finished command's line, or null: the exit status when
/// it failed or was stopped, the time when it took 10 seconds or more.
String? commandMeta(CommandBlock b) {
  if (b.running) return null;
  final took = b.took;
  final time = took != null && took >= const Duration(seconds: 1) ? formatTook(took) : null;
  if (b.failed || b.interrupted) {
    final what = b.interrupted ? 'interrupted' : 'exit ${b.exit}';
    return time == null ? what : '$what · $time';
  }
  if (took != null && took >= const Duration(seconds: 10)) return time;
  return null;
}

/// 12s, 1m 05s, 1h 02m.
String formatTook(Duration d) {
  final s = d.inSeconds;
  if (s < 60) return '${s}s';
  if (s < 3600) return '${s ~/ 60}m ${(s % 60).toString().padLeft(2, '0')}s';
  return '${s ~/ 3600}h ${((s % 3600) ~/ 60).toString().padLeft(2, '0')}m';
}

/// The block whose command lines include [line], or null.
CommandBlock? blockAt(List<CommandBlock> blocks, int line) {
  // Blocks are in order; few are on screen, so a binary search to start.
  var lo = 0, hi = blocks.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (blocks[mid].start <= line) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  if (lo == 0) return null;
  final b = blocks[lo - 1];
  return line < b.outputStart ? b : null;
}

/// The last command starting above [line] (⌘↑).
CommandBlock? previousBlock(List<CommandBlock> blocks, num line) {
  for (var i = blocks.length - 1; i >= 0; i--) {
    if (blocks[i].start < line) return blocks[i];
  }
  return null;
}

/// The first command starting below [line] (⌘↓).
CommandBlock? nextBlock(List<CommandBlock> blocks, num line) {
  for (final b in blocks) {
    if (b.start > line) return b;
  }
  return null;
}

/// The command pinned at the top of the pane: [block], the [lines] of it
/// shown (its first one or two), pushed up by [shift] lines as the next
/// command arrives under it.
typedef StickyCommand = ({CommandBlock block, int lines, double shift});

/// The command whose output fills the top of the view, when its own lines
/// scrolled away: [first] is the first line on screen and [offset] the
/// fraction of it scrolled past.
StickyCommand? stickyCommand(List<CommandBlock> blocks, int first, double offset) {
  final top = first + offset;
  for (var i = blocks.length - 1; i >= 0; i--) {
    final b = blocks[i];
    if (b.start > top) continue;
    // Its command still shows (even in part), or the top is past its output.
    if (top < b.outputStart || (b.end != null && top >= b.end!)) return null;
    // Its command was trimmed off the scrollback: nothing to show.
    if (b.start < 0) return null;
    final lines = math.min(2, math.max(1, b.commandLines));
    // The next command pushes it up as it reaches its bottom edge.
    final next = i + 1 < blocks.length ? blocks[i + 1].start : null;
    final room = next == null ? double.infinity : next - top;
    return (block: b, lines: lines, shift: room < lines ? room - lines : 0.0);
  }
  return null;
}

// ---------------------------------------------------------------------------
// How your lines look (Settings → Appearance → Your lines in the terminal)
// ---------------------------------------------------------------------------

/// The marks on what you ran and the pinned command, as set in Settings.
@immutable
class YourLines {
  const YourLines({
    this.marks = true,
    this.band = true,
    this.bandAlpha = 0.08,
    this.bar = 2,
    this.dark = defaultColor,
    this.light,
    this.meta = true,
    this.sticky = true,
  });

  static const defaultColor = Color(0xFFFFA43D);

  /// Bar (and band) on the lines you ran.
  final bool marks;

  /// A faint band of the color across the line, besides the bar.
  final bool band;
  final double bandAlpha;

  /// Bar width in logical pixels.
  final double bar;

  /// On dark terminals (Dark, and Hybrid's terminal).
  final Color dark;

  /// Your own color for light terminals; null follows [dark] (see
  /// [forLightTerminal]).
  final Color? light;

  /// Exit status and time on a command that failed or was slow.
  final bool meta;

  /// The command stays on top while its output scrolls.
  final bool sticky;

  static const keyOn = 'terminal.marks.on';
  static const keyStyle = 'terminal.marks.style';
  static const keyDark = 'terminal.marks.dark';
  static const keyLightMode = 'terminal.marks.lightMode';
  static const keyLight = 'terminal.marks.light';
  static const keyBand = 'terminal.marks.band';
  static const keyBar = 'terminal.marks.bar';
  static const keyMeta = 'terminal.marks.meta';
  static const keySticky = 'terminal.stickyCommand';

  static bool isKey(String key) => key.startsWith('terminal.marks.') || key == keySticky;

  factory YourLines.from(Preferences p) {
    final own = p.get<String>(keyLightMode, 'auto') == 'own';
    return YourLines(
      marks: p.get<bool>(keyOn, true),
      band: p.get<String>(keyStyle, 'barBand') != 'bar',
      bandAlpha: p.get<num>(keyBand, 8).clamp(2, 30) / 100,
      bar: p.get<num>(keyBar, 2).clamp(1, 5).toDouble(),
      dark: parseHexColor(p.get<String>(keyDark, '')) ?? defaultColor,
      light: own ? parseHexColor(p.get<String>(keyLight, '')) : null,
      meta: p.get<bool>(keyMeta, true),
      sticky: p.get<bool>(keySticky, true),
    );
  }

  /// The mark's color in a terminal painted with [c]: what decides is the
  /// terminal's background, not the app's theme (Hybrid's is dark).
  Color colorFor(KumoPalette c) => c.isDark ? dark : (light ?? forLightTerminal(dark, terminalBackground(c)));

  @override
  bool operator ==(Object other) =>
      other is YourLines &&
      other.marks == marks &&
      other.band == band &&
      other.bandAlpha == bandAlpha &&
      other.bar == bar &&
      other.dark == dark &&
      other.light == light &&
      other.meta == meta &&
      other.sticky == sticky;

  @override
  int get hashCode => Object.hash(marks, band, bandAlpha, bar, dark, light, meta, sticky);
}

/// The swatches in Settings, for dark terminals. Light ones are these,
/// through [forLightTerminal].
const yourLinesPresets = <(String, Color)>[
  ('Orange', Color(0xFFFFA43D)),
  ('Tangerine', Color(0xFFFF8A3D)),
  ('Honey', Color(0xFFFFC94D)),
  ('Lemon', Color(0xFFF5D90A)),
  ('Coral', Color(0xFFFF6B6B)),
  ('Indigo', Color(0xFF97A6FF)),
  ('Mint', Color(0xFF5EE09A)),
  ('Sky', Color(0xFF7FDBEA)),
  ('Lilac', Color(0xFFC8A6FF)),
  ('Gray', Color(0xFF9AA0B4)),
];

/// Contrast a mark needs against its background: WCAG's 3:1 for UI parts.
const markContrast = 3.0;

/// `#RRGGBB` or `RRGGBB` (any case); null otherwise.
Color? parseHexColor(String text) {
  final t = text.trim();
  final hex = t.startsWith('#') ? t.substring(1) : t;
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex, radix: 16));
}

/// `#RRGGBB`, uppercase.
String hexOf(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

double _luminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// WCAG contrast ratio of two opaque colors, 1 to 21.
double contrastRatio(Color a, Color b) {
  final x = _luminance(a), y = _luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// [color] for a light terminal: the same hue and saturation, darker until
/// it has [markContrast] against [background].
Color forLightTerminal(Color color, Color background) {
  final hsl = HSLColor.fromColor(color.withAlpha(0xFF));
  var l = (hsl.lightness * 100).round();
  var out = color.withAlpha(0xFF);
  while (l > 8 && contrastRatio(out, background) < markContrast) {
    l -= 1;
    out = hsl.withLightness(l / 100).toColor();
  }
  return out;
}

/// What a terminal painted with [c] looks like behind its text: its
/// translucent fill over the window, roughly (the desktop behind varies).
Color terminalBackground(KumoPalette c) {
  final base = c.isDark ? const Color(0xFF0E1019) : const Color(0xFFF5F6FA);
  return Color.alphaBlend(c.term, base);
}
