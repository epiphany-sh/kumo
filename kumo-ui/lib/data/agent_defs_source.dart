import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'agent_defs.dart';
import 'agent_playground.dart';
import 'agents_source.dart';
import 'models.dart' show AgentStatus;

/// Where a run of one of your agents works.
enum AgentWhereKind {
  /// A worktree of the workspace ([AgentWhere.path]).
  worktree,

  /// A new worktree of [AgentWhere.repo], from its default branch.
  newWorktree,

  /// A repository, branch or pull request link ([AgentWhere.url]): Kumo
  /// clones or checks it out.
  link,

  /// Any folder ([AgentWhere.path]), repository or not.
  folder,

  /// An empty folder Kumo makes, for research or writing.
  scratch,
}

@immutable
class AgentWhere {
  const AgentWhere.worktree(this.path, {this.repo = ''})
      : kind = AgentWhereKind.worktree,
        url = '';
  const AgentWhere.newWorktree(this.repo)
      : kind = AgentWhereKind.newWorktree,
        path = '',
        url = '';
  const AgentWhere.link(this.url)
      : kind = AgentWhereKind.link,
        path = '',
        repo = '';
  const AgentWhere.folder(this.path)
      : kind = AgentWhereKind.folder,
        repo = '',
        url = '';
  const AgentWhere.scratch()
      : kind = AgentWhereKind.scratch,
        path = '',
        repo = '',
        url = '';

  final AgentWhereKind kind;
  final String path;

  /// The repository's name (worktrees).
  final String repo;
  final String url;
}

/// A repository, branch or pull request link, as Kumo reads it.
@immutable
class RepoLink {
  const RepoLink({required this.host, required this.path, this.number, this.mergeRequest = false, this.branch = ''});

  /// e.g. github.com.
  final String host;

  /// owner/repo (GitLab: group/sub/repo).
  final String path;

  /// The pull (merge) request's number.
  final int? number;
  final bool mergeRequest;
  final String branch;

  String get name => path.split('/').last;
  String get ref => number == null ? '' : (mergeRequest ? '!$number' : '#$number');
}

/// Reads [url] as a repository, branch or pull request link; null when it
/// isn't one.
RepoLink? parseRepoLink(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null || !(u.scheme == 'https' || u.scheme == 'http') || u.host.isEmpty) return null;
  final parts = [for (final p in u.pathSegments) if (p.isNotEmpty) p];
  final dash = parts.indexOf('-');
  final cut = dash >= 0 ? dash : parts.indexWhere((p) => p == 'pull' || p == 'tree' || p == 'pulls' || p == 'merge_requests');
  final repo = (cut >= 0 ? parts.sublist(0, cut) : parts).join('/').replaceAll(RegExp(r'\.git$'), '');
  if (repo.split('/').length < 2) return null;
  final rest = cut >= 0 ? parts.sublist(dash >= 0 ? dash + 1 : cut) : const <String>[];
  if (rest.length >= 2 && (rest[0] == 'pull' || rest[0] == 'merge_requests')) {
    final n = int.tryParse(rest[1]);
    if (n == null) return null;
    return RepoLink(host: u.host, path: repo, number: n, mergeRequest: rest[0] == 'merge_requests');
  }
  if (rest.length >= 2 && rest[0] == 'tree') return RepoLink(host: u.host, path: repo, branch: rest.sublist(1).join('/'));
  return RepoLink(host: u.host, path: repo);
}

/// Your agents (Claude Code subagents): the files of the workspace and of
/// its repositories, their runs and their test runs. Through the daemon,
/// which reads and writes the files and keeps Kumo's own settings for them
/// (time and cost limits, triggers).
abstract class AgentDefsSource extends ChangeNotifier {
  /// The daemon has the AgentDefs service (false: Agents › Your agents
  /// says Kumo needs updating).
  bool get supported;

  /// Every agent, personal first, then each repository's.
  List<AgentDef> get agents;

