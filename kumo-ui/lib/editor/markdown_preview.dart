import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../platform/open_url.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../views/task_detail/markdown.dart';
import 'syntax.dart';
import '../widgets/controls.dart';
import '../widgets/kicons.dart';

/// A Markdown file of the worktree read as a document: one column at a
/// reading width, headings with room above them, code with its colors and
/// a copy button, GitHub's alerts, tables, the README's images and badges.
/// Links to other files of the worktree open them; `#heading` links
/// scroll there. Everything selects and copies (⌘C).
class MarkdownPreview extends StatefulWidget {
  const MarkdownPreview({super.key, required this.source, required this.path, this.root = '', this.files = const [], this.onOpenFile, this.controller});

  /// The Markdown (the buffer, with edits not saved yet).
  final String source;

  /// The file's path in the worktree: relative links and images start
  /// from its folder.
  final String path;

  /// The worktree's folder on disk, for local images; empty: none load.
  final String root;

  /// The worktree's files: a link to one opens it.
  final List<String> files;
  final ValueChanged<String>? onOpenFile;
  final ScrollController? controller;

  /// The width text reads best at; wider windows get margins.
  static const readingWidth = 780.0;

  @override
  State<MarkdownPreview> createState() => _MarkdownPreviewState();
}

class _MarkdownPreviewState extends State<MarkdownPreview> {
  final _ownScroll = ScrollController();
  ScrollController get _scroll => widget.controller ?? _ownScroll;

  String? _parsedFrom;
  List<MdBlock> _blocks = const [];
  List<String?> _slugs = const [];
  final _anchors = <String, GlobalKey>{};

  List<String>? _filesFrom;
  Set<String> _fileSet = const {};

  @override
  void dispose() {
    _ownScroll.dispose();
    super.dispose();
  }

  void _parse() {
    if (_parsedFrom == widget.source) return;
    _parsedFrom = widget.source;
    _blocks = parseMarkdown(widget.source);
    final seen = <String, int>{};
    _slugs = [
      for (final b in _blocks)
        if (b is MdHeading) _uniqueSlug(headingSlug(b.text), seen) else null,
    ];
    _anchors.removeWhere((slug, _) => !_slugs.contains(slug));
  }

  static String _uniqueSlug(String slug, Map<String, int> seen) {
    final n = seen[slug] ?? 0;
    seen[slug] = n + 1;
    return n == 0 ? slug : '$slug-$n';
  }

  Set<String> get _files {
    if (!identical(widget.files, _filesFrom)) {
      _filesFrom = widget.files;
      _fileSet = widget.files.toSet();
    }
    return _fileSet;
  }

  /// A link was clicked: true when it was for here (a heading, a file of
  /// the worktree); false lets the browser have it.
  bool _openLink(String target) {
    if (target.startsWith('#')) {
      _scrollToAnchor(target.substring(1));
      return true;
    }
    if (RegExp(r'^[a-zA-Z][\w+.-]*:').hasMatch(target)) return false;
    final hash = target.indexOf('#');
    final path = resolveRelative(widget.path, target);
    if (path == null || path.isEmpty) return true;
    if (path == widget.path && hash >= 0) {
      _scrollToAnchor(target.substring(hash + 1));
      return true;
    }
    final files = _files;
    final open = widget.onOpenFile;
    final hit = files.contains(path) ? path : (files.contains('$path/README.md') ? '$path/README.md' : null);
    if (hit != null && open != null) open(hit);
    return true;
  }

