import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/agent_defs.dart';
import 'package:kumo_ui/data/agent_defs_source.dart';
import 'package:kumo_ui/data/agent_playground.dart';
import 'package:kumo_ui/data/agents_source.dart';
import 'package:kumo_ui/data/models.dart' show AgentStatus;
import 'package:kumo_ui/views/agents_library.dart' show lineDiff;
import 'package:kumo_ui/views/agents_screen.dart';
import 'package:kumo_ui/widgets/controls.dart' show KSegmented;

Future<AppState> _pumpAgents(WidgetTester tester, {AgentsMode mode = AgentsMode.library}) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(demoWallpaper: true);
  state.setSetting('agents.mode', mode == AgentsMode.library ? 'library' : 'sessions');
  await tester.pumpWidget(KumoApp(state: state));
  state.view = KumoView.agents;
  await tester.pump();
  await tester.pump();
  return state;
}

const _file = '''---
name: security-reviewer
description: Reviews changes for security issues. Use it before merging anything that touches auth or payments.
tools: Read, Grep, Glob, Bash
model: opus
color: red
hooks: { PreToolUse: [] }
---

You are a security reviewer.
Don’t change any file.''';

void main() {
  group('agent files', () {
    test('a file reads into an agent and writes back the same', () {
      final read = readAgentFile(_file);
      expect(read.usable, isTrue);
      final a = read.agent!;
      expect(a.name, 'security-reviewer');
      expect(a.tools, ['Read', 'Grep', 'Glob', 'Bash']);
      expect(a.model, 'opus');
      expect(a.color, 'red');
      expect(a.extra, [('hooks', '{ PreToolUse: [] }')], reason: 'fields Kumo doesn’t edit are kept');
      expect(read.checks.map((c) => c.level), containsAll([CheckLevel.warn, CheckLevel.info]));
      final again = readAgentFile(a.toMarkdown()).agent!;
      expect(again, a, reason: 'a round trip changes nothing');
      expect(a.toMarkdown(), contains('hooks: { PreToolUse: [] }'));
    });

    test('knowledge and the report’s shape are sections of the instructions', () {
      const a = AgentDef(
        name: 'r',
        description: 'd',
        instructions: 'Do it.',
        knowledge: ['docs/conventions.md'],
        output: AgentOutput.json,
        outputTemplate: '[{ "file": "" }]',
        maxTurns: null,
        isolation: true,
        approvals: AgentApprovals.plan,
        memory: AgentMemory.project,
        mcpServers: ['jira'],
      );
      final md = a.toMarkdown();
      expect(md, contains('## Read first\n- docs/conventions.md'));
      expect(md, contains('## Report like this\n```json\n[{ "file": "" }]\n```'));
      expect(md, contains('tools: Read, Grep, Glob, mcp__jira'));
      expect(md, contains('permissionMode: plan'));
      expect(md, contains('isolation: worktree'));
      expect(md, contains('memory: project'));
      expect(md, isNot(contains('maxTurns')));
      final back = readAgentFile(md).agent!;
      expect(back.instructions, 'Do it.');
      expect(back.knowledge, ['docs/conventions.md']);
      expect(back.output, AgentOutput.json);
      expect(back.outputTemplate, '[{ "file": "" }]');
      expect(back.mcpServers, ['jira']);
      expect(back.maxTurns, isNull);
    });

    test('what a file lacks, and names', () {
      expect(readAgentFile('hello').checks.single.level, CheckLevel.error, reason: 'no frontmatter');
      final noTools = readAgentFile('---\nname: lint-fixer\ndescription: Fixes lint. Use it before a PR.\n---\nDo it.');
      expect(noTools.agent!.tools, readOnlyTools, reason: 'no tools line means every tool: it comes in read-only');
      expect(noTools.checks.first.text, startsWith('No tools line'));
      final named = readAgentFile('---\nname: Go PR Reviewer\ndescription: x\ntools:\n  - Read\n  - Grep\n---\nBody', taken: {'go-pr-reviewer'});
      expect(named.agent!.name, 'go-pr-reviewer-2');
      expect(named.agent!.tools, ['Read', 'Grep'], reason: 'YAML lists too');
      expect(readAgentFile('---\nname: x\ntools: Read\n---\nBody').usable, isFalse, reason: 'Claude Code needs a description');
      expect(agentSlug(' My Agent! '), 'my-agent');
      expect(isAgentName('go-pr-reviewer'), isTrue);
      expect(isAgentName('Go'), isFalse);
      expect(isAgentName('a--b'), isFalse);
    });

    test('checks before saving', () {
      const ok = AgentDef(name: 'go-pr-reviewer', description: 'Reviews Go pull requests for code that could be reused. Use it when a PR is ready.', instructions: 'Do it.');
      expect(agentSavable(ok), isTrue);
      expect(agentNameCheck(ok, taken: {'go-pr-reviewer'}).level, CheckLevel.error);
      expect(agentDescriptionCheck(ok.copyWith(description: 'A helpful assistant')).level, CheckLevel.warn);
      expect(agentDescriptionCheck(ok.copyWith(description: 'Reviews Go pull requests for code that could have been reused.')).text, startsWith('Add when'));
      expect(agentSavable(ok.copyWith(tools: const [])), isFalse);
      final risky = ok.copyWith(tools: const ['Read', 'Bash'], approvals: AgentApprovals.dontAsk, maxTurns: () => null, maxMinutes: () => null);
      expect(agentChecks(risky).map((c) => c.text), contains('It changes things without asking and has no limits.'));
      final triggered = ok.copyWith(tools: const ['Edit'], triggers: const [AgentTrigger.pullRequest]);
      expect(agentChecks(triggered).last.level, CheckLevel.warn);
      expect(agentToolsWarning(ok), isNull);
      expect(agentToolsWarning(ok.copyWith(tools: const ['Edit', 'Bash'])), startsWith('It can change files and run commands.'));
      expect(agentToolsKind(const ['Read', 'WebFetch']).$2, 'read + web');
    });

    test('commands: by name where it’s found, inline elsewhere', () {
      const a = AgentDef(name: 'go-pr-reviewer', scope: AgentScope.project, repo: 'price-admin');
      expect(agentCommand(a, contextDir: '~/.kumo/runs/x', prompt: 'Review #521'), 'claude --agents \'{"go-pr-reviewer": …}\' --agent go-pr-reviewer --add-dir ~/.kumo/runs/x -- "Review #521"');
      final inline = jsonDecode(agentInlineJson(a.copyWith(instructions: 'Hi.'))) as Map;
      expect((inline['go-pr-reviewer'] as Map)['prompt'], 'Hi.');
      expect(playgroundCommand(a), contains('--output-format stream-json --verbose --max-turns 25'));
    });

    test('links', () {
      final pr = parseRepoLink('https://github.com/workspace-1/price-admin/pull/521')!;
      expect((pr.path, pr.number, pr.ref, pr.name), ('workspace-1/price-admin', 521, '#521', 'price-admin'));
      final mr = parseRepoLink('https://gitlab.example.com/pricing/price-reader-v2/-/merge_requests/231')!;
      expect((mr.path, mr.ref), ('pricing/price-reader-v2', '!231'));
      expect(parseRepoLink('https://github.com/segmentio/kafka-go')!.number, isNull);
      expect(parseRepoLink('https://github.com/o/r/tree/feat/x')!.branch, 'feat/x');
      expect(parseRepoLink('hello'), isNull);
    });

    test('templates start with safe defaults', () {
      final reviewer = agentTemplates.first.draft();
      expect(reviewer.tools, readOnlyTools);
      expect(reviewer.isolation, isFalse);
      final tests = agentTemplates.firstWhere((t) => t.id == 'test-writer').draft();
      expect(tests.isolation, isTrue, reason: 'it changes files: its own worktree');
      expect(tests.maxTurns, 25);
      expect(tests.maxMinutes, isNull, reason: 'a clock would end a conversation that’s only waiting for you');
    });
  });

  group('playground', () {
    test('stream-json folds into steps and counters', () {
      var run = PlayRun(id: 'p', agent: 'a', task: 't', draft: true, startedAt: DateTime(2026));
      for (final line in [
        jsonEncode({'type': 'system', 'subtype': 'init'}),
        jsonEncode({'type': 'assistant', 'message': {'content': [{'type': 'text', 'text': 'Reading the diff.'}]}}),
        jsonEncode({'type': 'assistant', 'message': {'content': [{'type': 'tool_use', 'id': 't1', 'name': 'Read', 'input': {'file_path': 'a.go'}}]}}),
        jsonEncode({'type': 'user', 'message': {'content': [{'type': 'tool_result', 'tool_use_id': 't1', 'content': [{'type': 'text', 'text': 'Read 40 lines'}]}]}}),
        'not json',
        jsonEncode({'type': 'assistant', 'message': {'content': [{'type': 'text', 'text': 'Nothing to reuse.'}]}}),
        jsonEncode({'type': 'result', 'subtype': 'success', 'num_turns': 3, 'duration_ms': 4000, 'total_cost_usd': 0.02, 'result': 'Nothing to reuse.', 'usage': {'input_tokens': 1000, 'output_tokens': 200}}),
      ]) {
        run = foldStreamJson(run, line, at: Duration.zero);
      }
      expect(run.state, PlayState.done);
      expect(run.steps.map((s) => s.kind), [PlayStepKind.thinking, PlayStepKind.tool, PlayStepKind.answer], reason: 'the last thing said is the answer, once');
      expect(run.steps[1].params, '{"file_path":"a.go"}');
      expect(run.steps[1].result, 'Read 40 lines');
      expect(run.meters.turns, 3);
      expect(run.meters.costUsd, 0.02);
      expect(run.meters.tokensIn, 1000);
      expect(describeStep(run.steps[1]), 'Read({"file_path":"a.go"}) → Read 40 lines');

      final capped = foldStreamJson(PlayRun(id: 'q', agent: 'a', task: 't', draft: true, startedAt: DateTime(2026)), jsonEncode({'type': 'result', 'subtype': 'error_max_turns'}));
      expect(capped.state, PlayState.failed);
      expect(capped.error, 'It reached its turn limit.');
    });

    test('the suggested fix shows as lines removed and added', () {
      final d = lineDiff('a\nb\nc\nd\ne', 'a\nb\nc\nX\nd\ne');
      expect(d, [('c', 0), ('X', 1), ('d', 0)]);
    });

    test('the mock plays a run step by step, and improves the instructions', () async {
      final defs = MockAgentDefs(step: const Duration(milliseconds: 1));
      final reviewer = defs.agents.firstWhere((a) => a.name == 'go-pr-reviewer');
      expect(defs.playRuns(reviewer).length, 3, reason: 'canned history');
      final run = await defs.play(reviewer, task: 'Review #521', worktreePath: '/wt');
      expect(run!.state, PlayState.running);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(defs.playRuns(reviewer).first.state, PlayState.done);
      expect(defs.playRuns(reviewer).first.answer?.text, startsWith('Two reuse opportunities'));
      final better = await defs.improve(reviewer, step: 'Glob(**/*_test.go)');
      expect(better, contains('4. Only open tests of the packages the PR touches'));
      defs.dispose();
    });
  });

  group('Agents view', () {
    testWidgets('Your agents: list, run form, its terminal', (tester) async {
      final state = await _pumpAgents(tester);
      expect(find.text('Your agents'), findsWidgets);
      expect(find.text('go-pr-reviewer'), findsWidgets);
      expect(find.text('PRICE-ADMIN'), findsOneWidget, reason: 'project agents under their repo');
      await tester.tap(find.text('go-pr-reviewer').first);
      await tester.pump();
      expect(find.text('1 · Where should it work?'), findsOneWidget);
      expect(find.textContaining('--agent go-pr-reviewer'), findsOneWidget);
      // Its running review: a terminal right here.
      await tester.tap(find.text('PR #521 · Bulk discounts').first);
      await tester.pump();
      expect(find.text('Terminal view'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
      await tester.ensureVisible(find.text('New run'));
      await tester.pump();
      await tester.tap(find.text('New run'));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('field-First message')), 'Review #519');
      await tester.pump();
      await tester.tap(find.text('Start in its own terminal'));
      await tester.pump();
      await tester.pump();
      expect(state.agentDefs.runsOf(state.agentDefs.agents.firstWhere((a) => a.name == 'go-pr-reviewer')).first.prompt, 'Review #519');
      expect(find.text('Terminal view'), findsOneWidget, reason: 'the new run opens in its terminal');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Run with Codex: what changes shows before it starts, and it starts on Codex', (tester) async {
      final state = await _pumpAgents(tester);
      await tester.tap(find.text('go-pr-reviewer').first);
      await tester.pump();
      await tester.ensureVisible(find.text('New run'));
      await tester.pump();
      await tester.tap(find.text('New run'));
      await tester.pump();
      expect(find.text('Runs with'), findsOneWidget);
      final pick = tester.widget<KSegmented<AgentCli>>(find.byType(KSegmented<AgentCli>));
      expect([for (final i in pick.items) i.$2], ['Claude Code', 'Codex', 'Copilot'], reason: 'only connected CLIs it can run on: not Gemini');
      expect(find.textContaining('On Codex CLI'), findsNothing, reason: 'Claude Code first: nothing changes');
      await tester.tap(find.descendant(of: find.byType(KSegmented<AgentCli>), matching: find.text('Codex')));
      await tester.pump();
      expect(find.textContaining('Its file is Claude Code’s. On Codex CLI'), findsOneWidget);
      expect(find.textContaining('Read-only: it reads and runs commands'), findsOneWidget);
      expect(find.textContaining('codex -s read-only'), findsOneWidget);
      await tester.ensureVisible(find.text('Start in its own terminal'));
      await tester.pump();
      await tester.tap(find.text('Start in its own terminal'));
      await tester.pump();
      await tester.pump();
      final run = state.agentDefs.runsOf(state.agentDefs.agents.firstWhere((a) => a.name == 'go-pr-reviewer')).first;
      expect(run.providerId, 'codex');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Edit: tools warn, checks gate Save, Save writes it', (tester) async {
      final state = await _pumpAgents(tester);
      await tester.tap(find.text('go-pr-reviewer').first);
      await tester.pump();
      await tester.tap(find.text('Edit').first);
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);
      await tester.ensureVisible(find.text('Bash'));
      await tester.pump();
      await tester.tap(find.text('Bash'));
      await tester.pump();
      expect(find.textContaining('It can run any command.'), findsOneWidget);
      expect(find.textContaining('tools: Read, Grep, Glob, Bash'), findsOneWidget, reason: 'the file preview follows');
      await tester.enterText(find.byKey(const ValueKey('field-Name')), 'test-writer');
      await tester.pump();
      expect(find.text('test-writer is taken in price-admin.'), findsOneWidget, reason: 'under the field');
      await tester.enterText(find.byKey(const ValueKey('field-Name')), 'go-reuse-reviewer');
      await tester.pump();
      await tester.ensureVisible(find.text('Save'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      state.dismissUndo();
      final saved = state.agentDefs.agents.where((a) => a.name == 'go-reuse-reviewer').single;
      expect(saved.tools, contains('Bash'));
      expect(state.agentDefs.agents.where((a) => a.name == 'go-pr-reviewer'), isEmpty, reason: 'renamed, not copied');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Create: a template opens unsaved in Edit; import reads a pasted file', (tester) async {
      final state = await _pumpAgents(tester);
      await tester.tap(find.text('Create agent').first);
      await tester.pumpAndSettle();
      expect(find.text('Create an agent'), findsOneWidget);
      await tester.tap(find.text('Test writer'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('From the Test writer template'), findsOneWidget);
      expect(find.text('Save agent'), findsOneWidget);
      expect(find.text('not saved'), findsWidgets);

      await tester.tap(find.text('Create agent').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import a .md file…'));
      await tester.pump();
      expect(find.text('Import an agent'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, _file);
      await tester.pump();
      expect(find.textContaining('Kept as written'), findsOneWidget);
      await tester.tap(find.text('Open in Edit'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Imported from what you pasted'), findsOneWidget);
      expect(state.agentDefs.agents.where((a) => a.name == 'security-reviewer'), isEmpty, reason: 'nothing saved until you save');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Playground: run, flag a step, apply the fix to the draft', (tester) async {
      await _pumpAgents(tester);
      await tester.tap(find.text('go-pr-reviewer').first);
      await tester.pump();
      await tester.tap(find.text('Playground'));
      await tester.pump();
      expect(find.text('Its answer'), findsOneWidget, reason: 'the last test run');
      await tester.ensureVisible(find.text('Went wrong here').at(4));
      await tester.pump();
      await tester.tap(find.text('Went wrong here').at(4));
      await tester.pump();
      await tester.pump();
      expect(find.text('Claude suggests:'), findsOneWidget);
      await tester.ensureVisible(find.text('Apply to the draft'));
      await tester.pump();
      await tester.tap(find.text('Apply to the draft'));
      await tester.pump();
      expect(find.text('Run again with the fix'), findsOneWidget);
      expect(find.text('Looks right: save it'), findsOneWidget, reason: 'the draft has changes now');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sessions: Terminal opens the session’s terminal inside Agents', (tester) async {
      final state = await _pumpAgents(tester, mode: AgentsMode.sessions);
      expect(state.view, KumoView.agents);
      await tester.tap(find.byTooltip('See its whole output here, and type into it').at(1));
      await tester.pump();
      expect(state.view, KumoView.agents, reason: 'no jump to the Terminal view');
      expect(find.text('Approve once'), findsOneWidget, reason: 'Codex’s approval, next to its terminal');
      expect(find.text('Terminal view'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to the cards (Esc)'));
      await tester.pump();
      expect(find.text('Terminal view'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  test('a message to an agent waiting on an approval waits too', () async {
    final agents = _Waiting();
    final state = AppState(agents: agents);
    const item = AgentContextItem(kind: AgentContextKind.code, title: 'x');
    expect(await state.sendToAgent('w', item, 'hello'), isTrue);
    expect(agents.sent, isEmpty, reason: 'typing now would answer its question');
    expect(state.queuedFor('w'), 1);
    agents.answer();
    expect(agents.sent, ['hello']);
    expect(state.queuedFor('w'), 0);
    state.dispose();
  });

  test('a whole agent file pasted in the instructions can go to its fields', () {
    const pasted = '---\nname: finder\ndescription: Finds duplicates. Use it when reviewing a PR.\ntools: Read, Grep\nmodel: sonnet\n---\n\nYou find duplicates.';
    final a = agentTemplates.firstWhere((t) => t.id == 'doc-writer').draft().copyWith(name: 'x', maxMinutes: () => 7, instructions: pasted);
    expect(agentChecks(a).where((c) => c.level == CheckLevel.warn && c.text.contains('frontmatter')), hasLength(1));
    final read = agentFromPastedFile(a)!;
    expect((read.name, read.description, read.model, read.instructions), ('finder', 'Finds duplicates. Use it when reviewing a PR.', 'sonnet', 'You find duplicates.'));
    expect(read.tools, ['Read', 'Grep']);
    expect(read.maxMinutes, 7, reason: 'what only Kumo keeps stays');
    expect(agentFromPastedFile(read), isNull);
    expect(agentFromPastedFile(a.copyWith(instructions: 'You find duplicates.\n---\nmore')), isNull);
  });

  test('a file in use shows what it really grants; an import comes in safer', () {
    const file = '---\nname: wide\ndescription: d\npermissionMode: bypassPermissions\n---\n\nDo things.';
    final listed = readAgentFile(file, asWritten: true).agent!;
    expect((listed.everyTool, listed.approvals, agentWrites(listed.tools)), (true, AgentApprovals.bypass, true));
    expect(agentChecks(listed).where((c) => c.level == CheckLevel.warn).map((c) => c.text).join(), allOf(contains('bypassPermissions'), contains('no tools line')));
    expect(listed.toMarkdown(), isNot(contains('tools:')), reason: 'saving doesn’t narrow it behind your back');
    expect(listed.toMarkdown(), contains('permissionMode: bypassPermissions'));
    expect((jsonDecode(agentInlineJson(listed)) as Map)['wide'], isNot(contains('tools')));
    expect(listed.copyWith(tools: readOnlyTools).everyTool, isFalse);

    final imported = readAgentFile(file).agent!;
    expect((imported.everyTool, imported.approvals, imported.tools), (false, AgentApprovals.ask, readOnlyTools));
  });

  test('inline, an agent keeps what its file says', () {
    const file = '---\nname: full\ndescription: d\ntools: Read, Bash\nskills: a, b\nmemory: project\ndisallowedTools: Bash, Write\neffort: high\nhooks:\n  Stop:\n    - type: command\n---\n\nDo things.';
    final json = (jsonDecode(agentInlineJson(readAgentFile(file, asWritten: true).agent!)) as Map)['full'] as Map;
    expect(json['disallowedTools'], ['Bash', 'Write'], reason: 'a list, or --agents refuses the whole agent');
    expect(json['skills'], ['a', 'b']);
    expect(json['memory'], 'project');
    expect(json['effort'], 'high');
    expect(json['hooks'], {'Stop': [{'type': 'command'}]});
  });

  test('two repositories of the same name keep their agents apart', () {
    const one = AgentDef(name: 'rev', scope: AgentScope.project, repo: 'api', repoPath: '/work/api');
    final other = one.copyWith(repoPath: '/oss/api');
    expect(one.key, isNot(other.key));
  });

  test('only time working counts towards a run’s limit', () {
    final started = DateTime(2026);
    AgentRun run(AgentStatus status) => AgentRun(
          id: 'w', providerId: 'claude', providerName: 'Claude', short: 'CC', worktreePath: '/wt', terminalId: 't', title: 'x',
          status: status, startedAt: started, worked: const Duration(minutes: 2), stateSince: started.add(const Duration(minutes: 5)),
        );
    final now = started.add(const Duration(minutes: 6));
    expect(run(AgentStatus.needsYou).workedAt(now), const Duration(minutes: 2));
    expect(run(AgentStatus.running).workedAt(now), const Duration(minutes: 3));
  });

  test('a message to an agent that is only quiet goes in now', () async {
    final agents = _Waiting(asked: false);
    final state = AppState(agents: agents);
    const item = AgentContextItem(kind: AgentContextKind.code, title: 'x');
    expect(await state.sendToAgent('w', item, 'hello'), isTrue);
    expect(agents.sent, ['hello']);
    expect(state.queuedFor('w'), 0);
    state.dispose();
  });
}

class _Waiting extends MockAgentsSource {
  _Waiting({this.asked = true});
  bool asked;
  var _status = AgentStatus.needsYou;
  final sent = <String>[];

  @override
  List<AgentRun> get runs => [
        AgentRun(id: 'w', providerId: 'codex', providerName: 'Codex', short: 'CX', worktreePath: '/wt', terminalId: 't', title: 'x', status: _status, asked: asked, startedAt: DateTime(2026)),
      ];

  void answer() {
    _status = AgentStatus.running;
    asked = false;
    notifyListeners();
  }

  @override
  Future<bool> addContext(String id, AgentContextItem item, {String text = ''}) async {
    sent.add(text);
    return true;
  }
}
