import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    show GestureBinding, PointerPanZoomEndEvent, PointerPanZoomStartEvent, PointerPanZoomUpdateEvent, PointerScrollEvent, PointerSignalEvent, kPrimaryButton, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../engine/grpc_terminal_surface.dart';
import '../platform/open_url.dart';

import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/context_menu.dart';
import '../widgets/kicons.dart';
import 'grid_renderer.dart';
import 'term_selection.dart';
import 'terminal_keys.dart';
import 'terminal_surface.dart';

/// Paints a [TerminalSurface] with a CustomPainter. Repaint is driven by the
/// surface's buffer listenable, so new output costs one paint, no rebuild.
///
/// Interactive surfaces get keyboard input while [active]; the pane that is
/// focused in the layout grabs the keyboard.
class TerminalCanvas extends StatefulWidget {
  const TerminalCanvas({super.key, required this.surface, this.active = false, this.fontSize = 12, this.lineHeight, this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12)});

  final TerminalSurface surface;
  final bool active;
  final double fontSize;
  /// Null: terminal spacing (1.25) for real shells, the airier 1.7 of the
  /// design mocks otherwise.
  final double? lineHeight;
  final EdgeInsets padding;

  @override
  State<TerminalCanvas> createState() => _TerminalCanvasState();
}

/// First buffer line on screen: the bottom of the buffer, or the line the
/// user scrolled to. [top] is that line counted from the session's start
/// (see [TermBuffer.dropped]); null follows the output. A full-screen
/// program, or lines re-wrapped since [reflows], show the bottom.
int visibleStart(TermBuffer b, int fit, {int? top, int reflows = 0}) {
  final maxLines = b.cursor != null ? fit : math.max(1, fit - 1);
  final bottom = math.max(0, b.lines.length - maxLines);
  if (top == null || b.altScreen || b.reflows != reflows) return bottom;
  return (top - b.dropped).clamp(0, bottom);
}

/// Fraction of a line the view sits past [visibleStart]'s line: [frac] while
/// in the history, none once that line is the bottom.
double visibleOffset(TermBuffer b, int fit, {int? top, int reflows = 0, double frac = 0}) =>
    visibleStart(b, fit, top: top, reflows: reflows) < visibleStart(b, fit) ? frac : 0;

class _TerminalCanvasState extends State<TerminalCanvas> with SingleTickerProviderStateMixin {
  int _cols = 0;
  int _rows = 0;
  final _focus = FocusNode(debugLabel: 'terminal');
  final _renderer = TerminalGridRenderer();
  bool _hasFocus = false;

  // ---- Selection: drag selects, double-click a word, triple-click the line.
  // Kept in buffer lines as of [_selDropped]; re-wrapping drops it.
  TermSelection? _sel;
  TermSelection? _unit; // the word or line a multi-click started from
  int _selDropped = 0;
  int _selReflows = 0;
  bool _dragging = false;
  int _clicks = 0;
  Duration _lastDown = Duration.zero;
  Offset _lastPos = Offset.zero;

  // ---- Scrollback: where the view is (a line and the fraction of it
  // scrolled past, so the wheel and trackpad move by pixels), the wheel's
  // leftover fraction of a line for full-screen programs, the scrollbar and
  // the autoscroll of a selection drag.
  int? _top;
  double _frac = 0;
  int _seenReflows = 0;
  double _wheelRest = 0;
  bool _barDrag = false;
  bool _barHover = false;
  bool _linkHover = false;
  Offset? _hoverAt;
  bool _barFlash = false;
  Timer? _barTimer;
  Timer? _autoScroll;
  Offset _dragAt = Offset.zero;
  double _flingVelocity = 0; // lines per second, trackpad
  Duration _lastPan = Duration.zero;
  // The coast runs on the display's frames, not a timer that beats against
  // them.
  late final Ticker _fling;
  Duration _lastCoast = Duration.zero;
  Offset _coastAt = Offset.zero;

  /// Geometry of the last layout, to map the pointer to cells.
  Size _cell = const Size(7, 15);
  Size _size = Size.zero;

  static bool get _mac => defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;

  static const _barWidth = 12.0;

