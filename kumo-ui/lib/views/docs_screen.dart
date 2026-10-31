import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/agents_source.dart';
import '../data/docs_source.dart';
import '../data/tasks_source.dart';
import '../overlays/new_agent_dialog.dart';
import '../overlays/settings_dialog.dart';
import '../platform/open_url.dart';
import '../shell/screen_chrome.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';
import 'task_detail/markdown.dart';

/// Confluence and Obsidian in one reader, through the task sources: the
/// Atlassian account of a Jira source and the notes of vault sources.
/// Pages can start an agent with them as context.
class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});

  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  final _query = TextEditingController();
  Timer? _debounce;

  List<DocGroup>? _groups;
  bool _loading = false;
  String? _error;

  /// The task sources the last list read through; a change lists again.
  String? _sourcesKey;
  int _listSeq = 0;

  String? _selected;
  DocPage? _page;
  bool _pageLoading = false;
  String? _pageError;
  int _readSeq = 0;
  bool _copied = false;
  bool _sent = false;
  String? _sendError;

  /// For you (pinned, recent, updated lately) or Browse (one level of a
  /// knowledge base at a time, with a breadcrumb).
  bool _browse = false;
  DocSourceInfo? _browseSource;
  /// The path to the level shown: node keys, and their titles for the
  /// breadcrumb.
  List<(String, String)> _browsePath = const [];
  List<DocNode>? _nodes;
  bool _browseLoading = false;
  String? _browseError;
  int _browseSeq = 0;

  // ---- Pinned and recent pages, kept across launches ----

  static const _pinKey = 'docs.pinned';
  static const _recentKey = 'docs.recent';
  static const _maxRecent = 6;

  /// Saved rows: id, title, source badge, place.
  List<_SavedDoc> _saved(String key) => [
        for (final m in AppScope.read(context).prefs.get<List<dynamic>>(key, const []))
          if (m is Map && m['id'] is String) _SavedDoc(m['id'] as String, '${m['title'] ?? ''}', '${m['badge'] ?? ''}', '${m['place'] ?? ''}'),
      ];

  void _save(String key, List<_SavedDoc> docs) {
    AppScope.read(context).prefs.set(key, [for (final d in docs) {'id': d.id, 'title': d.title, 'badge': d.badge, 'place': d.place}]);
  }

  static _SavedDoc _savedOf(DocPage page) => _SavedDoc(page.summary.id, page.summary.title, page.source.kind.badge, page.summary.place);

  bool _isPinned(String id) => _saved(_pinKey).any((d) => d.id == id);

  void _togglePin(DocPage page) {
    final pins = _saved(_pinKey);
    final at = pins.indexWhere((d) => d.id == page.summary.id);
    setState(() {
      if (at >= 0) {
        pins.removeAt(at);
      } else {
        pins.insert(0, _savedOf(page));
      }
      _save(_pinKey, pins);
    });
  }

  void _remember(DocPage page) {
    final recent = [_savedOf(page), for (final d in _saved(_recentKey)) if (d.id != page.summary.id) d];
    _save(_recentKey, recent.take(_maxRecent).toList());
  }

  // ---- Browse ----

  Future<void> _goTo(DocSourceInfo source, List<(String, String)> path) async {
    final s = AppScope.read(context);
    final seq = ++_browseSeq;
    setState(() {
      _browseSource = source;
      _browsePath = path;
      // The old level goes: its rows would lead somewhere else now.
      _nodes = null;
      _browseLoading = true;
      _browseError = null;
    });
    try {
      final nodes = await s.docs.browse(source, [for (final p in path) p.$1]);
      if (!mounted || seq != _browseSeq) return;
      setState(() {
        _nodes = nodes;
        _browseLoading = false;
      });
    } catch (e) {
      if (!mounted || seq != _browseSeq) return;
      setState(() {
        _browseError = '$e';
        _browseLoading = false;
      });
    }
  }

  void _startBrowse() {
    setState(() => _browse = true);
    final sources = [for (final g in _groups ?? const <DocGroup>[]) if (g.problem.isEmpty) g.source];
    if (_browseSource == null && sources.isNotEmpty) _goTo(sources.first, const []);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  /// Jira and Obsidian task sources: what docs read through.
  static String _keyOf(AppState s) => [
        for (final t in s.tasks.sources)
          if (t.kind == TaskSourceKind.jira || t.kind == TaskSourceKind.obsidian) '${t.id}:${t.enabled}:${t.hasSecret}:${t.options}',
      ].join('|');

  Future<void> _list({bool refresh = false}) async {
    final s = AppScope.read(context);
    final seq = ++_listSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await s.docs.list(query: _query.text, refresh: refresh);
      if (!mounted || seq != _listSeq) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
      // The first page, so the reader isn't empty.
      if (_selected == null && _query.text.trim().isEmpty) {
        final first = groups.expand((g) => g.docs).firstOrNull;
        if (first != null) _open(first.id);
      }
    } catch (e) {
      if (!mounted || seq != _listSeq) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _search(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _list);
  }

  Future<void> _open(String id, {bool remember = false}) async {
    final s = AppScope.read(context);
    final seq = ++_readSeq;
    setState(() {
      _selected = id;
      _pageLoading = true;
      _pageError = null;
      _copied = false;
      _sent = false;
      _sendError = null;
    });
    try {
      final page = await s.docs.read(id);
      if (!mounted || seq != _readSeq) return;
      // Pages you open (not the one shown to start with) go to Recent.
      if (remember) _remember(page);
      setState(() {
        _page = page;
        _pageLoading = false;
      });
    } catch (e) {
      if (!mounted || seq != _readSeq) return;
      setState(() {
        _page = null;
        _pageError = '$e';
        _pageLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // Lists only once Docs is open, and again when the sources change.
    final key = _keyOf(s);
    if (s.view == KumoView.docs && key != _sourcesKey) {
      final changed = _sourcesKey != null;
      _sourcesKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _list(refresh: changed);
      });
    }
    final page = _page;
    return ScreenFrame(
      toolbar: ScreenToolbar(
        breadcrumb: Breadcrumb(
          icon: KIcons.docs,
          parts: page == null ? const ['Docs'] : [page.source.kind.label, ...page.path, page.summary.title],
        ),
        primary: page == null || page.summary.url.isEmpty
            ? null
            : KButton(label: 'Open in ${page.source.kind.label}', icon: KIcons.external, height: 36, onTap: () => openUrl(page.summary.url)),
      ),
      body: LayoutBuilder(builder: (context, box) {
        final showAside = box.maxWidth >= 980 && page != null;
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 260, child: _tree(context)),
          const SizedBox(width: 10),
          Expanded(child: _reader(context)),
          if (showAside) ...[const SizedBox(width: 10), SizedBox(width: 300, child: _aside(context, page))],
        ]);
      }),
      status: [
        for (final g in _groups ?? const <DocGroup>[])
          Flexible(
            child: StatusText(
              g.problem.isNotEmpty ? '${g.source.kind.label} · can’t read' : '${g.source.kind.label} · ${g.source.name}',
              color: g.problem.isNotEmpty ? context.c.warn : null,
              flexible: true,
            ),
          ),
        const Spacer(),
        const StatusText('Read only'),
      ],
    );
  }

  // ---- Pages ----

  Widget _tree(BuildContext context) {
    final c = context.c;
    final groups = _groups;
    final searching = _query.text.trim().isNotEmpty;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(11)),
          child: Row(children: [
            Icon(KIcons.search, size: 14, color: c.text3),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _query,
                onChanged: _search,
                onSubmitted: (_) => _list(),
                style: sans(12.5, color: c.text),
                cursorColor: c.acc,
                decoration: InputDecoration.collapsed(hintText: 'Search docs', hintStyle: sans(12.5, color: c.text3)),
              ),
            ),
            if (_loading)
              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: c.text3))
            else
              KIconButton(icon: Icons.refresh_rounded, label: 'Refresh', size: 22, iconSize: 14, onTap: () => _list(refresh: true)),
          ]),
        ),
        const SizedBox(height: 10),
        if (!searching && groups != null && groups.isNotEmpty) ...[
          KSegmented<bool>(
            label: 'Docs',
            height: 28,
            expand: true,
            value: _browse,
            onChanged: (v) => v ? _startBrowse() : setState(() => _browse = false),
            items: const [(false, 'For you', null), (true, 'Browse', null)],
          ),
          const SizedBox(height: 10),
        ],
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            if (_error case final error?)
              _Note(text: error, warn: true)
            else if (groups == null)
              _Note(text: _loading ? 'Reading your docs…' : '')
            else if (groups.isEmpty)
              const _NoSources()
            else if (searching)
              // Search covers every source and every level.
              ..._sourceGroups(groups, searching: true)
            else if (_browse)
              ..._browseLevel(context, groups)
            else
              ..._forYou(context, groups),
          ]),
        ),
      ]),
    );
  }

  /// Each source's pages (search results, or "Updated lately").
  List<Widget> _sourceGroups(List<DocGroup> groups, {required bool searching}) => [
        for (final g in groups) ...[
          _GroupHeader(group: g),
          if (g.problem.isNotEmpty)
            _Problem(group: g)
          else if (g.docs.isEmpty)
            _Note(text: searching ? 'Nothing matches' : 'No pages yet', indent: true)
          else
            for (final d in g.docs) _DocRow(doc: d, selected: d.id == _selected, onTap: () => _open(d.id, remember: true)),
          const SizedBox(height: 10),
        ],
      ];

  /// For you: what you pinned and read, then what changed lately.
  List<Widget> _forYou(BuildContext context, List<DocGroup> groups) {
    final pins = _saved(_pinKey);
    final recent = [for (final d in _saved(_recentKey)) if (!pins.any((p) => p.id == d.id)) d];
    return [
      const _SectionLabel(icon: KIcons.pin, text: 'Pinned'),
      if (pins.isEmpty)
        const _Note(text: 'Pin a page from its header to keep it here.', indent: true)
      else
        for (final d in pins) _SavedRow(doc: d, selected: d.id == _selected, onTap: () => _open(d.id, remember: true)),
      if (recent.isNotEmpty) ...[
        const SizedBox(height: 10),
        const _SectionLabel(icon: KIcons.clock, text: 'Recent'),
        for (final d in recent) _SavedRow(doc: d, selected: d.id == _selected, onTap: () => _open(d.id, remember: true)),
      ],
      const SizedBox(height: 10),
      const _SectionLabel(icon: KIcons.activity, text: 'Updated lately'),
      ..._sourceGroups(groups, searching: false),
    ];
  }

  /// Browse: a source, where you are in it, and that level.
  List<Widget> _browseLevel(BuildContext context, List<DocGroup> groups) {
    final c = context.c;
    final sources = [for (final g in groups) if (g.problem.isEmpty) g.source];
    final source = _browseSource;
    if (sources.isEmpty || source == null) return [const _Note(text: 'No knowledge base can be read right now.')];
    final s = AppScope.read(context);
    // Long trails fold the middle: Confluence › … › Engineering › Discounts.
    final crumbs = <(String, List<(String, String)>)>[
      (source.kind.label, const []),
      for (var k = 0; k < _browsePath.length; k++) (_browsePath[k].$2, _browsePath.sublist(0, k + 1)),
    ];
    final shown = crumbs.length > 4 ? [crumbs.first, ('…', crumbs[crumbs.length - 3].$2), ...crumbs.sublist(crumbs.length - 2)] : crumbs;
    final hidden = crumbs.length > 4 ? crumbs.sublist(1, crumbs.length - 2).map((c) => c.$1).join(' › ') : '';
    final nodes = _nodes ?? const <DocNode>[];
    return [
      Wrap(spacing: 4, runSpacing: 4, children: [
        for (final src in sources)
          KPressable(
            onTap: () => _goTo(src, const []),
            semanticLabel: '${src.kind.label} · ${src.name}',
            tooltip: '${src.kind.label} · ${src.name}',
            selected: src.id == source.id,
            builder: (context, hover, focus) {
              final on = src.id == source.id;
              return Container(
                height: 26,
                padding: const EdgeInsets.only(left: 4, right: 8),
                decoration: BoxDecoration(
                  color: on ? c.accSoft : (hover || focus ? c.tile : null),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: on ? c.acc : c.chipBorder),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SourceTile(src.kind.badge, size: 16),
                  const SizedBox(width: 5),
                  Text(src.kind.label, style: sans(11.5, weight: FontWeight.w500, color: on ? c.text : c.text2)),
                ]),
              );
            },
          ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 26,
        child: Row(children: [
          if (_browsePath.isNotEmpty) ...[
            KIconButton(icon: KIcons.back, label: 'Up one level', size: 24, iconSize: 14, onTap: () => _goTo(source, _browsePath.sublist(0, _browsePath.length - 1))),
            const SizedBox(width: 2),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(children: [
                for (var k = 0; k < shown.length; k++) ...[
                  if (k > 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Text('›', style: sans(11.5, color: c.text3))),
                  KPressable(
                    onTap: () => _goTo(source, shown[k].$2),
                    semanticLabel: k == shown.length - 1 ? '${shown[k].$1}, where you are' : 'Go to ${shown[k].$1}',
                    tooltip: shown[k].$1 == '…' ? hidden : shown[k].$1,
                    builder: (context, hover, focus) => Container(
                      constraints: const BoxConstraints(maxWidth: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      decoration: BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        shown[k].$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: sans(11.5, weight: k == shown.length - 1 ? FontWeight.w600 : FontWeight.w400, color: k == shown.length - 1 ? c.text : c.text3),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
          if (_browseLoading) SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: c.text3)),
        ]),
      ),
      const SizedBox(height: 6),
      if (_browseError case final error?)
        _Note(text: error, warn: true)
      else if (nodes.isEmpty && !_browseLoading)
        const _Note(text: 'Nothing here yet.')
      else
        for (final n in nodes)
          _NodeRow(
            node: n,
            selected: n.doc != null && n.doc!.id == _selected,
            // A folder opens its level; a page opens itself, › its child pages.
            onTap: () => n.isFolder ? _goTo(source, [..._browsePath, (n.key, n.title)]) : _open(n.doc!.id, remember: true),
            onDrill: !n.isFolder && n.children > 0 ? () => _goTo(source, [..._browsePath, (n.key, n.title)]) : null,
          ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          s.docs.browsesEverything ? 'Every space and folder, one level at a time. Search covers all of it.' : 'Spaces and their recently edited pages. Search covers all of it.',
          style: sans(11, color: c.text3, height: 1.4),
        ),
      ),
    ];
  }

  Widget _reader(BuildContext context) {
    final c = context.c;
    final page = _page;
    Widget body;
    if (_pageError case final error?) {
      body = _Note(text: error, warn: true);
    } else if (page == null) {
      body = Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(_pageLoading ? 'Opening…' : 'Pick a page to read it here.', style: sans(14, color: c.text3)),
      );
    } else {
      final meta = [
        if (page.summary.place.isNotEmpty) page.summary.place,
        if (page.summary.updated case final at?) 'edited ${relativeTime(at)}',
        if (page.summary.author.isNotEmpty) 'by ${page.summary.author}',
      ].join(' · ');
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(page.summary.title, style: sans(28, weight: FontWeight.w600, color: c.text, letterSpacing: -0.7, height: 1.15))),
          const SizedBox(width: 8),
          KIconButton(
            icon: _isPinned(page.summary.id) ? KIcons.pinned : KIcons.pin,
            label: _isPinned(page.summary.id) ? 'Unpin from For you' : 'Pin to For you',
            color: _isPinned(page.summary.id) ? c.acc : null,
            onTap: () => _togglePin(page),
          ),
        ]),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(meta, style: sans(12, color: c.text3)),
        ],
        const SizedBox(height: 22),
        if (page.markdown.trim().isEmpty)
          Text('This page is empty.', style: sans(14, color: c.text3))
        else
          MarkdownView(page.markdown, style: const MdStyle(size: 14)),
      ]);
    }
    return GlassPanel(
      fill: c.paper,
      child: ListView(padding: const EdgeInsets.fromLTRB(36, 30, 36, 30), children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: AnimatedOpacity(opacity: _pageLoading && page != null ? 0.5 : 1, duration: const Duration(milliseconds: 120), child: body),
          ),
        ),
      ]),
    );
  }

  // ---- Agent ----

  Widget _aside(BuildContext context, DocPage page) {
    final c = context.c;
    final rows = [
      ('Source', '${page.source.kind.label} · ${page.source.name}'),
      if (page.summary.place.isNotEmpty) (page.source.kind == DocKind.confluence ? 'Space' : 'Folder', page.summary.place),
      if (page.summary.updated case final at?) ('Edited', relativeTime(at)),
      if (page.summary.author.isNotEmpty) ('By', page.summary.author),
      if (page.file.isNotEmpty) ('File', page.file),
    ];
    return ListView(padding: EdgeInsets.zero, children: [
      Section(
        strong: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(KIcons.agent, size: 16, color: c.acc),
            const SizedBox(width: 8),
            Text('Use with an agent', style: sans(13, weight: FontWeight.w600, color: c.text)),
          ]),
          const SizedBox(height: 8),
          Text('Start an agent in a worktree with this page as context.', style: sans(12, color: c.text3, height: 1.4)),
          const SizedBox(height: 12),
          KButton.primary(label: 'Start agent with this page', expand: true, onTap: () => _startAgent(page)),
          if (AppScope.of(context).activeAgent case final agent? when AppScope.of(context).agents.live) ...[
            const SizedBox(height: 8),
            KButton(
              label: _sent ? 'Sent to ${agent.providerName}' : 'Send to ${agent.providerName}',
              icon: _sent ? KIcons.check : KIcons.send,
              expand: true,
              onTap: _sent ? null : () => _sendToAgent(page, agent),
            ),
            if (_sendError case final error?) ...[
              const SizedBox(height: 6),
              Text(error, style: sans(11.5, color: c.err, height: 1.35)),
            ],
          ],
          const SizedBox(height: 8),
          KButton(
            label: _copied ? 'Copied' : 'Copy as Markdown',
            icon: _copied ? KIcons.check : KIcons.copy,
            expand: true,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: '# ${page.summary.title}\n\n${page.markdown}'));
              if (mounted) setState(() => _copied = true);
            },
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Section(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PanelHeading('Details', size: 13),
          const SizedBox(height: 8),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 58, child: Text(label, style: sans(12, color: c.text3))),
                Expanded(child: SelectableText(value, style: label == 'File' ? mono(11.5, color: c.text2) : sans(12, color: c.text2))),
              ]),
            ),
        ]),
      ),
    ]);
  }

  /// What an agent is told about [page]. A vault note is read where it
  /// is; a Confluence page is saved as Markdown in the temp folder first,
  /// since agents can't sign in to it.
  static Future<String> _promptFor(DocPage page) async {
    var file = page.file;
    if (file.isEmpty) {
      try {
        file = await saveDocForAgent(page);
      } catch (_) {
        file = '';
      }
    }
    final where = file.isEmpty ? '' : ' (saved at $file)';
    final link = page.summary.url.isEmpty ? '' : ' — ${page.summary.url}';
    return 'Read the ${page.source.kind.label} page “${page.summary.title}”$where$link and use it as context.';
  }

  Future<void> _startAgent(DocPage page) async {
    final prompt = await _promptFor(page);
    if (!mounted) return;
    await showNewAgentDialog(context, prompt: '$prompt ', about: [docContext(page)]);
  }

  /// Types the page into the worktree's running agent.
  Future<void> _sendToAgent(DocPage page, AgentRun agent) async {
    final s = AppScope.read(context);
    final prompt = await _promptFor(page);
    final sent = await s.agents.addContext(agent.id, docContext(page), text: prompt);
    if (!mounted) return;
    setState(() {
      _sent = sent;
      _sendError = sent ? null : (s.agents.error ?? 'The page didn’t reach ${agent.providerName}.');
    });
  }
}

