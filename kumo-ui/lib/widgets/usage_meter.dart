import 'package:flutter/widgets.dart';

import '../data/ai_usage_source.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';

/// How usage reads (Settings › AI agents › Plan usage).
@immutable
class UsageStyle {
  const UsageStyle({this.showUsed = false, this.warnAt = 0.25});

  /// "62% used" instead of "38% left".
  final bool showUsed;

  /// Amber at or below this share left; red at or below the smaller of
  /// 10% and half of it. Null: never highlighted.
  final double? warnAt;

  double? get errAt => warnAt == null ? null : (warnAt! / 2 < 0.10 ? warnAt! / 2 : 0.10);

  /// The colour of a window with [fractionLeft] left: null when it's fine.
  Color? tone(KumoPalette c, double fractionLeft) {
    if (warnAt == null) return null;
    if (fractionLeft <= errAt!) return c.err;
    if (fractionLeft <= warnAt!) return c.warn;
    return null;
  }

  /// "38% left", "88 of 300 left", "$31.40 of $50 left" (or used).
  String value(UsageWindow w) {
    final n = showUsed ? w.of - w.left : w.left;
    final word = showUsed ? 'used' : 'left';
    return switch (w.unit) {
      UsageUnit.percent => '${n.round()}% $word',
      UsageUnit.requests => '${n.round()} of ${w.of.round()} $word',
      UsageUnit.dollars => '\$${n.toStringAsFixed(2)} of \$${_money(w.of)} $word',
    };
  }

  /// "38%" for the sidebar row.
  String percent(UsageWindow w) => '${((showUsed ? 1 - w.fractionLeft : w.fractionLeft) * 100).round()}%';

  /// How much of the bar is filled.
  double fill(UsageWindow w) => showUsed ? 1 - w.fractionLeft : w.fractionLeft;
}

String _money(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

/// "Resets in 1 h 48 min", "Resets Mon 09:00", "Resets Nov 1".
String resetLabel(DateTime? resets, DateTime now) {
  if (resets == null) return 'Reset time not reported';
  final d = resets.difference(now);
  if (d.isNegative || d.inMinutes < 1) return 'Resets now';
  if (d.inHours < 24) {
    final h = d.inHours, m = d.inMinutes % 60;
    return h == 0 ? 'Resets in $m min' : (m == 0 ? 'Resets in $h h' : 'Resets in $h h $m min');
  }
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final midnight = resets.hour == 0 && resets.minute == 0;
  if (d.inDays < 6) {
    final clock = '${resets.hour.toString().padLeft(2, '0')}:${resets.minute.toString().padLeft(2, '0')}';
    return midnight ? 'Resets ${days[resets.weekday - 1]}' : 'Resets ${days[resets.weekday - 1]} $clock';
  }
  return 'Resets ${months[resets.month - 1]} ${resets.day}';
}

/// "118k", "1M", "848k".
String tokensLabel(int tokens) {
  // One decimal under 10 (2.4k, 1.5M), none above; "4k", never "4.0k".
  String fmt(double v) {
    final r = v < 10 ? (v * 10).round() / 10 : v.roundToDouble();
    return r == r.roundToDouble() ? '${r.round()}' : r.toStringAsFixed(1);
  }

  if (tokens < 1000) return '$tokens';
  final k = tokens / 1000;
  if (k < 10 ? (k * 10).round() / 10 < 1000 : k.round() < 1000) return '${fmt(k)}k';
  return '${fmt(tokens / 1000000)}M';
}

/// A thin bar: [fill] of it in [color] on a tinted track.
class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.fill, required this.color, this.width, this.height = 4, this.track});
  final double fill;
  final Color color;
  final double? width;
  final double height;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: track ?? c.tile, borderRadius: BorderRadius.circular(height / 2)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fill.clamp(0.0, 1.0).toDouble(),
        heightFactor: 1,
        child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2))),
      ),
    );
  }
}

/// One window with its bar and reset: the sidebar's details and the
/// Session widget share it.
class UsageWindowView extends StatelessWidget {
  const UsageWindowView({super.key, required this.window, required this.style, required this.now, this.track});
  final UsageWindow window;
  final UsageStyle style;
  final DateTime now;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tone = style.tone(c, window.fractionLeft);
    final value = style.value(window);
    final reset = resetLabel(window.resets, now);
    return Semantics(
      label: '${window.label}: $value. $reset',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // The value keeps up to 60% of a narrow row; the label ellipsizes first.
        LayoutBuilder(
          builder: (context, box) => Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Expanded(child: Text(window.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text2))),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth.isFinite ? box.maxWidth * 0.6 : double.infinity),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sans(12, weight: FontWeight.w600, color: tone ?? c.text).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        UsageBar(fill: style.fill(window), color: tone ?? c.acc, track: track),
        const SizedBox(height: 4),
        Text(reset, style: sans(11, color: c.text3)),
      ]),
    );
  }
}
