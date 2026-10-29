import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
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
    expect(find.byTooltip('Kumo 0.2.0 is downloaded. Restart to use it; otherwise it installs when Kumo quits.'), findsOneWidget);
    await tester.tap(find.text('Restart to update'));
    expect(updates.installs, 1);
    expect(tester.takeException(), isNull);
  });
}
