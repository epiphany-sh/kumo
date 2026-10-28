import 'package:flutter/material.dart';

import '../theme/kumo_theme.dart';
import 'glass.dart';

typedef HoverBuilder = Widget Function(BuildContext context, bool hovered, bool focused);

/// Base for every clickable thing: hover + keyboard focus + Enter/Space,
/// a semantics label, and a click cursor. Real buttons, not tappable divs.
class KPressable extends StatefulWidget {
  const KPressable({super.key, required this.builder, this.onTap, this.semanticLabel, this.tooltip, this.selected});

  final HoverBuilder builder;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final String? tooltip;
  final bool? selected;

  @override
  State<KPressable> createState() => _KPressableState();
}

class _KPressableState extends State<KPressable> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget child = FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap?.call();
          return null;
        }),
      },
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: widget.selected,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: widget.builder(context, _hover, _focus),
        ),
      ),
    );
    if (widget.tooltip != null) child = Tooltip(message: widget.tooltip!, child: child);
    return child;
  }
}

class KIconButton extends StatelessWidget {
  const KIconButton({super.key, required this.icon, required this.label, this.onTap, this.size = 28, this.iconSize = 16, this.color, this.filled = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      semanticLabel: label,
      tooltip: label,
      builder: (context, hover, focus) => AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: size,
        height: size,
        decoration: filled
            ? chipDecoration(c, radius: size / 2)
            : BoxDecoration(
                color: hover ? c.tile : null,
                borderRadius: BorderRadius.circular(size * 0.32),
                border: focus ? Border.all(color: c.acc, width: 1.5) : null,
              ),
        alignment: Alignment.center,
        child: Icon(icon, size: iconSize, color: color ?? c.text2),
      ),
    );
  }
}

enum KButtonKind { primary, secondary, ghost }

class KButton extends StatelessWidget {
  const KButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.kind = KButtonKind.secondary,
    this.height = 34,
    this.expand = false,
    this.trailing,
    this.fontSize = 13,
  });

  const KButton.primary({super.key, required this.label, this.onTap, this.icon, this.height = 34, this.expand = false, this.trailing, this.fontSize = 13})
      : kind = KButtonKind.primary;

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final KButtonKind kind;
  final double height;
  final bool expand;
  final Widget? trailing;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = onTap != null;
    return KPressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, hover, focus) {
        late final BoxDecoration deco;
        late final Color fg;
        switch (kind) {
          case KButtonKind.primary:
            fg = enabled ? c.accText : c.text3;
            deco = BoxDecoration(
              color: enabled ? (hover ? Color.alphaBlend(const Color(0x14FFFFFF), c.accFill) : c.accFill) : c.tile,
              borderRadius: BorderRadius.circular(height / 2),
              border: focus ? Border.all(color: c.text, width: 1.5) : null,
              boxShadow: enabled ? [BoxShadow(color: c.accFill.withAlpha(c.isDark ? 76 : 70), blurRadius: 16, offset: const Offset(0, 6))] : null,
            );
          case KButtonKind.secondary:
            fg = c.text;
            deco = chipDecoration(c, radius: height / 2, fill: hover ? c.tabActive : null);
          case KButtonKind.ghost:
            fg = c.text2;
            deco = BoxDecoration(color: hover ? c.tile : null, borderRadius: BorderRadius.circular(height / 2));
        }
        final row = Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: sans(fontSize, weight: FontWeight.w600, color: fg))),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        );
        return AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: height,
          padding: EdgeInsets.symmetric(horizontal: icon != null ? 12 : 14),
          decoration: deco,
          child: row,
        );
      },
    );
  }
}

class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = 7, this.ring = false});

  final Color color;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ring ? null : color,
          border: ring ? Border.all(color: color, width: 2) : null,
        ),
      );
}

/// Status pill: "● Running · 12:04".
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.color, required this.background, this.dot = true});

  final String label;
  final Color color;
  final Color background;
  final bool dot;

  @override
  Widget build(BuildContext context) => Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(11)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot) ...[Dot(color, size: 6), const SizedBox(width: 6)],
          Text(label, style: sans(11, weight: FontWeight.w600, color: color)),
        ]),
      );
}

/// Two/three-letter integration badge (GH, JI, CF…). Neutral on purpose:
/// no third-party logos.
class SourceTile extends StatelessWidget {
  const SourceTile(this.k, {super.key, this.size = 24, this.tooltip});

  final String k;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Text(k, style: mono(size * 0.4, weight: FontWeight.w600, color: c.tileText, height: 1)),
    );
    return tooltip == null ? tile : Tooltip(message: tooltip!, child: tile);
  }
}

class TagChip extends StatelessWidget {
  const TagChip(this.text, {super.key, this.color, this.background});

