import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The user's settings, as a small JSON file next to the app's data:
/// `~/Library/Application Support/Kumo/ui.json` on macOS (inside the app
/// container when sandboxed), `%APPDATA%\Kumo\ui.json` on Windows.
///
/// Values are plain JSON (bool / num / String). Writes are debounced, so a
/// slider drag costs one write, not one per frame.
class Preferences {
  Preferences(this.file, [Map<String, Object?>? values]) : _values = values ?? {};

  /// In-memory only (widget tests).
  Preferences.memory() : file = null, _values = {};

  final File? file;
  final Map<String, Object?> _values;
  Timer? _pending;

  static File? defaultFile() {
    final env = Platform.environment;
    if (Platform.isMacOS) {
      final home = env['HOME'];
      return home == null ? null : File('$home/Library/Application Support/Kumo/ui.json');
    }
    if (Platform.isWindows) {
      final appData = env['APPDATA'];
      return appData == null ? null : File('$appData\\Kumo\\ui.json');
    }
    final home = env['HOME'];
    return home == null ? null : File('$home/.config/kumo/ui.json');
  }

  /// Reads the file synchronously (it is tiny) so the first frame already
  /// has the user's theme and layout. A missing or broken file means
  /// defaults.
  static Preferences load([File? file]) {
    final f = file ?? defaultFile();
    if (f == null) return Preferences.memory();
    try {
      if (f.existsSync()) {
        final decoded = jsonDecode(f.readAsStringSync());
        if (decoded is Map<String, dynamic>) return Preferences(f, Map<String, Object?>.from(decoded));
      }
    } catch (_) {
      // Unreadable settings never block startup.
    }
    return Preferences(f);
  }

  T get<T>(String key, T fallback) {
    final v = _values[key];
    if (v is T) return v;
    if (fallback is double && v is num) return v.toDouble() as T;
    return fallback;
  }

  void set(String key, Object? value) {
    if (_values[key] == value) return;
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    _schedule();
  }

  void _schedule() {
    if (file == null) return;
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 400), flush);
  }

  /// Writes now (also called on dispose).
  void flush() {
    _pending?.cancel();
    _pending = null;
    final f = file;
    if (f == null) return;
    try {
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_values));
    } catch (_) {
      // Best effort: a read-only disk just means settings don't persist.
    }
  }

  void dispose() {
    if (_pending != null) flush();
  }
}
