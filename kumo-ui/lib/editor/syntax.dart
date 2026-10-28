/// Tiny line tokenizers: Go, Rust, TOML, the C-like family (Dart, TS/JS,
/// Swift, Kotlin, Java, C/C++, proto), Python, shell, SQL, YAML, JSON,
/// Markdown and Makefiles. Good enough for a design-faithful editor; the real app should use tree-sitter in the
/// Rust core and stream highlight ranges, so the UI never parses.
library;

enum Tok { kw, str, num, com, type, fn, key, punct, text, head }

enum Lang { go, rust, toml, dart, ts, python, shell, sql, proto, swift, kotlin, java, c, yaml, json, markdown, makefile, ignore, plain }

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
  if (name == 'Cargo.lock') return const LangInfo(Lang.toml, 'LCK', 'Cargo lockfile', 'read-only', 'Spaces: 2');
  if (name == 'Dockerfile' || name.startsWith('Dockerfile.')) return const LangInfo(Lang.shell, 'DKR', 'Dockerfile', '', 'Spaces: 2');
  final ext = name.contains('.') ? name.substring(name.lastIndexOf('.') + 1).toLowerCase() : '';
  final known = switch (ext) {
    'rs' => const LangInfo(Lang.rust, 'RS', 'Rust', '', 'Spaces: 4'),
    'toml' => const LangInfo(Lang.toml, 'TML', 'TOML', '', 'Spaces: 2'),
    'dart' => const LangInfo(Lang.dart, 'DRT', 'Dart', '', 'Spaces: 2'),
    'ts' || 'tsx' || 'mts' || 'cts' => const LangInfo(Lang.ts, 'TS', 'TypeScript', '', 'Spaces: 2'),
    'js' || 'jsx' || 'mjs' || 'cjs' => const LangInfo(Lang.ts, 'JS', 'JavaScript', '', 'Spaces: 2'),
    'py' => const LangInfo(Lang.python, 'PY', 'Python', '', 'Spaces: 4'),
    'sh' || 'bash' || 'zsh' => const LangInfo(Lang.shell, 'SH', 'Shell', '', 'Spaces: 2'),
    'sql' => const LangInfo(Lang.sql, 'SQL', 'SQL', '', 'Spaces: 2'),
    'proto' => const LangInfo(Lang.proto, 'PB', 'Protocol Buffers', '', 'Spaces: 2'),
    'swift' => const LangInfo(Lang.swift, 'SW', 'Swift', '', 'Spaces: 4'),
    'kt' || 'kts' => const LangInfo(Lang.kotlin, 'KT', 'Kotlin', '', 'Spaces: 4'),
    'java' => const LangInfo(Lang.java, 'JV', 'Java', '', 'Spaces: 4'),
    'c' || 'h' => const LangInfo(Lang.c, 'C', 'C', '', 'Spaces: 4'),
    'cc' || 'cpp' || 'cxx' || 'hpp' || 'hh' => const LangInfo(Lang.c, 'C++', 'C++', '', 'Spaces: 4'),
    _ => null,
  };
  if (known != null) return known;
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
        Lang.toml => _toml(line),
        Lang.rust || Lang.dart || Lang.ts || Lang.python || Lang.shell || Lang.sql || Lang.proto || Lang.swift || Lang.kotlin || Lang.java || Lang.c =>
          _code(_specs[lang]!, line),
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

  // ---- Languages with C-like tokens, set up per language ----

  static final Map<Lang, _Spec> _specs = {
    Lang.rust: _Spec(
      keywords: {
        'as', 'async', 'await', 'break', 'const', 'continue', 'crate', 'dyn', 'else', 'enum', 'extern', 'false', 'fn', 'for', 'if', 'impl', 'in', //
        'let', 'loop', 'match', 'mod', 'move', 'mut', 'pub', 'ref', 'return', 'self', 'Self', 'static', 'struct', 'super', 'trait', 'true', 'type',
        'unsafe', 'use', 'where', 'while', 'yield',
      },
      types: {'i8', 'i16', 'i32', 'i64', 'i128', 'isize', 'u8', 'u16', 'u32', 'u64', 'u128', 'usize', 'f32', 'f64', 'bool', 'char', 'str'},
      quotes: '"',
      macros: true,
      // Attributes, raw strings, chars ('x', '\n') and lifetimes ('a).
      extra: RegExp(r'''(#!?\[.*\])|(b?r(?:"[^"]*"?|#".*?(?:"#|$)|##".*?(?:"##|$)|###".*?(?:"###|$)))|('(?:[^'\\]|\\.[^']{0,7})')|('[A-Za-z_]\w*)'''),
      extraToks: const [Tok.key, Tok.str, Tok.str, Tok.type],
    ),
    Lang.dart: _Spec(
      keywords: {
        'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'deferred', 'do', //
        'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external', 'factory', 'false', 'final', 'finally', 'for', 'get', 'if',
        'implements', 'import', 'in', 'interface', 'is', 'late', 'library', 'mixin', 'new', 'null', 'on', 'operator', 'part', 'required',
        'rethrow', 'return', 'sealed', 'set', 'show', 'static', 'super', 'switch', 'this', 'throw', 'true', 'try', 'typedef', 'var', 'void',
        'when', 'while', 'with', 'yield',
      },
      types: {'int', 'double', 'num', 'bool', 'String', 'dynamic', 'Object', 'Never'},
      quotes: '"\'',
      extra: RegExp(r'(@\w+)'),
      extraToks: const [Tok.type],
    ),
    Lang.ts: _Spec(
      keywords: {
        'abstract', 'as', 'async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger', 'declare', 'default', 'delete', //
        'do', 'else', 'enum', 'export', 'extends', 'false', 'finally', 'for', 'from', 'function', 'get', 'if', 'implements', 'import', 'in',
        'instanceof', 'interface', 'keyof', 'let', 'new', 'null', 'of', 'private', 'protected', 'public', 'readonly', 'return', 'set', 'static',
        'super', 'switch', 'this', 'throw', 'true', 'try', 'type', 'typeof', 'undefined', 'var', 'void', 'while', 'yield',
      },
      types: {'string', 'number', 'boolean', 'any', 'unknown', 'never', 'object', 'bigint', 'symbol'},
      quotes: '"\'`',
      extra: RegExp(r'(@\w+)'),
      extraToks: const [Tok.type],
    ),
    Lang.python: _Spec(
      keywords: {
        'and', 'as', 'assert', 'async', 'await', 'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except', 'False', 'finally', //
        'for', 'from', 'global', 'if', 'import', 'in', 'is', 'lambda', 'match', 'case', 'None', 'nonlocal', 'not', 'or', 'pass', 'raise',
        'return', 'True', 'try', 'while', 'with', 'yield', 'self',
      },
      types: {'int', 'float', 'str', 'bool', 'bytes', 'list', 'dict', 'set', 'tuple', 'object'},
      comment: '#',
      block: false,
      quotes: '"\'',
      extra: RegExp(r'(@[\w.]+)'),
      extraToks: const [Tok.type],
    ),
    Lang.shell: _Spec(
      keywords: {
        'if', 'then', 'else', 'elif', 'fi', 'for', 'while', 'until', 'do', 'done', 'case', 'esac', 'in', 'function', 'return', 'export', //
        'local', 'readonly', 'source', 'unset', 'exit',
        'FROM', 'RUN', 'CMD', 'COPY', 'ADD', 'ENV', 'ARG', 'WORKDIR', 'EXPOSE', 'ENTRYPOINT', 'USER', 'VOLUME', 'LABEL', 'AS',
      },
      comment: '#',
      block: false,
      quotes: '"\'',
      calls: false,
      extra: RegExp(r'(\$\{[^}]*\}|\$\w+|\$[@#?$!*0-9])'),
      extraToks: const [Tok.type],
    ),
    Lang.sql: _Spec(
      keywords: {
        'select', 'from', 'where', 'and', 'or', 'not', 'null', 'is', 'in', 'as', 'on', 'join', 'left', 'right', 'inner', 'outer', 'full', //
        'group', 'by', 'order', 'having', 'limit', 'offset', 'insert', 'into', 'values', 'update', 'set', 'delete', 'create', 'table', 'index',
        'view', 'drop', 'alter', 'add', 'column', 'primary', 'key', 'foreign', 'references', 'unique', 'default', 'constraint', 'if', 'exists',
        'begin', 'commit', 'rollback', 'returning', 'distinct', 'case', 'when', 'then', 'else', 'end', 'true', 'false', 'with', 'union', 'all',
        'asc', 'desc', 'cascade', 'like', 'between',
      },
      types: {
        'int', 'integer', 'bigint', 'smallint', 'text', 'varchar', 'char', 'boolean', 'bool', 'numeric', 'decimal', 'date', 'timestamp', //
        'timestamptz', 'uuid', 'jsonb', 'json', 'serial', 'bigserial', 'real',
      },
      comment: '--',
      quotes: '\'',
      ignoreCase: true,
    ),
    Lang.proto: _Spec(
      keywords: {'syntax', 'package', 'import', 'option', 'message', 'enum', 'service', 'rpc', 'returns', 'stream', 'repeated', 'optional', 'oneof', 'map', 'reserved', 'true', 'false'},
      types: {'string', 'bytes', 'bool', 'int32', 'int64', 'uint32', 'uint64', 'sint32', 'sint64', 'fixed32', 'fixed64', 'float', 'double'},
      quotes: '"',
    ),
    Lang.swift: _Spec(
      keywords: {
        'actor', 'as', 'associatedtype', 'async', 'await', 'break', 'case', 'catch', 'class', 'continue', 'default', 'defer', 'deinit', 'do', //
        'else', 'enum', 'extension', 'false', 'fileprivate', 'for', 'func', 'guard', 'if', 'import', 'in', 'init', 'inout', 'internal', 'is',
        'let', 'nil', 'open', 'private', 'protocol', 'public', 'repeat', 'return', 'self', 'Self', 'some', 'static', 'struct', 'super',
        'switch', 'throw', 'throws', 'true', 'try', 'typealias', 'var', 'where', 'while',
      },
      quotes: '"',
      extra: RegExp(r'(@\w+)'),
      extraToks: const [Tok.type],
    ),
    Lang.kotlin: _Spec(
      keywords: {
        'as', 'break', 'class', 'companion', 'const', 'continue', 'data', 'do', 'else', 'enum', 'false', 'for', 'fun', 'if', 'import', 'in', //
        'interface', 'internal', 'is', 'lateinit', 'null', 'object', 'open', 'override', 'package', 'private', 'protected', 'public', 'return',
        'sealed', 'super', 'suspend', 'this', 'throw', 'true', 'try', 'typealias', 'val', 'var', 'when', 'while',
      },
      quotes: '"\'',
      extra: RegExp(r'(@\w+)'),
      extraToks: const [Tok.type],
    ),
    Lang.java: _Spec(
      keywords: {
        'abstract', 'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'do', 'else', 'enum', 'extends', 'final', //
        'finally', 'for', 'if', 'implements', 'import', 'instanceof', 'interface', 'native', 'new', 'null', 'package', 'private', 'protected',
        'public', 'record', 'return', 'static', 'super', 'switch', 'synchronized', 'this', 'throw', 'throws', 'true', 'false', 'try', 'var',
        'void', 'volatile', 'while',
      },
      types: {'int', 'long', 'short', 'byte', 'char', 'float', 'double', 'boolean'},
      quotes: '"\'',
      extra: RegExp(r'(@\w+)'),
      extraToks: const [Tok.type],
    ),
    Lang.c: _Spec(
      keywords: {
        'auto', 'break', 'case', 'class', 'const', 'constexpr', 'continue', 'default', 'delete', 'do', 'else', 'enum', 'extern', 'false', //
        'for', 'goto', 'if', 'inline', 'namespace', 'new', 'nullptr', 'private', 'protected', 'public', 'return', 'sizeof', 'static',
        'struct', 'switch', 'template', 'this', 'true', 'typedef', 'typename', 'union', 'using', 'virtual', 'volatile', 'while', 'NULL',
      },
      types: {'int', 'char', 'short', 'long', 'float', 'double', 'void', 'bool', 'unsigned', 'signed', 'size_t'},
      quotes: '"\'',
      extra: RegExp(r'(^\s*#\s*\w+)'),
      extraToks: const [Tok.kw],
    ),
  };

  static final _upper = RegExp(r'^[A-Z]');

  static List<Seg> _code(_Spec spec, String line) {
    final out = <Seg>[];
    final n = spec.extraToks.length;
    for (final m in spec.re.allMatches(line)) {
      final extra = [for (var i = 0; i < n; i++) if (m[i + 1] != null) i].firstOrNull;
      if (extra != null) {
        out.add((m[extra + 1]!, spec.extraToks[extra]));
        continue;
      }
      final g = n + 1;
      if (m[g] != null) {
        out.add((m[g]!, Tok.com));
      } else if (m[g + 1] != null) {
        out.add((m[g + 1]!, Tok.str));
      } else if (m[g + 2] != null) {
        out.add((m[g + 2]!, Tok.num));
      } else if (m[g + 3] != null) {
        final w = m[g + 3]!;
        final word = spec.ignoreCase ? w.toLowerCase() : w;
        final next = m.end < line.length ? line[m.end] : '';
        final Tok k;
        if (spec.keywords.contains(word)) {
          k = Tok.kw;
        } else if (spec.types.contains(word)) {
          k = Tok.type;
        } else if ((spec.calls && next == '(') || (spec.macros && next == '!')) {
          k = Tok.fn;
        } else if (!spec.ignoreCase && _upper.hasMatch(w)) {
          k = Tok.type;
        } else {
          k = Tok.text;
        }
        out.add((w, k));
      } else if (m[g + 4] != null) {
        out.add((m[g + 4]!, Tok.text));
      } else {
        out.add((m[g + 5]!, Tok.punct));
      }
    }
    return _merge(out);
  }

  // ---- TOML ----

  static final _tomlSection = RegExp(r'^(\s*)(\[\[?[^\]]*\]\]?)(.*)$');
  static final _tomlKey = RegExp(r'^(\s*)([A-Za-z0-9_.\-"]+)(\s*=)(.*)$');
  static final _tomlValue = RegExp(r'''(#.*$)|("(?:[^"\\]|\\.)*"?|'[^']*'?)|(\b(?:true|false)\b|[+-]?\d[\d_:.\-TZ+e]*)|([A-Za-z_][\w\-]*)|(\s+)|(.)''');

  static List<Seg> _toml(String line) {
    if (line.trimLeft().startsWith('#')) return [(line, Tok.com)];
    final out = <Seg>[];
    var rest = line;
    final section = _tomlSection.firstMatch(line);
    final key = section == null ? _tomlKey.firstMatch(line) : null;
    if (section != null) {
      out
        ..add((section[1]!, Tok.text))
        ..add((section[2]!, Tok.head));
      rest = section[3]!;
    } else if (key != null) {
      out
        ..add((key[1]!, Tok.text))
        ..add((key[2]!, Tok.key))
        ..add((key[3]!, Tok.punct));
      rest = key[4]!;
    }
    for (final m in _tomlValue.allMatches(rest)) {
      if (m[1] != null) {
        out.add((m[1]!, Tok.com));
      } else if (m[2] != null) {
        out.add((m[2]!, Tok.str));
      } else if (m[3] != null) {
        out.add((m[3]!, Tok.num));
      } else if (m[4] != null || m[5] != null) {
        out.add((m[4] ?? m[5]!, Tok.text));
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

/// How [Syntax] tokenizes a C-like language. Lines are tokenized one at a
/// time: the inner lines of a block comment are recognized by their
/// leading `*`.
class _Spec {
  _Spec({
    required this.keywords,
    this.types = const {},
    this.comment = '//',
    this.block = true,
    this.quotes = '"',
    this.calls = true,
    this.macros = false,
    this.ignoreCase = false,
    this.extra,
    this.extraToks = const [],
  });

  final Set<String> keywords;
  final Set<String> types;

  /// What starts a line comment.
  final String comment;

  /// Whether there are `/* */` comments.
  final bool block;

  /// The characters that delimit strings.
  final String quotes;

  /// Whether `name(` is a call and `name!` a macro.
  final bool calls;
  final bool macros;
  final bool ignoreCase;

  /// Language-specific tokens, tried first: one group per [extraToks].
  final RegExp? extra;
  final List<Tok> extraToks;

  late final RegExp re = RegExp([
    if (extra != null) extra!.pattern,
    '(${[
      '${RegExp.escape(comment)}.*\$',
      if (block) ...[r'/\*.*?(?:\*/|$)', r'^\s*\*(?:[\s/].*)?$'],
    ].join('|')})',
    // An unclosed string runs to the end of the line.
    '(${[for (final q in quotes.split('')) '$q(?:[^$q\\\\]|\\\\.)*$q?'].join('|')})',
    r'(\b0[xXbBoO][0-9a-fA-F_]+\b|\b\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?\w*)',
    r'([A-Za-z_][A-Za-z0-9_]*)',
    r'(\s+)',
    '(.)',
  ].join('|'));
}
