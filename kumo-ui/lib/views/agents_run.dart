part of 'agents_library.dart';

/// One agent's run form: where it works, what it knows, what it's told.
class _RunForm {
  /// The CLI it runs on; null: the first connected one that can.
  AgentCli? cli;
  AgentWhereKind where = AgentWhereKind.worktree;

  /// The worktree picked (absolute path), or the repository for a new one.
  String? worktree;
  String? newIn;
  final link = TextEditingController();
  final folder = TextEditingController();
  final prompt = TextEditingController();

  /// Context the form found that you took off, by its title.
  final removed = <String>{};
  final added = <AgentContextItem>[];

  void dispose() {
    link.dispose();
    folder.dispose();
    prompt.dispose();
  }
}

/// The worktree [path]'s pull request and linked tasks, as context items.
Future<List<AgentContextItem>> worktreeContext(AppState s, String path) async {
  final items = <AgentContextItem>[];
  try {
    final pr = (await s.pullRequests.forBranch(path).timeout(const Duration(seconds: 8))).pullRequest;
    if (pr != null) items.add(AgentContextItem(kind: AgentContextKind.pullRequest, title: '${pr.label} · ${pr.title}', detail: 'diff + description', url: pr.url));
  } on Object {
    // No host, no token, offline: the rest still goes.
  }
  final ids = {for (final l in s.tasks.links) if (l.worktreePath == path) l.taskId};
  for (final TaskEntry t in s.tasks.tasks) {
    if (ids.contains(t.id)) items.add(s.taskContext(t));
  }
  return items;
}

class _RunTab extends StatefulWidget {
  const _RunTab({
    super.key,
    required this.agentKey,
    required this.agent,
    required this.current,
    required this.fresh,
    required this.dirty,
    required this.runs,
    required this.form,
    required this.shown,
    required this.terminals,
    required this.onShow,
    required this.onEdit,
    required this.onTry,
  });

  final String agentKey;

  /// As saved: what runs.
  final AgentDef agent;

  /// With your edits.
  final AgentDef current;
  final bool fresh;
  final bool dirty;
  final List<AgentRun> runs;
  final _RunForm form;
  final String? shown;
  final AgentTerminals terminals;
  final ValueChanged<String?> onShow;
  final VoidCallback onEdit;
  final VoidCallback onTry;

  @override
  State<_RunTab> createState() => _RunTabState();
}

class _RunTabState extends State<_RunTab> {
  List<AgentContextItem> _found = const [];
  String? _foundFor;
  bool _adding = false;
  AgentContextKind _addKind = AgentContextKind.task;
  final _addText = TextEditingController();
  bool _starting = false;

  _RunForm get f => widget.form;

  @override
  void dispose() {
    _addText.dispose();
    super.dispose();
  }

  List<(Repo, Worktree, String)> _worktrees(AppState s) => [
        for (final r in s.workspace.repos)
          for (final w in s.worktreesOf(r)) (r, w, s.workspace.absolutePathOf(w)),
      ];

