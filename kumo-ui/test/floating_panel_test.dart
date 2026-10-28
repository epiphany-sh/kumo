import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/widgets/glass.dart';

void main() {
  testWidgets('New worktree opens centered, drags by its header and stays in the window', (tester) async {
    const window = Size(1440, 900);
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(demoWallpaper: true);
    await tester.pumpWidget(KumoApp(state: state));
    await tester.pump();

    Rect panel() => tester.getRect(find.ancestor(of: find.text('New worktree'), matching: find.byType(GlassOverlay)));
    final inside = Offset.zero & window;

    state.requestNewWorktree();
    await tester.pump();
    final opened = panel();
    expect(opened.center.dx, closeTo(window.width / 2, 1));
    expect(inside.intersect(opened), opened, reason: 'the whole panel is visible');

    await tester.drag(find.text('New worktree'), const Offset(-200, 50));
    await tester.pump();
    expect(panel().topLeft - opened.topLeft, const Offset(-200, 50));

    // Past an edge it stops at the margin, and coming back has no dead zone.
    await tester.drag(find.text('New worktree'), const Offset(-5000, 0));
    await tester.pump();
    expect(panel().left, 16);
    await tester.drag(find.text('New worktree'), const Offset(30, 0));
    await tester.pump();
    expect(panel().left, 46);

    // It reopens where it was left.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('New worktree'), findsNothing);
    state.requestNewWorktree();
    await tester.pump();
    expect(panel().left, 46);

    // Double-clicking the header centers it again.
    await tester.tap(find.text('New worktree'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('New worktree'));
    await tester.pumpAndSettle();
    expect(panel().center.dx, closeTo(window.width / 2, 1));
    expect(tester.takeException(), isNull);
  });
}
