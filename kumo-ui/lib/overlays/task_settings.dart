import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/tasks_source.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/kicons.dart';

/// One option of a kind of source, as the form shows it.
class _Field {
  const _Field(this.key, this.label, {this.hint, this.mono = false, this.optional = false});
  final String key;
  final String label;
  final String? hint;
  final bool mono;
  final bool optional;
}

List<_Field> _fields(TaskSourceKind kind) => switch (kind) {
      TaskSourceKind.obsidian => const [_Field('vault', 'Vault folder', hint: '~/Documents/Notes', mono: true)],
      TaskSourceKind.bear => const [_Field('database', 'Database', hint: 'Bear’s usual one', mono: true, optional: true)],
      TaskSourceKind.github => const [_Field('query', 'Issues for Everyone (GitHub search)', hint: 'is:open is:issue involves:@me', mono: true, optional: true)],
      TaskSourceKind.jira => const [
          _Field('site', 'Site', hint: 'https://acme.atlassian.net', mono: true),
          _Field('email', 'Account email', hint: 'you@acme.com'),
          _Field('jql', 'Issues for Everyone (JQL)', hint: 'Your projects’ open sprints and recent activity', mono: true, optional: true),
        ],
      TaskSourceKind.todoist => const [_Field('project', 'Only this project', hint: 'All open tasks', optional: true)],
    };

String _secretHelp(TaskSourceKind kind) => switch (kind) {
      TaskSourceKind.jira => 'Create one at id.atlassian.com › Security › API tokens.',
      TaskSourceKind.todoist => 'Todoist › Settings › Integrations › Developer.',
      _ => '',
    };

String _note(TaskSourceKind kind) => switch (kind) {
      TaskSourceKind.github => 'Signs in through your GitHub CLI: run `gh auth login` once in a terminal.',
      TaskSourceKind.bear => 'macOS may ask to let Kumo read Bear’s data the first time.',
      _ => '',
    };

/// What a source reads, in one line.
String _summary(TaskSourceInfo s) => switch (s.kind) {
      TaskSourceKind.obsidian => s.options['vault'] ?? '',
      TaskSourceKind.bear => s.options['database'] ?? 'Bear’s notes on this Mac',
      TaskSourceKind.github => s.options['query'] ?? '',
      TaskSourceKind.jira => '${s.options['site'] ?? ''} · ${s.options['email'] ?? ''}',
      TaskSourceKind.todoist => (s.options['project'] ?? '').isEmpty ? 'All open tasks' : 'Project “${s.options['project']}”',
    };

/// Settings › Tasks: where tasks come from. Local sources (Obsidian, Bear)
/// and a signed-in `gh` are offered when found; API tokens go to the
/// Keychain.
class TaskSourceSettingsPanel extends StatefulWidget {
  const TaskSourceSettingsPanel({super.key});

  @override
  State<TaskSourceSettingsPanel> createState() => _TaskSourceSettingsPanelState();
}

class _TaskSourceSettingsPanelState extends State<TaskSourceSettingsPanel> {
  String? _open;
  TaskSourceKind? _adding;
  List<DetectedSourceInfo> _detected = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _detect());
  }

  Future<void> _detect() async {
    if (!mounted) return;
    try {
      final found = await AppScope.read(context).tasks.detect();
      if (mounted) setState(() => _detected = found);
    } on Object {
      // Nothing found is fine: sources can be added by hand.
    }
  }

  Future<void> _addDetected(TasksSource tasks, DetectedSourceInfo d) async {
    try {
      await tasks.saveSource(kind: d.kind, name: d.name, options: d.options);
      if (mounted) setState(() => _detected = [for (final x in _detected) if (x != d) x]);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(listenable: s.tasks, builder: (context, _) => _build(context, s.tasks));
  }

  Widget _build(BuildContext context, TasksSource tasks) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final source in tasks.sources) ...[
        const SizedBox(height: 8),
        _SourceCard(
          key: ValueKey(source.id),
          source: source,
          expanded: _open == source.id,
          onToggle: () => setState(() => _open = _open == source.id ? null : source.id),
          onEnable: (enabled) => tasks.saveSource(id: source.id, kind: source.kind, name: source.name, options: source.options, enabled: enabled).ignore(),
          onDelete: () async {
            await tasks.deleteSource(source.id);
            _detect();
          },
        ),
      ],
      if (_detected.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Found on this Mac', style: sans(12, weight: FontWeight.w600, color: c.text2)),
        for (final d in _detected) ...[
          const SizedBox(height: 8),
          _DetectedRow(found: d, onAdd: () => _addDetected(tasks, d)),
        ],
      ],
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: sans(12, color: c.err)),
      ],
      const SizedBox(height: 14),
      if (_adding != null)
        _SourceForm(
          kind: _adding!,
          onCancel: () => setState(() => _adding = null),
          onSaved: () => setState(() => _adding = null),
        )
      else
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Add', style: sans(12.5, color: c.text2)),
          for (final kind in TaskSourceKind.values)
            KButton(label: kind.label, height: 30, fontSize: 12.5, onTap: () => setState(() => _adding = kind)),
        ]),
    ]);
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.kind, {this.active = true});
  final TaskSourceKind kind;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: active ? c.accSoft : c.tile, borderRadius: BorderRadius.circular(10)),
      child: Text(kind.badge, style: mono(11, weight: FontWeight.w700, color: active ? c.acc : c.text3)),
    );
  }
}