  void _lookUp(AppState s, String path) {
    if (_foundFor == path) return;
    _foundFor = path;
    _found = const [];
    worktreeContext(s, path).then((items) {
      if (mounted && _foundFor == path) setState(() => _found = items);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final shown = widget.runs.where((r) => r.id == widget.shown).firstOrNull;
    if (shown != null) {
      return _RunTerminal(run: shown, runs: widget.runs, agent: widget.agent, surfaceOf: widget.terminals.ofRun, onShow: widget.onShow, onDetach: widget.terminals.drop);
    }
    return LayoutBuilder(builder: (context, box) {
      final side = box.maxWidth >= 860;
      final form = _form(context, s);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: SingleChildScrollView(child: form)),
        if (side) ...[const SizedBox(width: 16), SizedBox(width: 270, child: SingleChildScrollView(child: _summary(context)))],
      ]);
    });
  }

  Widget _form(BuildContext context, AppState s) {
    final c = context.c;
    final a = widget.agent;
    final wts = _worktrees(s);
    final active = s.activeWorktreeEntry;
    // Picked before, unless it's gone since.
    if (!wts.any((w) => w.$3 == f.worktree)) {
      f.worktree = active != null && wts.any((w) => w.$3 == s.workspace.absolutePathOf(active)) ? s.workspace.absolutePathOf(active) : wts.firstOrNull?.$3;
    }
    if (!s.workspace.repos.any((r) => r.name == f.newIn)) f.newIn = s.workspace.repos.firstOrNull?.name;
    final picked = wts.where((w) => w.$3 == f.worktree).firstOrNull;
    if (f.where == AgentWhereKind.worktree && picked != null) _lookUp(s, picked.$3);
    final link = parseRepoLink(f.link.text);
    final linkContext = link?.number == null
        ? const <AgentContextItem>[]
        : [AgentContextItem(kind: AgentContextKind.pullRequest, title: '${link!.ref} · ${link.name}', detail: 'diff + description', url: f.link.text.trim())];
    final found = switch (f.where) {
      AgentWhereKind.worktree => _found,
      AgentWhereKind.link => linkContext,
      _ => const <AgentContextItem>[],
    };
    final context0 = [
      for (final i in [...found, ...f.added]) if (!f.removed.contains(i.title)) i,
    ];
    final knowledge = widget.current.knowledge;
    final writes = agentWrites(a.tools);
    final busy = picked != null && s.agents.runs.any((r) => r.worktreePath == picked.$3 && r.status != AgentStatus.done);
    final (whereNote, whereWarn) = switch (f.where) {
      AgentWhereKind.worktree when a.isolation => ('Isolation is on: Kumo makes it a fresh worktree of ${picked?.$1.name ?? 'the repo'} from the default branch, so the files here don’t change.', false),
      AgentWhereKind.worktree when writes && busy => ('Another agent is working in this worktree, and this one can change files: pick a new worktree, or turn on Isolation in Edit.', true),
      AgentWhereKind.worktree when busy => ('Read-only, so it can share this worktree with the agent working there without touching its files.', false),
      AgentWhereKind.worktree => ('Nothing else runs in this worktree.', false),
      AgentWhereKind.newWorktree => ('Kumo makes ${a.name}-${widget.runs.length + 1} from the default branch first. It shows in the sidebar like any worktree.', false),
      AgentWhereKind.link => (link == null ? 'Paste a repository, branch or pull request link.' : '${link.ref.isEmpty ? link.name : '${link.ref} of ${link.name}'}: Kumo checks it out in a worktree, cloning ${link.name} first if it isn’t in this workspace.', link == null && f.link.text.trim().isNotEmpty),
      AgentWhereKind.folder => ('Not a repository: no worktree, no branch. One that edits works on the folder itself.', false),
      AgentWhereKind.scratch => ('An empty folder kept for a week, for research or writing. Files can open it.', false),
    };
    final contextDir = context0.isEmpty && knowledge.isEmpty ? '' : '~/.kumo/runs/${a.name}-${widget.runs.length + 1}';
    final clis = s.agents.agentClis;
    // Picked before, unless it's been disconnected since; else the first
    // whose plan isn't used up.
    f.cli = startWith(clis, f.cli, usedUpClis(clis, s.usage, DateTime.now()));
    final cli = f.cli ?? AgentCli.claude;
    final cmd = agentCommand(a, contextDir: contextDir, prompt: f.prompt.text, cli: cli);
    final canStart = !widget.fresh && !_starting && clis.isNotEmpty && switch (f.where) {
      AgentWhereKind.worktree => picked != null,
      AgentWhereKind.newWorktree => f.newIn != null,
      AgentWhereKind.link => link != null,
      AgentWhereKind.folder => f.folder.text.trim().isNotEmpty,
      AgentWhereKind.scratch => true,
    };

    Future<void> start() async {
      if (!canStart) return;
      final where = switch (f.where) {
        AgentWhereKind.worktree => AgentWhere.worktree(picked!.$3, repo: picked.$1.name),
        AgentWhereKind.newWorktree => AgentWhere.newWorktree(f.newIn!),
        AgentWhereKind.link => AgentWhere.link(f.link.text.trim()),
        AgentWhereKind.folder => AgentWhere.folder(f.folder.text.trim()),
        AgentWhereKind.scratch => const AgentWhere.scratch(),
      };
      setState(() => _starting = true);
      final run = await s.agentDefs.run(a, where, prompt: f.prompt.text.trim(), context: context0, cli: cli);
      if (!mounted) return;
      setState(() => _starting = false);
      if (run == null) {
        s.notify('${a.name} didn’t start: ${s.agentDefs.error ?? s.agents.error ?? 'unknown error'}');
        return;
      }
      f.prompt.clear();
      widget.onShow(run.id);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.runs.isNotEmpty) ...[_RunStrip(runs: widget.runs, shown: null, onShow: widget.onShow), const SizedBox(height: 18)],
      if (widget.fresh)
        _Note(icon: KIcons.info, text: 'Save ${widget.current.name.isEmpty ? 'it' : widget.current.name} first: an unsaved agent only runs in the playground.', color: c.warn, background: c.warnSoft)
      else if (widget.dirty)
        _Note(icon: KIcons.info, text: 'It runs as saved: your edits run once you save them (or try them in the playground).', color: c.text2, background: c.tile),
      if (widget.fresh || widget.dirty) const SizedBox(height: 14),
      _CliPick(clis: clis, cli: cli, agent: a, onChanged: (v) => setState(() => f.cli = v)),
      const SizedBox(height: 18),
      _Block(
        title: '1 · Where should it work?',
        hint: 'its terminal opens there',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (k, label, icon, hint) in const [
              (AgentWhereKind.worktree, 'A worktree', KIcons.branch, 'Of a repo in this workspace'),
              (AgentWhereKind.newWorktree, 'A new worktree', KIcons.add, 'From a repo’s default branch'),
              (AgentWhereKind.link, 'A link', KIcons.link, 'A repo, branch or PR URL'),
              (AgentWhereKind.folder, 'A folder', KIcons.folder, 'Anywhere, repo or not'),
              (AgentWhereKind.scratch, 'Scratch', KIcons.page, 'An empty folder'),
            ])
              _Option(label: label, hint: hint, icon: icon, selected: f.where == k, onTap: () => setState(() => f.where = k)),
          ]),
          const SizedBox(height: 10),
          switch (f.where) {
            AgentWhereKind.worktree => wts.isEmpty
                ? Text('Add a repository to a namespace first.', style: sans(12, color: c.text3))
                : KSelect<String>(
                    label: 'Worktree',
                    value: f.worktree!,
                    monospace: true,
                    items: [for (final (r, w, p) in wts) (p, '${r.name} · ${w.branch}')],
                    onChanged: (v) => setState(() {
                      f.worktree = v;
                      f.removed.clear();
                    }),
                  ),
            AgentWhereKind.newWorktree => s.workspace.repos.isEmpty
                ? Text('Add a repository to a namespace first.', style: sans(12, color: c.text3))
                : KSelect<String>(
                    label: 'Repository',
                    value: f.newIn!,
                    items: [for (final r in s.workspace.repos) (r.name, r.name)],
                    onChanged: (v) => setState(() => f.newIn = v),
                  ),
            AgentWhereKind.link => _Line(controller: f.link, monospace: true, label: 'Link', hint: 'https://github.com/owner/repo/pull/123', onChanged: (_) => setState(() {})),
            AgentWhereKind.folder => _Line(controller: f.folder, monospace: true, label: 'Folder', hint: '~/notes/platform', onChanged: (_) => setState(() {})),
            AgentWhereKind.scratch => Text('~/.kumo/scratch/${a.name}-${widget.runs.length + 1}', style: mono(12, color: c.text2)),
          },
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(whereWarn ? KIcons.shield : KIcons.info, size: 13, color: whereWarn ? c.warn : c.text3),
            const SizedBox(width: 6),
            Expanded(child: Text(whereNote, style: sans(11.5, color: whereWarn ? c.warn : c.text3, height: 1.4))),
          ]),
        ]),
      ),
      const SizedBox(height: 18),
      _Block(
        title: '2 · What should it know?',
        hint: cli == AgentCli.codex
            ? 'saved next to the run and pointed at in its first message: nothing lands in the repo'
            : 'saved next to the run and read with --add-dir: nothing lands in the repo',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final i in context0)
              _Chip(
                label: i.title,
                tag: agentContextTag(i.kind),
                tooltip: i.detail.isEmpty ? null : i.detail,
                onRemove: () => setState(() {
                  f.removed.add(i.title);
                  f.added.remove(i);
                }),
              ),
            for (final k in knowledge) _Chip(label: k, tag: 'MD', note: 'always', tooltip: 'Its knowledge: read on every run. Change it in Edit.'),
            _AddChip(label: 'Add', onTap: () => setState(() => _adding = !_adding)),
          ]),
          if (_adding) ...[
            const SizedBox(height: 8),
            Row(children: [
              KSegmented<AgentContextKind>(
                label: 'What to add',
                value: _addKind,
                height: 30,
                onChanged: (k) => setState(() => _addKind = k),
                items: const [
                  (AgentContextKind.task, 'Task', null),
                  (AgentContextKind.pullRequest, 'Pull request', null),
                  (AgentContextKind.link, 'Link', null),
                  (AgentContextKind.files, 'Files', null),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Line(
                  controller: _addText,
                  label: 'What to add',
                  hint: switch (_addKind) {
                    AgentContextKind.task => 'TSK-415',
                    AgentContextKind.pullRequest => '#519, or its link',
                    AgentContextKind.link => 'https://…',
                    _ => 'internal/discount/',
                  },
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              KButton(label: 'Add', height: 32, fontSize: 12, onTap: _add),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 18),
      _Block(
        title: '3 · What should it do?',
        hint: 'optional: its first message, then it’s your terminal',
        child: _Area(controller: f.prompt, minLines: 3, maxLines: 8, label: 'First message', hint: 'Leave it empty to start it and type in its terminal', onChanged: (_) => setState(() {})),
      ),
      const SizedBox(height: 16),
      Container(height: 1, color: c.divider),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10)),
        child: SelectableText(cmd, style: mono(11.5, color: c.text2, height: 1.5)),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        KButton.primary(label: _starting ? 'Starting…' : 'Start in its own terminal', icon: KIcons.terminal, onTap: canStart ? start : null),
        KButton(label: 'Try it in the playground', onTap: widget.onTry),
      ]),
    ]);
  }

  void _add() {
    final t = _addText.text.trim();
    if (t.isEmpty) return;
    final link = parseRepoLink(t);
    final item = switch (_addKind) {
      AgentContextKind.pullRequest => AgentContextItem(kind: AgentContextKind.pullRequest, title: link?.ref.isNotEmpty == true ? '${link!.ref} · ${link.name}' : (t.startsWith('#') || t.startsWith('!') ? t : '#$t'), detail: 'diff + description', url: link == null ? '' : t),
      AgentContextKind.link => AgentContextItem(kind: AgentContextKind.link, title: t.replaceFirst(RegExp(r'^https?://'), ''), detail: 'fetched once, saved as text', url: t),
      AgentContextKind.files => AgentContextItem(kind: AgentContextKind.files, title: t, detail: 'from the worktree'),
      _ => AgentContextItem(kind: AgentContextKind.task, title: t.toUpperCase(), detail: 'the whole ticket'),
    };
    setState(() {
      f.added.add(item);
      f.removed.remove(item.title);
      _addText.clear();
      _adding = false;
    });
  }

  Widget _summary(BuildContext context) {
    final c = context.c;
    final a = widget.agent;
    final facts = <(String, String, Color)>[
      ('Tools', a.tools.isEmpty ? 'none' : [...a.tools, ...a.mcpServers].join(', '), a.tools.isEmpty ? c.err : c.text),
      ('Model', a.model == 'inherit' ? 'Inherits the session’s' : agentModelLabel(a.model), c.text),
      ('Approvals', a.approvals.label, c.text),
      ('Limits', [if (a.maxTurns != null) '${a.maxTurns} turns', if (a.maxMinutes != null) '${a.maxMinutes} min', if (a.maxCostUsd != null) '\$${a.maxCostUsd}'].join(' · ').ifEmpty('none'), c.text),
      ('Isolation', a.isolation ? 'Own worktree each run' : 'Where you start it', c.text),
      ('Knowledge', a.knowledge.isEmpty ? 'none' : a.knowledge.join(', '), c.text),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('What it can do', style: sans(13, weight: FontWeight.w600, color: c.text))),
            KButton(label: 'Edit', height: 24, fontSize: 11.5, kind: KButtonKind.ghost, onTap: widget.onEdit),
          ]),
          const SizedBox(height: 6),
          for (final (k, v, color) in facts)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 74, child: Text(k, style: sans(12, color: c.text3))),
                Expanded(child: Text(v, style: sans(12, color: color, height: 1.4))),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Runs', style: sans(13, weight: FontWeight.w600, color: c.text)),
          const SizedBox(height: 6),
          if (widget.runs.isEmpty) Text('Not run yet.', style: sans(12, color: c.text3)),
          for (final r in widget.runs.take(6))
            KPressable(
              onTap: () => widget.onShow(r.id),
              semanticLabel: r.title,
              builder: (context, hover, focus) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Dot(_runDot(c, r)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text)),
                      Text(_runMeta(r), maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}

