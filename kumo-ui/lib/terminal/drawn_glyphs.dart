import 'dart:math' as math;
import 'dart:ui';

/// Glyphs drawn as shapes that fill the whole cell instead of taken from a
/// font: powerline separators, box drawing and block elements. Fonts draw
/// them at font height, which leaves gaps with the cell background and
/// between rows; terminals like Ghostty and Kitty draw them the same way.
///
/// Returns false when [rune] is not one of them.
bool paintDrawnGlyph(Canvas canvas, int rune, Rect cell, Color color, {required double stroke}) {
  if (rune >= 0xE0B0 && rune <= 0xE0BF) return _powerline(canvas, rune, cell, color, stroke);
  if (rune >= 0x2580 && rune <= 0x259F) return _block(canvas, rune, cell, color);
  if (rune >= 0x256D && rune <= 0x2570) return _rounded(canvas, rune, cell, color, stroke);
  final arms = _boxArms[rune];
  if (arms != null) return _box(canvas, arms, cell, color, stroke);
  return false;
}

/// Overlap into the neighbouring cell so anti-aliasing leaves no seam.
const _bleed = 0.5;

bool _powerline(Canvas canvas, int rune, Rect c, Color color, double stroke) {
  final fill = Paint()
    ..color = color
    ..isAntiAlias = true;
  final line = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke;
  final (l, t, r, b, midY) = (c.left, c.top, c.right, c.bottom, c.center.dy);
  final halfOval = Radius.elliptical(c.width, c.height / 2);
  switch (rune) {
    case 0xE0B0: // right-pointing solid triangle
      canvas.drawPath(Path()..moveTo(l - _bleed, t)..lineTo(r, midY)..lineTo(l - _bleed, b)..close(), fill);
    case 0xE0B1:
      canvas.drawPath(Path()..moveTo(l, t)..lineTo(r, midY)..lineTo(l, b), line);
    case 0xE0B2: // left-pointing solid triangle
      canvas.drawPath(Path()..moveTo(r + _bleed, t)..lineTo(l, midY)..lineTo(r + _bleed, b)..close(), fill);
    case 0xE0B3:
      canvas.drawPath(Path()..moveTo(r, t)..lineTo(l, midY)..lineTo(r, b), line);
    case 0xE0B4: // right half circle (bubble end)
      canvas.drawPath(Path()..moveTo(l - _bleed, t)..arcToPoint(Offset(l - _bleed, b), radius: halfOval)..close(), fill);
    case 0xE0B5:
      canvas.drawPath(Path()..moveTo(l, t)..arcToPoint(Offset(l, b), radius: halfOval), line);
    case 0xE0B6: // left half circle (bubble start)
      canvas.drawPath(Path()..moveTo(r + _bleed, t)..arcToPoint(Offset(r + _bleed, b), radius: halfOval, clockwise: false)..close(), fill);
    case 0xE0B7:
      canvas.drawPath(Path()..moveTo(r, t)..arcToPoint(Offset(r, b), radius: halfOval, clockwise: false), line);
    case 0xE0B8: // ◣
      canvas.drawPath(Path()..moveTo(l, t)..lineTo(r, b)..lineTo(l, b)..close(), fill);
    case 0xE0BA: // ◢
      canvas.drawPath(Path()..moveTo(r, t)..lineTo(r, b)..lineTo(l, b)..close(), fill);
    case 0xE0BC: // ◤
      canvas.drawPath(Path()..moveTo(l, t)..lineTo(r, t)..lineTo(l, b)..close(), fill);
    case 0xE0BE: // ◥
      canvas.drawPath(Path()..moveTo(l, t)..lineTo(r, t)..lineTo(r, b)..close(), fill);
    case 0xE0B9 || 0xE0BF:
      canvas.drawLine(Offset(l, t), Offset(r, b), line);
    case 0xE0BB || 0xE0BD:
      canvas.drawLine(Offset(r, t), Offset(l, b), line);
    default:
      return false;
  }
  return true;
}

bool _block(Canvas canvas, int rune, Rect c, Color color) {
  final paint = Paint()..color = color;
  final (w, h) = (c.width, c.height);
  Rect? rect;
  switch (rune) {
    case 0x2580:
      rect = Rect.fromLTWH(c.left, c.top, w, h / 2);
    case >= 0x2581 && <= 0x2588: // lower 1/8 … full block
      final part = h * (rune - 0x2580) / 8;
      rect = Rect.fromLTWH(c.left, c.bottom - part, w, part);
    case >= 0x2589 && <= 0x258F: // left 7/8 … 1/8
      rect = Rect.fromLTWH(c.left, c.top, w * (0x2590 - rune) / 8, h);
    case 0x2590:
      rect = Rect.fromLTWH(c.left + w / 2, c.top, w / 2, h);
    case 0x2591 || 0x2592 || 0x2593: // shades
      paint.color = color.withValues(alpha: color.a * (rune - 0x2590) / 4);
      rect = c;
    case 0x2594:
      rect = Rect.fromLTWH(c.left, c.top, w, h / 8);
    case 0x2595:
      rect = Rect.fromLTWH(c.right - w / 8, c.top, w / 8, h);
    default: // quadrants 2596–259F
      final quads = _quadrants[rune - 0x2596];
      final (hw, hh) = (w / 2, h / 2);
      if (quads & 1 != 0) canvas.drawRect(Rect.fromLTWH(c.left, c.top, hw, hh), paint);
      if (quads & 2 != 0) canvas.drawRect(Rect.fromLTWH(c.left + hw, c.top, hw, hh), paint);
      if (quads & 4 != 0) canvas.drawRect(Rect.fromLTWH(c.left, c.top + hh, hw, hh), paint);
      if (quads & 8 != 0) canvas.drawRect(Rect.fromLTWH(c.left + hw, c.top + hh, hw, hh), paint);
      return true;
  }
  canvas.drawRect(rect, paint);
  return true;
}

