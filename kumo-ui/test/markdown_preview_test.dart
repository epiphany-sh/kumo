import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/editor/markdown_preview.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';
import 'package:kumo_ui/views/task_detail/markdown.dart';

List<String> _kinds(String md) => [for (final b in parseMarkdown(md)) b.runtimeType.toString()];

Future<void> _pump(WidgetTester tester, String source, {ValueChanged<String>? onOpenFile, List<String> files = const []}) async {
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: Material(child: MarkdownPreview(source: source, path: 'docs/guide.md', files: files, onOpenFile: onOpenFile)),
    ),
  ));
  await tester.pump();
}

void main() {
  group('parser', () {
    test('nested lists keep their depth and numbers; wrapped items join', () {
      final blocks = parseMarkdown('1. one\n2. two\n   - a\n     wrapped\n   - b\n       - deep\n3. three');
      expect(_kinds('1. one\n2. two\n   - a\n   - b\n3. three'), ['MdList', 'MdList', 'MdList']);
      final outer = blocks[0] as MdList;
      final inner = blocks[1] as MdList;
      final last = blocks[2] as MdList;
      expect(outer.items, ['one', 'two']);
      expect(inner.items, ['a wrapped', 'b', 'deep']);
      expect([for (var i = 0; i < 3; i++) inner.depthOf(i)], [1, 1, 2]);
      expect(last.numberOf(0), 3, reason: 'numbered as written');
      expect(last.depthOf(0), 0);
    });

    test('setext headings, hard breaks, front matter', () {
      final b = parseMarkdown('---\ntitle: Guide\ntags: [a]\n---\nGuide\n=====\nSub\n---\nline one  \nline two\\\nthree');
      expect(b.map((x) => x.runtimeType.toString()), ['MdFrontMatter', 'MdHeading', 'MdHeading', 'MdParagraph']);
      expect((b[0] as MdFrontMatter).entries, [('title', 'Guide'), ('tags', '[a]')]);
      expect(((b[1] as MdHeading).level, (b[2] as MdHeading).level), (1, 2));
      expect((b[3] as MdParagraph).text, 'line one\nline two\nthree');
    });

    test('GitHub alerts and quotes with paragraphs', () {
      final q = parseMarkdown('> [!WARNING]\n> Careful.\n>\n> Really.').single as MdQuote;
      expect(q.alert, 'WARNING');
      expect(q.text, 'Careful.\n\nReally.');
      expect((parseMarkdown('> just a quote').single as MdQuote).alert, isNull);
    });

    test('the HTML READMEs open with: centered logo and badges, headings, comments', () {
      final b = parseMarkdown(
          '<!-- hidden\nnote -->\n<p align="center">\n  <img src="logo.png" alt="Logo" width="96">\n</p>\n<h1 align="center">Kumo</h1>\n\n<a href="https://ci"><img src="https://img.shields.io/badge/ci-ok-green"></a>');
      expect(b.map((x) => x.runtimeType.toString()), ['MdParagraph', 'MdHeading', 'MdParagraph']);
      expect((b[0] as MdParagraph).center, isTrue);
      expect((b[0] as MdParagraph).text, '![Logo](logo.png)');
      expect((b[1] as MdHeading).text, 'Kumo');
      expect((b[2] as MdParagraph).text, '[![](https://img.shields.io/badge/ci-ok-green)](https://ci)');
    });

    test('inline: strike, images, linked images, autolinks', () {
      final spans = parseInline('~~old~~ ![a](x.png) [![b](y.svg)](https://h) <https://k.dev>');
      expect([
        for (final s in spans)
          if (s.$1 != MdInline.text) (s.$1, s.$2, s.$3, s.$4)
      ], [
        (MdInline.strike, 'old', '', ''),
        (MdInline.image, 'a', 'x.png', ''),
        (MdInline.imageLink, 'b', 'y.svg', 'https://h'),
        (MdInline.link, 'https://k.dev', 'https://k.dev', ''),
      ]);
    });

    test('paths and anchors', () {
      expect(resolveRelative('docs/guide.md', '../README.md'), 'README.md');
      expect(resolveRelative('docs/guide.md', './img/a%20b.png?raw=1'), 'docs/img/a b.png');
      expect(resolveRelative('docs/guide.md', '/kumo.md#top'), 'kumo.md');
      expect(resolveRelative('guide.md', '../../out.md'), isNull, reason: 'outside the worktree');
      expect(headingSlug('Getting started — **fast**!'), 'getting-started--fast');
      expect(headingSlug('Run `make dev` [here](x)'), 'run-make-dev-here');
    });
  });

  group('preview', () {
    testWidgets('renders the document without Markdown syntax showing', (tester) async {
      await _pump(tester, '# Title\n\nSome **bold** and `code`.\n\n- [x] done\n\n| a | b |\n|---|---|\n| 1 | 2 |');
      expect(find.text('Title'), findsOneWidget);
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('|'), findsNothing);
      expect(find.byType(CheckMark), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      expect(find.byType(SelectionArea), findsOneWidget, reason: 'text selects and copies');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a link to another file of the worktree opens it', (tester) async {
      final opened = <String>[];
      await _pump(tester, 'See [the readme](../README.md) and [setup](setup/).', files: ['README.md', 'docs/setup/README.md'], onOpenFile: opened.add);
      await tester.tap(find.text('the readme'));
      await tester.tap(find.text('setup'));
      expect(opened, ['README.md', 'docs/setup/README.md'], reason: 'a folder opens its README');
    });

    testWidgets('a #heading link scrolls to it', (tester) async {
      final filler = List.generate(60, (i) => 'Paragraph $i of filler text.').join('\n\n');
      await _pump(tester, '[Jump](#the-end)\n\n$filler\n\n## The end\n\n$filler');
      final before = tester.getTopLeft(find.text('The end')).dy;
      expect(before, greaterThan(900), reason: 'below the fold');
      await tester.tap(find.text('Jump'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('The end')).dy, lessThan(200));
    });

    testWidgets('code blocks copy their code', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await _pump(tester, '```go\nfunc main() {}\n```');
      expect(find.text('GO'), findsOneWidget, reason: 'its language in the corner');
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(find.textContaining('func main')));
      await tester.pump();
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(copied, 'func main() {}');
      expect(find.text('Copied'), findsOneWidget);
      await gesture.removePointer();
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
