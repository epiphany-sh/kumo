import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/changes.dart';
import '../data/mock_project.dart' show GitStatus;
import '../data/worktree_changes.dart';
import '../theme/kumo_theme.dart';
import '../widgets/change_scrollbar.dart';
import '../widgets/controls.dart';
import '../widgets/kicons.dart';
import 'code_editor.dart';
import 'diff_colors.dart';
import 'syntax.dart';

/// How a [FileView] shows its file.
enum FileViewMode { edit, diff, changesOnly }

/// A file of the worktree: editable (Edit), or the whole file with its
/// changes inline (Diff) or only the changed hunks, numbered old/new like
/// `git diff`, with previous / next change navigation. Its scrollbar maps
/// where the file changed.
class FileView extends StatefulWidget {
  const FileView({super.key, required this.path, this.startEditing = false});
  final String path;

  /// Opens in Edit (the Files tab) instead of the diff (a review's tabs).
  final bool startEditing;

  @override
  State<FileView> createState() => _FileViewState();
}

class _FileViewState extends State<FileView> {
  static const _lineH = 20.0;
  static const _foldH = 30.0;
  static const _gutter = 3.0 + 34 + 42 + 16;
  static const _editFont = 12.5;

  late FileViewMode _mode = widget.startEditing ? FileViewMode.edit : FileViewMode.diff;
  bool get _changesOnly => _mode == FileViewMode.changesOnly;
  int _hunk = 0;
  String? _saveError;

  /// The file with its changed lines, loaded from the worktree's changes.
  ChangedFile? _file;
  Object? _loadedFor;
  bool _diffLoaded = false;

  /// Changed lines for the editor's gutter (line → added?).
  Map<int, bool> _marks = const {};
  Object? _marksFor;

  /// (Re)loads when the worktree, its status or the path changes.
  void _load(WorktreeChanges changes) {
    final key = (changes, changes.version, widget.path);
    if (key == _loadedFor) return;
    _loadedFor = key;
    changes.diff(widget.path).then((file) {
      if (mounted && _loadedFor == key) {
        setState(() {
          _file = file;
          _diffLoaded = true;
        });
      }
    });
  }

  void _loadMarks(WorktreeChanges changes) {
    final key = (changes, changes.version, widget.path);
    if (key == _marksFor) return;
    _marksFor = key;
    changes.marks(widget.path).then((marks) {
      if (mounted && _marksFor == key) setState(() => _marks = marks);
    });
  }

