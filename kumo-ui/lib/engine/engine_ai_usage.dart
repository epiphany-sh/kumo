import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

import '../data/agents_source.dart';
import '../data/ai_usage_source.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart' as pb;
import 'kumo_engine.dart';

/// Plan usage and session context over `Agents.Usage` / `Agents.Compact`:
/// read on start, every minute, and when an agent starts, ends or its turn
/// does.
class EngineAiUsage extends AiUsageSource {
  EngineAiUsage(this._engine, this._agents) {
    _agents.addListener(_agentsChanged);
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
    refresh();
  }

  final KumoEngine _engine;
  final AgentsSource _agents;
  late final Timer _timer;
  bool _disposed = false;
  bool _supported = true;
  String _runsKey = '';
  Map<String, AgentPlanUsage> _plans = const {};
  Map<String, AgentSessionUsage> _sessions = const {};
  DateTime? _updatedAt;

  @override
  bool get supported => _supported;
  @override
  DateTime? get updatedAt => _updatedAt;
  @override
  AgentPlanUsage? planOf(String providerId) => _plans[providerId];
  @override
  AgentSessionUsage? sessionOf(AgentRun run) => _sessions[run.id];

  /// Runs come and go, and a turn ends (working → needs input): that's
  /// when the numbers change. Last lines change every second: not those.
  void _agentsChanged() {
    final key = [for (final r in _agents.runs) '${r.id}:${r.status.name}'].join(',');
    if (key == _runsKey) return;
    _runsKey = key;
    // The CLIs report a moment after their turn ends.
    Future<void>.delayed(const Duration(seconds: 3), refresh);
  }

  @override
  Future<void> refresh() async {
    if (_disposed || !_supported) return;
    try {
      final report = await (await _engine.connection()).agents.usage(pb.UsageRequest());
      if (_disposed) return;
      _plans = {for (final p in report.plans) p.providerId: _plan(p)};
      _sessions = {for (final s in report.sessions) s.sessionId: _session(s)};
      final read = [for (final p in report.plans) p.readAt, for (final s in report.sessions) s.readAt];
      _updatedAt = read.isEmpty ? null : _time(read.reduce((a, b) => a > b ? a : b));
    } on GrpcError catch (e) {
      // A daemon from before Usage existed.
      if (e.code != StatusCode.unimplemented) return;
      _supported = false;
    } on Object {
      return; // Not connected yet: the next refresh tries again.
    }
    if (!_disposed) notifyListeners();
  }

  @override
  Future<bool> compact(AgentRun run) async {
    try {
      await (await _engine.connection()).agents.compact(pb.CompactAgentRequest(id: run.id));
    } on Object {
      return false;
    }
    Future<void>.delayed(const Duration(seconds: 3), refresh);
    return true;
  }

  static AgentPlanUsage _plan(pb.PlanUsage p) => AgentPlanUsage(
        providerId: p.providerId,
        plan: p.plan,
        windows: [
          for (final w in p.windows)
            UsageWindow(
              label: w.label,
              short: w.short,
              left: w.left,
              of: w.of,
              unit: switch (w.unit) {
                pb.UsageUnit.USAGE_UNIT_REQUESTS => UsageUnit.requests,
                pb.UsageUnit.USAGE_UNIT_DOLLARS => UsageUnit.dollars,
                _ => UsageUnit.percent,
              },
              resets: w.resetsAt <= Int64.ZERO ? null : _time(w.resetsAt),
            ),
        ],
        problem: p.problem.isEmpty ? null : p.problem,
      );

  static AgentSessionUsage _session(pb.SessionUsage s) => AgentSessionUsage(
        model: s.model,
        contextMax: s.contextMax.toInt(),
        turns: s.turns,
        compactCommand: s.compactCommand.isEmpty ? null : s.compactCommand,
        slices: [
          for (final x in s.slices)
            ContextSlice(
              switch (x.kind) {
                pb.ContextSliceKind.CONTEXT_SLICE_SYSTEM => ContextSliceKind.system,
                pb.ContextSliceKind.CONTEXT_SLICE_FILES => ContextSliceKind.files,
                pb.ContextSliceKind.CONTEXT_SLICE_CONVERSATION => ContextSliceKind.conversation,
                _ => ContextSliceKind.total,
              },
              x.tokens.toInt(),
            ),
        ],
      );

  static DateTime _time(Int64 unixMs) => DateTime.fromMillisecondsSinceEpoch(unixMs.toInt());

  @override
  void dispose() {
    _disposed = true;
    _timer.cancel();
    _agents.removeListener(_agentsChanged);
    super.dispose();
  }
}
