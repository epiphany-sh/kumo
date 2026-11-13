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

  test('folded repositories stay folded after a restart', () {
    final dir = Directory.systemTemp.createTempSync('kumo_prefs');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/ui.json');

    final first = AppState(prefs: Preferences.load(file));
    expect(first.rememberSidebarFolds, isTrue, reason: 'on by default');
    final ns = first.namespaces.first;
    final repo = first.workspace.repo(ns.repos.first)!;
    expect(first.isRepoFolded(ns.id, repo), isFalse);
    first.toggleRepoFolded(ns.id, repo);
    expect(first.isRepoFolded(ns.id, repo), isTrue);
    first.prefs.flush();
    first.dispose();

    final second = AppState(prefs: Preferences.load(file));
    expect(second.isRepoFolded(ns.id, repo), isTrue);
    // Off: nothing is kept, the next launch opens everything.
    second.rememberSidebarFolds = false;
    second.prefs.flush();
    second.dispose();

    final third = AppState(prefs: Preferences.load(file));
    expect(third.rememberSidebarFolds, isFalse);
    expect(third.isRepoFolded(ns.id, repo), isFalse);
    third.toggleRepoFolded(ns.id, repo);
    third.prefs.flush();
    third.dispose();

    final fourth = AppState(prefs: Preferences.load(file));
    expect(fourth.isRepoFolded(ns.id, repo), isFalse);
    fourth.dispose();
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
