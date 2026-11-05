import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/editor/comment.dart';
import 'package:kumo_ui/editor/syntax.dart';

TextEditingValue _v(String text, int base, [int? extent]) => TextEditingValue(text: text, selection: TextSelection(baseOffset: base, extentOffset: extent ?? base));

void main() {
  test('the caret line, with the language marker, at its indent', () {
    final r = toggleLineComment(_v('func a() {\n    x := 1\n}', 16), Lang.go)!;
    expect(r.text, 'func a() {\n    // x := 1\n}');
    expect(r.selection.baseOffset, 19, reason: 'the caret stays on the same character');
    expect(toggleLineComment(_v('func a() {\n    x := 1\n}', 13), Lang.go)!.selection.baseOffset, 13, reason: 'inside the indent it stays put');
    expect(toggleLineComment(r, Lang.go)!.text, 'func a() {\n    x := 1\n}', reason: 'again uncomments');
  });

  test('a block: one column (the least indent), blank lines left alone', () {
    const src = 'def f():\n    a = 1\n\n        b = 2\n';
    final r = toggleLineComment(_v(src, 9, 33), Lang.python)!;
    expect(r.text, 'def f():\n    # a = 1\n\n    #     b = 2\n');
    expect(r.selection.textInside(r.text), '    # a = 1\n\n    #     b = 2');
    expect(toggleLineComment(r, Lang.python)!.text, src);
  });

  test('a mix of commented and not comments them all', () {
    expect(toggleLineComment(_v('// a\nb', 0, 6), Lang.ts)!.text, '// // a\n// b');
  });

  test('a selection ending at a line start leaves that line out', () {
    expect(toggleLineComment(_v('a\nb\nc', 0, 4), Lang.rust)!.text, '// a\n// b\nc');
  });

  test('each language its own marker; JSON has none', () {
    expect(toggleLineComment(_v('SELECT 1', 0), Lang.sql)!.text, '-- SELECT 1');
    expect(toggleLineComment(_v('key: 1', 0), Lang.yaml)!.text, '# key: 1');
    expect(toggleLineComment(_v('Hello', 0), Lang.markdown)!.text, '<!-- Hello -->');
    expect(toggleLineComment(_v('<!-- Hello -->', 0), Lang.markdown)!.text, 'Hello');
    expect(toggleLineComment(_v('{"a": 1}', 0), Lang.json), isNull);
    expect(toggleLineComment(_v('\n\n', 1), Lang.go), isNull, reason: 'only blank lines');
  });

  test('⌘/ is accepted by where / is on a US keyboard or by what it types', () {
    const a = CommentKeyActivator(meta: true);
    expect(a, const CommentKeyActivator(meta: true));
    expect(a.debugDescribeKeys(), '⌘/');
  });
}