  int get _fit => math.max(1, ((_size.height - widget.padding.vertical) / _cell.height).floor());

  TermBuffer get _buffer => widget.surface.buffer.value;

  /// First buffer line on screen.
  int _firstLine(TermBuffer b) => visibleStart(b, _fit, top: _top, reflows: _seenReflows);

  int _bottomLine(TermBuffer b) => visibleStart(b, _fit);

  /// Fraction of a line the view sits past [_firstLine].
  double _offset(TermBuffer b) => visibleOffset(b, _fit, top: _top, reflows: _seenReflows, frac: _frac);

  /// Lines were re-wrapped (a width change): positions in them are gone.
  void _syncReflows(TermBuffer b) {
    if (b.reflows == _seenReflows) return;
    _seenReflows = b.reflows;
    _top = null;
  }

  /// The selection in the current buffer's line numbers.
  TermSelection? _selIn(TermBuffer b) {
    final sel = _sel;
    if (sel == null || b.reflows != _selReflows) return null;
    return sel.shifted(_selDropped - b.dropped);
  }

  void _setSel(TermSelection? sel, TermBuffer b) {
    _sel = sel;
    _selDropped = b.dropped;
    _selReflows = b.reflows;
  }

  /// The boundary between cells under [local] ([cell]: the cell itself).
  TermPoint _pointAt(Offset local, {bool cell = false}) {
    final b = _buffer;
    if (b.lines.isEmpty) return const TermPoint(0, 0);
    final first = _firstLine(b);
    final row = ((local.dy - widget.padding.top) / _cell.height + _offset(b)).floor();
    final line = first + row;
    if (line >= b.lines.length) return TermPoint(b.lines.length - 1, lineWidth(b.lines.last));
    if (line < first) return TermPoint(first, 0);
    final x = (local.dx - widget.padding.left) / _cell.width;
    final width = lineWidth(b.lines[line]);
    final col = cell ? x.floor() : x.round();
    return TermPoint(line, col.clamp(0, cell ? 1 << 20 : width));
  }

  // ---- Scrolling

  /// Moves the view [delta] lines, fractions too (negative: back in
  /// history). False when it was already at that end.
  bool _scrollBy(num delta) {
    final b = _buffer;
    if (b.altScreen || delta == 0) return false;
    _syncReflows(b);
    return _scrollTo(_firstLine(b) + _offset(b) + delta);
  }

  /// Puts [line] (and the [line]'s fraction scrolled past) at the top; at
  /// the bottom the view follows the output again.
  bool _scrollTo(num line) {
    final b = _buffer;
    _syncReflows(b);
    final bottom = _bottomLine(b);
    final next = line.clamp(0, bottom).toDouble();
    final whole = next.floor();
    final top = whole >= bottom ? null : b.dropped + whole;
    final frac = top == null ? 0.0 : next - whole;
    final moved = top != _top || frac != _frac;
    setState(() {
      _top = top;
      _frac = frac;
    });
    _flashBar();
    return moved;
  }

  void _toBottom() {
    if (_top == null) return;
    setState(() => _top = null);
  }

