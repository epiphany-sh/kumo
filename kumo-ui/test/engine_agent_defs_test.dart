import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/data/agent_defs.dart';
import 'package:kumo_ui/data/agent_playground.dart';
import 'package:kumo_ui/data/agents_source.dart';
import 'package:kumo_ui/engine/engine_agent_defs.dart';
import 'package:kumo_ui/engine/engine_agents_source.dart';
import 'package:kumo_ui/engine/generated/kumo/v1/kumo.pb.dart' as pb;

void main() {
  const reviewer = AgentDef(
    name: 'go-pr-reviewer',
    description: 'Reviews Go pull requests. Use it when a PR is ready.',
    instructions: 'You review.\n\nDon’t change any file.',
    knowledge: ['docs/conventions.md'],
    scope: AgentScope.project,
    repo: 'price-admin',
    maxMinutes: 5,
    maxCostUsd: 1.5,
    triggers: [AgentTrigger.pullRequest],
  );

  group('agent files', () {
    test('an agent goes as its file and settings and comes back the same', () {
      final file = agentDefFileTo(reviewer, repoPath: '/w/price-admin');
      expect(file.scope, pb.AgentDefScope.AGENT_DEF_SCOPE_PROJECT);
      expect((file.repoPath, file.repoName, file.name), ('/w/price-admin', 'price-admin', 'go-pr-reviewer'));
      expect(file.markdown, reviewer.toMarkdown());
      expect(file.settings.maxMinutes, 5);
      expect(file.settings.maxCostUsd, 1.5);
      expect(file.settings.triggers, [pb.AgentDefTrigger.AGENT_DEF_TRIGGER_PULL_REQUEST]);
      expect(agentDefFrom(file), reviewer.copyWith(repoPath: '/w/price-admin'), reason: 'names aren’t unique: it remembers which');
    });

    test('a personal agent has no repository; no settings mean no limits', () {
      final file = agentDefFileTo(reviewer.copyWith(scope: AgentScope.personal, maxMinutes: () => null, maxCostUsd: () => null, triggers: []));
      expect((file.scope, file.repoName, file.settings.hasMaxMinutes()), (pb.AgentDefScope.AGENT_DEF_SCOPE_PERSONAL, '', false));
      final back = agentDefFrom(file);
      expect((back.maxMinutes, back.maxCostUsd, back.triggers.length), (null, null, 0));
    });

    test('the file name wins, and a file that can’t be read still lists', () {
      final renamed = agentDefFrom(pb.AgentDefFile(name: 'reviewer', markdown: reviewer.toMarkdown()));
      expect(renamed.name, 'reviewer');
      final broken = agentDefFrom(pb.AgentDefFile(name: 'notes', markdown: 'no frontmatter'));
      expect((broken.name, broken.instructions), ('notes', 'no frontmatter'));
    });

    test('Claude’s answers come without their fence', () {
      expect(unfence('```markdown\n---\nname: x\n---\nHi\n```'), '---\nname: x\n---\nHi');
      expect(unfence('  plain  '), 'plain');
    });
  });

  group('runs', () {
    test('context kinds and ids go and come back one to one', () {
      for (final kind in AgentContextKind.values) {
        final item = AgentContextItem(kind: kind, title: 't', detail: 'd', url: 'u', id: 'src/1');
        expect(agentContextFrom(agentContextTo(item)), item);
      }
    });

    test('a session says which of your agents it runs', () {
      final run = agentRunFrom(pb.AgentSession(id: 's1', agentName: 'go-pr-reviewer', contextDir: '/d/runs/x'));
      expect(run.agent, 'go-pr-reviewer');
    });
  });

  group('test runs', () {
    pb.PlayEvent line(Object json, int at) => pb.PlayEvent(playId: 'p1', line: jsonEncode(json), atMs: Int64(at));

    test('a kept run folds its lines; the exit code ends it', () {
      final record = pb.PlayRecord(
        playId: 'p1',
        task: 'Review #521',
        draft: true,
        startedUnixMs: Int64(1000),
        events: [
          line({'type': 'assistant', 'message': {'id': 'm1', 'content': [{'type': 'tool_use', 'id': 't1', 'name': 'Read', 'input': {'file_path': 'a.go'}}]}}, 10),
          line({'type': 'result', 'subtype': 'success', 'num_turns': 1, 'result': 'Nothing to reuse.'}, 20),
          pb.PlayEvent(playId: 'p1', exited: 0, atMs: Int64(21)),
        ],
      );
      final run = playRunFrom(record, agent: 'go-pr-reviewer');
      expect((run.id, run.task, run.draft, run.state), ('p1', 'Review #521', true, PlayState.done));
      expect(run.steps.map((s) => s.kind), [PlayStepKind.tool, PlayStepKind.answer]);
    });

    test('an exit without a result fails it, unless it was stopped', () {
      final running = PlayRun(id: 'x', agent: 'a', task: 't', draft: false, startedAt: DateTime(2026));
      expect(playEnded(running, 2).state, PlayState.failed);
      expect(playEnded(running, 2).error, contains('code 2'));
      expect(playEnded(running, 137, stopped: true).state, PlayState.stopped);
      expect(playEnded(running.copyWith(state: PlayState.done), 1).state, PlayState.done);
      final unfinished = playRunFrom(pb.PlayRecord(playId: 'p2', events: [line({'type': 'system'}, 1)]), agent: 'a');
      expect(unfinished.state, PlayState.stopped);
    });
  });

  test('a stopped test run ends stopped, also when read back', () {
    final run = PlayRun(id: 'p', agent: 'a', task: 't', draft: false, startedAt: DateTime(2026));
    expect(playEnded(run, 130).state, PlayState.stopped);
    expect(playEnded(run, 124).state, PlayState.stopped);
    expect(playEnded(run, 2).state, PlayState.failed);
  });
}
