import 'package:flutter/foundation.dart';

import 'models.dart';

/// A coding-agent CLI the user can run (known or custom).
@immutable
class AgentProviderInfo {
  const AgentProviderInfo({
    required this.id,
    required this.name,
    required this.short,
    required this.program,
    this.args = '',
    this.custom = false,
    this.enabled = false,
    this.isDefault = false,
    this.installed = false,
    this.resolvedPath = '',
    this.installHint = '',
    this.takesPrompt = false,
    this.hasLogin = false,
  });

  final String id;
  final String name;

  /// Two-letter badge.
  final String short;
  final String program;

  /// Extra arguments, shell-quoted.
  final String args;
  final bool custom;

  /// Connected: offered by "New agent".
  final bool enabled;
  final bool isDefault;

  /// Found on the user's PATH.
  final bool installed;
  final String resolvedPath;
  final String installHint;

  /// The prompt goes as an argument; otherwise Kumo types it in.
  final bool takesPrompt;
  final bool hasLogin;
}

enum AgentContextKind { task, doc, code }

/// A ticket, page or piece of code an agent was given.
@immutable
class AgentContextItem {
  const AgentContextItem({required this.kind, required this.title, this.detail = '', this.url = ''});
  final AgentContextKind kind;

  /// e.g. "PRC-412 · Bulk discounts by category".
  final String title;

  /// Where it lives, e.g. "Jira" or "Confluence · Pricing".
  final String detail;
  final String url;

  @override
  bool operator ==(Object other) =>
      other is AgentContextItem && other.kind == kind && other.title == title && other.detail == detail && other.url == url;

  @override
  int get hashCode => Object.hash(kind, title, detail, url);
}

enum AgentStepKind {
  started,
  edited,
  ran,
  read,
  searched,

  /// Another tool, named in the text.
  tool,

  /// Its turn ended; the text is what it said last.
  waiting,

  /// It was sent a ticket or page (the text is its title).
  context,

  /// The process ended; the text says how.
  exited,
}

/// One step of an agent's timeline, as the daemon read it from its terminal.
@immutable
class AgentStep {
  const AgentStep({required this.at, required this.kind, this.text = ''});
  final DateTime at;
  final AgentStepKind kind;
  final String text;
}

/// An agent running (or that ran) in a worktree.
@immutable
class AgentRun {
  const AgentRun({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.short,
    required this.worktreePath,
    required this.terminalId,
    required this.title,
    required this.status,
    required this.startedAt,
    this.prompt = '',
    this.exitCode = 0,
    this.lastLine = '',
    this.context = const [],
    this.steps = const [],
  });

  final String id;
  final String providerId;
  final String providerName;
  final String short;
  final String worktreePath;
  final String terminalId;
  final String title;
  final String prompt;
  final AgentStatus status;
  final int exitCode;
  final DateTime startedAt;
  final String lastLine;

  /// What it was given to work from, in the order it got it.
  final List<AgentContextItem> context;

  /// What it did, oldest first.
  final List<AgentStep> steps;
}

/// Coding agents: the providers the user connected in Settings and the
/// sessions running in worktrees. Optional: with none connected, the rest
/// of Kumo works the same.
abstract class AgentsSource extends ChangeNotifier {
  /// Backed by the daemon (false: design mocks).
  bool get live;

  List<AgentProviderInfo> get providers;

  /// Connected providers, the default first.
  List<AgentProviderInfo> get connected =>
      [for (final p in providers) if (p.enabled && p.isDefault) p, for (final p in providers) if (p.enabled && !p.isDefault) p];

  /// Re-reads providers (and whether they are installed).
  Future<void> loadProviders();

  /// Creates (no [id]: a custom agent) or updates a provider.
  Future<AgentProviderInfo?> saveProvider({String? id, required String name, required String program, String args = '', required bool enabled, bool isDefault = false});

  Future<void> deleteProvider(String id);

  /// The CLI's version; throws a readable message when it doesn't answer.
  Future<String> test(String id);

  /// Starts the CLI's own sign-in in a terminal; returns its terminal id.
  Future<String?> login(String id);

  List<AgentRun> get runs;

