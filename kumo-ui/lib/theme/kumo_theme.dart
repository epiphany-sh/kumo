import 'package:flutter/material.dart';

import 'palette.dart';

const kSans = 'Geist';
const kMono = 'GeistMono';
const kSansFallback = <String>['.AppleSystemUIFont', 'Segoe UI', 'Helvetica Neue', 'Arial'];
/// Bundled Nerd Font symbols (powerline, devicons…) come first, so shell
/// prompts like oh-my-posh or starship render their icons.
const kNerdSymbols = 'SymbolsNerdFontMono';
const kMonoFallback = <String>[kNerdSymbols, 'SF Mono', 'Menlo', 'Cascadia Mono', 'Consolas', 'monospace'];

/// Gives every widget the current palette, plus a separate palette for the
/// terminal area (differs only in [KumoThemeMode.hybrid]).
class KumoTheme extends InheritedWidget {
  const KumoTheme({
    super.key,
    required this.mode,
    required this.palette,
    required this.terminalPalette,
    required super.child,
  });

  final KumoThemeMode mode;
  final KumoPalette palette;
  final KumoPalette terminalPalette;

  static KumoTheme of(BuildContext context) {
    final t = context.dependOnInheritedWidgetOfExactType<KumoTheme>();
    assert(t != null, 'KumoTheme missing above this widget');
    return t!;
  }

  /// Re-scopes [palette] for a subtree (used to paint the terminal area with
  /// the terminal palette in hybrid mode).
  static Widget scope({required BuildContext context, required KumoPalette palette, required Widget child}) {
    final t = of(context);
    return KumoTheme(mode: t.mode, palette: palette, terminalPalette: t.terminalPalette, child: child);
  }

  @override
  bool updateShouldNotify(KumoTheme oldWidget) =>
      mode != oldWidget.mode || palette != oldWidget.palette || terminalPalette != oldWidget.terminalPalette;
}

extension KumoContext on BuildContext {
  KumoPalette get c => KumoTheme.of(this).palette;
  KumoPalette get tc => KumoTheme.of(this).terminalPalette;
  KumoThemeMode get themeMode => KumoTheme.of(this).mode;
}

/// Text style helpers so sizes/weights stay consistent with the canvas.
TextStyle sans(double size, {FontWeight weight = FontWeight.w400, Color? color, double height = 1.35, double? letterSpacing}) {
  return TextStyle(
    fontFamily: kSans,
    fontFamilyFallback: kSansFallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

TextStyle mono(double size, {FontWeight weight = FontWeight.w400, Color? color, double height = 1.5, FontStyle? style, TextDecoration? decoration}) {
  return TextStyle(
    fontFamily: kMono,
    fontFamilyFallback: kMonoFallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    fontStyle: style,
    decoration: decoration,
  );
}

/// Uppercase micro label ("WORKTREES", "INTEGRATIONS").
TextStyle microLabel(KumoPalette c) => sans(11, weight: FontWeight.w600, color: c.text3, letterSpacing: 0.66);

ThemeData materialThemeFor(KumoPalette c) {
  final scheme = ColorScheme.fromSeed(
    seedColor: c.acc,
    brightness: c.brightness,
  ).copyWith(primary: c.accFill, onPrimary: c.accText, surface: c.pop, onSurface: c.text);
  return ThemeData(
    useMaterial3: true,
    brightness: c.brightness,
    colorScheme: scheme,
    fontFamily: kSans,
    fontFamilyFallback: kSansFallback,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: c.tile,
    focusColor: c.accSoft,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.acc,
      selectionColor: c.accSoft,
      selectionHandleColor: c.acc,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.text3.withAlpha(90)),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.pop, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.popBorder)),
      textStyle: sans(11.5, color: c.text),
      waitDuration: const Duration(milliseconds: 500),
    ),
  );
}
