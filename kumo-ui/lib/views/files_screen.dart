import 'package:flutter/material.dart';

import '../data/mock_project.dart';
import '../editor/code_editor.dart';
import '../editor/syntax.dart';
import '../editor/working_copy.dart';
import '../shell/screen_chrome.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';

Color gitColor(KumoPalette c, GitStatus? s) => switch (s) {
      GitStatus.modified => c.warn,
      GitStatus.added || GitStatus.untracked => c.ok,
      GitStatus.deleted || GitStatus.conflict => c.err,
      null => c.text,
    };

Color langColor(KumoPalette c, Lang l, String badge) => switch (l) {
      Lang.go => c.synType,
      Lang.yaml => c.synKw,
      Lang.json => c.synNum,
      Lang.makefile => c.warn,
      Lang.plain when badge == 'SUM' => c.synType,
      _ => c.text3,
    };

/// Project explorer + tabbed, editable, highlighted editor + source control.
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final _wc = WorkingCopy();
  final _controllers = <String, CodeController>{};
  final _saved = <String, String>{};
  final _dirty = <String>{};
  final _collapsed = <String>{'cmd'};
  final _caret = ValueNotifier<(int, int)>((1, 1));
  final _commitMsg = TextEditingController(text: 'feat(discount): bulk discounts by category (PRC-412)');
  List<String> _tabs = ['internal/discount/repository.go', MockProject.conflictPath, 'testdata/bulk_discount.json'];
  String? _active = 'internal/discount/repository.go';
  bool _changedOnly = false;
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    _wc.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _wc.dispose();
    _caret.dispose();
    _commitMsg.dispose();
    super.dispose();
  }

  CodeController _ctrl(String path) {
    return _controllers.putIfAbsent(path, () {
      final text = MockProject.files[path] ?? '';
      _saved[path] = text;
      final c = CodeController(text: text, lang: langOf(path).lang, deleted: _wc.statusOf(path) == GitStatus.deleted);
      c.addListener(() {
        final isDirty = c.text != _saved[path];
        if (isDirty != _dirty.contains(path)) setState(() => isDirty ? _dirty.add(path) : _dirty.remove(path));
        if (path == _active) _caret.value = c.caret;
      });
      return c;
    });
  }

  void _open(String path) => setState(() {
        if (!_tabs.contains(path)) _tabs = [..._tabs, path];
        _active = path;
      });

  void _close(String path) => setState(() {
        final idx = _tabs.indexOf(path);
        _tabs = [..._tabs]..remove(path);
        if (_active == path) _active = _tabs.isEmpty ? null : _tabs[idx < _tabs.length ? idx : _tabs.length - 1];
      });

  void _save() {
    final p = _active;
    if (p == null) return;
    setState(() {
      _saved[p] = _ctrl(p).text;
      _dirty.remove(p);
    });
  }

  void _resolve(String keep) {
    final c = _ctrl(MockProject.conflictPath);
    c.text = MockProject.resolveConflict(c.text, keep);
    _saved[MockProject.conflictPath] = c.text;
    _dirty.remove(MockProject.conflictPath);
    _wc.resolve(keep);
  }

  void _restore() {
    _ctrl(MockProject.deletedPath).deleted = false;
    _wc.restore();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final active = _active;
    final info = active == null ? null : langOf(active);
    final conflicts = _wc.conflicts.length;
    return ScreenFrame(
      toolbar: ScreenToolbar(
        breadcrumb: const Breadcrumb(icon: KIcons.branch, parts: ['price-admin', 'feat/PRC-412-bulk-discounts']),
        searchHint: 'Go to file or symbol…',
        searchKey: '⌘P',
        primary: KButton.primary(label: 'Ask agent about file', icon: KIcons.agent, height: 36, onTap: () {}),
      ),
      body: LayoutBuilder(builder: (context, box) {
        final showScm = box.maxWidth >= 980;
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 250, child: _explorer(context)),
          const SizedBox(width: 10),
          Expanded(child: _editor(context)),
          if (showScm) ...[const SizedBox(width: 10), SizedBox(width: 290, child: _sourceControl(context))],
        ]);
      }),
      status: [
        StatusText('feat/PRC-412-bulk-discounts ↑${_wc.ahead} ↓0', icon: KIcons.branch, monospace: true),
        StatusText(conflicts > 0 ? '1 merge conflict' : 'No conflicts', color: conflicts > 0 ? c.err : null),
        const Spacer(),
        if (info != null) ...[
          ValueListenableBuilder<(int, int)>(valueListenable: _caret, builder: (context, v, _) => StatusText('Ln ${v.$1}, Col ${v.$2}')),
          StatusText('${info.indent} · UTF-8 · LF'),
          if (info.server.isNotEmpty) StatusText(info.server),
        ],
      ],
    );
  }

  // ───────────────────────── Explorer ─────────────────────────

  Widget _explorer(BuildContext context) {
    final c = context.c;
    final rows = <Widget>[];
    void walk(List<TreeNode> nodes, String prefix, int depth) {
      for (final n in nodes) {
        final path = prefix.isEmpty ? n.name : '$prefix/${n.name}';
        if (n.isDir) {
          final agg = _wc.dirStatus(path);
          if (_changedOnly && agg == null) continue;
          final open = _changedOnly || !_collapsed.contains(path);
          rows.add(_TreeRow(
            depth: depth,
            name: n.name,
            isDir: true,
            open: open,
            nameColor: agg == null ? c.text : (agg == GitStatus.conflict ? c.err : c.warn),
            dot: agg == null ? null : (agg == GitStatus.conflict ? c.err : c.warn),
            onTap: () => setState(() => open ? _collapsed.add(path) : _collapsed.remove(path)),
          ));
          if (open) walk(n.children!, path, depth + 1);
        } else {
          final s = _wc.statusOf(path);
          if (_changedOnly && s == null) continue;
          final li = langOf(path);
          rows.add(_TreeRow(
            depth: depth,
            name: n.name,
            isDir: false,
            badge: li.badge,
            badgeColor: langColor(c, li.lang, li.badge),
            status: s,
            selected: path == _active,
            nameColor: gitColor(c, s),
            onTap: () => _open(path),
          ));
        }
      }
    }

    walk(MockProject.tree, '', 0);
    final changedCount = _wc.changed.length;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(children: [
            Expanded(child: Text('EXPLORER', style: microLabel(c))),
            KIconButton(icon: KIcons.fileAdd, label: 'New file', size: 26, iconSize: 15, onTap: () {}),
            KIconButton(icon: KIcons.folderAdd, label: 'New folder', size: 26, iconSize: 15, onTap: () {}),
            KIconButton(icon: KIcons.collapseAll, label: 'Collapse all folders', size: 26, iconSize: 15, onTap: () => setState(() => _collapsed.addAll(['cmd', 'config', 'deploy', 'internal', 'testdata']))),
          ]),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: KSegmented<bool>(
            expand: true,
            height: 26,
            label: 'Show files',
            value: _changedOnly,
            onChanged: (v) => setState(() => _changedOnly = v),
            items: [(false, 'All files', null), (true, 'Changed', '$changedCount')],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: ListView(padding: EdgeInsets.zero, children: rows)),
        Container(height: 1, color: c.divider, margin: const EdgeInsets.only(top: 6, bottom: 8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(spacing: 10, runSpacing: 4, children: [
            for (final s in GitStatus.values)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(s.letter, style: mono(10.5, weight: FontWeight.w700, color: gitColor(c, s))),
                const SizedBox(width: 4),
                Text(s.label, style: sans(10.5, color: c.text3)),
              ]),
          ]),
        ),
      ]),
    );
  }

  // ───────────────────────── Editor ─────────────────────────

  Widget _editor(BuildContext context) {
    final c = context.c;
    final active = _active;
    return GlassPanel(
      fill: c.term,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            children: [for (final p in _tabs) _tab(context, p)],
          ),
        ),
        if (active == null)
          Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('No file open', style: sans(14, weight: FontWeight.w600, color: c.text2)),
                const SizedBox(height: 6),
                Text('Pick a file in the explorer or press ⌘P', style: sans(12.5, color: c.text3)),
              ]),
            ),
          )
        else ...[
          _breadcrumbRow(context, active),
          ..._banners(context, active),
          Expanded(
            child: CodeEditor(
              key: ValueKey(active),
              controller: _ctrl(active),
              readOnly: _wc.statusOf(active) == GitStatus.deleted,
              decorate: (lines) => _decorate(c, active, lines),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _tab(BuildContext context, String path) {
    final c = context.c;
    final sel = path == _active;
    final s = _wc.statusOf(path);
    final li = langOf(path);
    final name = path.split('/').last;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        height: 30,
        padding: const EdgeInsets.only(right: 3),
        decoration: sel ? chipDecoration(c, radius: 10, fill: c.tabActive) : BoxDecoration(borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          KPressable(
            onTap: () => setState(() => _active = path),
            semanticLabel: 'Tab $name',
            selected: sel,
            builder: (context, hover, focus) => Padding(
              padding: const EdgeInsets.fromLTRB(9, 0, 4, 0),
              child: Row(children: [
                Text(li.badge, style: mono(8.5, weight: FontWeight.w700, color: langColor(c, li.lang, li.badge))),
                const SizedBox(width: 7),
                Text(name, style: sans(12, weight: FontWeight.w500, color: sel ? c.text : c.text2).copyWith(decoration: s == GitStatus.deleted ? TextDecoration.lineThrough : null)),
                if (s != null) ...[const SizedBox(width: 6), Text(s.letter, style: mono(10.5, weight: FontWeight.w700, color: gitColor(c, s)))],
                if (_dirty.contains(path)) ...[const SizedBox(width: 6), Semantics(label: 'Unsaved changes', child: Dot(c.text))],
              ]),
            ),
          ),
          KIconButton(icon: KIcons.close, label: 'Close $name', size: 20, iconSize: 12, color: c.text3, onTap: () => _close(path)),
        ]),
      ),
    );
  }

  Widget _breadcrumbRow(BuildContext context, String path) {
    final c = context.c;
    final parts = path.split('/');
    final crumbs = parts.length > 1 ? 'price-admin › ${parts.sublist(0, parts.length - 1).join(' › ')} › ' : 'price-admin › ';
    final info = langOf(path);
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
      child: Row(children: [
        Flexible(child: Text(crumbs, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, color: c.text3))),
        Text(parts.last, style: mono(11.5, weight: FontWeight.w600, color: c.text)),
        const Spacer(),
        Kbd(info.label),
        if (_dirty.contains(path)) ...[
          const SizedBox(width: 8),
          KButton.primary(label: 'Save', height: 26, fontSize: 11.5, onTap: _save, trailing: Text('⌘S', style: sans(11, color: c.accText.withAlpha(190)))),
        ],
      ]),
    );
  }

  List<Widget> _banners(BuildContext context, String path) {
    final c = context.c;
    final s = _wc.statusOf(path);
    Widget banner(Color bg, IconData icon, Color fg, String title, String body, List<Widget> actions) => Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 6, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 8),
              Text(title, style: sans(12, weight: FontWeight.w600, color: fg)),
            ]),
            Text(body, style: sans(12, color: c.text2)),
            ...actions,
          ]),
        );
    if (path == MockProject.conflictPath && s == GitStatus.conflict) {
      return [
        banner(c.errSoft, KIcons.warning, c.err, 'Merge conflict with main', 'Both branches changed the image tag.', [
          KButton(label: 'Accept current', kind: KButtonKind.ghost, height: 26, fontSize: 11.5, onTap: () => _resolve('current')),
          KButton(label: 'Accept incoming', kind: KButtonKind.ghost, height: 26, fontSize: 11.5, onTap: () => _resolve('incoming')),
          KButton(label: 'Accept both', kind: KButtonKind.ghost, height: 26, fontSize: 11.5, onTap: () => _resolve('both')),
          KButton(label: _asked ? 'Sent to Claude' : 'Ask Claude to resolve', icon: KIcons.agent, kind: KButtonKind.ghost, height: 26, fontSize: 11.5, onTap: () => setState(() => _asked = true)),
        ]),
      ];
    }
    if (path == MockProject.conflictPath && _wc.resolution != null && s == GitStatus.modified) {
      return [banner(c.okSoft, KIcons.check, c.ok, 'Conflict resolved', 'Stage the file to finish the merge.', const [])];
    }
    if (s == GitStatus.deleted) {
      return [
        banner(c.errSoft, KIcons.warning, c.err, 'Deleted in this worktree', 'Showing the last committed version.', [
          KButton(label: 'Restore file', height: 26, fontSize: 11.5, onTap: _restore),
        ]),
      ];
    }
    return const [];
  }

  List<LineDeco> _decorate(KumoPalette c, String path, List<String> lines) {
    final s = _wc.statusOf(path);
    final conflictActive = MockProject.hasConflictMarkers(lines.join('\n'));
    final marks = <int, bool>{};
    if (s != null && !conflictActive) {
      for (final (from, to, add) in MockProject.marks[path] ?? const <(int, int, bool)>[]) {
        for (var n = from; n <= to; n++) {
          marks[n] = add;
        }
      }
    }
    final whole = s == GitStatus.added || s == GitStatus.untracked;
    String? zone;
    final out = <LineDeco>[];
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      Color? bg;
      if (conflictActive && l.startsWith('<<<<<<<')) {
        zone = 'cur';
        bg = c.curMark;
      } else if (conflictActive && l.startsWith('=======')) {
        zone = 'inc';
        bg = c.divider;
      } else if (conflictActive && l.startsWith('>>>>>>>')) {
        zone = null;
        bg = c.incMark;
      } else if (zone == 'cur') {
        bg = c.curBg;
      } else if (zone == 'inc') {
        bg = c.incBg;
      }
      if (s == GitStatus.deleted) {
        out.add(LineDeco(bar: c.err, background: c.delBg));
        continue;
      }
      final kind = whole ? true : marks[i + 1];
      out.add(LineDeco(bar: kind == null ? null : (kind ? c.ok : c.acc), background: bg));
    }
    return out;
  }

  // ───────────────────────── Source control ─────────────────────────

  Widget _sourceControl(BuildContext context) {
    final c = context.c;
    final sections = [
      ('Merge conflicts', _wc.conflicts, 'conflict', c.err),
      ('Staged', _wc.stagedList, 'staged', c.text),
      ('Changes', _wc.unstagedChanges, 'changes', c.text),
      ('Untracked', _wc.untracked, 'untracked', c.text),
    ].where((s) => s.$2.isNotEmpty).toList();
    final canCommit = _wc.canCommit;
    final hint = _wc.conflicts.isNotEmpty
        ? 'Resolve the merge conflict before committing'
        : (_wc.stagedList.isNotEmpty
            ? 'Commits to feat/PRC-412-bulk-discounts'
            : (_wc.lastCommitSize != null ? 'Committed ${_wc.lastCommitSize} files · not pushed yet' : 'Stage files to commit'));
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(children: [
            Expanded(child: Text('SOURCE CONTROL', style: microLabel(c))),
            Text('↑${_wc.ahead} ↓0', style: mono(11, color: c.text2)),
          ]),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Commit message', style: sans(11, color: c.text3)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(11), border: Border.all(color: c.chipBorder)),
              child: TextField(
                controller: _commitMsg,
                minLines: 2,
                maxLines: 4,
                style: sans(12.5, color: c.text, height: 1.4),
                cursorColor: c.acc,
                decoration: const InputDecoration.collapsed(hintText: 'Commit message'),
              ),
            ),
            const SizedBox(height: 8),
            KButton.primary(
              label: canCommit ? 'Commit ${_wc.stagedList.length} ${_wc.stagedList.length == 1 ? 'file' : 'files'}' : 'Commit',
              expand: true,
              height: 32,
              onTap: canCommit ? () => _wc.commit() : null,
            ),
            const SizedBox(height: 6),
            Text(hint, style: sans(11.5, color: _wc.conflicts.isNotEmpty ? c.err : c.text3)),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            for (final (title, items, mode, color) in sections) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
                child: Row(children: [
                  Expanded(child: Text(title, style: sans(11.5, weight: FontWeight.w600, color: color))),
                  Text('${items.length}', style: sans(11.5, color: c.text3)),
                ]),
              ),
              for (final p in items) _scmRow(context, p, mode),
              const SizedBox(height: 12),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _scmRow(BuildContext context, String path, String mode) {
    final c = context.c;
    final s = _wc.statusOf(path);
    final parts = path.split('/');
    final name = parts.removeLast();
    final li = langOf(path);
    final col = gitColor(c, s);
    return Container(
      decoration: BoxDecoration(color: path == _active ? c.navActive : null, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Expanded(
          child: KPressable(
            onTap: () => _open(path),
            semanticLabel: 'Open $name',
            builder: (context, hover, focus) => Container(
              height: 26,
              padding: const EdgeInsets.only(left: 6, right: 4),
              decoration: BoxDecoration(color: hover ? c.tile : null, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                SizedBox(width: 22, child: Text(li.badge, textAlign: TextAlign.center, style: mono(8.5, weight: FontWeight.w700, color: langColor(c, li.lang, li.badge)))),
                const SizedBox(width: 6),
                Text(name, style: sans(12.5, color: col).copyWith(decoration: s == GitStatus.deleted ? TextDecoration.lineThrough : null)),
                const SizedBox(width: 6),
                Expanded(child: Text(parts.join('/'), maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3))),
                Text(s?.letter ?? '', style: mono(10.5, weight: FontWeight.w700, color: col)),
              ]),
            ),
          ),
        ),
        if (mode != 'conflict')
          KIconButton(
            icon: mode == 'staged' ? KIcons.remove : KIcons.add,
            label: '${mode == 'staged' ? 'Unstage' : 'Stage'} $name',
            size: 24,
            iconSize: 14,
            onTap: () => mode == 'staged' ? _wc.unstage(path) : _wc.stage(path),
          ),
      ]),
    );
  }
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.depth,
    required this.name,
    required this.isDir,
    required this.nameColor,
    required this.onTap,
    this.open = false,
    this.badge,
    this.badgeColor,
    this.status,
    this.selected = false,
    this.dot,
  });

  final int depth;
  final String name;
  final bool isDir;
  final bool open;
  final String? badge;
  final Color? badgeColor;
  final GitStatus? status;
  final bool selected;
  final Color nameColor;
  final Color? dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: isDir ? '$name folder, ${open ? 'expanded' : 'collapsed'}' : '$name${status != null ? ', ${status!.label}' : ''}',
      builder: (context, hover, focus) => Container(
        height: 26,
        margin: const EdgeInsets.only(bottom: 1),
        padding: EdgeInsets.only(left: 6.0 + depth * 14 + (isDir ? 0 : 4), right: 8),
        decoration: selected
            ? chipDecoration(c, radius: 8, fill: c.navActive)
            : BoxDecoration(color: hover ? c.tile : null, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          if (isDir) ...[
            Icon(open ? KIcons.chevronDown : KIcons.chevronRight, size: 14, color: c.text3),
            const SizedBox(width: 2),
            Icon(open ? KIcons.folderOpen : KIcons.folder, size: 15, color: c.text3),
          ] else
            SizedBox(width: 22, child: Text(badge ?? '', textAlign: TextAlign.center, style: mono(8.5, weight: FontWeight.w700, color: badgeColor ?? c.text3))),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sans(12.5, weight: isDir || selected ? FontWeight.w500 : FontWeight.w400, color: nameColor)
                  .copyWith(decoration: status == GitStatus.deleted ? TextDecoration.lineThrough : null),
            ),
          ),
          if (dot != null) ...[Dot(dot!, size: 6), const SizedBox(width: 4)],
          if (status != null)
            Container(
              constraints: const BoxConstraints(minWidth: 14),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(color: status == GitStatus.conflict ? c.errSoft : null, borderRadius: BorderRadius.circular(4)),
              child: Text(status!.letter, textAlign: TextAlign.center, style: mono(10.5, weight: FontWeight.w700, color: gitColor(c, status))),
            ),
        ]),
      ),
    );
  }
}