  void _flashBar() {
    _barTimer?.cancel();
    if (!_barFlash) setState(() => _barFlash = true);
    _barTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _barFlash = false);
    });
  }

  /// Wheel or trackpad: [pixels] down (positive: toward newer output). In
  /// history on the main screen; a full-screen program gets arrows, or
  /// wheel reports when it asked for the mouse. False once the history
  /// can't go farther that way.
  bool _wheel(double pixels, Offset local) {
    final surface = widget.surface;
    final grpc = surface is GrpcTerminalSurface ? surface : null;
    final b = _buffer;
    if (grpc != null && (grpc.mouseTracking || b.altScreen)) {
      // The program moves by whole lines: keep the rest for the next event.
      _wheelRest += pixels / _cell.height;
      final lines = _wheelRest.truncate();
      if (lines == 0) return true;
      _wheelRest -= lines;
      final up = lines < 0;
      final col = ((local.dx - widget.padding.left) / _cell.width).floor().clamp(0, _cols - 1);
      final row = ((local.dy - widget.padding.top) / _cell.height).floor().clamp(0, _rows - 1);
      final once = grpc.mouseTracking
          ? wheelReport(up: up, col: col, row: row, sgr: grpc.sgrMouse)
          : utf8.encode(grpc.applicationCursorKeys ? '\x1bO${up ? 'A' : 'B'}' : '\x1b[${up ? 'A' : 'B'}');
      final bytes = <int>[for (var i = 0; i < math.min(lines.abs(), 12); i++) ...once];
      grpc.sendBytes(bytes);
      return true;
    }
    return _scrollBy(pixels / _cell.height);
  }

  void _signal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final scroll = event as PointerScrollEvent;
      _stopFling();
      _wheel(scroll.scrollDelta.dy, scroll.localPosition);
    });
  }

  void _panStart(PointerPanZoomStartEvent e) {
    _stopFling();
    _flingVelocity = 0;
    _lastPan = e.timeStamp;
  }

  /// Trackpad: content follows the fingers.
  void _panUpdate(PointerPanZoomUpdateEvent e) {
    final pixels = -e.localPanDelta.dy;
    final dt = (e.timeStamp - _lastPan).inMicroseconds / 1e6;
    _lastPan = e.timeStamp;
    if (dt > 0) _flingVelocity = 0.7 * _flingVelocity + 0.3 * (pixels / _cell.height / dt);
    _wheel(pixels, e.localPosition);
  }

  /// Trackpad lift: the scroll coasts and slows down, like any macOS view.
  void _panEnd(PointerPanZoomEndEvent e) {
    if (_flingVelocity.abs() < 8 || _buffer.altScreen) return;
    _coastAt = e.localPosition;
    _lastCoast = Duration.zero;
    _stopFling();
    _fling.start();
  }

  /// One frame of the coast: as far as the velocity carries it since the
  /// last frame, slowing down the same per second at 60 or 120 Hz.
  void _coast(Duration elapsed) {
    final dt = (elapsed - _lastCoast).inMicroseconds / 1e6;
    _lastCoast = elapsed;
    if (dt <= 0) return;
    _flingVelocity *= math.pow(0.93, dt / 0.016);
    if (_flingVelocity.abs() < 2 || !_wheel(_flingVelocity * dt * _cell.height, _coastAt)) _stopFling();
  }

  void _stopFling() {
    if (_fling.isActive) _fling.stop();
  }

  bool _onBar(Offset local) => local.dx >= _size.width - _barWidth && _buffer.lines.length > _fit && !_buffer.altScreen;

  /// Scrollbar drag: the thumb's center follows the pointer.
  void _dragBar(Offset local) {
    final b = _buffer;
    final bottom = _bottomLine(b);
    if (bottom <= 0) return;
    final track = _size.height - 8;
    final thumb = scrollThumbExtent(track, _fit, b.lines.length);
    final t = ((local.dy - 4 - thumb / 2) / math.max(1, track - thumb)).clamp(0.0, 1.0);
    _scrollTo(t * bottom);
  }

  // ---- Links: Shift-click (or ⌘-click on macOS, Ctrl-click elsewhere)
  // opens the URL under the pointer.

  static bool get _linkModifier {
    final keys = HardwareKeyboard.instance;
    return keys.isShiftPressed || (_mac ? keys.isMetaPressed : keys.isControlPressed);
  }

  String? _linkAt(Offset local) {
    if (!_linkModifier || _onBar(local)) return null;
    return linkAt(_buffer.lines, _pointAt(local, cell: true))?.$2;
  }

  /// Pressing or letting go of the modifier over a link swaps the cursor
  /// without the mouse moving.
  bool _modifierChanged(KeyEvent _) {
    final at = _hoverAt;
    if (at != null && mounted) _hover(at);
    return false;
  }

  void _hover(Offset local) {
    final bar = _onBar(local);
    final link = _linkAt(local) != null;
    if (bar != _barHover || link != _linkHover) {
      setState(() {
        _barHover = bar;
        _linkHover = link;
      });
    }
  }

  // ---- Selection and pointer

  void _down(PointerDownEvent e) {
    _focus.requestFocus();
    _stopFling();
    if (e.buttons == kSecondaryButton) {
      _menu(e.position);
      return;
    }
    if (e.buttons != kPrimaryButton) return;
    final url = _linkAt(e.localPosition);
    if (url != null) {
      openUrl(url);
      return;
    }
    if (_onBar(e.localPosition)) {
      setState(() => _barDrag = true);
      _dragBar(e.localPosition);
      return;
    }
    // Clicks in quick succession at the same spot count up: 2 word, 3 line.
    final quick = e.timeStamp - _lastDown < const Duration(milliseconds: 450) && (e.localPosition - _lastPos).distance < 5;
    _clicks = quick ? (_clicks % 3) + 1 : 1;
    _lastDown = e.timeStamp;
    _lastPos = e.localPosition;
    final b = _buffer;
    final lines = b.lines;
    setState(() {
      _dragging = true;
      switch (_clicks) {
        case 2:
          _unit = wordAt(lines, _pointAt(e.localPosition, cell: true));
          _setSel(_unit, b);
        case 3:
          _unit = lineAt(lines, _pointAt(e.localPosition).line);
          _setSel(_unit, b);
        default:
          _unit = null;
          final p = _pointAt(e.localPosition);
          _setSel(TermSelection(p, p), b);
      }
    });
  }

  void _move(PointerMoveEvent e) {
    if (_barDrag) {
      _dragBar(e.localPosition);
      return;
    }
    if (!_dragging || e.buttons != kPrimaryButton) return;
    _dragAt = e.localPosition;
    _extendTo(e.localPosition);
    // Past the top or bottom edge, the view scrolls and the selection
    // follows, faster the farther the pointer is.
    final above = widget.padding.top - e.localPosition.dy;
    final below = e.localPosition.dy - (_size.height - widget.padding.bottom);
    if (above > 0 || below > 0) {
      _autoScroll ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
        final up = widget.padding.top - _dragAt.dy;
        final down = _dragAt.dy - (_size.height - widget.padding.bottom);
        if (!mounted || !_dragging || (up <= 0 && down <= 0)) {
          _stopAutoScroll();
          return;
        }
        final speed = 1 + ((up > 0 ? up : down) / _cell.height).floor();
        _scrollBy(up > 0 ? -speed : speed);
        _extendTo(_dragAt);
      });
    } else {
      _stopAutoScroll();
    }
  }

  void _extendTo(Offset local) {
    final b = _buffer;
    final p = _pointAt(local);
    final unit = _unit?.shifted(_selDropped - b.dropped);
    final sel = _selIn(b);
    setState(() {
      if (unit == null) {
        _setSel(TermSelection(sel?.anchor ?? p, p), b);
      } else {
        // Dragging after a double/triple click keeps the word or line.
        _setSel(p.compareTo(unit.start) < 0 ? TermSelection(unit.end, p) : TermSelection(unit.start, p.compareTo(unit.end) < 0 ? unit.end : p), b);
        _unit = unit;
      }
    });
  }

  void _stopAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  void _up(PointerEvent e) {
    _stopAutoScroll();
    if (_barDrag) {
      setState(() => _barDrag = false);
      return;
    }
    if (!_dragging) return;
    setState(() {
      _dragging = false;
      if (_sel?.isEmpty ?? false) _sel = null;
    });
  }

  String get _selectedText {
    final b = _buffer;
    final sel = _selIn(b);
    return sel == null ? '' : selectedText(b.lines, sel);
  }

  void _copy() {
    final text = _selectedText;
    if (text.isNotEmpty) Clipboard.setData(ClipboardData(text: text));
  }

  void _paste() {
    final surface = widget.surface;
    if (!surface.interactive) return;
    final grpc = surface is GrpcTerminalSurface ? surface : null;
    Clipboard.getData(Clipboard.kTextPlain).then((data) {
      final text = data?.text;
      if (text != null && text.isNotEmpty) {
        _toBottom();
        surface.sendBytes(terminalPaste(text, bracketed: grpc?.bracketedPaste ?? false));
      }
    });
  }

  void _selectAll() {
    final b = _buffer;
    final lines = b.lines;
    if (lines.isEmpty) return;
    setState(() => _setSel(TermSelection(const TermPoint(0, 0), TermPoint(lines.length - 1, lineWidth(lines.last))), b));
  }

  void _clearScrollback() {
    final surface = widget.surface;
    if (surface is! GrpcTerminalSurface) return;
    surface.clearScrollback();
    setState(() {
      _top = null;
      _sel = null;
    });
  }

  void _menu(Offset at) {
    final has = _selectedText.isNotEmpty;
    final mod = _mac ? '⌘' : 'Ctrl+Shift+';
    final canClear = widget.surface is GrpcTerminalSurface;
    showKMenu(
      context,
      position: at,
      builder: (context, close) {
        void then(VoidCallback f) {
          close();
          f();
        }

        return KMenuPanel(width: 200, children: [
          KMenuItem(icon: KIcons.copy, label: 'Copy', shortcut: '${mod}C', onTap: has ? () => then(_copy) : null),
          if (widget.surface.interactive) KMenuItem(icon: KIcons.paste, label: 'Paste', shortcut: '${mod}V', onTap: () => then(_paste)),
          KMenuItem(icon: KIcons.selectAll, label: 'Select all', shortcut: _mac ? '⌘A' : null, onTap: () => then(_selectAll)),
          if (canClear) KMenuItem(icon: KIcons.trash, label: 'Clear scrollback', onTap: () => then(_clearScrollback)),
        ]);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fling = createTicker(_coast);
    HardwareKeyboard.instance.addHandler(_modifierChanged);
    _focus.addListener(() => setState(() => _hasFocus = _focus.hasFocus));
    if (widget.active) _grabKeyboard();
  }

  @override
  void didUpdateWidget(TerminalCanvas old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _grabKeyboard();
    if (widget.surface != old.surface) {
      _top = null;
      _sel = null;
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_modifierChanged);
    _barTimer?.cancel();
    _stopAutoScroll();
    _fling.dispose();
    _focus.dispose();
    _renderer.dispose();
    super.dispose();
  }

  void _grabKeyboard() {
    if (!widget.surface.interactive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// Scrollback keys: Shift+PageUp/PageDown a page, Shift+Home/End the
  /// ends; on macOS also ⌘↑/⌘↓ a line and ⌘Home/⌘End the ends.
  bool _scrollKey(KeyEvent event) {
    if (event is KeyUpEvent || _buffer.altScreen) return false;
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    final page = math.max(1, _fit - 1);
    if (keys.isShiftPressed && !keys.isMetaPressed && !keys.isControlPressed) {
      if (key == LogicalKeyboardKey.pageUp) {
        _scrollBy(-page);
        return true;
      }
      if (key == LogicalKeyboardKey.pageDown) {
        _scrollBy(page);
        return true;
      }
      if (key == LogicalKeyboardKey.home) {
        _scrollTo(0);
        return true;
      }
      if (key == LogicalKeyboardKey.end) {
        _toBottom();
        return true;
      }
    }
    if (_mac && keys.isMetaPressed && !keys.isShiftPressed) {
      if (key == LogicalKeyboardKey.arrowUp) {
        _scrollBy(-1);
        return true;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _scrollBy(1);
        return true;
      }
      if (key == LogicalKeyboardKey.home) {
        _scrollTo(0);
        return true;
      }
      if (key == LogicalKeyboardKey.end) {
        _toBottom();
        return true;
      }
    }
    return false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final surface = widget.surface;
    final grpc = surface is GrpcTerminalSurface ? surface : null;
    final keys = HardwareKeyboard.instance;
    if (_scrollKey(event)) return KeyEventResult.handled;
    // ⌘C / ⌘V / ⌘A on macOS; Ctrl+Shift+C / V elsewhere (Ctrl+C is ^C).
    final mod = _mac ? keys.isMetaPressed : keys.isControlPressed && keys.isShiftPressed;
    if (event is! KeyUpEvent && mod) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.keyC && _selectedText.isNotEmpty) {
        _copy();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyV && surface.interactive) {
        _paste();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyA && _mac) {
        _selectAll();
        return KeyEventResult.handled;
      }
    }
    if (!surface.interactive) return KeyEventResult.ignored;
    final bytes = terminalInputFor(event, applicationCursorKeys: grpc?.applicationCursorKeys ?? false);
    if (bytes == null) return KeyEventResult.ignored;
    // Typing drops the selection and goes back to the prompt, like any
    // terminal.
    if (_sel != null || _top != null) {
      setState(() {
        _sel = null;
        _top = null;
      });
    }
    surface.sendBytes(bytes);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = mono(widget.fontSize, color: c.text, height: widget.lineHeight ?? (widget.surface.interactive ? 1.25 : 1.7));
    return LayoutBuilder(builder: (context, box) {
      final cell = _cellSize(style);
      _cell = cell;
      _size = Size(box.maxWidth, box.maxHeight);
      final cols = math.max(1, ((box.maxWidth - widget.padding.horizontal) / cell.width).floor());
      final rows = math.max(1, ((box.maxHeight - widget.padding.vertical) / cell.height).floor());
      if (cols != _cols || rows != _rows) {
        _cols = cols;
        _rows = rows;
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.surface.resize(cols, rows));
      }
      final canvas = RepaintBoundary(
        child: CustomPaint(
          size: Size(box.maxWidth, box.maxHeight),
          painter: _TerminalPainter(
            buffer: widget.surface.buffer,
            renderer: _renderer,
            palette: c,
            style: style,
            padding: widget.padding,
            lineExtent: cell.height,
            cellWidth: cell.width,
            focused: _hasFocus,
            top: _top,
            frac: _frac,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            reflows: _seenReflows,
            selection: _sel,
            selectionDropped: _selDropped,
            selectionReflows: _selReflows,
            selectionColor: c.acc.withValues(alpha: 0.32),
            showBar: _top != null || _barFlash || _barHover || _barDrag,
            barColor: c.text3.withValues(alpha: _barDrag || _barHover ? 0.55 : 0.35),
          ),
        ),
      );
      return Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          onPointerSignal: _signal,
          onPointerPanZoomStart: _panStart,
          onPointerPanZoomUpdate: _panUpdate,
          onPointerPanZoomEnd: _panEnd,
          child: MouseRegion(
            cursor: _linkHover
                ? SystemMouseCursors.click
                : _barHover || _barDrag
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.text,
            onHover: (e) {
              _hoverAt = e.localPosition;
              _hover(e.localPosition);
            },
            onExit: (_) {
              _hoverAt = null;
              if (_barHover || _linkHover) {
                setState(() {
                  _barHover = false;
                  _linkHover = false;
                });
              }
            },
            child: Stack(children: [
              Positioned.fill(child: canvas),
              if (_top != null)
                Positioned(
                  right: 18,
                  bottom: 12,
                  child: _JumpToBottom(onTap: _toBottom),
                ),
            ]),
          ),
        ),
      );
    });
  }

  static final Map<double, Size> _cellCache = {};

  Size _cellSize(TextStyle style) {
    final key = (style.fontSize ?? 12) * 1000 + (style.height ?? 1);
    return _cellCache.putIfAbsent(key, () {
      final tp = TextPainter(
        text: TextSpan(text: 'M', style: style),
        textDirection: TextDirection.ltr,
        strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      )..layout();
      final s = Size(tp.width, tp.height);
      tp.dispose();
      return s;
    });
  }

}