  void _scrollToAnchor(String anchor) {
    final slug = Uri.decodeComponent(anchor).toLowerCase();
    final ctx = _anchors[slug]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic, alignment: 0.04);
  }

  /// Where a picture's source is: a URL, a file of the worktree on disk,
  /// or nowhere (shown as its name).
  Widget _picture(String alt, String src, {bool block = false}) {
    final c = context.c;
    Widget fallback() => _MissingImage(alt: alt, src: src, block: block);
    final svg = _isSvg(src);
    Widget img;
    if (src.startsWith('http://') || src.startsWith('https://')) {
      img = svg
          ? SvgPicture.network(src, semanticsLabel: alt, errorBuilder: (_, __, ___) => fallback(), placeholderBuilder: (_) => SizedBox(height: block ? 120 : 20, width: block ? null : 60))
          : Image.network(src, semanticLabel: alt, errorBuilder: (_, __, ___) => fallback(), frameBuilder: _fadeIn);
    } else {
      final rel = resolveRelative(widget.path, src);
      final root = widget.root;
      if (rel == null || root.isEmpty) return fallback();
      final file = File('$root${Platform.pathSeparator}${rel.replaceAll('/', Platform.pathSeparator)}');
      if (!file.existsSync()) return fallback();
      img = svg
          ? SvgPicture.file(file, semanticsLabel: alt, errorBuilder: (_, __, ___) => fallback())
          : Image.file(file, semanticLabel: alt, errorBuilder: (_, __, ___) => fallback(), frameBuilder: _fadeIn);
    }
    if (!block) return img;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(position: DecorationPosition.foreground, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: c.divider)), child: img),
    );
  }

  static Widget _fadeIn(BuildContext context, Widget child, int? frame, bool sync) =>
      sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 180), child: child);

  static bool _isSvg(String src) {
    final path = src.split('?').first.split('#').first.toLowerCase();
    return path.endsWith('.svg') || src.contains('shields.io/') || src.contains('badgen.net/') || src.contains('/badge.svg');
  }

  MdStyle get _mdStyle => MdStyle(size: _Type.body, onOpenLink: _openLink, image: (alt, src) => _picture(alt, src));

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    _parse();
    if (widget.source.trim().isEmpty) {
      return Center(child: Text('This file is empty. Switch to Edit to write it.', style: sans(13, color: c.text3)));
    }
    final style = _mdStyle;
    final children = <Widget>[];
    for (var i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      if (i > 0) children.add(SizedBox(height: _gap(_blocks[i - 1], b)));
      final slug = _slugs[i];
      final view = _block(context, b, style);
      children.add(slug == null ? view : KeyedSubtree(key: _anchors.putIfAbsent(slug, () => GlobalKey(debugLabel: slug)), child: view));
    }
    return LayoutBuilder(builder: (context, box) {
      final side = box.maxWidth >= 900 ? 56.0 : (box.maxWidth >= 600 ? 40.0 : 22.0);
      return Scrollbar(
        controller: _scroll,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(side, 34, side, 80),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: MarkdownPreview.readingWidth),
              child: SelectionArea(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ),
        ),
      );
    });
  }

  /// Room between two blocks: more above a heading the bigger it is, less
  /// under one (it belongs to what follows), little between the pieces of
  /// one nested list.
  static double _gap(MdBlock prev, MdBlock b) {
    if (b is MdHeading) return switch (b.level) { 1 => 36, 2 => 32, 3 => 26, _ => 22 };
    if (prev is MdHeading) return prev.level <= 2 ? 14 : 10;
    bool listy(MdBlock x) => x is MdList || x is MdChecklist;
    if (listy(prev) && listy(b)) return 6;
    return 16;
  }

  Widget _block(BuildContext context, MdBlock b, MdStyle style) {
    final c = context.c;
    final body = _Type.bodyStyle(c);
    return switch (b) {
      MdHeading() => _heading(context, b, style),
      MdParagraph() => _paragraph(context, b, style, body),
      MdList() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, item) in b.items.indexed)
            _ListRow(
              depth: b.depthOf(i),
              first: i == 0,
              marker: b.ordered
                  ? Text('${b.numberOf(i)}.', textAlign: TextAlign.right, style: body.copyWith(color: c.text2, fontFeatures: const [FontFeature.tabularFigures()]))
                  : _Bullet(depth: b.depthOf(i)),
              child: _rich(context, item, style, body),
            ),
        ]),
      MdChecklist() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, (done, item)) in b.items.indexed)
            _ListRow(
              depth: b.depthOf(i),
              first: i == 0,
              marker: Padding(
                padding: const EdgeInsets.only(top: (_Type.body * _Type.lineHeight - 15) / 2, right: 4),
                child: Align(alignment: Alignment.topRight, child: CheckMark(done: done, size: 15)),
              ),
              child: _rich(context, item, style, done ? body.copyWith(color: c.text2) : body),
            ),
        ]),
      MdQuote() => _Quote(quote: b, style: style),
      MdCode() => _CodeBlock(code: b),
      MdTable() => _Table(table: b, style: style),
      MdImage() => Align(alignment: Alignment.centerLeft, child: _picture(b.alt, b.src, block: true)),
      MdRule() => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Container(height: 1, color: c.divider)),
      MdFrontMatter() => _FrontMatter(matter: b),
    };
  }

  Widget _rich(BuildContext context, String text, MdStyle style, TextStyle base, {TextAlign align = TextAlign.start}) =>
      Text.rich(TextSpan(style: base, children: inlineSpans(context, text, style, base)), textAlign: align);

  Widget _heading(BuildContext context, MdHeading b, MdStyle style) {
    final c = context.c;
    final s = _Type.heading(c, b.level);
    final text = _rich(context, b.text, style, s);
    return Semantics(
      header: true,
      child: b.level <= 2
          ? Container(
              padding: EdgeInsets.only(bottom: b.level == 1 ? 10 : 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
              child: text,
            )
          : text,
    );
  }

  /// A paragraph; one made only of images (a README's badges, a row of
  /// screenshots) lays them out side by side.
  Widget _paragraph(BuildContext context, MdParagraph b, MdStyle style, TextStyle body) {
    final spans = parseInline(b.text);
    final onlyImages = spans.every((s) => s.$1 == MdInline.image || s.$1 == MdInline.imageLink || (s.$1 == MdInline.text && s.$2.trim().isEmpty)) && spans.any((s) => s.$1 != MdInline.text);
    if (!onlyImages) return _rich(context, b.text, style, body, align: b.center ? TextAlign.center : TextAlign.start);
    final pictures = <Widget>[
      for (final (kind, alt, src, href) in spans)
        if (kind == MdInline.image)
          _picture(alt, src, block: spans.length == 1)
        else if (kind == MdInline.imageLink)
          Tooltip(
            message: href,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  if (!_openLink(href)) openUrl(href);
                },
                child: _picture(alt, src),
              ),
            ),
          ),
    ];
    return Wrap(
      alignment: b.center ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: pictures,
    );
  }
}