  /// Starts an agent ([providerId] null: the default one) in a worktree.
  /// [context] is what the prompt hands it (a ticket, a page).
  Future<AgentRun?> start({String? providerId, required String worktreePath, String prompt = '', String title = '', List<AgentContextItem> context = const []});

  /// Sends [item] to a running agent: [text] is typed into its terminal and
  /// submitted. False when it couldn't be sent ([error] says why).
  Future<bool> addContext(String id, AgentContextItem item, {String text = ''});

  Future<void> stop(String id);
  Future<void> dismiss(String id);

  /// Last failure reported by the daemon, readable.
  String? get error;

  /// Completes once [runs] reflects the daemon (or right away for mocks).
  Future<void> get ready;
}

/// The design canvas: Claude Code, Codex and Gemini connected, Aider not
/// installed. No real sessions (the Agents view shows its own mock).
class MockAgentsSource extends AgentsSource {
  List<AgentProviderInfo> _providers = const [
    AgentProviderInfo(id: 'claude', name: 'Claude Code', short: 'CC', program: 'claude', enabled: true, isDefault: true, installed: true, takesPrompt: true, hasLogin: true),
    AgentProviderInfo(id: 'codex', name: 'Codex CLI', short: 'CX', program: 'codex', enabled: true, installed: true, takesPrompt: true, hasLogin: true),
    AgentProviderInfo(id: 'gemini', name: 'Gemini CLI', short: 'GM', program: 'gemini', enabled: true, installed: true, takesPrompt: true, hasLogin: true),
    AgentProviderInfo(id: 'aider', name: 'Aider', short: 'AD', program: 'aider', installHint: 'brew install aider', hasLogin: true),
  ];

  @override
  bool get live => false;
  @override
  List<AgentProviderInfo> get providers => _providers;
  @override
  Future<void> loadProviders() async {}

  @override
  Future<AgentProviderInfo?> saveProvider({String? id, required String name, required String program, String args = '', required bool enabled, bool isDefault = false}) async {
    final current = _providers.where((p) => p.id == id).firstOrNull;
    final saved = AgentProviderInfo(
      id: id ?? 'custom-${_providers.length}',
      name: current?.name ?? name,
      short: current?.short ?? name.substring(0, name.length < 2 ? name.length : 2).toUpperCase(),
      program: program,
      args: args,
      custom: current?.custom ?? true,
      enabled: enabled,
      isDefault: isDefault && enabled,
      installed: current?.installed ?? true,
      installHint: current?.installHint ?? '',
      takesPrompt: current?.takesPrompt ?? args.contains('{prompt}'),
      hasLogin: current?.hasLogin ?? false,
    );
    _providers = [
      for (final p in _providers)
        if (p.id == saved.id) saved else if (saved.isDefault && p.isDefault) _withoutDefault(p) else p,
      if (current == null) saved,
    ];
    notifyListeners();
    return saved;
  }

  static AgentProviderInfo _withoutDefault(AgentProviderInfo p) => AgentProviderInfo(
        id: p.id, name: p.name, short: p.short, program: p.program, args: p.args, custom: p.custom, enabled: p.enabled,
        installed: p.installed, resolvedPath: p.resolvedPath, installHint: p.installHint, takesPrompt: p.takesPrompt, hasLogin: p.hasLogin,
      );

  @override
  Future<void> deleteProvider(String id) async {
    _providers = [for (final p in _providers) if (p.id != id) p];
    notifyListeners();
  }

  @override
  Future<String> test(String id) async => '${_providers.firstWhere((p) => p.id == id).program} responded · signed in';

  @override
  Future<String?> login(String id) async => null;

  @override
  List<AgentRun> get runs => const [];

  @override
  Future<AgentRun?> start({String? providerId, required String worktreePath, String prompt = '', String title = '', List<AgentContextItem> context = const []}) async => null;

  @override
  Future<bool> addContext(String id, AgentContextItem item, {String text = ''}) async => false;

  @override
  Future<void> stop(String id) async {}
  @override
  Future<void> dismiss(String id) async {}
  @override
  String? get error => null;
  @override
  Future<void> get ready async {}
}
