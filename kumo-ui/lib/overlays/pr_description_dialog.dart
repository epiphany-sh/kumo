import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/agents_source.dart';
import '../data/ai_usage_source.dart';
import '../data/models.dart';
import '../data/pipelines_source.dart';
import '../data/pr_agent_prompts.dart';
import '../data/repo_activity.dart';
import '../data/tasks_source.dart';
import '../editor/markdown_preview.dart';
import '../platform/open_url.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';

/// Where an agent works on [pr]: its branch's worktree (true), else the
/// repository's main checkout (false), as an absolute path. Null when the
/// repository has no checkout at all.
(String, bool)? prAgentHome(AppState s, Repo repo, RepoPullRequest pr) {
  final trees = s.worktreesOf(repo);
  final own = trees.where((w) => w.branch == pr.branch).firstOrNull;
  if (own != null) return (s.workspace.absolutePathOf(own), true);
  final main = trees.where((w) => w.isMain).firstOrNull ?? trees.firstOrNull;
  if (main != null) return (s.workspace.absolutePathOf(main), false);
  final path = repo.path;
  return path == null || path.isEmpty ? null : (path, false);
}

/// What the agent is told about [pr] and where it runs.
PrAgentTarget prAgentTarget(RepoActivitySource source, RepoPullRequest pr, bool inWorktree) => PrAgentTarget(
      pr: pr,
      repoName: source.repo.name,
      host: source.repo.host,
      base: pr.base.isNotEmpty ? pr.base : source.mainBranch,
      inWorktree: inWorktree,
    );

/// The team's pull request template in [root], relative; null when none.
String? prTemplateIn(String root) {
  const candidates = [
    '.github/pull_request_template.md',
    '.github/PULL_REQUEST_TEMPLATE.md',
    'pull_request_template.md',
    'docs/pull_request_template.md',
    '.gitlab/merge_request_templates/Default.md',
  ];
  for (final c in candidates) {
    try {
      if (File('$root/$c').existsSync()) return c;
    } on Object {
      return null;
    }
  }
  return null;
}

/// "Write the description" for [pr]: pick an agent and what it reads, it
/// writes a draft, you check it, and only then is the pull request
/// updated. Without the daemon (design, tests) the draft is made up here.
Future<void> showPrDescriptionDialog(BuildContext context, {required RepoActivitySource source, required RepoPullRequest pr}) {
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
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: Material(type: MaterialType.transparency, child: PrDescriptionDialog(source: source, pr: pr)),
      ),
    ),
  );
}

enum _Phase { setup, writing, draft }

class PrDescriptionDialog extends StatefulWidget {
  const PrDescriptionDialog({super.key, required this.source, required this.pr});
  final RepoActivitySource source;
  final RepoPullRequest pr;

  @override
  State<PrDescriptionDialog> createState() => _PrDescriptionDialogState();
}

class _PrDescriptionDialogState extends State<PrDescriptionDialog> {
  final _extra = TextEditingController();
  final _ask = TextEditingController();
  final _md = TextEditingController();

  _Phase _phase = _Phase.setup;
  String? _provider;
  bool _commits = true;
  bool _ticket = true;
  bool _template = true;
  bool _keepCurrent = true;
  bool _suggestTitle = true;
  bool _useTitle = true;
  PrDescriptionLength _length = PrDescriptionLength.standard;
  bool _markdownView = false;
  bool _applying = false;
  bool _copied = false;
  String? _error;

  /// The agent writing it (null: none yet, or the made-up draft).
  String? _runId;
  String? _draftPath;
  String? _titlePath;
  String? _suggested;
  Timer? _poll;
  DateTime? _baseline;
  int _lastLength = -1;
  int _titleWaits = 0;
  int _revisions = 0;

  /// Found once: the PR template and the ticket its branch names.
  String? _templatePath;
  TaskEntry? _task;
  bool _looked = false;

