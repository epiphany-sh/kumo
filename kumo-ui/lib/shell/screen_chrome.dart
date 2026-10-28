import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../platform/window_effects.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';

/// Standard screen frame: toolbar row, content, status row.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({super.key, required this.toolbar, required this.body, required this.status});

  final Widget toolbar;
  final Widget body;
  final List<Widget> status;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      toolbar,
      const SizedBox(height: 10),
      Expanded(child: body),
      const SizedBox(height: 6),
      StatusRow(children: status),
    ]);
  }
}

/// Toolbar: breadcrumb capsule, search, theme cycle, primary action.
class ScreenToolbar extends StatelessWidget {
  const ScreenToolbar({super.key, required this.breadcrumb, this.primary, this.searchHint = 'Search commands, tickets, docs…', this.searchKey = '⌘K'});

  final Widget breadcrumb;
  final Widget? primary;
  final String searchHint;
  final String searchKey;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final hiddenSidebarInset = (!s.sidebarVisible && !kIsWeb && Platform.isMacOS && WindowEffects.nativeBackdrop) ? 76.0 : 0.0;
    final (themeIcon, themeName) = switch (s.mode) {
      KumoThemeMode.dark => (KIcons.moon, 'Dark'),
      KumoThemeMode.light => (KIcons.sun, 'Light'),
      KumoThemeMode.hybrid => (KIcons.hybrid, 'Hybrid'),
    };
    return Padding(
      padding: EdgeInsets.only(left: hiddenSidebarInset, top: 2),
      child: Row(children: [
        if (!s.sidebarVisible) ...[
          KIconButton(icon: KIcons.sidebar, label: 'Show sidebar (⌥⌘S)', onTap: s.toggleSidebar, size: 36, filled: true),
          const SizedBox(width: 8),
        ],
        Flexible(child: Capsule(child: breadcrumb)),
        const Spacer(),
        const SizedBox(width: 8),
        SizedBox(width: 300, child: _SearchField(hint: searchHint, shortcut: searchKey)),
        const SizedBox(width: 8),
        KIconButton(icon: themeIcon, label: 'Theme: $themeName — click to cycle (⇧⌘L)', onTap: s.cycleTheme, size: 36, filled: true, color: c.text),
        if (primary != null) ...[const SizedBox(width: 8), primary!],
      ]),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.shortcut});
  final String hint;
  final String shortcut;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Capsule(
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: Row(children: [
        Icon(KIcons.search, size: 16, color: c.text3),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            style: sans(13, color: c.text),
            cursorColor: c.acc,
            decoration: InputDecoration.collapsed(hintText: hint, hintStyle: sans(13, color: c.text3)),
          ),
        ),
        Kbd(shortcut),
      ]),
    );
  }
}

/// "icon  repo / branch" breadcrumb content.
class Breadcrumb extends StatelessWidget {
  const Breadcrumb({super.key, required this.icon, required this.parts, this.iconColor});

  final IconData icon;
  final List<String> parts;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final children = <Widget>[Icon(icon, size: 15, color: iconColor ?? c.acc), const SizedBox(width: 8)];
    for (var i = 0; i < parts.length; i++) {
      final last = i == parts.length - 1;
      if (i > 0) children.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('/', style: sans(13, color: c.text3))));
      final text = Text(parts[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13, weight: last ? FontWeight.w600 : FontWeight.w400, color: last ? c.text : c.text2));
      children.add(last ? Flexible(child: text) : text);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class StatusRow extends StatelessWidget {
  const StatusRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 22,
      child: DefaultTextStyle(
        style: sans(11.5, color: c.text3),
        child: IconTheme(
          data: IconThemeData(size: 13, color: c.text3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: _spaced(children)),
          ),
        ),
      ),
    );
  }

  List<Widget> _spaced(List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0 && items[i] is! Spacer && items[i - 1] is! Spacer) out.add(const SizedBox(width: 16));
      out.add(items[i]);
    }
    return out;
  }
}

/// Small helpers for status content.
class StatusText extends StatelessWidget {
  const StatusText(this.text, {super.key, this.icon, this.color, this.dot = false, this.monospace = false, this.flexible = false});
  final String text;
  final IconData? icon;
  final Color? color;
  final bool dot;
  final bool monospace;

  /// Ellipsize instead of overflowing. Only inside a Flexible/Expanded
  /// (the inner Row needs a bounded width).
  final bool flexible;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = color ?? c.text3;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 13, color: col), const SizedBox(width: 6)],
      if (dot) ...[Dot(col, size: 6), const SizedBox(width: 6)],
      if (flexible)
        Flexible(child: Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: _style(col)))
      else
        Text(text, style: _style(col)),
    ]);
  }

  TextStyle _style(Color col) => monospace ? mono(11.5, color: col, height: 1.2) : sans(11.5, color: col, weight: color != null ? FontWeight.w500 : FontWeight.w400);
}

/// Panel title used inside glass sections.
class PanelHeading extends StatelessWidget {
  const PanelHeading(this.text, {super.key, this.trailing, this.size = 12.5});
  final String text;
  final Widget? trailing;
  final double size;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(text, style: sans(size, weight: FontWeight.w600, color: context.c.text))),
        if (trailing != null) trailing!,
      ]);
}

/// Convenience: a standard glass section with padding.
class Section extends StatelessWidget {
  const Section({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.strong = false});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool strong;

  @override
  Widget build(BuildContext context) => GlassPanel(padding: padding, fill: strong ? context.c.panelStrong : null, child: child);
}
