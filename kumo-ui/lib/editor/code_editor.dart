import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/change_scrollbar.dart';
import 'syntax.dart';

/// Editable controller that highlights as you type. The span text always
/// equals [text] exactly, so caret and selection stay correct.
class CodeController extends TextEditingController {
  CodeController({required String text, required this.lang, this.deleted = false}) : super(text: text);

  final Lang lang;
  bool deleted;
  KumoPalette? palette;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final p = palette ?? context.c;
    final lines = text.split('\n');
    final children = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      for (final (t, k) in Syntax.line(lang, lines[i])) {
        children.add(TextSpan(text: t, style: deleted ? TextStyle(color: p.text3, decoration: TextDecoration.lineThrough) : _style(p, k)));
      }
      if (i < lines.length - 1) children.add(const TextSpan(text: '\n'));
    }
    return TextSpan(style: style, children: children);
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
  static double lineExtentFor(double fontSize) => fontSize * _CodeEditorState._lh;
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
    final style = mono(widget.fontSize, color: c.text, height: _lh);
    final strut = StrutStyle(fontFamily: kMono, fontFamilyFallback: kMonoFallback, fontSize: widget.fontSize, height: _lh, forceStrutHeight: true);
    final lineExtent = widget.fontSize * _lh;
    final charW = _charWidth(style);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final lines = widget.controller.text.split('\n');
        final longest = lines.fold<int>(0, (m, l) => math.max(m, l.length));
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