  /// Last failure, readable.
  String? get error;

  Future<void> load();

  /// Saves [agent] (moving or renaming [previous] when it was saved under
  /// another name or scope). Throws a readable message.
  Future<AgentDef> save(AgentDef agent, {AgentDef? previous});

  Future<void> delete(AgentDef agent);

  /// Skills and MCP servers it can be given.
  List<String> get skills;
  List<String> get mcpServers;

  /// Whether triggers run (the daemon schedules them).
  bool get triggersSupported;

  /// An agent a connected CLI drafted from [description]; null when it
  /// couldn't.
  Future<AgentDef?> draft(String description, {AgentScope scope = AgentScope.personal, String repo = ''});

  /// New instructions for [agent], from a test step that went wrong.
  Future<String?> improve(AgentDef agent, {String step = '', String answer = ''});

  /// Starts [agent] on [cli] in its own terminal at [where], with [prompt]
  /// as its first message and [context] saved next to the run.
  Future<AgentRun?> run(AgentDef agent, AgentWhere where, {String prompt = '', List<AgentContextItem> context = const [], AgentCli cli = AgentCli.claude});

  /// Runs of [agent] (newest first); the daemon's sessions that ran it.
  List<AgentRun> runsOf(AgentDef agent);

  /// Tries [agent] (the unsaved draft when [draft]) on [task], headless, in
  /// [worktreePath] (or a throwaway worktree of it when it can change
  /// files). The run fills in as it goes and joins [owner]'s test runs (the
  /// agent as saved: a draft may have another name); see [playRuns].
  Future<PlayRun?> play(AgentDef agent, {required String task, required String worktreePath, AgentDef? owner, bool draft = true, List<AgentContextItem> context = const [], AgentCli cli = AgentCli.claude});

  Future<void> stopPlay(String id);

  /// Test runs of [agent], newest first: the last 10 are kept.
  List<PlayRun> playRuns(AgentDef agent);
}

/// The design's agents: three in price-admin, three personal; a review of
/// PR #521 running, and canned test runs.
class MockAgentDefs extends AgentDefsSource {
  MockAgentDefs({this.step = const Duration(milliseconds: 450)});

  /// Between the playground's steps.
  final Duration step;

  static const _reviewer = AgentDef(
    name: 'go-pr-reviewer',
    description: 'Reviews Go pull requests and finds code that already existed and could have been reused. Use it when a PR in a Go repo is ready for review.',
    instructions: 'You review pull requests of Go repositories. Your one job: find code the PR adds that already existed in the repo and could have been reused.\n\n'
        'How to work:\n1. Read the PR’s diff (it’s in the run’s context folder).\n2. For each new function, type or constant, search the repo for one that does the same.\n3. Read the candidates before you claim a match.\n\n'
        'Report each match as: the new code (file:line), the existing code (file:line), and one line on how to reuse it. If you find nothing, say so.\n\n'
        'Don’t comment on style, naming or tests. Don’t change any file.',
    knowledge: ['docs/conventions.md'],
    scope: AgentScope.project,
    repo: 'price-admin',
  );

