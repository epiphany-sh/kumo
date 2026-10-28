import 'package:flutter/material.dart';

import '../data/tasks_source.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';

/// Visual vocabulary the Tasks board and the ticket detail share, from the
/// approved design (docs/design/tasks): type icons and colors, priority,
/// epic colors, avatars and how dates read.

// ---- Types ----

IconData taskTypeIcon(TaskType t) => switch (t) {
      TaskType.story => Icons.bookmark_border_rounded,
      TaskType.bug => Icons.bug_report_outlined,
      TaskType.task => Icons.check_box_outlined,
      TaskType.subtask => Icons.subdirectory_arrow_right_rounded,
      TaskType.epic => Icons.bolt_rounded,
      TaskType.issue => Icons.adjust_rounded,
      TaskType.todo => Icons.radio_button_unchecked_rounded,
    };

String taskTypeLabel(TaskType t) => switch (t) {
      TaskType.story => 'Story',
      TaskType.bug => 'Bug',
      TaskType.task => 'Task',
      TaskType.subtask => 'Sub-task',
      TaskType.epic => 'Epic',
      TaskType.issue => 'Issue',
      TaskType.todo => 'Task',
    };

Color taskTypeColor(KumoPalette c, TaskType t) {
  final dark = c.isDark;
  return switch (t) {
    TaskType.story || TaskType.issue => dark ? const Color(0xFF5EE09A) : const Color(0xFF137A43),
    TaskType.bug => dark ? const Color(0xFFFF8A8A) : const Color(0xFFB42318),
    TaskType.task || TaskType.subtask => dark ? const Color(0xFF97A6FF) : const Color(0xFF3A4FD8),
    TaskType.epic => dark ? const Color(0xFFC3A8FF) : const Color(0xFF6B3FD1),
    TaskType.todo => c.text3,
  };
}

// ---- Priority ----

/// Null for no priority.
IconData? priorityIcon(TaskPriority p) => switch (p) {
      TaskPriority.urgent => Icons.keyboard_double_arrow_up_rounded,
      TaskPriority.high => Icons.keyboard_arrow_up_rounded,
      TaskPriority.medium => Icons.drag_handle_rounded,
      TaskPriority.low => Icons.keyboard_arrow_down_rounded,
      TaskPriority.none => null,
    };

/// "Medium" where there's room (the detail); the card says "Med".
String priorityLongLabel(TaskPriority p) => switch (p) {
      TaskPriority.urgent => 'Urgent',
      TaskPriority.high => 'High',
      TaskPriority.medium => 'Medium',
      TaskPriority.low => 'Low',
      TaskPriority.none => 'None',
    };

Color priorityColor(KumoPalette c, TaskPriority p) => switch (p) {
      TaskPriority.urgent => c.err,
      TaskPriority.high => c.warn,
      _ => c.text2,
    };

// ---- Epics ----

const _epicPalette = ['violet', 'teal', 'amber'];

/// (text, background) of an epic or parent chip: its color name, or one
/// picked from its key so the same epic always looks the same.
(Color, Color) epicColors(KumoPalette c, {String color = '', String key = ''}) {
  final name = _epicPalette.contains(color) ? color : _epicPalette[key.codeUnits.fold<int>(0, (h, u) => (h * 31 + u) & 0x7fffffff) % _epicPalette.length];
  final dark = c.isDark;
  return switch (name) {
    'teal' => dark ? (const Color(0xFF6FDCD8), const Color(0x216FDCD8)) : (const Color(0xFF0E7C7B), const Color(0x1A0E7C7B)),
    'amber' => dark ? (const Color(0xFFFFC46B), const Color(0x21FFC46B)) : (const Color(0xFF9A5B00), const Color(0x1A9A5B00)),
    _ => dark ? (const Color(0xFFC3A8FF), const Color(0x26B79CFF)) : (const Color(0xFF6B3FD1), const Color(0x1A6B3FD1)),
  };
}

// ---- People ----

const _avatarTints = [
  (Color(0x42E58AC8), Color(0x2EC44896)),
  (Color(0x3D5ED3D0), Color(0x2E0E7C7B)),
  (Color(0x3DFFC46B), Color(0x33AA6E00)),
  (Color(0x385EE09A), Color(0x2B137A43)),
  (Color(0x3D96AADC), Color(0x2E465A96)),
];

