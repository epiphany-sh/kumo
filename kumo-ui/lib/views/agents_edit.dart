part of 'agents_library.dart';

/// Edit: the basics first (name, model, description, instructions, tools),
/// the rest under Advanced; its file as Claude Code reads it, and what to
/// fix before saving, beside.
class _AgentEditor extends StatefulWidget {
  const _AgentEditor({
    super.key,
    required this.saved,
    required this.agent,
    required this.note,
    required this.taken,
    required this.onChanged,
    required this.onSave,
    required this.onDiscard,
    required this.onDelete,
    required this.onTest,
  });

  /// As saved (null: never saved).
  final AgentDef? saved;
  final AgentDef agent;

  /// Where it came from ("From the Code reviewer template").
  final String note;

  /// Names taken where it's saved.
  final Set<String> taken;
  final ValueChanged<AgentDef> onChanged;
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  final VoidCallback onDelete;
  final VoidCallback onTest;

  @override
  State<_AgentEditor> createState() => _AgentEditorState();
}

class _AgentEditorState extends State<_AgentEditor> {
  late final _name = TextEditingController(text: widget.agent.name);
  late final _desc = TextEditingController(text: widget.agent.description);
  late final _body = TextEditingController(text: widget.agent.instructions);
  late final _output = TextEditingController(text: widget.agent.outputTemplate);
  late final _turns = TextEditingController(text: widget.agent.maxTurns?.toString() ?? '');
  late final _minutes = TextEditingController(text: widget.agent.maxMinutes?.toString() ?? '');
  late final _cost = TextEditingController(text: widget.agent.maxCostUsd == null ? '' : _money(widget.agent.maxCostUsd!));
  final _knowledge = TextEditingController();
  final _otherTool = TextEditingController();
  String _otherToolError = '';
  bool _advanced = false;
  bool _drafting = false;
  bool _confirmDelete = false;

