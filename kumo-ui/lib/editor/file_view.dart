import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/changes.dart';
import '../data/worktree_changes.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/kicons.dart';
import 'diff_colors.dart';
import 'syntax.dart';

/// A file tab of the Terminal view: the whole file with its changes inline
/// (or only the changed hunks), numbered old/new like `git diff`, with
/// previous / next change navigation.
class FileView extends StatefulWidget {
  const FileView({super.key, required this.path});
  final String path;

  @override
  State<FileView> createState() => _FileViewState();
}

class _FileViewState extends State<FileView> {
  static const _lineH = 20.0;
  static const _foldH = 30.0;
  static const _gutter = 3.0 + 34 + 42 + 16;

  bool _changesOnly = false;
  int _hunk = 0;

  /// The file with its changed lines, loaded from the worktree's changes.
  ChangedFile? _file;
  Object? _loadedFor;

  /// (Re)loads when the worktree, its status or the path changes.
  void _load(WorktreeChanges changes) {
    final key = (changes, changes.version, widget.path);
    if (key == _loadedFor) return;
    _loadedFor = key;
    changes.diff(widget.path).then((file) {
      if (mounted && _loadedFor == key) setState(() => _file = file);
    });
  }
  final _scroll = ScrollController();
  final _hScroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  void _jump(int delta, List<DiffRow> rows, int count) {
    if (count == 0) return;
    final next = (_hunk + delta + count) % count;
    setState(() => _hunk = next);
    var y = 6.0;
    for (final r in rows) {
      if (r.hunk == next) break;
      y += r.isFold ? _foldH : _lineH;
    }
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final target = math.max(0.0, math.min(pos.maxScrollExtent, y - pos.viewportDimension / 3));
    _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    _load(AppScope.of(context).changes);
    final file = _file;
    final name = widget.path.substring(widget.path.lastIndexOf('/') + 1);
    final dir = widget.path.substring(0, widget.path.lastIndexOf('/') + 1);
    final count = file == null ? 0 : hunkCount(file);
    final rows = file == null ? const <DiffRow>[] : diffRows(file, changesOnly: _changesOnly);
    final kindColor = file == null ? c.text3 : (file.kind == 'A' ? c.ok : c.warn);
    final kindSoft = file == null ? c.tile : (file.kind == 'A' ? c.okSoft : c.warnSoft);
    final label = file == null ? 'No changes' : switch (file.kind) { 'A' => 'Added', 'D' => 'Deleted', _ => 'Modified' };
    final hunkLabel = file == null ? '—' : (file.kind == 'A' ? 'New file' : 'Change ${count == 0 ? 0 : _hunk + 1} of $count');

    return Container(
      decoration: BoxDecoration(color: c.pane, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.paneBorder)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, box) {
          final compact = box.maxWidth < 640;
          return Container(
            height: 42,
            padding: const EdgeInsets.only(left: 12, right: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
            child: Row(children: [
              Icon(KIcons.file, size: 15, color: kindColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: dir, style: mono(12, color: c.text3)),
                    TextSpan(text: name, style: mono(12, weight: FontWeight.w600, color: c.text)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              if (!compact) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(color: kindSoft, borderRadius: BorderRadius.circular(9)),
                  child: Text(label, style: sans(11, weight: FontWeight.w600, color: kindColor)),
                ),
                const SizedBox(width: 8),
              ],
              if (file != null) ...[
                Text.rich(TextSpan(children: [
                  TextSpan(text: '+${file.added} ', style: mono(11.5, color: c.ok)),
                  TextSpan(text: '−${file.deleted}', style: mono(11.5, color: c.err)),
                ])),
                if (file.writing && !compact) ...[
                  const SizedBox(width: 8),
                  Pill(label: 'Claude is still writing', color: c.acc, background: c.accSoft),
                ],
              ],
              const Spacer(),
              if (file != null) ...[
                KSegmented<bool>(
                  label: 'Show',
                  height: 24,
                  value: _changesOnly,
                  onChanged: (v) => setState(() => _changesOnly = v),
                  items: const [(false, 'Full file', null), (true, 'Changes only', null)],
                ),
                const SizedBox(width: 8),
                KIconButton(icon: KIcons.chevronUp, label: 'Previous change', size: 24, iconSize: 16, onTap: () => _jump(-1, rows, count)),
                if (!compact)
                  SizedBox(width: 82, child: Text(hunkLabel, textAlign: TextAlign.center, style: sans(11.5, color: c.text2))),
                KIconButton(icon: KIcons.chevronDown, label: 'Next change', size: 24, iconSize: 16, onTap: () => _jump(1, rows, count)),
              ],
              KIconButton(
                icon: KIcons.external,
                label: 'Edit in the editor',
                size: 24,
                iconSize: 14,
                onTap: () => AppScope.read(context).editFile(widget.path),
              ),
            ]),
          );
        }),
        Expanded(child: file == null ? _unchanged(context) : _body(context, file, rows)),
      ]),
    );
  }

  Widget _unchanged(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: 'No changes in this file on ', style: sans(12.5, color: c.text2)),
          TextSpan(text: AppScope.of(context).changes.branch, style: mono(12, color: c.text2)),
          TextSpan(text: '.', style: sans(12.5, color: c.text2)),
        ])),
        const SizedBox(height: 12),
        KButton(label: 'Open in the editor', height: 30, onTap: () => AppScope.read(context).editFile(widget.path)),
      ]),
    );
  }

  Widget _body(BuildContext context, ChangedFile file, List<DiffRow> rows) {
    final c = context.c;
    final d = DiffColors.of(c);
    final lang = langOf(file.path).lang;
    final base = mono(12, color: d.text, height: 1.4);
    final longest = file.lines.fold<int>(0, (m, l) => math.max(m, l.text.replaceAll('\t', '    ').length));
    final probe = TextPainter(text: TextSpan(text: 'M', style: base), textDirection: TextDirection.ltr)..layout();
    final charW = probe.width;
    probe.dispose();

    Widget line(DiffRow r) {
      final l = r.line!;
      final (bg, bar, sign, signColor) = switch (l.kind) {
        DiffKind.added => (d.add, c.ok, '+', c.ok),
        DiffKind.deleted => (d.del, c.err, '−', c.err),
        DiffKind.context => (Colors.transparent, Colors.transparent, ' ', c.text3),
      };
      final text = l.text.replaceAll('\t', '    ');
      return Container(
        height: _lineH,
        color: bg,
        child: Row(children: [
          Container(width: 3, color: bar),
          SizedBox(width: 34, child: Text(r.oldNo?.toString() ?? '', textAlign: TextAlign.right, style: mono(12, color: c.text3, height: 1.4))),
          SizedBox(
            width: 42,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(r.newNo?.toString() ?? '', textAlign: TextAlign.right, style: mono(12, color: c.text3, height: 1.4)),
            ),
          ),
          SizedBox(width: 16, child: Text(sign, style: mono(12, color: signColor, height: 1.4))),
          Expanded(
            child: Text.rich(
              TextSpan(style: base, children: [for (final (t, tok) in Syntax.line(lang, text)) TextSpan(text: t, style: d.styleFor(tok))]),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          ),
        ]),
      );
    }

    Widget fold(DiffRow r) => SizedBox(
          height: _foldH,
          child: KPressable(
            onTap: () => setState(() => _changesOnly = false),
            semanticLabel: 'Show ${r.fold} unchanged lines',
            builder: (context, hover, focus) => Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.only(left: _gutter - 16),
              alignment: Alignment.centerLeft,
              color: hover || focus ? c.accSoft : c.tile,
              child: Text('⋯  ${r.fold} unchanged ${r.fold == 1 ? 'line' : 'lines'}', style: sans(11.5, color: c.text3)),
            ),
          ),
        );

    return LayoutBuilder(builder: (context, box) {
      final width = math.max(box.maxWidth, _gutter + longest * charW + 24);
      final extra = file.writing ? 1 : 0;
      return Scrollbar(
        controller: _hScroll,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: box.maxHeight,
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: rows.length + extra,
              itemBuilder: (context, i) {
                if (i == rows.length) {
                  return SizedBox(
                    height: _lineH,
                    child: Padding(
                      padding: const EdgeInsets.only(left: _gutter),
                      child: Align(alignment: Alignment.centerLeft, child: Container(width: 7, height: 15, color: c.acc)),
                    ),
                  );
                }
                final r = rows[i];
                return r.isFold ? fold(r) : line(r);
              },
            ),
          ),
        ),
      );
    });
  }
}
