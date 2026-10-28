import '../data/agents_source.dart';
import '../data/models.dart';
import '../data/tasks_source.dart';

/// Labels and lookups the Tasks board and the ticket detail share.

const taskColumns = [
  (TaskColumn.todo, 'To do'),
  (TaskColumn.doing, 'In progress'),
  (TaskColumn.review, 'In review'),
  (TaskColumn.done, 'Done'),
];

/// For the narrow "Move to" control.
const shortTaskColumns = [
  (TaskColumn.todo, 'To do'),
  (TaskColumn.doing, 'Doing'),
  (TaskColumn.review, 'Review'),
  (TaskColumn.done, 'Done'),
];

String columnName(TaskColumn column) => taskColumns.firstWhere((c) => c.$1 == column).$2;

String priorityLabel(TaskPriority p) => switch (p) {
      TaskPriority.urgent => 'Urgent',
      TaskPriority.high => 'High',
      TaskPriority.medium => 'Med',
      TaskPriority.low => 'Low',
      TaskPriority.none => '',
    };

/// The latest agent run in [worktree], if any.
AgentRun? runIn(List<AgentRun> runs, String worktree) {
  AgentRun? latest;
  for (final r in runs) {
    if (r.worktreePath == worktree && (latest == null || r.startedAt.isAfter(latest.startedAt))) latest = r;
  }
  return latest;
}
