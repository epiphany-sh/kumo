import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/preferences.dart';
import 'package:kumo_ui/theme/palette.dart';

void main() {
  test('settings survive a restart', () {
    final dir = Directory.systemTemp.createTempSync('kumo_prefs');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/ui.json');

    final first = AppState(prefs: Preferences.load(file));
    first.sidePanelRight = true;
    first.mode = KumoThemeMode.hybrid;
    first.translucency = 0.7;
    first.setSetting('terminal.cursor', 'Bar');
    first.prefs.flush();
    first.dispose();

    final second = AppState(prefs: Preferences.load(file));
    expect(second.sidePanelRight, isTrue);
    expect(second.mode, KumoThemeMode.hybrid);
    expect(second.translucency, closeTo(0.7, 1e-9));
    expect(second.setting<String>('terminal.cursor', 'Block'), 'Bar');
    second.dispose();
  });

  test('a broken file falls back to defaults', () {
    final dir = Directory.systemTemp.createTempSync('kumo_prefs');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/ui.json')..writeAsStringSync('{not json');
    final s = AppState(prefs: Preferences.load(file));
    expect(s.sidePanelRight, isFalse);
    expect(s.sidePanelOpen, isTrue);
    s.dispose();
  });
}
