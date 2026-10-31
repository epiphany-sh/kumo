import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/agents_source.dart';
import 'package:kumo_ui/data/ai_usage_source.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/shell/side_panel.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';
import 'package:kumo_ui/widgets/usage_meter.dart';

/// Connected providers and runs as a test sets them.
class _Agents extends MockAgentsSource {
  _Agents({List<AgentProviderInfo>? providers}) : _providers = providers;
  final List<AgentProviderInfo>? _providers;
  List<AgentRun> current = const [];

  @override
  List<AgentProviderInfo> get providers => _providers ?? super.providers;
  @override
  List<AgentRun> get runs => current;

  void set(List<AgentRun> runs) {
    current = runs;
    notifyListeners();
  }
}

AgentProviderInfo _p(String id, String name, String short, {bool isDefault = false}) =>
    AgentProviderInfo(id: id, name: name, short: short, program: id, enabled: true, installed: true, isDefault: isDefault);

AgentRun _run(String id, String provider, String name, String path, {List<AgentContextItem> context = const []}) => AgentRun(
      id: id,
      providerId: provider,
      providerName: name,
      short: name.substring(0, 2).toUpperCase(),
      worktreePath: path,
      terminalId: 't-$id',
      title: 'PRC-412',
      status: AgentStatus.running,
      startedAt: DateTime(2026, 10, 30, 13, 54),
      context: context,
    );

Future<AppState> _app(WidgetTester tester, {AgentsSource? agents, AiUsageSource? usage}) async {
  tester.view.physicalSize = const Size(1440, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(demoWallpaper: true, agents: agents, usage: usage);
  await tester.pumpWidget(KumoApp(state: state));
  await tester.pump();
  return state;
}

/// The side panel alone, with only the Session widget.
Future<(AppState, String)> _panel(WidgetTester tester, {required _Agents agents, AiUsageSource? usage}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(agents: agents, usage: usage);
  for (final w in [...state.widgets]) {
    if (w != InspectorWidget.session) state.removeWidget(w);
  }
  await tester.pumpWidget(AppScope(
    state: state,
    child: const KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: SidePanel())),
    ),
  ));
  await tester.pump();
  return (state, state.workspace.absolutePathOf(state.activeWorktreeEntry!));
}

Finder _in(String key, Finder f) => find.descendant(of: find.byKey(ValueKey(key)), matching: f);

