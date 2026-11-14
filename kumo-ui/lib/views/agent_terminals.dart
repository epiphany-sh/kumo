import 'package:flutter/widgets.dart';

import '../data/agents_source.dart';
import '../engine/grpc_terminal_surface.dart';
import '../engine/kumo_engine.dart';
import '../terminal/mock_terminal.dart';
import '../terminal/terminal_surface.dart';

/// The agents' terminals the Agents view shows, attached once and kept
/// while it lives: switching between sessions doesn't replay them. Closing
/// only detaches: the agent keeps running (and stays in the Terminal view).
class AgentTerminals {
  AgentTerminals(this.engine);

  /// Null in widget tests and the design: mock terminals instead.
  final KumoEngine? engine;
  final _surfaces = <String, TerminalSurface>{};

  /// The terminal of daemon session [run].
  TerminalSurface ofRun(AgentRun run) => _surfaces.putIfAbsent(run.terminalId, () {
        final e = engine;
        if (e == null || run.terminalId.startsWith('mock:')) return _mock(run.terminalId, run);
        return GrpcTerminalSurface.attach(e, terminalId: run.terminalId, program: run.providerName, title: run.agent.isEmpty ? run.title : run.agent, directory: run.worktreePath, killOnClose: false);
      });

  /// A design session's terminal, by its key.
  TerminalSurface ofMock(String key) => _surfaces.putIfAbsent('mock:$key', () => _mock('mock:$key', null));

  /// A hand-started CLI's terminal (it belongs to the Terminal view: only
  /// attached here, never closed).
  TerminalSurface ofTerminal(String terminalId, {required String title, String? directory}) => _surfaces.putIfAbsent(terminalId, () {
        final e = engine;
        if (e == null || terminalId.startsWith('mock:')) return MockSessions.shell(2);
        return GrpcTerminalSurface.attach(e, terminalId: terminalId, program: title, title: title, directory: directory, killOnClose: false);
      });

  static TerminalSurface _mock(String id, AgentRun? run) => switch (id) {
        'mock:a1' => MockSessions.agent(),
        'mock:a2' => MockAgentTerminals.codex(),
        'mock:a3' => MockAgentTerminals.gemini(),
        'mock:a4' => MockAgentTerminals.finished('Claude Code', '~/wt/repo-b/cache', 'TSK-405: warm the cache on deploy.', [
            'Pushed perf/cache-warmup and opened MR !231.',
            'Pipeline passed, 12 of 12 jobs. MR !231 is ready for review.',
          ]),
        'mock:a5' => MockAgentTerminals.finished('Claude Code', '~/notes/platform', 'Update the platform on-call runbook with the new cache warm-up.', ['Updated 2 sections of the Platform runbook in Notion.']),
        'mock:reviewer' => MockAgentTerminals.reviewer(),
        'mock:reviewer-done' => MockAgentTerminals.finished('go-pr-reviewer', '~/wt/repo-a/TSK-398', 'Review PR #517.', [
            'Nothing to reuse: the rounding helper it adds is new, and nothing else in the repo rounds installments.',
          ]),
        'mock:researcher' => MockAgentTerminals.finished('researcher', '~/.kumo/scratch/researcher-2', 'Compare Kafka clients for Go.', [
            'segmentio/kafka-go, IBM/sarama and confluent-kafka-go compared: report saved as kafka-clients.md.',
          ]),
        _ => MockAgentTerminals.started(run?.agent ?? 'agent', run?.prompt ?? ''),
      };

  /// Forgets [terminalId]'s surface (a dismissed session), once the frame
  /// that still shows it is done.
  void drop(String terminalId) {
    final s = _surfaces.remove(terminalId);
    if (s != null) WidgetsBinding.instance.addPostFrameCallback((_) => s.dispose());
  }

  void dispose() {
    for (final s in _surfaces.values) {
      s.dispose();
    }
    _surfaces.clear();
  }
}
