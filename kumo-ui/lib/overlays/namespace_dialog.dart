import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/models.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';

/// Opens the namespace modal: create a new one, or (with [edit]) change the
/// repos and name of an existing one.
Future<void> showNamespaceDialog(BuildContext context, {Namespace? edit}) {
  final c = context.c;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: c.isDark ? const Color(0x66000000) : const Color(0x33141428),
    transitionDuration: const Duration(milliseconds: 140),
    transitionBuilder: (context, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)), child: child),
    ),
    pageBuilder: (context, _, __) => Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
        child: Material(type: MaterialType.transparency, child: NamespaceDialog(edit: edit)),
      ),
    ),
  );
}

class NamespaceDialog extends StatefulWidget {
  const NamespaceDialog({super.key, this.edit});
  final Namespace? edit;

  @override
  State<NamespaceDialog> createState() => _NamespaceDialogState();
}

class _NamespaceDialogState extends State<NamespaceDialog> {
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  final _filter = TextEditingController();
  String _src = 'all';
  late final Set<String> _checked = {...?widget.edit?.repos};
  bool _saved = false;

  /// Set once a new namespace was created, so "Edit again" updates it
  /// instead of creating a second one.
  String? _createdId;

  bool get _isNew => widget.edit == null;

  @override
  void initState() {
    super.initState();
    _filter.addListener(() => setState(() {}));
    // Look for repositories on disk while the dialog opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).workspace.discover();
    });
  }

  /// Repositories that can go in a namespace (from the daemon or the mocks).
  List<RepoCandidate> get _candidates => AppScope.read(context).workspace.candidates;

  @override
  void dispose() {
    _name.dispose();
    _filter.dispose();
    super.dispose();
  }

  void _save() {
    final s = AppScope.read(context);
    final repos = [for (final cand in _candidates) if (_checked.contains(cand.repo.id)) cand.repo.id];
    final id = widget.edit?.id ?? _createdId;
    if (id == null) {
      _createdId = s.createNamespace(_name.text, repos);
    } else {
      s.updateNamespace(id, name: _name.text, repos: repos);
    }
    setState(() => _saved = true);
  }

  void _close() => Navigator.of(context).maybePop();

  /// Other namespaces a candidate already belongs to ("in identity").
  String? _tagFor(RepoCandidate cand, List<Namespace> all) {
    final others = [
      for (final n in all)
        if (n.id != (widget.edit?.id ?? _createdId) && n.repos.contains(cand.repo.id)) n.name,
    ];
    return others.isEmpty ? null : 'in ${others.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = AppScope.of(context);
    final title = _isNew ? 'New namespace' : 'Repositories in namespace';
    final subtitle = _isNew
        ? 'Name it and pick the repos it groups. Kumo lists every worktree of each one in the sidebar.'
        : 'Pick the repos this namespace groups. Kumo lists every worktree of each one in the sidebar.';
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: FocusScope(
        autofocus: true,
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          namesRoute: true,
          label: title,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: GlassOverlay(
              radius: 24,
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(11)),
                    child: Icon(KIcons.namespace, size: 18, color: c.acc),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: sans(16, weight: FontWeight.w600, color: c.text)),
                      Text(subtitle, style: sans(12, color: c.text3)),
                    ]),
                  ),
                  KIconButton(icon: KIcons.close, label: 'Close', size: 30, iconSize: 15, onTap: _close),
                ]),
                const SizedBox(height: 14),
                if (_saved) ..._done() else ..._form(s),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _form(AppState s) {
    final p = context.c;
    final q = _filter.text.trim().toLowerCase();
    int count(String h) => _candidates.where((r) => h == 'all' || r.host == h).length;
    final rows = [
      for (final cand in _candidates)
        if ((_src == 'all' || cand.host == _src) && (q.isEmpty || cand.fullName.toLowerCase().contains(q) || cand.meta.toLowerCase().contains(q))) cand,
    ];
    final picked = [for (final cand in _candidates) if (_checked.contains(cand.repo.id)) cand];
    final toClone = picked.where((r) => !r.cloned).length;
    return [
      Wrap(spacing: 10, runSpacing: 10, children: [
        SizedBox(width: 200, child: KField(label: 'Namespace name', controller: _name, hint: 'e.g. catalog')),
        SizedBox(
          width: 330,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Filter detected repositories', style: sans(11, color: p.text3)),
            const SizedBox(height: 4),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: p.chipBorder)),
              child: Row(children: [
                Icon(KIcons.search, size: 15, color: p.text3),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _filter,
                    style: sans(12.5, color: p.text),
                    cursorColor: p.acc,
                    decoration: InputDecoration.collapsed(hintText: 'owner/repo or path', hintStyle: sans(12.5, color: p.text3)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerLeft,
        child: KSegmented<String>(
          label: 'Source',
          value: _src,
          onChanged: (v) => setState(() => _src = v),
          items: [
            for (final (k, label) in const [('all', 'All'), ('GH', 'GitHub'), ('GL', 'GitLab'), ('BB', 'Bitbucket'), ('LO', 'Local')]) (k, label, '${count(k)}'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Container(
        constraints: const BoxConstraints(maxHeight: 340),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: p.pane, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.paneBorder)),
        child: rows.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(18),
                child: Text('No repositories match “${_filter.text}”.', textAlign: TextAlign.center, style: sans(12.5, color: p.text3)),
              )
            : ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [for (final cand in rows) _row(cand, s)]),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: p.tile, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(KIcons.info, size: 15, color: p.text3)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'A repo can live in more than one namespace. Repos that aren’t cloned yet get cloned into ~/dev when you save.',
              style: sans(12, color: p.text2, height: 1.45),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '${picked.length} ', style: sans(12, weight: FontWeight.w600, color: p.text)),
            TextSpan(
              text: '${picked.length == 1 ? 'repository' : 'repositories'} selected${toClone > 0 ? ' · $toClone to clone' : ''}',
              style: sans(12, color: p.text2),
            ),
          ])),
        ),
        KButton(label: 'Cancel', onTap: _close),
        const SizedBox(width: 8),
        KButton.primary(
          label: _isNew ? 'Create namespace' : 'Save namespace',
          onTap: _save,
          trailing: Kbd('⌘↩', color: p.accText, background: const Color(0x33FFFFFF)),
        ),
      ]),
    ];
  }

  Widget _row(RepoCandidate cand, AppState s) {
    final c = context.c;
    final on = _checked.contains(cand.repo.id);
    final tag = _tagFor(cand, s.namespaces);
    return KPressable(
      onTap: () => setState(() => on ? _checked.remove(cand.repo.id) : _checked.add(cand.repo.id)),
      semanticLabel: '${cand.fullName}, ${on ? 'selected' : 'not selected'}',
      selected: on,
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: on ? c.accSoft : (hover || focus ? c.tile : null), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: on ? c.accFill : null,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: on ? c.accFill : c.text3, width: 1.5),
            ),
            child: on ? Icon(KIcons.check, size: 12, color: c.accText) : null,
          ),
          const SizedBox(width: 12),
          SizedBox(width: 26, child: Center(child: TagChip(cand.host))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cand.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(12.5, weight: FontWeight.w500, color: c.text)),
              Text(cand.meta, style: sans(11.5, color: cand.cloned ? c.text3 : c.warn)),
            ]),
          ),
          if (tag != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(9)),
              child: Text(tag, style: sans(11, color: c.text2)),
            ),
        ]),
      ),
    );
  }

  List<Widget> _done() {
    final p = context.c;
    final picked = [for (final cand in _candidates) if (_checked.contains(cand.repo.id)) cand];
    final toClone = picked.where((r) => !r.cloned).length;
    final name = _name.text.trim().isEmpty ? 'untitled' : _name.text.trim();
    final n = picked.length;
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: p.okSoft, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(KIcons.check, size: 16, color: p.ok),
            const SizedBox(width: 8),
            Text(_isNew ? 'Namespace created' : 'Namespace “$name” saved', style: sans(13, weight: FontWeight.w600, color: p.ok)),
          ]),
          const SizedBox(height: 8),
          Text(
            '$n ${n == 1 ? 'repository' : 'repositories'} in the sidebar under “$name”${toClone > 0 ? '. Cloning $toClone in the background.' : '.'}',
            style: sans(12.5, color: p.text2),
          ),
          if (picked.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(picked.map((r) => r.fullName).join('  ·  '), style: mono(11.5, color: p.text2)),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        KButton(label: 'Edit again', onTap: () => setState(() => _saved = false)),
        const SizedBox(width: 8),
        Expanded(child: KButton.primary(label: 'Done', expand: true, onTap: _close)),
      ]),
    ];
  }
}
