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
    this.cli = 'claude',
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

  /// The CLI it ran on: how its lines read.
  final String cli;
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
        cli: cli,
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

/// Folds one line of [run]'s output, read the way its CLI writes it.
PlayRun foldPlayLine(PlayRun run, String line, {Duration? at}) => switch (run.cli) {
      'codex' => foldCodexJson(run, line, at: at),
      'copilot' => foldCopilotJson(run, line, at: at),
      _ => foldStreamJson(run, line, at: at),
    };

/// Folds one line of `copilot -p --output-format json` into [run]. Its
/// reasoning comes with each message (the separate `assistant.reasoning`
/// repeats it, after); what it said last is the answer. Lines it can't read,
/// and the ones that only stream text, are skipped.
PlayRun foldCopilotJson(PlayRun run, String line, {Duration? at}) {
  final Object? e;
  try {
    e = jsonDecode(line);
  } on FormatException {
    return run;
  }
  if (e is! Map) return run;
  final when = at ?? DateTime.now().difference(run.startedAt);
  final steps = run.steps.toList();
  final d = e['data'] is Map ? e['data'] as Map : const {};
  final meters = run.meters;
  String toolName(String t) => switch (t) {
        'bash' || 'powershell' => 'Shell',
        'view' => 'Read',
        'create' || 'edit' || 'str_replace' || 'apply_patch' => 'Edit',
        'glob' => 'Glob',
        'grep' || 'rg' => 'Search',
        'web_fetch' => 'Web fetch',
        _ => t,
      };
  switch (e['type']) {
    case 'assistant.turn_start':
      return run.copyWith(meters: PlayMeters(turns: meters.turns + 1, elapsed: when, tokensIn: meters.tokensIn, tokensOut: meters.tokensOut));
    case 'assistant.message':
      final thought = '${d['reasoningText'] ?? ''}'.trim();
      if (thought.isNotEmpty) steps.add(PlayStep(kind: PlayStepKind.thinking, text: _short(thought, 600), at: when));
      final said = '${d['content'] ?? ''}'.trim();
      if (said.isNotEmpty) steps.add(PlayStep(kind: PlayStepKind.thinking, text: said, params: _said, at: when));
      if (thought.isEmpty && said.isEmpty) return run;
    case 'tool.execution_start':
      final id = '${d['toolCallId'] ?? ''}';
      if (steps.any((s) => s.kind == PlayStepKind.tool && s.toolId == id)) return run;
      steps.add(PlayStep(kind: PlayStepKind.tool, text: toolName('${d['toolName'] ?? 'tool'}'), params: jsonEncode(d['arguments'] ?? const {}), toolId: id, at: when));
    case 'tool.execution_complete':
      final id = '${d['toolCallId'] ?? ''}';
      final i = steps.lastIndexWhere((s) => s.kind == PlayStepKind.tool && s.toolId == id);
      if (i < 0) return run;
      final error = d['error'] is Map ? '${(d['error'] as Map)['message'] ?? ''}' : '';
      final result = d['result'] is Map ? _short('${(d['result'] as Map)['content'] ?? ''}') : '';
      steps[i] = steps[i].withResult(d['success'] == true ? result : 'Error: ${_short(error.isEmpty ? result : error)}');
    case 'session.usage_checkpoint':
      // Running totals, over every model it used.
      final snapshot = d['accountingSnapshot'] is Map ? d['accountingSnapshot'] as Map : const {};
      final models = snapshot['modelMetrics'] is Map ? (snapshot['modelMetrics'] as Map).values : const [];
      int sum(String key) => models.fold(0, (n, m) => n + (m is Map && m['usage'] is Map && (m['usage'] as Map)[key] is int ? (m['usage'] as Map)[key] as int : 0));
      return run.copyWith(meters: PlayMeters(turns: meters.turns, elapsed: when, tokensIn: sum('inputTokens'), tokensOut: sum('outputTokens')));
    case 'result':
      final code = e['exitCode'] is int ? e['exitCode'] as int : 0;
      final error = e['error'] is Map ? '${(e['error'] as Map)['message'] ?? ''}'.trim() : '';
      final ended = PlayMeters(turns: meters.turns, elapsed: when, tokensIn: meters.tokensIn, tokensOut: meters.tokensOut);
      if (code != 0 || error.isNotEmpty) {
        final text = error.isEmpty ? 'GitHub Copilot CLI exited with code $code.' : error;
        steps.add(PlayStep(kind: PlayStepKind.error, text: text, at: when));
        return run.copyWith(state: PlayState.failed, steps: steps, error: text, meters: ended);
      }
      final i = steps.lastIndexWhere((s) => s.kind == PlayStepKind.thinking && s.params == _said);
      if (i >= 0 && i == steps.length - 1) steps[i] = PlayStep(kind: PlayStepKind.answer, text: steps[i].text, at: steps[i].at);
      return run.copyWith(state: PlayState.done, steps: steps, meters: ended);
    default:
      return run;
  }
  return run.copyWith(steps: steps, meters: PlayMeters(turns: meters.turns, elapsed: when, tokensIn: meters.tokensIn, tokensOut: meters.tokensOut));
}

/// Marks a step that is something Codex said (not its reasoning): the last
/// one becomes the answer.
const _said = 'said';

