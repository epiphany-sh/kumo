import 'package:flutter/material.dart';

import '../../editor/syntax.dart';
import '../../widgets/open_link.dart';
import '../../theme/kumo_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/controls.dart';

/// The Markdown tickets bring (Jira, GitHub, notes), rendered the way the
/// approved design does: headings, paragraphs, lists, checklists, fenced
/// code with syntax colors, tables, images as placeholders, links,
/// @mentions and ticket keys that open in the panel.

// ---- Blocks ----

sealed class MdBlock {
  const MdBlock();
}

class MdHeading extends MdBlock {
  const MdHeading(this.level, this.text);
  final int level;
  final String text;
}

class MdParagraph extends MdBlock {
  const MdParagraph(this.text, {this.center = false});

  /// Inline Markdown; a hard line break is a `\n`.
  final String text;

  /// HTML asked for it (`<p align="center">`), as READMEs do for a logo
  /// and badges.
  final bool center;
}

class MdList extends MdBlock {
  const MdList(this.items, {this.ordered = false, this.start = 1, this.depths = const [], this.numbers = const []});
  final List<String> items;
  final bool ordered;
  final int start;

  /// How deep each item is nested (0: not nested); empty: all at 0.
  final List<int> depths;

  /// Each item's number as written (ordered lists); empty: from [start].
  final List<int> numbers;

  int depthOf(int i) => i < depths.length ? depths[i] : 0;
  int numberOf(int i) => i < numbers.length ? numbers[i] : start + i;
}

class MdChecklist extends MdBlock {
  const MdChecklist(this.items, {this.depths = const []});
  final List<(bool, String)> items;
  final List<int> depths;

  int depthOf(int i) => i < depths.length ? depths[i] : 0;
}

class MdCode extends MdBlock {
  const MdCode(this.lang, this.lines);

  /// The fence's language ("sql"), or empty.
  final String lang;
  final List<String> lines;
}

class MdTable extends MdBlock {
  const MdTable(this.head, this.rows);
  final List<String> head;
  final List<List<String>> rows;
}

class MdImage extends MdBlock {
  const MdImage(this.alt, this.src);
  final String alt;
  final String src;
}

class MdQuote extends MdBlock {
  const MdQuote(this.text, {this.alert});

  /// Its paragraphs, split by a blank line (`\n\n`).
  final String text;

  /// A GitHub alert (`> [!NOTE]`): NOTE, TIP, IMPORTANT, WARNING or
  /// CAUTION; null for a plain quote.
  final String? alert;
}

class MdRule extends MdBlock {
  const MdRule();
}

/// The `---` block of metadata a file may start with (YAML front matter).
class MdFrontMatter extends MdBlock {
  const MdFrontMatter(this.entries);

  /// `key: value` lines; a line without a key has an empty one.
  final List<(String, String)> entries;
}

final _heading = RegExp(r'^(#{1,6})\s+(.*?)\s*#*\s*$');
final _image = RegExp(r'^!\[([^\]]*)\]\(([^)\s]*)(?:\s+"[^"]*")?\)$');
final _check = RegExp(r'^\s*[-*+] \[( |x|X)\] (.*)$');
final _bullet = RegExp(r'^\s*[-*+] (?!\[[ xX]\] )(.*)$');
final _ordered = RegExp(r'^\s*(\d+)[.)] (.*)$');
final _anyItem = RegExp(r'^\s*([-*+]|\d+[.)]) ');
final _rule = RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$');
final _setext = RegExp(r'^\s*(=+|-+)\s*$');
final _blockStart = RegExp(r'^(#{1,6}\s|```|~~~|\||\s*[-*+] |\s*\d+[.)] |!\[|>|\s*<(?:[a-zA-Z]|!--))');
final _alert = RegExp(r'^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$', caseSensitive: false);
final _htmlStart = RegExp(r'^\s*<(?:[a-zA-Z][\w-]*(?:\s|/?>|$)|/[a-zA-Z]|!--)');

