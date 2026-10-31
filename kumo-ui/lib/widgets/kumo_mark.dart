import 'package:flutter/widgets.dart';

import '../theme/kumo_theme.dart';

/// Kumo's mark: petals around a center, in the brand gradient (amber →
/// coral → violet). The same drawing as the app icon. Below 20 px it switches
/// to the four-petal version, which stays legible that small.
class KumoMark extends StatelessWidget {
  const KumoMark({super.key, this.size = 24, this.semanticLabel = 'Kumo'});
  final double size;

  /// Null hides it from screen readers (decoration next to the name).
  final String? semanticLabel;

  /// The brand gradient.
  static const colors = [Color(0xFFFFB547), Color(0xFFFF4D6D), Color(0xFF7B5CFF)];

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(size: Size.square(size), painter: _MarkPainter(small: size < 20));
    if (semanticLabel == null) return ExcludeSemantics(child: mark);
    return Semantics(label: semanticLabel, image: true, child: mark);
  }
}

/// The mark and the "kumo" wordmark side by side.
class KumoLockup extends StatelessWidget {
  const KumoLockup({super.key, this.height = 28, this.color});
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: 'Kumo',
      child: ExcludeSemantics(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          KumoMark(size: height, semanticLabel: null),
          SizedBox(width: height * 0.28),
          Text('kumo', style: sans(height * 0.86, weight: FontWeight.w600, color: color ?? c.text, letterSpacing: -0.04 * height * 0.86, height: 1)),
        ]),
      ),
    );
  }
}

/// One petal in the 200×200 design space: from the tip of its base (x0, y0)
/// two curves out to the point and back, closed by an arc of radius r.
class _P {
  const _P(this.x0, this.y0, this.c1x, this.c1y, this.x1, this.y1, this.c2x, this.c2y, this.x2, this.y2, this.r);
  final double x0, y0, c1x, c1y, x1, y1, c2x, c2y, x2, y2, r;
}

const _eight = [
  _P(128.4, 75.7, 142.0, 58.3, 152.6, 22.1, 122.9, 45.5, 111.8, 64.6, 10.0),
  _P(137.2, 97.1, 158.5, 91.0, 188.3, 67.9, 150.6, 69.3, 130.4, 78.3, 10.0),
  _P(130.4, 121.7, 150.6, 130.7, 188.3, 132.1, 158.5, 109.0, 137.2, 102.9, 10.0),
  _P(111.8, 135.4, 122.9, 154.5, 152.6, 177.9, 142.0, 141.7, 128.4, 124.3, 10.0),
  _P(71.6, 124.3, 58.0, 141.7, 47.4, 177.9, 77.1, 154.5, 88.2, 135.4, 10.0),
  _P(62.8, 102.9, 41.5, 109.0, 11.7, 132.1, 49.4, 130.7, 69.6, 121.7, 10.0),
  _P(69.6, 78.3, 49.4, 69.3, 11.7, 67.9, 41.5, 91.0, 62.8, 97.1, 10.0),
  _P(88.2, 64.6, 77.1, 45.5, 47.4, 22.1, 58.0, 58.3, 71.6, 75.7, 10.0),
];

const _four = [
  _P(132.9, 76.3, 146.1, 60.5, 151.4, 23.7, 119.4, 42.5, 109.6, 60.7, 14.0),
  _P(109.6, 139.3, 119.4, 157.5, 151.4, 176.3, 146.1, 139.5, 132.9, 123.7, 14.0),
  _P(67.1, 123.7, 53.9, 139.5, 48.6, 176.3, 80.6, 157.5, 90.4, 139.3, 14.0),
  _P(90.4, 60.7, 80.6, 42.5, 48.6, 23.7, 53.9, 60.5, 67.1, 76.3, 14.0),
];

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.small});
  final bool small;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 200;
    canvas.save();
    canvas.scale(k);
    final path = Path();
    for (final p in small ? _four : _eight) {
      path
        ..moveTo(p.x0, p.y0)
        ..quadraticBezierTo(p.c1x, p.c1y, p.x1, p.y1)
        ..quadraticBezierTo(p.c2x, p.c2y, p.x2, p.y2)
        ..arcToPoint(Offset(p.x0, p.y0), radius: Radius.circular(p.r), clockwise: false)
        ..close();
    }
    path.addOval(Rect.fromCircle(center: const Offset(100, 100), radius: small ? 30 : 21));
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: KumoMark.colors, stops: [0, 0.5, 1]).createShader(Rect.fromPoints(const Offset(24, 20), const Offset(176, 180)));
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.small != small;
}
