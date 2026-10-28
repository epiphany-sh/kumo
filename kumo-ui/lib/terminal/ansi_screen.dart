import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'cell_width.dart';
import 'terminal_surface.dart';

/// Minimal VT100/xterm screen for M1 (kumo.md §10): enough for shells,
/// prompts and simple TUIs. M2 replaces it with the daemon-side emulator.
///
/// Feed it raw PTY bytes; read a [TermBuffer] snapshot once per frame.
/// Supported: UTF-8, C0 controls, cursor movement, erase (with background
/// color, like xterm), insert/delete, scroll regions, alternate screen, SGR
/// (16 colors as themed roles, 256 and truecolor exact, bold, dim, italic,
/// underline, inverse), wide glyphs, cursor visibility and DSR/DA replies.
class AnsiScreen {
  AnsiScreen({int cols = 80, int rows = 24, this.maxScrollback = 5000, this.onReply})
      : _cols = math.max(1, cols),
        _rows = math.max(1, rows) {
    _grid = List.generate(_rows, (_) => _Row(_cols));
    _decoder = const Utf8Decoder(allowMalformed: true).startChunkedConversion(_RuneSink(_onRune));
  }

  final int maxScrollback;

  /// Bytes the terminal must send back to the program (cursor reports).
  final void Function(List<int> bytes)? onReply;

  int _cols;
  int _rows;
  int get cols => _cols;
  int get rows => _rows;

  late List<_Row> _grid;
  final List<TermLine> _scrollback = [];

  int _cx = 0;
  int _cy = 0;
  bool _wrapPending = false;
  final _pen = _Pen();
  bool _cursorVisible = true;
  bool _appCursorKeys = false;
  bool _bracketedPaste = false;
  int _top = 0;
  int _bottom = 0x7fffffff; // clamped to rows - 1

  (int, int, _Pen)? _saved;
  List<_Row>? _mainGrid;
  (int, int)? _mainCursor;

  late final ByteConversionSink _decoder;
  _State _state = _State.ground;
  final _params = StringBuffer();
  String _private = '';

  /// DECCKM: arrows send `ESC O x` instead of `ESC [ x` (vim, less…).
  bool get applicationCursorKeys => _appCursorKeys;

  /// The program wants pasted text wrapped in `ESC [200~ … ESC [201~`.
  bool get bracketedPaste => _bracketedPaste;

  int get _scrollBottom => math.min(_bottom, _rows - 1);
  bool get _onAltScreen => _mainGrid != null;

  void feed(List<int> bytes) => _decoder.add(bytes);

  /// Screen as lines: scrollback, then every row of the grid. The cursor is
  /// an index into those lines.
  TermBuffer snapshot({int seq = 0}) {
    final lines = <TermLine>[..._scrollback];
    for (final row in _grid) {
      lines.add(row.line);
    }
    return TermBuffer(
      lines,
      cursorVisible: _cursorVisible,
      cursor: (_scrollback.length + _cy, math.min(_cx, _cols - 1)),
      seq: seq,
    );
  }

  void resize(int cols, int rows) {
    cols = math.max(1, cols);
    rows = math.max(1, rows);
    if (cols == _cols && rows == _rows) return;
    // Keep the cursor row on screen: push rows above it into scrollback.
    final overflow = _cy - (rows - 1);
    for (var i = 0; i < overflow; i++) {
      _pushScrollback(_grid.removeAt(0));
    }
    if (overflow > 0) _cy -= overflow;
    for (final row in _grid) {
      row.resize(cols);
    }
    while (_grid.length > rows) {
      _grid.removeLast();
    }
    while (_grid.length < rows) {
      _grid.add(_Row(cols));
    }
    _mainGrid = null;
    _mainCursor = null;
    _cols = cols;
    _rows = rows;
    _top = 0;
    _bottom = 0x7fffffff;
    _cx = math.min(_cx, cols - 1);
    _cy = math.min(_cy, rows - 1);
    _wrapPending = false;
  }