/// Wheel up or down as a mouse report (xterm: button 64/65), at a cell.
List<int> wheelReport({required bool up, required int col, required int row, bool sgr = false}) {
  final button = up ? 64 : 65;
  if (sgr) return utf8.encode('\x1b[<$button;${col + 1};${row + 1}M');
  return [0x1b, 0x5b, 0x4d, 32 + button, 32 + math.min(col + 1, 223), 32 + math.min(row + 1, 223)];
}

/// Height of the scrollbar's thumb on a [track] showing [fit] of [total]
/// lines.
double scrollThumbExtent(double track, int fit, int total) => math.min(track, math.max(24.0, track * fit / math.max(1, total)));

/// "Back to the prompt" while reading history.
class _JumpToBottom extends StatelessWidget {
  const _JumpToBottom({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: _TerminalCanvasState._mac ? 'Back to the prompt (⌘End)' : 'Back to the prompt (Shift+End)',
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: c.pop,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.popBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_downward_rounded, size: 14, color: c.acc),
              const SizedBox(width: 6),
              Text('Jump to bottom', style: sans(11.5, weight: FontWeight.w500, color: c.text2)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TerminalPainter extends CustomPainter {
  _TerminalPainter({
    required this.buffer,
    required this.renderer,
    required this.palette,
    required this.style,
    required this.padding,
    required this.lineExtent,
    required this.cellWidth,
    required this.focused,
    this.top,
    this.frac = 0,
    this.devicePixelRatio = 1,
    this.reflows = 0,
    this.selection,
    this.selectionDropped = 0,
    this.selectionReflows = 0,
    required this.selectionColor,
    this.showBar = false,
    required this.barColor,
  }) : super(repaint: buffer);

  final ValueListenable<TermBuffer> buffer;
  final TerminalGridRenderer renderer;
  final KumoPalette palette;
  final TextStyle style;
  final EdgeInsets padding;
  final double lineExtent;
  final double cellWidth;
  final bool focused;
  final int? top;
  final double frac;
  final double devicePixelRatio;
  final int reflows;
  final TermSelection? selection;
  final int selectionDropped;
  final int selectionReflows;
  final Color selectionColor;
  final bool showBar;
  final Color barColor;

  @override
  void paint(Canvas canvas, Size size) {
    renderer.configure(palette: palette, style: style, cellWidth: cellWidth, lineExtent: lineExtent);
    final b = buffer.value;
    final cursor = b.cursor;
    final fit = math.max(1, ((size.height - padding.vertical) / lineExtent).floor());
    // Line-oriented surfaces (mocks) get +1 row for the prompt/cursor line.
    final maxLines = cursor != null ? fit : math.max(1, fit - 1);
    final start = visibleStart(b, fit, top: top, reflows: reflows);
    final offset = visibleOffset(b, fit, top: top, reflows: reflows, frac: frac);
    // Part of a line scrolled off the top shows part of one more below.
    final end = math.min(b.lines.length, start + maxLines + (offset > 0 ? 1 : 0));
    final atBottom = start + maxLines >= b.lines.length;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Shifted on whole device pixels, so text stays crisp mid-scroll.
    canvas
      ..save()
      ..translate(0, -(offset * lineExtent * devicePixelRatio).round() / devicePixelRatio);
    var y = padding.top;
    for (var i = start; i < end; i++) {
      final line = b.lines[i];
      if (line.spans.isNotEmpty) {
        canvas
          ..save()
          ..translate(padding.left, y)
          ..drawPicture(renderer.row(line))
          ..restore();
      }
      y += lineExtent;
    }
    final sel = b.reflows == selectionReflows ? selection?.shifted(selectionDropped - b.dropped) : null;
    if (sel != null && !sel.isEmpty) {
      final paint = Paint()..color = selectionColor;
      for (var i = math.max(start, sel.start.line); i <= sel.end.line && i < end; i++) {
        final range = sel.cellsOn(i, lineWidth(b.lines[i]));
        if (range == null) continue;
        // An empty line inside the selection shows as a sliver.
        final (from, to) = range;
        final right = to > from ? to * cellWidth : from * cellWidth + cellWidth / 2;
        canvas.drawRect(Rect.fromLTRB(padding.left + from * cellWidth, padding.top + (i - start) * lineExtent, padding.left + right, padding.top + (i - start + 1) * lineExtent), paint);
      }
    }
    if (cursor != null) {
      if (b.cursorVisible && cursor.$1 >= start && cursor.$1 < end) {
        _paintCursor(canvas, b.lines[cursor.$1], cursor.$2, padding.top + (cursor.$1 - start) * lineExtent);
      }
    } else if (b.cursorVisible && atBottom) {
      _paintPromptCursor(canvas, y);
    }
    canvas.restore();
    if (showBar && !b.altScreen && b.lines.length > maxLines) _paintBar(canvas, size, start + offset, b.lines.length - maxLines, maxLines, b.lines.length);
    canvas.restore();
  }

  /// A thin thumb on the right edge: where the view is in the history.
  void _paintBar(Canvas canvas, Size size, double start, int bottom, int fit, int total) {
    final track = size.height - 8;
    final thumb = scrollThumbExtent(track, fit, total);
    final y = 4.0 + (bottom <= 0 ? 0.0 : (track - thumb) * start / bottom);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width - 8, y, 4, thumb), const Radius.circular(2)),
      Paint()..color = barColor,
    );
  }

