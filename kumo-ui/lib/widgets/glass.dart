import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../theme/kumo_theme.dart';
import '../theme/palette.dart';

/// Light-weight "liquid glass" surface: translucent fill with a soft top sheen
/// and a hairline border. Deliberately NO BackdropFilter — see
/// WindowEffects for why. Use [GlassOverlay] for popovers that may blur.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 20,
    this.fill,
    this.border,
    this.shadow = true,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? fill;
  final Color? border;
  final bool shadow;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final base = fill ?? c.panel;
    final top = Color.alphaBlend(c.panelSheen, base);
    final r = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (clip) content = ClipRRect(borderRadius: r, child: content);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(color: border ?? c.panelBorder, width: 1),
        boxShadow: shadow ? c.panelShadow : null,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, base, base],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: CustomPaint(foregroundPainter: GlassRimPainter(radius: radius, top: c.rimTop, bottom: c.rimBottom), child: content),
    );
  }
}

/// Capsule control surface (toolbar pills, search field, segmented tracks).
class Capsule extends StatelessWidget {
  const Capsule({super.key, required this.child, this.height = 36, this.padding = const EdgeInsets.symmetric(horizontal: 14), this.radius});

  final Widget child;
  final double height;
  final EdgeInsetsGeometry padding;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: height,
      padding: padding,
      decoration: chipDecoration(c, radius: radius ?? height / 2),
      child: child,
    );
  }
}

BoxDecoration chipDecoration(KumoPalette c, {double radius = 18, bool selected = true, Color? fill}) {
  if (!selected) return BoxDecoration(borderRadius: BorderRadius.circular(radius));
  final base = fill ?? c.chip;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: c.chipBorder),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color.alphaBlend(c.chipSheen, base), base, base],
      stops: const [0.0, 0.45, 1.0],
    ),
    boxShadow: c.isDark
        ? const [BoxShadow(color: Color(0x2E000000), blurRadius: 14, offset: Offset(0, 4))]
        : const [BoxShadow(color: Color(0x141E1E3C), blurRadius: 3, offset: Offset(0, 1))],
  );
}

/// Popover / sheet surface. This is the one place we allow a real blur,
/// because it is transient and small. A large one with content that scrolls
/// sets [blur] off: its surface is opaque, and no frame pays for a re-blur.
class GlassOverlay extends StatelessWidget {
  const GlassOverlay({super.key, required this.child, this.radius = 22, this.padding = const EdgeInsets.all(18), this.width, this.blur = true});

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = BorderRadius.circular(radius);
    final fill = blur ? c.pop : Color.alphaBlend(c.pop, c.isDark ? const Color(0xFF10121A) : const Color(0xFFFFFFFF));
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(color: c.popBorder),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.alphaBlend(c.panelSheen, fill), fill],
          stops: const [0.0, 0.4],
        ),
      ),
      child: child,
    );
    final rimmed = CustomPaint(foregroundPainter: GlassRimPainter(radius: radius, top: c.rimTop, bottom: c.rimBottom), child: surface);
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: c.isDark
            ? const [BoxShadow(color: Color(0x8C000000), blurRadius: 70, offset: Offset(0, 28))]
            : const [BoxShadow(color: Color(0x38282850), blurRadius: 60, offset: Offset(0, 24))],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: blur ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24), child: rimmed) : rimmed,
      ),
    );
  }
}

/// The specular rim of a glass edge: a 1 px line just inside the border,
/// bright along the top, gone through the middle and faint along the bottom,
/// as light catches the edges of a pane. One stroke, no blur.
class GlassRimPainter extends CustomPainter {
  const GlassRimPainter({required this.radius, required this.top, required this.bottom});

  final double radius;
  final Color top;
  final Color bottom;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(1.5), Radius.circular((radius - 1.5).clamp(0, radius)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, top.withAlpha(0), bottom.withAlpha(0), bottom],
        stops: const [0.0, 0.22, 0.78, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(GlassRimPainter old) => old.radius != radius || old.top != top || old.bottom != bottom;
}

/// The window's own glass: its tint, with light coming in from the top-left.
class WindowGlass extends StatelessWidget {
  const WindowGlass({super.key, required this.palette});

  final KumoPalette palette;

  @override
  Widget build(BuildContext context) {
    final w = palette.window;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.6, -1.0),
          end: const Alignment(0.6, 1.0),
          colors: [Color.alphaBlend(palette.windowSheen, w), w],
          stops: const [0.0, 0.4],
        ),
      ),
    );
  }
}

/// Painted stand-in for the desktop when the OS gives us no translucency
/// (Linux, widget tests, or the "demo wallpaper" setting).
class DemoWallpaper extends StatelessWidget {
  const DemoWallpaper({super.key, required this.palette});

  final KumoPalette palette;

  @override
  Widget build(BuildContext context) {
    final b = palette.wallpaperBlobs;
    return DecoratedBox(
      decoration: BoxDecoration(color: palette.wallpaperBase),
      child: Stack(fit: StackFit.expand, children: [
        for (var i = 0; i < b.length && i < _at.length; i++) _blob(_at[i], b[i], i == 3 ? 0.6 : 0.95),
      ]),
    );
  }

  static const _at = [Alignment(-0.95, -1.0), Alignment(1.0, -0.85), Alignment(0.3, 1.1), Alignment(-0.38, 0.22)];

  Widget _blob(Alignment at, Color color, double radius) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(center: at, radius: radius, colors: [color, color.withAlpha(0)]),
        ),
      );
}
