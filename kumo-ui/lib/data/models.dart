/// Plain view-models. They mirror what the daemon will stream later
/// (agents, worktrees, tasks). Kept immutable; screens copy on change.
library;

enum AgentStatus { running, needsYou, done }

enum WorktreeTone { idle, running, warn, ok }

class Worktree {
  const Worktree({
    required this.branch,
    required this.note,
    required this.tone,
    this.path = '',
    this.sync = '',
    this.agent = '',
    this.changes = '',
    this.unpushed = 0,
    this.everPushed = true,
    this.principal,
  });
  final String branch;
  final String note;
  final WorktreeTone tone;
  final String path;
  final String sync;
  final String agent;
  final String changes;

  /// Local commits not on the remote yet.
  final int unpushed;

  /// False when the branch only exists locally (no remote, so no pipelines).
  final bool everPushed;

  /// The repository's main checkout (not a `git worktree`). Mocks leave it
  /// unset and use the branch name.
  final bool? principal;
  bool get isMain => principal ?? branch == 'main';
}

enum CheckState { ok, running, waiting }

enum RunStatus { passed, running, queued }

class PipelineRun {
  const PipelineRun({required this.id, required this.commit, required this.status, required this.checks});
  final String id;
  final String commit;
  final RunStatus status;
  final List<(String, String, CheckState)> checks;
}

class Repo {
  const Repo({required this.name, required this.host, required this.worktrees, this.path});
  final String name;

  /// Absolute path of the main checkout (daemon data). Mocks have none.
  final String? path;

  /// Identity: the path when known, else the name (mocks).
  String get id => path ?? name;

  /// GH / GL / BB
  final String host;
  final List<Worktree> worktrees;
}

/// A repository Kumo detected (on a host or on disk) that can be added to a
/// namespace. [repo] is what the sidebar lists once it is in one.
class RepoCandidate {
  const RepoCandidate({required this.host, required this.fullName, required this.meta, required this.cloned, required this.repo});

  /// GH / GL / BB / LO (local folder).
  final String host;
  final String fullName;
  final String meta;
  final bool cloned;
  final Repo repo;

  String get name => repo.name;
}

/// User-defined group of repos in the sidebar.
class Namespace {
  const Namespace({required this.id, required this.name, required this.repos, this.collapsed = false});
  final String id;
  final String name;

  /// Repo names, in sidebar order.
  final List<String> repos;
  final bool collapsed;

  Namespace copyWith({String? name, List<String>? repos, bool? collapsed}) =>
      Namespace(id: id, name: name ?? this.name, repos: repos ?? this.repos, collapsed: collapsed ?? this.collapsed);
}

class Integration {
  const Integration(this.k, this.name);
  final String k;
  final String name;
}

class AgentSession {
  const AgentSession({
    required this.id,
    required this.agent,
    required this.k,
    required this.mode,
    required this.status,
    required this.title,
    required this.src,
    required this.key,
    required this.srcName,
    required this.where,
    required this.whereIsDoc,
    required this.step,
    required this.stepLabel,
    required this.last,
    required this.meta,
    required this.time,
    this.approvalCommand,
  });

  final String id;
  final String agent;
  final String k;
  final String mode;
  final AgentStatus status;
  final String title;
  final String src;
  final String key;
  final String srcName;
  final String where;
  final bool whereIsDoc;
  final int step;
  final String stepLabel;
  final String last;
  final String meta;
  final String time;
  final String? approvalCommand;

  AgentSession copyWith({AgentStatus? status, String? last, String? approvalCommand, bool clearApproval = false}) => AgentSession(
        id: id,
        agent: agent,
        k: k,
        mode: mode,
        status: status ?? this.status,
        title: title,
        src: src,
        key: key,
        srcName: srcName,
        where: where,
        whereIsDoc: whereIsDoc,
        step: step,
        stepLabel: stepLabel,
        last: last ?? this.last,
        meta: meta,
        time: time,
        approvalCommand: clearApproval ? null : (approvalCommand ?? this.approvalCommand),
      );
}

enum TaskColumn { todo, doing, review, done }

class TaskItem {
  const TaskItem({
    required this.col,
    required this.src,
    required this.key,
    required this.title,
    required this.prio,
    required this.meta,
    this.agent,
    this.agentNeedsYou = false,
    this.branch,
  });

  final TaskColumn col;
  final String src;
  final String key;
  final String title;
  final String prio;
  final String meta;
  final String? agent;
  final bool agentNeedsYou;
  final String? branch;

  TaskItem copyWith({TaskColumn? col, String? agent, String? branch}) => TaskItem(
        col: col ?? this.col,
        src: src,
        key: key,
        title: title,
        prio: prio,
        meta: meta,
        agent: agent ?? this.agent,
        agentNeedsYou: agentNeedsYou,
        branch: branch ?? this.branch,
      );
}

enum PrState { ready, draft, reviewRequested, changesRequested, merged }

class PullRequest {
  const PullRequest({required this.host, required this.repo, required this.branch, required this.number, required this.title, required this.state, required this.note});
  final String host;
  final String repo;
  final String branch;
  final String number;
  final String title;
  final PrState state;
  final String note;
}

class ActivityEvent {
  const ActivityEvent(this.text, this.time, this.who, this.tone);
  final String text;
  final String time;
  final String who;
  final WorktreeTone tone;
}
