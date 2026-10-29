import 'dart:async';

import 'package:grpc/grpc.dart';

import '../data/agents_source.dart';
import '../data/models.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart' as pb;
import 'kumo_engine.dart';

/// Agents as `kumod` runs them: providers on request, sessions streamed
/// (`Agents.Watch`).
class EngineAgentsSource extends AgentsSource {
  EngineAgentsSource(this._engine) {
    _watch();
  }

  final KumoEngine _engine;
  bool _disposed = false;
  List<AgentProviderInfo> _providers = const [];
  List<AgentRun> _runs = const [];
  String? _error;
  final _ready = Completer<void>();

  @override
  Future<void> get ready => _ready.future;

  @override
  bool get live => true;
  @override
  List<AgentProviderInfo> get providers => _providers;
  @override
  List<AgentRun> get runs => _runs;
  @override
  String? get error => _error;

  Future<pb.AgentsClient> get _client async => (await _engine.connection()).agents;

  Future<void> _watch() async {
    while (!_disposed) {
      try {
        await for (final snapshot in (await _client).watch(pb.WatchAgentsRequest())) {
          if (_disposed) return;
          _runs = [for (final s in snapshot.sessions) _run(s)];
          if (!_ready.isCompleted) _ready.complete();
          notifyListeners();
        }
      } on Object catch (e) {
        if (_disposed) return;
        _fail(e);
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  void _fail(Object error) {
    _error = _message(error);
    if (!_disposed) notifyListeners();
  }

  static String _message(Object error) => error is GrpcError ? (error.message ?? error.codeName) : '$error';

  /// Runs a call; on failure keeps the message in [error] and returns null.
  Future<T?> _call<T>(Future<T> Function(pb.AgentsClient client) call) async {
    try {
      _error = null;
      return await call(await _client);
    } on Object catch (e) {
      _fail(e);
      return null;
    }
  }

  @override
  Future<void> loadProviders() async {
    final list = await _call((c) => c.listProviders(pb.ListProvidersRequest()));
    if (list == null || _disposed) return;
    _providers = [for (final p in list.providers) _provider(p)];
    notifyListeners();
  }

  @override
  Future<AgentProviderInfo?> saveProvider({String? id, required String name, required String program, String args = '', required bool enabled, bool isDefault = false}) async {
    final saved = await _call((c) => c.saveProvider(pb.SaveProviderRequest(
          id: id ?? '',
          name: name,
          program: program,
          args: args,
          enabled: enabled,
          isDefault: isDefault,
        )));
    // The default may move: reload the whole list.
    await loadProviders();
    return saved == null ? null : _provider(saved);
  }

  @override
  Future<void> deleteProvider(String id) async {
    await _call((c) => c.deleteProvider(pb.DeleteProviderRequest(id: id)));
    await loadProviders();
  }

  @override
  Future<String> test(String id) async {
    try {
      return (await (await _client).testProvider(pb.TestProviderRequest(id: id))).version;
    } on Object catch (e) {
      throw _message(e);
    }
  }

  @override
  Future<String?> login(String id) async => (await _call((c) => c.loginProvider(pb.LoginProviderRequest(id: id))))?.terminalId;

  @override
  Future<AgentRun?> start({String? providerId, required String worktreePath, String prompt = '', String title = '', List<AgentContextItem> context = const []}) async {
    final session = await _call((c) => c.start(pb.StartAgentRequest(
          providerId: providerId ?? '',
          worktreePath: worktreePath,
          prompt: prompt,
          title: title,
          cols: 120,
          rows: 40,
          context: [for (final item in context) _contextTo(item)],
        )));
    return session == null ? null : _run(session);
  }

  @override
  Future<bool> addContext(String id, AgentContextItem item, {String text = ''}) async {
    final session = await _call((c) => c.addContext(pb.AddAgentContextRequest(id: id, context: _contextTo(item), text: text)));
    return session != null;
  }

  static pb.AgentContext _contextTo(AgentContextItem item) => pb.AgentContext(
        kind: item.kind == AgentContextKind.doc ? pb.AgentContextKind.AGENT_CONTEXT_KIND_DOC : pb.AgentContextKind.AGENT_CONTEXT_KIND_TASK,
        title: item.title,
        detail: item.detail,
        url: item.url,
      );

  @override
  Future<void> stop(String id) => _call((c) => c.stop(pb.StopAgentRequest(id: id)));

  @override
  Future<void> dismiss(String id) => _call((c) => c.dismiss(pb.DismissAgentRequest(id: id)));

  static AgentProviderInfo _provider(pb.AgentProvider p) => AgentProviderInfo(
        id: p.id,
        name: p.name,
        short: p.short,
        program: p.program,
        args: p.args,
        custom: p.custom,
        enabled: p.enabled,
        isDefault: p.isDefault,
        installed: p.installed,
        resolvedPath: p.resolvedPath,
        installHint: p.installHint,
        takesPrompt: p.takesPromptArgument,
        hasLogin: p.hasLogin,
      );

  static AgentRun _run(pb.AgentSession s) => AgentRun(
        id: s.id,
        providerId: s.providerId,
        providerName: s.providerName,
        short: s.short,
        worktreePath: s.worktreePath,
        terminalId: s.terminalId,
        title: s.title,
        prompt: s.prompt,
        status: switch (s.state) {
          pb.AgentState.AGENT_STATE_NEEDS_INPUT => AgentStatus.needsYou,
          pb.AgentState.AGENT_STATE_EXITED => AgentStatus.done,
          _ => AgentStatus.running,
        },
        exitCode: s.exitCode,
        startedAt: DateTime.fromMillisecondsSinceEpoch(s.startedUnixMs.toInt()),
        lastLine: s.lastLine,
        context: [
          for (final item in s.context)
            AgentContextItem(
              kind: item.kind == pb.AgentContextKind.AGENT_CONTEXT_KIND_DOC ? AgentContextKind.doc : AgentContextKind.task,
              title: item.title,
              detail: item.detail,
              url: item.url,
            ),
        ],
        steps: [for (final e in s.events) agentStepFrom(e)],
      );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

AgentStep agentStepFrom(pb.AgentEvent e) => AgentStep(
      at: DateTime.fromMillisecondsSinceEpoch(e.atUnixMs.toInt()),
      kind: switch (e.kind) {
        pb.AgentEventKind.AGENT_EVENT_KIND_EDITED => AgentStepKind.edited,
        pb.AgentEventKind.AGENT_EVENT_KIND_RAN => AgentStepKind.ran,
        pb.AgentEventKind.AGENT_EVENT_KIND_READ => AgentStepKind.read,
        pb.AgentEventKind.AGENT_EVENT_KIND_SEARCHED => AgentStepKind.searched,
        pb.AgentEventKind.AGENT_EVENT_KIND_TOOL => AgentStepKind.tool,
        pb.AgentEventKind.AGENT_EVENT_KIND_WAITING => AgentStepKind.waiting,
        pb.AgentEventKind.AGENT_EVENT_KIND_CONTEXT => AgentStepKind.context,
        pb.AgentEventKind.AGENT_EVENT_KIND_EXITED => AgentStepKind.exited,
        _ => AgentStepKind.started,
      },
      text: e.text,
    );