/// Columns of leading whitespace (a tab is 4).
int _indentOf(String l) {
  var n = 0;
  for (final ch in l.codeUnits) {
    if (ch == 0x20) {
      n++;
    } else if (ch == 0x09) {
      n += 4;
    } else {
      break;
    }
  }
  return n;
}

/// Splits [source] into blocks. Forgiving: whatever isn't recognized is a
/// paragraph.
List<MdBlock> parseMarkdown(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final blocks = <MdBlock>[];
  var n = 0;
  // Indents of the list items above, so a nested list is one level deeper
  // whatever its own indent (2, 3 or 4 spaces) and wherever it starts.
  final indents = <int>[];
  int depthAt(int indent) {
    while (indents.isNotEmpty && indents.last > indent) {
      indents.removeLast();
    }
    if (indents.isEmpty || indents.last < indent) indents.add(indent);
    return indents.length - 1;
  }

  void add(MdBlock b) {
    if (b is! MdList && b is! MdChecklist) indents.clear();
    blocks.add(b);
  }

  // Front matter: only on the very first line.
  if (lines.isNotEmpty && lines.first.trim() == '---') {
    final close = lines.indexWhere((l) => l.trim() == '---' || l.trim() == '...', 1);
    if (close > 0) {
      final entries = <(String, String)>[];
      for (final l in lines.sublist(1, close)) {
        if (l.trim().isEmpty) continue;
        final m = RegExp(r'^([\w.-]+):\s?(.*)$').firstMatch(l);
        entries.add(m == null ? ('', l.trim()) : (m.group(1)!, m.group(2)!.trim()));
      }
      add(MdFrontMatter(entries));
      n = close + 1;
    }
  }

  while (n < lines.length) {
    final l = lines[n];
    if (l.trim().isEmpty) {
      n++;
      continue;
    }
    final t = l.trimLeft();
    if (t.startsWith('```') || t.startsWith('~~~')) {
      final fence = t.substring(0, 3);
      final lang = t.substring(3).trim();
      final buf = <String>[];
      n++;
      while (n < lines.length && !lines[n].trimLeft().startsWith(fence)) {
        buf.add(lines[n++]);
      }
      n++;
      add(MdCode(lang, buf));
      continue;
    }
    if (_rule.hasMatch(l) && !_check.hasMatch(l)) {
      add(const MdRule());
      n++;
      continue;
    }
    var m = _heading.firstMatch(l);
    if (m != null) {
      add(MdHeading(m.group(1)!.length, m.group(2)!));
      n++;
      continue;
    }
    m = _image.firstMatch(l.trim());
    if (m != null) {
      add(MdImage(m.group(1)!, m.group(2)!));
      n++;
      continue;
    }
    if (_htmlStart.hasMatch(l)) {
      if (t.startsWith('<!--')) {
        // A comment: skipped whole, however many lines it takes.
        while (n < lines.length && !lines[n].contains('-->')) {
          n++;
        }
        n++;
        continue;
      }
      final buf = <String>[];
      while (n < lines.length && lines[n].trim().isNotEmpty) {
        buf.add(lines[n++]);
      }
      _htmlBlocks(buf.join('\n')).forEach(add);
      continue;
    }
    if (t.startsWith('|')) {
      final rows = <List<String>>[];
      while (n < lines.length && lines[n].trimLeft().startsWith('|')) {
        final cells = lines[n].trim().replaceAll(RegExp(r'^\||\|$'), '').split('|').map((x) => x.trim()).toList();
        if (!RegExp(r'^:?-+:?$').hasMatch(cells.first)) rows.add(cells);
        n++;
      }
      if (rows.isNotEmpty) add(MdTable(rows.first, rows.skip(1).toList()));
      continue;
    }
    if (t.startsWith('>')) {
      final buf = <String>[];
      while (n < lines.length && lines[n].trimLeft().startsWith('>')) {
        buf.add(lines[n++].trimLeft().substring(1).trim());
      }
      final alert = buf.isEmpty ? null : _alert.firstMatch(buf.first)?.group(1)?.toUpperCase();
      if (alert != null) buf.removeAt(0);
      // A blank quoted line splits paragraphs.
      final paras = <String>[];
      var cur = <String>[];
      for (final q in buf) {
        if (q.isEmpty) {
          if (cur.isNotEmpty) paras.add(cur.join(' '));
          cur = [];
        } else {
          cur.add(q);
        }
      }
      if (cur.isNotEmpty) paras.add(cur.join(' '));
      add(MdQuote(paras.join('\n\n'), alert: alert));
      continue;
    }
    if (_check.hasMatch(l)) {
      final items = <(bool, String)>[];
      final depths = <int>[];
      final base = _indentOf(l);
      while (n < lines.length) {
        final c = _check.firstMatch(lines[n]);
        if (c != null) {
          depths.add(depthAt(_indentOf(lines[n++])));
          items.add((c.group(1)!.toLowerCase() == 'x', c.group(2)!));
        } else if (_continues(lines[n], base)) {
          final (done, text) = items.removeLast();
          items.add((done, '$text ${lines[n++].trim()}'));
        } else {
          break;
        }
      }
      add(MdChecklist(items, depths: depths));
      continue;
    }
    final om = _ordered.firstMatch(l);
    if (om != null || _bullet.hasMatch(l)) {
      final ordered = om != null;
      final rx = ordered ? _ordered : _bullet;
      final items = <String>[];
      final depths = <int>[];
      final numbers = <int>[];
      final base = _indentOf(l);
      while (n < lines.length) {
        final c = rx.firstMatch(lines[n]);
        if (c != null) {
          depths.add(depthAt(_indentOf(lines[n++])));
          items.add(ordered ? c.group(2)! : c.group(1)!);
          if (ordered) numbers.add(int.parse(c.group(1)!));
        } else if (_continues(lines[n], base)) {
          items.add('${items.removeLast()} ${lines[n++].trim()}');
        } else {
          break;
        }
      }
      add(MdList(items, ordered: ordered, start: ordered ? int.parse(om.group(1)!) : 1, depths: depths, numbers: numbers));
      continue;
    }
    final buf = <String>[];
    while (n < lines.length && lines[n].trim().isNotEmpty && (buf.isEmpty || !_blockStart.hasMatch(lines[n]))) {
      // "Title" over "=====" or "-----" is a heading (setext).
      if (buf.isNotEmpty && _setext.hasMatch(lines[n])) break;
      buf.add(lines[n++]);
    }
    if (n < lines.length && buf.isNotEmpty && _setext.hasMatch(lines[n])) {
      final level = lines[n].trim().startsWith('=') ? 1 : 2;
      n++;
      add(MdHeading(level, buf.map((x) => x.trim()).join(' ')));
      continue;
    }
    add(MdParagraph(_joinLines(buf)));
  }
  return blocks;
}

