part of '../task_detail.dart';

// ---- Header ----

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.view});
  final _TaskDetailState state;
  final _View view;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = state.widget;
    final t = view.task;
    final expanded = w.expanded;
    final type = t?.type ?? TaskType.task;
    final typeName = t == null ? '' : (t.typeName.isNotEmpty ? t.typeName : taskTypeLabel(type));
    final step = w.onStep;
    final url = t?.url ?? '';
    final parent = t?.parent;
    return Padding(
      padding: expanded ? const EdgeInsets.fromLTRB(22, 14, 20, 16) : const EdgeInsets.fromLTRB(18, 12, 12, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (w.canGoBack) ...[
            _ChipButton(
              tooltip: 'Back to the previous ticket',
              onTap: w.onBack,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_back_rounded, size: 14, color: c.text2),
                const SizedBox(width: 4),
                Text('Back', style: sans(12, weight: FontWeight.w500, color: c.text2)),
              ]),
            ),
            const SizedBox(width: 10),
          ],
          if (t != null) ...[
            Tooltip(message: typeName, child: Icon(taskTypeIcon(type), size: 15, color: taskTypeColor(c, type))),
            const SizedBox(width: 6),
            Text(typeName, style: sans(12.5, color: c.text2)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('·', style: sans(12.5, color: c.text3))),
          ],
          Flexible(child: Text(view.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(12.5, weight: FontWeight.w600, color: c.text))),
          const Spacer(),
          KIconButton(icon: Icons.keyboard_arrow_up_rounded, label: 'Previous ticket (↑)', onTap: step == null ? null : () => step(-1), color: step == null ? c.text3 : null),
          KIconButton(icon: Icons.keyboard_arrow_down_rounded, label: 'Next ticket (↓)', onTap: step == null ? null : () => step(1), color: step == null ? c.text3 : null),
          KIconButton(
            icon: expanded ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
            iconSize: 14,
            label: expanded ? 'Back to the side panel (Esc)' : 'Expand to a large view',
            onTap: () => w.onExpand(!expanded),
          ),
          KIconButton(icon: KIcons.external, iconSize: 15, label: 'Open in ${view.kindLabel}', onTap: url.isEmpty ? null : () => openUrl(url), color: url.isEmpty ? c.text3 : null),
          KIconButton(
            icon: state._copied ? KIcons.check : KIcons.copy,
            iconSize: 14,
            label: state._copied ? 'Link copied' : 'Copy link',
            onTap: url.isEmpty ? null : () => state._copy(url),
            color: url.isEmpty ? c.text3 : (state._copied ? c.ok : null),
          ),
          KIconButton(icon: KIcons.close, label: 'Close (Esc)', onTap: w.onClose),
        ]),
        const SizedBox(height: 8),
        if (t == null)
          const _Bar(width: 220, height: 16)
        else
          SelectableText(t.title, style: sans(expanded ? 22 : 18, weight: FontWeight.w600, color: c.text, letterSpacing: -0.3, height: 1.3)),
        if (t != null) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Tooltip(message: 'Status in ${t.kind.label}', child: _StatusPill(column: t.column, text: t.sourceStatus.isNotEmpty ? t.sourceStatus : columnName(t.column), large: true)),
            Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(t.kind.badge, style: mono(10, weight: FontWeight.w700, color: c.tileText, height: 1)),
                const SizedBox(width: 6),
                Text(view.sourceName, style: sans(12, color: c.text2)),
              ]),
            ),
            if (parent != null)
              _RefChip(ref: parent, onTap: () => state._openRef(parent, t), showKey: parent.type != TaskType.epic),
          ]),
        ],
      ]),
    );
  }
}

/// A chip that acts: back, epic/parent.
class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.child, required this.tooltip, this.onTap, this.background, this.label});
  final Widget child;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? background;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      tooltip: tooltip,
      semanticLabel: label ?? tooltip,
      builder: (context, hover, focus) => Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: background == null ? (hover ? c.tabActive : c.tile) : (hover ? Color.alphaBlend(c.tile, background!) : background),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: focus ? c.acc : Colors.transparent, width: 1.5),
        ),
        child: child,
      ),
    );
  }
}