Color _runDot(KumoPalette c, AgentRun r) => switch (r.status) {
      AgentStatus.running => c.acc,
      AgentStatus.needsYou => c.warn,
      AgentStatus.done => r.exitCode == 0 ? c.ok : c.err,
    };

String _runMeta(AgentRun r) {
  final d = DateTime.now().difference(r.startedAt);
  final ago = d.inMinutes < 1 ? 'now' : (d.inMinutes < 60 ? '${d.inMinutes}m' : (d.inHours < 24 ? '${d.inHours}h' : '${d.inDays}d'));
  return switch (r.status) {
    AgentStatus.running => 'running · $ago',
    AgentStatus.needsYou => 'needs you · $ago',
    AgentStatus.done => r.exitCode == 0 ? 'done · $ago ago' : (r.exitCode == 130 ? 'stopped · $ago ago' : 'exited ${r.exitCode} · $ago ago'),
  };
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// The runs of an agent as tabs, and "New run".
class _RunStrip extends StatelessWidget {
  const _RunStrip({required this.runs, required this.shown, required this.onShow});
  final List<AgentRun> runs;
  final String? shown;
  final ValueChanged<String?> onShow;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget tab(String label, String meta, Color? dot, bool on, VoidCallback onTap) => KPressable(
          onTap: onTap,
          selected: on,
          semanticLabel: label,
          builder: (context, hover, focus) => Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: on ? c.accSoft : (hover ? c.tabActive : c.chip),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: on || focus ? c.acc : c.chipBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (dot != null) ...[Dot(dot), const SizedBox(width: 7)] else ...[Icon(KIcons.add, size: 13, color: c.text2), const SizedBox(width: 4)],
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, weight: on ? FontWeight.w600 : FontWeight.w500, color: on ? c.text : c.text2))),
              if (meta.isNotEmpty) ...[const SizedBox(width: 6), Text(meta, style: sans(11, color: c.text3))],
            ]),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        tab('New run', '', null, shown == null, () => onShow(null)),
        for (final r in runs) ...[const SizedBox(width: 4), tab(r.title, _runMeta(r), _runDot(c, r), r.id == shown, () => onShow(r.id))],
      ]),
    );
  }
}

