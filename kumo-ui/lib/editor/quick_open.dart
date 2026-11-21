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
  final q = fuzzyQuery(query);
  if (q.isEmpty) return (0, const []);
  return _match(q, path, path.toLowerCase(), path.lastIndexOf('/') + 1);
}

/// [query] as [fuzzyMatch] compares it: lower case, no spaces. Done once
/// per query, not once per path.
String fuzzyQuery(String query) => query.toLowerCase().replaceAll(' ', '');

/// [fuzzyMatch] for a query already through [fuzzyQuery] (not empty), on
/// [path] with its lower case [p] and where its name starts, [base].
(int, List<int>)? _match(String q, String path, String p, int base) {
  // Every candidate below needs the letters in order from the start: the
  // weakest condition, checked first without building anything.
  if (!_inOrder(p, q)) return null;
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

/// Whether [q]'s letters all show in [p], in order.
bool _inOrder(String p, String q) {
  var i = 0;
  final n = p.length;
  for (var k = 0; k < q.length; k++) {
    final ch = q.codeUnitAt(k);
    while (i < n && p.codeUnitAt(i) != ch) {
      i++;
    }
    if (i == n) return false;
    i++;
  }
  return true;
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
  final prev = path.codeUnitAt(i - 1);
  // '/', '_', '-', '.', ' '
  if (prev == 0x2F || prev == 0x5F || prev == 0x2D || prev == 0x2E || prev == 0x20) return true;
  // camelCase: a capital after a small letter.
  return _isUpper(path, i) && _isLower(path, i - 1);
}

/// ASCII by its code; anything else as the string compares it.
bool _isUpper(String s, int i) {
  final c = s.codeUnitAt(i);
  if (c < 0x80) return c >= 0x41 && c <= 0x5A;
  final ch = s[i];
  return ch.toUpperCase() == ch && ch.toLowerCase() != ch;
}

bool _isLower(String s, int i) {
  final c = s.codeUnitAt(i);
  if (c < 0x80) return c >= 0x61 && c <= 0x7A;
  final ch = s[i];
  return ch.toLowerCase() == ch && ch.toUpperCase() != ch;
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

/// [text] (from [from] up to [to]) as spans: the letters at [hits] (each
/// less [offset]) in [strong], the rest in [style]; one span per run of
/// either, not per letter.
List<TextSpan> markedSpans(String text, Set<int> hits, TextStyle style, TextStyle strong, {int from = 0, int? to, int offset = 0}) {
  final end = to ?? text.length;
  final spans = <TextSpan>[];
  var start = from;
  while (start < end) {
    final on = hits.contains(start + offset);
    var k = start + 1;
    while (k < end && hits.contains(k + offset) == on) {
      k++;
    }
    spans.add(TextSpan(text: text.substring(start, k), style: on ? strong : style));
    start = k;
  }
  return spans;
}

/// [files] ranked for [query], best first, at most [limit]; with no query,
/// [recent] (the files open, latest first) then the rest by path.
List<(String, List<int>)> rankFiles(String query, List<String> files, {List<String> recent = const [], int limit = 80}) => FileIndex(files).rank(query, recent: recent, limit: limit).top;

/// What [FileIndex.rank] found: the best [top], and how many matched in all.
typedef FileMatches = ({List<(String, List<int>)> top, int total});

/// [files] made ready to rank as the query is typed: each path's lower case
/// and name kept, and the paths the last query matched, so a query that
/// only adds letters looks at those alone (a path that misses `ab` misses
/// `abc` too). Same order as [fuzzyMatch] and a full sort give.
class FileIndex {
  FileIndex(this.files)
      : _lower = [for (final f in files) f.toLowerCase()],
        _base = [for (final f in files) f.lastIndexOf('/') + 1];

  final List<String> files;
  final List<String> _lower;
  final List<int> _base;
  Set<String>? _set;

  /// The last query (through [fuzzyQuery]) and the paths it matched.
  String? _lastQ;
  List<int> _lastHits = const [];
  int _lastLimit = -1;
  FileMatches? _last;

  /// Whether [other] holds the same paths, so this index still serves it.
  bool serves(List<String> other) {
    if (identical(other, files)) return true;
    if (other.length != files.length) return false;
    for (var i = 0; i < files.length; i++) {
      final a = other[i], b = files[i];
      if (!identical(a, b) && a != b) return false;
    }
    return true;
  }

  FileMatches rank(String query, {List<String> recent = const [], int limit = 80}) {
    final q = query.trim().isEmpty ? '' : fuzzyQuery(query);
    if (q.isEmpty) {
      _lastQ = null;
      final set = _set ??= files.toSet();
      final first = <String>[];
      final firstSet = <String>{};
      for (final r in recent) {
        if (set.contains(r) && firstSet.add(r)) first.add(r);
      }
      final top = <(String, List<int>)>[for (final f in first.take(limit)) (f, const <int>[])];
      for (final f in files) {
        if (top.length >= limit) break;
        if (!firstSet.contains(f)) top.add((f, const <int>[]));
      }
      return (top: top, total: files.length);
    }
    if (q == _lastQ && limit == _lastLimit) return _last!;

    final prev = _lastQ;
    final narrow = prev != null && q.startsWith(prev);
    final hits = <int>[];
    final best = TopK<(int, int, List<int>)>(limit, _better);
    void look(int i) {
      final m = _match(q, files[i], _lower[i], _base[i]);
      if (m == null) return;
      hits.add(i);
      best.add((m.$1, i, m.$2));
    }

    if (narrow) {
      for (final i in _lastHits) {
        look(i);
      }
    } else {
      for (var i = 0; i < files.length; i++) {
        look(i);
      }
    }
    _lastQ = q;
    _lastHits = hits;
    _lastLimit = limit;
    return _last = (top: [for (final (_, i, at) in best.sorted()) (files[i], at)], total: hits.length);
  }

  /// Higher score first, then the shorter path, then by path.
  int _better((int, int, List<int>) a, (int, int, List<int>) b) {
    final c = b.$1.compareTo(a.$1);
    if (c != 0) return c;
    final pa = files[a.$2], pb = files[b.$2];
    final l = pa.length.compareTo(pb.length);
    return l != 0 ? l : pa.compareTo(pb);
  }
}

/// The [k] best of what's [add]ed, by [compare] (negative: the first is
/// better), without sorting all of it: a heap with the worst kept on top.
class TopK<E> {
  TopK(this.k, this.compare);
  final int k;
  final int Function(E a, E b) compare;
  final List<E> _heap = [];

  void add(E e) {
    if (k <= 0) return;
    if (_heap.length < k) {
      _heap.add(e);
      _up(_heap.length - 1);
    } else if (compare(e, _heap[0]) < 0) {
      _heap[0] = e;
      _down(0);
    }
  }

  /// Best first.
  List<E> sorted() => [..._heap]..sort(compare);

  // The root is the worst: a parent is never better than its children.
  bool _worse(int i, int j) => compare(_heap[i], _heap[j]) > 0;

  void _up(int i) {
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (!_worse(i, parent)) return;
      _swap(i, parent);
      i = parent;
    }
  }

  void _down(int i) {
    final n = _heap.length;
    while (true) {
      final l = 2 * i + 1, r = l + 1;
      var w = i;
      if (l < n && _worse(l, w)) w = l;
      if (r < n && _worse(r, w)) w = r;
      if (w == i) return;
      _swap(i, w);
      i = w;
    }
  }

  void _swap(int i, int j) {
    final t = _heap[i];
    _heap[i] = _heap[j];
    _heap[j] = t;
  }
}

// ---- Palette ----

/// ⌘P: picks a file of the worktree; it opens in the full editor when that
/// is showing, else in the Terminal view's Files tab.
Future<void> goToFile(BuildContext context, AppState s) async {
  final path = await showQuickOpen(context, files: s.visibleFiles, recent: recentFiles(s), statusOf: s.changes.statusOf);
  if (path != null) openWorktreeFile(s, path);
}

/// The files open in the current worktree, latest first: what an empty
/// query lists first.
List<String> recentFiles(AppState s) {
  final current = s.contextFile;
  return [if (current != null) current, ...s.contextFiles.reversed.where((f) => f != current)];
}

/// Opens [path] of the current worktree in the full editor when that is
/// showing, else in the Terminal view's Files tab.
void openWorktreeFile(AppState s, String path) {
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
  late FileIndex _index = FileIndex(widget.files);
  List<(String, List<int>)> _results = const [];
  int _total = 0;
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

  void _rank() {
    if (!_index.serves(widget.files)) _index = FileIndex(widget.files);
    final found = _index.rank(_query.text, recent: widget.recent);
    _results = found.top;
    _total = found.total;
  }

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
              Text('$_total ${_total == 1 ? 'file' : 'files'}', style: sans(11.5, color: c.text3)),
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
    List<TextSpan> marked(String text, int offset, TextStyle style, TextStyle strong) => markedSpans(text, hit, style, strong, offset: offset);
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
