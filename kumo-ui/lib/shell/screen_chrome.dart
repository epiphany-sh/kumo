import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../platform/os/host_os.dart';
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
  const ScreenToolbar({super.key, required this.breadcrumb, this.primary, this.searchHint = 'Search commands, tickets, docs…', this.searchKey = '⌘K', this.onSearch});

  final Widget breadcrumb;
  final Widget? primary;
  final String searchHint;
  final String searchKey;

  /// The search field opens this (a picker of its own) instead of taking
  /// text.
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final hiddenSidebarInset = (!s.sidebarVisible && !kIsWeb && hostOs.windowButtonsInContent && WindowEffects.nativeBackdrop) ? 76.0 : 0.0;
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
        // All the free room is the breadcrumb's (it hugs its content, on the
        // left): a view can put a switch in it without squeezing the rest.
        Expanded(child: Align(alignment: Alignment.centerLeft, child: Capsule(child: breadcrumb))),
        const SizedBox(width: 8),
        // An update waiting takes some of the search field's room.
        SizedBox(width: s.updates.ready == null ? 300 : 220, child: _SearchField(hint: searchHint, shortcut: searchKey, onTap: onSearch)),
        const SizedBox(width: 8),
        if (s.updates.ready case final version?) ...[
          Tooltip(
            message: 'Kumo $version is downloaded. Restart to use it (open terminals close); otherwise it installs when Kumo quits.',
            child: KButton(label: 'Restart to update', icon: KIcons.download, height: 36, fontSize: 12.5, onTap: s.updates.installAndRelaunch),
          ),
          const SizedBox(width: 8),
        ],
        KIconButton(icon: themeIcon, label: 'Theme: $themeName — click to cycle (⇧⌘L)', onTap: s.cycleTheme, size: 36, filled: true, color: c.text),
        if (primary != null) ...[const SizedBox(width: 8), primary!],
      ]),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.shortcut, this.onTap});
  final String hint;
  final String shortcut;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tap = onTap;
    if (tap != null) {
      return KPressable(
        onTap: tap,
        semanticLabel: hint,
        builder: (context, hover, focus) => Capsule(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Row(children: [
            Icon(KIcons.search, size: 16, color: hover ? c.text2 : c.text3),
            const SizedBox(width: 8),
            Expanded(child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13, color: hover ? c.text2 : c.text3))),
            Kbd(shortcut),
          ]),
        ),
      );
    }
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
      // Every part ellipsizes when the toolbar is narrow.
      children.add(Flexible(child: text));
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
        // Shrinks (its texts ellipsize) rather than overflow a narrow panel.
        if (trailing != null) Flexible(child: trailing!),
      ]);
}

/// Convenience: a standard glass section with padding.
class Section extends StatelessWidget {
  const Section({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.strong = false});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final fill = strong ? context.c.panelStrong : null;
    final view = SectionViewport.maybeOf(context);
    final max = view?.maxHeight;
    if (view == null || max == null) return GlassPanel(padding: padding, fill: fill, child: child);
    return GlassPanel(
      fill: fill,
      clip: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: max),
        // The limit is for this panel only, not for panels inside it.
        child: _SectionScroll(controller: view.controller, padding: padding, child: SectionViewport(maxHeight: null, child: child)),
      ),
    );
  }
}

/// Height limit for the [Section] below it: the panel is as tall as its
/// content up to [maxHeight], and past that its content scrolls inside the
/// frame. With [controller] the owner can read how much content there is.
class SectionViewport extends InheritedWidget {
  const SectionViewport({super.key, required this.maxHeight, this.controller, required super.child});
  final double? maxHeight;
  final ScrollController? controller;

  static SectionViewport? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SectionViewport>();

  @override
  bool updateShouldNotify(SectionViewport oldWidget) => maxHeight != oldWidget.maxHeight || controller != oldWidget.controller;
}

/// The scrolling inside a height-limited [Section]. Scrolling past either
/// end carries on in the list around it, momentum included, so a trackpad
/// swipe never dies on a panel that has reached its end. (A panel whose
/// content fits takes no scroll gestures at all; the wheel already falls
/// through on its own.)
class _SectionScroll extends StatefulWidget {
  const _SectionScroll({required this.controller, required this.padding, required this.child});
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  State<_SectionScroll> createState() => _SectionScrollState();
}

class _SectionScrollState extends State<_SectionScroll> {
  ScrollController? _own;
  ScrollController get _controller => widget.controller ?? (_own ??= ScrollController());

  /// Whether the drag in course has been moving the list around.
  bool _handedOff = false;

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final outer = Scrollable.maybeOf(context)?.position;
    if (outer == null || outer.axis != Axis.vertical) return false;
    if (n is ScrollStartNotification) {
      _handedOff = false;
    } else if (n is OverscrollNotification) {
      if (n.dragDetails != null) {
        _handedOff = true;
        final to = (outer.pixels + n.overscroll).clamp(outer.minScrollExtent, outer.maxScrollExtent).toDouble();
        if (to != outer.pixels) outer.jumpTo(to);
      } else if (n.velocity != 0) {
        _fling(outer, n.velocity);
      }
    } else if (n is ScrollEndNotification) {
      // A drag that ended while pushing past the end: its momentum goes to
      // the list (pointer velocity is the opposite of scroll velocity).
      final v = n.dragDetails?.primaryVelocity ?? 0;
      if (_handedOff && v != 0) _fling(outer, -v);
      _handedOff = false;
    }
    return false;
  }

  void _fling(ScrollPosition outer, double velocity) {
    if (outer is ScrollPositionWithSingleContext) outer.goBallistic(velocity);
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Scrollbar(
          controller: _controller,
          child: SingleChildScrollView(
            controller: _controller,
            primary: false,
            physics: const ClampingScrollPhysics(),
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      );
}