class _DetectedRow extends StatelessWidget {
  const _DetectedRow({required this.found, required this.onAdd});
  final DetectedSourceInfo found;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final where = found.options['vault'] ?? found.options['query'] ?? 'Bear’s notes on this Mac';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.paneBorder)),
      child: Row(children: [
        _Badge(found.kind, active: false),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${found.kind.label} · ${found.name}', style: sans(13, weight: FontWeight.w600, color: c.text)),
            Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3)),
          ]),
        ),
        KButton.primary(label: 'Add', height: 30, fontSize: 12.5, onTap: onAdd),
      ]),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({super.key, required this.source, required this.expanded, required this.onToggle, required this.onEnable, required this.onDelete});
  final TaskSourceInfo source;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<bool> onEnable;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final x = source;
    final (status, color) = !x.enabled
        ? ('Paused', c.text3)
        : x.error.isNotEmpty
            ? ('Failing', c.err)
            : x.syncing
                ? ('Syncing', c.acc)
                : ('${x.taskCount} tasks', c.ok);
    return Container(
      decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: expanded ? c.accSoft : c.paneBorder)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            _Badge(x.kind, active: x.enabled),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(x.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13.5, weight: FontWeight.w600, color: c.text)),
                Text(_summary(x), maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, color: c.text3)),
              ]),
            ),
            const SizedBox(width: 10),
            Dot(color),
            const SizedBox(width: 6),
            Text(status, style: sans(12, weight: FontWeight.w500, color: color)),
            const SizedBox(width: 10),
            KSwitch(value: x.enabled, onChanged: onEnable, label: 'Sync ${x.name}'),
            const SizedBox(width: 10),
            KButton(label: expanded ? 'Done' : 'Configure', height: 30, fontSize: 12.5, onTap: onToggle),
          ]),
        ),
        if (x.error.isNotEmpty && x.enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(x.error, maxLines: 3, overflow: TextOverflow.ellipsis, style: sans(12, color: c.err)),
          ),
        if (expanded)
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
            child: _SourceForm(kind: x.kind, source: x, onDelete: onDelete, embedded: true),
          ),
      ]),
    );
  }
}

/// Options, token, test and save for a new source or an existing one.
class _SourceForm extends StatefulWidget {
  const _SourceForm({required this.kind, this.source, this.onCancel, this.onSaved, this.onDelete, this.embedded = false});
  final TaskSourceKind kind;
  final TaskSourceInfo? source;
  final VoidCallback? onCancel;
  final VoidCallback? onSaved;
  final VoidCallback? onDelete;
  final bool embedded;

  @override
  State<_SourceForm> createState() => _SourceFormState();
}

