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
import '../editor/markdown_preview.dart';
import '../platform/open_url.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';
import 'agent_files.dart';
import 'pr_description_dialog.dart' show AgentPickChip, ReadRow;

/// The checkout an agent reads a repository from: its main worktree.
String? mainCheckoutOf(AppState s, RepoActivitySource source) {
  final trees = s.worktreesOf(source.repo);
  final main = trees.where((w) => w.isMain).firstOrNull ?? trees.firstOrNull;
  if (main != null) return s.workspace.absolutePathOf(main);
  final p = source.repo.path;
  return p == null || p.isEmpty ? null : p;
}

/// "Write the release notes" for [releases]`[index]`: compared with the
/// previous release (or, for the first one, written from the project), by
/// an agent, checked here before the release changes on the host. [create]
/// turns a bare tag into a release.
Future<void> showReleaseNotesDialog(BuildContext context, {required RepoActivitySource source, required List<RepoRelease> releases, required int index}) {
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
        padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
        child: Material(type: MaterialType.transparency, child: ReleaseNotesDialog(source: source, releases: releases, index: index)),
      ),
    ),
  );
}

enum _Phase { setup, writing, draft }

class ReleaseNotesDialog extends StatefulWidget {
  const ReleaseNotesDialog({super.key, required this.source, required this.releases, required this.index});
  final RepoActivitySource source;
  final List<RepoRelease> releases;
  final int index;

  @override
  State<ReleaseNotesDialog> createState() => _ReleaseNotesDialogState();
}

class _ReleaseNotesDialogState extends State<ReleaseNotesDialog> {
  final _extra = TextEditingController();
  final _ask = TextEditingController();
  final _md = TextEditingController();

  _Phase _phase = _Phase.setup;
  String? _provider;

  /// Index in [ReleaseNotesDialog.releases] it's compared with; null: the
  /// first release (from the project).
  late int? _since = previousReleaseIndex(widget.releases, widget.index);
  late final int? _suggested = _since;
  ReleaseRange? _range;
  String? _rangeError;

  ReleaseNotesStyle _style = ReleaseNotesStyle.changelog;
  bool _prs = true;
  bool _tickets = true;
  bool _matchStyle = true;
  bool _thanks = true;
  bool _keepCurrent = true;
  bool _suggestName = true;
  bool _useName = true;
  bool _markdownView = false;
  bool _applying = false;
  bool _copied = false;
  String? _error;
  String? _name;

  String? _runId;
  AgentFileWatch? _files;
  Timer? _poll;
  AppState? _app;

  RepoRelease get release => widget.releases[widget.index];
  bool get _first => _since == null && widget.index == widget.releases.length - 1 && widget.source.olderReleases == 0;
  RepoRelease? get _sinceRelease => _since == null || _since! >= widget.releases.length ? null : widget.releases[_since!];
  String get _host => CiProvider.ofHost(widget.source.repo.host)?.hostName ?? widget.source.repo.host;
  bool get _create => release.isTag;

