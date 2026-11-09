import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/agent_defs.dart';
import '../platform/pasteboard.dart';
import '../theme/kumo_theme.dart';
import '../views/agents_library.dart' show AgentAvatar, CheckLine, riskColors;
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';

/// "Create an agent": from a template, from a description a connected CLI
/// drafts,
/// or from a .md file (dropped, chosen, or pasted). Returns the unsaved
/// agent and where it came from, for Edit to open; null when cancelled.
Future<(AgentDef, String)?> showCreateAgentDialog(BuildContext context, {bool import = false}) {
  final c = context.c;
  return showGeneralDialog<(AgentDef, String)>(
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
        child: Material(type: MaterialType.transparency, child: CreateAgentDialog(import: import)),
      ),
    ),
  );
}

class CreateAgentDialog extends StatefulWidget {
  const CreateAgentDialog({super.key, this.import = false});

  /// Opens on "Import a .md file".
  final bool import;

  @override
  State<CreateAgentDialog> createState() => _CreateAgentDialogState();
}

class _CreateAgentDialogState extends State<CreateAgentDialog> {
  late bool _import = widget.import;
  String _template = agentTemplates.first.id;
  final _describe = TextEditingController();
  final _paste = TextEditingController();
  AgentScope _scope = AgentScope.personal;
  String? _repo;
  String? _file;
  bool _drafting = false;
  final _dropZone = GlobalKey();
  StreamSubscription<FileDrop>? _drops;

  @override
  void initState() {
    super.initState();
    _describe.addListener(() => setState(() {}));
    _paste.addListener(() => setState(() {}));
    _drops = Pasteboard.drops.listen(_onDrop);
  }

  @override
  void dispose() {
    _drops?.cancel();
    _describe.dispose();
    _paste.dispose();
    super.dispose();
  }

  /// A file dropped on the window: taken when it lands on the drop zone.
  void _onDrop(FileDrop drop) {
    if (!_import || !mounted || drop.paths.isEmpty) return;
    final box = _dropZone.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(drop.position);
    if (!(Offset.zero & box.size).contains(local)) return;
    _read(drop.paths.first);
  }

  Future<void> _read(String path) async {
    try {
      final text = await File(path).readAsString();
      if (!mounted) return;
      setState(() {
        _file = path.split(Platform.pathSeparator).last;
        _paste.text = text;
      });
    } on Object catch (e) {
      if (mounted) AppScope.read(context).notify('Couldn’t read ${path.split(Platform.pathSeparator).last}: $e');
    }
  }

  Future<void> _choose() async {
    final path = await Pasteboard.chooseFile(extensions: const ['md', 'markdown', 'txt'], message: 'An agent file: frontmatter, then its instructions');
    if (path != null) await _read(path);
  }

  Set<String> _taken(AppState s) => {
        for (final a in s.agentDefs.agents)
          if (a.scope == _scope && (_scope == AgentScope.personal || a.repo == (_repo ?? ''))) a.name,
      };

