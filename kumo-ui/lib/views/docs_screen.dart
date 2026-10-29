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

  Future<void> _open(String id) async {
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
        const SizedBox(height: 12),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            if (_error case final error?)
              _Note(text: error, warn: true)
            else if (groups == null)
              _Note(text: _loading ? 'Reading your docs…' : '')
            else if (groups.isEmpty)
              const _NoSources()
            else
              for (final g in groups) ...[
                _GroupHeader(group: g),
                if (g.problem.isNotEmpty)
                  _Problem(group: g)
                else if (g.docs.isEmpty)
                  _Note(text: searching ? 'Nothing matches' : 'No pages yet', indent: true)
                else
                  for (final d in g.docs) _DocRow(doc: d, selected: d.id == _selected, onTap: () => _open(d.id)),
                const SizedBox(height: 10),
              ],
          ]),
        ),
      ]),
    );
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
        Text(page.summary.title, style: sans(28, weight: FontWeight.w600, color: c.text, letterSpacing: -0.7, height: 1.15)),
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
