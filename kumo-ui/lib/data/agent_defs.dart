/// Agents of your own: Claude Code subagents (`.claude/agents/<name>.md`),
/// as Kumo reads, checks and writes them. Pure: no I/O, so the file format,
/// the checks and the commands can be tested as text.
///
/// Only Claude Code: other CLIs have no subagent format Kumo could write.
library;

import 'dart:convert';

import 'package:yaml/yaml.dart';

import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Fields
// ---------------------------------------------------------------------------

/// Who can use it, and so where its file lives.
enum AgentScope {
  /// The workspace's Claude Code folder: only you, in every repository.
  personal('Personal', 'Only you, in every repo of this workspace.'),

  /// `<repo>/.claude/agents`: everyone who clones the repository.
  project('Project', 'Everyone who clones the repo. Git shows it as a change to commit.');

  const AgentScope(this.label, this.hint);
  final String label;
  final String hint;
}

/// What it asks you before doing (Claude Code's `permissionMode`). Kumo
/// doesn't offer `bypassPermissions`.
enum AgentApprovals {
  ask('default', 'Ask first', 'Asks before each edit and command its tools allow.'),
  plan('plan', 'Plan only', 'Reads and proposes; changes nothing.'),
  acceptEdits('acceptEdits', 'Edits without asking', 'Still asks before commands.'),
  dontAsk('dontAsk', 'Never ask', 'Denies whatever isn’t allowed instead of asking. For triggers.'),

  /// Only as a file says it: never offered, and an import comes in asking.
  bypass('bypassPermissions', 'Skips every approval', 'As its file says: runs everything without asking.');

  const AgentApprovals(this.key, this.label, this.hint);

  /// The value in the file.
  final String key;
  final String label;
  final String hint;

  static AgentApprovals? of(String key) => values.where((v) => v.key == key).firstOrNull;
}

/// What it keeps between runs (Claude Code's `memory`).
enum AgentMemory {
  none('', 'None', 'Starts fresh every run.'),
  project('project', 'This project', 'In the repo, shared through git.'),
  local('local', 'This computer', 'In the repo, not in git.'),
  user('user', 'Personal', 'In this workspace, for every repo.');

  const AgentMemory(this.key, this.label, this.hint);
  final String key;
  final String label;
  final String hint;

  static AgentMemory of(String key) => values.where((v) => v.key == key).firstOrNull ?? none;
}

/// How it reports back: free, or a template written into its instructions.
enum AgentOutput {
  free('Free', ''),
  markdown('Markdown template', '## Summary\n\n## Findings\n- file:line · what · why\n\n## Not checked'),
  json('JSON', '[{ "file": "", "line": 0, "finding": "", "fix": "" }]');

  const AgentOutput(this.label, this.template);
  final String label;

  /// What a new one starts with.
  final String template;
}

/// When it runs on its own (headless, in its own worktree). Kumo's, not a
/// subagent field.
enum AgentTrigger {
  pullRequest('When a pull request opens'),
  schedule('On a schedule');

  const AgentTrigger(this.label);
  final String label;
}

/// The models Kumo offers; `inherit` uses the session's.
const agentModels = <(String, String, String)>[
  ('inherit', 'Inherit', 'Whatever the session uses.'),
  ('haiku', 'Haiku', 'Fastest and cheapest: narrow, repetitive work.'),
  ('sonnet', 'Sonnet', 'Balanced: most agents.'),
  ('opus', 'Opus', 'Strongest on hard reasoning, and the most expensive.'),
];

String agentModelLabel(String model) => agentModels.where((m) => m.$1 == model).firstOrNull?.$2 ?? model;

/// Claude Code's subagent colors.
const agentColors = ['red', 'blue', 'green', 'yellow', 'purple', 'orange', 'pink', 'cyan'];

// ---------------------------------------------------------------------------
// Tools
// ---------------------------------------------------------------------------

/// How much a set of tools can do, from least to most.
enum AgentRisk { none, read, web, edits, commands }

/// The tools Kumo offers, in groups; anything else in a file is kept.
const agentToolGroups = <(String, AgentRisk, List<(String, String)>, String)>[
  ('Read and search', AgentRisk.read, [('Read', 'Read files'), ('Grep', 'Search file contents'), ('Glob', 'Find files by name')], 'Can’t change anything.'),
  ('Web', AgentRisk.web, [('WebFetch', 'Read a page'), ('WebSearch', 'Search the web')], 'What it searches for leaves your computer.'),
  ('Change files', AgentRisk.edits, [('Edit', 'Change a file'), ('Write', 'Create or replace a file')], 'Changes files where it runs.'),
  ('Run commands', AgentRisk.commands, [('Bash', 'Any shell command')], 'Anything you can run: tests and git, but also rm.'),
];

const readOnlyTools = ['Read', 'Grep', 'Glob'];

/// What a file with no tools line has, as far as Kumo shows it: everything.
const everyAgentTool = ['Read', 'Grep', 'Glob', 'Edit', 'Write', 'Bash', 'WebFetch', 'WebSearch'];

bool _edits(String t) => t == 'Edit' || t == 'Write' || t == 'MultiEdit' || t == 'NotebookEdit';

/// What [tools] let it do: the riskiest thing, and how to say it.
(AgentRisk, String) agentToolsKind(List<String> tools) {
  final bash = tools.contains('Bash');
  final edits = tools.any(_edits);
  if (bash) return (AgentRisk.commands, edits ? 'edits + commands' : 'runs commands');
  if (edits) return (AgentRisk.edits, 'edits files');
  if (tools.any((t) => t == 'WebFetch' || t == 'WebSearch')) return (AgentRisk.web, 'read + web');
  if (tools.isEmpty) return (AgentRisk.none, 'no tools');
  return (AgentRisk.read, 'read-only');
}

