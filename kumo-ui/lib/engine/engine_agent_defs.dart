import 'dart:async';

import 'package:grpc/grpc.dart';

import '../data/agent_defs.dart';
import '../data/agent_defs_source.dart';
import '../data/agent_playground.dart';
import '../data/agents_source.dart';
import '../data/workspace_source.dart';
import 'engine_agents_source.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart' as pb;
import 'kumo_engine.dart';

/// Your agents as `kumod` keeps them (`AgentDefs`): the files it moves, the
/// format read and written here ([readAgentFile], [AgentDef.toMarkdown]).
/// Runs show as the agents source's sessions.
class EngineAgentDefs extends AgentDefsSource {
  EngineAgentDefs(this._engine, this._agents, this._workspace) {
    _agents.addListener(notifyListeners);
  }

  final KumoEngine _engine;
  final AgentsSource _agents;
  final WorkspaceSource _workspace;
  bool _disposed = false;
  bool _supported = true;
  List<AgentDef> _list = const [];
  String? _error;
  List<String> _skills = const [];
  List<String> _mcpServers = const [];
  bool _triggers = false;

  /// Test runs by the agent's key; missing until read from the daemon.
  final Map<String, List<PlayRun>> _plays = {};
  final Set<String> _readingPlays = {};

  /// A test run's id here → the daemon's, once its first event came.
  final Map<String, String> _playIds = {};
  final Set<String> _stopping = {};
  final Map<String, StreamSubscription<pb.PlayEvent>> _live = {};
  int _seq = 0;

  Future<pb.AgentDefsClient> get _client async => (await _engine.connection()).agentDefs;

  @override
  bool get supported => _supported;
  @override
  List<AgentDef> get agents => _list;
  @override
  String? get error => _error;
  @override
  List<String> get skills => _skills;
  @override
  List<String> get mcpServers => _mcpServers;
  @override
  bool get triggersSupported => _triggers;

  static String _message(Object e) => e is GrpcError ? (e.message ?? e.codeName) : '$e';

