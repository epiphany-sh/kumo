import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/data/agents_source.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/overlays/agent_settings.dart';
import 'package:kumo_ui/overlays/new_agent_dialog.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';
import 'package:kumo_ui/views/agents_screen.dart';

/// A daemon-like source that records what the UI asks for.
class _FakeAgents extends AgentsSource {
  _FakeAgents({this.providers = const [], this.runs = const []});

  @override
  List<AgentProviderInfo> providers;
  @override
  List<AgentRun> runs;
  final saved = <(String?, bool)>[];
  final stopped = <String>[];

  @override
  bool get live => true;
  @override
  Future<void> get ready async {}
  @override
  String? get error => null;
  @override
  Future<void> loadProviders() async {}

  @override
  Future<AgentProviderInfo?> saveProvider({String? id, required String name, required String program, String args = '', required bool enabled, bool isDefault = false}) async {
    saved.add((id, enabled));
    return null;
  }

  @override
  Future<void> deleteProvider(String id) async {}
  @override
  Future<String> test(String id) async => '$id 1.0';
  @override
  Future<String?> login(String id) async => null;
  @override
  Future<AgentRun?> start({String? providerId, required String worktreePath, String prompt = '', String title = ''}) async => null;
  @override
  Future<void> stop(String id) async => stopped.add(id);
  @override
  Future<void> dismiss(String id) async {}
}

Future<AppState> pump(WidgetTester tester, Widget child, AgentsSource agents) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(agents: agents);
  await tester.pumpWidget(AppScope(
    state: state,
    child: KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  ));
  await tester.pump();
  return state;
}

void main() {
  testWidgets('settings shows installed, missing and connected agents; Connect saves', (tester) async {
    final agents = _FakeAgents(providers: const [
      AgentProviderInfo(id: 'claude', name: 'Claude Code', short: 'CC', program: 'claude', installed: true, resolvedPath: '/usr/local/bin/claude'),
      AgentProviderInfo(id: 'grok', name: 'Grok', short: 'GK', program: 'grok', installHint: 'Install a Grok coding CLI'),
      AgentProviderInfo(id: 'mine', name: 'My agent', short: 'MA', program: 'my-agent', custom: true, enabled: true, installed: true),
    ]);
    await pump(tester, const SingleChildScrollView(child: AgentSettingsPanel()), agents);

    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Not installed'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Copy install command'), findsOneWidget);

    await tester.tap(find.text('Connect'));
    await tester.pump();
    expect(agents.saved, [('claude', true)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new agent without any connected says where to connect one', (tester) async {
    await pump(tester, const NewAgentDialog(), _FakeAgents());
    expect(find.text('No agent connected yet'), findsOneWidget);
    expect(find.text('Open AI agents settings'), findsOneWidget);
  });

  testWidgets('agents view lists real sessions and stops them', (tester) async {
    final agents = _FakeAgents(runs: [
      AgentRun(
        id: 'a1',
        providerId: 'claude',
        providerName: 'Claude Code',
        short: 'CC',
        worktreePath: '/wt/app/x',
        terminalId: 't1',
        title: 'Fix the flaky test',
        status: AgentStatus.needsYou,
        startedAt: DateTime.now(),
        lastLine: 'Do you want to run make test?',
      ),
    ]);
    await pump(tester, const AgentsScreen(), agents);

    expect(find.text('Fix the flaky test'), findsOneWidget);
    expect(find.text('Needs you'), findsWidgets);
    expect(find.textContaining('make test'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(agents.stopped, ['a1']);
  });
}