/// It can change things: files, or anything through a shell.
bool agentWrites(List<String> tools) => tools.contains('Bash') || tools.any(_edits);

// ---------------------------------------------------------------------------
// The agent
// ---------------------------------------------------------------------------

/// One agent: what its file says, plus Kumo's own settings for it (time and
/// cost limits, triggers), which aren't subagent fields.
@immutable
class AgentDef {
  const AgentDef({
    required this.name,
    this.description = '',
    this.instructions = '',
    this.tools = readOnlyTools,
    this.model = 'inherit',
    this.approvals = AgentApprovals.ask,
    this.maxTurns,
    this.skills = const [],
    this.mcpServers = const [],
    this.memory = AgentMemory.none,
    this.isolation = false,
    this.color = 'cyan',
    this.knowledge = const [],
    this.output = AgentOutput.free,
    this.outputTemplate = '',
    this.extra = const [],
    this.scope = AgentScope.personal,
    this.repo = '',
    this.maxMinutes,
    this.everyTool = false,
    this.repoPath = '',
    this.maxCostUsd,
    this.triggers = const [],
  });

  final String name;

  /// When to use it: what Claude reads to decide whether to delegate.
  final String description;

  /// Its system prompt: role, what it does and doesn't, how.
  final String instructions;
  final List<String> tools;

  /// `inherit`, `haiku`, `sonnet`, `opus` or a full model id.
  final String model;
  final AgentApprovals approvals;

  /// Claude Code's `maxTurns`; null: no limit, the default (a task cut
  /// short by a guess costs more than letting it finish: Stop is at hand).
  final int? maxTurns;
  final List<String> skills;
  final List<String> mcpServers;
  final AgentMemory memory;

  /// Claude Code's `isolation: worktree`: a fresh worktree each run.
  final bool isolation;
  final String color;

  /// Files read before every run, written into the instructions under
  /// "## Read first" (so they hold when another agent calls it too).
  final List<String> knowledge;
  final AgentOutput output;

  /// The report's shape, written under "## Report like this".
  final String outputTemplate;

  /// Frontmatter Kumo doesn't edit (hooks, effort…), kept as written.
  final List<(String, String)> extra;
  final AgentScope scope;

  /// The repository of a project agent.
  final String repo;

  /// Kumo ends the run when it's up; null: no limit.
  final int? maxMinutes;

  /// Its file has no tools line: every tool, so none is written either.
  final bool everyTool;

  /// The main checkout of [repo], when known: names aren't unique.
  final String repoPath;

  /// For headless runs (playground, triggers); null: no limit.
  final double? maxCostUsd;
  final List<AgentTrigger> triggers;

  /// Where it's saved: `<repo>/.claude/agents/<name>.md`, or the
  /// workspace's `agents/<name>.md`.
  String get file => scope == AgentScope.project ? '$repo/.claude/agents/$name.md' : 'agents/$name.md';

  /// The same agent, wherever it's saved.
  String get key => '${scope.name}:${scope == AgentScope.project ? (repoPath.isEmpty ? repo : repoPath) : ''}:$name';

  AgentDef copyWith({
    String? name,
    String? description,
    String? instructions,
    List<String>? tools,
    String? model,
    AgentApprovals? approvals,
    int? Function()? maxTurns,
    List<String>? skills,
    List<String>? mcpServers,
    AgentMemory? memory,
    bool? isolation,
    String? color,
    List<String>? knowledge,
    AgentOutput? output,
    String? outputTemplate,
    List<(String, String)>? extra,
    AgentScope? scope,
    String? repo,
    int? Function()? maxMinutes,
    String? repoPath,
    double? Function()? maxCostUsd,
    List<AgentTrigger>? triggers,
  }) =>
      AgentDef(
        name: name ?? this.name,
        description: description ?? this.description,
        instructions: instructions ?? this.instructions,
        tools: tools ?? this.tools,
        model: model ?? this.model,
        approvals: approvals ?? this.approvals,
        maxTurns: maxTurns == null ? this.maxTurns : maxTurns(),
        skills: skills ?? this.skills,
        mcpServers: mcpServers ?? this.mcpServers,
        memory: memory ?? this.memory,
        isolation: isolation ?? this.isolation,
        color: color ?? this.color,
        knowledge: knowledge ?? this.knowledge,
        output: output ?? this.output,
        outputTemplate: outputTemplate ?? this.outputTemplate,
        extra: extra ?? this.extra,
        scope: scope ?? this.scope,
        repo: repo ?? this.repo,
        maxMinutes: maxMinutes == null ? this.maxMinutes : maxMinutes(),
        everyTool: tools == null && everyTool,
        repoPath: repoPath ?? this.repoPath,
        maxCostUsd: maxCostUsd == null ? this.maxCostUsd : maxCostUsd(),
        triggers: triggers ?? this.triggers,
      );

  /// The whole agent as text, to compare drafts with what's saved.
  String get fingerprint => jsonEncode([
        name, description, instructions, tools, model, approvals.key, maxTurns, skills, mcpServers, memory.key, isolation, color, knowledge,
        output.name, outputTemplate, [for (final (k, v) in extra) '$k=$v'], scope.name, repo, repoPath, everyTool, maxMinutes, maxCostUsd, [for (final t in triggers) t.name],
      ]);

  @override
  bool operator ==(Object other) => other is AgentDef && other.fingerprint == fingerprint;

  @override
  int get hashCode => fingerprint.hashCode;