/// The anchor GitHub gives a heading: lower case, punctuation gone, spaces
/// as hyphens ("Getting started!" → "getting-started").
String headingSlug(String heading) {
  var t = heading.replaceAllMapped(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!);
  t = t.replaceAll(RegExp(r'[`*_~]'), '').toLowerCase().trim();
  t = t.replaceAll(RegExp(r'[^\p{L}\p{N}\s-]', unicode: true), '');
  return t.replaceAll(RegExp(r'\s'), '-');
}

/// [target] (a link or image source in [fromFile]) as a path of the
/// worktree; null when it climbs out of it. A leading `/` is the
/// worktree's root; `#…` and `?…` are dropped.
String? resolveRelative(String fromFile, String target) {
  var t = target.split('#').first.split('?').first;
  try {
    t = Uri.decodeComponent(t);
  } on ArgumentError {
    // Not encoded: as it is.
  }
  final parts = t.startsWith('/') ? <String>[] : (fromFile.split('/')..removeLast());
  for (final seg in t.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (parts.isEmpty) return null;
      parts.removeLast();
    } else {
      parts.add(seg);
    }
  }
  return parts.join('/');
}

/// The preview's type scale.
abstract final class _Type {
  static const body = 14.5;
  static const lineHeight = 1.72;

  static TextStyle bodyStyle(KumoPalette c) => sans(body, color: c.text, height: lineHeight);