/// A run's own terminal, in Agents: its whole output, and its input.
class _RunTerminal extends StatelessWidget {
  const _RunTerminal({required this.run, required this.runs, required this.agent, required this.surfaceOf, required this.onShow, required this.onDetach});

  /// Lets go of its terminal (closed).
  final ValueChanged<String> onDetach;
  final AgentRun run;
  final List<AgentRun> runs;
  final AgentDef agent;
  final TerminalSurface Function(AgentRun run) surfaceOf;
  final ValueChanged<String?> onShow;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final r = run;
    final done = r.status == AgentStatus.done;
    final now = DateTime.now();
    final worked = r.workedAt(now);
    // Its plan ran out: by what Kumo reads of its usage, or by what it said
    // last once it stopped working.
    final clis = s.agents.agentClis;
    final from = AgentCli.of(r.providerId);
    final out = usedUpClis(clis, s.usage, now);
    final spent = from == null ? null : out[from];
    final stopped = spent != null || (from != null && r.status != AgentStatus.running && saysLimitReached(r.lastLine));
    final other = from == null || !stopped ? null : goOnWith(clis, from, out);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _RunStrip(runs: runs, shown: r.id, onShow: onShow),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Icon(KIcons.branch, size: 13, color: c.text3),
        Text(r.worktreePath, style: mono(11.5, color: c.text2)),
        for (final i in r.context) _Chip(label: i.title, tag: agentContextTag(i.kind)),
        for (final k in agent.knowledge) _Chip(label: k, tag: 'MD'),
        if (!done && agent.maxMinutes != null)
          _Meter(
            label: 'Working',
            value: '${worked.inMinutes}:${(worked.inSeconds % 60).toString().padLeft(2, '0')} / ${agent.maxMinutes}:00',
            fraction: worked.inSeconds / (agent.maxMinutes! * 60),
            tooltip: 'Kumo ends the run after this much time working. Waiting for you doesn’t count.',
          ),
      ]),
      const SizedBox(height: 10),
      Expanded(
        child: TerminalPane(
          key: ValueKey('run-term-${r.id}'),
          surface: surfaceOf(r),
          icon: KIcons.terminal,
          iconColor: _runDot(c, r),
          active: !done,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Tooltip(
              message: 'Optional: the same session, next to the worktree’s other terminals',
              child: KButton(
                label: 'Terminal view',
                icon: KIcons.external,
                height: 26,
                fontSize: 11.5,
                kind: KButtonKind.ghost,
                onTap: () => s.openTerminal(r.terminalId, title: r.title, agent: true, directory: r.worktreePath),
              ),
            ),
            const SizedBox(width: 4),
            done
                ? KButton(
                    label: 'Close',
                    height: 26,
                    fontSize: 11.5,
                    onTap: () {
                      onShow(null);
                      onDetach(r.terminalId);
                      s.agents.dismiss(r.id);
                      final defs = s.agentDefs;
                      if (defs is MockAgentDefs) defs.finish(r.id, forget: true);
                    },
                  )
                : KButton(
                    label: 'Stop',
                    height: 26,
                    fontSize: 11.5,
                    onTap: () {
                      s.agents.stop(r.id);
                      final defs = s.agentDefs;
                      if (defs is MockAgentDefs) defs.finish(r.id);
                    },
                  ),
          ]),
          footer: other != null
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: _Note(
                    icon: KIcons.info,
                    text: '${spent == null ? '${from!.label} says it reached its plan’s limit.' : usedUpText(from!, spent, resetLabel(spent.resets, now))} '
                        'Go on with ${other.label}: ${agent.name} starts there in this folder, with the same first message. What’s done here stays.',
                    color: c.warn,
                    background: c.warnSoft,
                    action: KButton.primary(label: 'Go on with ${other.short}', height: 26, fontSize: 11.5, onTap: () => _goOn(context, s, other)),
                  ),
                )
              : done
              ? null
              : SizedBox(
                  height: kAgentNoteSpace,
                  child: r.asked
                      ? Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                            child: _Note(icon: KIcons.shield, text: 'It’s asking you something: answer it in its terminal.', color: c.warn, background: c.warnSoft),
                          ),
                        )
                      : null,
                ),
        ),
      ),
    ]);
  }
}

