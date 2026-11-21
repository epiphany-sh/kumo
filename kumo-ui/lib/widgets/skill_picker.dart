import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/agent_defs_source.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import 'anchored_popover.dart';
import 'controls.dart';
import 'glass.dart';
import 'kicons.dart';
import 'search_marks.dart';

/// Picks the skills an agent loads, out of however many there are: a search
/// field on top, then every skill grouped by where it comes from (personal,
/// each repository, each plugin) with what it's for. Several can be picked,
/// so the list stays open. Arrows move, Return adds or removes, Esc closes.
class SkillPicker extends StatelessWidget {
  const SkillPicker({super.key, required this.selected, required this.skills, required this.onChanged});

  /// The agent's skills, in its file's order.
  final List<String> selected;

  /// Every skill it can be given.
  final List<AgentSkill> skills;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnchoredPopover(
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, 6),
      triggerBuilder: (context, toggle, open) => KPressable(
        onTap: toggle,
        semanticLabel: 'Add skills',
        builder: (context, hover, focus) => Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: hover || open ? c.tile : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: open || focus ? c.acc : c.chipBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(KIcons.add, size: 13, color: c.text2),
            const SizedBox(width: 4),
            Text('Add skills', style: sans(11.5, color: c.text2)),
            if (skills.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text('${skills.length} on this Mac', style: sans(10.5, color: c.text3)),
            ],
          ]),
        ),
      ),
      popoverBuilder: (context, close) => _SkillList(initial: selected, skills: skills, onChanged: onChanged),
    );
  }
}

class _Group {
  _Group(this.key, this.title, this.icon, this.rows, {this.label = false});
  final String key;
  final String title;
  final IconData icon;
  final List<AgentSkill> rows;

  /// Personal and Not found here read as labels, in capitals; a repository
  /// or a plugin keeps its name as it is.
  final bool label;
}

/// A line of the list: a group's heading or a skill.
class _Line {
  const _Line.heading(this.group) : skill = null;
  const _Line.skill(this.group, AgentSkill this.skill);
  final _Group group;
  final AgentSkill? skill;
}

const _rowHeight = 46.0;
const _headingHeight = 30.0;
const _notHere = 'Not on this Mac: Claude Code skips it when the agent runs.';

class _SkillList extends StatefulWidget {
  const _SkillList({required this.initial, required this.skills, required this.onChanged});

  final List<String> initial;
  final List<AgentSkill> skills;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_SkillList> createState() => _SkillListState();
}