/// A line that carries on the list item above it: indented past the
/// list's marker and not an item itself.
bool _continues(String line, int base) => line.trim().isNotEmpty && _indentOf(line) >= base + 2 && !_anyItem.hasMatch(line) && !line.trimLeft().startsWith('```');

/// A paragraph's lines in one: a line ending in two spaces or a backslash
/// breaks there.
String _joinLines(List<String> lines) {
  final out = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final hard = raw.endsWith('  ') || raw.trimRight().endsWith('\\');
    var text = raw.trim();
    if (hard && text.endsWith('\\')) text = text.substring(0, text.length - 1).trimRight();
    out.write(text);
    if (i < lines.length - 1) out.write(hard ? '\n' : ' ');
  }
  return out.toString();
}

/// An attribute of an HTML [tag] ("src", "href"), quoted or not; empty if
/// it has none.
String _attr(String tag, String name) {
  final m = RegExp('$name\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\'|([^\\s>]+))', caseSensitive: false).firstMatch(tag);
  return m == null ? '' : (m.group(1) ?? m.group(2) ?? m.group(3) ?? '');
}

/// HTML as inline Markdown: images (linked or not), links, bold, italics,
/// code and line breaks; other tags go and their text stays.
String _htmlInline(String html) {
  var s = html.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  s = s.replaceAllMapped(RegExp(r'<img\b[^>]*>', caseSensitive: false), (m) => '![${_attr(m[0]!, 'alt')}](${_attr(m[0]!, 'src')})');
  s = s.replaceAllMapped(RegExp(r'<a\b([^>]*)>(.*?)</a>', caseSensitive: false, dotAll: true), (m) {
    final href = _attr(m[1]!, 'href');
    final body = m[2]!.trim();
    return href.isEmpty || body.isEmpty ? body : '[$body]($href)';
  });
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</?(?:b|strong)>', caseSensitive: false), '**');
  s = s.replaceAll(RegExp(r'</?(?:i|em)>', caseSensitive: false), '_');
  s = s.replaceAll(RegExp(r'</?code>', caseSensitive: false), '`');
  s = s.replaceAll(RegExp(r'</?[a-zA-Z][^>]*>'), ' ');
  s = s.replaceAll('&nbsp;', ' ').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&amp;', '&');
  return [for (final l in s.split('\n')) l.replaceAll(RegExp(r'[ \t]+'), ' ').trim()].where((l) => l.isNotEmpty).join('\n');
}

