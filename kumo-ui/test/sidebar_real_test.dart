import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/ci_hosts_source.dart';
import 'package:kumo_ui/data/pipelines_source.dart';

Future<AppState> _app(WidgetTester tester, {CiHostsSource? hosts}) async {
  tester.view.physicalSize = const Size(1440, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(demoWallpaper: true, ciHosts: hosts);
  await tester.pumpWidget(KumoApp(state: state));
  await tester.pump();
  await tester.pump();
  return state;
}

void main() {
  testWidgets('the switcher shows the workspace with this workspace’s real counts', (tester) async {
    final s = await _app(tester);
    expect(find.text(s.profile.displayName), findsWidgets);
    final repos = s.workspace.repos.length;
    final ns = s.namespaces.length;
    expect(find.text('$ns namespaces · $repos repos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('badges count real things; integrations live in Settings, not the sidebar', (tester) async {
    final s = await _app(tester, hosts: MockCiHostsSource(hosts: const [CiHostInfo(host: 'gitlab.acme.dev', provider: CiProvider.gitlabCi, hasToken: true)]));
    expect(find.byTooltip('gitlab.acme.dev'), findsNothing);
    expect(find.text('AI USAGE'), findsOneWidget, reason: 'its place in the footer');
    final open = s.tasks.tasks.where((t) => t.mine && t.column.name != 'done').length;
    expect(find.text('$open'), findsWidgets, reason: 'the Tasks badge is your open tasks');
  });
}