/// Folds one line of `codex exec --json` into [run]. Lines it can't read are
/// skipped.
PlayRun foldCodexJson(PlayRun run, String line, {Duration? at}) {
  final Object? e;
  try {
    e = jsonDecode(line);
  } on FormatException {
    return run;
  }
  if (e is! Map) return run;
  final when = at ?? DateTime.now().difference(run.startedAt);
  final steps = run.steps.toList();
  final item = e['item'] is Map ? e['item'] as Map : const {};
  final id = '${item['id'] ?? ''}';
  String toolName(Map i) => switch (i['type']) {
        'command_execution' => 'Shell',
        'file_change' => 'Edit',
        'web_search' => 'Web search',
        'mcp_tool_call' => '${i['server'] ?? 'mcp'}.${i['tool'] ?? 'tool'}',
        _ => '${i['type']}',
      };
  String paramsOf(Map i) => jsonEncode(switch (i['type']) {
        'command_execution' => {'command': i['command'] ?? ''},
        'file_change' => {'files': [for (final c in (i['changes'] is List ? i['changes'] as List : const [])) if (c is Map) '${c['kind'] ?? 'change'} ${c['path'] ?? ''}']},
        'web_search' => {'query': i['query'] ?? ''},
        _ => i['arguments'] ?? const {},
      });
  String resultOf(Map i) => switch (i['type']) {
        'command_execution' => i['exit_code'] is int && i['exit_code'] != 0 ? 'Error: exit ${i['exit_code']}. ${_short('${i['aggregated_output'] ?? ''}')}' : _short('${i['aggregated_output'] ?? ''}'),
        'file_change' => '${i['status'] ?? ''}',
        'mcp_tool_call' => i['error'] != null ? 'Error: ${i['error']}' : _short(_resultText(i['result'] is Map ? (i['result'] as Map)['content'] : i['result'])),
        _ => '${i['status'] ?? ''}',
      };
  const tools = {'command_execution', 'file_change', 'web_search', 'mcp_tool_call'};
  final meters = run.meters;
  switch (e['type']) {
    case 'item.started' when tools.contains(item['type']):
      steps.add(PlayStep(kind: PlayStepKind.tool, text: toolName(item), params: paramsOf(item), toolId: id, at: when));
    case 'item.completed':
      switch (item['type']) {
        case 'agent_message':
          final t = '${item['text'] ?? ''}'.trim();
          if (t.isNotEmpty) steps.add(PlayStep(kind: PlayStepKind.thinking, text: t, params: _said, at: when));
        case 'reasoning':
          final t = '${item['text'] ?? ''}'.trim();
          if (t.isNotEmpty) steps.add(PlayStep(kind: PlayStepKind.thinking, text: _short(t, 600), at: when));
        case 'error':
          final t = '${item['message'] ?? ''}'.trim();
          if (t.isNotEmpty) steps.add(PlayStep(kind: PlayStepKind.thinking, text: 'Codex warned: ${_short(t, 300)}', at: when));
        case final String type when tools.contains(type):
          final i = steps.lastIndexWhere((s) => s.kind == PlayStepKind.tool && s.toolId == id);
          if (i >= 0) {
            steps[i] = steps[i].withResult(resultOf(item));
          } else {
            steps.add(PlayStep(kind: PlayStepKind.tool, text: toolName(item), params: paramsOf(item), result: resultOf(item), toolId: id, at: when));
          }
        default:
          return run;
      }
    case 'turn.completed':
      // What it said last is the answer.
      final i = steps.lastIndexWhere((s) => s.kind == PlayStepKind.thinking && s.params == _said);
      if (i >= 0 && i == steps.length - 1) steps[i] = PlayStep(kind: PlayStepKind.answer, text: steps[i].text, at: steps[i].at);
      final usage = e['usage'] is Map ? e['usage'] as Map : const {};
      return run.copyWith(
        state: PlayState.done,
        steps: steps,
        meters: PlayMeters(
          turns: meters.turns + 1,
          elapsed: when,
          tokensIn: meters.tokensIn + (usage['input_tokens'] is int ? usage['input_tokens'] as int : 0),
          tokensOut: meters.tokensOut + (usage['output_tokens'] is int ? usage['output_tokens'] as int : 0),
        ),
      );
    case 'turn.failed':
      final text = _codexError(e['error'] is Map ? '${(e['error'] as Map)['message'] ?? ''}' : '');
      steps.add(PlayStep(kind: PlayStepKind.error, text: text, at: when));
      return run.copyWith(state: PlayState.failed, steps: steps, error: text, meters: PlayMeters(turns: meters.turns, elapsed: when, tokensIn: meters.tokensIn, tokensOut: meters.tokensOut));
    default:
      return run;
  }
  return run.copyWith(steps: steps, meters: PlayMeters(turns: meters.turns, elapsed: when, tokensIn: meters.tokensIn, tokensOut: meters.tokensOut));
}

/// Codex's error, readable: its API errors come as JSON inside the message.
String _codexError(String raw) {
  final text = raw.trim();
  try {
    final inner = jsonDecode(text);
    if (inner is Map && inner['error'] is Map && (inner['error'] as Map)['message'] != null) return '${(inner['error'] as Map)['message']}';
  } on FormatException {
    // Plain text.
  }
  return text.isEmpty ? 'The run failed.' : text;
}

/// A step as Claude reads it when asked to fix the instructions.
String describeStep(PlayStep s) => switch (s.kind) {
      PlayStepKind.tool => '${s.text}(${s.params})${s.result.isEmpty ? '' : ' → ${s.result.split('\n').first}'}',
      _ => s.text,
    };