extension on _RunTerminal {
  /// Starts [agent] again on [to], where this run works: the CLI it ran on
  /// stopped at its plan's limit.
  Future<void> _goOn(BuildContext context, AppState s, AgentCli to) async {
    final from = AgentCli.of(run.providerId) ?? AgentCli.claude;
    final next = await s.agentDefs.run(agent, AgentWhere.folder(run.worktreePath), prompt: goOnPrompt(run.prompt, from), context: run.context, cli: to);
    if (next == null) {
      s.notify('${agent.name} didn’t start on ${to.label}: ${s.agentDefs.error ?? s.agents.error ?? 'unknown error'}');
      return;
    }
    onShow(next.id);
  }
}

/// A boxed note: an icon and a line.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.color, required this.background, this.action});
  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  /// A button at its end, for what the note suggests.
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(11)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 14, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: sans(12, color: color, height: 1.45))),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ]),
      );
}

/// A pane-colored card.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(13)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: c.pane, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.paneBorder)),
      child: child,
    );
  }
}

/// One of the "where" options: a card with an icon, a label and a hint.
class _Option extends StatelessWidget {
  const _Option({required this.label, required this.hint, required this.icon, required this.selected, required this.onTap});
  final String label;
  final String hint;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      builder: (context, hover, focus) => Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? c.accSoft : (hover ? c.tile : c.pane),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected || focus ? c.acc : c.paneBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 14, color: selected ? c.acc : c.text2),
            const SizedBox(width: 7),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: FontWeight.w600, color: selected ? c.acc : c.text))),
          ]),
          const SizedBox(height: 3),
          Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3, height: 1.35)),
        ]),
      ),
    );
  }
}

