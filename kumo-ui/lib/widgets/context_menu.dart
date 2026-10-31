import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/kumo_theme.dart';
import 'controls.dart';
import 'glass.dart';

/// Opens a small glass menu at [position] (global coordinates), used for
/// right-click and ⋮ menus. With [alignRight] the menu's right edge sits on
/// [position] (for a ⋮ button at the end of a row). Clicking outside, a
/// second right-click, or Esc closes it. The menu stays inside the window.
void showKMenu(
  BuildContext context, {
  required Offset position,
  required Widget Function(BuildContext context, VoidCallback close) builder,
  bool alignRight = false,
  VoidCallback? onClosed,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  var closed = false;
  void close() {
    if (closed) return;
    closed = true;
    entry.remove();
    onClosed?.call();
  }

  entry = OverlayEntry(
    builder: (ctx) => Stack(fit: StackFit.expand, children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: close,
          onSecondaryTap: close,
        ),
      ),
      CustomSingleChildLayout(
        delegate: _MenuLayout(position, alignRight),
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
          child: FocusScope(
            autofocus: true,
            child: Material(type: MaterialType.transparency, child: builder(ctx, close)),
          ),
        ),
      ),
    ]),
  );
  overlay.insert(entry);
}

class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout(this.position, this.alignRight);
  final Offset position;
  final bool alignRight;

  static const _margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen().deflate(const EdgeInsets.all(_margin));

  @override
  Offset getPositionForChild(Size size, Size child) {
    var x = alignRight ? position.dx - child.width : position.dx;
    var y = position.dy;
    if (y + child.height > size.height - _margin) y = position.dy - child.height;
    x = x.clamp(_margin, math.max(_margin, size.width - child.width - _margin)).toDouble();
    y = y.clamp(_margin, math.max(_margin, size.height - child.height - _margin)).toDouble();
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout old) => old.position != position || old.alignRight != alignRight;
}

/// Global position just under [context]'s widget, at its right or left edge.
Offset belowOf(BuildContext context, {bool right = true, double gap = 4}) {
  final box = context.findRenderObject() as RenderBox;
  return box.localToGlobal(Offset(right ? box.size.width : 0, box.size.height + gap));
}

/// The menu surface.
class KMenuPanel extends StatelessWidget {
  const KMenuPanel({super.key, required this.children, this.width = 232});
  final List<Widget> children;
  final double width;

  @override
  Widget build(BuildContext context) => GlassOverlay(
        width: width,
        radius: 12,
        padding: const EdgeInsets.all(5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
      );
}

class KMenuItem extends StatelessWidget {
  const KMenuItem({super.key, required this.icon, required this.label, this.onTap, this.shortcut, this.danger = false, this.note});

  final IconData icon;
  final String label;

  /// Null renders the item disabled (with [note] under the label, if any).
  final VoidCallback? onTap;
  final String? shortcut;
  final bool danger;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = onTap != null;
    final fg = !enabled ? c.text3 : (danger ? c.err : c.text);
    return KPressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, hover, focus) => Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: note == null ? 0 : 6),
        decoration: BoxDecoration(
          color: enabled && (hover || focus) ? (danger ? c.errSoft : c.tile) : null,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(crossAxisAlignment: note == null ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: sans(12.5, weight: FontWeight.w500, color: fg)),
              if (note != null) ...[
                const SizedBox(height: 2),
                Text(note!, style: sans(11, color: c.text3, height: 1.35)),
              ],
            ]),
          ),
          if (shortcut != null) Text(shortcut!, style: sans(11, color: c.text3)),
        ]),
      ),
    );
  }
}

class KMenuDivider extends StatelessWidget {
  const KMenuDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6), color: context.c.divider);
}

/// Inline "are you sure" step shown in place of the menu items.
class KMenuConfirm extends StatelessWidget {
  const KMenuConfirm({super.key, required this.title, required this.body, required this.confirmLabel, required this.onConfirm, required this.onCancel, this.detail, this.extra});

  final String title;
  final String? detail;
  final String body;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  /// Below the body, e.g. an option of what's confirmed.
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.enter): onConfirm},
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: sans(12.5, weight: FontWeight.w600, color: c.text)),
            if (detail != null) ...[const SizedBox(height: 4), Text(detail!, style: mono(11, color: c.text2))],
            const SizedBox(height: 4),
            Text(body, style: sans(11.5, color: c.text3, height: 1.4)),
            if (extra != null) ...[const SizedBox(height: 8), extra!],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            KButton(label: 'Cancel', height: 26, fontSize: 12, onTap: onCancel),
            const SizedBox(width: 6),
            DangerButton(label: confirmLabel, onTap: onConfirm),
          ]),
        ),
      ]),
    );
  }
}

/// Small solid red button for destructive confirmations.
class DangerButton extends StatelessWidget {
  const DangerButton({super.key, required this.label, required this.onTap, this.height = 26});
  final String label;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fill = c.isDark ? const Color(0xFFE5484D) : const Color(0xFFD92D20);
    return KPressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, hover, focus) => Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hover ? Color.alphaBlend(const Color(0x1AFFFFFF), fill) : fill,
          borderRadius: BorderRadius.circular(7),
          border: focus ? Border.all(color: c.text, width: 1.5) : null,
        ),
        child: Text(label, style: sans(12, weight: FontWeight.w600, color: const Color(0xFFFFFFFF))),
      ),
    );
  }
}
