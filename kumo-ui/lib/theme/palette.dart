import 'package:flutter/widgets.dart';

/// The three looks from the design canvas.
/// - [dark]: dark glass everywhere.
/// - [light]: light glass everywhere.
/// - [hybrid]: light chrome, dark "smoked glass" terminal area.
enum KumoThemeMode { dark, light, hybrid }

/// Every color token the UI uses. Ported 1:1 from the design canvas
/// (tokens() in each artboard). Alpha is baked into the hex so nothing
/// depends on deprecated Color helpers.
@immutable
class KumoPalette {
  const KumoPalette({
    required this.brightness,
    required this.window,
    required this.windowBorder,
    required this.panel,
    required this.panelStrong,
    required this.panelBorder,
    required this.panelSheen,
    required this.panelShadow,
    required this.chip,
    required this.chipBorder,
    required this.chipSheen,
    required this.navActive,
    required this.tabActive,
    required this.term,
    required this.pane,
    required this.paneBorder,
    required this.divider,
    required this.paper,
    required this.pop,
    required this.popBorder,
    required this.text,
    required this.text2,
    required this.text3,
    required this.acc,
    required this.accSoft,
    required this.accFill,
    required this.accText,
    required this.ok,
    required this.okSoft,
    required this.warn,
    required this.warnSoft,
    required this.err,
    required this.errSoft,
    required this.purple,
    required this.yellow,
    required this.cyan,
    required this.tile,
    required this.tileText,
    required this.codeBg,
    required this.addBg,
    required this.delBg,
    required this.hunkBg,
    required this.synKw,
    required this.synStr,
    required this.synNum,
    required this.synType,
    required this.synFn,
    required this.synKey,
    required this.curBg,
    required this.curMark,
    required this.incBg,
    required this.incMark,
    required this.wallpaperBase,
    required this.wallpaperBlobs,
  });

  final Brightness brightness;

  /// Tint painted over the native vibrancy (or over the demo wallpaper).
  final Color window;
  final Color windowBorder;

  final Color panel;
  final Color panelStrong;
  final Color panelBorder;

  /// Top "liquid" highlight blended into panel fills.
  final Color panelSheen;
  final List<BoxShadow> panelShadow;

  final Color chip;
  final Color chipBorder;
  final Color chipSheen;

  final Color navActive;
  final Color tabActive;
  final Color term;
  final Color pane;
  final Color paneBorder;
  final Color divider;
  final Color paper;
  final Color pop;
  final Color popBorder;

  final Color text;
  final Color text2;
  final Color text3;

  final Color acc;
  final Color accSoft;
  final Color accFill;
  final Color accText;

  final Color ok;
  final Color okSoft;
  final Color warn;
  final Color warnSoft;
  final Color err;
  final Color errSoft;

  final Color purple;
  final Color yellow;
  final Color cyan;

  final Color tile;
  final Color tileText;
  final Color codeBg;
  final Color addBg;
  final Color delBg;
  final Color hunkBg;

  final Color synKw;
  final Color synStr;
  final Color synNum;
  final Color synType;
  final Color synFn;
  final Color synKey;

  final Color curBg;
  final Color curMark;
  final Color incBg;
  final Color incMark;

  /// Only used when there is no native translucency (Linux, tests, or the
  /// "demo wallpaper" setting). Mirrors the canvas backgrounds.
  final Color wallpaperBase;
  final List<Color> wallpaperBlobs;

  bool get isDark => brightness == Brightness.dark;