  final String text;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: background ?? c.tile, borderRadius: BorderRadius.circular(5)),
      child: Text(text, style: mono(10, weight: FontWeight.w600, color: color ?? c.tileText, height: 1.4)),
    );
  }
}

class Kbd extends StatelessWidget {
  const Kbd(this.text, {super.key, this.color, this.background});

  final String text;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: background ?? c.tile, borderRadius: BorderRadius.circular(7)),
      child: Text(text, style: sans(11, weight: FontWeight.w500, color: color ?? c.text2)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(text.toUpperCase(), style: microLabel(context.c))),
        if (trailing != null) trailing!,
      ]);
}

/// Segmented control on a tinted track (filters, view modes).
class KSegmented<T> extends StatelessWidget {
  const KSegmented({super.key, required this.items, required this.value, required this.onChanged, this.height = 28, this.expand = false, this.label});

  final List<(T, String, String?)> items;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;
  final bool expand;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final children = [
      for (final (v, text, count) in items)
        _wrap(
          KPressable(
            onTap: () => onChanged(v),
            semanticLabel: text,
            selected: v == value,
            builder: (context, hover, focus) {
              final on = v == value;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: height,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                alignment: Alignment.center,
                decoration: on ? chipDecoration(c, radius: height * 0.38, fill: c.tabActive) : BoxDecoration(color: hover ? c.tile : null, borderRadius: BorderRadius.circular(height * 0.38)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, weight: FontWeight.w500, color: on ? c.text : c.text2))),
                  if (count != null) ...[const SizedBox(width: 6), Text(count, style: sans(11, color: c.text3))],
                ]),
              );
            },
          ),
        ),
    ];
    return Semantics(
      label: label,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(height * 0.5)),
        child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: _gap(children, 2)),
      ),
    );
  }

  Widget _wrap(Widget w) => expand ? Expanded(child: w) : w;
}

List<Widget> _gap(List<Widget> items, double gap) {
  final out = <Widget>[];
  for (var i = 0; i < items.length; i++) {
    if (i > 0) out.add(SizedBox(width: gap));
    out.add(items[i]);
  }
  return out;
}

/// Labeled dropdown styled as a glass field.
class KSelect<T> extends StatelessWidget {
  const KSelect({super.key, required this.label, required this.value, required this.items, required this.onChanged, this.monospace = false});

  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = monospace ? mono(12, color: c.text) : sans(12.5, color: c.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: sans(11, color: c.text3)),
      const SizedBox(height: 4),
      Container(
        height: 34,
        padding: const EdgeInsets.only(left: 10, right: 6),
        decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.chipBorder)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            isDense: true,
            focusColor: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            dropdownColor: Color.alphaBlend(c.pop, c.isDark ? const Color(0xFF181A24) : const Color(0xFFF7F8FB)),
            icon: Icon(Icons.unfold_more_rounded, size: 16, color: c.text3),
            style: style,
            items: [for (final (v, text) in items) DropdownMenuItem<T>(value: v, child: Text(text, style: style, overflow: TextOverflow.ellipsis))],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    ]);
  }
}

/// Labeled single-line input.
class KField extends StatelessWidget {
  const KField({super.key, required this.label, required this.controller, this.monospace = false, this.hint});

  final String label;
  final TextEditingController controller;
  final bool monospace;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = monospace ? mono(12, color: c.text) : sans(12.5, color: c.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: sans(11, color: c.text3)),
      const SizedBox(height: 4),
      Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.chipBorder)),
        child: TextField(
          controller: controller,
          style: style,
          cursorColor: c.acc,
          decoration: InputDecoration.collapsed(hintText: hint, hintStyle: style.copyWith(color: c.text3)),
        ),
      ),
    ]);
  }
}

class KSwitch extends StatelessWidget {
  const KSwitch({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: () => onChanged(!value),
      semanticLabel: label,
      selected: value,
      builder: (context, hover, focus) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 40,
        height: 24,
        padding: const EdgeInsets.all(2),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(color: value ? c.accFill : c.text3.withAlpha(70), borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(color: Color(0xFFFFFFFF), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))]),
        ),
      ),
    );
  }
}

class KCheck extends StatelessWidget {
  const KCheck({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: () => onChanged(!value),
      semanticLabel: label,
      selected: value,
      builder: (context, hover, focus) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: value ? c.accFill : null,
            borderRadius: BorderRadius.circular(4.5),
            border: Border.all(color: value ? c.accFill : c.text3, width: 1.4),
          ),
          child: value ? Icon(Icons.check_rounded, size: 12, color: c.accText) : null,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: sans(12.5, color: c.text2, height: 1.4))),
      ]),
    );
  }
}

/// Inline row with gaps, used everywhere instead of margins.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}