  /// The file Claude Code reads: frontmatter, then the instructions, with
  /// the knowledge and the report's shape as sections of their own.
  String toMarkdown() {
    String one(String s) => s.replaceAll('\n', ' ').trim();
    final fm = <(String, String)>[
      ('name', name),
      ('description', one(description)),
      if (!everyTool) ('tools', [...tools, for (final m in mcpServers) 'mcp__$m'].join(', ')),
      ('model', model),
      if (approvals != AgentApprovals.ask) ('permissionMode', approvals.key),
      if (maxTurns != null) ('maxTurns', '$maxTurns'),
      if (skills.isNotEmpty) ('skills', skills.join(', ')),
      if (mcpServers.isNotEmpty) ('mcpServers', mcpServers.join(', ')),
      if (memory != AgentMemory.none) ('memory', memory.key),
      if (isolation) ('isolation', 'worktree'),
      ('color', color),
      ...extra,
    ];
    final body = StringBuffer(instructions.trim());
    if (knowledge.isNotEmpty) {
      body.write('\n\n$_readFirst\n');
      body.write(knowledge.map((k) => '- $k').join('\n'));
    }
    if (output != AgentOutput.free && outputTemplate.trim().isNotEmpty) {
      body.write('\n\n$_reportLike\n');
      body.write(output == AgentOutput.json ? '```json\n${outputTemplate.trim()}\n```' : outputTemplate.trim());
    }
    final own = fm.length - extra.length;
    return [
      '---',
      // Kumo's values quoted when YAML needs it; the rest exactly as they came.
      for (final (i, (k, v)) in fm.indexed) i < own ? '$k: ${_yaml(v)}' : (v.startsWith('\n') ? '$k:$v' : '$k: $v'),
      '---',
      '',
      body.toString().trim(),
      '',
    ].join('\n');
  }
}

/// [v] as a YAML value: plain, unless YAML would read it as something else.
String _yaml(String v) {
  final plain = v.isNotEmpty &&
      !RegExp(r'''^[\[\]{}"'#*&!|>%@`,?:\-\s]''').hasMatch(v) &&
      !v.contains(': ') &&
      !v.contains(' #') &&
      !v.endsWith(' ') &&
      !RegExp(r'^(true|false|null|yes|no|on|off|~)$', caseSensitive: false).hasMatch(v);
  return plain ? v : jsonEncode(v);
}

const _readFirst = '## Read first';
const _reportLike = '## Report like this';

/// The frontmatter fields Kumo edits; the rest go to [AgentDef.extra].
const _known = {'name', 'description', 'tools', 'model', 'permissionMode', 'maxTurns', 'skills', 'mcpServers', 'memory', 'isolation', 'color'};

/// A name Claude Code takes: lowercase letters, digits and hyphens.
String agentSlug(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]+'), '-').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');

bool isAgentName(String name) => RegExp(r'^[a-z][a-z0-9]*(-[a-z0-9]+)*$').hasMatch(name);

// ---------------------------------------------------------------------------
// Reading a file
// ---------------------------------------------------------------------------

/// How serious a check is.
enum CheckLevel { ok, info, warn, error }

@immutable
class AgentCheck {
  const AgentCheck(this.level, this.text);
  final CheckLevel level;
  final String text;

  @override
  bool operator ==(Object other) => other is AgentCheck && other.level == level && other.text == text;

  @override
  int get hashCode => Object.hash(level, text);

  @override
  String toString() => '${level.name}: $text';
}

/// What Kumo read in an agent file: the agent (null when it can't be one)
/// and what to tell you about it.
@immutable
class AgentFileRead {
  const AgentFileRead(this.agent, this.checks);
  final AgentDef? agent;
  final List<AgentCheck> checks;

  /// It can come in (to be checked in Edit before it's saved).
  bool get usable => agent != null && !checks.any((c) => c.level == CheckLevel.error);
}

