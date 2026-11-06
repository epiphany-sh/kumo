// The code editor's geometry, in the real font: the text, the gutter, the
// line backgrounds and the indentation guides must agree on where every
// line and every column is. Each test here pins a bug that shipped once:
//
// - tabs drawn one space wide (Go lost its shape);
// - tabs widened with letter spacing, which Skia shifts by half of it;
// - Material's 0.5 letter spacing on every glyph, inherited by the
//   TextField, which drifted columns and wrapped long lines;
// - the line height computed as fontSize × 1.7 (21.25) while the engine
//   rounds it (21): the gutter and the guides two lines off by line 150.
//
// The test font (Ahem) has every glyph alike and hides all of this, so the
// app's GeistMono is loaded.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/editor/code_editor.dart';
import 'package:kumo_ui/editor/indent.dart';
import 'package:kumo_ui/editor/syntax.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';

Future<void> _loadMono() async {
  for (final f in ['GeistMono-Regular', 'GeistMono-Italic']) {
    final bytes = File('assets/fonts/$f.ttf').readAsBytesSync();
    await (FontLoader(kMono)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

double _colWidth(double fontSize) {
  final tp = TextPainter(text: TextSpan(text: 'MMMMMMMMMM', style: mono(fontSize)), textDirection: TextDirection.ltr)..layout();
  final w = tp.width / 10;
  tp.dispose();
  return w;
}

/// The editor showing [text], the window wide enough not to matter.
Future<RenderEditable> _editor(WidgetTester tester, String text, {Lang lang = Lang.go, double fontSize = 12.5, bool deleted = false}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await _loadMono();
  final ctrl = CodeController(text: text, lang: lang, deleted: deleted);
  await tester.pumpWidget(KumoTheme(
    mode: KumoThemeMode.dark,
    palette: KumoPalette.dark,
    terminalPalette: KumoPalette.dark,
    child: MaterialApp(
      // The app's theme: Material 3 text styles, whose letter spacing the
      // editor must not inherit.
      theme: materialThemeFor(KumoPalette.dark),
      home: Scaffold(body: CodeEditor(controller: ctrl, decorate: (_) => const [], fontSize: fontSize)),
    ),
  ));
  return tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
}

double _glyphLeft(RenderEditable e, int offset) => e.getBoxesForSelection(TextSelection(baseOffset: offset, extentOffset: offset + 1)).first.left;

double _lineTop(RenderEditable e, int offset) => e.getLocalRectForCaret(TextPosition(offset: offset)).top;

/// Offset of the first character of line [line] (0-based) in [text].
int _lineStart(String text, int line) {
  var off = 0;
  for (var i = 0; i < line; i++) {
    off = text.indexOf('\n', off) + 1;
  }
  return off;
}

void main() {
  group('columns', () {
    testWidgets('a long line keeps every glyph on its column: no inherited letter spacing', (tester) async {
      final line = List.generate(300, (i) => String.fromCharCode(0x61 + i % 26)).join();
      final e = await _editor(tester, line);
      final w = _colWidth(12.5);
      for (final col in [0, 1, 10, 100, 299]) {
        expect(_glyphLeft(e, col), moreOrLessEquals(col * w, epsilon: 0.5), reason: 'column $col');
      }
    });

    testWidgets('a long line does not wrap, even with tabs', (tester) async {
      final text = '${'\t' * 6}${'x' * 250}\nnext';
      final e = await _editor(tester, text);
      final last = text.indexOf('\n') - 1;
      expect(_lineTop(e, last), moreOrLessEquals(_lineTop(e, 0), epsilon: 0.5), reason: 'the long line wrapped');
      expect(_lineTop(e, text.length - 1) - _lineTop(e, 0), moreOrLessEquals(CodeEditor.lineExtentFor(12.5), epsilon: 0.5));
    });

    testWidgets('leading tabs: four columns each, from the first one', (tester) async {
      const text = 'a\n\tb\n\t\tc\n\t\t\td\n\t\t\t\te';
      final e = await _editor(tester, text);
      final w = _colWidth(12.5);
      for (var depth = 0; depth <= 4; depth++) {
        final at = _lineStart(text, depth) + depth;
        expect(_glyphLeft(e, at), moreOrLessEquals(depth * 4 * w, epsilon: 0.5), reason: 'depth $depth');
      }
    });

    testWidgets('a tab inside a line goes to the next stop', (tester) async {
      // gofmt aligns with spaces, but tabs in the middle happen.
      const text = 'a\tb\nabc\td\nabcd\te\nab\t\tf';
      final e = await _editor(tester, text);
      final w = _colWidth(12.5);
      expect(_glyphLeft(e, text.indexOf('b')), moreOrLessEquals(4 * w, epsilon: 0.5));
      expect(_glyphLeft(e, text.indexOf('d')), moreOrLessEquals(4 * w, epsilon: 0.5));
      expect(_glyphLeft(e, text.indexOf('e')), moreOrLessEquals(8 * w, epsilon: 0.5));
      expect(_glyphLeft(e, text.indexOf('f')), moreOrLessEquals(8 * w, epsilon: 0.5));
    });

    testWidgets('tabs inside comments and strings are widened too', (tester) async {
      const text = '\t// a\tb\n\tx := "c\td"';
      final e = await _editor(tester, text);
      final w = _colWidth(12.5);
      // `\t// a` is 4 + 4 columns: the tab on the stop at 8 runs to 12.
      expect(_glyphLeft(e, text.indexOf('b')), moreOrLessEquals(12 * w, epsilon: 0.5));
      // `\tx := "c` is 4 + 7 columns, so `d` sits on the stop at 12.
      expect(_glyphLeft(e, text.indexOf('d')), moreOrLessEquals(12 * w, epsilon: 0.5));
    });

    testWidgets('space indentation is left as it is', (tester) async {
      const text = 'fn a() {\n    let x = 1;\n        y();\n}';
      final e = await _editor(tester, text, lang: Lang.rust);
      final w = _colWidth(12.5);
      expect(_glyphLeft(e, text.indexOf('let')), moreOrLessEquals(4 * w, epsilon: 0.5));
      expect(_glyphLeft(e, text.indexOf('y()')), moreOrLessEquals(8 * w, epsilon: 0.5));
    });

    testWidgets('a deleted file (struck through) keeps its tab widths', (tester) async {
      const text = '\t\treturn err';
      final e = await _editor(tester, text, deleted: true);
      expect(_glyphLeft(e, 2), moreOrLessEquals(8 * _colWidth(12.5), epsilon: 0.5));
    });

    testWidgets('a selection over a tab is as wide as the tab', (tester) async {
      const text = 'ab\tc';
      final e = await _editor(tester, text);
      final box = e.getBoxesForSelection(const TextSelection(baseOffset: 2, extentOffset: 3)).first;
      expect(box.right - box.left, moreOrLessEquals(2 * _colWidth(12.5), epsilon: 0.5));
    });

    testWidgets('typing a tab re-lays the line out on the stops', (tester) async {
      final e = await _editor(tester, 'x\ny');
      final ctrl = tester.widget<EditableText>(find.byType(EditableText)).controller;
      ctrl.text = 'x\n\ty';
      await tester.pump();
      expect(_glyphLeft(e, 3), moreOrLessEquals(4 * _colWidth(12.5), epsilon: 0.5));
    });
  });

  group('lines', () {
    for (final size in [11.0, 12.5, 13.0, 14.0, 16.5]) {
      testWidgets('at ${size}pt, line 300 sits where the gutter puts it', (tester) async {
        final text = List.generate(300, (i) => '\tline $i').join('\n');
        final e = await _editor(tester, text, fontSize: size);
        final lh = CodeEditor.lineExtentFor(size);
        expect(_lineTop(e, _lineStart(text, 299)) - _lineTop(e, 0), moreOrLessEquals(299 * lh, epsilon: 0.5));
      });
    }

    testWidgets('the gutter numbers line up with their lines', (tester) async {
      final text = List.generate(40, (i) => '\tline $i').join('\n');
      final e = await _editor(tester, text);
      final editableOrigin = e.localToGlobal(Offset.zero).dy;
      for (final n in [1, 20, 40]) {
        final number = tester.getRect(find.text('$n')).center.dy;
        final caret = e.getLocalRectForCaret(TextPosition(offset: _lineStart(text, n - 1)));
        final line = editableOrigin + caret.top + CodeEditor.lineExtentFor(12.5) / 2;
        expect(number, moreOrLessEquals(line, epsilon: 1), reason: 'line $n');
      }
    });

    testWidgets('a tab does not make its line taller', (tester) async {
      const text = 'a\n\t\t\t\tb\nc';
      final e = await _editor(tester, text);
      final lh = CodeEditor.lineExtentFor(12.5);
      expect(_lineTop(e, text.indexOf('c')) - _lineTop(e, 0), moreOrLessEquals(2 * lh, epsilon: 0.5));
    });
  });

  group('guides', () {
    test('a guide is drawn inside the indentation, before the glyph of its level', () {
      for (final w in [6.6, 7.5, 8.4]) {
        for (final col in [0, 4, 8, 12]) {
          final x = CodeEditor.guideX(col, w);
          expect(x, greaterThan(col * w), reason: 'col $col, w $w');
          expect(x, lessThan((col + 1) * w), reason: 'col $col, w $w');
        }
      }
    });

    testWidgets('each guide sits under the first column of the lines it spans', (tester) async {
      const text = 'func a() {\n\tif x {\n\t\ty()\n\t}\n}';
      final e = await _editor(tester, text);
      final w = _colWidth(12.5);
      final g = IndentGuides.of(text.split('\n'));
      // Line 2 (`\t\ty()`) is crossed by the guides at 0 and 4: each falls
      // within the indentation, left of `y`.
      final y = _glyphLeft(e, text.indexOf('y'));
      for (final col in g.columnsAt(2)) {
        final x = CodeEditor.guideX(col, w);
        expect(x, lessThan(y));
        expect(x, greaterThanOrEqualTo(col * w));
      }
      expect(g.columnsAt(2).toList(), [0, 4]);
    });
  });

  group('indentation model', () {
    test('an empty buffer has no guides', () {
      final g = IndentGuides.of(['']);
      expect(g.depth, [0]);
      expect(g.activeAt(0), isNull);
      expect(g.activeAt(5), isNull);
      expect(g.activeAt(-1), isNull);
    });

    test('blank lines at the start and the end have no guides', () {
      final g = IndentGuides.of(['', '\tx', '', '']);
      expect(g.depth, [0, 4, 0, 0]);
    });

    test('whitespace-only lines count as blank', () {
      final g = IndentGuides.of(['{', '\t\tx', '   \t', '\t\ty', '}']);
      expect(g.depth[2], 8);
    });

    test('a blank line between two blocks of different depth takes the shallower', () {
      final g = IndentGuides.of(['{', '\t\t\tdeep', '', '\tshallow', '}']);
      expect(g.depth[2], 4);
    });

    test('the active guide spans blank lines inside the block', () {
      final g = IndentGuides.of(['func a() {', '\tx()', '', '\ty()', '}']);
      expect(g.activeAt(0), (column: 0, first: 1, last: 3));
      expect(g.activeAt(2), (column: 0, first: 1, last: 3));
    });

    test('nested blocks: the caret picks the innermost', () {
      final lines = ['func a() {', '\tfor {', '\t\tif x {', '\t\t\ty()', '\t\t}', '\t}', '}'];
      final g = IndentGuides.of(lines);
      expect(g.activeAt(3), (column: 8, first: 3, last: 3));
      expect(g.activeAt(2), (column: 8, first: 3, last: 3));
      expect(g.activeAt(1), (column: 4, first: 2, last: 4));
      expect(g.activeAt(5), (column: 4, first: 2, last: 4));
    });

    test('a Go switch: each case body is its own block', () {
      final lines = ['switch {', 'case a:', '\treturn 1', 'case b:', '\treturn 2', '}'];
      final g = IndentGuides.of(lines);
      expect(g.activeAt(1), (column: 0, first: 2, last: 2));
      expect(g.activeAt(3), (column: 0, first: 4, last: 4));
    });

    test('mixed tabs and spaces: the columns are what is drawn', () {
      expect(indentOf('\t  x'), 6);
      expect(indentOf('  \tx'), 4);
      expect(indentOf('\t\t'), isNull);
      final g = IndentGuides.of(['{', '\t  x', '}']);
      expect(g.unit, 4);
      expect(g.columnsAt(1).toList(), [0, 4]);
    });

    test('the space unit ignores odd alignment and huge indents', () {
      expect(IndentGuides.of(['a', '  b', '   c', '    d']).unit, 2);
      expect(IndentGuides.of(['a', '            b']).unit, kTabSize);
    });

    test('visual width counts tabs to their stops', () {
      expect(visualWidth(''), 0);
      expect(visualWidth('\t'), 4);
      expect(visualWidth('a\t'), 4);
      expect(visualWidth('abcd\t'), 8);
      expect(visualWidth('\t\t\t'), 12);
      expect(tabAdvance(0), 4);
      expect(tabAdvance(3), 1);
      expect(tabAdvance(4), 4);
      expect(tabAdvance(2, tabSize: 8), 6);
    });
  });
}