class _SkillListState extends State<_SkillList> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  final _folded = <String>{};
  late final List<String> _picked = [...widget.initial];
  bool _onlyPicked = false;

  /// The skill arrows and Return act on, in [_rows] order; -1: none yet.
  int _active = -1;
  List<AgentSkill> _rows = const [];
  List<_Line> _lines = const [];

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() => _active = _query.text.trim().isEmpty ? -1 : 0));
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<String> get _words => searchWords(_query.text);

  void _toggle(String name) {
    setState(() => _picked.contains(name) ? _picked.remove(name) : _picked.add(name));
    widget.onChanged(List.of(_picked));
  }

  List<_Group> _groups() {
    final words = _words;
    bool matches(AgentSkill k) => words.every((w) => k.name.toLowerCase().contains(w) || k.description.toLowerCase().contains(w) || k.fromName.toLowerCase().contains(w));
    bool shown(AgentSkill k) => matches(k) && (!_onlyPicked || _picked.contains(k.name));
    final groups = <_Group>[];
    final byKey = <String, _Group>{};
    for (final k in widget.skills) {
      if (!shown(k)) continue;
      final key = '${k.from.name}:${k.fromName}';
      byKey
          .putIfAbsent(key, () {
            final g = switch (k.from) {
              SkillFrom.personal => _Group(key, 'Personal', KIcons.folder, [], label: true),
              SkillFrom.repo => _Group(key, k.fromName, KIcons.repo, []),
              SkillFrom.plugin => _Group(key, '${k.fromName} plugin', KIcons.plug, []),
            };
            groups.add(g);
            return g;
          })
          .rows
          .add(k);
    }
    // Named in the agent's file but not found here (another Mac, removed).
    final known = {for (final k in widget.skills) k.name};
    final missing = [
      for (final name in _picked)
        if (!known.contains(name)) AgentSkill(name, description: _notHere),
    ].where(matches).toList();
    if (missing.isNotEmpty) groups.add(_Group('missing', 'Not found here', KIcons.warning, missing, label: true));
    return groups;
  }

  bool _open(_Group g) => _words.isNotEmpty || _onlyPicked || !_folded.contains(g.key);

  void _move(int delta) {
    if (_rows.isEmpty) return;
    setState(() => _active = ((_active < 0 ? (delta > 0 ? -1 : 0) : _active) + delta) % _rows.length);
    _reveal();
  }

  /// Scrolls the active skill into view (rows and headings are fixed heights).
  void _reveal() {
    if (!_scroll.hasClients || _active < 0) return;
    var top = 6.0;
    var seen = -1;
    for (final l in _lines) {
      if (l.skill == null) {
        top += _headingHeight;
        continue;
      }
      if (++seen == _active) break;
      top += _rowHeight;
    }
    final view = _scroll.position.viewportDimension;
    final at = _scroll.offset;
    if (top < at) {
      _scroll.jumpTo(top - 6);
    } else if (top + _rowHeight > at + view) {
      _scroll.jumpTo((top + _rowHeight - view + 6).clamp(0, _scroll.position.maxScrollExtent));
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      _move(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_active >= 0 && _active < _rows.length) _toggle(_rows[_active].name);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final groups = _groups();
    final lines = <_Line>[];
    final rows = <AgentSkill>[];
    for (final g in groups) {
      lines.add(_Line.heading(g));
      if (!_open(g)) continue;
      for (final k in g.rows) {
        lines.add(_Line.skill(g, k));
        rows.add(k);
      }
    }
    _lines = lines;
    _rows = rows;
    final total = widget.skills.length;
    final searching = _words.isNotEmpty;
    final matching = {for (final g in groups) ...g.rows.map((k) => k.name)}.length;
    return GlassOverlay(
      width: 440,
      blur: false,
      radius: 16,
      padding: EdgeInsets.zero,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(color: c.tile, border: Border(bottom: BorderSide(color: c.divider))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(KIcons.search, size: 15, color: c.text3),
              const SizedBox(width: 8),
              Expanded(
                child: Focus(
                  onKeyEvent: _onKey,
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    style: sans(13, color: c.text),
                    cursorColor: c.acc,
                    decoration: InputDecoration.collapsed(hintText: 'Search skills by name, what they do or where they’re from', hintStyle: sans(13, color: c.text3)),
                  ),
                ),
              ),
              if (_query.text.isNotEmpty) KIconButton(icon: KIcons.close, label: 'Clear search', size: 24, iconSize: 12, onTap: _query.clear),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(children: [
            KSegmented<bool>(
              label: 'Show',
              height: 22,
              items: [(false, 'All', '$total'), (true, 'Selected', '${_picked.length}')],
              value: _onlyPicked,
              onChanged: (v) => setState(() {
                _onlyPicked = v;
                _active = -1;
              }),
            ),
            const Spacer(),
            if (_picked.isNotEmpty)
              KButton(
                label: 'Clear',
                kind: KButtonKind.ghost,
                height: 24,
                fontSize: 11.5,
                onTap: () {
                  setState(_picked.clear);
                  widget.onChanged(const []);
                },
              ),
          ]),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: matching == 0
              ? _empty(c, searching)
              : ListView.builder(
                  controller: _scroll,
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(6),
                  itemCount: lines.length,
                  itemBuilder: (context, i) {
                    final l = lines[i];
                    return l.skill == null ? _heading(c, l.group) : _row(c, l.skill!, rows.indexOf(l.skill!));
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
          decoration: BoxDecoration(color: c.tile, border: Border(top: BorderSide(color: c.divider))),
          child: Row(children: [
            Expanded(
              child: Text(
                searching ? '$matching of $total skills' : '${_picked.length} selected · $total skills',
                style: sans(11, color: c.text3),
              ),
            ),
            const Kbd('↑'),
            const SizedBox(width: 3),
            const Kbd('↓'),
            const SizedBox(width: 5),
            Text('move', style: sans(11, color: c.text3)),
            const SizedBox(width: 10),
            const Kbd('↩'),
            const SizedBox(width: 5),
            Text('add or remove', style: sans(11, color: c.text3)),
          ]),
        ),
      ]),
    );
  }

  Widget _empty(KumoPalette c, bool searching) {
    final (title, body, action, onAction) = searching
        ? (
            'No skill matches “${_query.text.trim()}”',
            'Search looks at names, what each skill does and where it’s from: ~/.claude/skills, a repository’s .claude/skills and your plugins.',
            'Clear search',
            _query.clear,
          )
        : _onlyPicked
            ? ('No skills picked yet', 'Search above or switch to All, then tick the ones it should load.', 'Show all', () => setState(() => _onlyPicked = false))
            : ('No skills on this Mac yet', 'Add one in ~/.claude/skills or a repository’s .claude/skills, or install a plugin that has skills.', null, null);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title, textAlign: TextAlign.center, style: sans(13, weight: FontWeight.w600, color: c.text)),
        const SizedBox(height: 4),
        Text(body, textAlign: TextAlign.center, style: sans(12, color: c.text3, height: 1.45)),
        if (action != null) ...[
          const SizedBox(height: 10),
          KButton(label: action, height: 28, fontSize: 12, onTap: onAction),
        ],
      ]),
    );
  }

  Widget _heading(KumoPalette c, _Group g) {
    final open = _open(g);
    final foldable = _words.isEmpty && !_onlyPicked;
    final picked = g.rows.where((k) => _picked.contains(k.name)).length;
    final tint = g.key == 'missing' ? c.warn : c.text3;
    final head = SizedBox(
      height: _headingHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
        child: Row(children: [
          if (foldable) ...[
            AnimatedRotation(turns: open ? 0.25 : 0, duration: const Duration(milliseconds: 120), child: Icon(KIcons.chevronRight, size: 11, color: c.text3)),
            const SizedBox(width: 5),
          ],
          Icon(g.icon, size: 12, color: tint),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              g.label ? g.title.toUpperCase() : g.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sans(11, weight: FontWeight.w600, color: tint, letterSpacing: g.label ? 0.4 : 0),
            ),
          ),
          const SizedBox(width: 6),
          Text(picked > 0 ? '$picked of ${g.rows.length}' : '${g.rows.length}', style: sans(11, color: tint)),
        ]),
      ),
    );
    if (!foldable) return head;
    return KPressable(
      onTap: () => setState(() => open ? _folded.add(g.key) : _folded.remove(g.key)),
      semanticLabel: '${open ? 'Fold' : 'Unfold'} ${g.title}',
      builder: (context, hover, focus) => head,
    );
  }

  Widget _row(KumoPalette c, AgentSkill k, int at) {
    final on = _picked.contains(k.name);
    final active = at == _active;
    final words = _words;
    final row = MouseRegion(
      onEnter: (_) {
        if (_active != at) setState(() => _active = at);
      },
      child: KPressable(
        onTap: () => _toggle(k.name),
        semanticLabel: '${on ? 'Remove' : 'Add'} skill ${k.name}',
        selected: on,
        builder: (context, hover, focus) => Container(
          height: _rowHeight - 2,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: on ? c.accSoft : (active || hover ? c.tile : null),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: on ? c.accFill : null,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: on ? c.accFill : c.text3, width: 1.4),
              ),
              child: on ? Icon(KIcons.check, size: 11, color: c.accText) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                markedText(c, k.name, words, mono(12.5, weight: FontWeight.w500, color: c.text)),
                if (k.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  markedText(c, k.description, words, sans(11, color: widget.skills.contains(k) ? c.text3 : c.warn)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
    if (k.description.length < 60) return row;
    return Tooltip(message: k.description, waitDuration: const Duration(milliseconds: 700), child: row);
  }
}
