import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/change_scrollbar.dart';
import 'indent.dart';
import 'syntax.dart';

/// Editable controller that highlights as you type. The span text always
/// equals [text] exactly, so caret and selection stay correct.
class CodeController extends TextEditingController {
  CodeController({required String text, required this.lang, this.deleted = false}) : super(text: text);

  final Lang lang;
  bool deleted;
  KumoPalette? palette;

  /// The editor's font size, set by it. Flutter draws a tab as wide as a
  /// space; with this, each tab gets a font that many columns bigger, so it
  /// reaches the next stop and the text stays unchanged. (Letter spacing
  /// would also widen it, but Skia shifts the run by half of it, so the
  /// code drew off its columns.) The line keeps its height: the strut is
  /// forced.
  double fontSize = 0;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final p = palette ?? context.c;
    final lines = text.split('\n');
    final children = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      var col = 0;
      for (final (t, k) in Syntax.line(lang, lines[i])) {
        final s = deleted ? TextStyle(color: p.text3, decoration: TextDecoration.lineThrough) : _style(p, k);
        col = _addWithTabs(children, t, s, col);
      }
      if (i < lines.length - 1) children.add(const TextSpan(text: '\n'));
    }
    return TextSpan(style: style, children: children);
  }

  /// Adds [t] in [s] starting at column [col], each tab in a span of its
  /// own as wide as its stop; returns the column after it.
  int _addWithTabs(List<InlineSpan> out, String t, TextStyle s, int col) {
    if (fontSize <= 0 || !t.contains('\t')) {
      out.add(TextSpan(text: t, style: s));
      return col + visualWidth(t);
    }
    var start = 0;
    for (var j = 0; j < t.length; j++) {
      if (t.codeUnitAt(j) != 0x09) continue;
      if (j > start) out.add(TextSpan(text: t.substring(start, j), style: s));
      col += j - start;
      final adv = tabAdvance(col);
      // No strike-through: at that size it would cross the line elsewhere.
      out.add(TextSpan(text: '\t', style: adv == 1 ? s : s.copyWith(fontSize: fontSize * adv, decoration: TextDecoration.none)));
      col += adv;
      start = j + 1;
    }
    if (start < t.length) out.add(TextSpan(text: t.substring(start), style: s));
    return col + t.length - start;
  }

  static TextStyle _style(KumoPalette p, Tok k) => switch (k) {
        Tok.kw => TextStyle(color: p.synKw),
        Tok.str => TextStyle(color: p.synStr),
        Tok.num => TextStyle(color: p.synNum),
        Tok.com => TextStyle(color: p.text3, fontStyle: FontStyle.italic),
        Tok.type => TextStyle(color: p.synType),
        Tok.fn => TextStyle(color: p.synFn),
        Tok.key => TextStyle(color: p.synKey),
        Tok.punct => TextStyle(color: p.text2),
        Tok.text => TextStyle(color: p.text),
        Tok.head => TextStyle(color: p.synKw, fontWeight: FontWeight.w600),
      };

  /// 1-based (line, column) of the caret.
  (int, int) get caret {
    final off = selection.baseOffset.clamp(0, text.length);
    final before = text.substring(0, off);
    final line = '\n'.allMatches(before).length + 1;
    final col = off - (before.lastIndexOf('\n') + 1) + 1;
    return (line, col);
  }
}

/// Per-line decoration: change bar in the gutter and a full-width background.
class LineDeco {
  const LineDeco({this.bar, this.background});
  final Color? bar;
  final Color? background;
}

/// Gutter + highlighted, editable code with vertical and horizontal scroll.
class CodeEditor extends StatefulWidget {
  const CodeEditor({super.key, required this.controller, required this.decorate, this.readOnly = false, this.fontSize = 12.5, this.scrollController, this.focusNode});

  /// The text's focus, to give it back from outside (optional).
  final FocusNode? focusNode;

  /// Height of a line, and the space above the first one.
  ///
  /// Measured, not `fontSize * 1.7`: the text engine rounds each line's
  /// height (21.25 → 21), and the gutter, the guides and the line
  /// backgrounds drift off the text by that much per line otherwise.
  static double lineExtentFor(double fontSize) => _extents[fontSize] ??= _measureExtent(fontSize);
  static final _extents = <double, double>{};

  static double _measureExtent(double fontSize) {
    const n = 100;
    final tp = TextPainter(
      text: TextSpan(text: List.filled(n, 'x').join('\n'), style: _textStyle(fontSize)),
      strutStyle: _strut(fontSize),
      textDirection: TextDirection.ltr,
    )..layout();
    final extent = tp.height / n;
    tp.dispose();
    return extent;
  }

  // Letter spacing 0, said out loud: the TextField would take Material's
  // (0.5 per glyph) and the code would drift off the column grid the
  // guides, the tabs and the line width are measured on.
  static TextStyle _textStyle(double fontSize, {Color? color}) => mono(fontSize, color: color, height: _CodeEditorState._lh).copyWith(letterSpacing: 0);

  /// Where the guide of column [col] is drawn: half a column in, so it
  /// doesn't touch the glyphs, on a pixel.
  @visibleForTesting
  static double guideX(int col, double charWidth) => (col * charWidth + charWidth * 0.5).floorToDouble() + 0.5;

  static StrutStyle _strut(double fontSize) =>
      StrutStyle(fontFamily: kMono, fontFamilyFallback: kMonoFallback, fontSize: fontSize, height: _CodeEditorState._lh, forceStrutHeight: true);
  static const topPadding = 10.0;