  /// Block cursor over its cell; focused, it shows the glyph underneath in
  /// the background color, unfocused it is an outline.
  void _paintCursor(Canvas canvas, TermLine line, int column, double top) {
    final rect = Rect.fromLTWH(padding.left + column * cellWidth, top, cellWidth, lineExtent);
    if (!focused) {
      canvas.drawRect(
        rect.deflate(0.5),
        Paint()
          ..color = palette.acc
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      return;
    }
    canvas.drawRect(rect, Paint()..color = palette.acc);
    final cell = TerminalGridRenderer.cellAt(line, column);
    if (cell != null && cell.$1 != 0x20) {
      canvas
        ..save()
        ..translate(padding.left, top);
      renderer.paintGlyph(canvas, cell.$1, column, renderer.background, bold: cell.$2.bold);
      canvas.restore();
    }
  }

  /// Mocks: a "❯ " prompt and a block after the last line.
  void _paintPromptCursor(Canvas canvas, double y) {
    final prompt = TextPainter(text: TextSpan(text: '❯ ', style: style.copyWith(color: palette.acc)), textDirection: TextDirection.ltr)..layout();
    prompt.paint(canvas, Offset(padding.left, y));
    final cellW = prompt.width / 2;
    final rect = Rect.fromLTWH(padding.left + prompt.width, y + (lineExtent - style.fontSize! * 1.25) / 2, math.max(6, cellW * 0.9), style.fontSize! * 1.25);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(1)), Paint()..color = palette.acc);
    prompt.dispose();
  }

  @override
  bool shouldRepaint(_TerminalPainter old) =>
      old.buffer != buffer ||
      old.palette != palette ||
      old.style != style ||
      old.focused != focused ||
      old.cellWidth != cellWidth ||
      old.lineExtent != lineExtent ||
      old.top != top ||
      old.frac != frac ||
      old.devicePixelRatio != devicePixelRatio ||
      old.reflows != reflows ||
      old.selection != selection ||
      old.selectionDropped != selectionDropped ||
      old.selectionReflows != selectionReflows ||
      old.selectionColor != selectionColor ||
      old.showBar != showBar ||
      old.barColor != barColor;
}

