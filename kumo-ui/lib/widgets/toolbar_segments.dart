import 'package:flutter/material.dart';

import '../theme/kumo_theme.dart';
import 'controls.dart';
import 'glass.dart';

/// Segmented filter on a tinted track, as in the design (smaller than
/// [KSegmented], with counts, and items that can be disabled with a reason).
class ToolbarSegments<T> extends StatelessWidget {
  const ToolbarSegments({super.key, required this.items, required this.value, required this.onChanged, required this.label});

  /// (value, label, count, why it's disabled; null = enabled).
  final List<(T, String, int?, String?)> items;
  final T value;
  final ValueChanged<T> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final children = <Widget>[];
    for (final (v, text, count, disabledWhy) in items) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 2));
      final enabled = disabledWhy == null;
      final on = v == value;
      children.add(KPressable(
        onTap: enabled ? () => onChanged(v) : null,
        tooltip: disabledWhy,
        semanticLabel: text,
        selected: on,
        builder: (context, hover, focus) => Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.center,
          decoration: on
              ? chipDecoration(c, radius: 8, fill: c.tabActive)
              : BoxDecoration(
                  color: hover && enabled ? c.tabActive : null,
                  borderRadius: BorderRadius.circular(8),
                  border: focus ? Border.all(color: c.acc, width: 1.5) : null,
                ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(text, style: sans(11.5, weight: on ? FontWeight.w600 : FontWeight.w500, color: !enabled ? c.text3 : (on ? c.text : c.text2))),
            if (count != null) ...[const SizedBox(width: 5), Text('$count', style: sans(10.5, weight: FontWeight.w500, color: c.text3))],
          ]),
        ),
      ));
    }
    return Semantics(
      label: label,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
