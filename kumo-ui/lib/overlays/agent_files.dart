import 'dart:io';

/// A file an agent was asked to write (a draft, an answers file), and an
/// optional companion written just before it (a title, a name). Polled until
/// it's there, newer than [baseline], and the same size twice in a row:
/// written in full.
class AgentFileWatch {
  AgentFileWatch(this.path, {this.companion});

  /// `<tmp>/kumo-agents/<stem>.<ext>`, the folder made, the file gone.
  factory AgentFileWatch.fresh(String stem, String ext, {String? companionExt}) {
    final dir = Directory('${Directory.systemTemp.path}/kumo-agents')..createSync(recursive: true);
    final w = AgentFileWatch('${dir.path}/$stem.$ext', companion: companionExt == null ? null : '${dir.path}/$stem.$companionExt');
    w.delete();
    return w;
  }

  final String path;
  final String? companion;

  /// Only a file changed after this counts (set before asking for a redo).
  DateTime? baseline;
  int _last = -1;
  int _waits = 0;

  /// The file's text once written in full, with the companion's first line
  /// (null when it has none); null while still waiting.
  (String, String?)? poll() {
    final file = File(path);
    FileStat? stat;
    try {
      stat = file.existsSync() ? file.statSync() : null;
    } on Object {
      stat = null;
    }
    final size = stat?.size ?? 0;
    final b = baseline;
    final fresh = stat != null && size > 0 && (b == null || stat.modified.isAfter(b));
    if (!fresh || size != _last) {
      _last = fresh ? size : -1;
      return null;
    }
    final c = companion;
    // The companion comes first in the prompts, but agents don't always
    // obey: a few more polls for it.
    if (c != null && !File(c).existsSync() && _waits < 6) {
      _waits++;
      return null;
    }
    final String text;
    try {
      text = file.readAsStringSync();
    } on Object {
      return null;
    }
    String? first;
    if (c != null) {
      try {
        final line = File(c).readAsStringSync().trim().split('\n').first.trim();
        first = line.isEmpty ? null : line;
      } on Object {
        first = null;
      }
    }
    return (text, first);
  }

  /// Saves [text] as the file (your edits, before a redo) and only takes a
  /// newer one from then on.
  void rebase([String? text]) {
    try {
      if (text != null) File(path).writeAsStringSync(text);
      baseline = File(path).statSync().modified;
    } on Object {
      baseline = DateTime.now();
    }
    _last = -1;
    _waits = 0;
  }

  void delete() {
    for (final p in [path, companion]) {
      if (p == null) continue;
      try {
        File(p).deleteSync();
      } on Object {
        // Already gone.
      }
    }
  }
}