/// An epic (colored dot + title) or a parent (key + title) that opens.
class _RefChip extends StatelessWidget {
  const _RefChip({required this.ref, required this.onTap, this.showKey = false, this.maxWidth = 260});
  final TaskRef ref;
  final VoidCallback onTap;
  final bool showKey;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final epic = ref.type == TaskType.epic;
    final (fg, bg) = epicColors(c, color: ref.color, key: ref.key);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: _ChipButton(
        tooltip: 'Open ${ref.key} · ${ref.title} (back returns here)',
        label: '${epic ? 'Epic' : 'Parent'} ${ref.key} · ${ref.title}',
        onTap: onTap,
        background: epic ? bg : null,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (epic)
            Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(2)))
          else
            Icon(taskTypeIcon(ref.type), size: 13, color: c.text2),
          const SizedBox(width: 6),
          if (showKey) ...[
            Text(ref.key, style: mono(11, weight: FontWeight.w500, color: epic ? fg : c.text2)),
            const SizedBox(width: 6),
          ],
          Flexible(child: Text(ref.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, weight: FontWeight.w500, color: epic ? fg : c.text))),
        ]),
      ),
    );
  }
}

/// The source's status, tinted by the column it maps to (icon + words, so
/// it doesn't rely on color).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.column, required this.text, this.large = false});
  final TaskColumn column;
  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (icon, fg, bg) = switch (column) {
      TaskColumn.todo => (Icons.radio_button_unchecked_rounded, c.text2, c.tile),
      TaskColumn.doing => (Icons.timelapse_rounded, c.acc, c.accSoft),
      TaskColumn.review => (Icons.visibility_outlined, c.warn, c.warnSoft),
      TaskColumn.done => (Icons.check_rounded, c.ok, c.okSoft),
    };
    return Container(
      height: large ? 26 : 20,
      padding: EdgeInsets.symmetric(horizontal: large ? 8 : 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(large ? 8 : 6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: large ? 13 : 11, color: fg),
        SizedBox(width: large ? 5 : 4),
        Text(text, style: sans(large ? 12 : 11, weight: FontWeight.w600, color: fg, height: 1.1)),
      ]),
    );
  }
}

// ---- States ----

/// A gray placeholder line.
class _Bar extends StatelessWidget {
  const _Bar({this.width, this.height = 10, this.radius = 5});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(width: width, height: height, decoration: BoxDecoration(color: context.c.tile, borderRadius: BorderRadius.circular(radius)));
}

/// The skeleton while the source answers (loading.png).
class _Loading extends StatelessWidget {
  const _Loading({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget person() => Expanded(
          child: Row(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: c.tile, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_Bar(width: 56, height: 7), SizedBox(height: 6), _Bar(width: 92)])),
          ]),
        );
    Widget field() => const FractionallySizedBox(
          widthFactor: 0.5,
          child: Padding(
            padding: EdgeInsets.only(right: 16, bottom: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_Bar(width: 48, height: 7), SizedBox(height: 7), _Bar(width: 120)]),
          ),
        );
    return Semantics(
      liveRegion: true,
      label: text,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: c.acc, backgroundColor: c.tile)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: sans(12.5, color: c.text2))),
        ]),
        const SizedBox(height: 22),
        ExcludeSemantics(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [person(), const SizedBox(width: 16), person()]),
            const SizedBox(height: 22),
            Wrap(children: [for (var i = 0; i < 6; i++) field()]),
            const SizedBox(height: 10),
            for (final f in const [1.0, 0.92, 0.97, 0.6, 1.0, 0.85, 0.94, 0.5])
              Padding(padding: const EdgeInsets.only(bottom: 9), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: f, child: const _Bar(height: 8))),
            const SizedBox(height: 12),
            const _Bar(height: 92, radius: 14),
            const SizedBox(height: 16),
            const FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: 0.9, child: _Bar(height: 8)),
            const SizedBox(height: 9),
            const FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: 0.7, child: _Bar(height: 8)),
          ]),
        ),
      ]),
    );
  }
}