/// The HTML block READMEs open with (a centered logo, badges, a title),
/// as Markdown blocks.
List<MdBlock> _htmlBlocks(String html) {
  final out = <MdBlock>[];
  final center = RegExp('align\\s*=\\s*["\']?center', caseSensitive: false).hasMatch(html);
  var rest = html;
  for (final m in RegExp(r'<h([1-6])\b[^>]*>(.*?)</h\1>', caseSensitive: false, dotAll: true).allMatches(html)) {
    final at = rest.indexOf(m[0]!);
    final before = _htmlInline(rest.substring(0, at));
    if (before.isNotEmpty) out.add(MdParagraph(before, center: center));
    final text = _htmlInline(m[2]!);
    if (text.isNotEmpty) out.add(MdHeading(int.parse(m[1]!), text));
    rest = rest.substring(at + m[0]!.length);
  }
  final tail = _htmlInline(rest);
  if (tail.isNotEmpty) {
    final lone = _image.firstMatch(tail);
    out.add(lone != null && !center ? MdImage(lone.group(1)!, lone.group(2)!) : MdParagraph(tail, center: center));
  }
  return out;
}

/// The checklist items of [source] (acceptance criteria): (done, text).
List<(bool, String)> checklistOf(String source) => [
      for (final b in parseMarkdown(source))
        if (b is MdChecklist) ...b.items,
    ];

// ---- Inline ----

enum MdInline { text, bold, italic, strike, code, link, mention, key, image, imageLink }

/// A styled run: its kind, its text (an image's alt), its target (a link's
/// URL, an image's source) and, for a linked image, where it links.
typedef MdSpan = (MdInline kind, String text, String target, String href);

