import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/mock_project.dart' show GitStatus, GitStatusLetter;
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/file_icon.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';

// ---- Matching (pure) ----

/// How well [query] matches [path] (higher is better) and which of its
/// characters matched; null when it doesn't. The query's letters must
/// appear in order; runs of them, word starts and the file's name count
/// most, so `repgo` finds `repository.go` before `report/go.mod`. Spaces
/// in the query are ignored; case too.
(int, List<int>)? fuzzyMatch(String query, String path) {
  final q = query.toLowerCase().replaceAll(' ', '');
  if (q.isEmpty) return (0, const []);
  final p = path.toLowerCase();
  final base = path.lastIndexOf('/') + 1;
  (int, List<int>)? best;
  void consider(List<int>? at) {
    if (at == null) return;
    final s = _score(path, at, base);
    if (best == null || s > best!.$1) best = (s, at);
  }

  // A substring, in the name first, then anywhere.
  final inName = p.indexOf(q, base);
  if (inName >= 0) consider([for (var i = 0; i < q.length; i++) inName + i]);
  final anywhere = p.indexOf(q);
  if (anywhere >= 0 && anywhere != inName) consider([for (var i = 0; i < q.length; i++) anywhere + i]);
  // Scattered letters: all in the name, or from the start of the path.
  consider(_subsequence(p, q, base));
  consider(_subsequence(p, q, 0));
  return best;
}

List<int>? _subsequence(String p, String q, int from) {
  final at = <int>[];
  var i = from;
  for (final ch in q.codeUnits) {
    while (i < p.length && p.codeUnitAt(i) != ch) {
      i++;
    }
    if (i == p.length) return null;
    at.add(i++);
  }
  return at;
}

bool _boundary(String path, int i) {
  if (i == 0) return true;
  final prev = path[i - 1];
  if ('/_-. '.contains(prev)) return true;
  // camelCase: a capital after a small letter.
  final ch = path[i];
  return ch.toUpperCase() == ch && ch.toLowerCase() != ch && prev.toLowerCase() == prev && prev.toUpperCase() != prev;
}

int _score(String path, List<int> at, int base) {
  var s = 0;
  for (var k = 0; k < at.length; k++) {
    final i = at[k];
    s += 10;
    if (k > 0 && at[k - 1] == i - 1) s += 14;
    if (_boundary(path, i)) s += 12;
    if (i >= base) s += 8;
  }
  if (at.first == base) s += 20;
  // The whole name: a strong hint.
  if (at.length == path.length - base && at.first == base) s += 30;
  return s - path.length ~/ 6 - (at.first ~/ 8);
}

/// [files] ranked for [query], best first, at most [limit]; with no query,
/// [recent] (the files open, latest first) then the rest by path.
List<(String, List<int>)> rankFiles(String query, List<String> files, {List<String> recent = const [], int limit = 80}) {
  if (query.trim().isEmpty) {
    final set = files.toSet();
    final first = [
      for (final r in recent)
        if (set.contains(r)) r
    ];
    final firstSet = first.toSet();
    return [
      for (final f in first) (f, const <int>[]),
      for (final f in files)
        if (!firstSet.contains(f)) (f, const <int>[]),
    ].take(limit).toList();
  }
  final scored = <(int, String, List<int>)>[];
  for (final f in files) {
    final m = fuzzyMatch(query, f);
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

// ---- Palette ----

/// ⌘P: picks a file of the worktree; it opens in the full editor when that
/// is showing, else in the Terminal view's Files tab.
Future<void> goToFile(BuildContext context, AppState s) async {
  final current = s.contextFile;
  final recent = [if (current != null) current, ...s.contextFiles.reversed.where((f) => f != current)];
  final path = await showQuickOpen(context, files: s.visibleFiles, recent: recent, statusOf: s.changes.statusOf);
  if (path == null) return;
  if (s.view == KumoView.files) {
    s.editFile(path);
  } else {
    s.openContext(ContextTab.files);
    s.showContextFile(path);
  }
}

/// ⌘P: a field over the window that finds a file of the worktree by a few
/// letters of its name or path. ↑↓ pick, ↵ opens, Esc closes. Returns the
/// path picked, or null.
Future<String?> showQuickOpen(BuildContext context, {required List<String> files, List<String> recent = const [], GitStatus? Function(String path)? statusOf}) {
  final c = context.c;
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: c.isDark ? const Color(0x4D000000) : const Color(0x22141428),
    transitionDuration: const Duration(milliseconds: 110),
    transitionBuilder: (context, anim, _, child) => FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: child),
    pageBuilder: (context, _, __) => Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 84, 24, 24),
        child: Material(
          type: MaterialType.transparency,
          child: QuickOpen(files: files, recent: recent, statusOf: statusOf, onPick: (p) => Navigator.of(context).pop(p)),
        ),
      ),
    ),
  );
}

