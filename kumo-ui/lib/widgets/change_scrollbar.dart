import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/kumo_theme.dart';

/// A changed stretch of a file for [ChangeScrollbar], as fractions (0–1) of
/// the scrolled content's height.
@immutable
class ChangeTick {
  const ChangeTick(this.start, this.end, this.color);
  final double start;
  final double end;
  final Color color;

  @override
  bool operator ==(Object other) => other is ChangeTick && other.start == start && other.end == end && other.color == color;

  @override
  int get hashCode => Object.hash(start, end, color);
}

/// Ticks for rows of [heights] (one per row, in order) whose [colors] aren't
/// null; consecutive rows of the same color make one tick. [top] and
/// [bottom] are the content's padding.
List<ChangeTick> changeTicks(List<double> heights, List<Color?> colors, {double top = 0, double bottom = 0}) {
  final total = top + heights.fold<double>(0, (a, h) => a + h) + bottom;
  if (total <= 0) return const [];
  final ticks = <ChangeTick>[];
  var y = top;
  double? start;
  Color? run;
  for (var i = 0; i <= heights.length; i++) {
    final color = i < heights.length ? colors[i] : null;
    if (color != run) {
      if (run != null && start != null) ticks.add(ChangeTick(start / total, y / total, run));
      start = color == null ? null : y;
      run = color;
    }
    if (i < heights.length) y += heights[i];
  }
  return ticks;
}

/// The vertical scrollbar of a file: a slim track along the right edge that
/// maps where the file changed (ticks in the change colors) and shows the
/// part on screen (the thumb). Clicking the track goes there; dragging moves
/// through the file. It replaces the platform scrollbar of [child], which
/// must scroll with [controller].
class ChangeScrollbar extends StatefulWidget {
  const ChangeScrollbar({super.key, required this.controller, required this.ticks, required this.child, this.width = 14});

  final ScrollController controller;
  final List<ChangeTick> ticks;
  final Widget child;
  final double width;

  @override
  State<ChangeScrollbar> createState() => _ChangeScrollbarState();
}

class _ChangeScrollbarState extends State<ChangeScrollbar> {
  bool _hover = false;
  bool _dragging = false;
  double _grabY = 0;
  double _grabPixels = 0;

  ScrollPosition? get _position {
    final c = widget.controller;
    if (!c.hasClients || c.positions.length != 1) return null;
    final p = c.position;
    return p.hasContentDimensions ? p : null;
  }

  /// (top, height) of the thumb in a track [h] tall; null when it all fits.
  (double, double)? _thumb(ScrollPosition p, double h) {
    if (p.maxScrollExtent <= 0) return null;
    final total = p.maxScrollExtent + p.viewportDimension;
    final height = math.max(24.0, h * p.viewportDimension / total);
    final top = (h - height) * (p.pixels / p.maxScrollExtent).clamp(0.0, 1.0);
    return (top, height);
  }

  void _down(PointerDownEvent e, double h) {
    final p = _position;
    if (p == null || p.maxScrollExtent <= 0) return;
    final thumb = _thumb(p, h)!;
    final y = e.localPosition.dy;
    if (y < thumb.$1 || y > thumb.$1 + thumb.$2) {
      // Outside the thumb: center the view on that point first.
      final total = p.maxScrollExtent + p.viewportDimension;
      p.jumpTo((y / h * total - p.viewportDimension / 2).clamp(p.minScrollExtent, p.maxScrollExtent).toDouble());
    }
    setState(() => _dragging = true);
    _grabY = y;
    _grabPixels = p.pixels;
  }

  void _move(PointerMoveEvent e, double h) {
    final p = _position;
    if (!_dragging || p == null) return;
    final thumb = _thumb(p, h);
    if (thumb == null) return;
    final room = h - thumb.$2;
    if (room <= 0) return;
    final delta = (e.localPosition.dy - _grabY) / room * p.maxScrollExtent;
    p.jumpTo((_grabPixels + delta).clamp(p.minScrollExtent, p.maxScrollExtent).toDouble());
  }

  void _up() {
    if (_dragging) setState(() => _dragging = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        if (mounted) setState(() {});
        return false;
      },
      child: Stack(children: [
        Positioned.fill(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: widget.child,
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: widget.width,
          child: LayoutBuilder(builder: (context, box) {
            final h = box.maxHeight;
            return MouseRegion(
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _down(e, h),
                onPointerMove: (e) => _move(e, h),
                onPointerUp: (_) => _up(),
                onPointerCancel: (_) => _up(),
                child: AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, _) {
                    final p = _position;
                    final thumb = p == null ? null : _thumb(p, h);
                    return CustomPaint(
                      size: Size(widget.width, h),
                      painter: _ChangeMapPainter(
                        ticks: widget.ticks,
                        thumb: thumb,
                        thumbColor: c.text.withValues(alpha: _dragging ? 0.34 : (_hover ? 0.24 : 0.13)),
                        track: _hover || _dragging ? c.text.withValues(alpha: 0.05) : null,
                      ),
                    );
                  },
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

class _ChangeMapPainter extends CustomPainter {
  _ChangeMapPainter({required this.ticks, required this.thumb, required this.thumbColor, required this.track});

  final List<ChangeTick> ticks;
  final (double, double)? thumb;
  final Color thumbColor;
  final Color? track;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    if (size.height < 4) return;
    if (track != null) {
      canvas.drawRRect(RRect.fromLTRBR(2, 0, w - 2, size.height, const Radius.circular(5)), Paint()..color = track!);
    }
    final t = thumb;
    if (t != null) {
      canvas.drawRRect(RRect.fromLTRBR(3, t.$1, w - 3, t.$1 + t.$2, const Radius.circular(4)), Paint()..color = thumbColor);
    }
    // Ticks in the right lane, over the thumb, at least 2px tall.
    final paint = Paint();
    for (final k in ticks) {
      final top = (k.start * size.height).clamp(0.0, size.height - 2);
      final bottom = math.max(top + 2, k.end * size.height).clamp(0.0, size.height);
      paint.color = k.color;
      canvas.drawRRect(RRect.fromLTRBR(w - 6, top, w - 2.5, bottom, const Radius.circular(1.5)), paint);
    }
  }

  @override
  bool shouldRepaint(_ChangeMapPainter old) =>
      old.thumb != thumb || old.thumbColor != thumbColor || old.track != track || !_sameTicks(old.ticks, ticks);

  static bool _sameTicks(List<ChangeTick> a, List<ChangeTick> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