  final CodeController controller;

  /// Called with the current lines on every text change; must return one
  /// decoration per line.
  final List<LineDeco> Function(List<String> lines) decorate;
  final bool readOnly;
  final double fontSize;

  /// Vertical scrolling, to jump to a line from outside (optional).
  final ScrollController? scrollController;

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  final _ownV = ScrollController();
  final _h = ScrollController();
  static const _lh = 1.7;

  ScrollController get _v => widget.scrollController ?? _ownV;

  // The guides change with the text, not with the caret: kept between
  // builds.
  String? _guidesText;
  IndentGuides? _guides;

  IndentGuides _guidesFor(String text, List<String> lines) {
    if (text != _guidesText || _guides == null) {
      _guidesText = text;
      _guides = IndentGuides.of(lines);
    }
    return _guides!;
  }

  @override
  void dispose() {
    _ownV.dispose();
    _h.dispose();
    super.dispose();
  }

  double _charWidth(TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: 'MMMMMMMMMM', style: style), textDirection: TextDirection.ltr)..layout();
    final w = tp.width / 10;
    tp.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    widget.controller.palette = c;
    final style = CodeEditor._textStyle(widget.fontSize, color: c.text);
    final strut = CodeEditor._strut(widget.fontSize);
    final lineExtent = CodeEditor.lineExtentFor(widget.fontSize);
    final charW = _charWidth(style);
    widget.controller.fontSize = widget.fontSize;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final text = widget.controller.text;
        final lines = text.split('\n');
        final longest = lines.fold<int>(0, (m, l) => math.max(m, visualWidth(l)));
        final guides = _guidesFor(text, lines);
        final sel = widget.controller.selection;
        final active = sel.isValid ? guides.activeAt(widget.controller.caret.$1 - 1) : null;
        final raw = widget.decorate(lines);
        final decos = [for (var i = 0; i < lines.length; i++) i < raw.length ? raw[i] : const LineDeco()];
        // The scrollbar maps the change bars of the gutter.
        return ChangeScrollbar(
          controller: _v,
          ticks: changeTicks(List.filled(lines.length, lineExtent), [for (final d in decos) d.bar], top: CodeEditor.topPadding, bottom: 24),
          child: SingleChildScrollView(
            controller: _v,
            padding: const EdgeInsets.only(top: CodeEditor.topPadding, bottom: 24),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Gutter: change bar + line number.
              ExcludeSemantics(
                child: SizedBox(
                  width: 58,
                  child: Column(children: [
                    for (var i = 0; i < lines.length; i++)
                      SizedBox(
                        height: lineExtent,
                        child: Row(children: [
                          Container(width: 3, color: decos[i].bar),
                          Expanded(
                            child: ColoredBox(
                              color: decos[i].background ?? Colors.transparent,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: Align(alignment: Alignment.centerRight, child: Text('${i + 1}', style: mono(widget.fontSize, color: c.text3, height: 1))),
                              ),
                            ),
                          ),
                        ]),
                      ),
                  ]),
                ),
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  final contentW = math.max(box.maxWidth, longest * charW + 48);
                  return Scrollbar(
                    controller: _h,
                    child: SingleChildScrollView(
                      controller: _h,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: contentW,
                        child: Stack(children: [
                          Column(children: [
                            for (final d in decos) Container(height: lineExtent, color: d.background),
                          ]),
                          // Indentation guides: where each block starts and ends.
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _GuidesPainter(
                                  guides: guides,
                                  active: active,
                                  charWidth: charW,
                                  lineExtent: lineExtent,
                                  color: c.text3.withValues(alpha: c.text3.a * 0.22),
                                  activeColor: c.text3.withValues(alpha: c.text3.a * 0.7),
                                ),
                              ),
                            ),
                          ),
                          TextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            readOnly: widget.readOnly,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            style: style,
                            strutStyle: strut,
                            cursorColor: c.acc,
                            cursorWidth: 2,
                            decoration: const InputDecoration.collapsed(hintText: null),
                            scrollPhysics: const NeverScrollableScrollPhysics(),
                          ),
                        ]),
                      ),
                    ),
                  );
                }),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// One vertical line per indentation level, brighter for the block around
/// the caret.
class _GuidesPainter extends CustomPainter {
  _GuidesPainter({required this.guides, required this.active, required this.charWidth, required this.lineExtent, required this.color, required this.activeColor});

  final IndentGuides guides;
  final Guide? active;
  final double charWidth;
  final double lineExtent;
  final Color color;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    // Only the lines on screen would do, but the canvas clips and this is
    // cheap next to laying out the text.
    for (var i = 0; i < guides.depth.length; i++) {
      final top = i * lineExtent;
      for (final col in guides.columnsAt(i)) {
        final x = _x(col);
        canvas.drawLine(Offset(x, top), Offset(x, top + lineExtent), paint);
      }
    }
    final a = active;
    if (a != null) {
      final x = _x(a.column);
      canvas.drawLine(Offset(x, a.first * lineExtent), Offset(x, (a.last + 1) * lineExtent), paint..color = activeColor);
    }
  }

  double _x(int col) => CodeEditor.guideX(col, charWidth);

  @override
  bool shouldRepaint(_GuidesPainter old) =>
      old.guides != guides || old.active != active || old.charWidth != charWidth || old.lineExtent != lineExtent || old.color != color || old.activeColor != activeColor;
}