/// Splits a line into styled runs. [mentions] are names that may follow an
/// @ (so "@Ana Gómez" stays one mention); [keys] finds ticket keys
/// ("PRC-11300").
List<MdSpan> parseInline(String text, {Iterable<String> mentions = const [], bool keys = false, Set<String> keyProjects = const {}}) {
  final names = [for (final m in mentions) if (m.trim().isNotEmpty) RegExp.escape(m.trim())]..sort((a, b) => b.length.compareTo(a.length));
  final mention = names.isEmpty ? r'@[\p{L}\p{N}_][\p{L}\p{N}_.\-]*' : '@(?:${names.join('|')})(?![\\p{L}\\p{N}_])|@[\\p{L}\\p{N}_][\\p{L}\\p{N}_.\\-]*';
  // At one position the first that matches wins.
  final parts = <(String, MdInline)>[
    (r'`[^`]+`', MdInline.code),
    (r'\[!\[[^\]]*\]\([^)\s]+(?:\s+"[^"]*")?\)\]\([^)\s]+\)', MdInline.imageLink),
    (r'!\[[^\]]*\]\([^)\s]+(?:\s+"[^"]*")?\)', MdInline.image),
    (r'\*\*[^*]+\*\*', MdInline.bold),
    (r'__[^_]+__', MdInline.bold),
    (r'~~[^~]+~~', MdInline.strike),
    (r'\[[^\]]+\]\([^)\s]+\)', MdInline.link),
    (r'<https?://[^\s>]+>', MdInline.link),
    (r'https?://[^\s)<>]+[^\s).,;:!?<>]', MdInline.link),
    (r'(?<![\p{L}\p{N}_*])\*[^*\s](?:[^*]*[^*\s])?\*(?!\*)', MdInline.italic),
    (r'(?<![\p{L}\p{N}_])_[^_\s](?:[^_]*[^_\s])?_(?![\p{L}\p{N}_])', MdInline.italic),
    ('(?<![\\p{L}\\p{N}_])(?:$mention)', MdInline.mention),
    if (keys) (r'(?<![\w/#\-])[A-Z][A-Z0-9]{1,9}-\d+(?![\w\-])', MdInline.key),
  ];
  final re = RegExp(parts.map((p) => '(${p.$1})').join('|'), unicode: true);
  final image = RegExp(r'!\[([^\]]*)\]\(([^)\s]+)');
  final out = <MdSpan>[];
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) out.add((MdInline.text, text.substring(last, m.start), '', ''));
    final s = m.group(0)!;
    var kind = MdInline.text;
    for (var g = 0; g < parts.length; g++) {
      if (m.group(g + 1) != null) {
        kind = parts[g].$2;
        break;
      }
    }
    switch (kind) {
      case MdInline.code:
        out.add((MdInline.code, s.substring(1, s.length - 1), '', ''));
      case MdInline.bold || MdInline.strike:
        out.add((kind, s.substring(2, s.length - 2), '', ''));
      case MdInline.italic:
        out.add((MdInline.italic, s.substring(1, s.length - 1), '', ''));
      case MdInline.image:
        final im = image.firstMatch(s)!;
        out.add((MdInline.image, im.group(1)!, im.group(2)!, ''));
      case MdInline.imageLink:
        final im = image.firstMatch(s)!;
        final href = RegExp(r'\]\(([^)\s]+)\)$').firstMatch(s)!.group(1)!;
        out.add((MdInline.imageLink, im.group(1)!, im.group(2)!, href));
      case MdInline.link:
        if (s.startsWith('<')) {
          final url = s.substring(1, s.length - 1);
          out.add((MdInline.link, url, url, ''));
        } else if (s.startsWith('[')) {
          final lm = RegExp(r'^\[([^\]]+)\]\(([^)\s]+)\)$').firstMatch(s)!;
          out.add((MdInline.link, lm.group(1)!, lm.group(2)!, ''));
        } else {
          out.add((MdInline.link, s, s, ''));
        }
      case MdInline.mention:
        out.add((MdInline.mention, s, s.substring(1), ''));
      case MdInline.key:
        out.add(_isKey(s, keyProjects) ? (MdInline.key, s, s, '') : (MdInline.text, s, '', ''));
      case MdInline.text:
        out.add((MdInline.text, s, '', ''));
    }
    last = m.end;
  }
  if (last < text.length) out.add((MdInline.text, text.substring(last), '', ''));
  return out;
}

/// Abbreviations that look like keys ("UTF-8", "SHA-256").
const _notKeys = {'UTF', 'ISO', 'SHA', 'RFC', 'CVE', 'MD', 'TLS', 'SSL', 'HTTP', 'AES', 'RSA', 'IPV', 'ES', 'GPT', 'COVID', 'ARM', 'X', 'TCP', 'UDP', 'PEP'};

