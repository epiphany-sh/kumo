import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/agent_defs.dart';
import 'package:kumo_ui/data/agent_defs_source.dart';
import 'package:kumo_ui/data/agent_playground.dart';
import 'package:kumo_ui/data/ai_usage_source.dart';
import 'package:kumo_ui/data/plan_limits.dart';
import 'package:kumo_ui/widgets/controls.dart' show KSegmented;

/// When a CLI's plan runs out, your agents go on in another one.
void main() {
  final now = DateTime(2026, 11, 9, 14);
  UsageWindow window(double left, {Duration resets = const Duration(hours: 2)}) =>
      UsageWindow(label: '5-hour session', short: '5h', left: left, resets: now.add(resets));
  AgentPlanUsage plan(String id, double left, {Duration resets = const Duration(hours: 2)}) =>
      AgentPlanUsage(providerId: id, plan: 'x', windows: [window(left, resets: resets), UsageWindow(label: 'Weekly', short: 'wk', left: 40, resets: now.add(const Duration(days: 3)))]);

  group('a used-up plan', () {
    test('is a window with nothing left that hasn’t started over', () {
      expect(usedUp(plan('claude', 0), now)?.label, '5-hour session');
      expect(usedUp(plan('claude', 0.5), now), isNull);
      expect(usedUp(plan('claude', 0, resets: const Duration(minutes: -1)), now), isNull, reason: 'it started over');
      expect(usedUp(const AgentPlanUsage(providerId: 'copilot', plan: 'x', problem: 'signed out'), now), isNull, reason: 'unknown isn’t out');
      expect(usedUp(null, now), isNull);
    });

    test('the CLIs say so in their own words, and work that mentions limits isn’t it', () {
      for (final said in [
        'Claude AI usage limit reached|1790387720',
        '5-hour limit reached ∙ resets 3pm',
        'You\'ve hit your limit · resets 7pm (America/Buenos_Aires)',
        'You\'ve hit your usage limit. Upgrade to Pro or try again in 2 hours.',
        'You have exceeded your premium requests allowance for this month.',
        'Error: quota exceeded',
        'You have no remaining AI credits.',
      ]) {
        expect(saysLimitReached(said), isTrue, reason: said);
      }
      for (final work in ['Reviewed the limiter: 3 findings.', 'Error: Model "x" from --model flag is not available.', 'Done.']) {
        expect(saysLimitReached(work), isFalse, reason: work);
      }
    });

    test('it goes on with the first connected CLI that isn’t out, and starts there', () {
      const clis = [AgentCli.claude, AgentCli.codex, AgentCli.copilot];
      final out = {AgentCli.claude: window(0)};
      expect(goOnWith(clis, AgentCli.claude, out), AgentCli.codex);
      expect(goOnWith(clis, AgentCli.claude, {...out, AgentCli.codex: window(0)}), AgentCli.copilot);
      expect(goOnWith(const [AgentCli.claude], AgentCli.claude, out), isNull);
      expect(startWith(clis, null, out), AgentCli.codex);
      expect(startWith(clis, AgentCli.claude, out), AgentCli.claude, reason: 'what you picked stays');
      expect(startWith(const [AgentCli.claude], null, out), AgentCli.claude, reason: 'all out: the default');
      expect(startWith(const [], null, out), isNull);
    });

    test('the first message of the run that goes on says where it stands', () {
      expect(goOnPrompt('Review #521', AgentCli.claude), startsWith('Review #521\n\nAnother AI (Claude Code) started this here'));
      expect(goOnPrompt('  ', AgentCli.codex), startsWith('Another AI (Codex CLI)'));
    });
  });

  group('in Agents', () {
    Future<AppState> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final plans = MockAiUsageSource.designPlans(DateTime.now());
      final w = plans['claude']!.windows;
      plans['claude'] = AgentPlanUsage(providerId: 'claude', plan: 'Claude Max 5x', windows: [
        UsageWindow(label: '5-hour session', short: '5h', left: 0, resets: DateTime.now().add(const Duration(hours: 1, minutes: 30))),
        w.last,
      ]);
      final state = AppState(demoWallpaper: true, usage: MockAiUsageSource(plans: plans));
      state.setSetting('agents.mode', 'library');
      await tester.pumpWidget(KumoApp(state: state));
      state.view = KumoView.agents;
      await tester.pump();
      await tester.pump();
      return state;
    }

    testWidgets('Run starts on a CLI with plan left, and a run that ran out goes on there', (tester) async {
      final state = await pump(tester);
      await tester.tap(find.text('go-pr-reviewer').first);
      await tester.pump();
      await tester.ensureVisible(find.text('New run'));
      await tester.pump();
      await tester.tap(find.text('New run'));
      await tester.pump();
      final pick = tester.widget<KSegmented<AgentCli>>(find.byType(KSegmented<AgentCli>));
      expect(pick.value, AgentCli.codex, reason: 'Claude Code is out');
      expect(pick.items.first.$3, 'out');

      // Picked anyway: said, with a way out.
      await tester.tap(find.descendant(of: find.byType(KSegmented<AgentCli>), matching: find.text('Claude Code')));
      await tester.pump();
      expect(find.textContaining('Claude Code’s 5-hour session is used up: resets in 1 h'), findsOneWidget);
      expect(find.text('Use Codex'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('field-First message')), 'Review #519');
      await tester.pump();
      await tester.ensureVisible(find.text('Start in its own terminal'));
      await tester.pump();
      await tester.tap(find.text('Start in its own terminal'));
      await tester.pump();
      await tester.pump();
      final agent = state.agentDefs.agents.firstWhere((a) => a.name == 'go-pr-reviewer');
      final first = state.agentDefs.runsOf(agent).first;
      expect(first.providerId, 'claude');

      // Its terminal offers to go on with Codex, in the same folder.
      expect(find.text('Go on with Codex'), findsOneWidget);
      await tester.tap(find.text('Go on with Codex'));
      await tester.pump();
      await tester.pump();
      final next = state.agentDefs.runsOf(agent).first;
      expect((next.providerId, next.worktreePath), ('codex', first.worktreePath));
      expect(next.prompt, startsWith('Review #519\n\nAnother AI (Claude Code) started this here'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a test run that failed at the limit tries the same task elsewhere', (tester) async {
      final state = await pump(tester);
      final defs = state.agentDefs as MockAgentDefs;
      final agent = defs.agents.firstWhere((a) => a.name == 'go-pr-reviewer');
      defs.playRuns(agent).insert(
            0,
            PlayRun(id: 'p-limit', agent: agent.name, task: 'Review #600', draft: false, startedAt: DateTime.now(), cli: 'claude')
                .copyWith(state: PlayState.failed, error: 'Claude AI usage limit reached|1790387720'),
          );
      await tester.tap(find.text('go-pr-reviewer').first);
      await tester.pump();
      await tester.tap(find.text('Playground'));
      await tester.pump();
      expect(find.textContaining('The agent is one file: try the same task on Codex CLI.'), findsOneWidget);
      await tester.ensureVisible(find.text('Try it on Codex'));
      await tester.pump();
      await tester.tap(find.text('Try it on Codex'));
      await tester.pump();
      await tester.pump();
      final tried = defs.playRuns(agent).first;
      expect((tried.cli, tried.task, tried.draft), ('codex', 'Review #600', false));
      defs.dispose();
      expect(tester.takeException(), isNull);
    });
  });
}