/// Reads an agent file ([text]: frontmatter between `---` lines, then the
/// instructions). [taken] are the names already used where it would go: a
/// clash comes in as `<name>-2`. Without a `tools` line (every tool, in
/// Claude Code) it comes in read-only.
///
/// [asWritten] is for a file already in use (listing): it shows what the file
/// really grants. Without it (an import) it comes in safer than it was.
AgentFileRead readAgentFile(String text, {AgentScope scope = AgentScope.personal, String repo = '', Set<String> taken = const {}, bool asWritten = false}) {
  final t = text.replaceAll('\r\n', '\n').trim();
  if (t.isEmpty) return const AgentFileRead(null, []);
  final m = RegExp(r'^---\n([\s\S]*?)\n---[ \t]*(?:\n([\s\S]*))?$').firstMatch(t);
  if (m == null) {
    return const AgentFileRead(null, [AgentCheck(CheckLevel.error, 'No frontmatter: an agent file starts with name, description and tools between two --- lines.')]);
  }
  final fields = <String, String>{};
  final order = <String>[];
  // Keys Kumo doesn't edit, exactly as written (nested lines included).
  final raw = <String, List<String>>{};
  String? last;
  for (final line in m.group(1)!.split('\n')) {
    final kv = RegExp(r'^([A-Za-z][\w-]*):\s*(.*)$').firstMatch(line);
    if (kv != null) {
      last = kv.group(1)!;
      fields[last] = _unquote(kv.group(2)!.trim());
      order.add(last);
      raw[last] = [kv.group(2)!];
      continue;
    }
    if (last != null) raw[last]!.add(line);
    if (last != null && !_known.contains(last)) continue;
    final item = RegExp(r'^\s*-\s*(.+)$').firstMatch(line);
    if (item != null && last != null) {
      fields[last] = [if (fields[last]!.isNotEmpty) fields[last]!, _unquote(item.group(1)!.trim())].join(', ');
    } else if (last != null && line.trim().isNotEmpty) {
      // A folded value: keep it on one line.
      fields[last] = '${fields[last]} ${line.trim()}'.trim();
    }
  }
  List<String> list(String? v) => v == null ? const [] : [for (final p in v.replaceAll(RegExp(r'^\[|\]$'), '').split(',')) if (p.trim().isNotEmpty) _unquote(p.trim())];

  final checks = <AgentCheck>[];
  final rawName = fields['name'] ?? '';
  var name = agentSlug(rawName);
  if (rawName.isEmpty) {
    checks.add(const AgentCheck(CheckLevel.error, 'It has no name.'));
  } else if (name.isEmpty) {
    checks.add(AgentCheck(CheckLevel.error, '“$rawName” can’t be made into a name.'));
  } else if (name != rawName) {
    checks.add(AgentCheck(CheckLevel.warn, '“$rawName” isn’t a valid name: it’s saved as $name.'));
  }
  if (name.isNotEmpty && taken.contains(name)) {
    var n = 2;
    while (taken.contains('$name-$n')) {
      n++;
    }
    checks.add(AgentCheck(CheckLevel.warn, '$name already exists in ${scope == AgentScope.project ? repo : 'Personal'}: it comes in as $name-$n. Rename it in Edit if you like.'));
    name = '$name-$n';
  }
  final description = fields['description'] ?? '';
  if (description.isEmpty) checks.add(const AgentCheck(CheckLevel.error, 'It has no description, and Claude Code needs one.'));

  final allTools = list(fields['tools']);
  final mcpFromTools = [for (final t in allTools) if (t.startsWith('mcp__')) t.substring(5).split('__').first];
  var tools = [for (final t in allTools) if (!t.startsWith('mcp__')) t];
  if (!fields.containsKey('tools')) {
    checks.add(const AgentCheck(CheckLevel.warn, 'No tools line: in Claude Code that means every tool. It comes in read-only; give it more in Edit.'));
    tools = asWritten ? everyAgentTool : readOnlyTools;
  } else {
    final writes = agentWrites(tools);
    checks.add(AgentCheck(writes ? CheckLevel.warn : CheckLevel.ok, 'Tools: ${allTools.join(', ')}.${writes ? ' It can change things: check its approvals in Edit.' : ''}'));
  }
  if (fields['permissionMode'] == 'bypassPermissions') {
    checks.add(const AgentCheck(CheckLevel.warn, 'It skipped every approval (bypassPermissions): it comes in asking first.'));
  }
  final extraKeys = [for (final k in order) if (!_known.contains(k)) k];
  if (extraKeys.isNotEmpty) checks.add(AgentCheck(CheckLevel.info, 'Kept as written, though Kumo doesn’t edit them: ${extraKeys.join(', ')}.'));

  // The sections Kumo writes come back as fields.
  var body = (m.group(2) ?? '').trim();
  var knowledge = <String>[];
  var output = AgentOutput.free;
  var template = '';
  // The report's shape is everything after the last "## Report like this"
  // (a Markdown template has headings of its own); it's written back the
  // same way, so nothing is lost either way.
  final report = body.lastIndexOf('\n$_reportLike\n');
  final at = report >= 0 ? report + 1 : (body.startsWith('$_reportLike\n') ? 0 : -1);
  if (at >= 0) {
    var shape = body.substring(at + _reportLike.length).trim();
    body = body.substring(0, at).trim();
    final fence = RegExp(r'^```json\n([\s\S]*?)\n```$').firstMatch(shape);
    if (fence != null) {
      output = AgentOutput.json;
      shape = fence.group(1)!;
    } else {
      output = AgentOutput.markdown;
    }
    template = shape;
  }
  // "## Read first" is Kumo's only at the end and with nothing but a list:
  // a hand-written section of that name stays in the instructions.
  final read = body.lastIndexOf('\n$_readFirst\n');
  final readAt = read >= 0 ? read + 1 : (body.startsWith('$_readFirst\n') ? 0 : -1);
  if (readAt >= 0) {
    final lines = body.substring(readAt + _readFirst.length).trim().split('\n');
    if (lines.every((l) => l.trim().isEmpty || RegExp(r'^\s*-\s+').hasMatch(l))) {
      knowledge = [for (final l in lines) if (l.trim().isNotEmpty) l.replaceFirst(RegExp(r'^\s*-\s+'), '').trim()];
      body = body.substring(0, readAt).trim();
    }
  }
  if (body.isEmpty) checks.add(const AgentCheck(CheckLevel.error, 'No instructions after the frontmatter.'));
  if (name.isEmpty) return AgentFileRead(null, checks);

  final turns = int.tryParse(fields['maxTurns'] ?? '');
  final color = fields['color'] ?? '';
  return AgentFileRead(
    AgentDef(
      name: name,
      description: description,
      instructions: body,
      tools: tools,
      model: (fields['model'] ?? '').isEmpty ? 'inherit' : fields['model']!,
      approvals: _approvalsOf(fields['permissionMode'] ?? '', asWritten: asWritten),
      everyTool: asWritten && !fields.containsKey('tools'),
      // No maxTurns line: no limit, as Claude Code reads it.
      maxTurns: turns,
      skills: list(fields['skills']),
      mcpServers: {...list(fields['mcpServers']), ...mcpFromTools}.toList(),
      memory: AgentMemory.of(fields['memory'] ?? ''),
      isolation: fields['isolation'] == 'worktree',
      color: agentColors.contains(color) ? color : 'cyan',
      knowledge: knowledge,
      output: output,
      outputTemplate: template,
      extra: [for (final k in extraKeys) (k, raw[k]!.join('\n'))],
      scope: scope,
      repo: repo,
    ),
    checks,
  );
}