  @override
  void initState() {
    super.initState();
    _loadRange();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).agents.loadProviders();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.read(context);
  }

  void _loadRange() {
    final since = _sinceRelease;
    setState(() {
      _range = null;
      _rangeError = null;
    });
    widget.source.releaseRange(release, since: since).then((r) {
      if (mounted && since == _sinceRelease) setState(() => _range = r);
    }, onError: (Object e) {
      if (mounted) setState(() => _rangeError = '$e');
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    final id = _runId;
    final s = _app;
    if (id != null && s != null) {
      final run = s.agents.runs.where((r) => r.id == id).firstOrNull;
      if (run != null && run.status != AgentStatus.done) s.agents.stop(id).ignore();
    }
    _files?.delete();
    _extra.dispose();
    _ask.dispose();
    _md.dispose();
    super.dispose();
  }

  ReleaseTarget _target() => ReleaseTarget(
        repoName: widget.source.repo.name,
        host: widget.source.repo.host,
        tag: release.tag,
        since: _sinceRelease?.tag,
        preRelease: release.kind == ReleaseKind.preRelease,
        skipped: [for (final r in skippedBetween(widget.releases, widget.index, _since)) if (r.notes.trim().isEmpty) r.tag],
      );

  // ---- Writing ----

  Future<void> _start() async {
    final s = AppScope.read(context);
    setState(() {
      _error = null;
      _phase = _Phase.writing;
    });
    if (!s.agents.live) return _makeUp();
    final dir = mainCheckoutOf(s, widget.source);
    if (dir == null) return _fail('${widget.source.repo.name} has no checkout on this Mac for an agent to read.');
    final files = _files = AgentFileWatch.fresh('${widget.source.repo.name}-${release.tag}-notes', 'md', companionExt: _suggestName ? 'name.txt' : null);
    final prev = _sinceRelease;
    final prompt = releaseNotesPrompt(
      _target(),
      draftPath: files.path,
      namePath: files.companion,
      style: _style,
      prs: _prs ? _range?.prs ?? const [] : const [],
      tickets: _tickets,
      styleOf: _matchStyle && prev != null && prev.notes.trim().isNotEmpty ? prev.tag : null,
      thanks: _thanks,
      currentNotes: _keepCurrent ? release.notes : null,
      extra: _extra.text,
    );
    final run = await s.agents.start(
      providerId: _provider ?? s.agents.connected.firstOrNull?.id,
      worktreePath: dir,
      prompt: prompt,
      title: '${release.tag} · Release notes',
    );
    if (!mounted) {
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

  void _watch() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      final got = _files?.poll();
      if (got == null) return setState(() {});
      _poll?.cancel();
      setState(() {
        _md.text = got.$1.trim();
        final n = got.$2;
        _name = n == null || n == release.name ? _name : n;
        _phase = _Phase.draft;
        _error = null;
      });
    });
  }

  /// Without the daemon: notes made up from the range, to show the flow.
  void _makeUp() {
    _poll?.cancel();
    _poll = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final range = _range;
      final prs = range?.prs ?? const <MergedPr>[];
      String human(String t) {
        final x = t.replaceFirst(RegExp(r'^\w+(\(.+?\))?!?: '), '');
        return x.length > 1 && x[1] == x[1].toUpperCase() && x[1] != x[1].toLowerCase() ? x : (x.isEmpty ? x : x[0].toUpperCase() + x.substring(1));
      }

      String item(MergedPr p) => '- ${human(p.$2)} (${p.$1}${_tickets && p.$4 != null ? ', ${p.$4}' : ''}).';
      final feats = [for (final p in prs) if (p.$2.startsWith('feat')) p];
      final fixes = [for (final p in prs) if (p.$2.startsWith('fix')) p];
      final rest = [for (final p in prs) if (!p.$2.startsWith('feat') && !p.$2.startsWith('fix')) p];
      final lines = <String>[];
      if (_first) {
        lines.addAll(['## What it is', '${widget.source.repo.name} answers prices for the storefront, with a read-through cache in front of its database.', '## In this first version', ...prs.map(item), '## Run it', '- `make run`; the README has the rest.']);
      } else {
        final hl = ['## Highlights', ...(feats.isEmpty ? prs : feats).take(3).map(item)];
        final cl = [
          if (feats.isNotEmpty) ...['## What’s new', ...feats.map(item)],
          if (fixes.isNotEmpty) ...['## Fixes', ...fixes.map(item)],
          if (rest.isNotEmpty) ...['## Other', ...rest.map(item)],
        ];
        if (release.kind == ReleaseKind.preRelease) lines.add('A pre-release of what’s coming after ${_sinceRelease?.tag ?? 'the latest release'}: try it before it becomes the latest.');
        lines.addAll(switch (_style) {
          ReleaseNotesStyle.highlights => hl,
          ReleaseNotesStyle.both => [...hl, ...cl],
          ReleaseNotesStyle.changelog => cl,
        });
      }
      if (_extra.text.trim().isNotEmpty) lines.addAll(['## Notes', '- ${_extra.text.trim()}']);
      if (_thanks && range != null && range.people.isNotEmpty) lines.add('Thanks ${range.people.join(', ')}.');
      if (_ask.text.trim().isNotEmpty) lines.add('_(${_ask.text.trim()})_');
      setState(() {
        _md.text = lines.join('\n');
        _name = _suggestName && feats.isNotEmpty ? human(feats.first.$2).split(' ').take(3).join(' ') : (_first && _suggestName ? 'First release' : null);
        _phase = _Phase.draft;
      });
    });
  }

  Future<void> _revise() async {
    final s = AppScope.read(context);
    final ask = _ask.text.trim().isEmpty ? 'write them again, more clearly' : _ask.text.trim();
    setState(() {
      _phase = _Phase.writing;
      _error = null;
      _copied = false;
    });
    final id = _runId;
    final files = _files;
    if (!s.agents.live || id == null || files == null) return _makeUp();
    files.rebase(_md.text);
    final sent = await s.agents.addContext(
      id,
      AgentContextItem(kind: AgentContextKind.doc, title: '${release.tag} notes · change', detail: ask),
      text: 'Change the release notes in `${files.path}` as follows, and save them to the same file: $ask. Don’t change anything else. When the file is written, say “Done”.',
    );
    if (!mounted) return;
    if (!sent) return _fail(s.agents.error ?? 'Couldn’t reach the agent: it may have stopped.');
    _ask.clear();
    _watch();
  }

  // ---- Updating the release ----

  Future<void> _apply() async {
    if (_applying) return;
    final s = AppScope.read(context);
    final notes = _md.text.trim();
    final navigator = Navigator.of(context);
    if (!widget.source.releasesEditable) {
      _applying = true;
      await Clipboard.setData(ClipboardData(text: notes));
      if (release.url.isNotEmpty) await openUrl(release.url);
      navigator.maybePop();
      s.notify('Copied: paste them into ${release.tag} on $_host');
      return;
    }
    setState(() {
      _applying = true;
      _error = null;
    });
    try {
      await widget.source.editRelease(release, notes: notes, name: _useName ? _name : null);
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
    final url = release.url;
    s.notify(_create ? 'Created release ${release.tag}' : 'Updated the notes of ${release.tag}', action: url.isEmpty ? null : 'Open', onAction: url.isEmpty ? null : () => openUrl(url));
  }

  // ---- Building ----

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final since = _sinceRelease;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: GlassOverlay(
        width: 640,
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
                Text(
                  _create ? 'Create a release from ${release.tag}' : '${release.notes.trim().isEmpty ? 'Write' : 'Rewrite'} the release notes of ${release.tag}',
                  style: sans(14, weight: FontWeight.w600, color: c.text),
                ),
                const SizedBox(height: 3),
                Text(
                  _first ? 'First release of ${widget.source.repo.name}' : (since == null ? release.tag : '${since.tag}…${release.tag}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mono(11.5, color: c.text3),
                ),
              ]),
            ),
            KIconButton(icon: KIcons.close, label: 'Close', onTap: () => Navigator.of(context).maybePop()),
          ]),
          const SizedBox(height: 14),
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
      : Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, maxLines: 4, overflow: TextOverflow.ellipsis, style: sans(12, color: context.c.err)));

  List<Widget> _setup(BuildContext context, AppState s) {
    final c = context.c;
    final connected = s.agents.connected;
    final live = s.agents.live;
    if (live && connected.isEmpty) {
      return [Text('Connect an agent in Settings › AI agents first: it reads the history and writes the notes.', style: sans(12.5, color: c.text2, height: 1.4))];
    }
    final provider = _provider ?? connected.firstOrNull?.id;
    final providerName = connected.where((p) => p.id == provider).firstOrNull?.name ?? 'The agent';
    final range = _range;
    final since = _sinceRelease;
    final prWord = widget.source.repo.host == 'GL' ? 'merge requests' : 'pull requests';
    final candidates = [for (var j = widget.index + 1; j < widget.releases.length && j <= widget.index + 4; j++) j];
    final skipped = skippedBetween(widget.releases, widget.index, _since);
    final dir = mainCheckoutOf(s, widget.source);
    return [
      if (connected.isNotEmpty) ...[
        _label(context, 'Agent'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in connected) AgentPickChip(provider: p, selected: p.id == provider, onTap: () => setState(() => _provider = p.id)),
        ]),
        const SizedBox(height: 14),
      ],
      if (_first)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(KIcons.sparkle, size: 15, color: c.acc),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'First release: there’s nothing before ${release.tag} to compare with, so the agent reads the project itself and writes what it is, what this first version does and how to run it.',
                style: sans(12.5, color: c.text, height: 1.5),
              ),
            ),
          ]),
        )
      else if (candidates.isNotEmpty) ...[
        _label(context, 'Compare with'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final j in candidates)
            _CompareChip(
              release: widget.releases[j],
              suggested: j == _suggested,
              selected: j == _since,
              onTap: () {
                setState(() => _since = j);
                _loadRange();
              },
            ),
        ]),
        const SizedBox(height: 6),
        Text(
          since == null
              ? ''
              : _since != _suggested
                  ? 'Compared with ${since.tag} instead of the previous release.'
                  : release.kind == ReleaseKind.preRelease || release.kind == ReleaseKind.draft
                      ? '${release.tag} is a pre-release, so it’s compared with the latest full release, ${since.tag}.'
                      : 'Compared with the previous release, ${since.tag}.${skipped.isEmpty ? '' : ' ${skipped.map((r) => r.tag).join(', ')} ${skipped.length == 1 ? 'has' : 'have'} no release of ${skipped.length == 1 ? 'its' : 'their'} own, so its changes are included.'}',
          style: sans(11.5, color: c.text3, height: 1.45),
        ),
        const SizedBox(height: 14),
      ],
      _label(context, 'It reads'),
      Container(
        decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          if (_first)
            const ReadRow(icon: KIcons.repo, title: 'The project', note: 'README, docs, build files and main packages', value: true, onChanged: null)
          else
            ReadRow(
              icon: KIcons.commit,
              title: 'Changes since ${since?.tag ?? 'the previous release'}',
              note: range == null ? (_rangeError ?? 'Counting…') : '${range.commits} commits · ${range.files} files · +${range.added} −${range.deleted}',
              value: true,
              onChanged: null,
            ),
          if (range != null && range.prs.isNotEmpty)
            ReadRow(icon: KIcons.pullRequest, title: '${range.prs.length} merged $prWord', note: '${range.prs.first.$2}${range.prs.length > 1 ? ' and ${range.prs.length - 1} more' : ''}', value: _prs, onChanged: (v) => setState(() => _prs = v)),
          if (range != null && range.tickets.isNotEmpty)
            ReadRow(icon: KIcons.tasks, title: range.tickets.join(', '), note: 'Named next to each change', value: _tickets, onChanged: (v) => setState(() => _tickets = v)),
          if (since != null && since.notes.trim().isNotEmpty)
            ReadRow(icon: KIcons.page, title: '${since.tag}’s notes', note: 'Keeps the same sections and tone', value: _matchStyle, onChanged: (v) => setState(() => _matchStyle = v)),
          if (range != null && range.people.isNotEmpty)
            ReadRow(icon: KIcons.people, title: 'Thank who contributed', note: range.people.join(', '), value: _thanks, onChanged: (v) => setState(() => _thanks = v)),
          if (release.notes.trim().isNotEmpty)
            ReadRow(icon: KIcons.rename, title: 'The current notes', note: 'Keeps what’s still true in them', value: _keepCurrent, onChanged: (v) => setState(() => _keepCurrent = v)),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Text('STYLE', style: sans(11, weight: FontWeight.w600, color: c.text3).copyWith(letterSpacing: 0.6)),
        const SizedBox(width: 10),
        KSegmented<ReleaseNotesStyle>(
          label: 'Style',
          height: 26,
          value: _style,
          onChanged: (v) => setState(() => _style = v),
          items: [for (final st in ReleaseNotesStyle.values) (st, st.label, null)],
        ),
        const Spacer(),
        Flexible(child: KCheck(value: _suggestName, label: 'Suggest a release name', onChanged: (v) => setState(() => _suggestName = v))),
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
          decoration: InputDecoration.collapsed(
            hintText: _first ? 'e.g. say it replaces the old service behind the same API' : 'e.g. say imports over 10,000 rows are still slow, or that it needs a new Kafka topic',
          ),
        ),
      ),
      _errorLine(context),
      const SizedBox(height: 14),
      Text(
        !live
            ? 'Without Kumo’s engine these notes are made up, to show the flow.'
            : dir == null
                ? '${widget.source.repo.name} has no checkout on this Mac.'
                : '$providerName reads the history in the main checkout, in a new session. Nothing changes on $_host until you ${_create ? 'create' : 'update'} the release.',
        style: sans(11, color: c.text3, height: 1.4),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          KButton(label: 'Cancel', onTap: () => Navigator.of(context).maybePop()),
          KButton.primary(label: 'Write the notes', icon: KIcons.sparkle, onTap: (live && dir == null) || (!_first && _range == null && _rangeError == null) ? null : _start),
        ]),
      ),
    ];
  }

  List<Widget> _writing(BuildContext context, AppState s) {
    final c = context.c;
    final run = _runId == null ? null : s.agents.runs.where((r) => r.id == _runId).firstOrNull;
    final asking = run?.status == AgentStatus.needsYou;
    final ended = run?.status == AgentStatus.done;
    final line = run == null
        ? (_first ? 'Reading the project…' : 'Reading what changed…')
        : ended
            ? '${run.providerName} stopped before writing the notes.'
            : asking
                ? '${run.providerName} is waiting for you (a permission, or a question).'
                : (run.lastLine.trim().isEmpty ? '${run.providerName} is reading the history…' : run.lastLine.trim());
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          if (ended) Icon(KIcons.warning, size: 16, color: c.warn) else SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: asking ? c.warn : c.acc)),
          const SizedBox(width: 10),
          Expanded(child: Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(12.5, color: asking || ended ? c.text : c.text2))),
        ]),
      ),
      _errorLine(context),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerRight,
        child: Wrap(spacing: 8, runSpacing: 8, children: [
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
                _phase = _md.text.isEmpty ? _Phase.setup : _Phase.draft;
              });
            },
          ),
        ]),
      ),
    ];
  }

  List<Widget> _draft(BuildContext context, AppState s) {
    final c = context.c;
    final run = _runId == null ? null : s.agents.runs.where((r) => r.id == _runId).firstOrNull;
    final name = _name;
    final canAsk = !s.agents.live || (run != null && run.status != AgentStatus.done);
    final editable = widget.source.releasesEditable;
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
      if (name != null) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Text('Name', style: sans(12, color: c.text3)),
            const SizedBox(width: 8),
            if (release.name.isNotEmpty) ...[
              Flexible(child: Text(release.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text3).copyWith(decoration: _useName ? TextDecoration.lineThrough : null))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('→', style: sans(12, color: c.text3))),
            ],
            Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, weight: FontWeight.w600, color: _useName ? c.text : c.text3))),
            const SizedBox(width: 8),
            KButton(label: _useName ? 'Don’t use it' : 'Use this name', kind: KButtonKind.ghost, height: 24, fontSize: 12, onTap: () => setState(() => _useName = !_useName)),
          ]),
        ),
        const SizedBox(height: 10),
      ],
      SizedBox(
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
                  decoration: const InputDecoration.collapsed(hintText: 'The notes, in Markdown'),
                ),
              )
            : Container(
                decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: MarkdownPreview(source: _md.text, path: 'RELEASE.md'),
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
                decoration: const InputDecoration.collapsed(hintText: 'Ask for changes: shorter, for customers, add upgrade notes…'),
              ),
            ),
            KButton(label: _ask.text.trim().isEmpty ? 'Regenerate' : 'Apply', height: 28, fontSize: 12, onTap: _revise),
          ]),
        ),
      ],
      _errorLine(context),
      const SizedBox(height: 14),
      Text(
        !editable
            ? (widget.source.repo.host == 'BB' ? 'Bitbucket has no releases: this copies the notes for the tag’s message.' : 'Kumo can’t edit releases yet: this copies the notes and opens ${release.tag} on $_host to paste.')
            : _create
                ? 'Creates the release on $_host from the tag ${release.tag}.'
                : 'Replaces the notes of ${release.tag} on $_host.',
        style: sans(11, color: c.text3, height: 1.4),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
          KButton(
            label: _copied ? 'Copied' : 'Copy Markdown',
            icon: _copied ? KIcons.check : KIcons.copy,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: _md.text.trim()));
              if (mounted) setState(() => _copied = true);
            },
          ),
          KButton.primary(
            label: !editable
                ? (release.url.isEmpty ? 'Copy the notes' : 'Copy and open on $_host')
                : _applying
                    ? 'Saving…'
                    : _create
                        ? 'Create release ${release.tag}'
                        : 'Update ${release.tag}${_useName && name != null ? ' and its name' : ''}',
            icon: editable ? KIcons.upload : KIcons.external,
            onTap: _applying || _md.text.trim().isEmpty ? null : _apply,
          ),
        ]),
      ),
    ];
  }
}

/// A tag to compare with, marked when it's the suggested one.
class _CompareChip extends StatelessWidget {
  const _CompareChip({required this.release, required this.suggested, required this.selected, required this.onTap});
  final RepoRelease release;
  final bool suggested;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final why = suggested
        ? 'previous release · suggested'
        : switch (release.kind) {
            ReleaseKind.preRelease => 'pre-release',
            ReleaseKind.draft => 'draft',
            ReleaseKind.tagOnly => 'tag only',
            ReleaseKind.release => 'release',
          };
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '${release.tag}, $why',
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.accSoft : (hover ? c.chip : c.tile),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected || focus ? c.acc : const Color(0x00000000)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(release.tag, style: mono(12, weight: FontWeight.w600, color: c.text)),
          Text(why, style: sans(10.5, color: suggested ? c.ok : c.text3)),
        ]),
      ),
    );
  }
}
