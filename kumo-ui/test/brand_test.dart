import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/overlays/settings_dialog.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';
import 'package:kumo_ui/widgets/kumo_mark.dart';

void main() {
  testWidgets('the mark paints at icon and tiny sizes, and the lockup reads “Kumo”', (tester) async {
    await tester.pumpWidget(KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: const MaterialApp(home: Scaffold(body: Column(children: [KumoMark(size: 120), KumoMark(size: 16), KumoLockup()]))),
    ));
    expect(find.byType(KumoMark), findsNWidgets(3));
    expect(find.text('kumo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings › General starts with the app’s mark and name', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(KumoApp(state: AppState(demoWallpaper: true)));
    await tester.pump();
    await tester.tap(find.byTooltip('Settings (⌘,)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SettingsDialog), findsOneWidget);
    final settings = find.byType(SettingsDialog);
    expect(find.descendant(of: settings, matching: find.byType(KumoMark)), findsOneWidget);
    expect(find.descendant(of: settings, matching: find.text('kumo')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
