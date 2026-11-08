import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/agent_defs.dart';
import '../data/agent_defs_source.dart';
import '../data/agent_playground.dart';
import '../data/agents_source.dart';
import '../data/models.dart' show AgentStatus, Repo, Worktree;
import '../data/tasks_source.dart';
import '../overlays/create_agent_dialog.dart';
import '../shell/screen_chrome.dart';
import '../terminal/terminal_surface.dart';
import '../terminal/terminal_view.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/controls.dart';
import '../widgets/kicons.dart';
import 'agent_terminals.dart';

part 'agents_run.dart';
part 'agents_edit.dart';
part 'agents_playground.dart';

enum _Tab { run, edit, play }

/// An agent's color, from its file's name for it.
Color agentColor(KumoPalette c, String name) => switch (name) {
      'red' => c.err,
      'blue' => c.acc,
      'green' => c.ok,
      'yellow' => c.yellow,
      'purple' => c.purple,
      'orange' => c.warn,
      'pink' => c.isDark ? const Color(0xFFFF8FC7) : const Color(0xFFB4237A),
      _ => c.cyan,
    };

String _initials(String name) => name.split('-').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join().toUpperCase();

/// The square with an agent's initials, in its color.
class AgentAvatar extends StatelessWidget {
  const AgentAvatar({super.key, required this.name, required this.color, this.size = 28});
  final String name;
  final String color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = agentColor(c, color);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: col.withAlpha(c.isDark ? 40 : 34), borderRadius: BorderRadius.circular(size / 3), border: Border.all(color: col.withAlpha(90))),
      child: Text(_initials(name.isEmpty ? 'new' : name), style: mono(size * 0.36, weight: FontWeight.w600, color: col)),
    );
  }
}

(Color, Color) riskColors(KumoPalette c, AgentRisk r) => switch (r) {
      AgentRisk.commands || AgentRisk.edits => (c.warn, c.warnSoft),
      AgentRisk.web => (c.acc, c.accSoft),
      AgentRisk.none => (c.err, c.errSoft),
      AgentRisk.read => (c.ok, c.okSoft),
    };

/// What Your agents keeps while you look at Sessions: the agent shown, its
/// tab, unsaved edits and new agents, run forms. The Agents view owns it.
class AgentLibraryMemory {
  String? sel;
  _Tab tab = _Tab.run;

  /// Edits not saved yet, by the agent's key as saved.
  final drafts = <String, AgentDef>{};

  /// New agents not saved yet, by a key of their own.
  final fresh = <String, AgentDef>{};
  int freshSeq = 0;

  /// Where each unsaved agent came from.
  final notes = <String, String>{};

  /// Each agent's run form (where, context, first message).
  final forms = <String, _RunForm>{};

  /// The run whose terminal is shown, by agent (null: the run form).
  final shownRun = <String, String?>{};

  /// Unsaved new agents or edits.
  bool get unsaved => fresh.isNotEmpty || drafts.isNotEmpty;

  void dispose() {
    for (final f in forms.values) {
      f.dispose();
    }
  }
}

/// Agents › Your agents: the Claude Code subagents of this workspace and its
/// repositories, each to run in a terminal of its own, edit, and try out.
class AgentLibrary extends StatefulWidget {
  const AgentLibrary({super.key, required this.terminals, required this.memory});

  /// The runs' terminals (the Agents view keeps them attached).
  final AgentTerminals terminals;

  /// Kept by the Agents view across Sessions and back.
  final AgentLibraryMemory memory;

  @override
  State<AgentLibrary> createState() => AgentLibraryState();
}

