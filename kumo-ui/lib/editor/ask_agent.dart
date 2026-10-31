import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/agents_source.dart';
import '../data/models.dart' show AgentStatus;
import '../overlays/new_agent_dialog.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';
import 'code_editor.dart';

/// Lines [from]–[to] (1-based) of [text] that [selection] covers, or null
/// when nothing is selected. A selection ending at a line's start doesn't
/// take that line.
(int, int)? selectedLines(String text, TextSelection selection) {
  if (!selection.isValid || selection.isCollapsed) return null;
  final start = selection.start.clamp(0, text.length);
  var end = selection.end.clamp(0, text.length);
  if (end > start && text[end - 1] == '\n') end--;
  int lineAt(int offset) => '\n'.allMatches(text.substring(0, offset)).length + 1;
  return (lineAt(start), lineAt(math.max(start, end)));
}

/// What the agent is told: where (repo, worktree, branch, file, lines),
/// the code's first line to anchor it, and the note. One paragraph, so it
/// types into an agent's terminal as one message.
String askAgentMessage({
  required String repo,
  required String worktree,
  required String branch,
  required String path,
  required (int, int) lines,
  required String firstLine,
  required String note,
  bool unsaved = false,
}) {
  final range = lines.$1 == lines.$2 ? 'line ${lines.$1}' : 'lines ${lines.$1}–${lines.$2}';
  final anchor = firstLine.trim().isEmpty ? '' : ' (starts with `${firstLine.trim().length > 80 ? '${firstLine.trim().substring(0, 79)}…' : firstLine.trim()}`)';
  final where = [if (repo.isNotEmpty) 'In $repo', if (worktree.isNotEmpty) 'worktree $worktree', if (branch.isNotEmpty) 'branch $branch'].join(', ');
  final drift = unsaved ? ' The file has unsaved edits in Kumo, so the file on disk may differ.' : '';
  return '${where.isEmpty ? '' : '$where: '}look at $path, $range$anchor. ${note.trim()}$drift';
}

/// Over the code editor: with code selected, an "Ask agent ⌘L" pill under
/// the selection; it opens a popup to write what to do and pick the agent,
/// shows the exact message, sends it, and keeps it on screen afterwards.
class AskAgentLayer extends StatefulWidget {
  const AskAgentLayer({super.key, required this.path, required this.controller, required this.scroll, required this.open, required this.fontSize, this.unsaved = false, this.onClosed});

  /// After the popup closes (to give the code its focus back).
  final VoidCallback? onClosed;

  final String path;
  final TextEditingController controller;
  final ScrollController scroll;

  /// The popup is open (⌘L opens it from outside).
  final ValueNotifier<bool> open;
  final double fontSize;
  final bool unsaved;

  @override
  State<AskAgentLayer> createState() => _AskAgentLayerState();
}

class _AskAgentLayerState extends State<AskAgentLayer> {
  static const _width = 400.0;
  final _note = TextEditingController();
  final _noteFocus = FocusNode();

  /// The running agent picked, or null for a new one.
  String? _target;
  bool _pickedTarget = false;
  bool _preview = false;
  bool _sending = false;
  String? _sentTo;
  String? _sentMessage;
  String? _error;

  /// The lines the popup is about (kept once open, even if the selection moves).
  (int, int)? _lines;

  @override
  void initState() {
    super.initState();
    widget.open.addListener(_onOpen);
    _note.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(AskAgentLayer old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open) {
      old.open.removeListener(_onOpen);
      widget.open.addListener(_onOpen);
    }
  }

