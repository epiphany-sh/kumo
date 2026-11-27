import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/data/worktree_lights.dart';
import 'package:kumo_ui/shell/sidebar.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';

Widget _host(bool pulse, {bool reduceMotion = false, bool ticking = true}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: KumoTheme(
        mode: KumoThemeMode.dark,
        palette: KumoPalette.dark,
        terminalPalette: KumoPalette.dark,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TickerMode(enabled: ticking, child: Center(child: WorktreeDot(WorktreeLight.working, pulse: pulse))),
        ),
      ),
    );

double _opacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.descendant(of: find.byType(WorktreeDot), matching: find.byType(Opacity))).opacity;

void main() {
  testWidgets('a pulsing dot fades out and back over 1.1 s, then stops steady', (tester) async {
    await tester.pumpWidget(_host(true));
    expect(_opacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 500));
    final mid = _opacity(tester);
    expect(mid, lessThan(1));
    expect(mid, greaterThan(0.35));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_opacity(tester), closeTo(0.35, 0.01));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(_opacity(tester), closeTo(1, 0.01));

    await tester.pumpWidget(_host(false));
    expect(_opacity(tester), 1);
    await tester.pump(const Duration(seconds: 2));
    expect(_opacity(tester), 1);
  });

  testWidgets('a steady dot stays at full opacity and schedules nothing', (tester) async {
    await tester.pumpWidget(_host(false));
    await tester.pump(const Duration(seconds: 2));
    expect(_opacity(tester), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('less motion keeps the dot steady', (tester) async {
    await tester.pumpWidget(_host(true, reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_opacity(tester), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a dot with tickers off (offstage) does not pulse', (tester) async {
    await tester.pumpWidget(_host(true, ticking: false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_opacity(tester), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(_host(true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_opacity(tester), lessThan(1));
    await tester.pumpWidget(_host(false));
  });

  testWidgets('the dot repaints on its own layer', (tester) async {
    await tester.pumpWidget(_host(true));
    expect(find.descendant(of: find.byType(WorktreeDot), matching: find.byType(RepaintBoundary)), findsOneWidget);
    await tester.pumpWidget(_host(false));
  });
}