/// A ticket key of [projects] ("PRC" for "PRC-11300"); any but the usual
/// abbreviations when there are none.
bool _isKey(String s, Set<String> projects) {
  final project = s.substring(0, s.lastIndexOf('-'));
  return projects.isEmpty ? !_notKeys.contains(project) : projects.contains(project);
}

/// How Markdown reads in the ticket.
@immutable
class MdStyle {
  const MdStyle({this.onOpenKey, this.mentions = const [], this.keyProjects = const {}, this.size = 13, this.onOpenLink, this.image});

  /// Ticket keys become links that call this (with the key); null leaves
  /// them as text.
  final ValueChanged<String>? onOpenKey;

  /// People's names, so "@Ana Gómez" reads as one mention.
  final List<String> mentions;

  /// The projects whose keys link ("PRC"); empty: any key-like word.
  final Set<String> keyProjects;
  final double size;

  /// Called first when a link is clicked; true when it handled it (a file
  /// of the worktree, a heading), false to open it in the browser.
  final bool Function(String target)? onOpenLink;

  /// Draws an image (alt, source); null shows its alt text.
  final Widget Function(String alt, String src)? image;
}

/// One line of Markdown, inline only (list items, table cells, criteria).
class MdText extends StatelessWidget {
  const MdText(this.text, {super.key, required this.style, this.base});
  final String text;
  final MdStyle style;
  final TextStyle? base;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final base = this.base ?? sans(style.size, color: c.text, height: 1.55);
    return Text.rich(TextSpan(style: base, children: inlineSpans(context, text, style, base)));
  }
}

List<InlineSpan> inlineSpans(BuildContext context, String text, MdStyle style, TextStyle base) {
  final c = context.c;
  final size = base.fontSize ?? style.size;
  final spans = <InlineSpan>[];
  void open(String target) {
    if (style.onOpenLink?.call(target) ?? false) return;
    openDocumentLink(context, target);
  }

  InlineSpan link(String t, String target) => WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: _InlineLink(text: t, tooltip: target, style: base.copyWith(color: c.acc, decoration: TextDecoration.underline, decorationColor: c.acc), onTap: () => open(target)),
      );

  for (final (kind, t, target, href) in parseInline(text, mentions: style.mentions, keys: style.onOpenKey != null, keyProjects: style.keyProjects)) {
    switch (kind) {
      case MdInline.text:
        spans.add(TextSpan(text: t));
      case MdInline.bold:
        spans.add(TextSpan(text: t, style: const TextStyle(fontWeight: FontWeight.w600)));
      case MdInline.italic:
        spans.add(TextSpan(text: t, style: const TextStyle(fontStyle: FontStyle.italic)));
      case MdInline.strike:
        spans.add(TextSpan(text: t, style: TextStyle(color: c.text2, decoration: TextDecoration.lineThrough, decorationColor: c.text2, decorationThickness: 1.6)));
      case MdInline.image || MdInline.imageLink:
        final draw = style.image;
        if (draw == null) {
          // No pictures here: what it shows, linked when it links.
          final label = t.isEmpty ? target.split('/').last : t;
          spans.add(kind == MdInline.imageLink ? link(label, href) : TextSpan(text: label, style: TextStyle(color: c.text3)));
        } else {
          final picture = draw(t, target);
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: kind == MdInline.imageLink ? _ImageLink(href: href, onTap: () => open(href), child: picture) : picture,
          ));
        }
      case MdInline.code:
        spans.add(TextSpan(
          // Thin spaces for room, word joiners so a line never breaks
          // between the code and the punctuation after it.
          text: '\u2060\u2009$t\u202F\u2060',
          style: mono(size - 1.5, color: c.text, height: base.height ?? 1.55).copyWith(background: Paint()..color = c.tile),
        ));
      case MdInline.mention:
        spans.add(TextSpan(
          text: '\u2009${t.replaceAll(' ', '\u00A0')}\u2009',
          semanticsLabel: 'Mention $t',
          style: TextStyle(color: c.acc, fontWeight: FontWeight.w500, background: Paint()..color = c.accSoft),
        ));
      case MdInline.link:
        spans.add(link(t, target));
      case MdInline.key:
        final open = style.onOpenKey;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _InlineLink(
            text: t,
            tooltip: 'Open $t (back returns here)',
            style: mono(size - 1.5, color: c.acc, height: base.height ?? 1.55, decoration: TextDecoration.underline).copyWith(decorationColor: c.acc),
            onTap: open == null ? null : () => open(target),
          ),
        ));
    }
  }
  return spans;
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({required this.text, required this.tooltip, required this.style, this.onTap});
  final String text;
  final String tooltip;
  final TextStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      tooltip: tooltip,
      semanticLabel: text,
      builder: (context, hover, focus) => Container(
        decoration: BoxDecoration(
          color: hover ? c.accSoft : null,
          borderRadius: BorderRadius.circular(3),
          border: focus ? Border.all(color: c.acc, width: 1.5) : null,
        ),
        child: Text(text, style: style),
      ),
    );
  }
}

