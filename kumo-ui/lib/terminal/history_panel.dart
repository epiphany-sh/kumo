import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';
import 'command_history.dart';

/// The commands remembered for the repository [source]'s shell is in: type
/// to find one, Enter puts it at the prompt, ⌘Enter (Ctrl+Enter) runs it.
/// [atPrompt] says whether the shell waits for a command now; while one
/// runs, nothing is typed into it.
Future<void> showHistoryPanel(BuildContext context, CommandHistorySource source, {required bool Function() atPrompt}) {
  final c = context.c;
  unawaited(source.refreshHistory());
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
        padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
        child: Material(type: MaterialType.transparency, child: HistoryPanel(source: source, atPrompt: atPrompt)),
      ),
    ),
  );
}

/// Commands that contain every word of [query], in their order (last run
/// first).
List<HistoryItem> filterHistory(List<HistoryItem> items, String query) {
  final words = query.toLowerCase().split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return items;
  return [
    for (final item in items)
      if (words.every(item.command.toLowerCase().contains)) item,
  ];
}

/// "2m", "3h", "5d": how long ago, short.
String ago(DateTime when, DateTime now) {
  final d = now.difference(when);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  if (d.inDays < 60) return '${d.inDays}d';
  return '${d.inDays ~/ 30}mo';
}

class HistoryPanel extends StatefulWidget {
  const HistoryPanel({super.key, required this.source, required this.atPrompt});

  final CommandHistorySource source;
  final bool Function() atPrompt;

  @override
  State<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends State<HistoryPanel> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  int _picked = 0;
  String? _note;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() => _picked = 0));
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  void _use(HistoryItem item, {required bool run}) {
    if (!widget.atPrompt()) {
      setState(() => _note = 'A command is running: wait for the prompt.');
      return;
    }
    widget.source.insertCommand(item.command, run: run);
    _close();
  }

  Future<void> _forget() async {
    final forgotten = await widget.source.forgetHistory();
    if (mounted) setState(() => _note = 'Forgot $forgotten ${forgotten == 1 ? 'command' : 'commands'}.');
  }

  void _move(int by, int count) {
    if (count == 0) return;
    setState(() => _picked = (_picked + by).clamp(0, count - 1));
    const row = 34.0;
    final target = _picked * row;
    if (_scroll.hasClients) {
      final view = _scroll.position.viewportDimension;
      if (target < _scroll.offset) _scroll.jumpTo(target);
      if (target + row > _scroll.offset + view) _scroll.jumpTo(target + row - view);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ValueListenableBuilder<CommandHistory>(
      valueListenable: widget.source.history,
      builder: (context, history, _) {
        final items = filterHistory(history.items, _query.text);
        final picked = items.isEmpty ? null : items[_picked.clamp(0, items.length - 1)];
        final where = history.repo.isEmpty ? 'Commands run outside a repository' : 'Commands run in ${history.repo.split('/').last}';
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): _close,
            const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1, items.length),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1, items.length),
            const SingleActivator(LogicalKeyboardKey.enter): () {
              if (picked != null) _use(picked, run: false);
            },
            const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
              if (picked != null) _use(picked, run: true);
            },
            const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
              if (picked != null) _use(picked, run: true);
            },
          },
          child: FocusScope(
            autofocus: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: GlassOverlay(
                radius: 20,
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Icon(KIcons.clock, size: 17, color: c.acc),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Command history', style: sans(14, weight: FontWeight.w600, color: c.text)),
                        Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3)),
                      ]),
                    ),
                    KIconButton(icon: KIcons.close, label: 'Close', size: 28, iconSize: 15, onTap: _close),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.chipBorder)),
                    child: Row(children: [
                      Icon(KIcons.search, size: 15, color: c.text3),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _query,
                          autofocus: true,
                          style: mono(12.5, color: c.text),
                          cursorColor: c.acc,
                          decoration: InputDecoration.collapsed(hintText: 'Find a command', hintStyle: sans(12.5, color: c.text3)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 360),
                    decoration: BoxDecoration(color: c.pane, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.paneBorder)),
                    child: items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              history.items.isEmpty ? 'Nothing yet: the commands you run here show up.' : 'No command has “${_query.text}”.',
                              textAlign: TextAlign.center,
                              style: sans(12.5, color: c.text3),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(4),
                            itemCount: items.length,
                            itemExtent: 34,
                            itemBuilder: (context, i) => _row(items[i], i == _picked.clamp(0, items.length - 1)),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: Text(
                        _note ?? '↵ puts it at the prompt · ${_mac ? '⌘' : 'Ctrl+'}↵ runs it',
                        style: sans(11.5, color: c.text3),
                      ),
                    ),
                    KButton(label: 'Forget these', icon: KIcons.trash, kind: KButtonKind.ghost, height: 30, fontSize: 12, onTap: history.items.isEmpty ? null : _forget),
                  ]),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  static bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

  Widget _row(HistoryItem item, bool picked) {
    final c = context.c;
    final lastRun = item.lastRun;
    final meta = [
      if (item.runs > 1) '×${item.runs}',
      if (lastRun != null) ago(lastRun, DateTime.now()),
    ].join(' · ');
    return KPressable(
      onTap: () => _use(item, run: false),
      semanticLabel: item.command,
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: picked ? c.accSoft : (hover ? c.tile : null), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: item.failed ? c.err : (item.lastExit == null ? c.text3 : c.ok)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item.command.replaceAll('\n', ' ⏎ '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(12.5, color: c.text)),
          ),
          if (meta.isNotEmpty) ...[const SizedBox(width: 10), Text(meta, style: sans(11, color: c.text3))],
        ]),
      ),
    );
  }
}