class QuickOpen extends StatefulWidget {
  const QuickOpen({super.key, required this.files, required this.onPick, this.recent = const [], this.statusOf});
  final List<String> files;
  final List<String> recent;
  final GitStatus? Function(String path)? statusOf;
  final ValueChanged<String> onPick;

  @override
  State<QuickOpen> createState() => _QuickOpenState();
}

class _QuickOpenState extends State<QuickOpen> {
  static const _rowH = 36.0;
  final _query = TextEditingController();
  final _scroll = ScrollController();
  List<(String, List<int>)> _results = const [];
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _rank();
    _query.addListener(() => setState(() {
          _rank();
          _selected = 0;
          if (_scroll.hasClients) _scroll.jumpTo(0);
        }));
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _rank() => _results = rankFiles(_query.text, widget.files, recent: widget.recent);

  void _move(int delta) {
    if (_results.isEmpty) return;
    setState(() => _selected = (_selected + delta).clamp(0, _results.length - 1));
    if (!_scroll.hasClients) return;
    final top = _selected * _rowH;
    final pos = _scroll.position;
    if (top < pos.pixels) {
      _scroll.jumpTo(top);
    } else if (top + _rowH > pos.pixels + pos.viewportDimension) {
      _scroll.jumpTo(top + _rowH - pos.viewportDimension);
    }
  }

  void _open([int? i]) {
    final at = i ?? _selected;
    if (at < _results.length) widget.onPick(_results[at].$1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () => _move(8),
        const SingleActivator(LogicalKeyboardKey.pageUp): () => _move(-8),
        if (mac) const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => _move(1),
        if (mac) const SingleActivator(LogicalKeyboardKey.keyP, control: true): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.enter): _open,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _open,
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
      },
      child: GlassOverlay(
        width: 620,
        radius: 16,
        padding: const EdgeInsets.all(6),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Icon(KIcons.search, size: 17, color: c.text3),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const ValueKey('quick-open'),
                  controller: _query,
                  autofocus: true,
                  style: sans(14.5, color: c.text),
                  cursorColor: c.acc,
                  onSubmitted: (_) => _open(),
                  decoration: InputDecoration.collapsed(hintText: 'Go to file…', hintStyle: sans(14.5, color: c.text3)),
                ),
              ),
              Text('${_results.length == 80 ? '80+' : _results.length} ${_results.length == 1 ? 'file' : 'files'}', style: sans(11.5, color: c.text3)),
            ]),
          ),
          Container(height: 1, color: c.divider, margin: const EdgeInsets.symmetric(horizontal: 6)),
          if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(child: Text(widget.files.isEmpty ? 'No files in this worktree' : 'No file matches “${_query.text}”', style: sans(12.5, color: c.text3))),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _rowH * 11 + 8),
              child: ListView.builder(
                controller: _scroll,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemExtent: _rowH,
                itemCount: _results.length,
                itemBuilder: (context, i) => _row(context, i),
              ),
            ),
          Container(height: 1, color: c.divider, margin: const EdgeInsets.symmetric(horizontal: 6)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
            child: Text('↑↓ to move · ↵ to open · Esc to close', style: sans(11, color: c.text3)),
          ),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, int i) {
    final c = context.c;
    final (path, at) = _results[i];
    final base = path.lastIndexOf('/') + 1;
    final name = path.substring(base);
    final dir = base == 0 ? '' : path.substring(0, base - 1);
    final status = widget.statusOf?.call(path);
    final on = i == _selected;
    final hit = at.toSet();
    List<TextSpan> marked(String text, int offset, TextStyle style, TextStyle strong) => [
          for (var k = 0; k < text.length; k++) TextSpan(text: text[k], style: hit.contains(offset + k) ? strong : style),
        ];
    final nameStyle = sans(13, weight: FontWeight.w500, color: c.text);
    final dirStyle = sans(12, color: c.text3);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onHover: (_) {
        if (_selected != i) setState(() => _selected = i);
      },
      child: GestureDetector(
        onTap: () => _open(i),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: on ? c.navActive : null, borderRadius: BorderRadius.circular(9)),
          child: Row(children: [
            SizedBox(width: 18, child: Center(child: FileIcon(path, size: 15))),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text.rich(TextSpan(children: marked(name, base, nameStyle, nameStyle.copyWith(color: c.acc, fontWeight: FontWeight.w700))), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(TextSpan(children: marked(dir, 0, dirStyle, dirStyle.copyWith(color: c.text2, fontWeight: FontWeight.w600))), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (status != null) ...[
              const SizedBox(width: 8),
              Text(status.letter, style: mono(11, weight: FontWeight.w700, color: _statusColor(c, status))),
            ],
          ]),
        ),
      ),
    );
  }

  static Color _statusColor(KumoPalette c, GitStatus s) => switch (s) {
        GitStatus.modified => c.warn,
        GitStatus.added || GitStatus.untracked => c.ok,
        GitStatus.deleted || GitStatus.conflict => c.err,
      };
}