/// A titled terminal pane: header row + canvas + optional footer.
/// [focused] draws the accent ring of the active split pane; [onFocus]
/// fires on any pointer down inside it (without stealing the gesture).
class TerminalPane extends StatelessWidget {
  const TerminalPane({super.key, required this.surface, required this.icon, required this.iconColor, this.trailing, this.footer, this.focused = false, this.active = false, this.onFocus});

  final TerminalSurface surface;

  /// The pane that owns the keyboard (the layout's current focus).
  final bool active;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget? footer;
  final bool focused;
  final VoidCallback? onFocus;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pane = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: c.pane,
        borderRadius: BorderRadius.circular(14),
        // Outline only: a spread shadow would show through the translucent
        // pane fill and tint the whole terminal.
        border: Border.all(color: focused ? c.acc : c.paneBorder, width: focused ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
          child: Row(children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 8),
            Flexible(flex: 3, child: Text(surface.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, weight: FontWeight.w600, color: c.text))),
            const SizedBox(width: 8),
            Flexible(child: Text(surface.cwd, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3))),
            const Spacer(),
            if (trailing != null) trailing!,
          ]),
        ),
        Expanded(child: TerminalCanvas(surface: surface, active: active)),
        if (footer != null) footer!,
      ]),
    );
    if (onFocus == null) return pane;
    return Listener(behavior: HitTestBehavior.translucent, onPointerDown: (_) => onFocus!(), child: pane);
  }
}