class AgentLibraryState extends State<AgentLibrary> {
  AgentLibraryMemory get _m => widget.memory;
  String? get _sel => _m.sel;
  set _sel(String? v) => _m.sel = v;
  _Tab get _tab => _m.tab;
  set _tab(_Tab v) => _m.tab = v;
  Map<String, AgentDef> get _drafts => _m.drafts;
  Map<String, AgentDef> get _fresh => _m.fresh;
  Map<String, _RunForm> get _forms => _m.forms;
  Map<String, String?> get _shownRun => _m.shownRun;
  Map<String, String> get _notes => _m.notes;
  final _search = TextEditingController();
  AppState? _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.read(context);
    if (!identical(app, _app)) {
      _app?.agentsRequest.removeListener(_onRequest);
      _app = app..agentsRequest.addListener(_onRequest);
      app.agentDefs.load().ignore();
      WidgetsBinding.instance.addPostFrameCallback((_) => _onRequest());
    }
  }

  @override
  void dispose() {
    _app?.agentsRequest.removeListener(_onRequest);
    _search.dispose();
    super.dispose();
  }

  void _onRequest() {
    final app = _app;
    final r = app?.agentsRequest.value;
    if (app == null || r == null || r.agent == null || !mounted) return;
    app.agentsRequest.value = null;
    if (r.tab == 'new') {
      create();
      return;
    }
    setState(() {
      _sel = r.agent;
      _tab = switch (r.tab) { 'edit' => _Tab.edit, 'playground' => _Tab.play, _ => _Tab.run };
      if (r.run != null) _shownRun[r.agent!] = r.run;
    });
  }

  /// Opens "Create an agent"; what it makes opens in Edit, unsaved.
  Future<void> create() async {
    final draft = await showCreateAgentDialog(context);
    if (draft == null || !mounted) return;
    addDraft(draft.$1, note: draft.$2);
  }

  /// [agent] joins the list unsaved, open in Edit.
  void addDraft(AgentDef agent, {String note = ''}) {
    final key = 'new:${++_m.freshSeq}';
    setState(() {
      _fresh[key] = agent;
      _notes[key] = note;
      _sel = key;
      _tab = _Tab.edit;
    });
  }


  List<(String, AgentDef)> _all(AgentDefsSource defs) => [
        for (final a in defs.agents) (a.key, a),
        for (final e in _fresh.entries) (e.key, e.value),
      ];

  /// Names taken where [a] would be saved, besides its own.
  Set<String> _taken(AgentDefsSource defs, String key, AgentDef a) => {
        for (final (k, x) in _all(defs))
          if (k != key && x.scope == a.scope && (a.scope == AgentScope.personal || x.repo == a.repo)) (_drafts[k] ?? x).name,
      };

  _RunForm _formOf(String key) => _forms.putIfAbsent(key, _RunForm.new);

  void _edit(String key, AgentDef next) => setState(() {
        if (_fresh.containsKey(key)) {
          _fresh[key] = next;
        } else {
          _drafts[key] = next;
        }
      });

  Future<void> _save(AgentDefsSource defs, String key, AgentDef saved, AgentDef cur) async {
    final s = AppScope.read(context);
    try {
      final out = await defs.save(cur, previous: _fresh.containsKey(key) ? null : saved);
      if (!mounted) return;
      setState(() {
        _drafts.remove(key);
        _fresh.remove(key);
        _notes.remove(key);
        final form = _forms.remove(key);
        if (form != null) _forms[out.key] = form;
        _sel = out.key;
      });
      s.notify('Saved ${out.file}${out.scope == AgentScope.project ? ' · Git shows it as a change' : ''}');
    } on Object catch (e) {
      s.notify('Couldn’t save ${cur.name}: $e');
    }
  }

  Future<void> _delete(AgentDefsSource defs, String key, AgentDef saved) async {
    if (_fresh.containsKey(key)) {
      setState(() {
        _fresh.remove(key);
        _sel = null;
      });
      return;
    }
    await defs.delete(saved);
    if (!mounted) return;
    setState(() {
      _drafts.remove(key);
      _sel = null;
    });
    AppScope.read(context).notify('Deleted ${saved.file}');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final defs = s.agentDefs;
    return ListenableBuilder(
      listenable: defs,
      builder: (context, _) {
        if (!defs.supported) return _Unsupported(error: defs.error);
        final all = _all(defs);
        final sel = all.where((e) => e.$1 == _sel).firstOrNull ?? all.firstOrNull;
        return LayoutBuilder(builder: (context, box) {
          final listW = box.maxWidth < 1000 ? 240.0 : 288.0;
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: listW, child: _list(context, defs, all, sel?.$1)),
            const SizedBox(width: 10),
            Expanded(
              child: Section(
                padding: const EdgeInsets.all(18),
                child: sel == null ? _NoAgents(onCreate: create) : _detail(context, defs, sel.$1, sel.$2),
              ),
            ),
          ]);
        });
      },
    );
  }

  Widget _list(BuildContext context, AgentDefsSource defs, List<(String, AgentDef)> all, String? selKey) {
    final c = context.c;
    final s = AppScope.of(context);
    final q = _search.text.trim().toLowerCase();
    bool match(AgentDef a) => q.isEmpty || a.name.contains(q) || a.description.toLowerCase().contains(q);
    final groups = <(String, String, List<(String, AgentDef)>)>[
      ('Personal', 'only you · this workspace', [for (final e in all) if (e.$2.scope == AgentScope.personal && match(_drafts[e.$1] ?? e.$2)) e]),
      for (final repo in {for (final e in all) if (e.$2.scope == AgentScope.project) e.$2.repo})
        (repo, 'project · shared through git', [for (final e in all) if (e.$2.scope == AgentScope.project && e.$2.repo == repo && match(_drafts[e.$1] ?? e.$2)) e]),
    ];
    return Section(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(children: [
            Expanded(child: Text('Your agents', style: sans(14, weight: FontWeight.w600, color: c.text))),
            Text('Claude Code', style: sans(11.5, color: c.text3)),
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.chipBorder)),
          child: Row(children: [
            Icon(KIcons.search, size: 14, color: c.text3),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: sans(12.5, color: c.text),
                cursorColor: c.acc,
                decoration: InputDecoration.collapsed(hintText: 'Filter by name or what it does', hintStyle: sans(12.5, color: c.text3)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            for (final (label, note, rows) in groups)
              if (rows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text(label.toUpperCase(), style: sans(10.5, weight: FontWeight.w600, color: c.text3, letterSpacing: 0.5)),
                    const SizedBox(width: 6),
                    Flexible(child: Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3))),
                  ]),
                ),
                for (final (key, a) in rows)
                  _AgentRow(
                    agent: _drafts[key] ?? a,
                    selected: key == selKey,
                    edited: _drafts.containsKey(key) && _drafts[key] != a,
                    unsaved: _fresh.containsKey(key),
                    running: _fresh.containsKey(key) ? 0 : defs.runsOf(a).where((r) => r.status != AgentStatus.done).length,
                    last: _fresh.containsKey(key) ? 'not saved' : _lastRun(defs.runsOf(a)),
                    onTap: () => setState(() => _sel = key),
                  ),
                const SizedBox(height: 12),
              ],
            if (groups.every((g) => g.$3.isEmpty))
              Padding(padding: const EdgeInsets.all(8), child: Text(q.isEmpty ? 'No agents yet.' : 'No agent matches “$q”.', style: sans(12, color: c.text3))),
          ]),
        ),
        Container(height: 1, color: c.divider, margin: const EdgeInsets.only(bottom: 10)),
        KButton(label: 'Create agent', icon: KIcons.add, height: 32, fontSize: 12.5, expand: true, onTap: create),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            'Claude Code subagent files: ${s.workspace.repos.isEmpty ? '' : '.claude/agents/*.md. '}Ones you add by hand show up here too.',
            style: sans(11, color: c.text3, height: 1.4),
          ),
        ),
      ]),
    );
  }

  static String _lastRun(List<AgentRun> runs) {
    if (runs.isEmpty) return 'never run';
    if (runs.any((r) => r.status != AgentStatus.done)) return 'running now';
    final d = DateTime.now().difference(runs.first.startedAt);
    if (d.inMinutes < 60) return '${math.max(1, d.inMinutes)}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return d.inDays == 1 ? 'yesterday' : '${d.inDays} days ago';
  }

  Widget _detail(BuildContext context, AgentDefsSource defs, String key, AgentDef saved) {
    final c = context.c;
    final cur = _drafts[key] ?? saved;
    final fresh = _fresh.containsKey(key);
    final dirty = fresh || (_drafts.containsKey(key) && _drafts[key] != saved);
    final runs = fresh ? const <AgentRun>[] : defs.runsOf(saved);
    final live = runs.where((r) => r.status != AgentStatus.done).length;
    final (risk, kind) = agentToolsKind(cur.tools);
    final (fg, bg) = riskColors(c, risk);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.start, alignment: WrapAlignment.spaceBetween, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            AgentAvatar(name: cur.name, color: cur.color, size: 40),
            const SizedBox(width: 12),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(cur.name.isEmpty ? 'new agent' : cur.name, style: mono(18, weight: FontWeight.w600, color: c.text)),
                  Pill(label: cur.scope == AgentScope.project ? 'Project · ${cur.repo}' : 'Personal', color: c.text2, background: c.tile, dot: false),
                  Pill(label: kind, color: fg, background: bg, dot: false),
                ]),
                const SizedBox(height: 4),
                Text(cur.description.isEmpty ? 'No description yet.' : cur.description, style: sans(12.5, color: c.text2, height: 1.45)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(KIcons.file, size: 12, color: c.text3),
                  const SizedBox(width: 6),
                  Flexible(child: Text(cur.file, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3))),
                  Text(fresh ? ' · not saved yet' : (cur.scope == AgentScope.project ? ' · in git' : ' · this workspace only'), style: sans(11, color: c.text3)),
                ]),
              ]),
            ),
          ]),
        ),
        KSegmented<_Tab>(
          label: cur.name,
          value: _tab,
          onChanged: (t) => setState(() => _tab = t),
          height: 30,
          items: [
            (_Tab.run, 'Run', live > 0 ? '$live running' : null),
            (_Tab.edit, 'Edit', dirty ? '•' : null),
            (_Tab.play, 'Playground', null),
          ],
        ),
      ]),
      const SizedBox(height: 18),
      Expanded(
        child: switch (_tab) {
          _Tab.run => _RunTab(
              key: ValueKey('run-$key'),
              agentKey: key,
              agent: saved,
              current: cur,
              fresh: fresh,
              dirty: dirty,
              runs: runs,
              form: _formOf(key),
              shown: _shownRun[key],
              terminals: widget.terminals,
              onShow: (id) => setState(() => _shownRun[key] = id),
              onEdit: () => setState(() => _tab = _Tab.edit),
              onTry: () => setState(() => _tab = _Tab.play),
            ),
          _Tab.edit => _AgentEditor(
              key: ValueKey('edit-$key'),
              saved: fresh ? null : saved,
              agent: cur,
              note: _notes[key] ?? '',
              taken: _taken(defs, key, cur),
              onChanged: (a) => _edit(key, a),
              onSave: () => _save(defs, key, saved, cur),
              onDiscard: () => setState(() => _drafts.remove(key)),
              onDelete: () => _delete(defs, key, saved),
              onTest: () => setState(() => _tab = _Tab.play),
            ),
          _Tab.play => _Playground(
              key: ValueKey('play-$key'),
              saved: fresh ? null : saved,
              history: fresh ? AgentDef(name: key) : saved,
              agent: cur,
              dirty: dirty,
              onChanged: (a) => _edit(key, a),
              onSave: agentSavable(cur, taken: _taken(defs, key, cur)) ? () => _save(defs, key, saved, cur) : null,
              onEdit: () => setState(() => _tab = _Tab.edit),
            ),
        },
      ),
    ]);
  }
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.agent, required this.selected, required this.edited, required this.unsaved, required this.running, required this.last, required this.onTap});
  final AgentDef agent;
  final bool selected;
  final bool edited;
  final bool unsaved;
  final int running;
  final String last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = agent;
    final (risk, kind) = agentToolsKind(a.tools);
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '${a.name}, $kind',
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: selected ? c.navActive : (hover ? c.tile : null),
          borderRadius: BorderRadius.circular(12),
          border: focus ? Border.all(color: c.acc, width: 1.5) : null,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AgentAvatar(name: a.name, color: a.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(a.name.isEmpty ? 'new agent' : a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(12.5, weight: FontWeight.w600, color: c.text))),
                if (running > 0) ...[const SizedBox(width: 6), Dot(c.acc, size: 6), const SizedBox(width: 3), Text('$running running', style: sans(10.5, weight: FontWeight.w600, color: c.acc))],
                if (unsaved || edited) ...[const SizedBox(width: 6), Text(unsaved ? 'not saved' : 'edited', style: sans(10.5, weight: FontWeight.w600, color: c.warn))],
              ]),
              const SizedBox(height: 2),
              Text(a.description.isEmpty ? 'No description yet' : a.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text2, height: 1.35)),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: kind, style: TextStyle(color: riskColors(c, risk).$1, fontWeight: FontWeight.w600)),
                  TextSpan(text: ' · ${agentModelLabel(a.model)} · $last'),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sans(10.5, color: c.text3),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _NoAgents extends StatelessWidget {
  const _NoAgents({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(KIcons.agent, size: 26, color: c.text3),
        const SizedBox(height: 12),
        Text('No agents of your own yet', style: sans(13.5, weight: FontWeight.w600, color: c.text2)),
        const SizedBox(height: 4),
        Text('Start from a template, describe one for Claude to draft, or import a .md file.', style: sans(12.5, color: c.text3)),
        const SizedBox(height: 14),
        KButton.primary(label: 'Create agent', icon: KIcons.add, height: 32, onTap: onCreate),
      ]),
    );
  }
}

class _Unsupported extends StatelessWidget {
  const _Unsupported({this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Section(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(KIcons.agent, size: 26, color: c.text3),
            const SizedBox(height: 12),
            Text('Your agents need a newer engine', style: sans(13.5, weight: FontWeight.w600, color: c.text2)),
            const SizedBox(height: 6),
            Text(
              '${error ?? 'This version of Kumo’s engine can’t read agent files yet.'} Your Claude Code agents in .claude/agents still work in any terminal: `claude --agent <name>`.',
              textAlign: TextAlign.center,
              style: sans(12.5, color: c.text3, height: 1.45),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A small titled block of the forms.
class _Block extends StatelessWidget {
  const _Block({required this.title, this.hint = '', required this.child, this.trailing});
  final String title;
  final String hint;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(title, style: sans(13, weight: FontWeight.w600, color: c.text)),
        if (hint.isNotEmpty) ...[const SizedBox(width: 8), Flexible(child: Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3)))],
        if (trailing != null) ...[const Spacer(), trailing!],
      ]),
      const SizedBox(height: 8),
      child,
    ]);
  }
}

/// A check's line: icon and text in its level's color.
class CheckLine extends StatelessWidget {
  const CheckLine(this.check, {super.key});
  final AgentCheck check;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (icon, color) = switch (check.level) {
      CheckLevel.ok => (KIcons.check, c.ok),
      CheckLevel.info => (KIcons.info, c.text3),
      CheckLevel.warn => (KIcons.warning, c.warn),
      CheckLevel.error => (KIcons.warning, c.err),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 13, color: color)),
        const SizedBox(width: 6),
        Expanded(child: Text(check.text, style: sans(11.5, color: color, height: 1.4))),
      ]),
    );
  }
}

/// A multi-line field in the glass style.
class _Area extends StatelessWidget {
  const _Area({required this.controller, this.minLines = 2, this.maxLines = 8, this.hint = '', this.monospace = false, this.onChanged, this.border, this.label});
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final String hint;
  final bool monospace;
  final ValueChanged<String>? onChanged;
  final Color? border;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = monospace ? mono(11.5, color: c.text, height: 1.55) : sans(12.5, color: c.text, height: 1.45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(11), border: Border.all(color: border ?? c.chipBorder)),
      child: Semantics(
        label: label,
        textField: true,
        child: TextField(
          key: label == null ? null : ValueKey('field-$label'),
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          onChanged: onChanged,
          style: style,
          cursorColor: c.acc,
          decoration: InputDecoration.collapsed(hintText: hint, hintStyle: style.copyWith(color: c.text3)),
        ),
      ),
    );
  }
}

/// A one-line field in the glass style.
class _Line extends StatelessWidget {
  const _Line({required this.controller, this.hint = '', this.monospace = false, this.onChanged, this.onSubmitted, this.border, this.label});
  final TextEditingController controller;
  final String hint;
  final bool monospace;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Color? border;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = monospace ? mono(12, color: c.text) : sans(12.5, color: c.text);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: border ?? c.chipBorder)),
      child: Semantics(
        label: label,
        textField: true,
        child: TextField(
          key: label == null ? null : ValueKey('field-$label'),
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: style,
          cursorColor: c.acc,
          decoration: InputDecoration.collapsed(hintText: hint, hintStyle: style.copyWith(color: c.text3)),
        ),
      ),
    );
  }
}

/// A removable chip (context, skills, knowledge…).
class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.tag, this.onRemove, this.note, this.tooltip});
  final String label;
  final String? tag;
  final VoidCallback? onRemove;
  final String? note;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final chip = Container(
      height: 28,
      padding: EdgeInsets.only(left: tag == null ? 10 : 6, right: onRemove == null ? 10 : 2),
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.chipBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (tag != null) ...[TagChip(tag!), const SizedBox(width: 6)],
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 260), child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text))),
        if (note != null) ...[const SizedBox(width: 6), Text(note!, style: sans(10.5, color: c.text3))],
        if (onRemove != null) KIconButton(icon: KIcons.close, label: 'Remove $label', size: 24, iconSize: 12, onTap: onRemove),
      ]),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

/// "+ Add"-style dashed button.
class _AddChip extends StatelessWidget {
  const _AddChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, hover, focus) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hover ? c.tile : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: focus ? c.acc : c.chipBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(KIcons.add, size: 13, color: c.text2),
          const SizedBox(width: 4),
          Text(label, style: sans(11.5, color: c.text2)),
        ]),
      ),
    );
  }
}

/// A labeled counter: "Turns 7 / 25" with a bar.
class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, this.fraction, this.tooltip});
  final String label;
  final String value;
  final double? fraction;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final f = fraction;
    final color = f != null && f > 0.85 ? c.warn : c.acc;
    // A fixed width: a bar that fills a fraction can't be measured by its
    // content (IntrinsicWidth fails on it).
    final w = SizedBox(
      width: 150,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(label, maxLines: 1, style: sans(11, color: c.text3)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: mono(11, color: f == null ? c.text2 : color))),
        ]),
        const SizedBox(height: 3),
        Container(
          height: 3,
          decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(2)),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: (f ?? 0).clamp(0.0, 1.0), child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)))),
        ),
      ]),
    );
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}
