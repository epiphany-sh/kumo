import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/editor/code_editor.dart';
import 'package:kumo_ui/editor/find.dart';
import 'package:kumo_ui/editor/quick_open.dart';
import 'package:kumo_ui/editor/syntax.dart';

List<String> _found(String text, FindQuery q) => [for (final r in findMatches(text, q).matches) r.textInside(text)];

void main() {
  group('find', () {
    const text = 'Discount discount DISCOUNT discounts\nrediscount';

    test('ignores case unless asked', () {
      expect(_found(text, const FindQuery('discount')), hasLength(5));
      expect(_found(text, const FindQuery('discount', caseSensitive: true)), ['discount', 'discount', 'discount']);
    });

    test('whole words leave out longer words', () {
      expect(_found(text, const FindQuery('discount', wholeWord: true)), ['Discount', 'discount', 'DISCOUNT']);
    });

    test('regular expressions, across lines, and a bad one says so', () {
      expect(_found(text, const FindQuery(r'disc\w+s\b', regex: true)), ['discounts']);
      expect(_found(text, const FindQuery(r'^re\w+', regex: true)), ['rediscount'], reason: '^ is a line start');
      final bad = findMatches(text, const FindQuery('(', regex: true));
      expect(bad.matches, isEmpty);
      expect(bad.error, isNotNull);
      expect(findMatches(text, const FindQuery('x*', regex: true)).matches, isEmpty, reason: 'empty matches are skipped');
    });

    test('special characters are literal without regex', () {
      expect(_found('a.b axb (c)', const FindQuery('a.b')), ['a.b']);
      expect(_found('a.b axb (c)', const FindQuery('(c)')), ['(c)']);
    });

    test('stops at the limit and says it did', () {
      final many = findMatches(List.filled(50, 'x').join(' '), const FindQuery('x'), limit: 10);
      expect(many.matches, hasLength(10));
      expect(many.capped, isTrue);
    });

    test('replace one keeps the rest; regex groups expand', () {
      const q = FindQuery(r'(\w+)@(\w+)', regex: true);
      final r = findMatches('ana@pricing bo@ops', q).matches;
      final (one, end) = replaceMatch('ana@pricing bo@ops', r.first, q, r'$2/$1');
      expect(one, 'pricing/ana bo@ops');
      expect(end, 'pricing/ana'.length);
      expect(replaceAllMatches('ana@pricing bo@ops', q, r'$2/$1 ($&) $$'), ('pricing/ana (ana@pricing) \$ ops/bo (bo@ops) \$', 2));
      expect(replaceAllMatches('a.b a.b', const FindQuery('a.b'), r'$1'), (r'$1 $1', 2), reason: 'no regex: the text as typed');
    });

    testWidgets('the state follows the editor: current match, steps, replace, close', (tester) async {
      final ctrl = CodeController(text: 'one two one two one', lang: Lang.plain);
      final find = EditorFind()..attach(ctrl);
      addTearDown(() {
        find.dispose();
        ctrl.dispose();
      });
      ctrl.selection = const TextSelection.collapsed(offset: 5);
      find.open();
      find.query.text = 'one';
      expect(find.matches, hasLength(3));
      expect(find.current, 1, reason: 'the first match after the caret');
      expect(ctrl.highlights, hasLength(3));
      expect(ctrl.selection.start, 8);
      find.next();
      find.next();
      expect(find.current, 0, reason: 'wraps around');
      find.replacement.text = '1';
      find.replaceOne();
      expect(ctrl.text, '1 two one two one');
      expect(find.matches, hasLength(2));
      expect(find.replaceAll(), 2);
      expect(ctrl.text, '1 two 1 two 1');
      // Typing in the editor moves the matches along.
      find.query.text = 'two';
      ctrl.text = 'two ${ctrl.text}';
      expect(find.matches, hasLength(3));
      find.close();
      expect(ctrl.highlights, isEmpty);
      find.readOnly = true;
      find.replaceAll();
      expect(ctrl.text, 'two 1 two 1 two 1', reason: 'nothing is replaced in a read-only file');
    });
  });

  group('go to file', () {
    const files = [
      'internal/discount/repository.go',
      'internal/discount/bulk.go',
      'internal/report/go.mod',
      'cmd/server/main.go',
      'README.md',
      'kumo-ui/lib/editor/fileView.dart',
    ];

    List<String> rank(String q) => [for (final r in rankFiles(q, files)) r.$1];

    test('letters in order match; others do not', () {
      expect(fuzzyMatch('rpgo', 'internal/discount/repository.go'), isNotNull);
      expect(fuzzyMatch('zz', 'internal/discount/repository.go'), isNull);
      expect(fuzzyMatch('ogr', 'repository.go'), isNull, reason: 'order matters');
    });

    test('the file name counts most', () {
      expect(rank('repo').first, 'internal/discount/repository.go');
      expect(rank('main').first, 'cmd/server/main.go');
      expect(rank('readme').first, 'README.md', reason: 'case does not matter');
    });

    test('word starts and camelCase help', () {
      expect(rank('fv').first, 'kumo-ui/lib/editor/fileView.dart');
      expect(rank('disc bulk').first, 'internal/discount/bulk.go', reason: 'spaces are ignored');
    });

    test('marks the letters it matched', () {
      final (_, at) = fuzzyMatch('bulk', 'internal/discount/bulk.go')!;
      expect([for (final i in at) 'internal/discount/bulk.go'[i]].join(), 'bulk');
      expect(at.first, 'internal/discount/'.length, reason: 'in the name, not scattered in the folders');
    });

    test('no query: the open files first, then the rest', () {
      final r = rankFiles('', files, recent: ['cmd/server/main.go', 'gone.txt']);
      expect(r.first.$1, 'cmd/server/main.go');
      expect(r, hasLength(files.length), reason: 'files that are gone are left out');
    });
  });
}
