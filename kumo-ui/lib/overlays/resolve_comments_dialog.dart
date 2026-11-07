import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/agents_source.dart';
import '../data/git_agent_prompts.dart';
import '../data/models.dart';
import '../data/pipelines_source.dart';
import '../data/repo_activity.dart';
import '../data/repo_history.dart';
import '../platform/open_url.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';
import 'agent_files.dart';
import 'pr_description_dialog.dart' show AgentPickChip, prAgentHome, prAgentTarget;

/// "Resolve comments" on [pr]: pick the open review threads, an agent
/// changes the code for each (committing, not pushing) and drafts a reply;
/// you check every reply, then push and post them in one go.
Future<void> showResolveCommentsDialog(BuildContext context, {required RepoActivitySource source, required RepoPullRequest pr}) {
  final c = context.c;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: c.isDark ? const Color(0x66000000) : const Color(0x33141428),
    transitionDuration: const Duration(milliseconds: 140),
    transitionBuilder: (context, anim, _, child) => FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: child),
    pageBuilder: (context, _, __) => Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
        child: Material(type: MaterialType.transparency, child: ResolveCommentsDialog(source: source, pr: pr)),
      ),
    ),
  );
}

enum _Phase { loading, setup, working, done }

class ResolveCommentsDialog extends StatefulWidget {
  const ResolveCommentsDialog({super.key, required this.source, required this.pr});
  final RepoActivitySource source;
  final RepoPullRequest pr;

  @override
  State<ResolveCommentsDialog> createState() => _ResolveCommentsDialogState();
}

class _ResolveCommentsDialogState extends State<ResolveCommentsDialog> {
  _Phase _phase = _Phase.loading;
  List<ReviewThread> _threads = const [];
  final _off = <String>{};
  String? _provider;
  ResolveMode _mode = ResolveMode.replyAndResolve;
  String? _error;

  String? _runId;
  AgentFileWatch? _files;
  Timer? _poll;
  int _step = 0;
  AppState? _app;
  bool _applying = false;

  /// The agent's outcome per thread id, and your edits to it.
  final _answers = <String, ThreadAnswer>{};
  final _replies = <String, TextEditingController>{};
  final _resolve = <String, bool>{};

  RepoPullRequest get pr => widget.pr;
  String get _host => CiProvider.ofHost(widget.source.repo.host)?.hostName ?? widget.source.repo.host;
  List<ReviewThread> get _open => [for (final t in _threads) if (!t.resolved) t];
  List<ReviewThread> get _chosen => [for (final t in _open) if (!_off.contains(t.id)) t];

  @override
  void initState() {
    super.initState();
    widget.source.reviewThreads(pr).then((all) {
      if (!mounted) return;
      setState(() {
        _threads = all;
        _phase = _Phase.setup;
      });
    }, onError: (Object e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _phase = _Phase.setup;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).agents.loadProviders();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.read(context);
  }

  @override
  void dispose() {
    _poll?.cancel();
    // A one-off session: it ends with the dialog (unless handed to its tab).
    final id = _runId;
    final s = _app;
    if (id != null && s != null && _phase != _Phase.done) {
      final run = s.agents.runs.where((r) => r.id == id).firstOrNull;
      if (run != null && run.status != AgentStatus.done) s.agents.stop(id).ignore();
    }
    _files?.delete();
    for (final c in _replies.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- The agent ----

  Future<void> _start() async {
    final s = AppScope.read(context);
    final chosen = _chosen;
    if (chosen.isEmpty) return;
    setState(() {
      _phase = _Phase.working;
      _step = 0;
      _error = null;
    });
    if (!s.agents.live) return _makeUp(chosen);
    final home = prAgentHome(s, widget.source.repo, pr);
    if (home == null) return _fail('${widget.source.repo.name} has no checkout on this Mac.');
    final files = _files = AgentFileWatch.fresh('${widget.source.repo.name}-${pr.id}-threads', 'json');
    final run = await s.agents.start(
      providerId: _provider ?? s.agents.connected.firstOrNull?.id,
      worktreePath: home.$1,
      prompt: resolveCommentsPrompt(prAgentTarget(widget.source, pr, home.$2), chosen, answersPath: files.path, mode: _mode),
      title: '${pr.number} · Review comments',
    );
    if (!mounted) {
      if (run != null) s.agents.stop(run.id).ignore();
      return;
    }
    if (run == null) return _fail(s.agents.error ?? 'The agent didn’t start.');
    _runId = run.id;
    _poll = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) return;
      final got = files.poll();
      if (got == null) return setState(() {});
      final answers = ThreadAnswer.parse(got.$1);
      if (answers.isEmpty) return;
      _poll?.cancel();
      _finish(answers);
    });
  }

