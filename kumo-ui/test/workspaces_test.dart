import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/app/preferences.dart';
import 'package:kumo_ui/data/profiles_source.dart';
import 'package:kumo_ui/engine/engine_profiles.dart';
import 'package:kumo_ui/overlays/new_workspace_dialog.dart';
import 'package:kumo_ui/overlays/settings_dialog.dart';

Future<AppState> _app(WidgetTester tester, {ProfilesSource? profiles, WorkspaceOpener? open}) async {
  tester.view.physicalSize = const Size(1440, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(demoWallpaper: true, profiles: profiles);
  await tester.pumpWidget(KumoApp(state: state, openWorkspace: open));
  await tester.pump();
  return state;
}

Future<void> _openSwitcher(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('workspace-switcher')));
  await tester.pump();
}

void main() {
  group('workspaces', () {
    test('names stay unique, and the default, current and last one stay', () async {
      final p = MockProfilesSource();
      expect(p.current.name, 'Fravega');
      await expectLater(p.create(name: ' personal ', color: profileColors.first.$2), throwsA(contains('already')));
      final made = await p.create(name: 'Side gig', color: profileColors[4].$2);
      expect(made.worktreesDir, '~/wt/side-gig/{repo}/{key}');
      expect(p.profiles.last.id, made.id);
      await p.update(made.id, const ProfileChanges(name: 'Side project', gitEmail: 'me@example.com'));
      expect(p.profiles.last.name, 'Side project');
      expect(p.profiles.last.gitEmail, 'me@example.com');
      await expectLater(p.delete('default'), throwsA(contains('first workspace')));
      await expectLater(p.delete(p.currentId), throwsA(anything));
      await p.delete(made.id);
      expect(p.profiles.length, 3);
    });

    test('colors go to the daemon as #RRGGBB and back', () {
      expect(colorHex(const Color(0xFF8C9BFF)), '#8C9BFF');
      expect(colorFromHex('#4cc38a'), const Color(0xFF4CC38A));
      expect(colorFromHex('nope'), isNull);
      expect(worktreesDirFor('Acme Consulting!'), '~/wt/acme-consulting/{repo}/{key}');
    });

    test('an older kumod: one workspace, which can still be named', () async {
      final prefs = Preferences.memory();
      final p = SingleProfileSource(prefs);
      expect(p.canManage, isFalse);
      expect(p.current.displayName, 'Workspace');
      await p.update('default', const ProfileChanges(name: 'Fravega'));
      expect(p.current.displayName, 'Fravega');
      await expectLater(p.create(name: 'x', color: profileColors.first.$2), throwsA(contains('update it')));
    });

    testWidgets('the switcher lists each workspace with what runs there; picking one switches, Undo comes back', (tester) async {
      final s = await _app(tester);
      expect(find.text('Fravega'), findsOneWidget);
      await _openSwitcher(tester);
      expect(find.text('WORKSPACES'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('1 agent needs you'), findsWidgets);
      expect(find.text('⌃⌘3'), findsOneWidget);
      expect(find.text('New workspace…'), findsOneWidget);
      await tester.tap(find.text('Personal'));
      await tester.pump();
      expect(s.profile.id, 'personal');
      expect(s.inHome, isTrue, reason: 'a workspace not visited yet starts at Home');
      expect(s.undo?.message, 'In Personal · Fravega keeps running');
      s.undoLast();
      await tester.pump();
      expect(s.profile.id, 'default');
      expect(s.inHome, isFalse, reason: 'back where you were');
      expect(tester.takeException(), isNull);
    });

    testWidgets('⌃⌘3 switches to the third workspace', (tester) async {
      final s = await _app(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(s.profile.id, 'acme');
      s.dismissUndo();
      expect(tester.takeException(), isNull);
    });

    testWidgets('with a state per workspace, switching shows the other’s and coming back keeps the first', (tester) async {
      final profiles = MockProfilesSource();
      final made = <String>[];
      AppState? personal;
      final first = await _app(tester, profiles: profiles, open: (p) {
        made.add(p.id);
        final next = AppState(demoWallpaper: true, profiles: profiles, ownsShared: false);
        if (p.id == 'personal') personal = next;
        return (next, null);
      });
      await first.switchProfile('personal');
      await tester.pump();
      expect(made, ['personal']);
      expect(personal!.undo?.message, 'In Personal · Fravega keeps running', reason: 'the new state says where you came from');
      await personal!.switchProfile('default');
      await tester.pump();
      expect(made, ['personal'], reason: 'Fravega’s state was kept, not made again');
      await first.switchProfile('personal');
      await tester.pump();
      expect(made, ['personal']);
      first.dismissUndo();
      personal!.dismissUndo();
      expect(tester.takeException(), isNull);
    });

    testWidgets('New workspace: name it, it gets its own folder, then switch to it', (tester) async {
      final s = await _app(tester);
      await _openSwitcher(tester);
      await tester.tap(find.text('New workspace…'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('~/wt/{workspace}/{repo}/{key}'), findsOneWidget);
      await tester.enterText(find.descendant(of: find.byType(NewWorkspaceDialog), matching: find.byType(TextField)), 'Side gig');
      await tester.pump();
      expect(find.text('~/wt/side-gig/{repo}/{key}'), findsOneWidget);
      await tester.tap(find.text('Create workspace'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Side gig is ready'), findsOneWidget);
      await tester.tap(find.text('Switch to Side gig'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(s.profile.name, 'Side gig');
      s.dismissUndo();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Settings › Workspaces: what belongs to each; the current and the first can’t be deleted', (tester) async {
      final s = await _app(tester);
      await tester.tap(find.byTooltip('Settings (⌘,)'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Workspaces').first);
      await tester.pump();
      expect(find.text('This window'), findsOneWidget);
      expect(find.text('Open in new window'), findsNWidgets(2));
      await tester.tap(find.text('Configure').last);
      await tester.pump();
      expect(find.text('WHAT BELONGS ONLY TO ACME CONSULTING'), findsOneWidget);
      expect(find.textContaining('Switch to Acme Consulting to edit them'), findsOneWidget);
      await tester.ensureVisible(find.text('Delete workspace…'));
      await tester.pump();
      await tester.tap(find.text('Delete workspace…'));
      await tester.pump();
      expect(find.text('Delete Acme Consulting?'), findsOneWidget);
      await tester.ensureVisible(find.text('Delete Acme Consulting'));
      await tester.pump();
      await tester.tap(find.text('Delete Acme Consulting'));
      await tester.pump();
      await tester.pump();
      expect(s.profiles.profiles.map((p) => p.id), ['default', 'personal']);
      expect(find.textContaining('Acme Consulting deleted'), findsOneWidget);

      await tester.tap(find.text('Repositories'));
      await tester.pump();
      expect(find.text('Only for Fravega. '), findsNothing, reason: 'it is one rich text');
      expect(find.textContaining('Only for Fravega.', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an older kumod: the switcher says how to get more workspaces', (tester) async {
      await _app(tester, profiles: SingleProfileSource(Preferences.memory()));
      expect(find.text('Workspace'), findsOneWidget);
      await _openSwitcher(tester);
      expect(find.text('Update kumod to keep workspaces apart'), findsOneWidget);
      expect(find.byTooltip('Open Workspace in a new window'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  test('Settings has a Workspaces tab', () {
    expect(SettingsTab.values.map((t) => t.label), contains('Workspaces'));
  });
}