/// An image that is a link (a README's badges): a hand on hover.
class _ImageLink extends StatelessWidget {
  const _ImageLink({required this.href, required this.onTap, required this.child});
  final String href;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: href,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: onTap, child: child)),
      );
}

// ---- Block widgets ----

/// A whole Markdown document.
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.source, {super.key, this.style = const MdStyle()});
  final String source;
  final MdStyle style;

  @override
  Widget build(BuildContext context) {
    final blocks = parseMarkdown(source);
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (i > 0) children.add(SizedBox(height: b is MdHeading ? 14 : 10));
      children.add(MdBlockView(b, style: style));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children);
  }
}

class MdBlockView extends StatelessWidget {
  const MdBlockView(this.block, {super.key, required this.style});
  final MdBlock block;
  final MdStyle style;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final body = sans(style.size, color: c.text, height: 1.55);
    final b = block;
    return switch (b) {
      MdHeading() => Semantics(
          header: true,
          child: MdText(b.text,
              style: style,
              base: sans(switch (b.level) { 1 => style.size + 4, 2 => style.size + 2, _ => style.size + 0.5 }, weight: FontWeight.w600, color: c.text, height: 1.35, letterSpacing: b.level <= 2 ? -0.2 : null)),
        ),
      MdParagraph() => b.center ? Center(child: MdText(b.text, style: style, base: body)) : MdText(b.text, style: style, base: body),
      MdQuote() => Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: c.divider, width: 3))),
          child: MdText(b.alert == null ? b.text : '**${b.alert![0]}${b.alert!.substring(1).toLowerCase()}:** ${b.text}', style: style, base: body.copyWith(color: c.text2)),
        ),
      MdFrontMatter() => CodeBlockView(MdCode('yaml', [for (final (k, v) in b.entries) k.isEmpty ? v : '$k: $v'])),
      MdRule() => Divider(height: 1, thickness: 1, color: c.divider),
      MdList() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, item) in b.items.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 4, left: 18.0 * b.depthOf(i)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: b.ordered ? 22 : 16,
                  child: Text(b.ordered ? '${b.numberOf(i)}.' : (b.depthOf(i).isOdd ? '◦' : '•'), textAlign: b.ordered ? TextAlign.right : TextAlign.center, style: body.copyWith(color: c.text2)),
                ),
                const SizedBox(width: 6),
                Expanded(child: MdText(item, style: style, base: body)),
              ]),
            ),
        ]),
      MdChecklist() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, (done, item)) in b.items.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6, left: 18.0 * b.depthOf(i)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 2.5), child: CheckMark(done: done)),
                const SizedBox(width: 9),
                Expanded(child: MdText(item, style: style, base: body)),
              ]),
            ),
        ]),
      MdCode() => CodeBlockView(b),
      MdTable() => _TableView(b, style: style),
      MdImage() => _ImagePlaceholder(b),
    };
  }
}