  void _fail(String why) {
    if (!mounted) return;
    setState(() {
      _phase = _runId == null ? _Phase.setup : _Phase.working;
      _error = why;
    });
  }

  /// Without the daemon: the design's outcomes, one thread at a time.
  void _makeUp(List<ReviewThread> chosen) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 650), (t) {
      if (!mounted) return;
      if (_step < chosen.length) return setState(() => _step++);
      t.cancel();
      _finish([
        for (final th in chosen)
          if (mockThreadWork[th.id] case (final changed, final commit, final reply))
            ThreadAnswer(thread: th.id, changed: changed, commit: commit, reply: reply)
          else
            ThreadAnswer(thread: th.id, reply: 'Done.'),
      ]);
    });
  }

  void _finish(List<ThreadAnswer> answers) {
    setState(() {
      for (final a in answers) {
        _answers[a.thread] = a;
        _replies[a.thread] = TextEditingController(text: a.reply);
        _resolve[a.thread] = _mode == ResolveMode.replyAndResolve;
      }
      _phase = _Phase.done;
    });
  }

  List<String> get _commits => [
        ...{
          for (final a in _answers.values)
            if (a.commit.isNotEmpty) a.commit,
        },
      ];

  // ---- Push and post ----

  Future<void> _apply() async {
    if (_applying) return;
    final s = AppScope.read(context);
    final navigator = Navigator.of(context);
    final posting = _mode != ResolveMode.codeOnly;
    final done = [for (final t in _chosen) if (_answers.containsKey(t.id)) t];
    final commits = _commits;
    setState(() {
      _applying = true;
      _error = null;
    });
    // The agent pushes its own commits: it's in the worktree, with your git.
    final id = _runId;
    final lines = [
      for (final t in done)
        if ((_replies[t.id]?.text.trim() ?? '').isNotEmpty) '- [${t.id}] ${t.where}${_resolve[t.id] == true ? ' (resolve)' : ''}: ${_replies[t.id]!.text.trim()}',
    ];
    final post = posting && !widget.source.threadsWritable && lines.isNotEmpty
        ? 'Post these replies on ${pr.number}${_mode == ResolveMode.replyAndResolve ? ' and resolve the threads marked so' : ''}:\n${lines.join('\n')}'
        : '';
    if ((commits.isNotEmpty || post.isNotEmpty) && id != null && s.agents.live) {
      final ok = await s.agents.addContext(
        id,
        AgentContextItem(kind: AgentContextKind.doc, title: '${pr.number} · push'),
        text: [if (commits.isNotEmpty) 'Push the commits now (`git push`). Don’t change anything else.', if (post.isNotEmpty) post].join(' Then: '),
      );
      if (!ok) {
        if (mounted) {
          setState(() {
            _applying = false;
            _error = s.agents.error ?? 'Couldn’t reach the agent to push.';
          });
        }
        return;
      }
    }
    var posted = 0, resolved = 0;
    if (posting && widget.source.threadsWritable) {
      try {
        for (final t in done) {
          final reply = _replies[t.id]?.text.trim() ?? '';
          final res = _resolve[t.id] == true;
          if (reply.isEmpty && !res) continue;
          await widget.source.answerThread(pr, t, reply: reply, resolve: res);
          if (reply.isNotEmpty) posted++;
          if (res) resolved++;
        }
      } on Object catch (e) {
        if (mounted) {
          setState(() {
            _applying = false;
            _error = 'Posted $posted, then: $e';
          });
        }
        return;
      }
    }
    if (!mounted) return;
    navigator.maybePop();
    final parts = [
      if (commits.isNotEmpty) 'pushed ${commits.length} ${commits.length == 1 ? 'commit' : 'commits'}',
      if (posting && widget.source.threadsWritable) '$posted ${posted == 1 ? 'reply' : 'replies'}${resolved > 0 ? ', $resolved resolved' : ''}',
      if (posting && !widget.source.threadsWritable && s.agents.live) 'the agent posts the replies',
    ];
    final msg = parts.isEmpty ? 'Nothing to push or post' : parts.join(', ');
    s.notify('${msg[0].toUpperCase()}${msg.substring(1)} on ${pr.number}', action: pr.url.isEmpty ? null : 'Open', onAction: pr.url.isEmpty ? null : () => openUrl(pr.url));
  }

  // ---- Building ----

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: GlassOverlay(
        width: 680,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(10)),
              child: Icon(KIcons.chat, size: 16, color: c.acc),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Resolve comments on ${pr.number}', style: sans(14, weight: FontWeight.w600, color: c.text)),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: pr.title, style: sans(12, color: c.text2)),
                    TextSpan(text: '  ·  ', style: sans(12, color: c.text3)),
                    TextSpan(text: pr.branch, style: mono(11, color: c.text3)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            KIconButton(icon: KIcons.close, label: 'Close', onTap: () => Navigator.of(context).maybePop()),
          ]),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: _content(context, s)),
            ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, maxLines: 4, overflow: TextOverflow.ellipsis, style: sans(12, color: c.err))),
          const SizedBox(height: 12),
          ..._footer(context, s),
        ]),
      ),
    );
  }

  List<Widget> _content(BuildContext context, AppState s) {
    final c = context.c;
    if (_phase == _Phase.loading) {
      return [Padding(padding: const EdgeInsets.all(20), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.acc))))];
    }
    final open = _open;
    if (open.isEmpty) {
      return [Text(_threads.isEmpty ? 'No review threads on ${pr.number}.' : 'Every review thread is resolved.', style: sans(12.5, color: c.text2))];
    }
    final setup = _phase == _Phase.setup;
    final working = _phase == _Phase.working;
    final shown = setup ? open : _chosen;
    final run = _runId == null ? null : s.agents.runs.where((r) => r.id == _runId).firstOrNull;
    return [
      if (setup && s.agents.connected.isNotEmpty) ...[
        Text('AGENT', style: microLabel(c)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in s.agents.connected)
            AgentPickChip(provider: p, selected: p.id == (_provider ?? s.agents.connected.firstOrNull?.id), onTap: () => setState(() => _provider = p.id)),
        ]),
        const SizedBox(height: 14),
      ],
      if (setup)
        Row(children: [
          Text('${open.length} OPEN ${open.length == 1 ? 'THREAD' : 'THREADS'}', style: microLabel(c)),
          const Spacer(),
          KButton(
            label: _off.isEmpty ? 'None' : 'All',
            kind: KButtonKind.ghost,
            height: 24,
            fontSize: 12,
            onTap: () => setState(() => _off.isEmpty ? _off.addAll(open.map((t) => t.id)) : _off.clear()),
          ),
        ]),
      if (working)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: run?.status == AgentStatus.needsYou ? c.warn : c.acc)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                run == null
                    ? 'Working on thread ${(_step + 1).clamp(1, shown.length)} of ${shown.length}…'
                    : run.status == AgentStatus.needsYou
                        ? '${run.providerName} is waiting for you (a permission, or a question).'
                        : (run.lastLine.trim().isEmpty ? '${run.providerName} is working through the threads…' : run.lastLine.trim()),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: sans(12.5, color: c.text),
              ),
            ),
          ]),
        ),
      const SizedBox(height: 6),
      for (var i = 0; i < shown.length; i++) ...[
        _ThreadCard(
          thread: shown[i],
          me: widget.source.currentUser,
          pickable: setup,
          picked: !_off.contains(shown[i].id),
          onPick: () => setState(() => _off.contains(shown[i].id) ? _off.remove(shown[i].id) : _off.add(shown[i].id)),
          status: working && run == null ? (i < _step ? true : (i == _step ? false : null)) : (_phase == _Phase.done ? true : null),
          answer: _answers[shown[i].id],
          reply: _mode == ResolveMode.codeOnly ? null : _replies[shown[i].id],
          resolve: _resolve[shown[i].id] ?? false,
          onResolve: (v) => setState(() => _resolve[shown[i].id] = v),
        ),
        const SizedBox(height: 8),
      ],
      if (setup && _threads.length > open.length) Text('${_threads.length - open.length} already resolved', style: sans(11.5, color: c.text3)),
      if (setup) ...[
        const SizedBox(height: 10),
        Row(children: [
          Text('THEN', style: microLabel(c)),
          const SizedBox(width: 10),
          KSegmented<ResolveMode>(
            label: 'Then',
            height: 26,
            value: _mode,
            onChanged: (m) => setState(() => _mode = m),
            items: [for (final m in ResolveMode.values) (m, m.label, null)],
          ),
        ]),
        const SizedBox(height: 4),
        Text(_mode.hint, style: sans(11.5, color: c.text3)),
      ],
    ];
  }

  List<Widget> _footer(BuildContext context, AppState s) {
    final c = context.c;
    final run = _runId == null ? null : s.agents.runs.where((r) => r.id == _runId).firstOrNull;
    final home = prAgentHome(s, widget.source.repo, pr);
    final commits = _commits;
    final replies = _mode == ResolveMode.codeOnly ? 0 : [for (final t in _chosen) if ((_replies[t.id]?.text.trim() ?? '').isNotEmpty) t].length;
    final note = switch (_phase) {
      _Phase.loading || _Phase.setup => !s.agents.live
          ? 'Without Kumo’s engine the agent’s work is made up, to show the flow.'
          : home == null
              ? '${widget.source.repo.name} has no checkout on this Mac.'
              : 'It works in ${home.$2 ? 'the PR’s worktree' : 'the main checkout (it switches to ${pr.branch})'}: it commits but doesn’t push, and nothing is posted until you say so.',
      _Phase.working => 'Read-only on $_host until you approve.',
      _Phase.done => '${commits.isEmpty ? 'No commits' : '${commits.length} ${commits.length == 1 ? 'commit' : 'commits'} on ${pr.branch}, not pushed'}. Questions only get a reply.'
          '${!widget.source.threadsWritable && _mode != ResolveMode.codeOnly ? ' Kumo can’t post on $_host yet: the agent posts the replies.' : ''}',
    };
    return [
      Text(note, style: sans(11, color: c.text3, height: 1.4)),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          if (_phase == _Phase.setup || _phase == _Phase.loading) ...[
            KButton(label: 'Cancel', onTap: () => Navigator.of(context).maybePop()),
            KButton.primary(
              label: 'Work on ${_chosen.length} ${_chosen.length == 1 ? 'thread' : 'threads'}',
              icon: KIcons.sparkle,
              onTap: _phase == _Phase.loading || _chosen.isEmpty || (s.agents.live && (home == null || s.agents.connected.isEmpty)) ? null : _start,
            ),
          ],
          if (_phase == _Phase.working) ...[
            if (run != null)
              KButton(
                label: 'Open its tab',
                onTap: () {
                  _poll?.cancel();
                  _runId = null;
                  Navigator.of(context).maybePop();
                  s.openTerminal(run.terminalId, title: run.title, agent: true, directory: run.worktreePath);
                },
              ),
            KButton(
              label: 'Stop',
              onTap: () {
                _poll?.cancel();
                final id = _runId;
                if (id != null) s.agents.stop(id).ignore();
                setState(() {
                  _runId = null;
                  _phase = _Phase.setup;
                });
              },
            ),
          ],
          if (_phase == _Phase.done) ...[
            if (run != null)
              KButton(
                label: 'Review in its tab',
                onTap: () {
                  _runId = null;
                  Navigator.of(context).maybePop();
                  s.openTerminal(run.terminalId, title: run.title, agent: true, directory: run.worktreePath);
                },
              ),
            KButton.primary(
              label: _applying
                  ? 'Working…'
                  : [
                      if (commits.isNotEmpty) 'Push ${commits.length} ${commits.length == 1 ? 'commit' : 'commits'}',
                      if (replies > 0) '${commits.isNotEmpty ? 'post' : 'Post'} $replies ${replies == 1 ? 'reply' : 'replies'}',
                    ].join(' and ').ifEmpty('Done'),
              icon: KIcons.upload,
              onTap: _applying ? null : _apply,
            ),
          ],
        ]),
      ),
    ];
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.thread,
    required this.me,
    required this.pickable,
    required this.picked,
    required this.onPick,
    required this.status,
    required this.answer,
    required this.reply,
    required this.resolve,
    required this.onResolve,
  });
  final ReviewThread thread;
  final String? me;
  final bool pickable;
  final bool picked;
  final VoidCallback onPick;

  /// null: not started; false: working on it; true: done.
  final bool? status;
  final ThreadAnswer? answer;
  final TextEditingController? reply;
  final bool resolve;
  final ValueChanged<bool> onResolve;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = thread;
    final a = answer;
    final (kindFg, kindBg) = switch (t.kind) {
      ThreadKind.change => (c.acc, c.accSoft),
      ThreadKind.nit => (c.text2, c.chip),
      ThreadKind.question => (c.purple, c.purple.withAlpha(36)),
    };
    final reply = this.reply;
    final initial = t.author.isEmpty ? '?' : String.fromCharCode(t.author.runes.first).toUpperCase();
    return Opacity(
      opacity: pickable && !picked ? 0.55 : (status == null && !pickable ? 0.65 : 1),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.tile,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: status == false ? c.acc : const Color(0x00000000)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (pickable)
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 10),
                child: KPressable(
                  onTap: onPick,
                  semanticLabel: 'Include ${t.where}',
                  selected: picked,
                  builder: (context, hover, focus) => Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: picked ? c.accFill : null,
                      borderRadius: BorderRadius.circular(4.5),
                      border: Border.all(color: picked ? const Color(0x00000000) : c.text3, width: 1.4),
                    ),
                    child: picked ? Icon(Icons.check_rounded, size: 12, color: c.accText) : null,
                  ),
                ),
              )
            else if (status != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: status! ? c.okSoft : c.accSoft, shape: BoxShape.circle),
                  child: status! ? Icon(KIcons.check, size: 11, color: c.ok) : SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.5, color: c.acc)),
                ),
              ),
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.author == me ? c.accSoft : c.chip, shape: BoxShape.circle),
              child: Text(initial, style: sans(10, weight: FontWeight.w700, color: t.author == me ? c.acc : c.text2, height: 1)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(t.author, style: sans(11.5, weight: FontWeight.w600, color: c.text2)),
                  const SizedBox(width: 8),
                  Flexible(child: Text(t.where, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(color: kindBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(t.kind.label, style: sans(10.5, weight: FontWeight.w600, color: kindFg, height: 1.6)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(t.body, style: sans(12.5, color: c.text, height: 1.45)),
              ]),
            ),
          ]),
          if (a != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (a.changed.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: c.okSoft, borderRadius: BorderRadius.circular(9)),
                    child: Row(children: [
                      Icon(KIcons.commit, size: 13, color: c.ok),
                      const SizedBox(width: 8),
                      Expanded(child: Text(a.changed, style: sans(12, color: c.text))),
                      if (a.commit.isNotEmpty) Text(a.commit, style: mono(11, color: c.text3)),
                    ]),
                  ),
                if (reply != null) ...[
                  const SizedBox(height: 8),
                  Text('Reply to ${t.author}', style: sans(11, color: c.text3)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(9), border: Border.all(color: c.chipBorder)),
                    child: TextField(
                      controller: reply,
                      minLines: 1,
                      maxLines: 4,
                      style: sans(12.5, color: c.text, height: 1.45),
                      cursorColor: c.acc,
                      decoration: const InputDecoration.collapsed(hintText: 'No reply'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  KCheck(value: resolve, label: 'Resolve the thread', onChanged: onResolve),
                ],
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}