  static const dark = KumoPalette(
    brightness: Brightness.dark,
    window: Color(0x8C10121A), // rgba(16,18,26,.55)
    windowBorder: Color(0x1FFFFFFF),
    panel: Color(0x0EFFFFFF),
    panelStrong: Color(0x17FFFFFF),
    panelBorder: Color(0x1AFFFFFF),
    panelSheen: Color(0x14FFFFFF),
    panelShadow: [BoxShadow(color: Color(0x38000000), blurRadius: 30, offset: Offset(0, 10))],
    chip: Color(0x14FFFFFF),
    chipBorder: Color(0x1FFFFFFF),
    chipSheen: Color(0x1FFFFFFF),
    navActive: Color(0x1CFFFFFF),
    tabActive: Color(0x1AFFFFFF),
    term: Color(0x6B06070C),
    pane: Color(0x08FFFFFF),
    paneBorder: Color(0x12FFFFFF),
    divider: Color(0x14FFFFFF),
    paper: Color(0x730A0B12),
    pop: Color(0xD91E202C),
    popBorder: Color(0x24FFFFFF),
    text: Color(0xFFF3F4F8),
    text2: Color(0xBDECEEF6),
    text3: Color(0x8FECEEF6),
    acc: Color(0xFF97A6FF),
    accSoft: Color(0x2997A6FF),
    accFill: Color(0xFF97A6FF),
    accText: Color(0xFF0B0D18),
    ok: Color(0xFF5EE09A),
    okSoft: Color(0x245EE09A),
    warn: Color(0xFFFFB45C),
    warnSoft: Color(0x29FFB45C),
    err: Color(0xFFFF8A8A),
    errSoft: Color(0x24FF8A8A),
    purple: Color(0xFFC8A6FF),
    yellow: Color(0xFFF2D27A),
    cyan: Color(0xFF7FDBEA),
    tile: Color(0x1AFFFFFF),
    tileText: Color(0xFFE6E8F0),
    codeBg: Color(0x38000000),
    addBg: Color(0x1A5EE09A),
    delBg: Color(0x1AFF8A8A),
    hunkBg: Color(0x1497A6FF),
    synKw: Color(0xFFC8A6FF),
    synStr: Color(0xFF9FE3B0),
    synNum: Color(0xFFF5B97A),
    synType: Color(0xFF7FDBEA),
    synFn: Color(0xFFA3B4FF),
    synKey: Color(0xFF8FC7FF),
    curBg: Color(0x175EE09A),
    curMark: Color(0x335EE09A),
    incBg: Color(0x1A78A0FF),
    incMark: Color(0x3878A0FF),
    wallpaperBase: Color(0xFF07080D),
    wallpaperBlobs: [Color(0x996C54FF), Color(0x7A00A8BE), Color(0x61DE468C)],
  );