  bool _unsupported(Object e) {
    if (e is GrpcError && e.code == StatusCode.unimplemented) {
      _supported = false;
      _error = UnsupportedAgentDefs().error;
      return true;
    }
    return false;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> load() async {
    try {
      final client = await _client;
      final list = await client.list(pb.ListAgentDefsRequest());
      _list = [for (final f in list.agents) agentDefFrom(f)];
      _supported = true;
      _error = null;
      try {
        final caps = await client.capabilities(pb.AgentDefCapabilitiesRequest());
        _skills = caps.skills.toList();
        _mcpServers = caps.mcpServers.toList();
        _triggers = caps.triggersSupported;
      } on Object {
        // The list still shows.
      }
    } on Object catch (e) {
      if (!_unsupported(e)) _error = _message(e);
    }
    _changed();
  }

  /// The main checkout of the workspace's repository [name].
  String _repoPath(String name) => _workspace.repos.where((r) => r.name == name).firstOrNull?.path ?? '';

  /// The main checkout of the repository [where]'s worktree belongs to.
  String _repoOfWorktree(AgentWhere where) {
    for (final repo in _workspace.repos) {
      if (repo.worktrees.any((w) => _workspace.absolutePathOf(w) == where.path)) return repo.path ?? '';
    }
    return _repoPath(where.repo);
  }

  pb.AgentDefFile _fileOf(AgentDef a) => agentDefFileTo(a, repoPath: a.scope == AgentScope.project ? (a.repoPath.isNotEmpty ? a.repoPath : _repoPath(a.repo)) : '');

  @override
  Future<AgentDef> save(AgentDef agent, {AgentDef? previous}) async {
    try {
      final request = pb.SaveAgentDefRequest(agent: _fileOf(agent));
      if (previous != null) request.previous = _fileOf(previous);
      await (await _client).save(request);
      // As it lists from now on.
      agent = agent.copyWith(repoPath: request.agent.repoPath);
      if (previous != null && previous.key != agent.key) {
        final kept = _plays.remove(previous.key);
        if (kept != null) _plays[agent.key] = kept;
      }
    } on Object catch (e) {
      _unsupported(e);
      throw _message(e);
    }
    await load();
    return agent;
  }

  @override
  Future<void> delete(AgentDef agent) async {
    try {
      await (await _client).delete(pb.DeleteAgentDefRequest(agent: _fileOf(agent)));
      _plays.remove(agent.key);
    } on Object catch (e) {
      _unsupported(e);
      _error = _message(e);
    }
    await load();
  }

  /// One answer from Claude (plan mode), or null with [error] set.
  Future<String?> _ask(String prompt, {String cwd = ''}) async {
    try {
      final answer = await (await _client).ask(pb.AskClaudeRequest(prompt: prompt, cwd: cwd));
      _error = null;
      return unfence(answer.text);
    } on Object catch (e) {
      if (!_unsupported(e)) _error = _message(e);
      _changed();
      return null;
    }
  }

  @override
  Future<AgentDef?> draft(String description, {AgentScope scope = AgentScope.personal, String repo = ''}) async {
    final text = await _ask(draftAgentPrompt(description), cwd: scope == AgentScope.project ? _repoPath(repo) : '');
    if (text == null) return null;
    final taken = {for (final a in _list) if (a.scope == scope && (scope == AgentScope.personal || a.repo == repo)) a.name};
    return readAgentFile(text, scope: scope, repo: repo, taken: taken).agent;
  }

  @override
  Future<String?> improve(AgentDef agent, {String step = '', String answer = ''}) =>
      _ask(improveInstructionsPrompt(agent, step: step, answer: answer), cwd: agent.scope == AgentScope.project ? _repoPath(agent.repo) : '');

  @override
  Future<AgentRun?> run(AgentDef agent, AgentWhere where, {String prompt = '', List<AgentContextItem> context = const [], AgentCli cli = AgentCli.claude}) async {
    final request = pb.RunAgentDefRequest(
      agent: _fileOf(agent),
      inlineJson: agentInlineJson(agent),
      providerId: cli.id,
      prompt: prompt,
      context: [for (final c in context) agentContextTo(c)],
      cols: 120,
      rows: 40,
    );
    switch (where.kind) {
      case AgentWhereKind.worktree:
        // The CLIs don't isolate an agent run: Kumo does.
        final repo = agent.isolation ? _repoOfWorktree(where) : '';
        if (repo.isNotEmpty) {
          request.newWorktreeRepo = repo;
        } else {
          request.worktreePath = where.path;
        }
      case AgentWhereKind.newWorktree:
        request.newWorktreeRepo = _repoPath(where.repo);
      case AgentWhereKind.link:
        request.linkUrl = where.url;
      case AgentWhereKind.folder:
        request.folder = where.path;
      case AgentWhereKind.scratch:
        request.scratch = true;
    }
    try {
      final session = await (await _client).run(request);
      _error = null;
      _changed();
      return agentRunFrom(session);
    } on Object catch (e) {
      if (!_unsupported(e)) _error = _message(e);
      _changed();
      return null;
    }
  }

  @override
  List<AgentRun> runsOf(AgentDef agent) => [for (final r in _agents.runs) if (r.agent == agent.name) r];

  @override
  List<PlayRun> playRuns(AgentDef agent) {
    final known = _plays[agent.key];
    if (known != null) return known;
    if (_supported && _readingPlays.add(agent.key)) _readPlays(agent).ignore();
    return const [];
  }

  Future<void> _readPlays(AgentDef agent) async {
    try {
      final list = await (await _client).listPlays(pb.ListPlaysRequest(agent: _fileOf(agent)));
      final live = [for (final r in _plays[agent.key] ?? const <PlayRun>[]) if (r.state == PlayState.running) r];
      _plays[agent.key] = [
        ...live,
        for (final record in list.plays)
          if (!live.any((l) => _playIds[l.id] == record.playId)) playRunFrom(record, agent: agent.name),
      ];
    } on Object catch (e) {
      _unsupported(e);
    } finally {
      _readingPlays.remove(agent.key);
    }
    _changed();
  }

  @override
  Future<PlayRun?> play(AgentDef agent, {required String task, required String worktreePath, AgentDef? owner, bool draft = true, List<AgentContextItem> context = const [], AgentCli cli = AgentCli.claude}) async {
    final history = owner ?? agent;
    final request = pb.PlayRequest(
      name: agent.name,
      inlineJson: agentInlineJson(agent),
      task: task,
      worktreePath: worktreePath,
      throwaway: agentWrites(agent.tools),
      context: [for (final c in context) agentContextTo(c)],
      agent: _fileOf(history),
      draft: draft,
      providerId: cli.id,
    );
    if (agent.maxTurns != null) request.maxTurns = agent.maxTurns!;
    if (agent.maxMinutes != null) request.maxMinutes = agent.maxMinutes!;
    if (agent.maxCostUsd != null) request.maxCostUsd = agent.maxCostUsd!;
    final ResponseStream<pb.PlayEvent> stream;
    try {
      stream = (await _client).play(request);
    } on Object catch (e) {
      if (!_unsupported(e)) _error = _message(e);
      _changed();
      return null;
    }
    final id = 'play-local-${++_seq}';
    final list = _plays[history.key] ??= [];
    list.insert(0, PlayRun(id: id, agent: agent.name, task: task, draft: draft, startedAt: DateTime.now(), cli: cli.id));
    if (list.length > 10) list.removeRange(10, list.length);
    _error = null;
    _changed();

    void update(PlayRun Function(PlayRun) change) {
      final runs = _plays[history.key];
      final i = runs?.indexWhere((r) => r.id == id) ?? -1;
      if (runs == null || i < 0) return;
      runs[i] = change(runs[i]);
      _changed();
    }

    _live[id] = stream.listen(
      (event) {
        _playIds[id] = event.playId;
        if (_stopping.remove(id)) _stop(event.playId);
        final at = Duration(milliseconds: event.atMs.toInt());
        if (event.hasLine()) update((r) => foldPlayLine(r, event.line, at: at));
        if (event.hasExited()) update((r) => playEnded(r, event.exited, stopped: _stopped.contains(id)));
      },
      onError: (Object e) {
        update((r) => r.state == PlayState.running ? r.copyWith(state: PlayState.failed, error: _message(e)) : r);
        _live.remove(id);
      },
      onDone: () => _live.remove(id),
    );
    return list.first;
  }

  final Set<String> _stopped = {};

  Future<void> _stop(String playId) async {
    try {
      await (await _client).stopPlay(pb.StopPlayRequest(playId: playId));
    } on Object catch (e) {
      _error = _message(e);
      _changed();
    }
  }

  @override
  Future<void> stopPlay(String id) async {
    _stopped.add(id);
    final engineId = _playIds[id];
    if (engineId == null) {
      // Stopped before it said its id: once it does.
      _stopping.add(id);
      return;
    }
    await _stop(engineId);
  }

  @override
  void dispose() {
    _disposed = true;
    _agents.removeListener(notifyListeners);
    for (final s in _live.values) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Claude's answer without a code fence around it.
String unfence(String text) {
  final t = text.trim();
  final m = RegExp(r'^```[\w-]*\n([\s\S]*?)\n```$').firstMatch(t);
  return m == null ? t : m.group(1)!.trim();
}

/// A listed file as an agent: read as Claude Code reads it, named by its
/// file (what `--agent` takes), with Kumo's settings. A file that can't be
/// read still lists, its text as the instructions, for Edit to show.
AgentDef agentDefFrom(pb.AgentDefFile f) {
  final scope = f.scope == pb.AgentDefScope.AGENT_DEF_SCOPE_PROJECT ? AgentScope.project : AgentScope.personal;
  final read = readAgentFile(f.markdown, scope: scope, repo: f.repoName, asWritten: true).agent;
  final agent = (read ?? AgentDef(name: f.name, instructions: f.markdown, scope: scope, repo: f.repoName)).copyWith(name: f.name);
  final s = f.settings;
  return agent.copyWith(
    repoPath: f.repoPath,
    maxMinutes: () => s.hasMaxMinutes() ? s.maxMinutes : null,
    maxCostUsd: () => s.hasMaxCostUsd() ? s.maxCostUsd : null,
    triggers: [
      for (final t in s.triggers)
        if (t == pb.AgentDefTrigger.AGENT_DEF_TRIGGER_SCHEDULE) AgentTrigger.schedule else AgentTrigger.pullRequest,
    ],
  );
}

/// [a] as the daemon saves it: its file and Kumo's settings.
pb.AgentDefFile agentDefFileTo(AgentDef a, {String repoPath = ''}) {
  final settings = pb.AgentDefSettings(
    triggers: [
      for (final t in a.triggers) t == AgentTrigger.schedule ? pb.AgentDefTrigger.AGENT_DEF_TRIGGER_SCHEDULE : pb.AgentDefTrigger.AGENT_DEF_TRIGGER_PULL_REQUEST,
    ],
  );
  if (a.maxMinutes != null) settings.maxMinutes = a.maxMinutes!;
  if (a.maxCostUsd != null) settings.maxCostUsd = a.maxCostUsd!;
  return pb.AgentDefFile(
    scope: a.scope == AgentScope.project ? pb.AgentDefScope.AGENT_DEF_SCOPE_PROJECT : pb.AgentDefScope.AGENT_DEF_SCOPE_PERSONAL,
    repoPath: repoPath,
    repoName: a.scope == AgentScope.project ? a.repo : '',
    name: a.name,
    markdown: a.toMarkdown(),
    settings: settings,
  );
}

/// How a test run ended, from its exit code (a result line may have said
/// it already).
PlayRun playEnded(PlayRun run, int code, {bool stopped = false}) {
  if (run.state != PlayState.running) return run;
  // 130: stopped; 124: its time limit.
  if (stopped || code == 130 || code == 124) return run.copyWith(state: PlayState.stopped);
  final name = AgentCli.of(run.cli)?.label ?? run.cli;
  return code == 0 ? run.copyWith(state: PlayState.done) : run.copyWith(state: PlayState.failed, error: '$name exited with code $code.');
}

/// A kept test run, its lines folded as they came.
PlayRun playRunFrom(pb.PlayRecord record, {required String agent}) {
  var run = PlayRun(
    id: record.playId,
    agent: agent,
    task: record.task,
    draft: record.draft,
    startedAt: DateTime.fromMillisecondsSinceEpoch(record.startedUnixMs.toInt()),
    // Kept before there were other CLIs: Claude Code.
    cli: record.providerId.isEmpty ? AgentCli.claude.id : record.providerId,
  );
  for (final e in record.events) {
    final at = Duration(milliseconds: e.atMs.toInt());
    if (e.hasLine()) run = foldPlayLine(run, e.line, at: at);
    if (e.hasExited()) run = playEnded(run, e.exited);
  }
  if (!record.running && run.state == PlayState.running) run = run.copyWith(state: PlayState.stopped);
  return run;
}