/// Nothing to show: the ticket couldn't be read and isn't on the board.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.keyText, required this.error, required this.onRetry});
  final String keyText;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.errSoft, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(KIcons.warning, size: 16, color: c.err),
          const SizedBox(width: 8),
          Expanded(child: Text('Couldn’t open $keyText', style: sans(13, weight: FontWeight.w600, color: c.text))),
        ]),
        const SizedBox(height: 6),
        Text(error, maxLines: 4, overflow: TextOverflow.ellipsis, style: sans(12.5, color: c.text2, height: 1.45)),
        const SizedBox(height: 12),
        KButton(label: 'Retry', icon: KIcons.refresh, height: 30, fontSize: 12, onTap: onRetry),
      ]),
    );
  }
}

/// "Showing what Kumo saved." (offline.png).
class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.view, required this.onRetry});
  final _View view;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fetched = view.detail?.fetched ?? view.source?.lastSynced;
    final reason = view.detail?.staleReason ?? '';
    final body = 'Can’t reach ${view.kindLabel} right now.${fetched == null ? '' : ' Last synced ${relativeTime(fetched)}.'}';
    final extra = view.offBasic ? (view.error ?? '') : reason;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(color: c.warnSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.warn.withAlpha(60))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(KIcons.cloudOff, size: 16, color: c.warn)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(view.offBasic ? 'Showing what Kumo saved.' : 'Showing the copy Kumo saved.', style: sans(12.5, weight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 2),
              Text(body, style: sans(12, color: c.text2, height: 1.45)),
              if (extra.isNotEmpty && extra != body) ...[
                const SizedBox(height: 2),
                Text(extra, maxLines: 3, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3, height: 1.4)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          KButton(label: 'Retry', icon: KIcons.refresh, height: 28, fontSize: 12, onTap: onRetry),
        ]),
      ),
    );
  }
}

/// "Blocked by PRC-11355 · To Do" with a way there.
class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner({required this.blockers, required this.onOpen});
  final List<TaskRef> blockers;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final text = 'Blocked by ${blockers.map((b) => '${b.key} · ${b.sourceStatus.isNotEmpty ? b.sourceStatus : columnName(b.column)}').join(', ')}';
    return KPressable(
      onTap: onOpen,
      tooltip: 'Open the blocking ticket (back returns here)',
      semanticLabel: text,
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: hover ? Color.alphaBlend(c.tile, c.warnSoft) : c.warnSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: focus ? c.acc : Colors.transparent, width: 1.5),
        ),
        child: Row(children: [
          Icon(KIcons.lock, size: 15, color: c.warn),
          const SizedBox(width: 8),
          Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: FontWeight.w600, color: c.warn))),
          Text('Open', style: sans(12, weight: FontWeight.w600, color: c.text2)),
        ]),
      ),
    );
  }
}

/// Offline, never fetched: the rest arrives later.
class _NotSavedYet extends StatelessWidget {
  const _NotSavedYet();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CustomPaint(
      painter: _DashedBorder(c.text3.withAlpha(90), 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Not saved on this Mac yet', style: sans(13, weight: FontWeight.w600, color: c.text)),
          const SizedBox(height: 6),
          Text(
            'The description, acceptance criteria, subtasks, links, attachments and comments arrive the first time this ticket opens online. Starting a worktree still works.',
            style: sans(12.5, color: c.text2, height: 1.5),
          ),
        ]),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color, this.radius);
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.5), Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

// ---- People and fields ----