AgentApprovals _approvalsOf(String key, {required bool asWritten}) {
  final approvals = AgentApprovals.of(key) ?? AgentApprovals.ask;
  return approvals == AgentApprovals.bypass && !asWritten ? AgentApprovals.ask : approvals;
}

String _unquote(String s) {
  if (s.length < 2) return s;
  if (s.startsWith('"') && s.endsWith('"')) {
    try {
      final v = jsonDecode(s);
      if (v is String) return v;
    } on FormatException {
      // Not JSON: what's between the quotes.
    }
    return s.substring(1, s.length - 1);
  }
  if (s.startsWith("'") && s.endsWith("'")) return s.substring(1, s.length - 1).replaceAll("''", "'");
  return s;
}

// ---------------------------------------------------------------------------
// Before saving
// ---------------------------------------------------------------------------

/// Words that make a description too vague for Claude to delegate on.
final _vague = RegExp(r'^(a |an )?(helpful |general )?(assistant|helper|agent)\b|helps with (code|stuff|things)', caseSensitive: false);
final _when = RegExp(r'\b(use it|use this|when|before|after|for any|on any|whenever)\b', caseSensitive: false);

/// The name's check: valid and free where it's saved ([taken]).
AgentCheck agentNameCheck(AgentDef a, {Set<String> taken = const {}}) {
  final where = a.scope == AgentScope.project ? a.repo : 'Personal';
  if (a.name.isEmpty) return const AgentCheck(CheckLevel.error, 'It needs a name.');
  if (!isAgentName(a.name)) return const AgentCheck(CheckLevel.error, 'Only lowercase letters, digits and hyphens, starting with a letter.');
  if (taken.contains(a.name)) return AgentCheck(CheckLevel.error, '${a.name} is taken in $where.');
  return AgentCheck(CheckLevel.ok, '${a.name} is free in $where.');
}

/// The description's check: says what it does and when to use it.
AgentCheck agentDescriptionCheck(AgentDef a) {
  final d = a.description.trim();
  if (d.isEmpty) return const AgentCheck(CheckLevel.error, 'Say what it does and when to use it.');
  if (d.length < 40 || _vague.hasMatch(d)) return const AgentCheck(CheckLevel.warn, 'Too vague: Claude won’t know when to hand it work. Say what it does and when.');
  if (!_when.hasMatch(d)) return const AgentCheck(CheckLevel.warn, 'Add when to use it (“Use it when…”): that’s what Claude reads to delegate.');
  return AgentCheck(CheckLevel.ok, '${d.length} characters · says what and when.');
}

/// Whether [instructions] start with a frontmatter of their own: a whole agent
/// file pasted in, whose description and tools would be only text.
bool agentInstructionsHaveFile(String instructions) => instructions.trimLeft().startsWith(RegExp(r'---\r?\n'));

/// [a] with the file pasted in its instructions spread over its fields: what
/// the file doesn't say stays out, as if imported, but where it lives and what
/// only Kumo keeps stay [a]'s. Null when it can't be read.
AgentDef? agentFromPastedFile(AgentDef a) {
  if (!agentInstructionsHaveFile(a.instructions)) return null;
  final read = readAgentFile(a.instructions, scope: a.scope, repo: a.repo).agent;
  if (read == null) return null;
  return read.copyWith(
    name: read.name.isEmpty ? a.name : read.name,
    maxMinutes: () => a.maxMinutes,
    maxCostUsd: () => a.maxCostUsd,
    triggers: a.triggers,
  );
}

/// Everything to check before [a] is saved, in the order the form shows it.
List<AgentCheck> agentChecks(AgentDef a, {Set<String> taken = const {}}) {
  final writes = agentWrites(a.tools);
  return [
    agentNameCheck(a, taken: taken),
    agentDescriptionCheck(a),
    if (a.instructions.trim().isEmpty)
      const AgentCheck(CheckLevel.error, 'Write its instructions, or have Claude draft them.')
    else if (agentInstructionsHaveFile(a.instructions))
      const AgentCheck(CheckLevel.warn, 'Its instructions start with a frontmatter: a whole agent file pasted in? Its description and tools there are only text.')
    else
      AgentCheck(CheckLevel.ok, 'Instructions: ${a.instructions.trim().split('\n').where((l) => l.trim().isNotEmpty).length} lines.'),
    if (a.tools.isEmpty && a.mcpServers.isEmpty)
      const AgentCheck(CheckLevel.error, 'Pick at least one tool, even if only Read.')
    else
      AgentCheck(CheckLevel.ok, 'Tools: ${agentToolsKind(a.tools).$2}.'),
    if (a.approvals == AgentApprovals.bypass)
      const AgentCheck(CheckLevel.warn, 'Its file skips every approval (bypassPermissions): it runs everything without asking.'),
    if (a.everyTool)
      const AgentCheck(CheckLevel.warn, 'Its file has no tools line: it has every tool, MCP ones too. Pick some in Edit to limit it.'),
    if (writes && a.triggers.isNotEmpty && !a.isolation)
      const AgentCheck(CheckLevel.warn, 'A trigger runs it on its own with tools that change things: turn Isolation on.'),
  ];
}

bool agentSavable(AgentDef a, {Set<String> taken = const {}}) => !agentChecks(a, taken: taken).any((c) => c.level == CheckLevel.error);

