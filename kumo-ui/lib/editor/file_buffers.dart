import 'package:flutter/widgets.dart';

import '../data/worktree_changes.dart';
import 'code_editor.dart';
import 'syntax.dart';

/// What you're editing in the worktree's file views: one buffer per file,
/// kept while you switch tabs, saved with ⌘S. Buffers without edits follow
/// the disk (an agent writing the file, a discard).
class FileBuffers extends ChangeNotifier {
  FileBuffers(this.changes) {
    changes.addListener(_onChanges);
  }

  /// The worktree the buffers belong to.
  final WorktreeChanges changes;

  final _ctrls = <String, CodeController>{};
  final _saved = <String, String>{};
  final _loaded = <String>{};
  final _dirty = <String>{};
  final _readOnly = <String, String>{};
  final _loads = <String, int>{};
  int _version = -1;
  bool _disposed = false;

  bool isDirty(String path) => _dirty.contains(path);
  bool get anyDirty => _dirty.isNotEmpty;

  /// The file's text has arrived (an empty editor before means "loading").
  bool isLoaded(String path) => _loaded.contains(path);

  /// Why [path] can't be edited here (binary, too big), or null.
  String? readOnlyReason(String path) => _readOnly[path];

  /// The editor buffer of [path], loading it the first time.
  CodeController of(String path) => _ctrls.putIfAbsent(path, () {
        final c = CodeController(text: '', lang: langOf(path).lang);
        c.addListener(() => _edited(c));
        _load(path, c);
        return c;
      });

  void _edited(CodeController c) {
    // Looked up each time: a rename moves the buffer to another path.
    final path = _ctrls.entries.where((e) => identical(e.value, c)).firstOrNull?.key;
    if (path == null || !_loaded.contains(path)) return;
    final dirty = c.text != _saved[path];
    if (dirty == _dirty.contains(path)) return;
    dirty ? _dirty.add(path) : _dirty.remove(path);
    notifyListeners();
  }

  void _load(String path, CodeController c) {
    // Only the latest read counts: an older answer may arrive after it.
    final load = _loads[path] = (_loads[path] ?? 0) + 1;
    bool stale() => _disposed || _ctrls[path] != c || _loads[path] != load || _dirty.contains(path);
    changes.readForEdit(path).then((file) {
      if (stale()) return;
      final t = file?.text ?? '';
      final why = file == null ? 'This file isn’t in the worktree' : file.readOnly;
      if (why == null) {
        _readOnly.remove(path);
      } else {
        _readOnly[path] = why;
      }
      _saved[path] = t;
      final first = _loaded.add(path);
      if (c.text != t) {
        final at = c.selection.baseOffset.clamp(0, t.length);
        c.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: first ? 0 : at));
      }
      notifyListeners();
    }, onError: (Object error) {
      if (stale()) return;
      // Couldn't read it now: keep what's shown; the first time, say why.
      if (_loaded.add(path)) {
        _saved[path] = c.text;
        _readOnly[path] = 'Couldn’t read the file: $error';
      }
      notifyListeners();
    });
  }

  /// The status changed: files may have changed on disk.
  void _onChanges() {
    if (changes.version == _version) return;
    _version = changes.version;
    for (final e in _ctrls.entries) {
      if (!_dirty.contains(e.key)) _load(e.key, e.value);
    }
  }

  /// Writes [path]'s buffer to the worktree. Returns why not, or null.
  Future<String?> save(String path) async {
    final c = _ctrls[path];
    if (c == null || !_dirty.contains(path)) return null;
    final why = _readOnly[path];
    if (why != null) return why;
    final text = c.text;
    await changes.write(path, text);
    if (_disposed) return null;
    final error = changes.error;
    if (error != null) return error;
    _saved[path] = text;
    if (c.text == text) _dirty.remove(path);
    notifyListeners();
    return null;
  }

  /// Saves every buffer with edits (leaving the worktree).
  void saveAll() {
    for (final p in [..._dirty]) {
      save(p).ignore();
    }
  }

  /// Drops [path]'s edits: back to what's on disk.
  void revert(String path) {
    final c = _ctrls[path];
    if (c == null) return;
    _dirty.remove(path);
    c.text = _saved[path] ?? '';
    notifyListeners();
  }

  /// [path]'s tab closed: its buffer goes (edits included).
  void forget(String path) {
    _ctrls.remove(path)?.dispose();
    _saved.remove(path);
    _loaded.remove(path);
    _readOnly.remove(path);
    if (_dirty.remove(path)) notifyListeners();
  }

  /// A file or folder moved: its buffers move with it.
  void moved(String from, String to) {
    String follow(String p) => p == from ? to : (p.startsWith('$from/') ? to + p.substring(from.length) : p);
    for (final p in [..._ctrls.keys]) {
      final dest = follow(p);
      if (dest == p) continue;
      if (!_dirty.contains(p) && langOf(p).lang != langOf(dest).lang) {
        forget(p); // reloads with the new language's colors
        continue;
      }
      _ctrls[dest] = _ctrls.remove(p)!;
      if (_saved.containsKey(p)) _saved[dest] = _saved.remove(p)!;
      if (_loaded.remove(p)) _loaded.add(dest);
      final why = _readOnly.remove(p);
      if (why != null) _readOnly[dest] = why;
      if (_dirty.remove(p)) _dirty.add(dest);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    changes.removeListener(_onChanges);
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }
}