  // ---------------------------------------------------------------------------
  // Parser
  // ---------------------------------------------------------------------------

  void _onRune(int r) {
    switch (_state) {
      case _State.ground:
        if (r == 0x1b) {
          _state = _State.escape;
        } else if (r < 0x20 || r == 0x7f) {
          _control(r);
        } else {
          _print(r);
        }
      case _State.escape:
        _escape(r);
      case _State.csi:
        if (r >= 0x30 && r <= 0x3f) {
          if (r >= 0x3c && _params.isEmpty) {
            _private = String.fromCharCode(r);
          } else {
            _params.writeCharCode(r);
          }
        } else if (r >= 0x40 && r <= 0x7e) {
          _state = _State.ground;
          _csi(r);
        } else if (r < 0x20) {
          _control(r);
        } else if (r == 0x1b) {
          _state = _State.escape;
        }
      // Intermediates (0x20–0x2f) are ignored.
      case _State.osc:
        if (r == 0x07) {
          _state = _State.ground;
        } else if (r == 0x1b) {
          _state = _State.stringEsc;
        }
      case _State.string:
        if (r == 0x1b) _state = _State.stringEsc;
        if (r == 0x07) _state = _State.ground;
      case _State.stringEsc:
        _state = r == 0x5c ? _State.ground : _State.string;
      case _State.charset:
        _state = _State.ground;
    }
  }

  void _escape(int r) {
    _state = _State.ground;
    switch (r) {
      case 0x5b: // [
        _params.clear();
        _private = '';
        _state = _State.csi;
      case 0x5d: // ]
        _state = _State.osc;
      case 0x50 || 0x58 || 0x5e || 0x5f: // P X ^ _
        _state = _State.string;
      case 0x28 || 0x29 || 0x2a || 0x2b: // ( ) * +
        _state = _State.charset;
      case 0x37: // 7
        _saveCursor();
      case 0x38: // 8
        _restoreCursor();
      case 0x44: // D
        _lineFeed();
      case 0x45: // E
        _cx = 0;
        _lineFeed();
      case 0x4d: // M
        _reverseIndex();
      case 0x63: // c
        _reset();
    }
  }

  void _control(int r) {
    switch (r) {
      case 0x0d:
        _cx = 0;
        _wrapPending = false;
      case 0x0a || 0x0b || 0x0c:
        _lineFeed();
      case 0x08:
        if (_cx > 0) _cx--;
        _wrapPending = false;
      case 0x09:
        _cx = math.min(_cols - 1, (_cx ~/ 8 + 1) * 8);
    }
  }

  void _print(int rune) {
    final width = termCellWidth(rune);
    if (width == 0) return; // Combining marks / joiners: not composed (M1).
    if (_wrapPending || (width == 2 && _cx == _cols - 1 && _cols > 1)) {
      _cx = 0;
      _lineFeed();
      _wrapPending = false;
    }
    final row = _grid[_cy];
    row.set(_cx, rune, _pen);
    if (width == 2 && _cx + 1 < _cols) row.set(_cx + 1, _Row.continuation, _pen);
    final next = _cx + width;
    if (next >= _cols) {
      _cx = _cols - 1;
      _wrapPending = true;
    } else {
      _cx = next;
    }
  }

  List<int> _args() {
    if (_params.isEmpty) return const [];
    return [for (final p in _params.toString().split(';')) int.tryParse(p.split(':').first) ?? 0];
  }

