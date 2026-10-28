/// Tiny line tokenizers for the languages in the mock project. Good enough
/// for a design-faithful editor; the real app should use tree-sitter in the
/// Rust core and stream highlight ranges, so the UI never parses.
library;

enum Tok { kw, str, num, com, type, fn, key, punct, text, head }

enum Lang { go, yaml, json, markdown, makefile, ignore, plain }

typedef Seg = (String, Tok);

class LangInfo {
  const LangInfo(this.lang, this.badge, this.label, this.server, this.indent);
  final Lang lang;
  final String badge;
  final String label;
  final String server;
  final String indent;
}

LangInfo langOf(String path) {
  final name = path.split('/').last;
  if (name == 'go.mod') return const LangInfo(Lang.go, 'MOD', 'Go module', 'gopls ready', 'Tabs');
  if (name == 'go.sum') return const LangInfo(Lang.plain, 'SUM', 'Go checksums', 'read-only', 'Tabs');
  if (name.endsWith('.go')) return const LangInfo(Lang.go, 'GO', 'Go', 'gopls ready', 'Tabs');
  if (name.endsWith('.yaml') || name.endsWith('.yml')) return const LangInfo(Lang.yaml, 'YML', 'YAML', 'yaml-ls', 'Spaces: 2');
  if (name.endsWith('.json')) return const LangInfo(Lang.json, '{ }', 'JSON', 'schema: bulk-discount.json', 'Spaces: 2');
  if (name.endsWith('.md')) return const LangInfo(Lang.markdown, 'MD', 'Markdown', 'preview ⇧⌘V', 'Spaces: 2');
  if (name == 'Makefile') return const LangInfo(Lang.makefile, 'MK', 'Makefile', '3 targets', 'Tabs');
  if (name == '.gitignore') return const LangInfo(Lang.ignore, 'GIT', 'Ignore file', '', 'Spaces: 2');
  return const LangInfo(Lang.plain, 'TXT', 'Plain text', '', 'Spaces: 2');
}

abstract final class Syntax {
  static List<Seg> line(Lang lang, String line) => switch (lang) {
        Lang.go => _go(line),
        Lang.yaml => _yaml(line),
        Lang.json => _json(line),
        Lang.markdown => _md(line),
        Lang.makefile => _make(line),
        Lang.ignore => [(line, line.trimLeft().startsWith('#') ? Tok.com : Tok.text)],
        Lang.plain => [(line, Tok.text)],
      };

  static List<Seg> _merge(List<Seg> out) {
    final r = <Seg>[];
    for (final s in out) {
      if (s.$1.isEmpty) continue;
      if (r.isNotEmpty && r.last.$2 == s.$2) {
        r[r.length - 1] = (r.last.$1 + s.$1, s.$2);
      } else {
        r.add(s);
      }
    }
    return r;
  }

  static const _goKw = {
    'package', 'import', 'func', 'return', 'if', 'else', 'for', 'range', 'var', 'const', 'type', 'struct', 'interface', //
    'map', 'chan', 'go', 'defer', 'select', 'case', 'switch', 'default', 'break', 'continue', 'nil', 'true', 'false', 'module', 'require',
  };
  static const _goTypes = {'string', 'int', 'int64', 'float64', 'bool', 'error', 'any', 'byte'};
  static final _goRe = RegExp(r'(//.*$)|("(?:[^"\\]|\\.)*"|`[^`]*`)|(\b\d+(?:\.\d+)?\b)|([A-Za-z_][A-Za-z0-9_]*)|(\s+)|(.)');

  static List<Seg> _go(String line) {
    final out = <Seg>[];
    for (final m in _goRe.allMatches(line)) {
      if (m[1] != null) {
        out.add((m[1]!, Tok.com));
      } else if (m[2] != null) {
        out.add((m[2]!, Tok.str));
      } else if (m[3] != null) {
        out.add((m[3]!, Tok.num));
      } else if (m[4] != null) {
        final w = m[4]!;
        var k = Tok.text;
        if (_goKw.contains(w)) {
          k = Tok.kw;
        } else if (_goTypes.contains(w)) {
          k = Tok.type;
        } else if (m.end < line.length && line[m.end] == '(') {
          k = Tok.fn;
        } else if (RegExp(r'^[A-Z]').hasMatch(w)) {
          k = Tok.type;
        }
        out.add((w, k));
      } else if (m[5] != null) {
        out.add((m[5]!, Tok.text));
      } else {
        out.add((m[6]!, Tok.punct));
      }
    }
    return _merge(out);
  }