/// ▖ ▗ ▘ ▙ ▚ ▛ ▜ ▝ ▞ ▟ as bits: upper-left 1, upper-right 2, lower-left 4, lower-right 8.
const _quadrants = [4, 8, 1, 1 | 4 | 8, 1 | 8, 1 | 2 | 4, 1 | 2 | 8, 2, 2 | 4, 2 | 4 | 8];

/// Light/heavy box drawing as arm weights: (up, right, down, left).
const _boxArms = <int, (int, int, int, int)>{
  0x2500: (0, 1, 0, 1), 0x2501: (0, 2, 0, 2), 0x2502: (1, 0, 1, 0), 0x2503: (2, 0, 2, 0), //
  0x250C: (0, 1, 1, 0), 0x250F: (0, 2, 2, 0), 0x2510: (0, 0, 1, 1), 0x2513: (0, 0, 2, 2),
  0x2514: (1, 1, 0, 0), 0x2517: (2, 2, 0, 0), 0x2518: (1, 0, 0, 1), 0x251B: (2, 0, 0, 2),
  0x251C: (1, 1, 1, 0), 0x2523: (2, 2, 2, 0), 0x2524: (1, 0, 1, 1), 0x252B: (2, 0, 2, 2),
  0x252C: (0, 1, 1, 1), 0x2533: (0, 2, 2, 2), 0x2534: (1, 1, 0, 1), 0x253B: (2, 2, 0, 2),
  0x253C: (1, 1, 1, 1), 0x254B: (2, 2, 2, 2),
  0x2574: (0, 0, 0, 1), 0x2575: (1, 0, 0, 0), 0x2576: (0, 1, 0, 0), 0x2577: (0, 0, 1, 0),
  0x2578: (0, 0, 0, 2), 0x2579: (2, 0, 0, 0), 0x257A: (0, 2, 0, 0), 0x257B: (0, 0, 2, 0),
};

bool _box(Canvas canvas, (int, int, int, int) arms, Rect c, Color color, double stroke) {
  final paint = Paint()..color = color;
  final center = _pixelCenter(c, stroke);
  final (up, right, down, left) = arms;
  double t(int weight) => weight == 2 ? stroke * 2 : stroke;
  if (up > 0) canvas.drawRect(Rect.fromLTRB(center.dx - t(up) / 2, c.top, center.dx + t(up) / 2, center.dy + t(up) / 2), paint);
  if (down > 0) canvas.drawRect(Rect.fromLTRB(center.dx - t(down) / 2, center.dy - t(down) / 2, center.dx + t(down) / 2, c.bottom), paint);
  if (left > 0) canvas.drawRect(Rect.fromLTRB(c.left, center.dy - t(left) / 2, center.dx + t(left) / 2, center.dy + t(left) / 2), paint);
  if (right > 0) canvas.drawRect(Rect.fromLTRB(center.dx - t(right) / 2, center.dy - t(right) / 2, c.right, center.dy + t(right) / 2), paint);
  return true;
}

/// ╭ ╮ ╯ ╰: a quarter circle joining the two arms.
bool _rounded(Canvas canvas, int rune, Rect c, Color color, double stroke) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..isAntiAlias = true;
  final o = _pixelCenter(c, stroke);
  final radius = math.min(c.width, c.height) / 2;
  final r = Radius.circular(radius);
  final path = switch (rune) {
    0x256D => Path() // ╭ down + right
      ..moveTo(o.dx, c.bottom)
      ..lineTo(o.dx, o.dy + radius)
      ..arcToPoint(Offset(o.dx + radius, o.dy), radius: r)
      ..lineTo(c.right, o.dy),
    0x256E => Path() // ╮ down + left
      ..moveTo(c.left, o.dy)
      ..lineTo(o.dx - radius, o.dy)
      ..arcToPoint(Offset(o.dx, o.dy + radius), radius: r)
      ..lineTo(o.dx, c.bottom),
    0x256F => Path() // ╯ up + left
      ..moveTo(o.dx, c.top)
      ..lineTo(o.dx, o.dy - radius)
      ..arcToPoint(Offset(o.dx - radius, o.dy), radius: r)
      ..lineTo(c.left, o.dy),
    _ => Path() // ╰ up + right
      ..moveTo(o.dx, c.top)
      ..lineTo(o.dx, o.dy - radius)
      ..arcToPoint(Offset(o.dx + radius, o.dy), radius: r, clockwise: false)
      ..lineTo(c.right, o.dy),
  };
  canvas.drawPath(path, paint);
  return true;
}

/// Cell center snapped so odd-width lines land on whole pixels.
Offset _pixelCenter(Rect c, double stroke) {
  double snap(double v) => stroke.round().isOdd ? v.floorToDouble() + 0.5 : v.roundToDouble();
  return Offset(snap(c.center.dx), snap(c.center.dy));
}