  RepoPullRequest get pr => widget.pr;
  String get _host => CiProvider.ofHost(widget.source.repo.host)?.hostName ?? widget.source.repo.host;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).agents.loadProviders();
    });
  }

  void _lookAround(AppState s) {
    if (_looked) return;
    _looked = true;
    final home = prAgentHome(s, widget.source.repo, pr);
    _templatePath = home == null ? null : prTemplateIn(home.$1);
    final key = ticketKeyIn(pr.branch);
    _task = key == null ? null : s.tasks.tasks.where((t) => t.key == key).firstOrNull;
  }

  /// Kept for [dispose], where the tree can't be looked up any more.
  AppState? _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.read(context);
  }

  @override
  void dispose() {
    _poll?.cancel();
    final id = _runId;
    final s = _app;
    if (id != null && s != null) {
      // A one-off session: it ends with the dialog, and its files with it.
      final run = s.agents.runs.where((r) => r.id == id).firstOrNull;
      if (run != null && run.status != AgentStatus.done) s.agents.stop(id).ignore();
    }
    for (final p in [_draftPath, _titlePath]) {
      if (p == null) continue;
      try {
        File(p).deleteSync();
      } on Object {
        // Already gone.
      }
    }
    _extra.dispose();
    _ask.dispose();
    _md.dispose();
    super.dispose();
  }

  // ---- Writing ----

  Future<void> _start() async {
    final s = AppScope.read(context);
    setState(() {
      _error = null;
      _phase = _Phase.writing;
    });
    if (!s.agents.live) return _makeUp();
    final home = prAgentHome(s, widget.source.repo, pr);
    if (home == null) return _fail('${widget.source.repo.name} has no checkout on this Mac for an agent to read.');
    final dir = Directory('${Directory.systemTemp.path}/kumo-pr');
    try {
      dir.createSync(recursive: true);
    } on Object catch (e) {
      return _fail('Couldn’t make a folder for the draft: $e');
    }
    final stem = '${widget.source.repo.name}-${pr.id}';
    _draftPath = '${dir.path}/$stem.md';
    _titlePath = _suggestTitle ? '${dir.path}/$stem.title.txt' : null;
    for (final p in [_draftPath!, '${dir.path}/$stem.title.txt']) {
      try {
        File(p).deleteSync();
      } on Object {
        // Nothing there.
      }
    }
    String? ticket;
    final task = _task;
    if (_ticket && task != null) {
      var detail = s.tasks.cachedDetail(task.id);
      if (detail == null) {
        try {
          detail = await s.tasks.getTask(task.id).timeout(const Duration(seconds: 8));
        } on Object {
          detail = null;
        }
        if (!mounted) return;
      }
      ticket = AppState.taskPrompt(task, detail: detail);
    }
    final prompt = prDescriptionPrompt(
      prAgentTarget(widget.source, pr, home.$2),
      draftPath: _draftPath!,
      titlePath: _titlePath,
      commits: _commits,
      ticket: ticket,
      templatePath: _template ? _templatePath : null,
      keepCurrent: _keepCurrent,
      length: _length,
      extra: _extra.text,
    );
    final run = await s.agents.start(
      providerId: _provider ?? s.agents.connected.firstOrNull?.id,
      worktreePath: home.$1,
      prompt: prompt,
      title: '${pr.number} · ${PrAgentJob.describe.label}',
      context: [if (_ticket && task != null) s.taskContext(task)],
    );
    if (!mounted) {
      // Closed while it started: nobody would read its draft.
      if (run != null) s.agents.stop(run.id).ignore();
      return;
    }
    if (run == null) return _fail(s.agents.error ?? 'The agent didn’t start.');
    _runId = run.id;
    _watch();
  }

  void _fail(String why) {
    if (!mounted) return;
    setState(() {
      _phase = _runId == null ? _Phase.setup : _Phase.writing;
      _error = why;
    });
  }

  /// Waits for the agent's file: there, newer than before, and the same
  /// size twice in a row (written in full).
  void _watch() {
    _poll?.cancel();
    _lastLength = -1;
    _poll = Timer.periodic(const Duration(milliseconds: 700), (_) => _check());
  }

  void _check() {
    if (!mounted) return;
    final path = _draftPath;
    if (path == null) return;
    final file = File(path);
    FileStat? stat;
    try {
      stat = file.existsSync() ? file.statSync() : null;
    } on Object {
      stat = null;
    }
    final baseline = _baseline;
    final size = stat?.size ?? 0;
    final fresh = stat != null && size > 0 && (baseline == null || stat.modified.isAfter(baseline));
    final tp0 = _titlePath;
    final titleMissing = tp0 != null && _suggested == null && !File(tp0).existsSync();
    if (fresh && size == _lastLength && titleMissing && _titleWaits < 6) {
      // The title comes first in the prompt, but agents don't always obey:
      // give it a few more seconds.
      _titleWaits++;
      return;
    }
    if (fresh && size == _lastLength) {
      _poll?.cancel();
      _titleWaits = 0;
      String text;
      try {
        text = file.readAsStringSync();
      } on Object catch (e) {
        return _fail('Couldn’t read the draft: $e');
      }
      String? title;
      final tp = _titlePath;
      if (tp != null) {
        try {
          final t = File(tp).readAsStringSync().trim().split('\n').first.trim();
          title = t.isEmpty || t == pr.title ? null : t;
        } on Object {
          title = null;
        }
      }
      setState(() {
        _md.text = text.trim();
        _suggested = title ?? _suggested;
        _phase = _Phase.draft;
        _error = null;
      });
      return;
    }
    _lastLength = fresh ? size : -1;
    // The agent's last line and state show while it works.
    setState(() {});
  }

  /// Without the daemon: a made-up draft from what Kumo knows.
  void _makeUp() {
    _poll?.cancel();
    _poll = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final key = ticketKeyIn(pr.branch);
      final ask = _ask.text.trim();
      final stripped = pr.title.replaceFirst(RegExp(r'^\w+(\(.+?\))?!?: '), '');
      final what = stripped.isEmpty ? pr.title : stripped;
      final summary = '${what.isEmpty ? '' : what[0].toUpperCase()}${what.length > 1 ? what.substring(1) : ''}.${ask.isEmpty ? '' : ' ($ask)'}';
      setState(() {
        _md.text = [
          '## Summary',
          '',
          summary,
          if (_length != PrDescriptionLength.short) ...[
            '',
            '## Changes',
            '',
            '- Changes on `${pr.branch}`.',
            '',
            '## How to test',
            '',
            '- `make test`',
          ],
          if (_length == PrDescriptionLength.detailed) ...['', '## Notes for reviewers', '', '- Nothing unusual.'],
          if (key != null && _ticket) ...['', 'Closes $key.'],
        ].join('\n');
        _suggested = _suggestTitle && key != null ? '${pr.title} ($key)' : null;
        _phase = _Phase.draft;
      });
    });
  }

  /// Sends [ask] (or "again") to the same agent, after saving your edits to
  /// the file it rewrites.
  Future<void> _revise() async {
    final s = AppScope.read(context);
    final ask = _ask.text.trim().isEmpty ? 'write it again, more clearly' : _ask.text.trim();
    setState(() {
      _phase = _Phase.writing;
      _error = null;
      _copied = false;
    });
    final id = _runId;
    final path = _draftPath;
    if (!s.agents.live || id == null || path == null) return _makeUp();
    try {
      File(path).writeAsStringSync(_md.text);
      _baseline = File(path).statSync().modified;
    } on Object {
      _baseline = DateTime.now();
    }
    _revisions++;
    final sent = await s.agents.addContext(
      id,
      AgentContextItem(kind: AgentContextKind.doc, title: '${pr.number} description · change $_revisions', detail: ask),
      text: prDescriptionRevision(path, ask),
    );
    if (!mounted) return;
    if (!sent) return _fail(s.agents.error ?? 'Couldn’t reach the agent: it may have stopped.');
    _ask.clear();
    _watch();
  }

  // ---- Updating the pull request ----

  Future<void> _apply() async {
    final s = AppScope.read(context);
    final body = _md.text.trim();
    final navigator = Navigator.of(context);
    if (_applying) return;
    if (!widget.source.prsEditable) {
      // Until the daemon can edit pull requests: copy it and open the page.
      _applying = true;
      await Clipboard.setData(ClipboardData(text: body));
      await openUrl(pr.url);
      navigator.maybePop();
      s.notify('Copied: paste it into ${pr.number} on $_host');
      return;
    }
    setState(() {
      _applying = true;
      _error = null;
    });
    final title = _useTitle ? _suggested : null;
    try {
      await widget.source.editPr(pr, body: body, title: title);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _error = '$e';
      });
      return;
    }
    if (!mounted) return;
    navigator.maybePop();
    final url = pr.url;
    s.notify('Updated ${pr.number} on $_host', action: url.isEmpty ? null : 'Open', onAction: url.isEmpty ? null : () => openUrl(url));
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _md.text.trim()));
    if (mounted) setState(() => _copied = true);
  }

  // ---- Building ----

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    _lookAround(s);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: GlassOverlay(
        width: 620,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(10)),
              child: Icon(KIcons.sparkle, size: 16, color: c.acc),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Write a description for ${pr.number}', style: sans(14, weight: FontWeight.w600, color: c.text)),
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
          // Scrolls instead of overflowing a short window.
          Flexible(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                ...switch (_phase) {
                  _Phase.setup => _setup(context, s),
                  _Phase.writing => _writing(context, s),
                  _Phase.draft => _draft(context, s),
                },
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(), style: sans(11, weight: FontWeight.w600, color: context.c.text3).copyWith(letterSpacing: 0.6)),
      );

  Widget _errorLine(BuildContext context) => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(_error!, maxLines: 4, overflow: TextOverflow.ellipsis, style: sans(12, color: context.c.err)),
        );

  List<Widget> _setup(BuildContext context, AppState s) {
    final c = context.c;
    final connected = s.agents.connected;
    final live = s.agents.live;
    if (live && connected.isEmpty) {
      return [
        Text('Connect an agent in Settings › AI agents first: it reads the changes and writes the draft.', style: sans(12.5, color: c.text2, height: 1.4)),
      ];
    }
    final home = prAgentHome(s, widget.source.repo, pr);
    final provider = _provider ?? connected.firstOrNull?.id;
    final providerName = connected.where((p) => p.id == provider).firstOrNull?.name ?? 'The agent';
    final cli = prAgentTarget(widget.source, pr, home?.$2 ?? false).cli;
    final task = _task;
    final key = ticketKeyIn(pr.branch);
    return [
      if (connected.isNotEmpty) ...[
        _label(context, 'Agent'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in connected) _AgentChip(provider: p, selected: p.id == provider, onTap: () => setState(() => _provider = p.id)),
        ]),
        const SizedBox(height: 14),
      ],
      _label(context, 'It reads'),
      Container(
        decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          _ReadRow(icon: KIcons.files, title: 'Changes against ${pr.base.isNotEmpty ? pr.base : widget.source.mainBranch}', note: 'Always', value: true, onChanged: null),
          _ReadRow(icon: KIcons.git, title: 'Its commit messages', value: _commits, onChanged: (v) => setState(() => _commits = v)),
          if (task != null)
            _ReadRow(icon: KIcons.tasks, title: '${task.key} · ${task.title}', note: 'Description, acceptance criteria and comments', value: _ticket, onChanged: (v) => setState(() => _ticket = v))
          else if (key != null)
            _ReadRow(icon: KIcons.tasks, title: key, note: 'Not in your tasks, so the agent can’t read it', value: false, onChanged: null),
          if (_templatePath case final t?) _ReadRow(icon: KIcons.page, title: 'Your template', note: t, monospace: true, value: _template, onChanged: (v) => setState(() => _template = v)),
          if (cli != null)
            _ReadRow(icon: KIcons.rename, title: 'The current description', note: 'Keeps what’s still true in it (with `$cli`)', value: _keepCurrent, onChanged: (v) => setState(() => _keepCurrent = v)),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Text('LENGTH', style: sans(11, weight: FontWeight.w600, color: c.text3).copyWith(letterSpacing: 0.6)),
        const SizedBox(width: 10),
        KSegmented<PrDescriptionLength>(
          label: 'Length',
          height: 26,
          value: _length,
          onChanged: (v) => setState(() => _length = v),
          items: [for (final l in PrDescriptionLength.values) (l, l.label, null)],
        ),
        const Spacer(),
        Flexible(child: KCheck(value: _suggestTitle, label: 'Suggest a better title too', onChanged: (v) => setState(() => _suggestTitle = v))),
      ]),
      const SizedBox(height: 14),
      _label(context, 'Anything to point out (optional)'),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(11), border: Border.all(color: c.chipBorder)),
        child: TextField(
          controller: _extra,
          minLines: 2,
          maxLines: 4,
          style: sans(12.5, color: c.text, height: 1.4),
          cursorColor: c.acc,
          decoration: const InputDecoration.collapsed(hintText: 'e.g. say the flag stays off in production until the pricing team signs off'),
        ),
      ),
      _errorLine(context),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: Text(
            !live
                ? 'Without Kumo’s engine this draft is made up, to show the flow.'
                : home == null
                    ? '${widget.source.repo.name} has no checkout on this Mac.'
                    : '$providerName reads ${home.$2 ? 'the PR’s worktree' : 'the branch from the main checkout'} in a new session. Nothing changes on $_host until you update the PR.',
            style: sans(11, color: c.text3, height: 1.4),
          ),
        ),
        const SizedBox(width: 10),
        KButton(label: 'Cancel', onTap: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 8),
        KButton.primary(label: 'Write description', icon: KIcons.sparkle, onTap: live && home == null ? null : _start),
      ]),
    ];
  }

  List<Widget> _writing(BuildContext context, AppState s) {
    final c = context.c;
    final run = _runId == null ? null : s.agents.runs.where((r) => r.id == _runId).firstOrNull;
    final asking = run?.status == AgentStatus.needsYou;
    final ended = run?.status == AgentStatus.done;
    final line = run == null
        ? 'Reading the changes…'
        : ended
            ? '${run.providerName} stopped before writing the draft.'
            : asking
                ? '${run.providerName} is waiting for you (a permission, or a question).'
                : (run.lastLine.trim().isEmpty ? '${run.providerName} is reading the changes…' : run.lastLine.trim());
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          if (ended)
            Icon(KIcons.warning, size: 16, color: c.warn)
          else
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: asking ? c.warn : c.acc)),
          const SizedBox(width: 10),
          Expanded(child: Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(12.5, color: asking || ended ? c.text : c.text2))),
        ]),
      ),
      _errorLine(context),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: Text(
            _draftPath == null ? 'Writing the draft…' : 'It writes the draft to ${_draftPath!.split('/').last}; it shows here when it’s done.',
            style: sans(11, color: c.text3, height: 1.4),
          ),
        ),
        if (run != null) ...[
          KButton(
            label: 'Open its tab',
            onTap: () {
              // The session is the user's from here on: closing doesn't stop it.
              _poll?.cancel();
              _runId = null;
              Navigator.of(context).maybePop();
              s.openTerminal(run.terminalId, title: run.title, agent: true, directory: run.worktreePath);
            },
          ),
          const SizedBox(width: 8),
        ],
        KButton(
          label: 'Stop',
          onTap: () {
            _poll?.cancel();
            final id = _runId;
            if (id != null) s.agents.stop(id).ignore();
            setState(() {
              _runId = null;
              _phase = _md.text.isEmpty ? _Phase.setup : _Phase.draft;
            });
          },
        ),
      ]),
    ];
  }

  List<Widget> _draft(BuildContext context, AppState s) {
    final c = context.c;
    final run = _runId == null ? null : s.agents.runs.where((r) => r.id == _runId).firstOrNull;
    final suggested = _suggested;
    final canAsk = !s.agents.live || (run != null && run.status != AgentStatus.done);
    final editable = widget.source.prsEditable;
    return [
      Row(children: [
        KSegmented<bool>(
          label: 'Draft view',
          height: 26,
          value: _markdownView,
          onChanged: (v) => setState(() => _markdownView = v),
          items: const [(false, 'Preview', null), (true, 'Markdown', null)],
        ),
        const Spacer(),
        if (run != null) Text('By ${run.providerName}', style: sans(11.5, color: c.text3)),
      ]),
      const SizedBox(height: 10),
      if (suggested != null) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Text('Title', style: sans(12, color: c.text3)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(pr.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text3).copyWith(decoration: _useTitle ? TextDecoration.lineThrough : null)),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('→', style: sans(12, color: c.text3))),
            Expanded(
              child: Text(suggested, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, weight: FontWeight.w600, color: _useTitle ? c.text : c.text3)),
            ),
            const SizedBox(width: 8),
            KButton(label: _useTitle ? 'Keep the old one' : 'Use this title', kind: KButtonKind.ghost, height: 24, fontSize: 12, onTap: () => setState(() => _useTitle = !_useTitle)),
          ]),
        ),
        const SizedBox(height: 10),
      ],
      SizedBox(
        // Room for the rest of the dialog on a short window.
        height: (MediaQuery.sizeOf(context).height - 480).clamp(160.0, 340.0),
        child: _markdownView
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.chipBorder)),
                child: TextField(
                  controller: _md,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  style: mono(12, color: c.text, height: 1.5),
                  cursorColor: c.acc,
                  onChanged: (_) => setState(() => _copied = false),
                  decoration: const InputDecoration.collapsed(hintText: 'The description, in Markdown'),
                ),
              )
            : Container(
                decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: MarkdownPreview(source: _md.text, path: 'DESCRIPTION.md'),
              ),
      ),
      if (canAsk) ...[
        const SizedBox(height: 10),
        Container(
          height: 36,
          padding: const EdgeInsets.only(left: 10, right: 4),
          decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.chipBorder)),
          child: Row(children: [
            Icon(KIcons.sparkle, size: 14, color: c.text3),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ask,
                style: sans(12.5, color: c.text),
                cursorColor: c.acc,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _revise(),
                decoration: const InputDecoration.collapsed(hintText: 'Ask for changes: shorter, in Spanish, mention the migration…'),
              ),
            ),
            KButton(label: _ask.text.trim().isEmpty ? 'Regenerate' : 'Apply', height: 28, fontSize: 12, onTap: _revise),
          ]),
        ),
      ],
      _errorLine(context),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: Text(
            editable
                ? 'Replaces the current description of ${pr.number} on $_host.'
                : 'Kumo can’t edit ${pr.number} yet: this copies the description and opens it on $_host to paste.',
            style: sans(11, color: c.text3, height: 1.4),
          ),
        ),
        const SizedBox(width: 10),
        KButton(label: _copied ? 'Copied' : 'Copy Markdown', icon: _copied ? KIcons.check : KIcons.copy, onTap: _copy),
        const SizedBox(width: 8),
        KButton.primary(
          label: !editable
              ? 'Copy and open on $_host'
              : _applying
                  ? 'Updating…'
                  : 'Update ${pr.number}${_useTitle && suggested != null ? ' and its title' : ''}',
          icon: editable ? KIcons.upload : KIcons.external,
          onTap: _applying || _md.text.trim().isEmpty || (!editable && pr.url.isEmpty) ? null : _apply,
        ),
      ]),
    ];
  }
}

