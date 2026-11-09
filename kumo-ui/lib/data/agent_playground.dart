/// The playground: an agent tried on a sample task, headless
/// (`claude -p … --output-format stream-json --verbose`), shown step by
/// step. The engine hands over the run's output lines; reading them is
/// here, so it can be tested as text.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

enum PlayStepKind { thinking, tool, answer, error }

/// One line of the timeline: what it thought, a tool it called (with what
/// came back), or its answer.
@immutable
class PlayStep {
  const PlayStep({required this.kind, required this.text, this.params = '', this.result = '', this.toolId = '', this.at = Duration.zero});
  final PlayStepKind kind;

  /// The thought, the tool's name, or the answer.
  final String text;

  /// The tool's input, as compact JSON.
  final String params;

  /// What the tool returned, shortened.
  final String result;
  final String toolId;

  /// Since the run started.
  final Duration at;

  PlayStep withResult(String r) => PlayStep(kind: kind, text: text, params: params, result: r, toolId: toolId, at: at);
}

/// The counters over the timeline.
@immutable
class PlayMeters {
  const PlayMeters({this.turns = 0, this.elapsed = Duration.zero, this.costUsd, this.tokensIn = 0, this.tokensOut = 0});
  final int turns;
  final Duration elapsed;

  /// Null until the run reports it.
  final double? costUsd;
  final int tokensIn;
  final int tokensOut;
}

enum PlayState { running, done, stopped, failed }

/// One test run.
@immutable
class PlayRun {
  const PlayRun({
    required this.id,
    required this.agent,
    required this.task,
    required this.draft,
    required this.startedAt,
    this.state = PlayState.running,
    this.steps = const [],
    this.meters = const PlayMeters(),
    this.error = '',
    this.lastMessage = '',
  });
  final String id;
  final String agent;
  final String task;

  /// It ran the unsaved draft (not the saved file).
  final bool draft;
  final DateTime startedAt;
  final PlayState state;
  final List<PlayStep> steps;
  final PlayMeters meters;
  final String error;

  /// The assistant message the last event belonged to: a message comes in
  /// one event per block, and is one turn.
  final String lastMessage;

  PlayStep? get answer => steps.where((s) => s.kind == PlayStepKind.answer).lastOrNull;

  PlayRun copyWith({PlayState? state, List<PlayStep>? steps, PlayMeters? meters, String? error, String? lastMessage}) => PlayRun(
        id: id,
        agent: agent,
        task: task,
        draft: draft,
        startedAt: startedAt,
        state: state ?? this.state,
        steps: steps ?? this.steps,
        meters: meters ?? this.meters,
        error: error ?? this.error,
        lastMessage: lastMessage ?? this.lastMessage,
      );
}

String _short(String s, [int max = 400]) {
  final t = s.trimRight();
  final lines = t.split('\n');
  final head = lines.length > 6 ? '${lines.take(6).join('\n')}\n… ${lines.length - 6} more lines' : t;
  return head.length > max ? '${head.substring(0, max - 1)}…' : head;
}

String _resultText(Object? content) {
  if (content is String) return content;
  if (content is List) {
    return [
      for (final c in content)
        if (c is Map && c['type'] == 'text') '${c['text']}' else if (c is Map && c['type'] == 'image') '[image]',
    ].join('\n');
  }
  return content == null ? '' : '$content';
}

