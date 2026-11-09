part of 'agents_library.dart';

enum _Show { all, tools, words }

/// The playground: the agent (your draft, or as saved) on a sample task,
/// headless, every step on screen; flag where it went wrong and Claude
/// suggests a change to its instructions.
class _Playground extends StatefulWidget {
  const _Playground({super.key, required this.saved, required this.history, required this.agent, required this.dirty, required this.onChanged, required this.onSave, required this.onEdit});

  /// As saved (null: never saved).
  final AgentDef? saved;

  /// Whose test runs these are: the agent as saved, or a stand-in for one
  /// never saved (a draft's name can change).
  final AgentDef history;

  /// With your edits.
  final AgentDef agent;
  final bool dirty;
  final ValueChanged<AgentDef> onChanged;

  /// Saves the draft (null: it can't be saved yet).
  final VoidCallback? onSave;
  final VoidCallback onEdit;

  @override
  State<_Playground> createState() => _PlaygroundState();
}

class _PlaygroundState extends State<_Playground> {
  final _task = TextEditingController();
  late bool _draft = widget.dirty || widget.saved == null;

  /// The CLI it's tried on; null: the first connected one that can.
  AgentCli? _cli;
  String? _worktree;
  String? _shown;
  _Show _filter = _Show.all;

  /// The step flagged, by index in the run shown.
  int? _flag;
  String? _fix;
  bool _fixing = false;
  bool _applied = false;

  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    // The last test's task, to run again.
    final last = AppScope.read(context).agentDefs.playRuns(widget.history).firstOrNull;
    if (last != null) _task.text = last.task;
  }

  @override
  void dispose() {
    _task.dispose();
    super.dispose();
  }

  Future<void> _run(AppState s, AgentDef agent) async {
    final path = _worktree;
    if (path == null || _task.text.trim().isEmpty) return;
    final run = await s.agentDefs.play(agent, task: _task.text.trim(), worktreePath: path, owner: widget.history, draft: _draft, cli: _pick(s));
    if (!mounted) return;
    if (run == null) {
      s.notify('The test run didn’t start: ${s.agentDefs.error ?? 'unknown error'}');
      return;
    }
    setState(() {
      _shown = run.id;
      _flag = null;
      _fix = null;
      _applied = false;
    });
  }

  /// The CLI it's tried on, kept while it stays connected.
  AgentCli _pick(AppState s) {
    final clis = s.agents.agentClis;
    if (!clis.contains(_cli)) _cli = clis.firstOrNull;
    return _cli ?? AgentCli.claude;
  }

  Future<void> _flagStep(AppState s, PlayRun run, int i) async {
    if (_flag == i) {
      setState(() {
        _flag = null;
        _fix = null;
      });
      return;
    }
    setState(() {
      _flag = i;
      _fix = null;
      _fixing = true;
      _applied = false;
    });
    final text = await s.agentDefs.improve(widget.agent, step: describeStep(run.steps[i]), answer: run.answer?.text ?? '');
    if (!mounted || _flag != i) return;
    setState(() {
      _fixing = false;
      _fix = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final defs = s.agentDefs;
    final wts = [
      for (final r in s.workspace.repos)
        for (final w in s.worktreesOf(r)) (s.workspace.absolutePathOf(w), '${r.name} · ${w.branch}'),
    ];
    final active = s.activeWorktreeEntry;
    _worktree ??= active != null && wts.any((w) => w.$1 == s.workspace.absolutePathOf(active)) ? s.workspace.absolutePathOf(active) : wts.firstOrNull?.$1;
    final runs = defs.playRuns(widget.history);
    final run = runs.where((r) => r.id == _shown).firstOrNull ?? runs.firstOrNull;
    final agent = _draft || widget.saved == null ? widget.agent : widget.saved!;
    return LayoutBuilder(builder: (context, box) {
      final left = _setup(context, s, agent, wts, runs, run);
      final right = run == null ? _empty(context) : _timeline(context, s, run);
      if (box.maxWidth < 760) return ListView(children: [left, const SizedBox(height: 16), right]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 300, child: SingleChildScrollView(child: left)),
        const SizedBox(width: 16),
        Expanded(child: SingleChildScrollView(child: right)),
      ]);
    });
  }

  Widget _empty(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(children: [
        Icon(KIcons.flask, size: 26, color: c.text3),
        const SizedBox(height: 10),
        Text('Try it on a sample task', style: sans(13.5, weight: FontWeight.w600, color: c.text2)),
        const SizedBox(height: 4),
        Text('Every step shows here: what it thought, which tool it called with what, and what came back.', textAlign: TextAlign.center, style: sans(12.5, color: c.text3)),
      ]),
    );
  }

  Widget _setup(BuildContext context, AppState s, AgentDef agent, List<(String, String)> wts, List<PlayRun> runs, PlayRun? run) {
    final c = context.c;
    final running = run?.state == PlayState.running;
    final writes = agentWrites(agent.tools);
    final cli = _pick(s);
    final clis = s.agents.agentClis;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _CliPick(clis: clis, cli: cli, agent: agent, onChanged: (v) => setState(() => _cli = v)),
      const SizedBox(height: 12),
      _Block(title: 'Sample task', child: _Area(controller: _task, minLines: 3, maxLines: 6, label: 'Sample task', hint: 'Review PR #521 against main.', onChanged: (_) => setState(() {}))),
      const SizedBox(height: 12),
      if (wts.isNotEmpty)
        KSelect<String>(label: 'Runs on', value: _worktree!, monospace: true, items: wts, onChanged: (v) => setState(() => _worktree = v))
      else
        Text('Add a repository to a namespace first.', style: sans(12, color: c.text3)),
      const SizedBox(height: 4),
      Text(
        writes ? 'It can change files, so it runs in a throwaway worktree of that branch, removed after.' : 'Read-only, so it runs in place: nothing there changes.',
        style: sans(11, color: c.text3, height: 1.4),
      ),
      if (agent.knowledge.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 4, runSpacing: 4, children: [for (final k in agent.knowledge) _Chip(label: k, tag: 'MD')]),
      ],
      const SizedBox(height: 12),
      if (widget.saved != null) ...[
        Text('Version', style: sans(11, color: c.text3)),
        const SizedBox(height: 4),
        KSegmented<bool>(
          label: 'Version',
          value: _draft,
          onChanged: (v) => setState(() => _draft = v),
          items: [(true, widget.dirty ? 'Draft · unsaved' : 'Draft', null), (false, 'Saved', null)],
        ),
        const SizedBox(height: 12),
      ],
      KButton.primary(
        label: running ? 'Stop' : (_applied ? 'Run again with the fix' : (_draft || widget.saved == null ? 'Run the draft' : 'Run it')),
        icon: running ? KIcons.pause : KIcons.flask,
        expand: true,
        onTap: running ? () => s.agentDefs.stopPlay(run!.id) : (_worktree == null || _task.text.trim().isEmpty || clis.isEmpty ? null : () => _run(s, agent)),
      ),
      const SizedBox(height: 6),
      SelectableText(playgroundCommand(agent, task: _task.text, cli: cli), style: mono(10.5, color: c.text3, height: 1.5)),
      const SizedBox(height: 12),
      Container(height: 1, color: c.divider),
      const SizedBox(height: 10),
      Text('Test runs', style: sans(13, weight: FontWeight.w600, color: c.text)),
      const SizedBox(height: 4),
      if (runs.isEmpty) Text('None yet.', style: sans(12, color: c.text3)),
      for (final (i, r) in runs.indexed)
        KPressable(
          onTap: () => setState(() {
            _shown = r.id;
            _flag = null;
            _fix = null;
          }),
          selected: r.id == run?.id,
          semanticLabel: 'Run ${runs.length - i}',
          builder: (context, hover, focus) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(color: r.id == run?.id ? c.navActive : (hover || focus ? c.tile : null), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Dot(switch (r.state) { PlayState.running => c.acc, PlayState.done => c.ok, PlayState.stopped => c.text3, PlayState.failed => c.err }),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Run ${runs.length - i} · ${r.draft ? 'draft' : 'saved'}${r.cli == AgentCli.claude.id ? '' : ' · ${AgentCli.of(r.cli)?.label ?? r.cli}'}', style: sans(12, color: c.text)),
                  Text(_playMeta(r), maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3)),
                ]),
              ),
            ]),
          ),
        ),
      const SizedBox(height: 4),
      Text('The last 10 are kept.', style: sans(11, color: c.text3)),
    ]);
  }

  static String _playMeta(PlayRun r) {
    final m = r.meters;
    final parts = [
      switch (r.state) { PlayState.running => 'running', PlayState.stopped => 'stopped', PlayState.failed => r.error.isEmpty ? 'failed' : r.error, PlayState.done => 'done' },
      '${r.steps.where((x) => x.kind == PlayStepKind.tool).length} tool calls',
      '${m.elapsed.inSeconds}s',
      if (m.costUsd != null) '\$${m.costUsd!.toStringAsFixed(2)}',
    ];
    return parts.join(' · ');
  }

  Widget _timeline(BuildContext context, AppState s, PlayRun run) {
    final c = context.c;
    final a = widget.agent;
    final m = run.meters;
    final steps = [
      for (final (i, x) in run.steps.indexed)
        if (_filter == _Show.all || (_filter == _Show.tools ? x.kind == PlayStepKind.tool : x.kind != PlayStepKind.tool)) (i, x),
    ];
    final answer = run.answer;
    String fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 14, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (run.cli == AgentCli.claude.id)
          _Meter(label: 'Turns', value: '${m.turns} / ${a.maxTurns ?? '∞'}', fraction: a.maxTurns == null ? null : m.turns / a.maxTurns!, tooltip: 'Claude Code’s turns')
        else
          _Meter(label: 'Steps', value: '${run.steps.length}', tooltip: '${AgentCli.of(run.cli)?.label ?? run.cli} has no turn limit'),
        _Meter(label: 'Time', value: '${fmt(m.elapsed)} / ${a.maxMinutes == null ? '∞' : '${a.maxMinutes}:00'}', fraction: a.maxMinutes == null ? null : m.elapsed.inSeconds / (a.maxMinutes! * 60)),
        // Only Claude Code reports cost; the others, tokens.
        if (run.cli == AgentCli.claude.id)
          _Meter(label: 'Cost', value: m.costUsd == null ? '—' : '\$${m.costUsd!.toStringAsFixed(2)}', fraction: a.maxCostUsd == null || m.costUsd == null ? null : m.costUsd! / a.maxCostUsd!, tooltip: 'From Claude Code’s stream-json output'),
        _Meter(label: 'Tokens', value: m.tokensIn == 0 ? '—' : '${(m.tokensIn / 1000).toStringAsFixed(1)}k · ${(m.tokensOut / 1000).toStringAsFixed(1)}k'),
        KSegmented<_Show>(
          label: 'Show',
          value: _filter,
          height: 26,
          onChanged: (v) => setState(() => _filter = v),
          items: const [(_Show.all, 'All steps', null), (_Show.tools, 'Tools', null), (_Show.words, 'Thinking and answer', null)],
        ),
      ]),
      const SizedBox(height: 12),
      if (run.steps.isEmpty && run.state == PlayState.running) Text('Starting…', style: sans(12, color: c.text3)),
      for (final (i, x) in steps)
        if (x.kind != PlayStepKind.answer) ...[
          _StepCard(n: i + 1, step: x, flagged: _flag == i, onFlag: run.state == PlayState.running ? null : () => _flagStep(s, run, i)),
          if (_flag == i) _fixBox(context, s),
          const SizedBox(height: 6),
        ],
      if (run.state == PlayState.running && run.steps.isNotEmpty) Text('Running… step ${run.steps.length + 1}', style: sans(12, color: c.text3)),
      if (answer != null && _filter != _Show.tools) ...[
        const SizedBox(height: 6),
        _Card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Its answer', style: sans(13, weight: FontWeight.w600, color: c.text))),
              Text('${m.turns} turns · ${fmt(m.elapsed)}', style: sans(11, color: c.ok)),
            ]),
            const SizedBox(height: 6),
            SelectableText(answer.text, style: sans(12.5, color: c.text2, height: 1.5)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              if (widget.dirty) KButton.primary(label: 'Looks right: save it', height: 30, fontSize: 12.5, onTap: widget.onSave),
              KButton(label: 'Adjust instructions', height: 30, fontSize: 12.5, onTap: widget.onEdit),
            ]),
          ]),
        ),
      ],
    ]);
  }

  /// Claude's suggested change, as lines removed and added.
  Widget _fixBox(BuildContext context, AppState s) {
    final c = context.c;
    final fix = _fix;
    final lines = fix == null ? const <(String, int)>[] : lineDiff(widget.agent.instructions, fix);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.acc)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(KIcons.sparkle, size: 14, color: c.acc),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              _applied ? 'Applied to the draft. Run it again to check.' : (_fixing ? 'Claude is reading the run…' : (fix == null ? 'Claude had nothing to suggest.' : 'Claude suggests:')),
              style: sans(12.5, weight: FontWeight.w600, color: c.acc),
            ),
          ),
        ]),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(9)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (text, sign) in lines)
                Container(
                  color: sign > 0 ? c.addBg : (sign < 0 ? c.delBg : null),
                  child: Text('${sign > 0 ? '+' : (sign < 0 ? '−' : ' ')} $text', style: mono(11, color: sign == 0 ? c.text3 : c.text, height: 1.55)),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            KButton.primary(
              label: _applied ? 'Applied' : 'Apply to the draft',
              height: 30,
              fontSize: 12.5,
              onTap: _applied
                  ? null
                  : () {
                      widget.onChanged(widget.agent.copyWith(instructions: fix));
                      setState(() {
                        _applied = true;
                        _draft = true;
                      });
                    },
            ),
            const SizedBox(width: 8),
            KButton(label: 'Not this', height: 30, fontSize: 12.5, onTap: () => setState(() {
              _flag = null;
              _fix = null;
            })),
          ]),
        ],
      ]),
    );
  }
}

