import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../theme/palette.dart';
import 'cell_width.dart';
import 'drawn_glyphs.dart';
import 'terminal_surface.dart';

/// Paints [TermLine]s on a fixed cell grid: every glyph sits at
/// `column × cellWidth`, whatever font it comes from.
///
/// Per row: backgrounds first (full cell height, so adjacent cells join),
/// then text. Plain Latin text is laid out in runs (one paragraph per run,
/// the mono font keeps the advance equal to the cell). Anything else is
/// placed cell by cell, centred and squeezed to fit, or drawn as a shape
/// (powerline, box drawing, blocks).
///
/// Rows are recorded into [ui.Picture]s and cached per [TermLine] instance:
/// the parser only builds a new line when a row changes, so a frame re-records
/// just the dirty rows.
class TerminalGridRenderer {
  final _cache = Expando<(int, ui.Picture)>('terminal rows');

  /// Laid-out single glyphs (icons, CJK, symbols), reused across rows.
  final _glyphs = <(int, TextStyle), ui.Paragraph>{};
  static const _maxGlyphs = 1024;
  int _generation = 0;

  KumoPalette? _palette;
  TextStyle _style = const TextStyle();
  ui.ParagraphStyle _paragraphStyle = ui.ParagraphStyle();
  double _cellWidth = 8;
  double _lineExtent = 16;

  double get cellWidth => _cellWidth;
  double get lineExtent => _lineExtent;

  /// Call before painting; a change invalidates every cached row.
  void configure({required KumoPalette palette, required TextStyle style, required double cellWidth, required double lineExtent}) {
    if (palette == _palette && style == _style && cellWidth == _cellWidth && lineExtent == _lineExtent) return;
    _palette = palette;
    _style = style;
    // A forced strut gives every paragraph the same height and baseline,
    // whichever fallback font its glyphs come from.
    _paragraphStyle = style.getParagraphStyle(
      textDirection: TextDirection.ltr,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
    );
    _cellWidth = cellWidth;
    _lineExtent = lineExtent;
    _generation++;
    _clearGlyphs();
  }

  void _clearGlyphs() {
    for (final paragraph in _glyphs.values) {
      paragraph.dispose();
    }
    _glyphs.clear();
  }

  void dispose() => _clearGlyphs();

  /// The row recorded at origin (0, 0), one [lineExtent] tall.
  ui.Picture row(TermLine line) {
    final cached = _cache[line];
    if (cached != null && cached.$1 == _generation) return cached.$2;
    final picture = _record(line);
    _cache[line] = (_generation, picture);
    return picture;
  }

  /// Background color of the terminal (what inverse text on a default
  /// background paints its letters with).
  Color get background => _palette!.pane.withValues(alpha: 1);

  /// Paints one glyph in the cell at [column], e.g. the character under a
  /// block cursor in the background color.
  void paintGlyph(Canvas canvas, int rune, int column, Color color, {bool bold = false}) {
    _glyph(canvas, rune, column, termCellWidth(rune).clamp(1, 2), _textStyle(color, bold: bold));
  }

  /// The code point and span at [column] of [line], if any.
  static (int, TermSpan)? cellAt(TermLine line, int column) {
    var col = 0;
    for (final span in line.spans) {
      for (final rune in span.text.runes) {
        final width = termCellWidth(rune);
        if (width == 0) continue;
        if (column < col + width) return (rune, span);
        col += width;
      }
    }
    return null;
  }

  ui.Picture _record(TermLine line) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final palette = _palette!;
    final backgrounds = <(int, int, Color)>[];
    final glyphs = <void Function()>[];