  static String _money(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  AgentDef get a => widget.agent;

  @override
  void didUpdateWidget(_AgentEditor old) {
    super.didUpdateWidget(old);
    // Changed from outside (the playground's fix, a discard): the fields follow.
    void sync(TextEditingController t, String v) {
      if (t.text != v) t.text = v;
    }

    sync(_name, a.name);
    sync(_desc, a.description);
    sync(_body, a.instructions);
    sync(_output, a.outputTemplate);
    // Limits: only when they changed outside the field (a discard); the
    // field may hold what can't be read as a number yet.
    if (int.tryParse(_turns.text.trim()) != a.maxTurns) sync(_turns, a.maxTurns?.toString() ?? '');
    if (int.tryParse(_minutes.text.trim()) != a.maxMinutes) sync(_minutes, a.maxMinutes?.toString() ?? '');
    if (double.tryParse(_cost.text.trim()) != a.maxCostUsd) sync(_cost, a.maxCostUsd == null ? '' : _money(a.maxCostUsd!));
  }

  @override
  void dispose() {
    for (final t in [_name, _desc, _body, _output, _turns, _minutes, _cost, _knowledge, _otherTool]) {
      t.dispose();
    }
    super.dispose();
  }

  void _set(AgentDef next) => widget.onChanged(next);

  Future<void> _draftInstructions() async {
    final s = AppScope.read(context);
    setState(() => _drafting = true);
    String? text;
    if (a.instructions.trim().isEmpty) {
      text = (await s.agentDefs.draft(a.description.isEmpty ? a.name : a.description, scope: a.scope, repo: a.repo))?.instructions;
    } else {
      text = await s.agentDefs.improve(a);
    }
    if (!mounted) return;
    setState(() => _drafting = false);
    if (text == null || text.trim().isEmpty) {
      s.notify('${s.agents.askCli?.short ?? 'No connected CLI'} couldn’t draft them: ${s.agentDefs.error ?? 'try again'}');
      return;
    }
    _body.text = text;
    _set(a.copyWith(instructions: text));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final writer = AppScope.of(context).agents.askCli?.short;
    final checks = agentChecks(a, taken: widget.taken);
    final errors = checks.where((x) => x.level == CheckLevel.error).length;
    final dirty = widget.saved == null || widget.saved != a;
    final nameCheck = agentNameCheck(a, taken: widget.taken);
    final descCheck = agentDescriptionCheck(a);
    final form = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.note.isNotEmpty) ...[
        _Note(icon: KIcons.sparkle, text: widget.note, color: c.acc, background: c.accSoft),
        const SizedBox(height: 14),
      ],
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
          width: 240,
          child: _Block(
            title: 'Name',
            hint: 'lowercase and hyphens',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Line(controller: _name, monospace: true, label: 'Name', border: nameCheck.level == CheckLevel.error ? c.err : null, onChanged: (v) => _set(a.copyWith(name: v))),
              CheckLine(nameCheck),
            ]),
          ),
        ),
        _Block(
          title: 'Model',
          hint: 'cost and quality',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KSegmented<String>(
              label: 'Model',
              value: agentModels.any((m) => m.$1 == a.model) ? a.model : 'inherit',
              onChanged: (m) => _set(a.copyWith(model: m)),
              items: [for (final (id, label, _) in agentModels) (id, label, null)],
            ),
            const SizedBox(height: 4),
            Text(agentModels.where((m) => m.$1 == a.model).firstOrNull?.$3 ?? 'A model id: ${a.model}', style: sans(11, color: c.text3)),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      _Block(
        title: 'Description',
        hint: 'when to use it: Claude reads this to decide whether to hand it work',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Area(controller: _desc, minLines: 2, maxLines: 4, label: 'Description', border: descCheck.level == CheckLevel.ok ? null : (descCheck.level == CheckLevel.error ? c.err : c.warn), onChanged: (v) => _set(a.copyWith(description: v))),
          CheckLine(descCheck),
        ]),
      ),
      const SizedBox(height: 16),
      _Block(
        title: 'Instructions',
        hint: 'its role, what it does and doesn’t, how',
        trailing: KButton(
          label: _drafting ? 'Drafting…' : (writer == null ? 'Connect a CLI to draft' : '${a.instructions.trim().isEmpty ? 'Draft' : 'Improve'} with $writer'),
          icon: KIcons.sparkle,
          height: 26,
          fontSize: 11.5,
          kind: KButtonKind.ghost,
          onTap: _drafting || writer == null ? null : _draftInstructions,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Area(controller: _body, minLines: 9, maxLines: 22, monospace: true, label: 'Instructions', onChanged: (v) => _set(a.copyWith(instructions: v))),
          if (agentFromPastedFile(a) case final read?) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('This looks like a whole agent file: its description, tools and model are only text here.', style: sans(12, color: c.warn, height: 1.4))),
              const SizedBox(width: 8),
              KButton(label: 'Use its fields', height: 26, fontSize: 11.5, onTap: () => _set(read)),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      _tools(context),
      const SizedBox(height: 16),
      KPressable(
        onTap: () => setState(() => _advanced = !_advanced),
        selected: _advanced,
        semanticLabel: 'Advanced',
        builder: (context, hover, focus) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: hover ? c.tile : c.pane, borderRadius: BorderRadius.circular(12), border: Border.all(color: focus ? c.acc : c.paneBorder)),
          child: Row(children: [
            Icon(_advanced ? KIcons.chevronDown : KIcons.chevronRight, size: 16, color: c.text3),
            const SizedBox(width: 6),
            Text('Advanced', style: sans(12.5, weight: FontWeight.w600, color: c.text)),
            const SizedBox(width: 10),
            Expanded(child: Text(_advancedSummary(), maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3))),
          ]),
        ),
      ),
      if (_advanced) ...[const SizedBox(height: 10), _advancedFields(context)],
    ]);

    final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Card(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(KIcons.file, size: 13, color: c.text3),
            const SizedBox(width: 6),
            Expanded(child: Text(a.file, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text2))),
          ]),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10)),
            child: SingleChildScrollView(child: SelectableText(a.toMarkdown(), style: mono(10.5, color: c.text2, height: 1.55))),
          ),
          const SizedBox(height: 8),
          Text(
            '${a.maxMinutes != null || a.maxCostUsd != null || a.triggers.isNotEmpty ? 'Kumo keeps the time and cost limits and the triggers itself: they aren’t subagent fields. ' : ''}'
            'Knowledge and the report’s shape go into the instructions, so they hold when another agent calls it too.',
            style: sans(11, color: c.text3, height: 1.4),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      _Card(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Before saving', style: sans(13, weight: FontWeight.w600, color: c.text)),
          const SizedBox(height: 4),
          // The name's and the description's show under their fields: here,
          // only whether they're fine.
          for (final x in checks.take(2))
            CheckLine(x.level == CheckLevel.ok ? AgentCheck(CheckLevel.ok, x == checks.first ? 'Name: fine.' : 'Description: says what and when.') : AgentCheck(x.level, x == checks.first ? 'Name: see above.' : 'Description: see above.')),
          for (final x in checks.skip(2)) CheckLine(x),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: KButton(label: 'Test in playground', icon: KIcons.flask, height: 32, fontSize: 12.5, expand: true, onTap: widget.onTest)),
        const SizedBox(width: 8),
        Expanded(
          child: KButton.primary(
            label: widget.saved == null ? 'Save agent' : (dirty ? 'Save' : 'Saved'),
            height: 32,
            fontSize: 12.5,
            expand: true,
            onTap: errors == 0 && dirty ? widget.onSave : null,
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Text(
        errors > 0
            ? '$errors ${errors == 1 ? 'thing' : 'things'} to fix before saving'
            : (widget.saved == null ? 'Not saved yet' : (dirty ? 'Unsaved changes · the playground tries them as they are' : 'Saved · Claude Code picks it up in new sessions')),
        style: sans(11, color: errors > 0 ? c.err : (dirty ? c.warn : c.text3)),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 4, children: [
        if (widget.saved != null && dirty) KButton(label: 'Discard changes', height: 26, fontSize: 11.5, kind: KButtonKind.ghost, onTap: widget.onDiscard),
        KButton(
          label: _confirmDelete ? 'Click again to delete ${widget.saved == null ? 'the draft' : a.file.split('/').last}' : (widget.saved == null ? 'Discard draft' : 'Delete agent'),
          icon: KIcons.trash,
          height: 26,
          fontSize: 11.5,
          kind: KButtonKind.ghost,
          onTap: () {
            if (_confirmDelete) {
              widget.onDelete();
            } else {
              setState(() => _confirmDelete = true);
            }
          },
        ),
      ]),
    ]);

    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 820) {
        return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [form, const SizedBox(height: 16), side]));
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: SingleChildScrollView(child: form)),
        const SizedBox(width: 16),
        SizedBox(width: math.min(360, box.maxWidth * 0.36), child: SingleChildScrollView(child: side)),
      ]);
    });
  }

  String _advancedSummary() => [
        if (a.skills.isNotEmpty) '${a.skills.length} skill${a.skills.length == 1 ? '' : 's'}',
        if (a.knowledge.isNotEmpty) '${a.knowledge.length} doc${a.knowledge.length == 1 ? '' : 's'}',
        if (agentOtherTools(a.tools).isNotEmpty) agentOtherTools(a.tools).join(', '),
        if (a.mcpServers.isNotEmpty) a.mcpServers.join(', '),
        if (a.maxTurns != null) '${a.maxTurns} turns',
        if (a.maxMinutes != null) '${a.maxMinutes} min',
        a.approvals.label,
        if (a.isolation) 'own worktree',
        a.triggers.isEmpty ? 'no triggers' : '${a.triggers.length} trigger${a.triggers.length == 1 ? '' : 's'}',
        if (a.memory != AgentMemory.none) '${a.memory.label.toLowerCase()} memory',
        a.scope == AgentScope.project ? 'project' : 'personal',
      ].join(' · ');

  Widget _tools(BuildContext context) {
    final c = context.c;
    final warning = agentToolsWarning(a);
    return _Block(
      title: 'Tools',
      hint: 'what it may use: you pick, nothing is inherited',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (label, risk, tools, hint) in agentToolGroups)
            _ToolGroup(
              label: label,
              hint: hint,
              color: riskColors(c, risk).$1,
              tools: [for (final (t, what) in tools) (t, what, a.tools.contains(t))],
              onToggle: (t) => _set(a.copyWith(tools: a.tools.contains(t) ? [for (final x in a.tools) if (x != t) x] : [...a.tools, t])),
            ),
          if (a.mcpServers.isNotEmpty)
            _ToolGroup(
              label: 'Connectors',
              hint: 'Every tool of the MCP servers in Advanced.',
              color: c.purple,
              tools: [for (final m in a.mcpServers) ('mcp__$m', 'Every tool of $m', true)],
              onToggle: (t) => _set(a.copyWith(mcpServers: [for (final m in a.mcpServers) if ('mcp__$m' != t) m])),
            ),
        ]),
        // Tools Kumo doesn't offer: kept as the file says, edited in Advanced.
        if (agentOtherTools(a.tools).isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Also: ${agentOtherTools(a.tools).join(', ')} · in Advanced', style: mono(11, color: c.text3)),
        ],
        if (warning != null) ...[
          const SizedBox(height: 8),
          _Note(icon: KIcons.shield, text: warning, color: c.warn, background: c.warnSoft),
        ],
      ]),
    );
  }

  Widget _advancedFields(BuildContext context) {
    final c = context.c;
    final s = AppScope.read(context);
    final defs = s.agentDefs;
    int? toInt(String v) => int.tryParse(v.trim());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Section(title: 'Capabilities', hint: 'what it can reach besides its tools', rows: [
        _Row(
          label: 'Skills',
          hint: 'procedures it loads when it needs them',
          child: Wrap(spacing: 5, runSpacing: 5, children: [
            for (final k in a.skills) _Chip(label: k, onRemove: () => _set(a.copyWith(skills: [for (final x in a.skills) if (x != k) x]))),
            for (final k in defs.skills.where((k) => !a.skills.contains(k))) _AddChip(label: k, onTap: () => _set(a.copyWith(skills: [...a.skills, k]))),
          ]),
        ),
        _Row(
          label: 'Knowledge',
          hint: 'files read before every run',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 5, runSpacing: 5, children: [
              for (final k in a.knowledge) _Chip(label: k, tag: 'MD', onRemove: () => _set(a.copyWith(knowledge: [for (final x in a.knowledge) if (x != k) x]))),
            ]),
            if (a.knowledge.isNotEmpty) const SizedBox(height: 6),
            _Line(
              controller: _knowledge,
              monospace: true,
              label: 'Add a file',
              hint: 'docs/conventions.md, then Enter',
              onSubmitted: (v) {
                final p = v.trim();
                if (p.isEmpty || a.knowledge.contains(p)) return;
                _knowledge.clear();
                _set(a.copyWith(knowledge: [...a.knowledge, p]));
              },
            ),
          ]),
        ),
        _Row(
          label: 'More tools',
          hint: 'any other Claude Code tool, by name',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 5, runSpacing: 5, children: [
              for (final t in agentOtherTools(a.tools)) _Chip(label: t, onRemove: () => _set(a.copyWith(tools: [for (final x in a.tools) if (x != t) x]))),
            ]),
            if (agentOtherTools(a.tools).isNotEmpty) const SizedBox(height: 6),
            _Line(
              controller: _otherTool,
              monospace: true,
              label: 'Add a tool',
              hint: 'Monitor, LSP…, then Enter',
              border: _otherToolError.isEmpty ? null : c.err,
              onChanged: (_) {
                if (_otherToolError.isNotEmpty) setState(() => _otherToolError = '');
              },
              onSubmitted: (v) {
                final error = agentOtherToolError(v, a.tools);
                if (error != null) {
                  setState(() => _otherToolError = error);
                  return;
                }
                _otherTool.clear();
                _set(a.copyWith(tools: [...a.tools, v.trim()]));
              },
            ),
            if (_otherToolError.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_otherToolError, style: sans(11, color: c.err)),
            ],
          ]),
        ),
        _Row(
          label: 'Connectors',
          hint: 'MCP servers of this workspace',
          child: Wrap(spacing: 5, runSpacing: 5, children: [
            for (final m in a.mcpServers) _Chip(label: m, onRemove: () => _set(a.copyWith(mcpServers: [for (final x in a.mcpServers) if (x != m) x]))),
            for (final m in defs.mcpServers.where((m) => !a.mcpServers.contains(m))) _AddChip(label: m, onTap: () => _set(a.copyWith(mcpServers: [...a.mcpServers, m]))),
            if (defs.mcpServers.isEmpty && a.mcpServers.isEmpty) Text('None connected in this workspace.', style: sans(11.5, color: c.text3)),
          ]),
        ),
        _Row(
          label: 'Output',
          hint: 'how it reports back',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: KSegmented<AgentOutput>(
                label: 'Output',
                value: a.output,
                onChanged: (o) {
                  final template = a.outputTemplate.trim().isEmpty || a.outputTemplate == a.output.template ? o.template : a.outputTemplate;
                  _output.text = template;
                  _set(a.copyWith(output: o, outputTemplate: template));
                },
                items: [for (final o in AgentOutput.values) (o, o.label, null)],
              ),
            ),
            if (a.output != AgentOutput.free) ...[
              const SizedBox(height: 6),
              _Area(controller: _output, minLines: 3, maxLines: 10, monospace: true, label: 'Report template', onChanged: (v) => _set(a.copyWith(outputTemplate: v))),
            ],
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      _Section(title: 'Control', hint: 'when it stops, and what it asks', rows: [
        _Row(
          label: 'Limits',
          hint: 'per run: it ends when one is hit',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              _LimitField(label: 'Turns', unit: '', controller: _turns, onChanged: (v) => _set(a.copyWith(maxTurns: () => toInt(v)))),
              _LimitField(label: 'Time', unit: 'min', controller: _minutes, onChanged: (v) => _set(a.copyWith(maxMinutes: () => toInt(v)))),
              _LimitField(label: 'Cost', unit: 'USD', controller: _cost, onChanged: (v) => _set(a.copyWith(maxCostUsd: () => double.tryParse(v.trim())))),
            ]),
            const CheckLine(AgentCheck(CheckLevel.info, 'Optional, and off by default: a task cut short by a guess often costs more than letting it finish. Stop is always at hand. Cost counts in headless runs (playground, triggers), from Claude Code’s own report.')),
          ]),
        ),
        _Row(
          label: 'Approvals',
          hint: 'what it asks you first',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final p in AgentApprovals.values)
              if (p != AgentApprovals.bypass || a.approvals == p)
              _Radio(label: p.label, detail: p.key, hint: p.hint, selected: a.approvals == p, onTap: () => _set(a.copyWith(approvals: p))),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      _Section(title: 'Execution', hint: 'where and when it runs', rows: [
        _Row(
          label: 'Isolation',
          hint: 'a copy of the repo of its own',
          child: Align(
            alignment: Alignment.centerLeft,
            child: KSegmented<bool>(
              label: 'Isolation',
              value: a.isolation,
              onChanged: (v) => _set(a.copyWith(isolation: v)),
              items: const [(false, 'None', null), (true, 'Own worktree', null)],
            ),
          ),
        ),
        _Row(
          label: 'Triggers',
          hint: 'off until you add one',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final t in a.triggers)
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.only(left: 10, right: 2),
                height: 32,
                decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(t == AgentTrigger.schedule ? KIcons.clock : KIcons.pullRequest, size: 13, color: c.text3),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t == AgentTrigger.pullRequest ? 'When a pull request opens${a.scope == AgentScope.project ? ' in ${a.repo}' : ''}' : 'Weekdays at 9:00', style: sans(12, color: c.text))),
                  Text('headless', style: sans(11, color: c.text3)),
                  KIconButton(icon: KIcons.close, label: 'Remove trigger', size: 26, iconSize: 12, onTap: () => _set(a.copyWith(triggers: [for (final x in a.triggers) if (x != t) x]))),
                ]),
              ),
            if (!defs.triggersSupported)
              Text('Triggers need a newer engine: they’re saved, and run once it can.', style: sans(11.5, color: c.text3))
            else
              Wrap(spacing: 5, children: [
                for (final t in AgentTrigger.values.where((t) => !a.triggers.contains(t))) _AddChip(label: t.label, onTap: () => _set(a.copyWith(triggers: [...a.triggers, t]))),
              ]),
            if (a.triggers.isNotEmpty) const CheckLine(AgentCheck(CheckLevel.info, 'It runs on its own, headless. When it needs you it shows under Needs you, with a notification.')),
          ]),
        ),
        _Row(
          label: 'Memory',
          hint: 'what it keeps between runs',
          child: Align(
            alignment: Alignment.centerLeft,
            child: KSegmented<AgentMemory>(
              label: 'Memory',
              value: a.memory,
              onChanged: (m) => _set(a.copyWith(memory: m)),
              items: [for (final m in AgentMemory.values) (m, m.label, null)],
            ),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      _Section(title: 'Appearance and scope', rows: [
        _Row(
          label: 'Color',
          hint: 'to tell it apart in Kumo',
          child: Wrap(spacing: 6, children: [
            for (final name in agentColors)
              KPressable(
                onTap: () => _set(a.copyWith(color: name)),
                selected: a.color == name,
                semanticLabel: name,
                tooltip: name,
                builder: (context, hover, focus) => Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: agentColor(c, name),
                    shape: BoxShape.circle,
                    border: Border.all(color: a.color == name || focus ? c.text : Colors.transparent, width: 2),
                  ),
                ),
              ),
          ]),
        ),
        _Row(
          label: 'Who can use it',
          hint: 'where its file lives',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final sc in AgentScope.values)
              _Radio(
                label: sc == AgentScope.project ? 'Project' : 'Personal',
                detail: sc == AgentScope.project ? '<repo>/.claude/agents/' : 'agents/ of this workspace',
                hint: sc.hint,
                selected: a.scope == sc,
                onTap: () => _set(a.copyWith(scope: sc, repo: sc == AgentScope.project && a.repo.isEmpty ? (s.activeRepo?.name ?? s.workspace.repos.firstOrNull?.name ?? '') : null)),
              ),
            if (a.scope == AgentScope.project && s.workspace.repos.isNotEmpty) ...[
              const SizedBox(height: 6),
              KSelect<String>(
                label: 'Repository',
                value: s.workspace.repos.any((r) => r.name == a.repo) ? a.repo : s.workspace.repos.first.name,
                items: [for (final r in s.workspace.repos) (r.name, r.name)],
                onChanged: (r) => _set(a.copyWith(repo: r)),
              ),
            ],
          ]),
        ),
      ]),
    ]);
  }
}

