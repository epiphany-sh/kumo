import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/widgets/controls.dart';

Finder _repoRow(String repo) => find.byWidgetPredicate((w) => w is KPressable && (w.semanticLabel ?? '').startsWith('$repo, '));

void main() {
  testWidgets('clicking a namespace folds and unfolds its repos', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(demoWallpaper: true);
    await tester.pumpWidget(KumoApp(state: state));
    await tester.pump();

    final ns = state.namespaces.firstWhere((n) => n.repos.contains('price-admin'));
    expect(ns.collapsed, isFalse);
    expect(_repoRow('price-admin'), findsOneWidget);

    final fold = find.byWidgetPredicate((w) => w is KPressable && w.semanticLabel == 'Collapse ${ns.name}');
    await tester.tap(fold);
    await tester.pump();
    expect(state.namespaceById(ns.id)!.collapsed, isTrue);
    expect(_repoRow('price-admin'), findsNothing);

    await tester.tap(find.byWidgetPredicate((w) => w is KPressable && w.semanticLabel == 'Expand ${ns.name}'));
    await tester.pump();
    expect(state.namespaceById(ns.id)!.collapsed, isFalse);
    expect(_repoRow('price-admin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('from Docs, clicking a worktree goes to its terminals', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(demoWallpaper: true)..view = KumoView.docs;
    await tester.pumpWidget(KumoApp(state: state));
    await tester.pump();
    await tester.tap(find.text('fix/PRC-398-rounding').first);
    await tester.pump();
    expect(state.view, KumoView.terminal);
    expect(state.activeWorktree, 'fix/PRC-398-rounding');
    expect(state.activeContext, isNull, reason: 'its terminals, not a Files or Git tab');
    expect(tester.takeException(), isNull);
  });
}
