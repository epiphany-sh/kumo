import 'package:flutter/foundation.dart';

import 'agents_source.dart';

/// How a usage window counts.
enum UsageUnit {
  /// Claude Code and Codex report a share of a window.
  percent,

  /// Gemini CLI per day, Copilot premium requests per month.
  requests,

  /// An API key with a budget the user set.
  dollars,
}

/// One limit of a plan: a 5-hour session, a week, a day, a month.
@immutable
class UsageWindow {
  const UsageWindow({required this.label, required this.short, required this.left, this.of = 100, this.unit = UsageUnit.percent, this.resets});

  /// "5-hour session", "Weekly · all models", "Premium requests · October".
  final String label;

  /// For the sidebar row: 5h, wk, day, mo.
  final String short;

  /// What's left, in [unit]s ([of] = 100 for percent).
  final double left;
  final double of;
  final UsageUnit unit;

  /// When it starts over; null when the agent doesn't say.
  final DateTime? resets;

  double get fractionLeft => of <= 0 ? 0 : (left / of).clamp(0.0, 1.0).toDouble();
}

/// What's left on one agent's plan, as its CLI or account reports it.
@immutable
class AgentPlanUsage {
  const AgentPlanUsage({required this.providerId, required this.plan, this.windows = const [], this.problem, this.fix});

  /// [AgentProviderInfo.id].
  final String providerId;

  /// "Claude Max 5x", "ChatGPT Plus", "Free · Google account".
  final String plan;
  final List<UsageWindow> windows;

  /// Why it can't be read (sign-in expired…); [windows] is then empty.
  final String? problem;

  /// What fixes [problem], e.g. "Sign in again in Settings › AI agents".
  final String? fix;

  /// The window closest to its end.
  UsageWindow? get tightest => windows.isEmpty ? null : windows.reduce((a, b) => b.fractionLeft < a.fractionLeft ? b : a);
}

/// What fills an agent's context window. [total] when the agent reports
/// only how much, not what.
enum ContextSliceKind { total, system, files, conversation }

@immutable
class ContextSlice {
  const ContextSlice(this.kind, this.tokens);
  final ContextSliceKind kind;
  final int tokens;

  String get label => switch (kind) {
        ContextSliceKind.total => 'In context',
        ContextSliceKind.system => 'System & tools',
        ContextSliceKind.files => 'Files & docs',
        ContextSliceKind.conversation => 'Conversation',
      };
}

/// Something the agent has in its context, and about how much of it.
@immutable
class SessionContextItem {
  const SessionContextItem({required this.badge, required this.label, required this.tokens, this.detail = ''});
  final String badge;
  final String label;
  final int tokens;
  final String detail;
}

/// One running agent's session: its model, context window and what's in it.
@immutable
class AgentSessionUsage {
  const AgentSessionUsage({required this.model, required this.contextMax, this.slices = const [], this.items = const [], this.turns = 0, this.compactCommand});
  final String model;

  /// Tokens the window holds.
  final int contextMax;
  final List<ContextSlice> slices;
  final List<SessionContextItem> items;
  final int turns;

  /// What the agent's CLI calls compacting (/compact, /compress); null
  /// when it can't.
  final String? compactCommand;

  int get used => slices.fold(0, (n, s) => n + s.tokens);
  double get fractionUsed => contextMax <= 0 ? 0 : (used / contextMax).clamp(0.0, 1.0).toDouble();
}

/// Plan usage and session context of the coding agents. Optional, like the
/// agents: with nothing reported, the sidebar hides "AI usage" and the
/// Session widget shows what the agent was given.
abstract class AiUsageSource extends ChangeNotifier {
  /// Kumo can read usage at all (false: this daemon doesn't yet).
  bool get supported;

  /// When the numbers were last read.
  DateTime? get updatedAt;

  AgentPlanUsage? planOf(String providerId);
  AgentSessionUsage? sessionOf(AgentRun run);

  Future<void> refresh();

  /// Types the agent's own compact command into its terminal. False when
  /// it couldn't.
  Future<bool> compact(AgentRun run);
}

/// The daemon doesn't read agents' usage yet: nothing to show.
class NoAiUsage extends AiUsageSource {
  @override
  bool get supported => false;
  @override
  DateTime? get updatedAt => null;
  @override
  AgentPlanUsage? planOf(String providerId) => null;
  @override
  AgentSessionUsage? sessionOf(AgentRun run) => null;
  @override
  Future<void> refresh() async {}
  @override
  Future<bool> compact(AgentRun run) async => false;
}

/// The design canvas: Claude Code (Max 5x), Codex (ChatGPT Plus), Gemini
/// CLI (free) and Copilot (Pro), each counting its own way.
class MockAiUsageSource extends AiUsageSource {
  MockAiUsageSource({DateTime Function()? clock, Map<String, AgentPlanUsage>? plans}) : _clock = clock ?? DateTime.now {
    final now = _clock();
    _updatedAt = now.subtract(const Duration(minutes: 1));
    _plans = plans ?? designPlans(now);
  }

  final DateTime Function() _clock;
  late DateTime _updatedAt;
  late Map<String, AgentPlanUsage> _plans;
  final _compacted = <String>{};