class _ToolGroup extends StatelessWidget {
  const _ToolGroup({required this.label, required this.hint, required this.color, required this.tools, required this.onToggle});
  final String label;
  final String hint;
  final Color color;

  /// (tool, what it does, on).
  final List<(String, String, bool)> tools;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final any = tools.any((t) => t.$3);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.pane, borderRadius: BorderRadius.circular(13), border: Border.all(color: any && color == c.warn ? c.warn : c.paneBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: sans(12, weight: FontWeight.w600, color: any ? color : c.text2)),
        const SizedBox(height: 6),
        Wrap(spacing: 5, runSpacing: 5, children: [
          for (final (t, what, on) in tools)
            KPressable(
              onTap: () => onToggle(t),
              selected: on,
              semanticLabel: t,
              tooltip: what,
              builder: (context, hover, focus) => Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: on ? color.withAlpha(c.isDark ? 40 : 30) : (hover ? c.tile : null),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: on || focus ? color : c.chipBorder),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(on ? KIcons.check : KIcons.add, size: 12, color: on ? color : c.text3),
                  const SizedBox(width: 4),
                  Flexible(child: Text(t, style: mono(11.5, color: on ? c.text : c.text2), overflow: TextOverflow.ellipsis, softWrap: false)),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Text(hint, style: sans(11, color: c.text3, height: 1.35)),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.hint = '', required this.rows});
  final String title;
  final String hint;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(title, style: sans(12.5, weight: FontWeight.w600, color: c.text)),
          if (hint.isNotEmpty) ...[const SizedBox(width: 8), Flexible(child: Text(hint, style: sans(11.5, color: c.text3)))],
        ]),
        for (final r in rows) ...[const SizedBox(height: 12), r],
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.hint, required this.child});
  final String label;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final head = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: sans(12, weight: FontWeight.w500, color: c.text)),
      Text(hint, style: sans(10.5, color: c.text3, height: 1.35)),
    ]);
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 420) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, const SizedBox(height: 6), child]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: head),
        const SizedBox(width: 12),
        Expanded(child: child),
      ]);
    });
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.label, required this.detail, required this.hint, required this.selected, required this.onTap});
  final String label;
  final String detail;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: KPressable(
        onTap: onTap,
        selected: selected,
        semanticLabel: label,
        builder: (context, hover, focus) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? c.accSoft : (hover ? c.tile : null),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected || focus ? c.acc : c.paneBorder),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? c.acc : c.text3, width: selected ? 4 : 1.5)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: label),
                    TextSpan(text: '  $detail', style: mono(10.5, color: c.text3)),
                  ]),
                  style: sans(12, weight: FontWeight.w500, color: selected ? c.text : c.text2),
                ),
                Text(hint, style: sans(11, color: c.text3, height: 1.35)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LimitField extends StatelessWidget {
  const _LimitField({required this.label, required this.unit, required this.controller, required this.onChanged});
  final String label;
  final String unit;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 150,
      height: 32,
      padding: const EdgeInsets.only(left: 10, right: 8),
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.chipBorder)),
      child: Row(children: [
        Expanded(child: Text(label, style: sans(11, color: c.text3))),
        SizedBox(
          width: 52,
          child: Semantics(
            label: label,
            textField: true,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: mono(12, color: c.text),
              cursorColor: c.acc,
              decoration: InputDecoration.collapsed(hintText: 'none', hintStyle: sans(11, color: c.text3)),
            ),
          ),
        ),
        if (unit.isNotEmpty) ...[const SizedBox(width: 4), Text(unit, style: sans(11, color: c.text3))],
      ]),
    );
  }
}
