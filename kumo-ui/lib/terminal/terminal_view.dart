import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/grpc_terminal_surface.dart';

import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import 'grid_renderer.dart';
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

class _TerminalCanvasState extends State<TerminalCanvas> {
  int _cols = 0;
  int _rows = 0;
  final _focus = FocusNode(debugLabel: 'terminal');
  final _renderer = TerminalGridRenderer();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _hasFocus = _focus.hasFocus));
    if (widget.active) _grabKeyboard();
  }

  @override
  void didUpdateWidget(TerminalCanvas old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _grabKeyboard();
  }

  @override
  void dispose() {
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

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final surface = widget.surface;
    final grpc = surface is GrpcTerminalSurface ? surface : null;
    if (event is! KeyUpEvent && HardwareKeyboard.instance.isMetaPressed && event.logicalKey == LogicalKeyboardKey.keyV) {
      Clipboard.getData(Clipboard.kTextPlain).then((data) {
        final text = data?.text;
        if (text != null && text.isNotEmpty) surface.sendBytes(terminalPaste(text, bracketed: grpc?.bracketedPaste ?? false));
      });
      return KeyEventResult.handled;
    }
    final bytes = terminalInputFor(event, applicationCursorKeys: grpc?.applicationCursorKeys ?? false);
    if (bytes == null) return KeyEventResult.ignored;
    surface.sendBytes(bytes);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = mono(widget.fontSize, color: c.text, height: widget.lineHeight ?? (widget.surface.interactive ? 1.25 : 1.7));
    return LayoutBuilder(builder: (context, box) {
      final cell = _cellSize(style);
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
          ),
        ),
      );
      if (!widget.surface.interactive) return canvas;
      return Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _focus.requestFocus, child: MouseRegion(cursor: SystemMouseCursors.text, child: canvas)),
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
  }) : super(repaint: buffer);

  final ValueListenable<TermBuffer> buffer;
  final TerminalGridRenderer renderer;
  final KumoPalette palette;
  final TextStyle style;
  final EdgeInsets padding;
  final double lineExtent;
  final double cellWidth;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    renderer.configure(palette: palette, style: style, cellWidth: cellWidth, lineExtent: lineExtent);
    final b = buffer.value;
    final cursor = b.cursor;
    final fit = math.max(1, ((size.height - padding.vertical) / lineExtent).floor());
    // Line-oriented surfaces (mocks) get +1 row for the prompt/cursor line.
    final maxLines = cursor != null ? fit : math.max(1, fit - 1);
    final start = math.max(0, b.lines.length - maxLines);

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    var y = padding.top;
    for (var i = start; i < b.lines.length; i++) {
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
    if (cursor != null) {
      if (b.cursorVisible && cursor.$1 >= start && cursor.$1 < b.lines.length) {
        _paintCursor(canvas, b.lines[cursor.$1], cursor.$2, padding.top + (cursor.$1 - start) * lineExtent);
      }
    } else if (b.cursorVisible) {
      _paintPromptCursor(canvas, y);
    }
    canvas.restore();
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
      old.buffer != buffer || old.palette != palette || old.style != style || old.focused != focused || old.cellWidth != cellWidth || old.lineExtent != lineExtent;
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