/// Which CLI it runs on, and what changes on it. One connected: said, not
/// asked. None: how to get one.
class _CliPick extends StatelessWidget {
  const _CliPick({required this.clis, required this.cli, required this.agent, required this.onChanged});

  /// The connected CLIs it can run on.
  final List<AgentCli> clis;
  final AgentCli cli;
  final AgentDef agent;
  final ValueChanged<AgentCli> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (clis.isEmpty) {
      return _Note(icon: KIcons.info, text: 'It runs on Claude Code, Codex or Copilot: connect one in Settings › AI agents.', color: c.warn, background: c.warnSoft);
    }
    final notes = agentCliNotes(agent, cli);
    final now = DateTime.now();
    final out = usedUpClis(clis, AppScope.of(context).usage, now);
    final spent = out[cli];
    final other = goOnWith(clis, cli, out);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // In a narrow column (the playground's) the choices take a line of
      // their own and share it.
      LayoutBuilder(builder: (context, box) {
        final title = Text('Runs with', style: sans(12, weight: FontWeight.w500, color: c.text));
        if (clis.length < 2) {
          return Wrap(spacing: 10, children: [title, Text(cli.label, style: sans(12, color: c.text2))]);
        }
        final narrow = box.maxWidth < 120.0 * clis.length + 80;
        final pick = KSegmented<AgentCli>(label: 'Runs with', value: cli, height: 28, expand: narrow, onChanged: onChanged, items: [for (final x in clis) (x, x.short, out.containsKey(x) ? 'out' : null)]);
        if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [title, const SizedBox(height: 6), pick]);
        return Row(children: [title, const SizedBox(width: 10), pick]);
      }),
      if (spent != null) ...[
        const SizedBox(height: 8),
        _Note(
          icon: KIcons.info,
          text: '${usedUpText(cli, spent, resetLabel(spent.resets, now))}${other == null ? ' Connect another CLI in Settings › AI agents to run it now.' : ''}',
          color: c.warn,
          background: c.warnSoft,
          action: other == null ? null : KButton(label: 'Use ${other.short}', height: 26, fontSize: 11.5, onTap: () => onChanged(other)),
        ),
      ],
      if (notes.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(11, 7, 11, 9),
          decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Its file is Claude Code’s. On ${cli.label}:', style: sans(11.5, weight: FontWeight.w500, color: c.text2)),
            for (final n in notes) CheckLine(n),
          ]),
        ),
      ],
    ]);
  }
}