  static final _yamlKey = RegExp(r'^(\s*)(-\s+)?([^\s:#][^:]*?)(:)(\s.*|$)');
  static final _yamlItem = RegExp(r'^(\s*)(-\s+)?(.*)$');
  static final _yamlComment = RegExp(r'\s#\s');

  static void _yamlValue(String v, List<Seg> out) {
    final lead = RegExp(r'^\s*').firstMatch(v)![0]!;
    final val = v.substring(lead.length);
    out.add((lead, Tok.text));
    if (val.isEmpty) return;
    var k = Tok.str;
    if (RegExp(r'^(true|false|null|~)\s*$').hasMatch(val)) {
      k = Tok.num;
    } else if (RegExp(r'^-?\d+(\.\d+)?([a-zA-Z]+)?\s*$').hasMatch(val)) {
      k = Tok.num;
    } else if (val.startsWith(r'${')) {
      k = Tok.type;
    }
    out.add((val, k));
  }

  static List<Seg> _yaml(String line) {
    if (line.trimLeft().startsWith('#')) return [(line, Tok.com)];
    var body = line;
    var com = '';
    final ci = _yamlComment.firstMatch(line);
    if (ci != null) {
      body = line.substring(0, ci.start);
      com = line.substring(ci.start);
    }
    final out = <Seg>[];
    final m = _yamlKey.firstMatch(body);
    if (m != null) {
      out.add((m[1]!, Tok.text));
      if (m[2] != null) out.add((m[2]!, Tok.punct));
      out.add((m[3]!, Tok.key));
      out.add((':', Tok.punct));
      _yamlValue(m[5] ?? '', out);
    } else {
      final l = _yamlItem.firstMatch(body)!;
      out.add((l[1]!, Tok.text));
      if (l[2] != null) out.add((l[2]!, Tok.punct));
      _yamlValue(l[3] ?? '', out);
    }
    if (com.isNotEmpty) out.add((com, Tok.com));
    return _merge(out);
  }

  static final _jsonRe = RegExp(r'("(?:[^"\\]|\\.)*")(\s*:)?|(-?\d+(?:\.\d+)?)|(true|false|null)|(\s+)|(.)');

  static List<Seg> _json(String line) {
    final out = <Seg>[];
    for (final m in _jsonRe.allMatches(line)) {
      if (m[1] != null) {
        if (m[2] != null) {
          out.add((m[1]!, Tok.key));
          out.add((m[2]!, Tok.punct));
        } else {
          out.add((m[1]!, Tok.str));
        }
      } else if (m[3] != null) {
        out.add((m[3]!, Tok.num));
      } else if (m[4] != null) {
        out.add((m[4]!, Tok.kw));
      } else if (m[5] != null) {
        out.add((m[5]!, Tok.text));
      } else {
        out.add((m[6]!, Tok.punct));
      }
    }
    return _merge(out);
  }

  static final _makeTarget = RegExp(r'^([\w.\-]+)(:)(.*)$');
  static final _makeVar = RegExp(r'(\$\([^)]*\))|([^$]+|\$)');

  static List<Seg> _make(String line) {
    if (line.trimLeft().startsWith('#')) return [(line, Tok.com)];
    final t = _makeTarget.firstMatch(line);
    if (t != null) return _merge([(t[1]!, Tok.fn), (':', Tok.punct), (t[3]!, Tok.text)]);
    return _merge([for (final m in _makeVar.allMatches(line)) m[1] != null ? (m[1]!, Tok.type) : (m[2]!, Tok.text)]);
  }

  static final _mdCode = RegExp(r'(`[^`]*`)|([^`]+|`)');

  static List<Seg> _md(String line) {
    if (line.startsWith('#')) return [(line, Tok.head)];
    return _merge([for (final m in _mdCode.allMatches(line)) m[1] != null ? (m[1]!, Tok.str) : (m[2]!, Tok.text)]);
  }
}
