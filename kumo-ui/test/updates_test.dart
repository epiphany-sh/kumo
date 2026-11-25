import 'dart:io' as io show exit;
import 'dart:io' show Process;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/platform/os/host_os.dart';
import 'package:kumo_ui/platform/os/key_combo.dart';
import 'package:kumo_ui/platform/os/windows.dart';
import 'package:kumo_ui/platform/updates.dart';

/// Sparkle as the runner would drive it.
class _Updates extends AppUpdates {
  String? _ready;
  var installs = 0;

  void download(String version) {
    _ready = version;
    notifyListeners();
  }

  @override
  String? get ready => _ready;

  @override
  Future<void> installAndRelaunch() async => installs++;
}

/// An updater Settings can ask to check (Windows).
class _CheckingUpdates extends AppUpdates {
  var checks = 0;
  var installs = 0;
  String? ready_;

  @override
  String? get ready => ready_;

  @override
  Future<void> installAndRelaunch() async => installs++;

  @override
  bool get canCheck => true;

  @override
  Future<void> check() async {
    checks++;
    setStatus(const UpdateChecking());
  }

  void finish(UpdateStatus status) => setStatus(status);
}

void main() {
  testWidgets('a downloaded update shows in the toolbar; one click installs it', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final updates = _Updates();
    await tester.pumpWidget(KumoApp(state: AppState(demoWallpaper: true, updates: updates)));
    await tester.pump();
    expect(find.text('Restart to update'), findsNothing);

    updates.download('0.2.0');
    await tester.pump();
    expect(find.byTooltip('Kumo 0.2.0 is downloaded. Restart to use it (open terminals close); otherwise it installs when Kumo quits.'), findsOneWidget);
    await tester.tap(find.text('Restart to update'));
    expect(updates.installs, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a downloaded update also shows bottom right until closed; a newer one shows again', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final updates = _Updates();
    await tester.pumpWidget(KumoApp(state: AppState(demoWallpaper: true, updates: updates)));
    await tester.pump();
    expect(find.text('Kumo 0.2.0 is ready'), findsNothing);

    updates.download('0.2.0');
    await tester.pumpAndSettle();
    final snackbar = tester.getRect(find.text('Kumo 0.2.0 is ready'));
    expect(snackbar.left, greaterThan(1440 / 2), reason: 'on the right');
    expect(snackbar.top, greaterThan(960 * 0.8), reason: 'at the bottom');
    await tester.tap(find.text('Restart'));
    expect(updates.installs, 1);

    await tester.tap(find.byTooltip('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Kumo 0.2.0 is ready'), findsNothing);
    expect(find.text('Restart to update'), findsOneWidget, reason: 'the toolbar keeps it');

    updates.download('0.2.1');
    await tester.pumpAndSettle();
    expect(find.text('Kumo 0.2.1 is ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> openSettings(WidgetTester tester, AppUpdates updates) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(KumoApp(state: AppState(demoWallpaper: true, updates: updates)));
    await tester.pump();
    await tester.tap(find.byTooltip('Settings (${AppKeys.settings.label})'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Settings › General checks for updates by hand where Kumo can, and says how it went', (tester) async {
    final updates = _CheckingUpdates();
    await openSettings(tester, updates);
    expect(find.text('Check for Updates…'), findsOneWidget);
    expect(find.text(describeUpdateStatus(const UpdateIdle())), findsOneWidget);

    await tester.tap(find.text('Check for Updates…'));
    await tester.pump();
    expect(updates.checks, 1);
    expect(find.text('Checking…'), findsOneWidget);

    updates.finish(const UpdateReady('0.9.0'));
    await tester.pump();
    expect(find.text('Kumo 0.9.0 is ready: restart to install it.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings › General offers the restart once an update is ready', (tester) async {
    final updates = _CheckingUpdates();
    await openSettings(tester, updates);
    expect(find.text('Restart to Update'), findsNothing);

    updates.ready_ = '0.9.0';
    updates.finish(const UpdateReady('0.9.0'));
    await tester.pump();
    await tester.tap(find.text('Restart to Update'));
    expect(updates.installs, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings › General has no update check where the build never updates itself', (tester) async {
    await openSettings(tester, _Updates());
    expect(find.text('Check for Updates…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Sparkle offers a check once the runner says it has a feed, and checking asks Sparkle', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final calls = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('kumo/updates'), (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(const MethodChannel('kumo/updates'), null));
    final updates = SparkleUpdates();
    addTearDown(updates.dispose);
    var notified = 0;
    updates.addListener(() => notified++);
    expect(updates.canCheck, isFalse, reason: 'a local build has no feed');

    const codec = StandardMethodCodec();
    await messenger.handlePlatformMessage('kumo/updates', codec.encodeMethodCall(const MethodCall('available', true)), (_) {});
    expect(updates.canCheck, isTrue);
    expect(notified, 1);

    await updates.check();
    expect(calls, ['available', 'check'], reason: 'asked once when created, then checked');
  });

  test('Sparkle installs only once the daemon has stopped', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('kumo/updates'),
      (call) async {
        // Asked once, when created: not part of installing.
        if (call.method != 'available') calls.add(call.method);
        return null;
      },
    );
    final updates = SparkleUpdates(stopDaemon: () async => calls.add('stop kumod'));
    await updates.installAndRelaunch();
    expect(calls, ['stop kumod', 'install']);
    await updates.relaunch();
    expect(calls, ['stop kumod', 'install', 'stop kumod', 'relaunch']);
  });

  test('without the macOS runner, relaunch stops the daemon and asks the OS to start Kumo again', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('kumo/updates'), null);
    final calls = <String>[];
    debugHostOs = _RelaunchingOs(calls);
    addTearDown(() => debugHostOs = null);
    final updates = SparkleUpdates(stopDaemon: () async => calls.add('stop kumod'));
    await updates.relaunch();
    expect(calls, ['stop kumod', 'relaunch after exit']);
  });
}

/// An OS that records being asked to relaunch.
class _RelaunchingOs extends WindowsOs {
  _RelaunchingOs(this.calls) : super(const {});

  final List<String> calls;

  @override
  Future<bool> relaunchAfterExit({int? pid, String? exe, ProcessStarter start = Process.start, void Function(int code) exit = io.exit}) async {
    calls.add('relaunch after exit');
    return true;
  }
}