/// What the tools mean, for the warning under them (null: nothing to say).
String? agentToolsWarning(AgentDef a) {
  final edits = a.tools.any(_edits);
  final bash = a.tools.contains('Bash');
  if (!edits && !bash) return null;
  final what = edits && bash ? 'It can change files and run commands.' : (edits ? 'It can change files.' : 'It can run any command.');
  final where = a.isolation ? 'Each run gets its own worktree, so your checkout is safe.' : 'It works on the files where you start it.';
  final ask = switch (a.approvals) {
    AgentApprovals.ask => 'It asks you before each edit or command.',
    AgentApprovals.plan => 'Plan only: it proposes, and changes nothing until you say so.',
    AgentApprovals.acceptEdits => 'It edits without asking, and asks before commands.',
    AgentApprovals.dontAsk => 'It won’t ask: anything not allowed is denied.',
    AgentApprovals.bypass => 'It won’t ask: its file skips every approval.',
  };
  return '$what $where $ask';
}

// ---------------------------------------------------------------------------
// Running it
// ---------------------------------------------------------------------------

/// The agent as `--agents` takes it inline (for a project agent run outside
/// its repo, or a draft in the playground).
String agentInlineJson(AgentDef a) => jsonEncode({
      a.name: {
        'description': a.description,
        'prompt': a.toMarkdown().split('\n---\n').skip(1).join('\n---\n').trim(),
        if (!a.everyTool) 'tools': [...a.tools, for (final m in a.mcpServers) 'mcp__$m'],
        'model': a.model,
        if (a.approvals != AgentApprovals.ask) 'permissionMode': a.approvals.key,
        if (a.maxTurns != null) 'maxTurns': a.maxTurns,
        if (a.skills.isNotEmpty) 'skills': a.skills,
        if (a.mcpServers.isNotEmpty) 'mcpServers': a.mcpServers,
        if (a.memory != AgentMemory.none) 'memory': a.memory.key,
        for (final (k, v) in a.extra) k: _inlineValue(k, v),
      },
    });

/// A field Kumo doesn't edit, from the way it's written in the file to what
/// `--agents` takes (which refuses the whole agent over a wrong type).
Object? _inlineValue(String key, String written) {
  Object? value;
  try {
    final doc = loadYaml('$key:${written.startsWith('\n') ? written : ' $written'}');
    value = jsonDecode(jsonEncode((doc as Map)[key]));
  } on Object {
    value = written.trim();
  }
  // Written as "A, B" in a file, a list here.
  if (const {'disallowedTools'}.contains(key) && value is String) {
    return [for (final t in value.split(',')) if (t.trim().isNotEmpty) t.trim()];
  }
  return value;
}

/// The command its terminal runs, as Kumo shows it (the engine builds the
/// real argv from the same parts).
String agentCommand(AgentDef a, {String contextDir = '', String prompt = '', AgentCli cli = AgentCli.claude}) {
  final p = prompt.trim();
  final quoted = p.isEmpty ? '' : ' "${p.length > 70 ? '${p.substring(0, 68)}…' : p}"';
  if (cli == AgentCli.codex) {
    // The context folder is only named in its message: --add-dir would let
    // Codex write there.
    return 'codex -s ${codexSandbox(a)} -c developer_instructions="…"${quoted.isEmpty ? '' : ' --$quoted'}';
  }
  if (cli == AgentCli.copilot) {
    // Copilot reads agents from files: Kumo writes this one for the run,
    // under a name of its own.
    return 'copilot --agent ${a.name}-… --add-dir <its copy>${contextDir.isEmpty ? '' : ' --add-dir $contextDir'}${quoted.isEmpty ? '' : ' -i$quoted'}';
  }
  // Always inline (agentInlineJson): by name, Claude Code goes by the file's
  // `name` line and Kumo by the file; and a file may not be where it runs.
  final agent = '--agents \'{"${a.name}": …}\' --agent ${a.name}';
  return 'claude $agent${contextDir.isEmpty ? '' : ' --add-dir $contextDir'}${quoted.isEmpty ? '' : ' --$quoted'}';
}

/// The headless run the playground starts.
String playgroundCommand(AgentDef a, {String task = '', AgentCli cli = AgentCli.claude}) {
  final p = task.trim();
  final quoted = p.isEmpty ? '' : ' "${p.length > 40 ? '${p.substring(0, 38)}…' : p}"';
  if (cli == AgentCli.codex) return 'codex exec --json -s ${codexSandbox(a)} -c developer_instructions="…"$quoted';
  if (cli == AgentCli.copilot) return 'copilot -p$quoted --agent ${a.name}-… --output-format json';
  return 'claude -p --agents \'{"${a.name}": …}\' --agent ${a.name} --output-format stream-json --verbose'
      '${a.maxTurns == null ? '' : ' --max-turns ${a.maxTurns}'}$quoted';
}

// ---------------------------------------------------------------------------
// The CLIs your agents run on
// ---------------------------------------------------------------------------

/// A CLI your agents can run on. The file is Claude Code's; the engine turns
/// it into each CLI's flags (`crates/domain/src/agent_defs/cli`).
enum AgentCli {
  claude('claude', 'Claude Code'),
  codex('codex', 'Codex CLI'),
  copilot('copilot', 'Copilot CLI');

  const AgentCli(this.id, this.label);

  /// The provider it runs as.
  final String id;
  final String label;

  /// Its name where there's little room: a choice among them.
  String get short => label.replaceAll(' CLI', '');

  static AgentCli? of(String id) => values.where((c) => c.id == id).firstOrNull;
}

bool _has(AgentDef a, String tool) => a.everyTool || a.tools.contains(tool);

/// Codex's sandbox for [a]: it never gets more than the file gives.
String codexSandbox(AgentDef a) {
  final writes = a.approvals != AgentApprovals.plan && (_has(a, 'Bash') || ['Edit', 'Write', 'MultiEdit', 'NotebookEdit'].any((t) => _has(a, t)));
  return writes ? 'workspace-write' : 'read-only';
}