class _People extends StatelessWidget {
  const _People({required this.people});
  final List<(String, TaskPerson?)> people;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      container: true,
      label: 'People',
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, (role, p)) in people.indexed) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(
            child: Row(children: [
              PersonAvatar(person: p, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(role, style: sans(11.5, color: c.text3)),
                  Row(children: [
                    Flexible(child: Text(p?.name ?? 'Unassigned', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13.5, weight: FontWeight.w500, color: c.text))),
                    if (p?.you ?? false) ...[const SizedBox(width: 6), Text('You', style: sans(11.5, weight: FontWeight.w600, color: c.acc))],
                  ]),
                ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// The ticket's fields, per kind of source (the design's `fields`).
class _Fields extends StatelessWidget {
  const _Fields({required this.view, required this.onOpen});
  final _View view;
  final ValueChanged<TaskRef> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = view.task!;
    final d = view.detail;
    final due = dueInfo(t.due);
    final dueText = due?.long ?? 'None';
    final fields = <(String, Widget)>[];
    Widget text(String v, {String sub = '', Color? color}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(13.5, weight: FontWeight.w500, color: color ?? c.text)),
          if (sub.isNotEmpty) Text(sub, style: sans(11.5, color: c.text3, height: 1.4)),
        ]);
    Widget tags(List<String> items) => items.isEmpty
        ? text('None')
        : Padding(padding: const EdgeInsets.only(top: 2), child: Wrap(spacing: 4, runSpacing: 4, children: [for (final x in items) _Tag(x)]));
    final dueWidget = text(dueText, color: due?.overdue ?? false ? c.err : null);
    switch (t.kind) {
      case TaskSourceKind.jira:
        final sp = t.sprint;
        final parent = t.parent;
        final isSub = t.type == TaskType.subtask;
        fields.addAll([
          ('Priority', text(priorityLongLabel(t.priority))),
          ('Story points', text(t.points > 0 ? _points(t.points) : (isSub || t.type == TaskType.epic ? '—' : 'Not estimated'))),
          ('Sprint', sp == null ? text('None') : text(sp.name, sub: [sprintDates(sp), sprintState(sp)].where((x) => x.isNotEmpty).join(' · '))),
          (
            isSub && parent != null ? 'Parent' : 'Epic',
            parent == null ? text('None') : Align(alignment: Alignment.centerLeft, child: _RefChip(ref: parent, showKey: true, maxWidth: 190, onTap: () => onOpen(parent))),
          ),
          ('Due', dueWidget),
          ('Labels', tags(t.labels)),
          if (!view.offBasic) ...[
            ('Components', tags(d?.components ?? const [])),
            ('Fix version', text(d == null || d.fixVersions.isEmpty ? 'None' : d.fixVersions.join(', '))),
          ],
        ]);
      case TaskSourceKind.github:
        fields.addAll([
          ('Repository', text(t.context.isEmpty ? '—' : t.context)),
          ('State', text(t.sourceStatus.isNotEmpty ? t.sourceStatus : columnName(t.column))),
          ('Labels', tags(t.labels)),
          if (t.due.isNotEmpty) ('Due', dueWidget),
        ]);
      case TaskSourceKind.obsidian:
      case TaskSourceKind.bear:
        final location = d?.location ?? '';
        fields.addAll([
          ('Due', dueWidget),
          ('Note', text(location.isNotEmpty ? location : t.key)),
          if (t.context.isNotEmpty && t.context != t.key) (t.kind == TaskSourceKind.obsidian ? 'Vault' : 'In', text(t.context)),
          ('Status', text(columnName(t.column))),
        ]);
      case TaskSourceKind.todoist:
        fields.addAll([
          ('Priority', text(priorityLongLabel(t.priority))),
          ('Due', dueWidget),
          ('Project', text(t.context.isNotEmpty ? t.context : t.key)),
          ('Labels', tags(t.labels)),
        ]);
    }
    final stamp = view.stamp;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, box) {
        final half = (box.maxWidth - 16) / 2;
        return Wrap(spacing: 16, runSpacing: 14, children: [
          for (final (k, v) in fields)
            SizedBox(
              width: half,
              child: Semantics(
                container: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(k, style: sans(11.5, color: c.text3)),
                  const SizedBox(height: 3),
                  v,
                ]),
              ),
            ),
        ]);
      }),
      if (stamp.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(stamp, style: sans(12, color: c.text3)),
      ],
    ]);
  }

  static String _points(double p) => p == p.roundToDouble() ? p.toInt().toString() : p.toString();
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(5)),
      child: Text(text, style: mono(11, weight: FontWeight.w500, color: c.tileText, height: 1.35)),
    );
  }
}

