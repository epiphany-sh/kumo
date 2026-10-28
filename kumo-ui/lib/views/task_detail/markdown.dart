import 'package:flutter/material.dart';

import '../../editor/syntax.dart';
import '../../platform/open_url.dart';
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
  const MdParagraph(this.text);
  final String text;
}

class MdList extends MdBlock {
  const MdList(this.items, {this.ordered = false, this.start = 1});
  final List<String> items;
  final bool ordered;
  final int start;
}

class MdChecklist extends MdBlock {
  const MdChecklist(this.items);
  final List<(bool, String)> items;
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
  const MdQuote(this.text);
  final String text;
}

class MdRule extends MdBlock {
  const MdRule();
}

final _heading = RegExp(r'^(#{1,6})\s+(.*?)\s*#*\s*$');
final _image = RegExp(r'^!\[([^\]]*)\]\(([^)]*)\)$');
final _check = RegExp(r'^\s*[-*+] \[( |x|X)\] (.*)$');
final _bullet = RegExp(r'^\s*[-*+] (?!\[[ xX]\] )(.*)$');
final _ordered = RegExp(r'^\s*(\d+)[.)] (.*)$');
final _rule = RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$');
final _blockStart = RegExp(r'^(#{1,6}\s|```|~~~|\||\s*[-*+] |\s*\d+[.)] |!\[|>)');

/// Splits [source] into blocks. Forgiving: whatever isn't recognized is a
/// paragraph.
List<MdBlock> parseMarkdown(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final blocks = <MdBlock>[];
  var n = 0;
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
      blocks.add(MdCode(lang, buf));
      continue;
    }
    if (_rule.hasMatch(l) && !_check.hasMatch(l)) {
      blocks.add(const MdRule());
      n++;
      continue;
    }
    var m = _heading.firstMatch(l);
    if (m != null) {
      blocks.add(MdHeading(m.group(1)!.length, m.group(2)!));
      n++;
      continue;
    }
    m = _image.firstMatch(l.trim());
    if (m != null) {
      blocks.add(MdImage(m.group(1)!, m.group(2)!));
      n++;
      continue;
    }
    if (t.startsWith('|')) {
      final rows = <List<String>>[];
      while (n < lines.length && lines[n].trimLeft().startsWith('|')) {
        final cells = lines[n].trim().replaceAll(RegExp(r'^\||\|$'), '').split('|').map((x) => x.trim()).toList();
        if (!RegExp(r'^:?-+:?$').hasMatch(cells.first)) rows.add(cells);
        n++;
      }
      if (rows.isNotEmpty) blocks.add(MdTable(rows.first, rows.skip(1).toList()));
      continue;
    }
    if (t.startsWith('>')) {
      final buf = <String>[];
      while (n < lines.length && lines[n].trimLeft().startsWith('>')) {
        buf.add(lines[n++].trimLeft().substring(1).trim());
      }
      blocks.add(MdQuote(buf.join(' ')));
      continue;
    }
    if (_check.hasMatch(l)) {
      final items = <(bool, String)>[];
      while (n < lines.length && _check.hasMatch(lines[n])) {
        final c = _check.firstMatch(lines[n++])!;
        items.add((c.group(1)!.toLowerCase() == 'x', c.group(2)!));
      }
      blocks.add(MdChecklist(items));
      continue;
    }
    final om = _ordered.firstMatch(l);
    if (om != null || _bullet.hasMatch(l)) {
      final ordered = om != null;
      final rx = ordered ? _ordered : _bullet;
      final items = <String>[];
      while (n < lines.length && rx.hasMatch(lines[n])) {
        final c = rx.firstMatch(lines[n++])!;
        items.add(ordered ? c.group(2)! : c.group(1)!);
      }
      blocks.add(MdList(items, ordered: ordered, start: ordered ? int.parse(om.group(1)!) : 1));
      continue;
    }
    final buf = <String>[];
    while (n < lines.length && lines[n].trim().isNotEmpty && (buf.isEmpty || !_blockStart.hasMatch(lines[n]))) {
      buf.add(lines[n++].trim());
    }
    blocks.add(MdParagraph(buf.join(' ')));
  }
  return blocks;
}

/// The checklist items of [source] (acceptance criteria): (done, text).
List<(bool, String)> checklistOf(String source) => [
      for (final b in parseMarkdown(source))
        if (b is MdChecklist) ...b.items,
    ];

// ---- Inline ----

enum MdInline { text, bold, italic, code, link, mention, key }

typedef MdSpan = (MdInline kind, String text, String target);