/// What changes when [a] runs on [cli], as the run form shows it. Empty for
/// Claude Code: the file is its own.
List<AgentCheck> agentCliNotes(AgentDef a, AgentCli cli) => switch (cli) {
  AgentCli.claude => const [],
  AgentCli.codex => _codexNotes(a),
  AgentCli.copilot => _copilotNotes(a),
};

/// Claude Code's tools and the Copilot tool each one is (as the engine's
/// `cli/copilot.rs`).
const _copilotToolOf = {
  'Read': 'read',
  'NotebookRead': 'read',
  'Grep': 'search',
  'Glob': 'search',
  'Edit': 'edit',
  'Write': 'edit',
  'MultiEdit': 'edit',
  'NotebookEdit': 'edit',
  'Bash': 'execute',
  'WebFetch': 'web',
  'WebSearch': 'web',
  'TodoWrite': 'todo',
};

/// Copilot's tools for [a]: it never gets more than the file gives.
List<String> copilotTools(AgentDef a) {
  final plan = a.approvals == AgentApprovals.plan;
  return [
    for (final t in const ['read', 'search', 'edit', 'execute', 'web', 'todo'])
      if ((a.everyTool || _copilotToolOf.entries.any((e) => e.value == t && a.tools.contains(e.key))) && !(plan && (t == 'edit' || t == 'execute'))) t,
  ];
}

List<AgentCheck> _copilotNotes(AgentDef a) {
  final plan = a.approvals == AgentApprovals.plan;
  final tools = copilotTools(a);
  final edits = tools.contains('edit');
  final model = a.model.toLowerCase();
  final own = model != 'inherit' && !model.startsWith('claude') && !['haiku', 'sonnet', 'opus'].any(model.contains);
  final unmatched = [for (final t in a.tools) if (!t.startsWith('mcp__') && !_copilotToolOf.containsKey(t)) t];
  return [
    if (!edits && !tools.contains('execute'))
      AgentCheck(CheckLevel.ok, '${plan ? 'Plan only, so it only reads' : 'It only reads'}: Copilot gets ${tools.isEmpty ? 'no tools' : tools.join(', ')}, as Kumo writes it for each run.')
    else
      AgentCheck(CheckLevel.info, 'Copilot gets ${tools.join(', ')}, as Kumo writes it for each run.'),
    if (edits && a.approvals == AgentApprovals.acceptEdits)
      const AgentCheck(CheckLevel.info, 'Edits go without asking.')
    else if (edits || tools.contains('execute'))
      const AgentCheck(CheckLevel.info, 'It asks you before each change in its terminal. A test run can’t ask, so it can’t change anything.'),
    if (a.approvals == AgentApprovals.bypass) const AgentCheck(CheckLevel.warn, 'Its file skips every approval: Copilot doesn’t, it asks.'),
    if (a.approvals == AgentApprovals.dontAsk && tools.any((t) => t == 'edit' || t == 'execute')) const AgentCheck(CheckLevel.info, 'Copilot can’t turn requests down on its own: it asks you instead.'),
    AgentCheck(
      CheckLevel.info,
      own ? 'Model: ${a.model}.' : 'Model: your Copilot default. If that’s Auto it can change from run to run, and some models drift from the role: pick one with /model in Copilot.',
    ),
    if (unmatched.isNotEmpty) AgentCheck(CheckLevel.warn, '${unmatched.join(', ')} ${unmatched.length == 1 ? 'has' : 'have'} no match in Copilot: it runs without ${unmatched.length == 1 ? 'it' : 'them'}.'),
    if (a.mcpServers.isNotEmpty) AgentCheck(CheckLevel.warn, 'Its connectors don’t carry over yet: it runs without ${a.mcpServers.join(', ')}.'),
    if (a.skills.isNotEmpty) AgentCheck(CheckLevel.warn, 'Its skills don’t carry over: it runs without ${a.skills.join(', ')}.'),
    if (a.maxTurns != null) AgentCheck(CheckLevel.info, 'Copilot has no turn limit: its ${a.maxTurns} turns don’t apply.'),
    if (a.maxCostUsd != null) const AgentCheck(CheckLevel.info, 'Copilot counts premium requests, not cost: the cost limit doesn’t apply.'),
    if (a.memory != AgentMemory.none) const AgentCheck(CheckLevel.info, 'Memory is Claude Code’s: on Copilot it starts fresh.'),
    const AgentCheck(CheckLevel.info, 'The first time in a folder Copilot asks whether to trust it: answer in its terminal.'),
  ];
}

