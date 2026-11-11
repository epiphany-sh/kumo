import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/data/agent_defs.dart';
import 'package:kumo_ui/data/agent_defs_source.dart';
import 'package:kumo_ui/data/agent_playground.dart';
import 'package:kumo_ui/data/agents_source.dart';
import 'package:kumo_ui/engine/engine_agent_defs.dart';
import 'package:kumo_ui/engine/generated/kumo/v1/kumo.pb.dart' as pb;

/// Your agents on other CLIs: what the run form says changes, the commands it
/// shows, and Codex's output read as a timeline. The fixtures are real
/// `codex exec --json` output (Codex CLI 0.157.0), paths replaced.
void main() {
  const reviewer = AgentDef(name: 'rev', description: 'Reviews. Use it when asked.', instructions: 'You review.', model: 'sonnet');

  List<String> fixture(String name) => File('test/fixtures/$name.jsonl').readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();

  group('what changes on Codex', () {
    String texts(AgentDef a) => agentCliNotes(a, AgentCli.codex).map((n) => n.text).join('\n');

    test('nothing for Claude Code: the file is its own', () {
      expect(agentCliNotes(reviewer.copyWith(maxTurns: () => 8, mcpServers: ['jira']), AgentCli.claude), isEmpty);
    });

    test('a reader is read-only and never asks; a model tier is effort', () {
      final t = texts(reviewer);
      expect(codexSandbox(reviewer), 'read-only');
      expect(t, contains('Read-only'));
      expect(t, contains('never asks'));
      expect(t, contains('medium effort'));
    });

    test('it gets no more than its file: edits stay in the folder, Bash asks, plan mode reads', () {
      final writer = reviewer.copyWith(tools: [...readOnlyTools, 'Edit', 'Write']);
      expect(codexSandbox(writer), 'workspace-write');
      expect(texts(writer), allOf(contains('not in temporary ones'), contains('never asks')));
      final runner = writer.copyWith(tools: [...writer.tools, 'Bash']);
      expect(texts(runner), allOf(isNot(contains('temporary')), contains('asks you before going beyond')));
      expect(codexSandbox(runner.copyWith(approvals: AgentApprovals.plan)), 'read-only');
      expect(texts(runner.copyWith(approvals: AgentApprovals.dontAsk)), contains('never asks'));
      expect(texts(runner.copyWith(approvals: AgentApprovals.bypass)), contains('keeps the sandbox'));
    });

    test('what doesn’t carry over is said, never dropped quietly', () {
      final busy = reviewer.copyWith(maxTurns: () => 8, maxCostUsd: () => 1, mcpServers: ['jira'], skills: ['sql'], memory: AgentMemory.project, tools: [...readOnlyTools, 'WebFetch']);
      final notes = agentCliNotes(busy, AgentCli.codex);
      final warned = notes.where((n) => n.level == CheckLevel.warn).map((n) => n.text).join('\n');
      expect(warned, allOf(contains('jira'), contains('sql'), contains('WebFetch')));
      expect(notes.map((n) => n.text).join('\n'), allOf(contains('8 turns'), contains('cost limit'), contains('starts fresh')));
    });
  });

  test('the commands it shows name the CLI and never a way around its limits', () {
    final run = agentCommand(reviewer, prompt: 'Review #521', contextDir: '~/.kumo/runs/rev-1', cli: AgentCli.codex);
    expect(run, startsWith('codex -s read-only -c developer_instructions='));
    expect(run, endsWith('-- "Review #521"'));
    expect(run, isNot(contains('--add-dir')), reason: 'it would let Codex write there');
    expect(playgroundCommand(reviewer, task: 'go', cli: AgentCli.codex), startsWith('codex exec --json -s read-only'));
    expect(agentCommand(reviewer), startsWith('claude --agents'), reason: 'Claude Code as before');
  });

  group('a Codex test run', () {
    PlayRun fresh() => PlayRun(id: 'p', agent: 'rev', task: 'Review calc.py', draft: true, startedAt: DateTime(2026), cli: 'codex');

    test('a real run folds into steps, commands with their output, and an answer', () {
      var run = fresh();
      for (final (i, line) in fixture('codex_review').indexed) {
        run = foldPlayLine(run, line, at: Duration(seconds: i));
      }
      expect(run.state, PlayState.done);
      expect(run.steps.map((s) => s.kind), [PlayStepKind.thinking, PlayStepKind.tool, PlayStepKind.tool, PlayStepKind.tool, PlayStepKind.answer]);
      final first = run.steps[1];
      expect(first.text, 'Shell');
      expect(jsonDecode(first.params)['command'], contains('calc.py'));
      expect(first.result, contains('def average'));
      expect(run.answer!.text, startsWith('ROLE-OK.'));
      expect((run.meters.tokensIn, run.meters.tokensOut, run.meters.costUsd), (56624, 518, null), reason: 'Codex reports tokens, not cost');
    });

    test('a failed run says why in plain words', () {
      var run = fresh();
      for (final line in fixture('codex_failed')) {
        run = foldPlayLine(run, line);
      }
      expect(run.state, PlayState.failed);
      expect(run.error, 'The \'sonnet\' model is not supported when using Codex with a ChatGPT account.');
      expect(run.steps.first.text, startsWith('Codex warned:'), reason: 'a warning isn’t the failure');
    });

    test('Kumo’s own failure line, and an exit without one, read as failures', () {
      final failed = foldPlayLine(fresh(), jsonEncode({'type': 'turn.failed', 'error': {'message': 'Error: not signed in'}}));
      expect((failed.state, failed.error), (PlayState.failed, 'Error: not signed in'));
      expect(playEnded(fresh(), 1).error, 'Codex CLI exited with code 1.');
    });

    test('a command that failed shows its exit code; lines it can’t read are skipped', () {
      var run = foldPlayLine(fresh(), jsonEncode({'type': 'item.started', 'item': {'id': 'i1', 'type': 'command_execution', 'command': 'touch x', 'aggregated_output': '', 'exit_code': null, 'status': 'in_progress'}}));
      run = foldPlayLine(run, jsonEncode({'type': 'item.completed', 'item': {'id': 'i1', 'type': 'command_execution', 'command': 'touch x', 'aggregated_output': 'touch: x: Operation not permitted', 'exit_code': 1, 'status': 'failed'}}));
      expect(run.steps.single.result, 'Error: exit 1. touch: x: Operation not permitted');
      expect(foldPlayLine(run, 'not json'), same(run));
      expect(foldPlayLine(run, jsonEncode({'type': 'item.completed', 'item': {'type': 'todo_list'}})), same(run));
    });

    test('a kept run reads with its CLI; one kept before there were others is Claude Code', () {
      final lines = fixture('codex_review');
      final record = pb.PlayRecord(
        playId: 'p1',
        providerId: 'codex',
        task: 'Review calc.py',
        events: [for (final (i, l) in lines.indexed) pb.PlayEvent(playId: 'p1', line: l, atMs: Int64(i)), pb.PlayEvent(playId: 'p1', exited: 0, atMs: Int64(99))],
      );
      final run = playRunFrom(record, agent: 'rev');
      expect((run.cli, run.state, run.answer?.text.startsWith('ROLE-OK.')), ('codex', PlayState.done, true));
      expect(playRunFrom(pb.PlayRecord(playId: 'p2'), agent: 'rev').cli, 'claude');
    });

    test('the mock plays it on Codex too, step by step', () async {
      final defs = MockAgentDefs(step: Duration.zero);
      final started = await defs.play(reviewer, task: 'Review #521', worktreePath: '/wt', cli: AgentCli.codex);
      expect(started!.cli, 'codex');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final done = defs.playRuns(reviewer).first;
      expect(done.state, PlayState.done);
      expect(done.answer!.text, contains('Two reuse opportunities'));
      final run = await defs.run(reviewer, const AgentWhere.scratch(), cli: AgentCli.codex);
      expect((run!.providerId, run.short), ('codex', 'CX'));
      defs.dispose();
    });
  });

  group('what changes on Copilot', () {
    String texts(AgentDef a) => agentCliNotes(a, AgentCli.copilot).map((n) => n.text).join('\n');

    test('a reader gets read and search, and Auto is pointed out', () {
      expect(copilotTools(reviewer), ['read', 'search']);
      final t = texts(reviewer);
      expect(t, contains('It only reads'));
      expect(t, contains('pick one with /model'));
      expect(t, contains('trust it'));
      expect(texts(reviewer.copyWith(model: 'gpt-6-sol')), contains('Model: gpt-6-sol.'));
    });

    test('it gets no more than its file: plan mode reads, only acceptEdits skips asking', () {
      final writer = reviewer.copyWith(tools: [...readOnlyTools, 'Edit', 'Bash', 'WebFetch']);
      expect(copilotTools(writer), ['read', 'search', 'edit', 'execute', 'web']);
      expect(texts(writer), contains('asks you before each change'));
      expect(copilotTools(writer.copyWith(approvals: AgentApprovals.plan)), ['read', 'search', 'web']);
      expect(texts(writer.copyWith(approvals: AgentApprovals.acceptEdits)), contains('Edits go without asking'));
      expect(texts(writer.copyWith(approvals: AgentApprovals.bypass)), contains('Copilot doesn’t, it asks'));
      expect(copilotTools(const AgentDef(name: 'all', description: 'd', instructions: 'x', everyTool: true)), ['read', 'search', 'edit', 'execute', 'web', 'todo'], reason: 'no tools line: every built-in tool, never a connector');
    });

    test('what doesn’t carry over is said, never dropped quietly', () {
      final busy = reviewer.copyWith(maxTurns: () => 8, maxCostUsd: () => 1, mcpServers: ['jira'], skills: ['sql'], memory: AgentMemory.project, tools: [...readOnlyTools, 'Task']);
      final notes = agentCliNotes(busy, AgentCli.copilot);
      final warned = notes.where((n) => n.level == CheckLevel.warn).map((n) => n.text).join('\n');
      expect(warned, allOf(contains('jira'), contains('sql'), contains('Task')));
      expect(notes.map((n) => n.text).join('\n'), allOf(contains('8 turns'), contains('cost limit'), contains('starts fresh')));
    });

    test('Claude Code’s own tools are said once, not warned about', () {
      final notes = agentCliNotes(reviewer.copyWith(tools: defaultAgentTools), AgentCli.copilot);
      expect(notes.where((n) => n.level == CheckLevel.warn), isEmpty);
      expect(notes.map((n) => n.text), contains('Artifact, Skill, ToolSearch, AskUserQuestion are Claude Code’s own: Copilot runs without them.'));
    });

    test('its commands name Kumo’s copy of the agent', () {
      expect(agentCommand(reviewer, prompt: 'Review #521', contextDir: '~/.kumo/runs/rev-1', cli: AgentCli.copilot), 'copilot --agent rev-… --add-dir <its copy> --add-dir ~/.kumo/runs/rev-1 -i "Review #521"');
      expect(playgroundCommand(reviewer, task: 'go', cli: AgentCli.copilot), 'copilot -p "go" --agent rev-… --output-format json');
    });
  });

  group('a Copilot test run', () {
    PlayRun fresh() => PlayRun(id: 'p', agent: 'rev', task: 'Review calc.py', draft: true, startedAt: DateTime(2026), cli: 'copilot');

    test('a real run folds into steps, tools with their output, and an answer', () {
      var run = fresh();
      for (final (i, line) in fixture('copilot_review').indexed) {
        run = foldPlayLine(run, line, at: Duration(seconds: i));
      }
      expect(run.state, PlayState.done);
      expect(run.steps.map((s) => s.kind), [PlayStepKind.tool, PlayStepKind.tool, PlayStepKind.thinking, PlayStepKind.answer]);
      expect((run.steps[0].text, run.steps[1].text), ('Glob', 'Read'));
      expect(jsonDecode(run.steps[1].params)['path'], '/work/app/calc.py');
      expect(run.steps[1].result, contains('def average'));
      expect(run.steps[2].text, startsWith('**Reviewing possible bugs**'), reason: 'its reasoning, once, before what it said');
      expect(run.answer!.text, startsWith('ROLE-OK'));
      expect((run.meters.turns, run.meters.tokensIn > 0, run.meters.tokensOut > 0, run.meters.costUsd), (3, true, true, null));
    });

    test('Kumo’s failure line, a denied tool, and lines it can’t read', () {
      final failed = foldPlayLine(fresh(), jsonEncode({'type': 'result', 'exitCode': 1, 'error': {'message': 'Error: Model "x" from --model flag is not available.'}}));
      expect((failed.state, failed.error), (PlayState.failed, 'Error: Model "x" from --model flag is not available.'));
      expect(foldPlayLine(fresh(), jsonEncode({'type': 'result', 'exitCode': 2})).error, 'GitHub Copilot CLI exited with code 2.');
      expect(playEnded(fresh(), 1).error, 'Copilot CLI exited with code 1.');
      var run = foldPlayLine(fresh(), jsonEncode({'type': 'tool.execution_start', 'data': {'toolCallId': 'c', 'toolName': 'create', 'arguments': {'path': 'x'}}}));
      run = foldPlayLine(run, jsonEncode({'type': 'tool.execution_complete', 'data': {'toolCallId': 'c', 'success': false, 'error': {'message': 'Permission denied because no interactive user response was available.'}}}));
      expect((run.steps.single.text, run.steps.single.result), ('Edit', 'Error: Permission denied because no interactive user response was available.'));
      expect(foldPlayLine(run, 'not json'), same(run));
      expect(foldPlayLine(run, jsonEncode({'type': 'assistant.message_delta', 'data': {'deltaContent': 'x'}})), same(run));
    });

    test('the mock plays it on Copilot too', () async {
      final defs = MockAgentDefs(step: Duration.zero);
      final started = await defs.play(reviewer, task: 'Review #521', worktreePath: '/wt', cli: AgentCli.copilot);
      expect(started!.cli, 'copilot');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final done = defs.playRuns(reviewer).first;
      expect(done.state, PlayState.done);
      expect(done.answer!.text, contains('Two reuse opportunities'));
      final run = await defs.run(reviewer, const AgentWhere.scratch(), cli: AgentCli.copilot);
      expect((run!.providerId, run.short), ('copilot', 'GH'));
      defs.dispose();
    });
  });

  test('the CLIs your agents run on are the ones Kumo can translate them for', () {
    expect([for (final c in AgentCli.values) c.id], ['claude', 'codex', 'copilot']);
    expect(AgentCli.of('gemini'), isNull);
    expect(AgentCli.of('Codex'), isNull, reason: 'matched exactly, as the engine does');
    expect(AgentCli.of('github-copilot'), isNull);
    expect(const AgentProviderInfo(id: 'codex', name: 'Codex', short: 'CX', program: 'codex').id, AgentCli.codex.id);
  });
}