/// [after]'s lines against [before]'s: (line, -1 removed / 0 kept / +1
/// added), with only a line of context around each change.
List<(String, int)> lineDiff(String before, String after) {
  final a = before.split('\n'), b = after.split('\n');
  // Longest common subsequence, small texts.
  final n = a.length, m = b.length;
  final lcs = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : math.max(lcs[i + 1][j], lcs[i][j + 1]);
    }
  }
  final out = <(String, int)>[];
  var i = 0, j = 0;
  while (i < n || j < m) {
    if (i < n && j < m && a[i] == b[j]) {
      out.add((a[i], 0));
      i++;
      j++;
    } else if (j < m && (i >= n || lcs[i][j + 1] >= lcs[i + 1][j])) {
      out.add((b[j], 1));
      j++;
    } else {
      out.add((a[i], -1));
      i++;
    }
  }
  // Keep the changes and one line either side.
  final keep = <int>{};
  for (var k = 0; k < out.length; k++) {
    if (out[k].$2 != 0) keep.addAll([k - 1, k, k + 1]);
  }
  return [for (var k = 0; k < out.length; k++) if (keep.contains(k)) out[k]];
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.n, required this.step, required this.flagged, required this.onFlag});
  final int n;
  final PlayStep step;
  final bool flagged;
  final VoidCallback? onFlag;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final x = step;
    final (label, icon, color) = switch (x.kind) {
      PlayStepKind.thinking => ('Thinking', KIcons.sparkle, c.text3),
      PlayStepKind.tool => ('Tool', KIcons.wrench, c.acc),
      PlayStepKind.answer => ('Answer', KIcons.check, c.ok),
      PlayStepKind.error => ('Stopped', KIcons.warning, c.err),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(color: flagged ? c.warnSoft : c.pane, borderRadius: BorderRadius.circular(12), border: Border.all(color: flagged ? c.warn : c.paneBorder)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 24,
          child: Column(children: [
            Text('$n', style: mono(10, color: c.text3)),
            const SizedBox(height: 3),
            Icon(icon, size: 13, color: color),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: sans(11, weight: FontWeight.w600, color: color)),
              const SizedBox(width: 8),
              Expanded(child: Text(x.text, style: x.kind == PlayStepKind.tool ? mono(12, weight: FontWeight.w600, color: c.text) : sans(12.5, color: c.text, height: 1.45))),
              Text('${x.at.inMilliseconds / 1000 < 10 ? (x.at.inMilliseconds / 1000).toStringAsFixed(1) : x.at.inSeconds}s', style: mono(10.5, color: c.text3)),
              if (onFlag != null) ...[
                const SizedBox(width: 6),
                KButton(label: flagged ? 'Flagged' : 'Went wrong here', height: 22, fontSize: 10.5, kind: flagged ? KButtonKind.secondary : KButtonKind.ghost, onTap: onFlag),
              ],
            ]),
            if (x.params.isNotEmpty) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(8)),
                child: SelectableText(x.params, style: mono(11, color: c.text2, height: 1.5)),
              ),
            ],
            if (x.result.isNotEmpty) ...[
              const SizedBox(height: 5),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('⎿ ', style: mono(11, color: c.text3)),
                Expanded(child: SelectableText(x.result, style: mono(11, color: c.text2, height: 1.5))),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}