/// An agent to pick, with what's left on its plan when Kumo can read it.
class _AgentChip extends StatelessWidget {
  const _AgentChip({required this.provider, required this.selected, required this.onTap});
  final AgentProviderInfo provider;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final w = s.usage.planOf(provider.id)?.tightest;
    final left = w == null
        ? null
        : w.unit == UsageUnit.percent
            ? '${w.short} · ${(w.fractionLeft * 100).round()}% left'
            : '${w.short} · ${w.left.round()} left';
    final low = w != null && w.fractionLeft < 0.2;
    return KPressable(
      onTap: onTap,
      semanticLabel: provider.name,
      selected: selected,
      tooltip: w == null ? null : '${w.label}: ${left!.split(' · ').last}',
      builder: (context, hover, focus) => Container(
        height: 40,
        padding: const EdgeInsets.only(left: 6, right: 12),
        decoration: BoxDecoration(
          color: selected ? c.accSoft : (hover ? c.chip : c.tile),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected || focus ? c.acc : const Color(0x00000000)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(8)),
            child: Text(provider.short, style: mono(9.5, weight: FontWeight.w700, color: c.text2)),
          ),
          const SizedBox(width: 8),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(provider.name, style: sans(12.5, weight: FontWeight.w600, color: c.text)),
            if (left != null) Text(left, style: sans(10.5, color: low ? c.warn : c.text3)),
          ]),
        ]),
      ),
    );
  }
}

/// One thing the agent reads, with a check (null [onChanged]: fixed).
class _ReadRow extends StatelessWidget {
  const _ReadRow({required this.icon, required this.title, required this.value, required this.onChanged, this.note, this.monospace = false});
  final IconData icon;
  final String title;
  final String? note;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = onChanged != null;
    final note = this.note;
    return KPressable(
      onTap: enabled ? () => onChanged!(!value) : null,
      semanticLabel: title,
      selected: value,
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: enabled && hover ? c.chip : null,
          borderRadius: BorderRadius.circular(12),
          border: focus ? Border.all(color: c.acc, width: 1.5) : null,
        ),
        child: Row(children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: value ? (enabled ? c.accFill : c.text3) : null,
              borderRadius: BorderRadius.circular(4.5),
              border: Border.all(color: value ? const Color(0x00000000) : c.text3, width: 1.4),
            ),
            child: value ? Icon(Icons.check_rounded, size: 12, color: c.accText) : null,
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 15, color: c.text3),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: FontWeight.w500, color: enabled || value ? c.text : c.text3)),
              if (note != null)
                Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: monospace ? mono(11, color: c.text3) : sans(11, color: c.text3)),
            ]),
          ),
        ]),
      ),
    );
  }
}