  void _csi(int finalByte) {
    final a = _args();
    int arg(int i, [int fallback = 1]) => (i < a.length && a[i] != 0) ? a[i] : fallback;
    if (_private == '?') {
      if (finalByte == 0x68 || finalByte == 0x6c) _privateMode(a, finalByte == 0x68);
      return;
    }
    if (_private.isNotEmpty) return; // e.g. CSI > c
    _wrapPending = false;
    switch (String.fromCharCode(finalByte)) {
      case 'A':
        _cy = math.max(_cy <= _scrollBottom && _cy >= _top ? _top : 0, _cy - arg(0));
      case 'B' || 'e':
        _cy = math.min(_cy >= _top && _cy <= _scrollBottom ? _scrollBottom : _rows - 1, _cy + arg(0));
      case 'C' || 'a':
        _cx = math.min(_cols - 1, _cx + arg(0));
      case 'D':
        _cx = math.max(0, _cx - arg(0));
      case 'E':
        _cx = 0;
        _cy = math.min(_rows - 1, _cy + arg(0));
      case 'F':
        _cx = 0;
        _cy = math.max(0, _cy - arg(0));
      case 'G' || '`':
        _cx = (arg(0) - 1).clamp(0, _cols - 1);
      case 'd':
        _cy = (arg(0) - 1).clamp(0, _rows - 1);
      case 'H' || 'f':
        _cy = (arg(0) - 1).clamp(0, _rows - 1);
        _cx = (arg(1) - 1).clamp(0, _cols - 1);
      case 'J':
        _eraseDisplay(arg(0, 0));
      case 'K':
        _eraseLine(arg(0, 0));
      case 'X':
        _grid[_cy].clear(_cx, math.min(_cols, _cx + arg(0)), _pen.bg);
      case 'P':
        _grid[_cy].delete(_cx, arg(0), _pen.bg);
      case '@':
        _grid[_cy].insert(_cx, arg(0), _pen.bg);
      case 'L':
        if (_cy >= _top && _cy <= _scrollBottom) _scrollDown(arg(0), from: _cy);
      case 'M':
        if (_cy >= _top && _cy <= _scrollBottom) _scrollUp(arg(0), from: _cy, keep: false);
      case 'S':
        _scrollUp(arg(0), from: _top, keep: false);
      case 'T':
        _scrollDown(arg(0), from: _top);
      case 'm':
        _sgr(a);
      case 'r':
        final top = arg(0) - 1;
        final bottom = arg(1, _rows) - 1;
        if (top < bottom && bottom < _rows) {
          _top = top;
          _bottom = bottom;
          _cx = 0;
          _cy = 0;
        }
      case 's':
        _saveCursor();
      case 'u':
        _restoreCursor();
      case 'n':
        if (arg(0, 0) == 6) onReply?.call(utf8.encode('\x1b[${_cy + 1};${_cx + 1}R'));
        if (arg(0, 0) == 5) onReply?.call(utf8.encode('\x1b[0n'));
      case 'c':
        onReply?.call(utf8.encode('\x1b[?1;2c'));
    }
  }