  /// The plans of the design, with resets counted from [now].
  static Map<String, AgentPlanUsage> designPlans(DateTime now) {
    DateTime next(int weekday, int hour) {
      for (var i = 0; i < 8; i++) {
        final d = DateTime(now.year, now.month, now.day + i, hour);
        if (d.weekday == weekday && d.isAfter(now)) return d;
      }
      return DateTime(now.year, now.month, now.day + 7, hour);
    }

    return {
      'claude': AgentPlanUsage(providerId: 'claude', plan: 'Claude Max 5x', windows: [
        UsageWindow(label: '5-hour session', short: '5h', left: 38, resets: now.add(const Duration(hours: 1, minutes: 48))),
        UsageWindow(label: 'Weekly · all models', short: 'wk', left: 59, resets: next(DateTime.monday, 9)),
      ]),
      'codex': AgentPlanUsage(providerId: 'codex', plan: 'ChatGPT Plus', windows: [
        UsageWindow(label: '5-hour session', short: '5h', left: 82, resets: now.add(const Duration(hours: 3, minutes: 10))),
        UsageWindow(label: 'Weekly', short: 'wk', left: 17, resets: next(DateTime.saturday, 14)),
      ]),
      'gemini': AgentPlanUsage(providerId: 'gemini', plan: 'Free · Google account', windows: [
        UsageWindow(label: 'Requests today', short: 'day', left: 760, of: 1000, unit: UsageUnit.requests, resets: DateTime(now.year, now.month, now.day + 1)),
      ]),
      'copilot': AgentPlanUsage(providerId: 'copilot', plan: 'Copilot Pro', windows: [
        UsageWindow(label: 'Premium requests · this month', short: 'mo', left: 88, of: 300, unit: UsageUnit.requests, resets: DateTime(now.year, now.month + 1)),
      ]),
    };
  }

  static const _sessions = <String, AgentSessionUsage>{
    'claude': AgentSessionUsage(
      model: 'Opus',
      contextMax: 200000,
      turns: 46,
      compactCommand: '/compact',
      slices: [ContextSlice(ContextSliceKind.system, 21000), ContextSlice(ContextSliceKind.files, 51000), ContextSlice(ContextSliceKind.conversation, 46000)],
      items: [
        SessionContextItem(badge: 'JI', label: 'PRC-412 · Bulk discounts by category', tokens: 2400, detail: 'Jira ticket the agent started from'),
        SessionContextItem(badge: 'CF', label: 'Discount rules v3', tokens: 6100, detail: 'Confluence · Pricing › Engineering › Discounts'),
        SessionContextItem(badge: '{}', label: 'repository.go:20–26 · your note', tokens: 400, detail: 'Sent with Ask agent'),
        SessionContextItem(badge: '14', label: 'files read · internal/discount/…', tokens: 42100, detail: 'Files the agent opened in this session'),
      ],
    ),
    'codex': AgentSessionUsage(
      model: 'GPT-5-Codex',
      contextMax: 256000,
      turns: 12,
      compactCommand: '/compact',
      slices: [ContextSlice(ContextSliceKind.system, 12000), ContextSlice(ContextSliceKind.files, 38000), ContextSlice(ContextSliceKind.conversation, 22000)],
      items: [
        SessionContextItem(badge: 'JI', label: 'PRC-412 · Bulk discounts by category', tokens: 2400, detail: 'Jira ticket the agent started from'),
        SessionContextItem(badge: '9', label: 'files read · internal/discount/…', tokens: 35600, detail: 'Files the agent opened in this session'),
      ],
    ),
    'gemini': AgentSessionUsage(
      model: 'Gemini Pro',
      contextMax: 1000000,
      turns: 7,
      compactCommand: '/compress',
      slices: [ContextSlice(ContextSliceKind.system, 14000), ContextSlice(ContextSliceKind.files, 120000), ContextSlice(ContextSliceKind.conversation, 18000)],
      items: [SessionContextItem(badge: '22', label: 'files read · internal/…', tokens: 120000, detail: 'Files the agent opened in this session')],
    ),
  };

  @override
  bool get supported => true;
  @override
  DateTime? get updatedAt => _updatedAt;
  @override
  AgentPlanUsage? planOf(String providerId) => _plans[providerId];

  @override
  AgentSessionUsage? sessionOf(AgentRun run) {
    final s = _sessions[run.providerId];
    if (s == null || !_compacted.contains(run.id)) return s;
    // Older turns become a short summary.
    return AgentSessionUsage(
      model: s.model,
      contextMax: s.contextMax,
      turns: s.turns,
      compactCommand: s.compactCommand,
      items: s.items,
      slices: [for (final x in s.slices) x.kind == ContextSliceKind.conversation ? ContextSlice(x.kind, (x.tokens * 0.18).round()) : x],
    );
  }

  @override
  Future<void> refresh() async {
    _updatedAt = _clock();
    notifyListeners();
  }

  @override
  Future<bool> compact(AgentRun run) async {
    if (_sessions[run.providerId]?.compactCommand == null) return false;
    _compacted.add(run.id);
    notifyListeners();
    return true;
  }
}