/// [page] as an agent's context: its title and where it lives.
AgentContextItem docContext(DocPage page) => AgentContextItem(
      kind: AgentContextKind.doc,
      title: page.summary.title,
      detail: [page.source.kind.label, page.summary.place].where((p) => p.isNotEmpty).join(' · '),
      url: page.summary.url,
    );

/// Writes [page] as Markdown under the temp folder; returns the path.
Future<String> saveDocForAgent(DocPage page) async {
  final dir = Directory('${Directory.systemTemp.path}/kumo-docs');
  await dir.create(recursive: true);
  final name = page.summary.title.replaceAll(RegExp(r'[^\w\- .]+'), '_').trim();
  final file = File('${dir.path}/${name.isEmpty ? 'page' : name}.md');
  final link = page.summary.url.isEmpty ? '' : '\n\nSource: ${page.summary.url}';
  await file.writeAsString('# ${page.summary.title}$link\n\n${page.markdown}\n');
  return file.path;
}

/// `just now`, `5 min ago`, `3 d ago`.
String relativeTime(DateTime t) {
  final m = DateTime.now().difference(t).inSeconds / 60;
  if (m < 1) return 'just now';
  if (m < 60) return '${m.floor()} min ago';
  if (m < 1440) return '${(m / 60).round()} h ago';
  if (m < 10080) return '${(m / 1440).round()} d ago';
  return '${(m / 10080).round()} w ago';
}