  final _scroll = ScrollController();
  final _hScroll = ScrollController();
  final _editScroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    _hScroll.dispose();
    _editScroll.dispose();
    super.dispose();
  }

  /// First line of each run of changed lines, for previous / next in Edit.
  List<int> get _runs {
    final lines = _marks.keys.toList()..sort();
    return [for (var i = 0; i < lines.length; i++) if (i == 0 || lines[i] != lines[i - 1] + 1) lines[i]];
  }

  void _scrollTo(ScrollController sc, double y) {
    if (!sc.hasClients) return;
    final pos = sc.position;
    final target = math.max(0.0, math.min(pos.maxScrollExtent, y - pos.viewportDimension / 3));
    sc.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  void _jump(int delta, List<DiffRow> rows, int count, FileViewMode mode) {
    if (count == 0) return;
    final next = (_hunk + delta + count) % count;
    setState(() => _hunk = next);
    if (mode == FileViewMode.edit) {
      final line = _runs[next];
      _scrollTo(_editScroll, CodeEditor.topPadding + (line - 1) * CodeEditor.lineExtentFor(_editFont));
      return;
    }
    var y = 6.0;
    for (final r in rows) {
      if (r.hunk == next) break;
      y += r.isFold ? _foldH : _lineH;
    }
    _scrollTo(_scroll, y);
  }

  Future<void> _save() async {
    final error = await AppScope.read(context).buffers.save(widget.path);
    if (mounted) setState(() => _saveError = error);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    _load(s.changes);
    final file = _file;
    final deleted = s.changes.statusOf(widget.path) == GitStatus.deleted || file?.kind == 'D';
    // Unchanged files only have the editor; deleted ones only the diff.
    final mode = file == null ? FileViewMode.edit : (deleted && _mode == FileViewMode.edit ? FileViewMode.diff : _mode);
    if (mode == FileViewMode.edit) _loadMarks(s.changes);
    final dirty = s.buffers.isDirty(widget.path);
    final asking = s.closeAsk?.$1 == widget.path;
    final name = widget.path.substring(widget.path.lastIndexOf('/') + 1);
    final dir = widget.path.substring(0, widget.path.lastIndexOf('/') + 1);
    final count = mode == FileViewMode.edit ? _runs.length : (file == null ? 0 : hunkCount(file));
    final rows = file == null || mode == FileViewMode.edit ? const <DiffRow>[] : diffRows(file, changesOnly: _changesOnly);
    final kindColor = file == null ? c.text3 : (file.kind == 'A' ? c.ok : c.warn);
    final kindSoft = file == null ? c.tile : (file.kind == 'A' ? c.okSoft : c.warnSoft);
    final label = file == null ? 'No changes' : switch (file.kind) { 'A' => 'Added', 'D' => 'Deleted', _ => 'Modified' };
    final hunkLabel = file?.kind == 'A' ? 'New file' : (count == 0 ? 'No changes' : 'Change ${_hunk.clamp(0, count - 1) + 1} of $count');

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
      },
      child: Container(
        decoration: BoxDecoration(color: c.pane, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.paneBorder)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LayoutBuilder(builder: (context, box) {
            final compact = box.maxWidth < 700;
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
                if (!compact && file != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(color: kindSoft, borderRadius: BorderRadius.circular(9)),
                    child: Text(label, style: sans(11, weight: FontWeight.w600, color: kindColor)),
                  ),
                  const SizedBox(width: 8),
                ],
                // Narrow with unsaved edits: the Save button needs the room.
                if (file != null && !(compact && dirty)) ...[
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
                if (dirty) ...[
                  Tooltip(message: 'Save (⌘S)', child: KButton(label: 'Save', height: 24, fontSize: 11.5, onTap: _save)),
                  const SizedBox(width: 8),
                ],
                if (file != null) ...[
                  KSegmented<FileViewMode>(
                    label: 'Show',
                    height: 24,
                    value: mode,
                    onChanged: (v) => setState(() {
                      _mode = v;
                      _hunk = 0;
                    }),
                    items: [
                      if (!deleted) (FileViewMode.edit, 'Edit', null),
                      (FileViewMode.diff, 'Diff', null),
                      (FileViewMode.changesOnly, compact ? 'Changes' : 'Changes only', null),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
                if (count > 0 || file != null) ...[
                  KIconButton(icon: KIcons.chevronUp, label: 'Previous change', size: 24, iconSize: 16, onTap: () => _jump(-1, rows, count, mode)),
                  if (!compact) SizedBox(width: 82, child: Text(hunkLabel, textAlign: TextAlign.center, style: sans(11.5, color: c.text2))),
                  KIconButton(icon: KIcons.chevronDown, label: 'Next change', size: 24, iconSize: 16, onTap: () => _jump(1, rows, count, mode)),
                ],
                KIconButton(
                  icon: KIcons.external,
                  label: 'Open in the full editor',
                  size: 24,
                  iconSize: 14,
                  onTap: () => AppScope.read(context).editFile(widget.path),
                ),
              ]),
            );
          }),
          if (asking) _closeBar(context, name),
          if (_saveError != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
              decoration: BoxDecoration(color: c.errSoft, border: Border(bottom: BorderSide(color: c.divider))),
              child: Row(children: [
                Icon(KIcons.warning, size: 15, color: c.err),
                const SizedBox(width: 8),
                Expanded(child: Text('Couldn’t save: $_saveError', maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text))),
                KIconButton(icon: KIcons.close, label: 'Dismiss', size: 22, iconSize: 12, onTap: () => setState(() => _saveError = null)),
              ]),
            ),
          Expanded(
            child: !_diffLoaded
                ? const SizedBox.shrink()
                : (mode == FileViewMode.edit || file == null ? _editor(context) : _body(context, file, rows)),
          ),
        ]),
      ),
    );
  }

  /// The tab asked to close with unsaved edits.
  Widget _closeBar(BuildContext context, String name) {
    final c = context.c;
    final s = AppScope.read(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
      decoration: BoxDecoration(color: c.warnSoft, border: Border(bottom: BorderSide(color: c.divider))),
      child: Row(children: [
        Icon(KIcons.warning, size: 15, color: c.warn),
        const SizedBox(width: 8),
        Expanded(child: Text('$name has unsaved changes. Save them before closing?', maxLines: 2, style: sans(12, color: c.text))),
        const SizedBox(width: 8),
        KButton.primary(
          label: 'Save and close',
          height: 26,
          fontSize: 11.5,
          onTap: () async {
            final error = await s.answerClose(save: true);
            if (mounted && error != null) setState(() => _saveError = error);
          },
        ),
        const SizedBox(width: 6),
        KButton(label: 'Don’t save', kind: KButtonKind.ghost, height: 26, fontSize: 11.5, onTap: () => s.answerClose(save: false)),
        KButton(label: 'Cancel', kind: KButtonKind.ghost, height: 26, fontSize: 11.5, onTap: s.cancelClose),
      ]),
    );
  }

  /// Edit: the file's buffer in the code editor, with its changed lines in
  /// the gutter and on the scrollbar.
  Widget _editor(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final buffers = s.buffers;
    final ctrl = buffers.of(widget.path);
    if (!buffers.isLoaded(widget.path)) return const SizedBox.shrink();
    final why = buffers.readOnlyReason(widget.path);
    final status = s.changes.statusOf(widget.path);
    final whole = status == GitStatus.added || status == GitStatus.untracked || _file?.kind == 'A';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (why != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          color: c.tile,
          child: Text(why, style: sans(12, color: c.text2)),
        ),
      Expanded(
        child: CodeEditor(
          key: ValueKey('edit:${widget.path}'),
          controller: ctrl,
          readOnly: why != null,
          fontSize: _editFont,
          scrollController: _editScroll,
          decorate: (lines) => [
            for (var i = 0; i < lines.length; i++)
              LineDeco(bar: whole ? c.ok : switch (_marks[i + 1]) { true => c.ok, false => c.warn, null => null }),
          ],
        ),
      ),
    ]);
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
            onTap: () => setState(() => _mode = FileViewMode.diff),
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

    final extra = file.writing ? 1 : 0;
    final ticks = changeTicks(
      [for (final r in rows) r.isFold ? _foldH : _lineH],
      [
        for (final r in rows)
          if (r.isFold) null else switch (r.line!.kind) { DiffKind.added => c.ok, DiffKind.deleted => c.err, DiffKind.context => null },
      ],
      top: 6,
      bottom: 6 + extra * _lineH,
    );
    return LayoutBuilder(builder: (context, box) {
      final width = math.max(box.maxWidth, _gutter + longest * charW + 24);
      return ChangeScrollbar(
        controller: _scroll,
        ticks: ticks,
        child: Scrollbar(
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
        ),
      );
    });
  }
}