  static TextStyle heading(KumoPalette c, int level) {
    final text = c.text;
    return switch (level) {
      1 => sans(29, weight: FontWeight.w700, color: text, height: 1.22, letterSpacing: -0.7),
      2 => sans(21.5, weight: FontWeight.w600, color: text, height: 1.3, letterSpacing: -0.35),
      3 => sans(17.5, weight: FontWeight.w600, color: text, height: 1.35, letterSpacing: -0.15),
      4 => sans(15.5, weight: FontWeight.w600, color: text, height: 1.4),
      5 => sans(14.5, weight: FontWeight.w600, color: text, height: 1.4),
      _ => sans(13.5, weight: FontWeight.w600, color: c.text2, height: 1.4, letterSpacing: 0.2),
    };
  }
}

/// One item of a list: its marker in a gutter, nested ones further in.
class _ListRow extends StatelessWidget {
  const _ListRow({required this.depth, required this.first, required this.marker, required this.child});
  final int depth;
  final bool first;
  final Widget marker;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: 2 + 24.0 * depth, top: first ? 0 : 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 22, child: marker),
          const SizedBox(width: 8),
          Expanded(child: child),
        ]),
      );
}

/// A list's marker, drawn (no font has to have it): a dot, then a ring,
/// then a square, deeper in.
class _Bullet extends StatelessWidget {
  const _Bullet({required this.depth});
  final int depth;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final kind = depth % 3;
    return SizedBox(
      height: _Type.body * _Type.lineHeight,
      child: Center(
        child: Container(
          width: kind == 2 ? 5 : 6,
          height: kind == 2 ? 5 : 6,
          decoration: BoxDecoration(
            shape: kind == 2 ? BoxShape.rectangle : BoxShape.circle,
            color: kind == 1 ? null : c.text3,
            border: kind == 1 ? Border.all(color: c.text3, width: 1.3) : null,
          ),
        ),
      ),
    );
  }
}

/// A quote, or a GitHub alert (`> [!WARNING]`) with its color and icon.
class _Quote extends StatelessWidget {
  const _Quote({required this.quote, required this.style});
  final MdQuote quote;
  final MdStyle style;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final paras = quote.text.split('\n\n');
    final alert = quote.alert;
    final (Color color, Color soft, IconData icon, String label) = switch (alert) {
      'TIP' => (c.ok, c.okSoft, Icons.lightbulb_outline_rounded, 'Tip'),
      'IMPORTANT' => (c.purple, c.purple.withValues(alpha: 0.12), Icons.feedback_outlined, 'Important'),
      'WARNING' => (c.warn, c.warnSoft, Icons.warning_amber_rounded, 'Warning'),
      'CAUTION' => (c.err, c.errSoft, Icons.report_gmailerrorred_rounded, 'Caution'),
      'NOTE' => (c.acc, c.accSoft, Icons.info_outline_rounded, 'Note'),
      _ => (c.text3, Colors.transparent, KIcons.info, ''),
    };
    final body = _Type.bodyStyle(c).copyWith(color: alert == null ? c.text2 : c.text);
    final text = <Widget>[
      for (final (i, p) in paras.indexed) ...[
        if (i > 0) const SizedBox(height: 10),
        Text.rich(TextSpan(style: body, children: inlineSpans(context, p, style, body))),
      ],
    ];
    if (alert == null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: c.text3.withValues(alpha: c.text3.a * 0.5), width: 3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: text),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: sans(13.5, weight: FontWeight.w600, color: color)),
        ]),
        const SizedBox(height: 6),
        ...text,
      ]),
    );
  }
}