// ---------------------------------------------------------------------------

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});
  final DocGroup group;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(children: [
        SourceTile(group.source.kind.badge, size: 20, tooltip: group.source.location),
        const SizedBox(width: 8),
        Text(group.source.kind.label, style: sans(12.5, weight: FontWeight.w600, color: c.text)),
        const SizedBox(width: 6),
        Flexible(child: Text(group.source.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3))),
      ]),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.selected, required this.onTap});
  final DocSummary doc;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sub = [if (doc.place.isNotEmpty) doc.place, if (doc.updated case final at?) relativeTime(at)].join(' · ');
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: doc.title,
      builder: (context, hover, focus) => Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.fromLTRB(34, 6, 8, 6),
        decoration: selected ? chipDecoration(c, radius: 9, fill: c.navActive) : BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(9)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? c.text : c.text2)),
          if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(10.5, color: c.text3)),
          if (doc.excerpt.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(doc.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3, height: 1.35)),
          ],
        ]),
      ),
    );
  }
}

/// A page kept in For you (pinned, recent).
@immutable
class _SavedDoc {
  const _SavedDoc(this.id, this.title, this.badge, this.place);
  final String id;
  final String title;
  final String badge;
  final String place;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Row(children: [
        Icon(icon, size: 12, color: c.text3),
        const SizedBox(width: 6),
        Text(text.toUpperCase(), style: microLabel(c)),
      ]),
    );
  }
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({required this.doc, required this.selected, required this.onTap});
  final _SavedDoc doc;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: doc.title,
      tooltip: doc.place.isEmpty ? doc.title : '${doc.title}\n${doc.place}',
      builder: (context, hover, focus) => Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: selected ? chipDecoration(c, radius: 9, fill: c.navActive) : BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(9)),
        child: Row(children: [
          SourceTile(doc.badge, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? c.text : c.text2)),
              if (doc.place.isNotEmpty) Text(doc.place, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(10.5, color: c.text3)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A Browse entry: a folder (with how many entries), or a page, whose ›
/// goes into its child pages.
class _NodeRow extends StatelessWidget {
  const _NodeRow({required this.node, required this.selected, required this.onTap, this.onDrill});
  final DocNode node;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDrill;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(children: [
      Expanded(
        child: KPressable(
          onTap: onTap,
          selected: selected,
          semanticLabel: node.isFolder ? '${node.title}, ${node.children} inside' : node.title,
          tooltip: node.title,
          builder: (context, hover, focus) => Container(
            margin: const EdgeInsets.only(bottom: 1),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: selected ? chipDecoration(c, radius: 9, fill: c.navActive) : BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(9)),
            child: Row(children: [
              Icon(node.isFolder ? KIcons.folder : KIcons.page, size: 14, color: node.isFolder ? c.text2 : c.text3),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    node.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: sans(12.5, weight: selected ? FontWeight.w600 : FontWeight.w400, color: node.note.isNotEmpty ? c.text3 : (selected ? c.text : c.text2)),
                  ),
                  if (node.note.isNotEmpty) Text(node.note, style: sans(10.5, color: c.text3)),
                ]),
              ),
              if (node.isFolder) ...[
                Text('${node.children}', style: sans(11, color: c.text3)),
                const SizedBox(width: 4),
                Icon(KIcons.chevronRight, size: 14, color: c.text3),
              ],
            ]),
          ),
        ),
      ),
      if (onDrill != null)
        KIconButton(
          icon: KIcons.chevronRight,
          label: '${node.children} ${node.children == 1 ? 'page' : 'pages'} under ${node.title}',
          size: 26,
          iconSize: 15,
          onTap: onDrill,
        ),
    ]);
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.group});
  final DocGroup group;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 2, 8, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(group.problem, style: sans(11.5, color: c.warn, height: 1.4)),
        if (group.problemIsAuth) ...[
          const SizedBox(height: 6),
          KButton(label: 'Fix in Settings', height: 28, fontSize: 12, onTap: () => showSettingsDialog(context, initial: SettingsTab.tickets)),
        ],
      ]),
    );
  }
}

class _NoSources extends StatelessWidget {
  const _NoSources();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('No docs yet', style: sans(13, weight: FontWeight.w600, color: c.text)),
        const SizedBox(height: 6),
        Text(
          'Docs reads Confluence with the Atlassian account of a Jira source, and the notes of your Obsidian vaults. Add one in Settings › Tasks.',
          style: sans(12, color: c.text3, height: 1.45),
        ),
        const SizedBox(height: 10),
        KButton(label: 'Open Settings', height: 30, fontSize: 12, onTap: () => showSettingsDialog(context, initial: SettingsTab.tickets)),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.warn = false, this.indent = false});
  final String text;
  final bool warn;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? 34 : 6, 4, 6, 4),
      child: Text(text, style: sans(12, color: warn ? c.warn : c.text3, height: 1.4)),
    );
  }
}