    var col = 0;
    for (final span in line.spans) {
      var fg = span.rgb != null ? Color(0xFF000000 | span.rgb!) : _roleColor(palette, span.role);
      Color? bg = switch (span.background) {
        null => null,
        TermColor(:final rgb?) => Color(0xFF000000 | rgb),
        TermColor(:final role) => _roleColor(palette, role!),
      };
      if (span.inverse) (fg, bg) = (bg ?? background, fg);
      if (span.dim) fg = fg.withValues(alpha: fg.a * 0.55);
      final style = _textStyle(fg, bold: span.bold, italic: span.italic, underline: span.underline);

      final spanStart = col;
      var runStart = col;
      final run = StringBuffer();
      void flush() {
        if (run.isEmpty) return;
        final text = run.toString();
        final at = runStart;
        glyphs.add(() => _text(canvas, text, at, style));
        run.clear();
      }

      for (final rune in span.text.runes) {
        final width = termCellWidth(rune);
        if (width == 0) continue;
        if (_isGridText(rune)) {
          if (run.isEmpty) runStart = col;
          run.writeCharCode(rune);
        } else {
          flush();
          final at = col;
          glyphs.add(() => _glyph(canvas, rune, at, width, style));
        }
        col += width;
      }
      flush();
      if (bg != null && col > spanStart) backgrounds.add((spanStart, col - spanStart, bg));
    }

    for (final (start, cells, color) in backgrounds) {
      canvas.drawRect(Rect.fromLTWH(start * _cellWidth, 0, cells * _cellWidth, _lineExtent), Paint()..color = color);
    }
    for (final paint in glyphs) {
      paint();
    }
    return recorder.endRecording();
  }

  /// Glyphs the mono font is known to draw at exactly one cell.
  static bool _isGridText(int rune) => (rune >= 0x20 && rune < 0x7F) || (rune >= 0xA0 && rune < 0x180);

  TextStyle _textStyle(Color color, {bool bold = false, bool italic = false, bool underline = false}) => _style.copyWith(
        color: color,
        fontWeight: bold ? FontWeight.w700 : null,
        fontStyle: italic ? FontStyle.italic : null,
        decoration: underline ? TextDecoration.underline : null,
        decorationColor: color,
      );

  ui.Paragraph _paragraph(String text, TextStyle style) {
    final builder = ui.ParagraphBuilder(_paragraphStyle)
      ..pushStyle(style.getTextStyle())
      ..addText(text);
    return builder.build()..layout(const ui.ParagraphConstraints(width: double.infinity));
  }

  void _text(Canvas canvas, String text, int column, TextStyle style) {
    final paragraph = _paragraph(text, style);
    canvas.drawParagraph(paragraph, Offset(column * _cellWidth, 0));
    paragraph.dispose();
  }

  void _glyph(Canvas canvas, int rune, int column, int cells, TextStyle style) {
    final cell = Rect.fromLTWH(column * _cellWidth, 0, cells * _cellWidth, _lineExtent);
    final stroke = (_style.fontSize! / 12).roundToDouble().clamp(1.0, 4.0);
    if (paintDrawnGlyph(canvas, rune, cell, style.color!, stroke: stroke)) return;

    if (_glyphs.length >= _maxGlyphs) _clearGlyphs();
    final paragraph = _glyphs.putIfAbsent((rune, style), () => _paragraph(String.fromCharCode(rune), style));
    final width = paragraph.maxIntrinsicWidth;
    if (width <= cell.width) {
      canvas.drawParagraph(paragraph, Offset(cell.left + (cell.width - width) / 2, 0));
      return;
    }
    // Wider than its cells (e.g. a proportional fallback): squeeze it in.
    canvas
      ..save()
      ..translate(cell.left, 0)
      ..scale(cell.width / width, 1)
      ..drawParagraph(paragraph, Offset.zero)
      ..restore();
  }

  static Color _roleColor(KumoPalette p, TermRole role) => switch (role) {
        TermRole.text => p.text,
        TermRole.text2 => p.text2,
        TermRole.text3 => p.text3,
        TermRole.acc => p.acc,
        TermRole.ok => p.ok,
        TermRole.warn => p.warn,
        TermRole.err => p.err,
        TermRole.purple => p.purple,
        TermRole.yellow => p.yellow,
        TermRole.cyan => p.cyan,
      };
}