class _TimeBar extends StatelessWidget {
  const _TimeBar({required this.time});
  final TimeTracking time;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final logged = time.loggedSeconds;
    final total = logged + time.remainingSeconds;
    final frac = total > 0 ? logged / total : (time.estimateSeconds > 0 ? (logged / time.estimateSeconds).clamp(0.0, 1.0) : 0.0);
    final aria = 'Logged ${time.logged.isEmpty ? 'nothing' : time.logged}${time.estimate.isEmpty ? '' : ' of ${time.estimate} estimated'}${time.remaining.isEmpty ? '' : ', ${time.remaining} remaining'}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text('Time tracking', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text3))),
        if (time.estimate.isNotEmpty) Flexible(child: Text('Estimate ${time.estimate}', textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12, color: c.text3))),
      ]),
      const SizedBox(height: 7),
      Semantics(
        label: aria,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: Stack(children: [
              Positioned.fill(child: ColoredBox(color: c.tile)),
              FractionallySizedBox(widthFactor: frac.toDouble(), heightFactor: 1, alignment: Alignment.centerLeft, child: ColoredBox(color: c.accFill)),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 7),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text('Logged ${time.logged.isEmpty ? '0' : time.logged}', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, color: c.text2))),
        if (time.remaining.isNotEmpty) Flexible(child: Text('Remaining ${time.remaining}', textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, color: c.text2))),
      ]),
    ]);
  }
}

// ---- Content ----

/// "SUBTASKS ····· 1 of 4 done".
class _SectionHead extends StatelessWidget {
  const _SectionHead(this.title, {this.count, this.trailing});
  final String title;
  final String? count;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      header: true,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: microLabel(c))),
            if (count != null) ...[const SizedBox(width: 8), Text(count!, style: sans(11.5, weight: FontWeight.w500, color: c.text3))],
          ]),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Flexible(child: Text(trailing!, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3))),
        ],
      ]),
    );
  }
}

class _AcceptanceCriteria extends StatelessWidget {
  const _AcceptanceCriteria({required this.source, required this.style});
  final String source;
  final MdStyle style;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = checklistOf(source);
    final met = items.where((i) => i.$1).length;
    return Semantics(
      container: true,
      label: 'Acceptance criteria',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(c.accSoft.withAlpha(c.accSoft.a * 255 ~/ 2), c.tile),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.accSoft),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(KIcons.sparkle, size: 15, color: c.acc),
            const SizedBox(width: 8),
            Expanded(child: Text('Acceptance criteria', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13.5, weight: FontWeight.w600, color: c.text))),
            if (items.isNotEmpty) Text('$met of ${items.length} met', style: sans(12, color: c.text3)),
          ]),
          const SizedBox(height: 10),
          if (items.isEmpty)
            MarkdownView(source, style: style)
          else
            for (final (i, (done, text)) in items.indexed)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 2), child: CheckMark(done: done)),
                  const SizedBox(width: 9),
                  Expanded(child: MdText(text, style: style, base: sans(13, color: c.text, height: 1.5))),
                ]),
              ),
          const SizedBox(height: 10),
          Text('The agent gets these as its definition of done.', style: sans(11.5, color: c.text3)),
        ]),
      ),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description({required this.heading, required this.source, required this.style, required this.collapsible, required this.open, required this.onToggle});
  final String heading;
  final String source;
  final MdStyle style;
  final bool collapsible;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final empty = source.trim().isEmpty;
    final long = collapsible && source.trim().split('\n').length > 8;
    Widget body = MarkdownView(source, style: style);
    if (long && !open) {
      body = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF000000), Color(0x00000000)], stops: [0.7, 1]).createShader(rect),
          child: ClipRect(child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: body)),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionHead(heading),
      const SizedBox(height: 10),
      if (empty) Text('No description.', style: sans(13, color: c.text3)) else body,
      if (long && !empty) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: KButton(label: open ? 'Show less' : 'Show more', kind: KButtonKind.ghost, height: 28, fontSize: 12, onTap: onToggle),
        ),
      ],
    ]);
  }
}