void main() {
  group('reading usage', () {
    test('left or used, and highlighted near the end', () {
      const pct = UsageWindow(label: '5-hour session', short: '5h', left: 38);
      const req = UsageWindow(label: 'Premium requests', short: 'mo', left: 88, of: 300, unit: UsageUnit.requests);
      const usd = UsageWindow(label: 'Budget', short: 'mo', left: 31.4, of: 50, unit: UsageUnit.dollars);
      const left = UsageStyle();
      const used = UsageStyle(showUsed: true);
      expect([left.value(pct), left.value(req), left.value(usd)], ['38% left', '88 of 300 left', '\$31.40 of \$50 left']);
      expect([used.value(pct), used.value(req), used.percent(pct)], ['62% used', '212 of 300 used', '62%']);
      expect(left.percent(req), '29%');
      const c = KumoPalette.dark;
      expect(left.tone(c, 0.38), isNull);
      expect(left.tone(c, 0.17), c.warn);
      expect(left.tone(c, 0.06), c.err);
      expect(const UsageStyle(warnAt: 0.10).tone(c, 0.17), isNull);
      expect(const UsageStyle(warnAt: 0.10).tone(c, 0.04), c.err);
      expect(const UsageStyle(warnAt: null).tone(c, 0.01), isNull, reason: 'Never');
    });

    test('resets and token counts read short', () {
      final now = DateTime(2026, 10, 30, 15, 0); // a Friday
      expect(resetLabel(now.add(const Duration(hours: 1, minutes: 48)), now), 'Resets in 1 h 48 min');
      expect(resetLabel(now.add(const Duration(minutes: 22)), now), 'Resets in 22 min');
      expect(resetLabel(DateTime(2026, 11, 2, 9), now), 'Resets Mon 09:00');
      expect(resetLabel(DateTime(2026, 11, 1), now), 'Resets Sun');
      expect(resetLabel(DateTime(2026, 11, 30), now), 'Resets Nov 30');
      expect(resetLabel(null, now), 'Reset time not reported');
      expect([tokensLabel(118000), tokensLabel(1000000), tokensLabel(2400), tokensLabel(400)], ['118k', '1M', '2.4k', '400']);
      expect([tokensLabel(3960), tokensLabel(999500), tokensLabel(1500000)], ['4k', '1M', '1.5M'], reason: 'no “4.0k” or “1000k”');
    });

    test('the tightest window is the one closest to its end', () {
      final plans = MockAiUsageSource.designPlans(DateTime(2026, 10, 30, 15));
      expect(plans['claude']!.tightest!.short, '5h');
      expect(plans['codex']!.tightest!.short, 'wk');
    });
  });

  group('sidebar', () {
    testWidgets('one row per connected agent with its tightest limit; a click shows every window', (tester) async {
      final s = await _app(tester);
      expect(find.text('AI USAGE'), findsOneWidget);
      expect(find.byKey(const ValueKey('usage-claude')), findsOneWidget);
      expect(find.byKey(const ValueKey('usage-codex')), findsOneWidget);
      expect(find.byKey(const ValueKey('usage-gemini')), findsOneWidget);
      expect(find.byKey(const ValueKey('usage-aider')), findsNothing, reason: 'not connected');
      expect(_in('usage-claude', find.text('38%')), findsOneWidget);
      expect(_in('usage-claude', find.text('5h')), findsOneWidget);
      expect(_in('usage-codex', find.text('17%')), findsOneWidget, reason: 'the weekly window is the tighter one');
      expect(_in('usage-gemini', find.text('day')), findsOneWidget);

      await tester.tap(_in('usage-claude', find.text('Claude Code')));
      await tester.pump();
      expect(_in('usage-claude', find.text('Claude Max 5x')), findsOneWidget);
      expect(_in('usage-claude', find.text('Weekly · all models')), findsOneWidget);
      expect(_in('usage-claude', find.text('59% left')), findsOneWidget);
      await tester.tap(_in('usage-claude', find.text('Claude Code')));
      await tester.pump();
      expect(_in('usage-claude', find.text('Claude Max 5x')), findsNothing);

      s.setSetting('usage.as', 'Used');
      await tester.pump();
      expect(_in('usage-claude', find.text('62%')), findsOneWidget);
      s.setSetting('usage.sidebar', false);
      await tester.pump();
      expect(find.text('AI USAGE'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('past four agents the last row folds the rest, and still says one is running low', (tester) async {
      final agents = _Agents(providers: [
        _p('claude', 'Claude Code', 'CC', isDefault: true),
        _p('codex', 'Codex CLI', 'CX'),
        _p('gemini', 'Gemini CLI', 'GM'),
        _p('copilot', 'Copilot CLI', 'CP'),
        _p('aider', 'Aider', 'AD'),
        _p('grok', 'Grok', 'GK'),
      ]);
      final plans = {
        ...MockAiUsageSource.designPlans(DateTime.now()),
        'aider': const AgentPlanUsage(providerId: 'aider', plan: 'API key', windows: [UsageWindow(label: 'Budget', short: 'mo', left: 31.4, of: 50, unit: UsageUnit.dollars)]),
        'grok': const AgentPlanUsage(providerId: 'grok', plan: 'SuperGrok', windows: [UsageWindow(label: 'Requests · 2 h', short: '2h', left: 9)]),
      };
      final s = await _app(tester, agents: agents, usage: MockAiUsageSource(plans: plans));
      expect(find.byKey(const ValueKey('usage-gemini')), findsOneWidget);
      expect(find.byKey(const ValueKey('usage-copilot')), findsNothing);
      expect(find.text('+3 more'), findsOneWidget);
      expect(find.text('Grok almost out'), findsOneWidget);

      await tester.tap(find.text('+3 more'));
      await tester.pump();
      expect(find.byKey(const ValueKey('usage-grok')), findsOneWidget);
      expect(find.text('Show less'), findsOneWidget);

      s.setSetting('usage.rows', 'All');
      await tester.pump();
      expect(find.byKey(const ValueKey('usage-more')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing reported: the footer is just you and Settings', (tester) async {
      await _app(tester, usage: NoAiUsage());
      expect(find.text('AI USAGE'), findsNothing);
      expect(find.byKey(const ValueKey('usage-claude')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Session widget', () {
    testWidgets('the context window with what fills it, and the plan of the agent picked', (tester) async {
      final agents = _Agents();
      final usage = MockAiUsageSource();
      final (_, path) = await _panel(tester, agents: agents, usage: usage);
      expect(find.textContaining('When an agent runs in this worktree'), findsOneWidget);

      agents.set([_run('a1', 'claude', 'Claude Code', path), _run('a2', 'codex', 'Codex CLI', path), _run('x', 'gemini', 'Gemini CLI', '/elsewhere')]);
      await tester.pump();
      expect(find.text('Opus · started 13:54 · 46 turns'), findsOneWidget);
      expect(find.text('118k'), findsOneWidget);
      expect(find.text(' / 200k'), findsOneWidget);
      expect(find.text('82k free · 41% of the window'), findsOneWidget);
      expect(find.text('Discount rules v3'), findsOneWidget);
      expect(find.text('Claude Max 5x'), findsOneWidget);
      expect(find.text('38% left'), findsOneWidget);

      await tester.tap(find.text('Codex CLI'));
      await tester.pump();
      expect(find.text('72k'), findsOneWidget);
      expect(find.text('ChatGPT Plus'), findsOneWidget);
      expect(find.text('17% left'), findsOneWidget);

      await tester.tap(find.text('Compact context'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Typed /compact into Codex CLI'), findsOneWidget);
      expect(find.text('54k'), findsOneWidget, reason: 'older turns became a summary');
      expect(tester.takeException(), isNull);
    });

    testWidgets('three or more agents here: a menu that says how full each one is', (tester) async {
      final agents = _Agents();
      final (_, path) = await _panel(tester, agents: agents, usage: MockAiUsageSource());
      agents.set([
        _run('a1', 'claude', 'Claude Code', path),
        _run('a2', 'codex', 'Codex CLI', path),
        _run('a3', 'gemini', 'Gemini CLI', path),
      ]);
      await tester.pump();
      expect(find.text(' · 3'), findsOneWidget);
      await tester.tap(find.text(' · 3'));
      await tester.pump();
      expect(find.text('RUNNING IN THIS WORKTREE'), findsOneWidget);
      expect(find.text('59% of its context used'), findsOneWidget);
      await tester.tap(find.text('Gemini CLI').last);
      await tester.pump();
      expect(find.text('Gemini Pro · started 13:54 · 7 turns'), findsOneWidget);
      expect(find.text(' / 1M'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without usage from the daemon it shows what the agent was given and says what it can’t read', (tester) async {
      final agents = _Agents();
      final (_, path) = await _panel(tester, agents: agents, usage: NoAiUsage());
      const page = AgentContextItem(kind: AgentContextKind.doc, title: 'Discount rules v3', detail: 'Confluence · Pricing');
      agents.set([_run('a1', 'claude', 'Claude Code', path, context: const [page])]);
      await tester.pump();
      expect(find.text('Claude Code · started 13:54'), findsOneWidget);
      expect(find.text('Kumo can’t read Claude Code’s context window or plan usage yet.'), findsOneWidget);
      expect(find.text('Discount rules v3'), findsOneWidget);
      expect(find.text('Compact context'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