/// Splits a line into styled runs. [mentions] are names that may follow an
/// @ (so "@Ana Gómez" stays one mention); [keys] finds ticket keys
/// ("PRC-11300").
List<MdSpan> parseInline(String text, {Iterable<String> mentions = const [], bool keys = false, Set<String> keyProjects = const {}}) {
  final names = [for (final m in mentions) if (m.trim().isNotEmpty) RegExp.escape(m.trim())]..sort((a, b) => b.length.compareTo(a.length));
  final mention = names.isEmpty ? r'@[\p{L}\p{N}_][\p{L}\p{N}_.\-]*' : '@(?:${names.join('|')})(?![\\p{L}\\p{N}_])|@[\\p{L}\\p{N}_][\\p{L}\\p{N}_.\\-]*';
  final parts = <String>[
    r'`[^`]+`',
    r'\*\*[^*]+\*\*',
    r'__[^_]+__',
    r'\[[^\]]+\]\([^)\s]+\)',
    r'https?://[^\s)]+[^\s).,;:!?]',
    r'(?<![\p{L}\p{N}_*])\*[^*\s](?:[^*]*[^*\s])?\*(?!\*)',
    r'(?<![\p{L}\p{N}_])_[^_\s](?:[^_]*[^_\s])?_(?![\p{L}\p{N}_])',
    '(?<![\\p{L}\\p{N}_])(?:$mention)',
    if (keys) r'(?<![\w/#\-])[A-Z][A-Z0-9]{1,9}-\d+(?![\w\-])',
  ];
  final re = RegExp(parts.map((p) => '($p)').join('|'), unicode: true);
  final out = <MdSpan>[];
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) out.add((MdInline.text, text.substring(last, m.start), ''));
    final s = m.group(0)!;
    if (m.group(1) != null) {
      out.add((MdInline.code, s.substring(1, s.length - 1), ''));
    } else if (m.group(2) != null || m.group(3) != null) {
      out.add((MdInline.bold, s.substring(2, s.length - 2), ''));
    } else if (m.group(4) != null) {
      final lm = RegExp(r'^\[([^\]]+)\]\(([^)\s]+)\)$').firstMatch(s)!;
      out.add((MdInline.link, lm.group(1)!, lm.group(2)!));
    } else if (m.group(5) != null) {
      out.add((MdInline.link, s, s));
    } else if (m.group(6) != null || m.group(7) != null) {
      out.add((MdInline.italic, s.substring(1, s.length - 1), ''));
    } else if (m.group(8) != null) {
      out.add((MdInline.mention, s, s.substring(1)));
    } else if (_isKey(s, keyProjects)) {
      out.add((MdInline.key, s, s));
    } else {
      out.add((MdInline.text, s, ''));
    }
    last = m.end;
  }
  if (last < text.length) out.add((MdInline.text, text.substring(last), ''));
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
  const MdStyle({this.onOpenKey, this.mentions = const [], this.keyProjects = const {}, this.size = 13});

  /// Ticket keys become links that call this (with the key); null leaves
  /// them as text.
  final ValueChanged<String>? onOpenKey;

  /// People's names, so "@Ana Gómez" reads as one mention.
  final List<String> mentions;

  /// The projects whose keys link ("PRC"); empty: any key-like word.
  final Set<String> keyProjects;
  final double size;
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
  for (final (kind, t, target) in parseInline(text, mentions: style.mentions, keys: style.onOpenKey != null, keyProjects: style.keyProjects)) {
    switch (kind) {
      case MdInline.text:
        spans.add(TextSpan(text: t));
      case MdInline.bold:
        spans.add(TextSpan(text: t, style: const TextStyle(fontWeight: FontWeight.w600)));
      case MdInline.italic:
        spans.add(TextSpan(text: t, style: const TextStyle(fontStyle: FontStyle.italic)));
      case MdInline.code:
        spans.add(TextSpan(
          text: '\u2009$t\u2009',
          style: mono(size - 1.5, color: c.text, height: base.height ?? 1.55).copyWith(background: Paint()..color = c.tile),
        ));
      case MdInline.mention:
        spans.add(TextSpan(
          text: '\u2009${t.replaceAll(' ', '\u00A0')}\u2009',
          semanticsLabel: 'Mention $t',
          style: TextStyle(color: c.acc, fontWeight: FontWeight.w500, background: Paint()..color = c.accSoft),
        ));
      case MdInline.link:
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _InlineLink(text: t, tooltip: target, style: base.copyWith(color: c.acc, decoration: TextDecoration.underline, decorationColor: c.acc), onTap: () => openUrl(target)),
        ));
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
      MdParagraph() => MdText(b.text, style: style, base: body),
      MdQuote() => Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: c.divider, width: 3))),
          child: MdText(b.text, style: style, base: body.copyWith(color: c.text2)),
        ),
      MdRule() => Divider(height: 1, thickness: 1, color: c.divider),
      MdList() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, item) in b.items.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: b.ordered ? 22 : 16,
                  child: Text(b.ordered ? '${b.start + i}.' : '•', textAlign: b.ordered ? TextAlign.right : TextAlign.center, style: body.copyWith(color: c.text2)),
                ),
                const SizedBox(width: 6),
                Expanded(child: MdText(item, style: style, base: body)),
              ]),
            ),
        ]),
      MdChecklist() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, (done, item)) in b.items.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
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

TextStyle _tokStyle(KumoPalette p, Tok k) => switch (k) {
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
        spans.add(TextSpan(text: t, style: _tokStyle(c, k)));
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
