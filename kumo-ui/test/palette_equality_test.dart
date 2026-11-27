import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';

KumoTheme _theme(KumoPalette p) => KumoTheme(mode: KumoThemeMode.dark, palette: p, terminalPalette: KumoPalette.dark, child: const SizedBox());

void main() {
  test('palettes with the same colors are equal', () {
    final copy = KumoPalette.dark.copyWith();
    expect(identical(copy, KumoPalette.dark), isFalse);
    expect(copy, KumoPalette.dark);
    expect(copy.hashCode, KumoPalette.dark.hashCode);
    expect(KumoPalette.light, isNot(KumoPalette.dark));
    expect(KumoPalette.dark.copyWith(window: const Color(0x01000000)), isNot(KumoPalette.dark));
    expect(KumoPalette.dark.copyWith(panelShadow: const []), isNot(KumoPalette.dark));
  });

  test('the same translucency gives back the same palette', () {
    final a = KumoPalette.dark.withTranslucency(0.6);
    expect(identical(KumoPalette.dark.withTranslucency(0.6), a), isTrue);
    expect(KumoPalette.dark.withTranslucency(0.8), isNot(a));
    expect(KumoPalette.light.withTranslucency(0.6), isNot(a));
    expect(KumoPalette.dark.withTranslucency(0.6), a);
  });

  test('the Material theme is built once per palette', () {
    final p = KumoPalette.light.withTranslucency(0.5);
    final t = materialThemeFor(p);
    expect(identical(materialThemeFor(p.copyWith()), t), isTrue);
    expect(identical(materialThemeFor(KumoPalette.dark), t), isFalse);
  });

  test('the theme tells its readers only when a color changed', () {
    final p = KumoPalette.dark.withTranslucency(0.6);
    expect(_theme(p.copyWith()).updateShouldNotify(_theme(p)), isFalse);
    expect(_theme(p.copyWith(term: const Color(0x01000000))).updateShouldNotify(_theme(p)), isTrue);
  });
}
