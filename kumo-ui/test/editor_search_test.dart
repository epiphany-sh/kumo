import 'dart:math';

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
      final r = findMatches('ana@platform bo@ops', q).matches;
      final (one, end) = replaceMatch('ana@platform bo@ops', r.first, q, r'$2/$1');
      expect(one, 'platform/ana bo@ops');
      expect(end, 'platform/ana'.length);
      expect(replaceAllMatches('ana@platform bo@ops', q, r'$2/$1 ($&) $$'), ('platform/ana (ana@platform) \$ ops/bo (bo@ops) \$', 2));
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

  group('ranking as the query is typed', () {
    // Paths with shared letters, so short queries match many and longer
    // ones narrow them.
    final random = Random(7);
    const parts = ['src', 'lib', 'internal', 'discount', 'handler', 'repo', 'report', 'go', 'main', 'fileView', 'bulk_api', 'x-y', 'README'];
    final files = {
      for (var i = 0; i < 600; i++) [for (var k = 0; k < 1 + random.nextInt(4); k++) parts[random.nextInt(parts.length)]].join('/') + (random.nextBool() ? '.go' : '.dart'),
    }.toList();

    /// The ranking as it was: every path scored, all of them sorted.
    List<(String, List<int>)> reference(String q, int limit) {
      final scored = <(int, String, List<int>)>[];
      for (final f in files) {
        final m = fuzzyMatch(q, f);
        if (m != null) scored.add((m.$1, f, m.$2));
      }
      scored.sort((a, b) {
        final c = b.$1.compareTo(a.$1);
        if (c != 0) return c;
        final l = a.$2.length.compareTo(b.$2.length);
        return l != 0 ? l : a.$2.compareTo(b.$2);
      });
      return [for (final s in scored.take(limit)) (s.$2, s.$3)];
    }

    test('typing, erasing and pasting rank as a full sort does', () {
      const letters = 'srcdiagohlnmepbtuvRE/ _.';
      final index = FileIndex(files);
      var q = '';
      for (var step = 0; step < 400; step++) {
        final r = random.nextInt(10);
        if (r < 6) {
          q += letters[random.nextInt(letters.length)];
        } else if (r < 8 && q.isNotEmpty) {
          q = q.substring(0, q.length - 1);
        } else if (r < 9) {
          q = parts[random.nextInt(parts.length)].substring(0, 2);
        } else {
          q = '';
        }
        final found = index.rank(q, limit: 25);
        if (q.trim().isEmpty) continue;
        expect([for (final (f, at) in found.top) '$f $at'], [for (final (f, at) in reference(q, 25)) '$f $at'], reason: 'query "$q"');
        expect(found.total, reference(q, files.length).length, reason: 'query "$q"');
      }
    });

    test('keeps the best few, best first', () {
      final best = TopK<int>(3, (a, b) => b.compareTo(a));
      for (final n in [5, 1, 9, 7, 3, 9, 2, 8]) {
        best.add(n);
      }
      expect(best.sorted(), [9, 9, 8]);
    });

    test('marks runs of matched letters, not each letter', () {
      const plain = TextStyle(), strong = TextStyle(fontWeight: FontWeight.w700);
      final spans = markedSpans('repository.go', {0, 1, 2, 11, 12}, plain, strong);
      expect([for (final s in spans) s.text], ['rep', 'ository.', 'go']);
      expect([for (final s in spans) s.style], [strong, plain, strong]);
      expect([for (final s in markedSpans('ab/cd', {3}, plain, strong, offset: 3, from: 0)) s.text], ['a', 'b/cd']);
    });
  });
}
