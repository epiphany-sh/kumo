import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/widgets/controls.dart';

void main() {
  testWidgets('New worktree: the path follows the branch until the user writes one', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(demoWallpaper: true);
    await tester.pumpWidget(KumoApp(state: state));
    await tester.pump();
    state.requestNewWorktree();
    await tester.pump();

    Finder field(String label) => find.descendant(of: find.widgetWithText(KField, label), matching: find.byType(TextField));
    String path() => tester.widget<TextField>(field('Path')).controller!.text;

    await tester.tap(find.text('New branch'));
    await tester.pump();
    final root = path().substring(0, path().lastIndexOf('/') + 1);
    expect(root, startsWith('~/wt/'));

    // A fresh branch never leaves the path on the repo folder, which
    // already exists after the first worktree.
    await tester.enterText(field('Branch'), 'feat/test');
    await tester.pump();
    expect(path(), '${root}feat-test');

    await tester.enterText(field('Path'), '~/elsewhere');
    await tester.enterText(field('Branch'), 'feat/other');
    await tester.pump();
    expect(path(), '~/elsewhere');

    // Switching the source starts over with the default.
    await tester.tap(find.text('Existing'));
    await tester.pump();
    final branch = tester.widget<TextField>(field('Branch')).controller!.text;
    expect(path(), '$root${branch.replaceAll('/', '-')}');
    expect(tester.takeException(), isNull);
  });
}