class _SourceFormState extends State<_SourceForm> {
  late final _name = TextEditingController(text: widget.source?.name ?? '');
  late final _options = {
    for (final f in _fields(widget.kind)) f.key: TextEditingController(text: widget.source?.options[f.key] ?? ''),
  };
  final _secret = TextEditingController();
  (bool, String)? _result;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _secret.dispose();
    for (final c in _options.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _values => {for (final e in _options.entries) e.key: e.value.text.trim()};

  bool get _complete =>
      _fields(widget.kind).every((f) => f.optional || _values[f.key]!.isNotEmpty) &&
      (!widget.kind.needsSecret || _secret.text.trim().isNotEmpty || (widget.source?.hasSecret ?? false));

  Future<void> _run(Future<String> Function(TasksSource tasks) action) async {
    final tasks = AppScope.read(context).tasks;
    setState(() {
      _busy = true;
      _result = (true, 'Checking…');
    });
    try {
      final message = await action(tasks);
      if (mounted) setState(() => _result = (true, message));
    } on Object catch (e) {
      if (mounted) setState(() => _result = (false, '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _test() => _run((tasks) => tasks.test(id: widget.source?.id, kind: widget.kind, options: _values, secret: _secret.text.trim()));

  void _save() => _run((tasks) async {
        final saved = await tasks.saveSource(
          id: widget.source?.id,
          kind: widget.kind,
          name: _name.text.trim(),
          options: _values,
          enabled: widget.source?.enabled ?? true,
          secret: _secret.text.trim(),
        );
        _secret.clear();
        widget.onSaved?.call();
        return 'Saved · reading ${saved.name}';
      });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final kind = widget.kind;
    final note = _note(kind);
    final hasSecret = widget.source?.hasSecret ?? false;
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!widget.embedded) ...[
        Row(children: [
          _Badge(kind),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Add ${kind.label}', style: sans(13.5, weight: FontWeight.w600, color: c.text)),
              Text(kind.blurb, style: sans(12, color: c.text3)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
      ],
      KField(label: 'Name', controller: _name, hint: kind.label),
      for (final f in _fields(kind)) ...[
        const SizedBox(height: 10),
        KField(label: f.optional ? '${f.label} (optional)' : f.label, controller: _options[f.key]!, monospace: f.mono, hint: f.hint),
      ],
      if (kind.needsSecret) ...[
        const SizedBox(height: 10),
        _SecretField(controller: _secret, stored: hasSecret),
        const SizedBox(height: 4),
        Text('${_secretHelp(kind)} Kept in the macOS Keychain, never in Kumo’s files.', style: sans(11.5, color: c.text3)),
      ],
      if (note.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(note, style: sans(11.5, color: c.text3)),
      ],
      const SizedBox(height: 12),
      ListenableBuilder(
        listenable: Listenable.merge([_secret, ..._options.values]),
        builder: (context, _) => Row(children: [
          KButton(label: 'Test connection', height: 30, fontSize: 12.5, onTap: _busy || !_complete ? null : _test),
          if (_result != null) ...[
            const SizedBox(width: 10),
            Icon(_result!.$1 ? KIcons.check : KIcons.warning, size: 14, color: _result!.$1 ? c.ok : c.err),
            const SizedBox(width: 6),
            Flexible(child: Text(_result!.$2, maxLines: 3, overflow: TextOverflow.ellipsis, style: sans(12, color: _result!.$1 ? c.ok : c.err))),
          ],
          const Spacer(),
          if (widget.onDelete != null) _DangerLink(label: 'Remove', onTap: widget.onDelete!),
          if (widget.onCancel != null) ...[
            KButton(label: 'Cancel', height: 30, fontSize: 12.5, onTap: widget.onCancel),
            const SizedBox(width: 8),
          ],
          KButton.primary(label: widget.source == null ? 'Add source' : 'Save', height: 30, fontSize: 12.5, onTap: _busy || !_complete ? null : _save),
        ]),
      ),
    ]);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: widget.embedded ? null : BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.accSoft)),
      child: body,
    );
  }
}

class _SecretField extends StatelessWidget {
  const _SecretField({required this.controller, required this.stored});
  final TextEditingController controller;
  final bool stored;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('API token', style: sans(11, color: c.text3)),
      const SizedBox(height: 4),
      Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.chipBorder)),
        child: TextField(
          controller: controller,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          style: mono(12, color: c.text),
          cursorColor: c.acc,
          decoration: InputDecoration.collapsed(hintText: stored ? '•••••••• stored · type to replace' : 'Paste your token'),
        ),
      ),
    ]);
  }
}

class _DangerLink extends StatelessWidget {
  const _DangerLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, hover, focus) => Container(
        height: 30,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: hover || focus ? c.errSoft : null, borderRadius: BorderRadius.circular(15)),
        child: Text(label, style: sans(12.5, weight: FontWeight.w500, color: c.err)),
      ),
    );
  }
}