  List<AgentDef> _agents = [
    const AgentDef(
      name: 'researcher',
      description: 'Researches a library, API or approach on the web and in the code, and reports the options with sources. Use it before picking a dependency.',
      instructions: 'You are a researcher.\n\nHow to work:\n1. Look at three to five options: docs, issues, releases, and how the code here would use each.\n2. Compare them in a table.\n\nDon’t change any file. Cite every claim.',
      tools: [...readOnlyTools, 'WebFetch', 'WebSearch'],
      model: 'opus',
      maxTurns: 30,
      maxMinutes: 15,
      maxCostUsd: 2,
      memory: AgentMemory.user,
      color: 'purple',
      output: AgentOutput.markdown,
      outputTemplate: '## Options\n\n## Recommendation\n\n## Sources',
    ),
    const AgentDef(
      name: 'release-notes',
      description: 'Writes release notes from the commits and pull requests since the previous tag. Use it when cutting a release.',
      instructions: 'You write release notes.\n\nHow to work:\n1. Read git log since the previous tag and the merged pull requests.\n2. Group what changed for people who use it.\n\nDon’t tag, don’t push, don’t edit the release.',
      tools: [...readOnlyTools, 'Bash'],
      model: 'haiku',
      maxTurns: 20,
      color: 'blue',
    ),
    const AgentDef(
      name: 'ticket-writer',
      description: 'Turns a bug report or a Slack thread into a Jira ticket with steps, impact and acceptance criteria. Use it when a report needs a ticket.',
      instructions: 'You write Jira tickets for the pricing team: summary, steps to reproduce, impact, acceptance criteria.\n\nCreate it only after I confirm it.',
      tools: ['Read', 'WebFetch'],
      mcpServers: ['jira'],
      maxTurns: 15,
      maxMinutes: 5,
      color: 'pink',
    ),
    _reviewer,
    const AgentDef(
      name: 'test-writer',
      description: 'Writes table-driven Go tests for what a branch changed and runs them. Use it once a feature works, before asking for review.',
      instructions: 'You write table-driven Go tests.\n\nHow to work:\n1. Find the functions the branch changed.\n2. Write tests for each, then run go test for those packages.\n\nDon’t change code outside _test.go files. Don’t push.',
      tools: [...readOnlyTools, 'Edit', 'Write', 'Bash'],
      model: 'sonnet',
      approvals: AgentApprovals.acceptEdits,
      maxTurns: 40,
      maxMinutes: 20,
      skills: ['go-table-tests'],
      memory: AgentMemory.project,
      isolation: true,
      color: 'green',
      knowledge: ['docs/testing.md'],
      scope: AgentScope.project,
      repo: 'price-admin',
    ),
    const AgentDef(
      name: 'migration-checker',
      description: 'Checks that SQL migrations are reversible and safe on a live table. Use it on any branch that adds a migration.',
      instructions: 'You review SQL migrations for Postgres.\n\nFor each migration, check it has a down step and doesn’t lock a large table.\n\nDon’t run any migration. Don’t change any file.',
      model: 'haiku',
      approvals: AgentApprovals.plan,
      maxTurns: 15,
      maxMinutes: 5,
      mcpServers: ['postgres'],
      color: 'orange',
      output: AgentOutput.json,
      outputTemplate: '[{ "file": "", "reversible": true, "locks": "", "fix": "" }]',
      scope: AgentScope.project,
      repo: 'price-admin',
    ),
  ];