  @override
  void dispose() {
    widget.open.removeListener(_onOpen);
    // The flag outlives this layer: closed, so the next one can open.
    if (widget.open.value) widget.open.value = false;
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _onOpen() {
    if (!mounted) return;
    if (widget.open.value) {
      final lines = selectedLines(widget.controller.text, widget.controller.selection);
      if (lines == null) {
        widget.open.value = false;
        return;
      }
      setState(() {
        _lines = lines;
        _sentTo = null;
        _sentMessage = null;
        _error = null;
        // Each time: the agent running here, unless you pick another.
        _pickedTarget = false;
        _target = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _noteFocus.requestFocus();
      });
    } else {
      setState(() {
        _lines = null;
        _sentTo = null;
        _sentMessage = null;
        _error = null;
        _preview = false;
        _note.clear();
      });
      widget.onClosed?.call();
    }
  }

  /// The pill: opens the popup (again, if a closed one left the flag set).
  void _openPopup() {
    if (widget.open.value) {
      _onOpen();
    } else {
      widget.open.value = true;
    }
  }

  void _close() => widget.open.value = false;

  String _message(AppState s, (int, int) lines) {
    final text = widget.controller.text.split('\n');
    final entry = s.activeWorktreeEntry;
    return askAgentMessage(
      repo: s.activeRepo?.name ?? '',
      worktree: entry == null ? '' : s.workspace.absolutePathOf(entry),
      branch: s.changes.branch,
      path: widget.path,
      lines: lines,
      firstLine: lines.$1 - 1 < text.length ? text[lines.$1 - 1] : '',
      note: _note.text,
      unsaved: widget.unsaved,
    );
  }

  Future<void> _send(AppState s, List<AgentRun> running) async {
    final lines = _lines;
    if (lines == null || _note.text.trim().isEmpty || _sending) return;
    final message = _message(s, lines);
    final name = widget.path.split('/').last;
    final item = AgentContextItem(
      kind: AgentContextKind.code,
      title: '$name · ${lines.$1 == lines.$2 ? 'line ${lines.$1}' : 'lines ${lines.$1}–${lines.$2}'}',
      detail: [s.activeRepo?.name ?? '', s.changes.branch].where((p) => p.isNotEmpty).join(' · '),
    );
    final agent = running.where((r) => r.id == _target).firstOrNull;
    if (agent == null) {
      // A new agent: the dialog starts with this message as its prompt. The
      // popup stays (with your note) unless an agent did start.
      final before = s.worktreeAgents.length;
      await showNewAgentDialog(context, prompt: message, about: [item]);
      if (mounted && s.worktreeAgents.length > before) _close();
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final ok = await s.agents.addContext(agent.id, item, text: message);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _sentTo = agent.providerName;
        _sentMessage = message;
      } else {
        _error = s.agents.error ?? 'The message didn’t reach ${agent.providerName}.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, widget.scroll, widget.open]),
      builder: (context, _) {
        final open = widget.open.value && _lines != null;
        final lines = open ? _lines : selectedLines(widget.controller.text, widget.controller.selection);
        if (lines == null) return const SizedBox.shrink();
        return LayoutBuilder(builder: (context, box) {
          final lh = CodeEditor.lineExtentFor(widget.fontSize);
          final offset = widget.scroll.hasClients ? widget.scroll.offset : 0.0;
          final below = CodeEditor.topPadding + lines.$2 * lh - offset + 4;
          final above = CodeEditor.topPadding + (lines.$1 - 1) * lh - offset - 8;
          if (!open) {
            // At the right edge, under the selection, off the code; it stays
            // inside the editor even when the selection scrolls away.
            final top = below.clamp(6.0, math.max(6.0, box.maxHeight - 36)).toDouble();
            return Stack(children: [
              Positioned(top: top, right: 22, child: _Pill(onTap: _openPopup)),
            ]);
          }
          // As wide as fits; below the selection, else above it, else as
          // tall as the editor allows (the middle scrolls).
          final width = math.min(_width, box.maxWidth - 16);
          final left = (box.maxWidth - width - 16).clamp(8.0, 120.0);
          final maxH = math.max(160.0, box.maxHeight - 12);
          const wanted = 420.0;
          final double top = below + wanted < box.maxHeight
              ? below
              : (above - wanted > 6 ? above - wanted : 6.0);
          return Stack(children: [
            Positioned(
              top: top,
              left: left,
              width: width,
              child: ConstrainedBox(constraints: BoxConstraints(maxHeight: maxH), child: _popup(context, s, lines, width)),
            ),
          ]);
        });
      },
    );
  }

  Widget _popup(BuildContext context, AppState s, (int, int) lines, double width) {
    final c = context.c;
    final running = [for (final r in s.worktreeAgents) if (r.status != AgentStatus.done) r];
    if (!_pickedTarget) _target = running.firstOrNull?.id;
    final range = lines.$1 == lines.$2 ? 'line ${lines.$1}' : 'lines ${lines.$1}–${lines.$2}';
    final canSend = _note.text.trim().isNotEmpty && !_sending;
    final agentName = running.where((r) => r.id == _target).firstOrNull?.providerName;
    final message = _sentMessage ?? _message(s, lines);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () => _send(s, running),
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () => _send(s, running),
      },
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        label: 'Ask an agent about $range',
        child: GlassOverlay(
          width: width,
          radius: 16,
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(KIcons.sparkle, size: 15, color: c.acc),
              const SizedBox(width: 8),
              Expanded(child: Text('Ask an agent about $range', style: sans(12.5, weight: FontWeight.w600, color: c.text))),
              KIconButton(icon: KIcons.close, label: 'Close (Esc)', size: 24, iconSize: 12, onTap: _close),
            ]),
            const SizedBox(height: 8),
            Tooltip(
              message: 'What the agent gets with your note',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${widget.path}:${lines.$1 == lines.$2 ? lines.$1 : '${lines.$1}-${lines.$2}'}', style: mono(11.5, color: c.text)),
                  Text([s.activeRepo?.name ?? '', s.changes.branch].where((p) => p.isNotEmpty).join(' · '), style: sans(11, color: c.text3)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            if (_sentTo == null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(11), border: Border.all(color: c.chipBorder)),
                child: TextField(
                  key: const ValueKey('ask-note'),
                  controller: _note,
                  focusNode: _noteFocus,
                  minLines: 3,
                  maxLines: 6,
                  style: sans(12.5, color: c.text, height: 1.45),
                  cursorColor: c.acc,
                  decoration: InputDecoration.collapsed(hintText: 'What should the agent do with this? (⌘↩ sends)', hintStyle: sans(12.5, color: c.text3, height: 1.45)),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final (label, said) in const [
                  ('Explain', 'Explain what this does and why.'),
                  ('Find bugs', 'Look for bugs or edge cases here.'),
                  ('Refactor', 'Refactor this to be simpler, with the same behaviour.'),
                  ('Write a test', 'Write a table test that covers this.'),
                ])
                  KButton(
                    label: label,
                    kind: KButtonKind.ghost,
                    height: 24,
                    fontSize: 11.5,
                    onTap: () {
                      _note.text = said;
                      _note.selection = TextSelection.collapsed(offset: said.length);
                      _noteFocus.requestFocus();
                    },
                  ),
              ]),
              const SizedBox(height: 10),
              Text('Send to', style: sans(11, color: c.text3)),
              const SizedBox(height: 4),
              Row(children: [
                for (final r in running.take(2)) ...[
                  Expanded(child: _Target(name: r.providerName, note: r.title.isEmpty ? 'running here' : r.title, selected: _target == r.id, onTap: () => setState(() {
                    _target = r.id;
                    _pickedTarget = true;
                  }))),
                  const SizedBox(width: 4),
                ],
                Expanded(child: _Target(name: 'New agent', note: 'starts in this worktree', selected: _target == null, onTap: () => setState(() {
                  _target = null;
                  _pickedTarget = true;
                }))),
              ]),
              const SizedBox(height: 8),
            ] else
              Container(
                padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                decoration: BoxDecoration(color: c.okSoft, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(KIcons.check, size: 14, color: c.ok),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Sent to $_sentTo', style: sans(12, color: c.text))),
                  KButton(
                    label: 'Open terminal',
                    kind: KButtonKind.ghost,
                    height: 26,
                    fontSize: 12,
                    onTap: () {
                      _close();
                      s.showTerminals();
                    },
                  ),
                ]),
              ),
            KPressable(
              onTap: () => setState(() => _preview = !_preview),
              semanticLabel: _sentTo != null ? 'Message sent' : 'Message the agent gets',
              selected: _preview || _sentTo != null,
              builder: (context, hover, focus) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(_preview || _sentTo != null ? KIcons.chevronDown : KIcons.chevronRight, size: 14, color: hover ? c.text : c.text2),
                  const SizedBox(width: 4),
                  Text(_sentTo != null ? 'Message sent' : 'Message the agent gets', style: sans(11.5, color: hover ? c.text : c.text2)),
                ]),
              ),
            ),
            if (_preview || _sentTo != null)
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10)),
                child: SingleChildScrollView(child: SelectableText(message, style: mono(11, color: c.text2, height: 1.5))),
              ),
            if (_error case final error?) ...[
              const SizedBox(height: 6),
              Text(error, style: sans(11.5, color: c.err, height: 1.35)),
            ],
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (_sentTo == null) ...[
                KButton(label: 'Cancel', kind: KButtonKind.ghost, height: 30, fontSize: 12.5, onTap: _close),
                const SizedBox(width: 6),
                // A long agent name ellipsizes in a narrow editor.
                Flexible(
                  child: KButton.primary(
                    label: _sending ? 'Sending…' : (agentName == null ? 'Start agent ⌘↩' : 'Send to $agentName ⌘↩'),
                    height: 30,
                    fontSize: 12.5,
                    onTap: canSend ? () => _send(s, running) : null,
                  ),
                ),
              ] else
                KButton(label: 'Done', height: 30, fontSize: 12.5, onTap: _close),
            ]),
          ])),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      semanticLabel: 'Ask an agent about the selection',
      tooltip: 'Ask an agent about the selection (⌘L)',
      builder: (context, hover, focus) => Container(
        height: 28,
        padding: const EdgeInsets.only(left: 8, right: 10),
        decoration: chipDecoration(c, radius: 14, fill: hover || focus ? c.tabActive : null),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(KIcons.sparkle, size: 13, color: c.acc),
          const SizedBox(width: 6),
          Text('Ask agent', style: sans(12, weight: FontWeight.w600, color: c.text)),
          const SizedBox(width: 6),
          Text('⌘L', style: sans(11.5, color: c.text3)),
        ]),
      ),
    );
  }
}

class _Target extends StatelessWidget {
  const _Target({required this.name, required this.note, required this.selected, required this.onTap});
  final String name;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '$name, $note',
      tooltip: '$name · $note',
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.accSoft : (hover || focus ? c.tile : null),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? c.acc : c.chipBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, weight: FontWeight.w600, color: c.text)),
          Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(10.5, color: c.text3)),
        ]),
      ),
    );
  }
}