/// A row that opens a ticket: key, title, status, (avatar).
class _RefRow extends StatelessWidget {
  const _RefRow({required this.ref, required this.onTap, this.avatar = false, this.leading, this.background});
  final TaskRef ref;
  final VoidCallback onTap;
  final bool avatar;
  final Widget? leading;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final status = ref.sourceStatus.isNotEmpty ? ref.sourceStatus : columnName(ref.column);
    return KPressable(
      onTap: onTap,
      tooltip: 'Open ${ref.key} (back returns here)',
      semanticLabel: '${ref.key} ${ref.title}, $status',
      builder: (context, hover, focus) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: hover ? Color.alphaBlend(c.tile, background ?? const Color(0x00000000)) : background,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: focus ? c.acc : Colors.transparent, width: 1.5),
        ),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Text(ref.key, style: mono(11.5, color: c.text2)),
          const SizedBox(width: 8),
          Expanded(child: Text(ref.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13, color: c.text))),
          const SizedBox(width: 8),
          _StatusPill(column: ref.column, text: status),
          if (avatar) ...[const SizedBox(width: 8), PersonAvatar(person: ref.assignee, size: 20)],
        ]),
      ),
    );
  }
}

class _Subtasks extends StatelessWidget {
  const _Subtasks({required this.epic, required this.subtasks, required this.onOpen});
  final bool epic;
  final List<TaskRef> subtasks;
  final ValueChanged<TaskRef> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final n = subtasks.length;
    final done = subtasks.where((s) => s.column == TaskColumn.done).length;
    final doing = subtasks.where((s) => s.column == TaskColumn.doing || s.column == TaskColumn.review).length;
    final progress = '$done of $n done${doing > 0 ? ' · $doing in progress' : ''}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionHead(epic ? 'Child issues' : 'Subtasks', trailing: progress),
      const SizedBox(height: 9),
      Semantics(
        label: progress,
        child: SizedBox(
          height: 4,
          child: Row(children: [
            if (done > 0) Expanded(flex: done, child: Container(decoration: BoxDecoration(color: c.ok, borderRadius: BorderRadius.circular(2)))),
            if (done > 0 && doing > 0) const SizedBox(width: 2),
            if (doing > 0) Expanded(flex: doing, child: Container(decoration: BoxDecoration(color: c.acc, borderRadius: BorderRadius.circular(2)))),
            if (n - done - doing > 0) ...[
              if (done + doing > 0) const SizedBox(width: 2),
              Expanded(flex: n - done - doing, child: Container(decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(2)))),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 8),
      for (final s in subtasks) _RefRow(ref: s, avatar: true, onTap: () => onOpen(s)),
    ]);
  }
}

class _Links extends StatelessWidget {
  const _Links({required this.links, required this.onOpen});
  final List<LinkedTask> links;
  final ValueChanged<TaskRef> onOpen;

  static String _group(LinkKind k) => switch (k) {
        LinkKind.blockedBy => 'Is blocked by',
        LinkKind.blocks => 'Blocks',
        LinkKind.relates => 'Relates to',
        LinkKind.duplicates => 'Duplicates',
        LinkKind.duplicatedBy => 'Is duplicated by',
        LinkKind.other => '',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Known relations in the design's order, then the source's own wording.
    final groups = <String, List<LinkedTask>>{};
    for (final k in const [LinkKind.blockedBy, LinkKind.blocks, LinkKind.relates, LinkKind.duplicates, LinkKind.duplicatedBy]) {
      final items = links.where((l) => l.kind == k).toList();
      if (items.isNotEmpty) groups[_group(k)] = items;
    }
    for (final l in links.where((l) => l.kind == LinkKind.other)) {
      final r = l.relation.isEmpty ? 'Linked' : l.relation[0].toUpperCase() + l.relation.substring(1);
      (groups[r] ??= []).add(l);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _SectionHead('Linked issues'),
      for (final MapEntry(key: rel, value: items) in groups.entries) ...[
        const SizedBox(height: 10),
        Text(rel, style: sans(12, weight: FontWeight.w500, color: c.text2)),
        const SizedBox(height: 5),
        for (final l in items) ...[
          Builder(builder: (context) {
            final blocking = l.kind == LinkKind.blockedBy && l.task.column != TaskColumn.done;
            final resolved = l.kind == LinkKind.blockedBy && !blocking;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _RefRow(
                ref: l.task,
                onTap: () => onOpen(l.task),
                background: blocking ? c.warnSoft : c.codeBg,
                leading: blocking ? Icon(KIcons.lock, size: 14, color: c.warn) : (resolved ? Icon(KIcons.check, size: 14, color: c.ok) : null),
              ),
              if (blocking || resolved)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 5, 8, 0),
                  child: Text(
                    blocking ? 'Blocking this ticket' : 'Done, so it no longer blocks this one',
                    style: sans(11.5, weight: blocking ? FontWeight.w600 : FontWeight.w400, color: blocking ? c.warn : c.text3),
                  ),
                ),
              const SizedBox(height: 5),
            ]);
          }),
        ],
      ],
    ]);
  }
}