  static const light = KumoPalette(
    brightness: Brightness.light,
    window: Color(0x6BFFFFFF), // rgba(255,255,255,.42)
    windowBorder: Color(0xCCFFFFFF),
    panel: Color(0x80FFFFFF),
    panelStrong: Color(0xB8FFFFFF),
    panelBorder: Color(0xD9FFFFFF),
    panelSheen: Color(0x99FFFFFF),
    panelShadow: [
      BoxShadow(color: Color(0x0F1E1E3C), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x14282850), blurRadius: 32, offset: Offset(0, 12)),
    ],
    chip: Color(0x99FFFFFF),
    chipBorder: Color(0x14141428),
    chipSheen: Color(0xCCFFFFFF),
    navActive: Color(0xE6FFFFFF),
    tabActive: Color(0xEBFFFFFF),
    term: Color(0xA8FFFFFF),
    pane: Color(0x9EFFFFFF),
    paneBorder: Color(0x12141428),
    divider: Color(0x14141428),
    paper: Color(0xC7FFFFFF),
    pop: Color(0xCCFFFFFF),
    popBorder: Color(0xF2FFFFFF),
    text: Color(0xFF15161C),
    text2: Color(0xBD15161C),
    text3: Color(0x9915161C),
    acc: Color(0xFF3A4FD8),
    accSoft: Color(0x1F3A4FD8),
    accFill: Color(0xFF3A4FD8),
    accText: Color(0xFFFFFFFF),
    ok: Color(0xFF137A43),
    okSoft: Color(0x1C137A43),
    warn: Color(0xFFA35200),
    warnSoft: Color(0x24D67814),
    err: Color(0xFFB42318),
    errSoft: Color(0x1AB42318),
    purple: Color(0xFF6E3BC9),
    yellow: Color(0xFF8A5C00),
    cyan: Color(0xFF0E6F7E),
    tile: Color(0x0F141628),
    tileText: Color(0xFF2A2C36),
    codeBg: Color(0x0D141628),
    addBg: Color(0x1A137A43),
    delBg: Color(0x17B42318),
    hunkBg: Color(0x123A4FD8),
    synKw: Color(0xFF7A3FD1),
    synStr: Color(0xFF137A43),
    synNum: Color(0xFFA35200),
    synType: Color(0xFF0E6F7E),
    synFn: Color(0xFF3A4FD8),
    synKey: Color(0xFF1F5FA8),
    curBg: Color(0x14137A43),
    curMark: Color(0x2E137A43),
    incBg: Color(0x143A4FD8),
    incMark: Color(0x2E3A4FD8),
    wallpaperBase: Color(0xFFEDF0F6),
    wallpaperBlobs: [Color(0xBFA0BEFF), Color(0xCCB0E0E8), Color(0xB3CCC4FF)],
  );

  /// Terminal area for the hybrid look: dark tokens, more opaque smoked glass.
  static final hybridTerminal = dark.copyWith(
    term: const Color(0xD6141620),
    pane: const Color(0x09FFFFFF),
    panelBorder: const Color(0x24FFFFFF),
    panelShadow: const [BoxShadow(color: Color(0x471E2250), blurRadius: 44, offset: Offset(0, 20))],
  );

  KumoPalette copyWith({
    Color? term,
    Color? pane,
    Color? panelBorder,
    List<BoxShadow>? panelShadow,
    Color? window,
  }) {
    return KumoPalette(
      brightness: brightness,
      window: window ?? this.window,
      windowBorder: windowBorder,
      panel: panel,
      panelStrong: panelStrong,
      panelBorder: panelBorder ?? this.panelBorder,
      panelSheen: panelSheen,
      panelShadow: panelShadow ?? this.panelShadow,
      chip: chip,
      chipBorder: chipBorder,
      chipSheen: chipSheen,
      navActive: navActive,
      tabActive: tabActive,
      term: term ?? this.term,
      pane: pane ?? this.pane,
      paneBorder: paneBorder,
      divider: divider,
      paper: paper,
      pop: pop,
      popBorder: popBorder,
      text: text,
      text2: text2,
      text3: text3,
      acc: acc,
      accSoft: accSoft,
      accFill: accFill,
      accText: accText,
      ok: ok,
      okSoft: okSoft,
      warn: warn,
      warnSoft: warnSoft,
      err: err,
      errSoft: errSoft,
      purple: purple,
      yellow: yellow,
      cyan: cyan,
      tile: tile,
      tileText: tileText,
      codeBg: codeBg,
      addBg: addBg,
      delBg: delBg,
      hunkBg: hunkBg,
      synKw: synKw,
      synStr: synStr,
      synNum: synNum,
      synType: synType,
      synFn: synFn,
      synKey: synKey,
      curBg: curBg,
      curMark: curMark,
      incBg: incBg,
      incMark: incMark,
      wallpaperBase: wallpaperBase,
      wallpaperBlobs: wallpaperBlobs,
    );
  }

  /// Window tint for a translucency level (0.25–0.9), as in the canvas tweak.
  KumoPalette withTranslucency(double t) {
    final a = (isDark ? t : (t - 0.14).clamp(0.12, 1.0)).clamp(0.0, 1.0);
    final base = isDark ? const Color(0xFF10121A) : const Color(0xFFFFFFFF);
    return copyWith(window: base.withAlpha((a * 255).round()));
  }
}