  late final List<AgentRun> _runs = [
    AgentRun(
      id: 'def-r2', providerId: 'claude', providerName: 'Claude Code', short: 'CC', agent: 'go-pr-reviewer',
      worktreePath: '~/wt/price-admin/PRC-412', terminalId: 'mock:reviewer', title: 'PR #521 · Bulk discounts', status: AgentStatus.running,
      startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      prompt: 'Review PR #521 against main. Point out code that already existed and could have been reused.',
      context: const [AgentContextItem(kind: AgentContextKind.pullRequest, title: '#521 · diff + description'), AgentContextItem(kind: AgentContextKind.task, title: 'PRC-412', detail: 'Jira')],
    ),
    AgentRun(
      id: 'def-r1', providerId: 'claude', providerName: 'Claude Code', short: 'CC', agent: 'go-pr-reviewer',
      worktreePath: '~/wt/price-admin/PRC-398', terminalId: 'mock:reviewer-done', title: 'PR #517 · Rounding fix', status: AgentStatus.done,
      startedAt: DateTime.now().subtract(const Duration(hours: 2)), prompt: 'Review PR #517.',
    ),
    AgentRun(
      id: 'def-q1', providerId: 'claude', providerName: 'Claude Code', short: 'CC', agent: 'researcher',
      worktreePath: '~/.kumo/scratch/researcher-2', terminalId: 'mock:researcher', title: 'Kafka clients for Go', status: AgentStatus.done,
      startedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];
  final Map<String, List<PlayRun>> _plays = {};
  final Map<String, Timer> _timers = {};
  int _seq = 0;

  @override
  bool get supported => true;
  @override
  List<AgentDef> get agents => _agents;
  @override
  String? get error => null;
  @override
  bool get triggersSupported => true;
  @override
  List<String> get skills => const ['go-table-tests', 'go-conventions', 'sql-review'];
  @override
  List<String> get mcpServers => const ['jira', 'gitlab', 'postgres'];

  @override
  Future<void> load() async {}

  @override
  Future<AgentDef> save(AgentDef agent, {AgentDef? previous}) async {
    // In place of the one it replaces (or at the end); renamed, its test runs go along.
    final at = _agents.indexWhere((a) => a.key == (previous ?? agent).key);
    final out = [..._agents];
    if (at >= 0) out[at] = agent;
    out.removeWhere((a) => a.key == agent.key && !identical(a, agent));
    if (previous != null) out.removeWhere((a) => a.key == previous.key && !identical(a, agent));
    if (at < 0) out.add(agent);
    _agents = out;
    if (previous != null && previous.key != agent.key && _plays.containsKey(previous.key)) _plays[agent.key] = _plays.remove(previous.key)!;
    notifyListeners();
    return agent;
  }

  @override
  Future<void> delete(AgentDef agent) async {
    _agents = [for (final a in _agents) if (a.key != agent.key) a];
    notifyListeners();
  }

  @override
  Future<AgentDef?> draft(String description, {AgentScope scope = AgentScope.personal, String repo = ''}) async {
    final words = description.toLowerCase();
    final migrations = words.contains('migration');
    return AgentDef(
      name: migrations ? 'migration-guard' : 'new-agent',
      description: migrations
          ? 'Checks that SQL migrations are reversible and safe on a live table. Use it on any branch that adds a migration.'
          : '${description.trim().replaceAll(RegExp(r'\.$'), '')}. Use it when ',
      instructions: 'You are ${migrations ? 'a reviewer of SQL migrations' : 'an agent that ${description.trim()}'}.\n\nHow to work:\n1. Read what you were given first.\n2. ${migrations ? 'Check every migration has a down step and won’t lock a large table.' : 'Do the job, step by step.'}\n3. Say what you did and what you’re unsure of.\n\nDon’t change any file.',
      tools: defaultAgentTools,
      color: migrations ? 'orange' : 'cyan',
      scope: scope,
      repo: repo,
    );
  }

  @override
  Future<String?> improve(AgentDef agent, {String step = '', String answer = ''}) async {
    const line = '4. Only open tests of the packages the PR touches; don’t list every test file.';
    if (agent.instructions.contains(line)) return agent.instructions;
    final lines = agent.instructions.split('\n');
    final at = lines.indexWhere((l) => l.startsWith('3. '));
    if (at < 0) return '${agent.instructions.trim()}\n\n$line';
    lines.insert(at + 1, line);
    return lines.join('\n');
  }

  @override
  Future<AgentRun?> run(AgentDef agent, AgentWhere where, {String prompt = '', List<AgentContextItem> context = const [], AgentCli cli = AgentCli.claude}) async {
    final r = AgentRun(
      id: 'def-n${++_seq}', providerId: cli.id, providerName: cli.label, short: switch (cli) { AgentCli.codex => 'CX', AgentCli.copilot => 'GH', AgentCli.claude => 'CC' }, agent: agent.name,
      worktreePath: where.path.isNotEmpty ? where.path : (where.url.isNotEmpty ? where.url : '~/.kumo/scratch/${agent.name}-$_seq'),
      terminalId: 'mock:new-$_seq', title: prompt.isEmpty ? 'Run ${runsOf(agent).length + 1}' : (prompt.length > 34 ? '${prompt.substring(0, 32)}…' : prompt),
      status: AgentStatus.running, startedAt: DateTime.now(), prompt: prompt, context: context,
    );
    _runs.insert(0, r);
    notifyListeners();
    return r;
  }

  /// Stops or forgets a mock run (the design has no daemon to ask).
  void finish(String id, {bool forget = false}) {
    final i = _runs.indexWhere((r) => r.id == id);
    if (i < 0) return;
    if (forget) {
      _runs.removeAt(i);
    } else {
      final r = _runs[i];
      _runs[i] = AgentRun(
        id: r.id, providerId: r.providerId, providerName: r.providerName, short: r.short, agent: r.agent, worktreePath: r.worktreePath,
        terminalId: r.terminalId, title: r.title, status: AgentStatus.done, startedAt: r.startedAt, prompt: r.prompt, exitCode: 130, context: r.context,
      );
    }
    notifyListeners();
  }

  @override
  List<AgentRun> runsOf(AgentDef agent) => [for (final r in _runs) if (r.agent == agent.name) r];

  @override
  List<PlayRun> playRuns(AgentDef agent) => _plays[agent.key] ??= _history(agent);

  List<PlayRun> _history(AgentDef agent) {
    if (agent.name != 'go-pr-reviewer') return [];
    var run = PlayRun(id: 'play-h4', agent: agent.name, task: _task, draft: false, startedAt: DateTime.now().subtract(const Duration(minutes: 5)));
    for (final (i, line) in _script.indexed) {
      run = foldStreamJson(run, line, at: Duration(milliseconds: 1200 * i));
    }
    return [
      run,
      PlayRun(id: 'play-h3', agent: agent.name, task: _task, draft: false, startedAt: DateTime.now().subtract(const Duration(hours: 1)), state: PlayState.done, meters: const PlayMeters(turns: 18, elapsed: Duration(seconds: 130), costUsd: 0.14)),
      PlayRun(id: 'play-h2', agent: agent.name, task: _task, draft: false, startedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)), state: PlayState.failed, error: 'It reached its turn limit.', meters: const PlayMeters(turns: 25, elapsed: Duration(seconds: 214), costUsd: 0.21)),
    ];
  }

  static const _task = 'Review PR #521 (Bulk discounts by category) against main.';

  /// A real-looking stream-json run of go-pr-reviewer.
  static final _script = <String>[
    jsonEncode({'type': 'system', 'subtype': 'init', 'model': 'claude-sonnet'}),
    jsonEncode({'type': 'assistant', 'message': {'content': [{'type': 'text', 'text': 'I’ll read the diff first, then look for existing code for each new function.'}]}}),
    jsonEncode({'type': 'assistant', 'message': {'content': [{'type': 'tool_use', 'id': 't1', 'name': 'Read', 'input': {'file_path': '~/.kumo/runs/play/pr-521.diff'}}]}}),
    jsonEncode({'type': 'user', 'message': {'content': [{'type': 'tool_result', 'tool_use_id': 't1', 'content': '412 lines · 4 files · new: bulkPercent, roundCents, CategoryRule'}]}}),
    jsonEncode({'type': 'assistant', 'message': {'content': [{'type': 'text', 'text': 'Three new identifiers. Searching for helpers that already do the same.'}]}}),
    jsonEncode({'type': 'assistant', 'message': {'content': [{'type': 'tool_use', 'id': 't2', 'name': 'Grep', 'input': {'pattern': r'func (\w*Percent|[Rr]ound\w*)', 'path': 'internal/'}}]}}),
    jsonEncode({'type': 'user', 'message': {'content': [{'type': 'tool_result', 'tool_use_id': 't2', 'content': 'internal/discount/calc.go:48  func applyPercent(p Price, pct int) Price\ninternal/money/round.go:12  func RoundCents(v float64) int64'}]}}),
    jsonEncode({'type': 'assistant', 'message': {'content': [{'type': 'tool_use', 'id': 't3', 'name': 'Glob', 'input': {'pattern': '**/*_test.go'}}]}}),
    jsonEncode({'type': 'user', 'message': {'content': [{'type': 'tool_result', 'tool_use_id': 't3', 'content': '61 files'}]}}),
    jsonEncode({'type': 'assistant', 'message': {'content': [{'type': 'tool_use', 'id': 't4', 'name': 'Read', 'input': {'file_path': 'internal/money/round.go'}}]}}),
    jsonEncode({'type': 'user', 'message': {'content': [{'type': 'tool_result', 'tool_use_id': 't4', 'content': 'Read 40 lines'}]}}),
    jsonEncode({
      'type': 'result', 'subtype': 'success', 'num_turns': 8, 'duration_ms': 41000, 'total_cost_usd': 0.06,
      'usage': {'input_tokens': 38200, 'output_tokens': 2100},
      'result': 'Two reuse opportunities:\n1. bulkPercent (internal/kafka/bulk_consumer.go:91) does what applyPercent (internal/discount/calc.go:48) does, with the cap inlined. Call applyPercent and cap after.\n2. roundCents (bulk_consumer.go:118) repeats money.RoundCents (internal/money/round.go:12). Use that one.\n\nCategoryRule is new: nothing like it exists.',
    }),
  ];

  /// The same review on Codex: `codex exec --json`, as it prints it.
  static final _codexScript = <String>[
    jsonEncode({'type': 'thread.started', 'thread_id': 'mock'}),
    jsonEncode({'type': 'turn.started'}),
    jsonEncode({'type': 'item.completed', 'item': {'id': 'item_0', 'type': 'agent_message', 'text': 'I’ll read the diff, then look for existing code for each new function.'}}),
    jsonEncode({'type': 'item.started', 'item': {'id': 'item_1', 'type': 'command_execution', 'command': "rg -n 'func (\\w*Percent|[Rr]ound\\w*)' internal/", 'aggregated_output': '', 'exit_code': null, 'status': 'in_progress'}}),
    jsonEncode({'type': 'item.completed', 'item': {'id': 'item_1', 'type': 'command_execution', 'command': "rg -n 'func (\\w*Percent|[Rr]ound\\w*)' internal/", 'aggregated_output': 'internal/discount/calc.go:48:func applyPercent(p Price, pct int) Price\ninternal/money/round.go:12:func RoundCents(v float64) int64', 'exit_code': 0, 'status': 'completed'}}),
    jsonEncode({'type': 'item.completed', 'item': {'id': 'item_2', 'type': 'agent_message', 'text': 'Two reuse opportunities: bulkPercent repeats applyPercent (internal/discount/calc.go:48), and roundCents repeats money.RoundCents (internal/money/round.go:12). CategoryRule is new.'}}),
    jsonEncode({'type': 'turn.completed', 'usage': {'input_tokens': 24100, 'cached_input_tokens': 18000, 'output_tokens': 610}}),
  ];

  /// The same review on Copilot: `copilot -p --output-format json`, as it
  /// prints it (the lines that only stream text left out).
  static final _copilotScript = <String>[
    jsonEncode({'type': 'assistant.turn_start', 'data': {'turnId': '0'}}),
    jsonEncode({'type': 'assistant.message', 'data': {'content': 'I’ll read the diff, then look for existing code for each new function.', 'toolRequests': []}}),
    jsonEncode({'type': 'tool.execution_start', 'data': {'toolCallId': 'c1', 'toolName': 'grep', 'arguments': {'pattern': r'func (\w*Percent|[Rr]ound\w*)', 'path': 'internal/'}}}),
    jsonEncode({'type': 'tool.execution_complete', 'data': {'toolCallId': 'c1', 'success': true, 'result': {'content': 'internal/discount/calc.go:48:func applyPercent(p Price, pct int) Price\ninternal/money/round.go:12:func RoundCents(v float64) int64'}}}),
    jsonEncode({'type': 'assistant.turn_start', 'data': {'turnId': '1'}}),
    jsonEncode({'type': 'assistant.message', 'data': {'content': 'Two reuse opportunities: bulkPercent repeats applyPercent (internal/discount/calc.go:48), and roundCents repeats money.RoundCents (internal/money/round.go:12). CategoryRule is new.', 'toolRequests': []}}),
    jsonEncode({'type': 'session.usage_checkpoint', 'data': {'accountingSnapshot': {'modelMetrics': {'gpt-6-luna': {'usage': {'inputTokens': 21400, 'outputTokens': 540}}}}}}),
    jsonEncode({'type': 'result', 'exitCode': 0, 'usage': {'premiumRequests': 1}}),
  ];

  @override
  Future<PlayRun?> play(AgentDef agent, {required String task, required String worktreePath, AgentDef? owner, bool draft = true, List<AgentContextItem> context = const [], AgentCli cli = AgentCli.claude}) async {
    final id = 'play-${++_seq}';
    final list = playRuns(owner ?? agent);
    list.insert(0, PlayRun(id: id, agent: agent.name, task: task, draft: draft, startedAt: DateTime.now(), cli: cli.id));
    if (list.length > 10) list.removeRange(10, list.length);
    final script = switch (cli) { AgentCli.codex => _codexScript, AgentCli.copilot => _copilotScript, AgentCli.claude => _script };
    var at = 0;
    _timers[id] = Timer.periodic(step, (t) {
      final i = list.indexWhere((r) => r.id == id);
      if (i < 0 || at >= script.length) {
        t.cancel();
        _timers.remove(id);
        return;
      }
      list[i] = foldPlayLine(list[i], script[at], at: Duration(milliseconds: step.inMilliseconds * (at + 1)));
      at++;
      notifyListeners();
    });
    notifyListeners();
    return list.first;
  }

  @override
  Future<void> stopPlay(String id) async {
    _timers.remove(id)?.cancel();
    for (final list in _plays.values) {
      final i = list.indexWhere((r) => r.id == id);
      if (i >= 0 && list[i].state == PlayState.running) list[i] = list[i].copyWith(state: PlayState.stopped);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }
}