String _size(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1024 * 1024);
  return '${mb >= 10 ? mb.round() : mb.toStringAsFixed(1)} MB';
}

class _Attachments extends StatelessWidget {
  const _Attachments({required this.attachments, required this.kindLabel, required this.fallbackUrl});
  final List<TaskAttachment> attachments;
  final String kindLabel;
  final String fallbackUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionHead('Attachments', count: '${attachments.length}'),
      const SizedBox(height: 10),
      for (final a in attachments) ...[
        Builder(builder: (context) {
          final image = a.kind.toLowerCase().contains('image');
          final url = a.url.isNotEmpty ? a.url : fallbackUrl;
          final meta = [a.kind, _size(a.sizeBytes)].where((x) => x.isNotEmpty).join(' · ');
          return Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(8)),
                child: Icon(image ? Icons.image_outlined : Icons.insert_drive_file_outlined, size: 16, color: c.text2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13, weight: FontWeight.w500, color: c.text)),
                  if (meta.isNotEmpty) Text(meta, style: sans(11.5, color: c.text3)),
                ]),
              ),
              KIconButton(icon: KIcons.external, iconSize: 15, label: 'Open ${a.name} in $kindLabel', onTap: url.isEmpty ? null : () => openUrl(url)),
            ]),
          );
        }),
        const SizedBox(height: 6),
      ],
    ]);
  }
}

class _Comments extends StatelessWidget {
  const _Comments({required this.comments, required this.all, required this.onToggle, required this.style, required this.kindLabel, required this.url});
  final List<TaskComment> comments;
  final bool all;
  final VoidCallback onToggle;
  final MdStyle style;
  final String kindLabel;
  final String url;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final n = comments.length;
    final more = n > 3;
    final visible = all || !more ? comments : comments.sublist(n - 3);
    final note = all || n <= 3 ? (n > 0 ? 'All $n, oldest first' : '') : 'Latest 3 of $n';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionHead('Comments', count: '$n', trailing: note),
      const SizedBox(height: 10),
      if (more) ...[
        KPressable(
          onTap: onToggle,
          semanticLabel: all ? 'Show the latest 3' : 'Show all $n comments',
          builder: (context, hover, focus) => CustomPaint(
            painter: _DashedBorder(focus ? c.acc : c.text3.withAlpha(80), 9),
            child: Container(
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: hover ? c.tile : null, borderRadius: BorderRadius.circular(9)),
              child: Text(all ? 'Show the latest 3' : 'Show all $n comments', style: sans(12, weight: FontWeight.w500, color: c.text2)),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (n == 0) Text('No comments yet.', style: sans(13, color: c.text3)),
      for (final cm in visible)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PersonAvatar(person: cm.author, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Flexible(child: Text(cm.author.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: FontWeight.w600, color: c.text))),
                  if (cm.author.you) ...[const SizedBox(width: 6), Text('You', style: sans(11, weight: FontWeight.w600, color: c.acc))],
                  if (cm.created != null) ...[const SizedBox(width: 7), Text(relativeTime(cm.created!), style: sans(12, color: c.text3))],
                ]),
                const SizedBox(height: 3),
                MarkdownView(cm.body, style: style),
              ]),
            ),
          ]),
        ),
      // Room for "Add a comment" later.
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 14, color: c.text3),
          const SizedBox(width: 8),
          Expanded(child: Text('Add a comment · coming soon. Reply in $kindLabel for now.', style: sans(12, color: c.text3))),
          if (url.isNotEmpty) KButton(label: 'Open in $kindLabel', kind: KButtonKind.ghost, height: 26, fontSize: 12, onTap: () => openUrl(url)),
        ]),
      ),
    ]);
  }
}
