import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/app/preferences.dart';
import 'package:kumo_ui/overlays/settings_dialog.dart';
import 'package:kumo_ui/platform/app_icon.dart';
import 'package:kumo_ui/platform/os/host_os.dart';
import 'package:kumo_ui/platform/os/linux.dart';
import 'package:kumo_ui/platform/os/macos.dart';
import 'package:kumo_ui/platform/os/windows.dart';
import 'package:kumo_ui/theme/palette.dart';

void main() {
  tearDown(() => debugHostOs = null);

  test('the chosen icon: yours only while there is one, Kumo’s otherwise', () {
    final p = Preferences.memory();
    expect(AppIcons.chosen(p), AppIcon.kumo);
    p.set(AppIcons.key, 'own');
    expect(AppIcons.chosen(p), AppIcon.kumo, reason: 'no image made yet');
    p.set(AppIcons.fileKey, '/data/app-icon-1.png');
    expect(AppIcons.chosen(p), AppIcon.own);
    // One a later version offered, then dropped.
    p.set(AppIcons.key, 'gone');
    expect(AppIcons.chosen(p), AppIcon.kumo);
  });

  test('Settings offers a choice where the runner can make one', () {
    debugHostOs = MacOs(const {'HOME': '/Users/test'});
    expect(AppIcons.choosable, isTrue);
    // Windows shows a chosen icon, but has no file dialog and ships only Kumo's.
    debugHostOs = WindowsOs(const {'APPDATA': r'C:\Users\test\AppData\Roaming'});
    expect(AppIcons.supported, isTrue);
    expect(AppIcons.choosable, isFalse);
    debugHostOs = LinuxOs(const {'HOME': '/home/test'});
    expect(AppIcons.supported, isFalse);
  });

  group('Settings → Appearance', () {
    const icons = MethodChannel('kumo/app_icon');
    const pasteboard = MethodChannel('kumo/pasteboard');
    late List<MethodCall> calls;
    late bool readable;

    setUp(() {
      calls = [];
      readable = true;
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(icons, (call) async {
        calls.add(call);
        return call.method == 'make' ? readable : true;
      });
      messenger.setMockMethodCallHandler(pasteboard, (call) async => call.method == 'chooseFile' ? '/Users/test/Pictures/me.jpg' : null);
    });

    tearDown(() {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(icons, null);
      messenger.setMockMethodCallHandler(pasteboard, null);
    });

    Future<AppState> openAppearance(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = AppState(mode: KumoThemeMode.dark, demoWallpaper: true);
      await tester.pumpWidget(KumoApp(state: state));
      await tester.pump();
      await tester.tap(find.byTooltip('Settings (⌘,)'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SettingsDialog), findsOneWidget);
      await tester.tap(find.text('Appearance'));
      await tester.pump();
      return state;
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
    }

    testWidgets('an image of yours becomes the icon, and Kumo’s stays a click away', (tester) async {
      debugHostOs = MacOs(const {'HOME': '/Users/test'});
      final state = await openAppearance(tester);
      expect(find.text('App icon'), findsOneWidget);
      expect(find.textContaining('In the Dock and the app switcher while Kumo runs.'), findsOneWidget);
      expect(state.appIcon, AppIcon.kumo);
      expect(find.text('Yours'), findsNothing, reason: 'none made yet');

      await tester.tap(find.text('Choose image…'));
      await settle(tester);
      final make = calls.singleWhere((c) => c.method == 'make');
      final args = (make.arguments as Map).cast<String, Object?>();
      expect(args['source'], '/Users/test/Pictures/me.jpg');
      final made = args['target'] as String;
      expect(made, matches(RegExp(r'app-icon-\d+\.png$')));
      expect(state.appIcon, AppIcon.own);
      expect(state.ownAppIcon, made);
      expect(calls.last.method, 'setFile');
      expect(calls.last.arguments, made);
      expect(find.text('Yours'), findsOneWidget);

      // Back to Kumo's: yours stays there to go back to.
      await tester.tap(find.text('Kumo').last);
      await tester.pump();
      expect(state.appIcon, AppIcon.kumo);
      expect((calls.last.method, calls.last.arguments), ('set', 'kumo'));
      expect(state.ownAppIcon, made);
      await tester.tap(find.text('Yours'));
      await tester.pump();
      expect(state.appIcon, AppIcon.own);
      expect((calls.last.method, calls.last.arguments), ('setFile', made));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a file that isn’t an image says so and changes nothing', (tester) async {
      debugHostOs = MacOs(const {'HOME': '/Users/test'});
      readable = false;
      final state = await openAppearance(tester);
      await tester.tap(find.text('Choose image…'));
      await settle(tester);
      expect(find.text('Kumo couldn’t read that file as an image.'), findsOneWidget);
      expect(state.appIcon, AppIcon.kumo);
      expect(state.ownAppIcon, isNull);
      expect(calls.map((c) => c.method), ['make']);
    });

    testWidgets('where there is nothing to choose, there is no row', (tester) async {
      debugHostOs = LinuxOs(const {'HOME': '/home/test'});
      await openAppearance(tester);
      expect(find.text('App icon'), findsNothing);
      await AppIcons.apply(Preferences.memory());
      expect(calls, isEmpty);
    });
  });
}
