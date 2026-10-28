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
  testWidgets('the switcher shows the selected worktree’s namespace with real counts and jumps to another', (tester) async {
    final s = await _app(tester);
    final ns = s.namespaces.firstWhere((n) => n.repos.contains(s.activeRepo!.id));
    final repos = [for (final id in ns.repos) s.workspace.repo(id)!];
    final worktrees = repos.fold<int>(0, (n, r) => n + s.worktreesOf(r).length);
    expect(find.text('${repos.length} repos · $worktrees worktrees'), findsOneWidget);
    final other = s.namespaces.firstWhere((n) => n.id != ns.id);
    await tester.tap(find.text('${repos.length} repos · $worktrees worktrees'));
    await tester.pump();
    await tester.tap(find.text(other.name).last);
    await tester.pump();
    expect(other.repos, contains(s.activeRepo!.id), reason: 'its first repository is selected');
    expect(tester.takeException(), isNull);
  });

  testWidgets('integrations come from the connected task sources and hosts; badges count real things', (tester) async {
    final s = await _app(tester, hosts: MockCiHostsSource(hosts: const [CiHostInfo(host: 'gitlab.acme.dev', provider: CiProvider.gitlabCi, hasToken: true)]));
    for (final src in s.tasks.sources) {
      expect(find.byTooltip(src.name), findsOneWidget, reason: src.name);
    }
    expect(find.byTooltip('gitlab.acme.dev'), findsOneWidget);
    expect(find.text('${s.tasks.sources.map((x) => x.kind.badge).toSet().length + 1} connected'), findsOneWidget);
    final open = s.tasks.tasks.where((t) => t.mine && t.column.name != 'done').length;
    expect(find.text('$open'), findsWidgets, reason: 'the Tasks badge is your open tasks');
  });
}