List<AgentCheck> _codexNotes(AgentDef a) {
  final plan = a.approvals == AgentApprovals.plan;
  final bash = _has(a, 'Bash');
  final model = a.model.toLowerCase();
  final effort = model.contains('haiku') ? 'low' : (model.contains('sonnet') ? 'medium' : (model.contains('opus') ? 'high' : ''));
  return [
    if (codexSandbox(a) == 'read-only')
      AgentCheck(CheckLevel.ok, '${plan ? 'Plan only, so read-only' : 'Read-only'}: it reads and runs commands in a sandbox that stops any change and the network.')
    else
      AgentCheck(CheckLevel.info, 'It can change files only in the folder it runs in${bash ? '' : ', not in temporary ones'}. The network stays off.'),
    if (bash && !plan && a.approvals != AgentApprovals.dontAsk)
      const AgentCheck(CheckLevel.info, 'It asks you before going beyond the sandbox.')
    else
      const AgentCheck(CheckLevel.info, 'It never asks: what the sandbox stops just fails.'),
    if (a.approvals == AgentApprovals.bypass) const AgentCheck(CheckLevel.warn, 'Its file skips every approval: Codex doesn’t, it keeps the sandbox.'),
    AgentCheck(
      CheckLevel.info,
      effort.isNotEmpty
          ? 'Model: your Codex default, thinking with $effort effort (${agentModelLabel(a.model)}).'
          : (model == 'inherit' || model.startsWith('claude') ? 'Model: your Codex default.' : 'Model: ${a.model}.'),
    ),
    if (_has(a, 'WebSearch')) const AgentCheck(CheckLevel.info, 'Web search on.') else if (_has(a, 'WebFetch')) const AgentCheck(CheckLevel.warn, 'WebFetch has no match in Codex: it can’t read pages.'),
    if (a.mcpServers.isNotEmpty) AgentCheck(CheckLevel.warn, 'Its connectors don’t carry over yet: it runs without ${a.mcpServers.join(', ')}.'),
    if (a.skills.isNotEmpty) AgentCheck(CheckLevel.warn, 'Its skills don’t carry over: it runs without ${a.skills.join(', ')}.'),
    if (a.maxTurns != null) AgentCheck(CheckLevel.info, 'Codex has no turn limit: its ${a.maxTurns} turns don’t apply.'),
    if (a.maxCostUsd != null) const AgentCheck(CheckLevel.info, 'Codex reports tokens, not cost: the cost limit doesn’t apply.'),
    if (a.memory != AgentMemory.none) const AgentCheck(CheckLevel.info, 'Memory is Claude Code’s: on Codex it starts fresh.'),
  ];
}

// ---------------------------------------------------------------------------
// Starting points
// ---------------------------------------------------------------------------

/// A template for a new agent.
@immutable
class AgentTemplate {
  const AgentTemplate(this.id, this.label, this.hint, this.tools, this.color, {this.role = '', this.step = '', this.dont = ''});
  final String id;
  final String label;
  final String hint;
  final List<String> tools;
  final String color;
  final String role;
  final String step;
  final String dont;

  bool get blank => id == 'blank';

  /// The draft it starts: safe defaults, its tools, isolation when it
  /// changes things.
  AgentDef draft({AgentScope scope = AgentScope.personal, String repo = '', String name = ''}) => AgentDef(
        name: name.isEmpty ? id : name,
        description: blank ? '' : '${hint.replaceAll(RegExp(r'\.$'), '')}. Use it when ',
        instructions: blank
            ? ''
            : [
                'You are $role.',
                '',
                'How to work:',
                '1. Read what you were given first.',
                '2. $step',
                '3. Say what you did and what you’re unsure of.',
                '',
                dont,
              ].join('\n'),
        tools: tools,
        color: color,
        isolation: agentWrites(tools),
        scope: scope,
        repo: repo,
      );
}

const agentTemplates = [
  AgentTemplate('code-reviewer', 'Code reviewer', 'Reads a diff and reports bugs, risky changes and missing tests. Changes nothing.', readOnlyTools, 'cyan',
      role: 'a code reviewer', step: 'Read the diff, then the code around each change; list bugs, risky changes and missing tests, most serious first.', dont: 'Don’t change any file.'),
  AgentTemplate('researcher', 'Researcher', 'Reads the code and the web; reports options with sources.', [...readOnlyTools, 'WebFetch', 'WebSearch'], 'purple',
      role: 'a researcher', step: 'Look at three to five options: docs, issues, releases, and how the code here would use each.', dont: 'Don’t change any file. Cite every claim.'),
  AgentTemplate('doc-writer', 'Writer', 'Writes and updates docs, READMEs and runbooks.', [...readOnlyTools, 'Edit', 'Write'], 'blue',
      role: 'a technical writer', step: 'Write or update the docs it was asked for, in the repo’s style.', dont: 'Only change documentation files. Don’t push.'),
  AgentTemplate('test-writer', 'Test writer', 'Writes tests for what a branch changed, and runs them.', [...readOnlyTools, 'Edit', 'Write', 'Bash'], 'green',
      role: 'a test writer', step: 'Write tests for every function the branch changed, then run them.', dont: 'Don’t change code outside test files. Don’t push.'),
  AgentTemplate('bug-fixer', 'Bug fixer', 'Reproduces a bug from a ticket, fixes it and proves it with a test.', [...readOnlyTools, 'Edit', 'Bash'], 'red',
      role: 'a bug fixer', step: 'Reproduce the bug with a failing test, fix it, and run the tests around it.', dont: 'Don’t push. Don’t change unrelated code.'),
  AgentTemplate('blank', 'Blank', 'Only the safe defaults: read-only.', readOnlyTools, 'yellow'),
];

/// What Kumo asks Claude to draft an agent from [description] (the engine
/// runs it headless and hands back the file).
String draftAgentPrompt(String description) => [
      'Write a Claude Code subagent file for this: ${description.trim()}',
      'Reply with only the file: a frontmatter between --- lines with name (lowercase and hyphens), description (what it does, then “Use it when…”), tools (the fewest that do the job: Read, Grep and Glob unless it must change files or run commands) and model: inherit; then its instructions: its role, how to work in numbered steps, what to report, and what not to do.',
    ].join('\n\n');

/// What Kumo asks Claude to improve [a]'s instructions with, from a test
/// run's step that went wrong ([step], as the playground showed it).
String improveInstructionsPrompt(AgentDef a, {String step = '', String answer = ''}) => [
      'These are the instructions of the subagent ${a.name} (${a.description}):',
      '```\n${a.instructions.trim()}\n```',
      if (step.isNotEmpty) 'In a test run it went wrong here: $step',
      if (answer.isNotEmpty) 'Its answer was:\n$answer',
      'Change the instructions as little as possible so it doesn’t happen again. Reply with only the new instructions.',
    ].join('\n\n');