/// A read-only checkbox: done or not (the label says which).
class CheckMark extends StatelessWidget {
  const CheckMark({super.key, required this.done, this.size = 16});
  final bool done;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: done ? 'Done' : 'Not done',
      child: Tooltip(
        message: done ? 'Done' : 'Not done',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: done ? c.accFill : null,
            borderRadius: BorderRadius.circular(4.5),
            border: Border.all(color: done ? c.accFill : c.text3, width: 1.4),
          ),
          child: done ? Icon(Icons.check_rounded, size: size * 0.75, color: c.accText) : null,
        ),
      ),
    );
  }
}

const _fenceExt = {
  'rust': 'rs',
  'python': 'py',
  'typescript': 'ts',
  'javascript': 'js',
  'shell': 'sh',
  'bash': 'sh',
  'zsh': 'sh',
  'console': 'sh',
  'golang': 'go',
  'kotlin': 'kt',
  'yml': 'yaml',
  'markdown': 'md',
  'c++': 'cpp',
  'protobuf': 'proto',
};

/// The editor's language for a fence tag ("sql", "go", "bash").
Lang fenceLang(String tag) {
  final t = tag.trim().toLowerCase();
  if (t.isEmpty) return Lang.plain;
  return langOf('snippet.${_fenceExt[t] ?? t}').lang;
}

/// How a syntax token reads, the editor's way.
TextStyle tokenStyle(KumoPalette p, Tok k) => switch (k) {
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

/// A fenced code block: its language on top, colored like the editor,
/// scrolling sideways when a line is long.
class CodeBlockView extends StatelessWidget {
  const CodeBlockView(this.code, {super.key});
  final MdCode code;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lang = fenceLang(code.lang);
    final spans = <InlineSpan>[];
    for (var i = 0; i < code.lines.length; i++) {
      for (final (t, k) in Syntax.line(lang, code.lines[i])) {
        spans.add(TextSpan(text: t, style: tokenStyle(c, k)));
      }
      if (i < code.lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return Semantics(
      container: true,
      label: code.lang.isEmpty ? 'Code' : '${code.lang.toUpperCase()} code',
      child: Container(
        decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.divider)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (code.lang.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(code.lang.toUpperCase(), style: microLabel(c).copyWith(fontSize: 10)),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Text.rich(TextSpan(style: mono(12, color: c.text, height: 1.6), children: spans), softWrap: false),
          ),
        ]),
      ),
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView(this.table, {required this.style});
  final MdTable table;
  final MdStyle style;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final width = [table.head.length, for (final r in table.rows) r.length].reduce((a, b) => a > b ? a : b);
    List<String> padded(List<String> r) => [...r, for (var i = r.length; i < width; i++) ''];
    Widget cell(String t, {bool head = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: MdText(t, style: style, base: sans(12.5, weight: head ? FontWeight.w600 : FontWeight.w400, color: head ? c.text2 : c.text, height: 1.4)),
        );
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: c.divider)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder(horizontalInside: BorderSide(color: c.divider)),
          children: [
            TableRow(decoration: BoxDecoration(color: c.tile), children: [for (final h in padded(table.head)) cell(h, head: true)]),
            for (final r in table.rows) TableRow(children: [for (final t in padded(r)) cell(t)]),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder(this.image);
  final MdImage image;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final name = image.src.split('/').last;
    return Semantics(
      image: true,
      label: 'Image: ${image.alt.isEmpty ? name : image.alt}',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 112,
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.divider)),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.image_outlined, size: 22, color: c.text3),
              const SizedBox(height: 6),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text2)),
            ]),
          ),
          if (image.alt.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(image.alt, style: sans(11.5, color: c.text3)),
          ],
        ]),
      ),
    );
  }
}
