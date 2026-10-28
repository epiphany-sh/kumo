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
          stops: const [0.0, 0.08, 1.0],
        ),
      ),
      child: content,
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
      colors: [Color.alphaBlend(c.chipSheen, base), base],
      stops: const [0.0, 0.35],
    ),
    boxShadow: c.isDark
        ? const [BoxShadow(color: Color(0x2E000000), blurRadius: 14, offset: Offset(0, 4))]
        : const [BoxShadow(color: Color(0x141E1E3C), blurRadius: 3, offset: Offset(0, 1))],
  );
}

/// Popover / sheet surface. This is the one place we allow a real blur,
/// because it is transient and small.
class GlassOverlay extends StatelessWidget {
  const GlassOverlay({super.key, required this.child, this.radius = 22, this.padding = const EdgeInsets.all(18), this.width});

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = BorderRadius.circular(radius);
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
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(color: c.popBorder),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.alphaBlend(c.panelSheen, c.pop), c.pop],
                stops: const [0.0, 0.12],
              ),
            ),
            child: child,
          ),
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
        _blob(const Alignment(-0.95, -1.0), b[0]),
        _blob(const Alignment(1.0, -0.85), b[1]),
        _blob(const Alignment(0.3, 1.1), b[2]),
      ]),
    );
  }

  Widget _blob(Alignment at, Color color) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(center: at, radius: 0.95, colors: [color, color.withAlpha(0)]),
        ),
      );
}