/// Folds one line of Claude Code's stream-json output into [run]. Lines it
/// can't read are skipped (the stream mixes in other events).
PlayRun foldStreamJson(PlayRun run, String line, {Duration? at}) {
  final Object? e;
  try {
    e = jsonDecode(line);
  } on FormatException {
    return run;
  }
  if (e is! Map) return run;
  final when = at ?? DateTime.now().difference(run.startedAt);
  final steps = run.steps.toList();
  var meters = run.meters;
  var lastMessage = run.lastMessage;
  // A subagent's own steps (it called one): not this agent's timeline.
  if (e['parent_tool_use_id'] != null && (e['type'] == 'assistant' || e['type'] == 'user')) return run;
  switch (e['type']) {
    case 'assistant':
      final content = (e['message'] is Map ? (e['message'] as Map)['content'] : null) as Object?;
      if (content is! List) return run;
      for (final c in content) {
        if (c is! Map) continue;
        switch (c['type']) {
          case 'thinking':
            final t = '${c['thinking'] ?? ''}'.trim();
            if (t.isNotEmpty) steps.add(PlayStep(kind: PlayStepKind.thinking, text: _short(t, 600), at: when));
          case 'text':
            final t = '${c['text'] ?? ''}'.trim();
            // Said between tool calls: a thought; the last one is the answer
            // (the result event replaces it).
            if (t.isNotEmpty) steps.add(PlayStep(kind: PlayStepKind.thinking, text: _short(t, 600), at: when));
          case 'tool_use':
            steps.add(PlayStep(kind: PlayStepKind.tool, text: '${c['name'] ?? 'tool'}', params: jsonEncode(c['input'] ?? const {}), toolId: '${c['id'] ?? ''}', at: when));
        }
      }
      final id = e['message'] is Map ? '${(e['message'] as Map)['id'] ?? ''}' : '';
      final turn = id.isEmpty || id != lastMessage;
      lastMessage = id;
      meters = PlayMeters(turns: meters.turns + (turn ? 1 : 0), elapsed: when, costUsd: meters.costUsd, tokensIn: meters.tokensIn, tokensOut: meters.tokensOut);
    case 'user':
      final content = (e['message'] is Map ? (e['message'] as Map)['content'] : null) as Object?;
      if (content is! List) return run;
      for (final c in content) {
        if (c is! Map || c['type'] != 'tool_result') continue;
        final id = '${c['tool_use_id'] ?? ''}';
        final i = steps.lastIndexWhere((s) => s.kind == PlayStepKind.tool && s.toolId == id);
        final text = _short(_resultText(c['content']));
        if (i >= 0) steps[i] = steps[i].withResult(c['is_error'] == true ? 'Error: $text' : text);
      }
    case 'result':
      final ok = e['subtype'] == 'success' && e['is_error'] != true;
      final text = '${e['result'] ?? ''}'.trim();
      // The last thing it said is the answer: don't show it twice.
      if (text.isNotEmpty && steps.isNotEmpty && steps.last.kind == PlayStepKind.thinking && steps.last.text == _short(text, 600)) steps.removeLast();
      if (ok && text.isNotEmpty) steps.add(PlayStep(kind: PlayStepKind.answer, text: text, at: when));
      if (!ok) steps.add(PlayStep(kind: PlayStepKind.error, text: e['subtype'] == 'error_max_turns' ? 'It reached its turn limit.' : (text.isEmpty ? 'The run failed.' : text), at: when));
      final usage = e['usage'] is Map ? e['usage'] as Map : const {};
      meters = PlayMeters(
        turns: e['num_turns'] is int ? e['num_turns'] as int : meters.turns,
        elapsed: e['duration_ms'] is int ? Duration(milliseconds: e['duration_ms'] as int) : when,
        costUsd: e['total_cost_usd'] is num ? (e['total_cost_usd'] as num).toDouble() : meters.costUsd,
        tokensIn: (usage['input_tokens'] is int ? usage['input_tokens'] as int : 0) + (usage['cache_read_input_tokens'] is int ? usage['cache_read_input_tokens'] as int : 0),
        tokensOut: usage['output_tokens'] is int ? usage['output_tokens'] as int : 0,
      );
      return run.copyWith(state: ok ? PlayState.done : PlayState.failed, steps: steps, meters: meters, error: ok ? '' : (steps.last.text));
    default:
      return run;
  }
  return run.copyWith(steps: steps, meters: meters, lastMessage: lastMessage);
}

/// A step as Claude reads it when asked to fix the instructions.
String describeStep(PlayStep s) => switch (s.kind) {
      PlayStepKind.tool => '${s.text}(${s.params})${s.result.isEmpty ? '' : ' → ${s.result.split('\n').first}'}',
      _ => s.text,
    };
