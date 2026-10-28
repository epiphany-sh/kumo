import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/data/ci_hosts_source.dart';
import 'package:kumo_ui/data/pipelines_source.dart';
import 'package:kumo_ui/engine/engine_pipelines_source.dart';
import 'package:kumo_ui/engine/generated/kumo/v1/kumo.pb.dart' as pb;
import 'package:kumo_ui/overlays/host_settings.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';
import 'package:kumo_ui/widgets/controls.dart';

void main() {
  test('a run comes over as the widget shows it', () {
    final run = ciRunFrom(pb.CiRun(
      id: '11896352187',
      label: 'run #8812 · attempt 2',
      shortSha: '4e1b2c0',
      title: 'feat: BulkDiscount aggregate',
      state: pb.CiState.CI_STATE_FAILED,
      createdAt: Int64(1761660191000),
      finishedAt: Int64(0),
      url: 'https://github.com/pricing/price-admin/actions/runs/11896352187',
      jobs: [
        pb.CiJob(name: 'build', state: pb.CiState.CI_STATE_PASSED, durationMs: Int64(72000)),
        pb.CiJob(
          name: 'integration',
          state: pb.CiState.CI_STATE_FAILED,
          durationMs: Int64(82000),
          failure: 'bulk_test.go:88 · expected 3 rows, got 2',
        ),
        pb.CiJob(name: 'lint', state: pb.CiState.CI_STATE_RUNNING, startedAt: Int64(1761660251000)),
        pb.CiJob(name: 'deploy', state: pb.CiState.CI_STATE_SKIPPED),
      ],
    ));
    expect((run.id, run.label, run.shortSha, run.state), ('11896352187', 'run #8812 · attempt 2', '4e1b2c0', CiState.failed));
    expect(run.createdAt, DateTime.fromMillisecondsSinceEpoch(1761660191000));
    expect(run.finishedAt, isNull, reason: '0 means unknown');
    expect([for (final j in run.jobs) j.state], [CiState.passed, CiState.failed, CiState.running, CiState.skipped]);
    expect(run.jobs[0].duration, const Duration(seconds: 72));
    expect(run.jobs[1].failure, 'bulk_test.go:88 · expected 3 rows, got 2');
    expect(run.jobs[0].failure, isNull, reason: 'empty is no failure line');
    expect(run.jobs[2].startedAt, DateTime.fromMillisecondsSinceEpoch(1761660251000));
    expect(run.jobs[3].duration, isNull);
    expect(run.hasFailedJobs, isTrue);
    expect(run.done, 3);
  });

  test('every problem kind maps, with its extras', () {
    final kinds = {
      pb.CiProblemKind.CI_PROBLEM_KIND_NOT_CONNECTED: CiProblemKind.notConnected,
      pb.CiProblemKind.CI_PROBLEM_KIND_UNAUTHORIZED: CiProblemKind.unauthorized,
      pb.CiProblemKind.CI_PROBLEM_KIND_FORBIDDEN: CiProblemKind.forbidden,
      pb.CiProblemKind.CI_PROBLEM_KIND_NOT_FOUND: CiProblemKind.notFound,
      pb.CiProblemKind.CI_PROBLEM_KIND_RATE_LIMITED: CiProblemKind.rateLimited,
      pb.CiProblemKind.CI_PROBLEM_KIND_UNREACHABLE: CiProblemKind.unreachable,
      pb.CiProblemKind.CI_PROBLEM_KIND_NOT_PUSHED: CiProblemKind.notPushed,
      pb.CiProblemKind.CI_PROBLEM_KIND_UNSUPPORTED: CiProblemKind.unsupported,
    };
    kinds.forEach((wire, kind) => expect(ciProblemFrom(pb.CiProblem(kind: wire)).kind, kind));

    final forbidden = ciProblemFrom(pb.CiProblem(
      kind: pb.CiProblemKind.CI_PROBLEM_KIND_FORBIDDEN,
      detail: 'HTTP 403 · Resource not accessible by personal access token',
      missingScope: 'actions:read',
    ));
    expect((forbidden.detail, forbidden.missingScope, forbidden.needsSettings), ('HTTP 403 · Resource not accessible by personal access token', 'actions:read', true));
    final limited = ciProblemFrom(pb.CiProblem(kind: pb.CiProblemKind.CI_PROBLEM_KIND_RATE_LIMITED, retryAt: Int64(1761660221000)));
    expect((limited.retryAt, limited.keepsLastRun), (DateTime.fromMillisecondsSinceEpoch(1761660221000), true));
    final waiting = ciProblemFrom(pb.CiProblem(kind: pb.CiProblemKind.CI_PROBLEM_KIND_NOT_PUSHED, commitsWaiting: 3));
    expect(waiting.commitsWaiting, 3);
    expect(describeCiProblem(waiting, CiProvider.githubActions).$2, contains('3 commits are waiting'));
  });

  test('providers and hosts', () {
    expect(ciProviderFrom(pb.CiProvider.CI_PROVIDER_GITLAB_CI), CiProvider.gitlabCi);
    expect(ciProviderFrom(pb.CiProvider.CI_PROVIDER_NONE), isNull);
    final host = ciHostFrom(pb.CiHostInfo(
      host: 'github.com',
      provider: pb.CiProvider.CI_PROVIDER_GITHUB_ACTIONS,
      usesGh: true,
      ghAccount: 'MDellag',
      ghAvailable: true,
      repos: ['pricing/app'],
    ))!;
    expect((host.ghAccount, host.ghAvailable), ('MDellag', true));
    expect((host.host, host.provider, host.hasToken, host.usesGh), ('github.com', CiProvider.githubActions, false, true));
    expect(host.repos, ['pricing/app']);
    expect(ciHostFrom(pb.CiHostInfo(host: 'x', provider: pb.CiProvider.CI_PROVIDER_NONE)), isNull);
  });

  testWidgets('Settings › Repositories: test and save a host token', (tester) async {
    final hosts = MockCiHostsSource();
    await _pumpPanel(tester, hosts);
    expect(find.text('github.com'), findsOneWidget);
    expect(find.text('Token saved'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);

    await tester.tap(find.widgetWithText(KButton, 'Connect'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'bad');
    await tester.pump();
    await tester.tap(find.widgetWithText(KButton, 'Test'));
    await tester.pump();
    expect(find.text('Your GitLab token stopped working'), findsOneWidget);
    expect(find.text('HTTP 401 · Bad credentials'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'glpat-new');
    await tester.pump();
    await tester.tap(find.widgetWithText(KButton, 'Save'));
    await tester.pump();
    expect(hosts.saved, [('gitlab.fravega.com', 'glpat-new')]);
    expect(find.text('Token saved'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('GitHub signs in with the GitHub CLI, no token needed', (tester) async {
    final hosts = MockCiHostsSource(hosts: const [CiHostInfo(host: 'github.com', provider: CiProvider.githubActions, ghAvailable: true, repos: ['pricing/app'])]);
    await _pumpPanel(tester, hosts);
    expect(find.text('Not connected'), findsOneWidget);
    await tester.tap(find.widgetWithText(KButton, 'Connect'));
    await tester.pump();
    expect(find.text('Or an access token'), findsOneWidget, reason: 'the token is the other way');
    await tester.tap(find.widgetWithText(KButton, 'Sign in with GitHub CLI'));
    await tester.pump();
    expect(hosts.signIns, ['github.com']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a GitHub host signed in with gh says as whom; without gh, how to get it', (tester) async {
    await _pumpPanel(
      tester,
      MockCiHostsSource(hosts: const [
        CiHostInfo(host: 'github.com', provider: CiProvider.githubActions, usesGh: true, ghAccount: 'MDellag', ghAvailable: true),
        CiHostInfo(host: 'github.acme.dev', provider: CiProvider.githubActions),
      ]),
    );
    expect(find.text('Signed in with gh as MDellag'), findsOneWidget);
    await tester.tap(find.widgetWithText(KButton, 'Connect'));
    await tester.pump();
    expect(find.textContaining('brew install gh'), findsOneWidget);
    expect(find.widgetWithText(KButton, 'Sign in with GitHub CLI'), findsNothing);
  });
}

Future<void> _pumpPanel(WidgetTester tester, CiHostsSource hosts) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AppScope(
    state: AppState(ciHosts: hosts),
    child: const KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: HostTokensPanel()))),
    ),
  ));
  await tester.pump();
  await tester.pump();
}
