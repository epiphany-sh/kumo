import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/editor/code_editor.dart';
import 'package:kumo_ui/editor/indent.dart';
import 'package:kumo_ui/editor/syntax.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';

const _go = [
  'func (s *Service) Apply(b Bulk) error {', // 0
  '\tif err := b.Validate(); err != nil {', //  1
  '\t\treturn err', //                          2
  '\t}', //                                     3
  '', //                                        4
  '\treturn nil', //                            5
  '}', //                                       6
  '', //                                        7
  'func other() {}', //                         8
];

void main() {
  test('tabs advance to the next stop', () {
    expect(visualWidth('\t\treturn'), 8 + 6);
    expect(visualWidth('ab\tc'), 5);
    expect(visualWidth('abcd\tc'), 9);
    expect(indentOf('\t  x'), 6);
    expect(indentOf('   \t'), isNull);
  });

  test('blank lines keep the guides of the block they sit in', () {
    final g = IndentGuides.of(_go);
    expect(g.unit, 4);
    expect(g.depth, [0, 4, 8, 4, 4, 4, 0, 0, 0]);
    expect(g.columnsAt(2).toList(), [0, 4]);
    expect(g.columnsAt(7).toList(), isEmpty);
  });

  test('the active guide is the block a line opens, closes or sits in', () {
    final g = IndentGuides.of(_go);
    // `func … {` opens the body.
    expect(g.activeAt(0), (column: 0, first: 1, last: 5));
    // `if … {` opens its body; `}` closes it.
    expect(g.activeAt(1), (column: 4, first: 2, last: 2));
    expect(g.activeAt(3), (column: 4, first: 2, last: 2));
    // `return nil` sits in the function.
    expect(g.activeAt(5), (column: 0, first: 1, last: 5));
    expect(g.activeAt(8), isNull);
  });

  test('space indentation finds its unit, ignoring block comment stars', () {
    expect(IndentGuides.of(['a:', '  b:', '    c: 1', ' * note']).unit, 2);
    expect(IndentGuides.of(['fn a() {', '    x();', '}']).unit, 4);
    expect(IndentGuides.of(['plain', 'text']).unit, kTabSize);
  });

  testWidgets('the editor draws each tab up to its stop, in the real font', (tester) async {
    // The test font has every glyph alike and hid the bug: letter spacing
    // shifted the whole run by half of it. GeistMono shows it.
    final font = File('assets/fonts/GeistMono-Regular.ttf').readAsBytesSync();
    await (FontLoader(kMono)..addFont(Future.value(ByteData.sublistView(font)))).load();
    final ctrl = CodeController(text: '\t\treturn err\nab\tc', lang: Lang.go);
    await tester.pumpWidget(KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: CodeEditor(controller: ctrl, decorate: (_) => const []))),
    ));
    final editable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
    double glyphLeft(int offset) => editable.getBoxesForSelection(TextSelection(baseOffset: offset, extentOffset: offset + 1)).first.left;
    final tp = TextPainter(text: TextSpan(text: 'MMMMMMMMMM', style: mono(12.5)), textDirection: TextDirection.ltr)..layout();
    final colW = tp.width / 10;
    tp.dispose();
    // `return` after two tabs: column 8. `c` after `ab` + tab: column 4.
    expect(glyphLeft(0), moreOrLessEquals(0, epsilon: 0.5));
    expect(glyphLeft(2), moreOrLessEquals(8 * colW, epsilon: 0.5));
    expect(glyphLeft(3), moreOrLessEquals(9 * colW, epsilon: 0.5));
    final c = ctrl.text.lastIndexOf('c');
    expect(glyphLeft(c), moreOrLessEquals(4 * colW, epsilon: 0.5));
    // Lines keep their height around the bigger tabs.
    final lh = CodeEditor.lineExtentFor(12.5);
    expect(editable.getLocalRectForCaret(TextPosition(offset: c)).top - editable.getLocalRectForCaret(const TextPosition(offset: 2)).top, moreOrLessEquals(lh, epsilon: 0.5));
  });

  testWidgets('line 200 of the text sits where the gutter and the guides put it', (tester) async {
    // The engine rounds each line's height; a computed extent (21.25 for
    // 21) drifted two lines off by line 150.
    final font = File('assets/fonts/GeistMono-Regular.ttf').readAsBytesSync();
    await (FontLoader(kMono)..addFont(Future.value(ByteData.sublistView(font)))).load();
    final ctrl = CodeController(text: List.filled(200, '\tx := 1').join('\n'), lang: Lang.go);
    await tester.pumpWidget(KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: CodeEditor(controller: ctrl, decorate: (_) => const []))),
    ));
    final editable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
    double top(int line) => editable.getLocalRectForCaret(TextPosition(offset: line * 8)).top;
    final lh = CodeEditor.lineExtentFor(12.5);
    expect(top(199) - top(0), moreOrLessEquals(199 * lh, epsilon: 0.5));
  });
}