/// Fenced code: the editor's colors, its language in the corner and, on
/// hover, a button that copies it.
class _CodeBlock extends StatefulWidget {
  const _CodeBlock({required this.code});
  final MdCode code;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _hover = false;
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.code.lines.join('\n')));
    _reset?.cancel();
    setState(() => _copied = true);
    _reset = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final code = widget.code;
    final lang = fenceLang(code.lang);
    final spans = <InlineSpan>[];
    for (var i = 0; i < code.lines.length; i++) {
      for (final (t, k) in Syntax.line(lang, code.lines[i].replaceAll('\t', '    '))) {
        spans.add(TextSpan(text: t, style: tokenStyle(c, k)));
      }
      if (i < code.lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    final showCopy = _hover || _copied;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        container: true,
        label: code.lang.isEmpty ? 'Code' : '${code.lang.toUpperCase()} code',
        child: Container(
          decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.divider)),
          child: Stack(children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
              child: Text.rich(TextSpan(style: mono(12.5, color: c.text, height: 1.65), children: spans), softWrap: false),
            ),
            Positioned(
              top: 7,
              right: 8,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                child: showCopy
                    ? KButton(
                        key: const ValueKey('copy'),
                        label: _copied ? 'Copied' : 'Copy',
                        icon: _copied ? KIcons.check : KIcons.copy,
                        kind: KButtonKind.ghost,
                        height: 24,
                        fontSize: 11,
                        onTap: _copy,
                      )
                    : (code.lang.isEmpty
                        ? const SizedBox(key: ValueKey('none'), height: 24)
                        : Padding(
                            key: const ValueKey('lang'),
                            padding: const EdgeInsets.only(top: 5, right: 4),
                            child: Text(code.lang.toUpperCase(), style: microLabel(c).copyWith(fontSize: 10)),
                          )),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.table, required this.style});
  final MdTable table;
  final MdStyle style;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final width = [table.head.length, for (final r in table.rows) r.length].reduce((a, b) => a > b ? a : b);
    List<String> padded(List<String> r) => [...r, for (var i = r.length; i < width; i++) ''];
    Widget cell(String t, {bool head = false}) {
      final base = sans(13.5, weight: head ? FontWeight.w600 : FontWeight.w400, color: c.text, height: 1.5);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text.rich(TextSpan(style: base, children: inlineSpans(context, t, style, base))),
      );
    }

    final zebra = c.tile.withValues(alpha: c.tile.a * 0.5);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: c.divider)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder(horizontalInside: BorderSide(color: c.divider), verticalInside: BorderSide(color: c.divider)),
            children: [
              TableRow(decoration: BoxDecoration(color: c.tile), children: [for (final h in padded(table.head)) cell(h, head: true)]),
              for (final (i, r) in table.rows.indexed) TableRow(decoration: i.isOdd ? BoxDecoration(color: zebra) : null, children: [for (final t in padded(r)) cell(t)]),
            ],
          ),
        ),
      ),
    );
  }
}

/// A file's front matter, quietly: its keys and values.
class _FrontMatter extends StatelessWidget {
  const _FrontMatter({required this.matter});
  final MdFrontMatter matter;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('FRONT MATTER', style: microLabel(c).copyWith(fontSize: 10)),
        const SizedBox(height: 8),
        Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          columnWidths: const {1: FlexColumnWidth()},
          children: [
            for (final (k, v) in matter.entries)
              TableRow(children: [
                Padding(padding: const EdgeInsets.only(right: 16, bottom: 3), child: Text(k, style: mono(12, color: c.text3, height: 1.55))),
                Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(v, style: mono(12, color: c.text, height: 1.55))),
              ]),
          ],
        ),
      ]),
    );
  }
}

/// An image that can't be shown (not found, offline): its name in a chip.
class _MissingImage extends StatelessWidget {
  const _MissingImage({required this.alt, required this.src, required this.block});
  final String alt;
  final String src;
  final bool block;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final name = src.split('?').first.split('/').last;
    return Semantics(
      image: true,
      label: 'Image: ${alt.isEmpty ? name : alt}',
      child: ExcludeSemantics(
        child: Tooltip(
          message: src,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: block ? 10 : 3),
            decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(block ? 10 : 6), border: Border.all(color: c.divider)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.image_outlined, size: block ? 16 : 13, color: c.text3),
              const SizedBox(width: 6),
              Flexible(child: Text(alt.isEmpty ? name : alt, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(block ? 12.5 : 11.5, color: c.text2))),
            ]),
          ),
        ),
      ),
    );
  }
}