/// A person's initials in a circle: the user in the accent color, teammates
/// tinted by who they are, nobody as a dashed circle ("Unassigned"). The
/// name shows on hover.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.person, this.size = 20});
  final TaskPerson? person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = person;
    final style = sans(size * 0.42, weight: FontWeight.w600, color: p == null ? c.text3 : (p.you ? c.acc : c.text), height: 1);
    if (p == null) {
      return Tooltip(
        message: 'Unassigned',
        child: CustomPaint(
          painter: _DashedCircle(c.text3),
          child: SizedBox(width: size, height: size, child: Icon(Icons.person_outline_rounded, size: size * 0.62, color: c.text3)),
        ),
      );
    }
    final tint = _avatarTints[p.id.codeUnits.fold<int>(0, (h, u) => (h * 31 + u) & 0x7fffffff) % _avatarTints.length];
    return Tooltip(
      message: p.you ? '${p.name} (you)' : p.name,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.you ? c.accSoft : (c.isDark ? tint.$1 : tint.$2),
          border: Border.all(color: p.you ? c.acc : Colors.transparent),
        ),
        child: Text(p.initials.isEmpty ? initialsOf(p.name) : p.initials, style: style),
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  _DashedCircle(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Offset.zero & size;
    const dashes = 12;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect.deflate(0.5), i * 2 * 3.14159 / dashes, 3.14159 / dashes, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.color != color;
}

/// "Ana Gómez" → "AG"; "Tomás" → "T".
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '';
  if (words.length == 1) return words.first.characters.first.toUpperCase();
  return (words.first.characters.first + words.last.characters.first).toUpperCase();
}

// ---- Dates ----

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Oct 31".
String shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// How a due date reads (the design's `fmtDue`).
@immutable
class DueInfo {
  const DueInfo({required this.text, required this.long, required this.label, this.overdue = false, this.soon = false});

  /// On the card: "2 days overdue", "Due today", "Due tomorrow", "Oct 31".
  final String text;

  /// In the detail: "Oct 26 · 2 days overdue".
  final String long;

  /// "Oct 26".
  final String label;
  final bool overdue;

  /// Today or tomorrow.
  final bool soon;
}

/// [due] is YYYY-MM-DD; null when empty or unreadable.
DueInfo? dueInfo(String due, {DateTime? today}) {
  final d = DateTime.tryParse(due);
  if (d == null) return null;
  final now = today ?? DateTime.now();
  final diff = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  final label = shortDate(d);
  if (diff < 0) {
    final days = '${-diff} ${diff == -1 ? 'day' : 'days'} overdue';
    return DueInfo(text: days, long: '$label · $days', label: label, overdue: true);
  }
  if (diff == 0) return DueInfo(text: 'Due today', long: '$label · today', label: label, soon: true);
  if (diff == 1) return DueInfo(text: 'Due tomorrow', long: '$label · tomorrow', label: label, soon: true);
  return DueInfo(text: label, long: label, label: label);
}

/// "20 min ago", "3 h ago", "today", "yesterday", "Oct 24".
String relativeTime(DateTime at, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(at);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 12) return '${d.inHours} h ago';
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(n.year, n.month, n.day);
  final days = today.difference(day).inDays;
  if (days == 0) return 'today';
  if (days == 1) return 'yesterday';
  return shortDate(at);
}

// ---- Sprints ----

/// The sprint's number after its board ("Pricing 2026.21" → "2026.21").
String sprintShortName(TaskSprint s) => s.name.split(' ').last;

/// What the card says about a sprint: only when it closed (carried over) or
/// is the next one. Null for the active sprint.
String? sprintCardNote(TaskSprint s) => switch (s.state) {
      SprintState.closed => '${sprintShortName(s)} · closed',
      SprintState.future => '${sprintShortName(s)} · next',
      SprintState.active => null,
    };

/// "Oct 21 – Nov 4".
String sprintDates(TaskSprint s) => s.start == null || s.end == null ? '' : '${shortDate(s.start!)} – ${shortDate(s.end!)}';

/// "Active · 7 days left", "Closed", "Next".
String sprintState(TaskSprint s, {DateTime? today}) {
  switch (s.state) {
    case SprintState.closed:
      return 'Closed';
    case SprintState.future:
      return 'Next';
    case SprintState.active:
      final end = s.end;
      if (end == null) return 'Active';
      final n = today ?? DateTime.now();
      final left = DateTime(end.year, end.month, end.day).difference(DateTime(n.year, n.month, n.day)).inDays;
      return left <= 0 ? 'Active · ends today' : 'Active · $left ${left == 1 ? 'day' : 'days'} left';
  }
}

// ---- Status ----

/// The source's status only when it says more than the column the card
/// sits in ("Code Review" in In review: yes; "In Progress" in In progress: no).
String? statusBeyondColumn(TaskEntry t, String columnName) {
  final s = t.sourceStatus.trim();
  if (s.isEmpty) return null;
  final norm = s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  final col = columnName.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  return norm == col ? null : s;
}