/// A daemon without the AgentDefs service: nothing to list, nothing saved.
class UnsupportedAgentDefs extends AgentDefsSource {
  @override
  bool get supported => false;
  @override
  List<AgentDef> get agents => const [];
  @override
  String? get error => 'This version of Kumo’s engine can’t read agent files yet.';
  @override
  bool get triggersSupported => false;
  @override
  List<String> get skills => const [];
  @override
  List<String> get mcpServers => const [];
  @override
  Future<void> load() async {}
  @override
  Future<AgentDef> save(AgentDef agent, {AgentDef? previous}) async => throw error!;
  @override
  Future<void> delete(AgentDef agent) async {}
  @override
  Future<AgentDef?> draft(String description, {AgentScope scope = AgentScope.personal, String repo = ''}) async => null;
  @override
  Future<String?> improve(AgentDef agent, {String step = '', String answer = ''}) async => null;
  @override
  Future<AgentRun?> run(AgentDef agent, AgentWhere where, {String prompt = '', List<AgentContextItem> context = const [], AgentCli cli = AgentCli.claude}) async => null;
  @override
  List<AgentRun> runsOf(AgentDef agent) => const [];
  @override
  Future<PlayRun?> play(AgentDef agent, {required String task, required String worktreePath, AgentDef? owner, bool draft = true, List<AgentContextItem> context = const [], AgentCli cli = AgentCli.claude}) async => null;
  @override
  Future<void> stopPlay(String id) async {}
  @override
  List<PlayRun> playRuns(AgentDef agent) => const [];
}