  void _privateMode(List<int> modes, bool on) {
    for (final mode in modes) {
      switch (mode) {
        case 1:
          _appCursorKeys = on;
        case 25:
          _cursorVisible = on;
        case 2004:
          _bracketedPaste = on;
        case 1049 || 1047 || 47:
          on ? _enterAltScreen() : _leaveAltScreen();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Screen operations
  // ---------------------------------------------------------------------------

  void _lineFeed() {
    if (_cy == _scrollBottom) {
      _scrollUp(1, from: _top, keep: true);
    } else if (_cy < _rows - 1) {
      _cy++;
    }
  }

  void _reverseIndex() {
    if (_cy == _top) {
      _scrollDown(1, from: _top);
    } else if (_cy > 0) {
      _cy--;
    }
  }

  /// Scrolls rows `from.._scrollBottom` up by [n]. Rows leaving the top of
  /// the full main screen go to scrollback when [keep].
  void _scrollUp(int n, {required int from, required bool keep}) {
    final bottom = _scrollBottom;
    n = math.min(n, bottom - from + 1);
    for (var i = 0; i < n; i++) {
      final row = _grid.removeAt(from);
      if (keep && from == 0 && !_onAltScreen) _pushScrollback(row);
      _grid.insert(bottom, _Row(_cols, _pen.bg));
    }
  }

  void _scrollDown(int n, {required int from}) {
    final bottom = _scrollBottom;
    n = math.min(n, bottom - from + 1);
    for (var i = 0; i < n; i++) {
      _grid.removeAt(bottom);
      _grid.insert(from, _Row(_cols, _pen.bg));
    }
  }

  void _pushScrollback(_Row row) {
    _scrollback.add(row.line);
    if (_scrollback.length > maxScrollback) _scrollback.removeRange(0, _scrollback.length - maxScrollback);
  }

  void _eraseDisplay(int mode) {
    final bg = _pen.bg;
    switch (mode) {
      case 0:
        _grid[_cy].clear(_cx, _cols, bg);
        for (var y = _cy + 1; y < _rows; y++) {
          _grid[y].clear(0, _cols, bg);
        }
      case 1:
        _grid[_cy].clear(0, _cx + 1, bg);
        for (var y = 0; y < _cy; y++) {
          _grid[y].clear(0, _cols, bg);
        }
      case 2:
        for (final row in _grid) {
          row.clear(0, _cols, bg);
        }
      case 3:
        _scrollback.clear();
    }
  }

  void _eraseLine(int mode) {
    final bg = _pen.bg;
    switch (mode) {
      case 0:
        _grid[_cy].clear(_cx, _cols, bg);
      case 1:
        _grid[_cy].clear(0, _cx + 1, bg);
      case 2:
        _grid[_cy].clear(0, _cols, bg);
    }
  }

  void _saveCursor() => _saved = (_cx, _cy, _pen.copy());

  void _restoreCursor() {
    final saved = _saved;
    if (saved == null) return;
    _cx = math.min(saved.$1, _cols - 1);
    _cy = math.min(saved.$2, _rows - 1);
    _pen.setFrom(saved.$3);
    _wrapPending = false;
  }

  void _enterAltScreen() {
    if (_onAltScreen) return;
    _mainGrid = _grid;
    _mainCursor = (_cx, _cy);
    _grid = List.generate(_rows, (_) => _Row(_cols));
    _cx = 0;
    _cy = 0;
  }

  void _leaveAltScreen() {
    final main = _mainGrid;
    if (main == null) return;
    _grid = main;
    _mainGrid = null;
    final (x, y) = _mainCursor ?? (0, 0);
    _cx = math.min(x, _cols - 1);
    _cy = math.min(y, _rows - 1);
    _mainCursor = null;
  }

  void _reset() {
    _grid = List.generate(_rows, (_) => _Row(_cols));
    _mainGrid = null;
    _cx = 0;
    _cy = 0;
    _pen.reset();
    _top = 0;
    _bottom = 0x7fffffff;
    _cursorVisible = true;
    _appCursorKeys = false;
    _bracketedPaste = false;
  }

  // ---------------------------------------------------------------------------
  // SGR
  // ---------------------------------------------------------------------------

  void _sgr(List<int> a) {
    if (a.isEmpty) {
      _pen.reset();
      return;
    }
    for (var i = 0; i < a.length; i++) {
      final p = a[i];
      switch (p) {
        case 0:
          _pen.reset();
        case 1:
          _pen.set(_Attr.bold, true);
        case 2:
          _pen.set(_Attr.dim, true);
        case 3:
          _pen.set(_Attr.italic, true);
        case 4:
          _pen.set(_Attr.underline, true);
        case 7:
          _pen.set(_Attr.inverse, true);
        case 22:
          _pen
            ..set(_Attr.bold, false)
            ..set(_Attr.dim, false);
        case 23:
          _pen.set(_Attr.italic, false);
        case 24:
          _pen.set(_Attr.underline, false);
        case 27:
          _pen.set(_Attr.inverse, false);
        case >= 30 && <= 37:
          _pen.fg = _Color.ansi(p - 30);
        case >= 90 && <= 97:
          _pen.fg = _Color.ansi(p - 90 + 8);
        case 39:
          _pen.fg = _Color.none;
        case >= 40 && <= 47:
          _pen.bg = _Color.ansi(p - 40);
        case >= 100 && <= 107:
          _pen.bg = _Color.ansi(p - 100 + 8);
        case 49:
          _pen.bg = _Color.none;
        case 38 || 48:
          final (color, used) = _extendedColor(a, i + 1);
          if (color != null) {
            if (p == 38) {
              _pen.fg = color;
            } else {
              _pen.bg = color;
            }
          }
          i += used;
      }
    }
  }

  /// Parses `5;n` or `2;r;g;b`: the color code and how many params it used.
  (int?, int) _extendedColor(List<int> a, int i) {
    if (i >= a.length) return (null, 0);
    if (a[i] == 5 && i + 1 < a.length) return (_Color.indexed(a[i + 1]), 2);
    if (a[i] == 2 && i + 3 < a.length) return (_Color.rgb(a[i + 1], a[i + 2], a[i + 3]), 4);
    return (null, 1);
  }
}

enum _State { ground, escape, csi, osc, string, stringEsc, charset }

/// Cell colors packed in an int: 0 = default, 1–16 = ANSI color + 1
/// (themed), `0x1000000 | rgb` = exact color.
abstract final class _Color {
  static const none = 0;
  static const _exact = 0x1000000;

  static int ansi(int index) => index + 1;
  static int rgb(int r, int g, int b) => _exact | ((r & 0xff) << 16) | ((g & 0xff) << 8) | (b & 0xff);

  /// xterm 256-color palette: 16 ANSI, a 6×6×6 cube, 24 grays.
  static int indexed(int n) {
    n = n.clamp(0, 255);
    if (n < 16) return ansi(n);
    if (n >= 232) {
      final v = 8 + (n - 232) * 10;
      return rgb(v, v, v);
    }
    const levels = [0, 95, 135, 175, 215, 255];
    final c = n - 16;
    return rgb(levels[c ~/ 36], levels[(c ~/ 6) % 6], levels[c % 6]);
  }

  static TermRole foregroundRole(int c) => (c >= 1 && c <= 16) ? _ansiRoles[c - 1] : TermRole.text;

  static int? exact(int c) => c & _exact != 0 ? c & 0xffffff : null;

  static TermColor? background(int c) {
    if (c == none) return null;
    final rgb = exact(c);
    if (rgb != null) return TermColor.rgb(rgb);
    // ANSI black as a background means black, not the dimmest text role.
    return c == ansi(0) ? const TermColor.rgb(0x000000) : TermColor.role(_ansiRoles[c - 1]);
  }

  static const _ansiRoles = [
    TermRole.text3, TermRole.err, TermRole.ok, TermRole.yellow, //
    TermRole.acc, TermRole.purple, TermRole.cyan, TermRole.text2,
    TermRole.text3, TermRole.err, TermRole.ok, TermRole.yellow,
    TermRole.acc, TermRole.purple, TermRole.cyan, TermRole.text,
  ];
}

/// SGR attribute bits.
abstract final class _Attr {
  static const bold = 1;
  static const dim = 2;
  static const italic = 4;
  static const underline = 8;
  static const inverse = 16;
}

/// Current graphic rendition.
class _Pen {
  int fg = _Color.none;
  int bg = _Color.none;
  int attrs = 0;

  void reset() {
    fg = _Color.none;
    bg = _Color.none;
    attrs = 0;
  }

  void set(int attr, bool on) => attrs = on ? attrs | attr : attrs & ~attr;

  _Pen copy() => _Pen()..setFrom(this);

  void setFrom(_Pen other) {
    fg = other.fg;
    bg = other.bg;
    attrs = other.attrs;
  }
}

/// One screen row of cells. Caches its [TermLine] until the next change.
class _Row {
  _Row(int cols, [int bg = _Color.none])
      : _runes = Uint32List(cols)..fillRange(0, cols, 0x20),
        _fg = Uint32List(cols),
        _bg = Uint32List(cols)..fillRange(0, cols, bg),
        _attrs = Uint8List(cols);

  /// Second cell of a wide glyph.
  static const continuation = 0;

  Uint32List _runes;
  Uint32List _fg;
  Uint32List _bg;
  Uint8List _attrs;
  TermLine? _line;

  void set(int x, int rune, _Pen pen) {
    _runes[x] = rune;
    _fg[x] = pen.fg;
    _bg[x] = pen.bg;
    _attrs[x] = pen.attrs;
    _line = null;
  }

  /// Erased cells keep the current background color (xterm BCE).
  void clear(int from, int to, int bg) {
    if (from >= to) return;
    _runes.fillRange(from, to, 0x20);
    _fg.fillRange(from, to, _Color.none);
    _bg.fillRange(from, to, bg);
    _attrs.fillRange(from, to, 0);
    _line = null;
  }

  void delete(int x, int n, int bg) {
    final cols = _runes.length;
    n = math.min(n, cols - x);
    _runes.setRange(x, cols - n, _runes, x + n);
    _fg.setRange(x, cols - n, _fg, x + n);
    _bg.setRange(x, cols - n, _bg, x + n);
    _attrs.setRange(x, cols - n, _attrs, x + n);
    clear(cols - n, cols, bg);
  }

  void insert(int x, int n, int bg) {
    final cols = _runes.length;
    n = math.min(n, cols - x);
    _runes.setRange(x + n, cols, Uint32List.fromList(_runes.sublist(x, cols - n)));
    _fg.setRange(x + n, cols, Uint32List.fromList(_fg.sublist(x, cols - n)));
    _bg.setRange(x + n, cols, Uint32List.fromList(_bg.sublist(x, cols - n)));
    _attrs.setRange(x + n, cols, Uint8List.fromList(_attrs.sublist(x, cols - n)));
    clear(x, x + n, bg);
  }

  void resize(int cols) {
    final old = _runes.length;
    if (cols == old) return;
    final keep = math.min(cols, old);
    _runes = (Uint32List(cols)..fillRange(0, cols, 0x20))..setRange(0, keep, _runes);
    _fg = Uint32List(cols)..setRange(0, keep, _fg);
    _bg = Uint32List(cols)..setRange(0, keep, _bg);
    _attrs = Uint8List(cols)..setRange(0, keep, _attrs);
    _line = null;
  }

  TermLine get line => _line ??= _build();

  bool _sameStyle(int a, int b) => _fg[a] == _fg[b] && _bg[a] == _bg[b] && _attrs[a] == _attrs[b];

  bool _isBlank(int x) => _runes[x] == 0x20 && _bg[x] == _Color.none && _attrs[x] & _Attr.inverse == 0;

  TermLine _build() {
    var end = _runes.length;
    while (end > 0 && _isBlank(end - 1)) {
      end--;
    }
    if (end == 0) return TermLine.empty;
    final spans = <TermSpan>[];
    var start = 0;
    final text = StringBuffer();
    for (var x = 0; x <= end; x++) {
      if (x == end || !_sameStyle(x, start)) {
        final attrs = _attrs[start];
        spans.add(TermSpan.styled(
          text.toString(),
          role: _Color.foregroundRole(_fg[start]),
          rgb: _Color.exact(_fg[start]),
          background: _Color.background(_bg[start]),
          bold: attrs & _Attr.bold != 0,
          dim: attrs & _Attr.dim != 0,
          italic: attrs & _Attr.italic != 0,
          underline: attrs & _Attr.underline != 0,
          inverse: attrs & _Attr.inverse != 0,
        ));
        text.clear();
        start = x;
      }
      if (x < end && _runes[x] != continuation) text.writeCharCode(_runes[x]);
    }
    return TermLine(spans);
  }
}

/// Forwards decoded UTF-16 text to the parser rune by rune.
class _RuneSink extends StringConversionSinkBase {
  _RuneSink(this._onRune);
  final void Function(int rune) _onRune;

  @override
  void addSlice(String str, int start, int end, bool isLast) {
    for (final rune in str.substring(start, end).runes) {
      _onRune(rune);
    }
  }

  @override
  void close() {}
}
