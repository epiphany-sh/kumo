part of '../task_detail.dart';

/// What to do with the ticket: the footer pinned to the side panel, or the
/// top of the large view's right column.
extension _Actions on _TaskDetailState {
  List<Widget> _actions(_View v) {
    final s = AppScope.of(context);
    final t = v.task!;
    final links = s.tasks.linksOf(t.id);
    final formOpen = widget.expanded || _formOpen;
    return [
      if (links.isNotEmpty) ...[_worktrees(s, t, links), const SizedBox(height: 12)],
      _moveTo(s, v),
      const SizedBox(height: 12),
      if (formOpen) _startForm(s, t, startTitle: links.isEmpty ? 'Start in a worktree' : 'Start another worktree') else _startButton(s, t, links),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, maxLines: 4, overflow: TextOverflow.ellipsis, style: sans(12, color: context.c.err)),
      ],
      const SizedBox(height: 6),
      _agentGets(v),
    ];
  }

  Future<void> _move(TasksSource tasks, String id, TaskColumn column) async {
    _set(() {
      _moving = true;
      _error = null;
    });
    final ok = await tasks.setStatus(id, column);
    if (!mounted) return;
    _set(() {
      _moving = false;
      if (!ok) _error = tasks.error;
    });
  }

  Future<void> _start(AppState s, TaskEntry task, Repo repo) async {
    _set(() {
      _busy = true;
      _error = null;
    });
    String? error;
    var failed = false;
    try {
      error = await s.startTask(task, repo: repo, branch: _branch.text.trim(), base: _base, agent: _agentOn, providerId: _agent);
    } on Object catch (e) {
      error = '$e';
      failed = true;
    }
    if (!mounted) return;
    _set(() {
      _busy = false;
      _error = error;
      if (!failed) _formOpen = false;
    });
  }

  Widget _moveTo(AppState s, _View v) {
    final c = context.c;
    final t = v.task!;
    final writable = v.source?.writable ?? const <TaskColumn>{};
    final blocked = v.moveBlocked;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Move to', style: sans(11.5, color: c.text3)),
        const SizedBox(width: 12),
        if (blocked && writable.isNotEmpty)
          Flexible(
            child: Text('Moving needs ${t.kind.label}. Try again when it’s reachable.',
                textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(11.5, weight: FontWeight.w500, color: c.warn)),
          ),
      ]),
      const SizedBox(height: 6),
      if (writable.isEmpty)
        Text('${t.kind.label} tasks are read only here: change them in ${t.kind.label}.', style: sans(12, color: c.text3))
      else
        Opacity(
          opacity: _moving || blocked ? 0.55 : 1,
          child: KSegmented<TaskColumn>(
            expand: true,
            height: 30,
            label: 'Move to',
            value: t.column,
            items: [for (final (col, name) in shortTaskColumns) if (writable.contains(col) || col == t.column) (col, name, null)],
            onChanged: (col) {
              if (!_moving && !blocked && col != t.column && writable.contains(col)) _move(s.tasks, t.id, col);
            },
          ),
        ),
    ]);
  }

  /// "feat/PRC-11355-migraciones · price-admin · Claude Code".
  String _preview(AppState s) {
    final repo = _repo == null ? s.workspace.repos.firstOrNull : s.workspace.repo(_repo!);
    final agents = s.agents.connected;
    final agent = agents.where((a) => a.id == _agent).firstOrNull ?? agents.firstOrNull;
    return [
      _branch.text.trim(),
      repo?.name ?? '—',
      if (_agentOn && agent != null) agent.name,
    ].where((x) => x.isNotEmpty).join(' · ');
  }

  Widget _startButton(AppState s, TaskEntry t, List<TaskLinkInfo> links) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KButton.primary(
        label: links.isEmpty ? 'Start in a worktree' : 'Start another worktree',
        icon: KIcons.sparkle,
        expand: true,
        height: 36,
        onTap: () => _set(() => _formOpen = true),
      ),
      const SizedBox(height: 8),
      Tooltip(
        message: 'Branch, repository and agent it will use',
        child: Text(_preview(s), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3)),
      ),
    ]);
  }

  Widget _startForm(AppState s, TaskEntry t, {required String startTitle}) {
    final c = context.c;
    final repos = s.workspace.repos;
    final repo = _repo == null ? null : s.workspace.repo(_repo!);
    final agents = s.agents.connected;
    final bases = _branches == null ? <String>[if (_base.isNotEmpty) _base] : [_branches!.current, for (final l in _branches!.local) if (l != _branches!.current) l];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(KIcons.sparkle, size: 15, color: c.acc),
        const SizedBox(width: 8),
        Expanded(child: Text(startTitle, style: sans(13.5, weight: FontWeight.w600, color: c.text))),
        if (!widget.expanded) KButton(label: 'Cancel', kind: KButtonKind.ghost, height: 26, fontSize: 12, onTap: () => _set(() => _formOpen = false)),
      ]),
      const SizedBox(height: 10),
      if (repos.isEmpty)
        Text('Add a repository to a namespace first: the worktree is created in it.', style: sans(12, color: c.text3))
      else ...[
        Row(children: [
          Expanded(
            child: KSelect<String>(
              label: 'Repository',
              value: _repo ?? repos.first.id,
              items: [for (final r in repos) (r.id, r.name)],
              onChanged: _pickRepo,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: bases.where((b) => b.isNotEmpty).isEmpty
                ? KField(label: 'Base branch', controller: TextEditingController(text: '…'), monospace: true)
                : KSelect<String>(
                    label: 'Base branch',
                    monospace: true,
                    value: _base.isEmpty ? bases.first : _base,
                    items: [for (final b in bases) if (b.isNotEmpty) (b, b)],
                    onChanged: (v) => _set(() => _base = v),
                  ),
          ),
        ]),
        const SizedBox(height: 10),
        KField(label: 'New branch', controller: _branch, monospace: true),
        const SizedBox(height: 10),
        Row(children: [
          KSwitch(value: _agentOn && agents.isNotEmpty, onChanged: agents.isEmpty ? (_) {} : (v) => _set(() => _agentOn = v), label: 'Start an agent'),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              agents.isEmpty ? 'No agent connected: just the worktree' : 'Start an agent with the task as its prompt',
              style: sans(12, color: c.text2),
            ),
          ),
        ]),
        if (_agentOn && agents.isNotEmpty) ...[
          const SizedBox(height: 10),
          KSelect<String>(
            label: 'Agent',
            value: _agent != null && agents.any((a) => a.id == _agent) ? _agent! : agents.first.id,
            items: [for (final a in agents) (a.id, a.name)],
            onChanged: (v) => _set(() => _agent = v),
          ),
        ],
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: _branch,
          builder: (context, _) => KButton.primary(
            label: _busy ? 'Creating…' : (_agentOn && agents.isNotEmpty ? 'Create worktree and start agent' : 'Create worktree'),
            expand: true,
            height: 36,
            onTap: _busy || repo == null || _branch.text.trim().isEmpty ? null : () => _start(s, t, repo),
          ),
        ),
      ],
    ]);
  }

  Widget _worktrees(AppState s, TaskEntry t, List<TaskLinkInfo> links) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(KIcons.branch, size: 14, color: c.acc),
        const SizedBox(width: 6),
        Text('Being worked on', style: sans(11.5, weight: FontWeight.w600, color: c.text2)),
      ]),
      const SizedBox(height: 6),
      for (final link in links) ...[
        Builder(builder: (context) {
          final run = runIn(s.agents.runs, link.worktreePath);
          final (dot, color, status) = switch (run?.status) {
            AgentStatus.needsYou => (c.warn, c.warn, 'needs you'),
            AgentStatus.done => (c.ok, c.ok, 'finished'),
            null => (c.text3, c.text2, ''),
            _ => (c.acc, c.acc, 'working'),
          };
          return Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
            decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Dot(dot, size: 7),
              const SizedBox(width: 9),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(link.branch, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, weight: FontWeight.w500, color: c.text)),
                  if (run != null)
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${run.providerName} · $status', style: sans(11.5, weight: FontWeight.w600, color: color)),
                        if (run.lastLine.isNotEmpty) TextSpan(text: ' · ${run.lastLine}', style: sans(11.5, color: c.text3)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(link.worktreePath, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3)),
                ]),
              ),
              if (run != null && run.status != AgentStatus.done)
                KButton(
                  label: 'Terminal',
                  icon: KIcons.terminal,
                  kind: KButtonKind.ghost,
                  height: 26,
                  fontSize: 12,
                  onTap: () => s.openTerminal(run.terminalId, title: run.title, agent: true, directory: run.worktreePath),
                ),
              KIconButton(icon: KIcons.close, iconSize: 14, size: 26, label: 'Unlink ${link.branch} from this ticket', onTap: () => s.tasks.unlink(t.id, link.worktreePath)),
            ]),
          );
        }),
        const SizedBox(height: 6),
      ],
    ]);
  }

  Widget _agentGets(_View v) {
    final c = context.c;
    final d = v.detail;
    final ac = d == null ? const <(bool, String)>[] : checklistOf(d.acceptanceCriteria);
    final nAc = ac.isNotEmpty ? ac.length : (d != null && d.acceptanceCriteria.trim().isNotEmpty ? 1 : 0);
    final nC = d?.comments.length ?? 0;
    final hasDesc = d != null && d.description.trim().isNotEmpty;
    final items = [
      ('Title', true, ''),
      ('Description', hasDesc, hasDesc ? '' : 'empty'),
      ('Acceptance criteria', nAc > 0, nAc > 0 ? (ac.isNotEmpty ? '$nAc items' : '') : 'none on this ticket'),
      if (v.hasComments) ('Comments', nC > 0, nC > 0 ? 'all $nC' : 'none yet'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: KPressable(
          onTap: () => _set(() => _agentInfo = !_agentInfo),
          semanticLabel: 'What the agent gets',
          selected: _agentInfo,
          builder: (context, hover, focus) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: hover ? c.tile : null,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: focus ? c.acc : Colors.transparent, width: 1.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(KIcons.info, size: 14, color: c.text3),
              const SizedBox(width: 6),
              Text('What the agent gets', style: sans(12.5, color: c.text2)),
              const SizedBox(width: 4),
              Icon(_agentInfo ? KIcons.chevronDown : KIcons.chevronRight, size: 16, color: c.text3),
            ]),
          ),
        ),
      ),
      if (_agentInfo)
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Starting from this ticket, the agent’s first prompt includes:', style: sans(12, color: c.text2)),
            const SizedBox(height: 8),
            for (final (label, on, note) in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Icon(on ? KIcons.check : KIcons.remove, size: 14, color: on ? c.ok : c.text3),
                  const SizedBox(width: 8),
                  Text(label, style: sans(12.5, color: on ? c.text : c.text3)),
                  if (note.isNotEmpty) ...[const SizedBox(width: 6), Text('· $note', style: sans(12, color: c.text3))],
                ]),
              ),
            const SizedBox(height: 6),
            Text('Attachments, subtasks and linked issues stay out; the ticket link goes in so the agent can look them up.', style: sans(11.5, color: c.text3, height: 1.45)),
            if (v.offBasic) ...[
              const SizedBox(height: 4),
              Text('Offline: only the title and the fields saved on the card go in.', style: sans(11.5, color: c.warn, height: 1.45)),
            ],
          ]),
        ),
    ]);
  }
}