  Future<void> _go(AppState s) async {
    final repo = _scope == AgentScope.project ? (_repo ?? '') : '';
    if (_import) {
      final read = readAgentFile(_paste.text, scope: _scope, repo: repo, taken: _taken(s));
      if (!read.usable) return;
      Navigator.of(context).pop((read.agent!, 'Imported from ${_file ?? 'what you pasted'}. Check it, then save: nothing is written until you do.'));
      return;
    }
    final text = _describe.text.trim();
    final writer = s.agents.askCli?.short;
    if (text.isNotEmpty && writer != null) {
      setState(() => _drafting = true);
      final draft = await s.agentDefs.draft(text, scope: _scope, repo: repo);
      if (!mounted) return;
      setState(() => _drafting = false);
      if (draft == null) {
        s.notify('$writer couldn’t draft it: ${s.agentDefs.error ?? 'try again'}');
        return;
      }
      Navigator.of(context).pop((draft, '$writer drafted this from your description. Check every field: nothing is saved yet.'));
      return;
    }
    final t = agentTemplates.firstWhere((x) => x.id == _template);
    var name = t.id == 'blank' ? 'new-agent' : t.id;
    final taken = _taken(s);
    for (var n = 2; taken.contains(name); n++) {
      name = '${t.id == 'blank' ? 'new-agent' : t.id}-$n';
    }
    Navigator.of(context).pop((t.draft(scope: _scope, repo: repo, name: name), t.blank ? 'A blank agent with safe defaults. Nothing is saved until you save it.' : 'From the ${t.label} template. Nothing is saved until you save it.'));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    _repo ??= s.activeRepo?.name ?? s.workspace.repos.firstOrNull?.name;
    final writer = s.agents.askCli?.short;
    final read = _import ? readAgentFile(_paste.text, scope: _scope, repo: _repo ?? '', taken: _taken(s)) : null;
    final canGo = !_drafting && (!_import || (read?.usable ?? false)) && (_scope == AgentScope.personal || _repo != null);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
          if (canGo) _go(s);
        },
      },
      child: GlassOverlay(
        width: 660,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
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
                Text(_import ? 'Import an agent' : 'Create an agent', style: sans(15, weight: FontWeight.w600, color: c.text)),
                Text(
                  _import
                      ? 'A Claude Code agent file: from a repo, a teammate, or a post. Nothing is saved until you check it in Edit.'
                      : 'One agent for every CLI you’ve connected: you choose which one each time you run it.',
                  style: sans(11.5, color: c.text3),
                ),
              ]),
            ),
            KIconButton(icon: KIcons.close, label: 'Close', onTap: () => Navigator.of(context).maybePop()),
          ]),
          const SizedBox(height: 16),
          Flexible(child: SingleChildScrollView(child: _import ? _importBody(context, read) : _pickBody(context, writer))),
          const SizedBox(height: 12),
          Container(height: 1, color: c.divider),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('For', style: sans(12, color: c.text3)),
            KSegmented<AgentScope>(
              label: 'Who can use it',
              value: _scope,
              onChanged: (v) => setState(() => _scope = v),
              items: const [(AgentScope.personal, 'Personal', null), (AgentScope.project, 'Project', null)],
            ),
            if (_scope == AgentScope.project && s.workspace.repos.isNotEmpty)
              SizedBox(
                width: 180,
                child: KSelect<String>(
                  label: 'Repository',
                  value: s.workspace.repos.any((r) => r.name == _repo) ? _repo! : s.workspace.repos.first.name,
                  items: [for (final r in s.workspace.repos) (r.name, r.name)],
                  onChanged: (v) => setState(() => _repo = v),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: KButton(
                  label: _import ? 'Templates' : 'Import a .md file…',
                  icon: _import ? KIcons.back : KIcons.upload,
                  height: 32,
                  fontSize: 12.5,
                  kind: KButtonKind.ghost,
                  onTap: () => setState(() => _import = !_import),
                ),
              ),
            ),
            const SizedBox(width: 8),
            KButton(label: 'Cancel', height: 32, fontSize: 12.5, onTap: () => Navigator.of(context).maybePop()),
            const SizedBox(width: 8),
            KButton.primary(
              label: _drafting ? 'Drafting…' : (_import ? 'Open in Edit' : (writer != null && _describe.text.trim().isNotEmpty ? 'Draft it with $writer' : 'Continue')),
              height: 32,
              fontSize: 12.5,
              onTap: canGo ? () => _go(s) : null,
              trailing: Kbd('⌘↩', color: c.accText, background: const Color(0x26000000)),
            ),
          ]),
        ]),
      ),
    );
  }

  /// [writer]: the connected CLI that drafts; null when there's none.
  Widget _pickBody(BuildContext context, String? writer) {
    final c = context.c;
    final describing = writer != null && _describe.text.trim().isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('START FROM', style: sans(10.5, weight: FontWeight.w600, color: c.text3, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth > 560 ? 3 : 2;
        final w = (box.maxWidth - 8 * (cols - 1)) / cols;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in agentTemplates)
            SizedBox(width: w, child: _TemplateCard(template: t, selected: !describing && _template == t.id, onTap: () => setState(() {
              _template = t.id;
              _describe.clear();
            }))),
        ]);
      }),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: describing ? c.accSoft : c.pane, borderRadius: BorderRadius.circular(14), border: Border.all(color: describing ? c.acc : c.paneBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(KIcons.sparkle, size: 13, color: c.acc),
            const SizedBox(width: 7),
            Text(writer == null ? 'Or describe it, and have it drafted' : 'Or describe it, and $writer drafts it', style: sans(12.5, weight: FontWeight.w600, color: c.text)),
          ]),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.chipBorder)),
            child: TextField(
              controller: _describe,
              enabled: writer != null,
              minLines: 2,
              maxLines: 4,
              style: sans(12.5, color: c.text, height: 1.45),
              cursorColor: c.acc,
              decoration: InputDecoration.collapsed(hintText: 'An agent that checks our SQL migrations are reversible before they’re merged', hintStyle: sans(12.5, color: c.text3, height: 1.45)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            writer == null
                ? 'Connect Claude Code, Codex or Copilot in Settings › AI agents, and it writes the agent from what you describe.'
                : '$writer writes the name, description, instructions and a tool list to match. You check every field before it’s saved.',
            style: sans(11, color: c.text3),
          ),
        ]),
      ),
    ]);
  }

  Widget _importBody(BuildContext context, AgentFileRead? read) {
    final c = context.c;
    final a = read?.agent;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        key: _dropZone,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _file == null ? c.chipBorder : c.acc, width: 1.5)),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(11)),
            child: Icon(_file == null ? KIcons.upload : KIcons.file, size: 17, color: _file == null ? c.text3 : c.acc),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_file ?? 'Drop a .md file here', style: sans(12.5, weight: FontWeight.w600, color: c.text)),
              Text(
                _file != null
                    ? 'Read into the box below: change anything before it comes in.'
                    : (Pasteboard.canChoose ? 'or choose one: it opens your system’s file dialog' : 'or paste it below'),
                style: sans(11.5, color: c.text3),
              ),
            ]),
          ),
          if (Pasteboard.canChoose) KButton(label: _file == null ? 'Choose a file…' : 'Choose another…', height: 30, fontSize: 12, onTap: _choose),
        ]),
      ),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text('Or paste it', style: sans(12.5, weight: FontWeight.w600, color: c.text)),
        const SizedBox(width: 8),
        Flexible(child: Text('the frontmatter between --- lines, then its instructions', style: sans(11.5, color: c.text3))),
      ]),
      const SizedBox(height: 5),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(11), border: Border.all(color: c.chipBorder)),
        child: TextField(
          controller: _paste,
          minLines: 7,
          maxLines: 12,
          onChanged: (_) => _file = null,
          style: mono(11.5, color: c.text, height: 1.55),
          cursorColor: c.acc,
          decoration: InputDecoration.collapsed(
            hintText: '---\nname: security-reviewer\ndescription: Reviews changes for security issues. Use it before merging…\ntools: Read, Grep, Glob\n---\n\nYou are a security reviewer…',
            hintStyle: mono(11.5, color: c.text3, height: 1.55),
          ),
        ),
      ),
      if (read != null && read.checks.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.pane, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.paneBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (a != null) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AgentAvatar(name: a.name, color: a.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(a.name, style: mono(12.5, weight: FontWeight.w600, color: c.text)),
                      Text(agentToolsKind(a.tools).$2, style: sans(10.5, weight: FontWeight.w600, color: riskColors(c, agentToolsKind(a.tools).$1).$1)),
                      Text('· ${agentModelLabel(a.model)}', style: sans(10.5, color: c.text3)),
                    ]),
                    Text(a.description.isEmpty ? 'No description' : a.description, style: sans(11.5, color: c.text2, height: 1.4)),
                  ]),
                ),
              ]),
              const SizedBox(height: 6),
            ],
            for (final x in read.checks) CheckLine(x),
          ]),
        ),
      ],
    ]);
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.selected, required this.onTap});
  final AgentTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = template;
    final (risk, kind) = agentToolsKind(t.tools);
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: t.label,
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected ? c.accSoft : (hover ? c.tile : c.pane),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected || focus ? c.acc : c.paneBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AgentAvatar(name: t.label.toLowerCase().replaceAll(' ', '-'), color: t.color, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(t.label, style: sans(12.5, weight: FontWeight.w600, color: c.text))),
          ]),
          const SizedBox(height: 5),
          Text(t.hint, maxLines: 3, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text2, height: 1.4)),
          const SizedBox(height: 5),
          Text(kind, style: sans(10.5, weight: FontWeight.w600, color: riskColors(c, risk).$1)),
        ]),
      ),
    );
  }
}
