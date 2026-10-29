// This is a generated file - do not edit.
//
// Generated from kumo/v1/kumo.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class GitHost extends $pb.ProtobufEnum {
  static const GitHost GIT_HOST_UNSPECIFIED =
      GitHost._(0, _omitEnumNames ? '' : 'GIT_HOST_UNSPECIFIED');
  static const GitHost GIT_HOST_LOCAL =
      GitHost._(1, _omitEnumNames ? '' : 'GIT_HOST_LOCAL');
  static const GitHost GIT_HOST_GITHUB =
      GitHost._(2, _omitEnumNames ? '' : 'GIT_HOST_GITHUB');
  static const GitHost GIT_HOST_GITLAB =
      GitHost._(3, _omitEnumNames ? '' : 'GIT_HOST_GITLAB');
  static const GitHost GIT_HOST_BITBUCKET =
      GitHost._(4, _omitEnumNames ? '' : 'GIT_HOST_BITBUCKET');
  static const GitHost GIT_HOST_OTHER =
      GitHost._(5, _omitEnumNames ? '' : 'GIT_HOST_OTHER');

  static const $core.List<GitHost> values = <GitHost>[
    GIT_HOST_UNSPECIFIED,
    GIT_HOST_LOCAL,
    GIT_HOST_GITHUB,
    GIT_HOST_GITLAB,
    GIT_HOST_BITBUCKET,
    GIT_HOST_OTHER,
  ];

  static final $core.List<GitHost?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static GitHost? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const GitHost._(super.value, super.name);
}

class ChangeKind extends $pb.ProtobufEnum {
  static const ChangeKind CHANGE_KIND_NONE =
      ChangeKind._(0, _omitEnumNames ? '' : 'CHANGE_KIND_NONE');
  static const ChangeKind CHANGE_KIND_MODIFIED =
      ChangeKind._(1, _omitEnumNames ? '' : 'CHANGE_KIND_MODIFIED');
  static const ChangeKind CHANGE_KIND_ADDED =
      ChangeKind._(2, _omitEnumNames ? '' : 'CHANGE_KIND_ADDED');
  static const ChangeKind CHANGE_KIND_DELETED =
      ChangeKind._(3, _omitEnumNames ? '' : 'CHANGE_KIND_DELETED');
  static const ChangeKind CHANGE_KIND_RENAMED =
      ChangeKind._(4, _omitEnumNames ? '' : 'CHANGE_KIND_RENAMED');
  static const ChangeKind CHANGE_KIND_UNTRACKED =
      ChangeKind._(5, _omitEnumNames ? '' : 'CHANGE_KIND_UNTRACKED');
  static const ChangeKind CHANGE_KIND_TYPE_CHANGED =
      ChangeKind._(6, _omitEnumNames ? '' : 'CHANGE_KIND_TYPE_CHANGED');

  static const $core.List<ChangeKind> values = <ChangeKind>[
    CHANGE_KIND_NONE,
    CHANGE_KIND_MODIFIED,
    CHANGE_KIND_ADDED,
    CHANGE_KIND_DELETED,
    CHANGE_KIND_RENAMED,
    CHANGE_KIND_UNTRACKED,
    CHANGE_KIND_TYPE_CHANGED,
  ];

  static final $core.List<ChangeKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static ChangeKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ChangeKind._(super.value, super.name);
}

class DiffScope extends $pb.ProtobufEnum {
  /// Working tree (staged and not) vs HEAD.
  static const DiffScope DIFF_SCOPE_WORKING =
      DiffScope._(0, _omitEnumNames ? '' : 'DIFF_SCOPE_WORKING');

  /// HEAD vs the branch base.
  static const DiffScope DIFF_SCOPE_COMMITTED =
      DiffScope._(1, _omitEnumNames ? '' : 'DIFF_SCOPE_COMMITTED');

  static const $core.List<DiffScope> values = <DiffScope>[
    DIFF_SCOPE_WORKING,
    DIFF_SCOPE_COMMITTED,
  ];

  static final $core.List<DiffScope?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static DiffScope? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DiffScope._(super.value, super.name);
}

class DiffLineKind extends $pb.ProtobufEnum {
  static const DiffLineKind DIFF_LINE_KIND_CONTEXT =
      DiffLineKind._(0, _omitEnumNames ? '' : 'DIFF_LINE_KIND_CONTEXT');
  static const DiffLineKind DIFF_LINE_KIND_ADDED =
      DiffLineKind._(1, _omitEnumNames ? '' : 'DIFF_LINE_KIND_ADDED');
  static const DiffLineKind DIFF_LINE_KIND_DELETED =
      DiffLineKind._(2, _omitEnumNames ? '' : 'DIFF_LINE_KIND_DELETED');

  static const $core.List<DiffLineKind> values = <DiffLineKind>[
    DIFF_LINE_KIND_CONTEXT,
    DIFF_LINE_KIND_ADDED,
    DIFF_LINE_KIND_DELETED,
  ];

  static final $core.List<DiffLineKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static DiffLineKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DiffLineKind._(super.value, super.name);
}

class AgentState extends $pb.ProtobufEnum {
  /// Producing output.
  static const AgentState AGENT_STATE_WORKING =
      AgentState._(0, _omitEnumNames ? '' : 'AGENT_STATE_WORKING');

  /// Quiet, or it rang the terminal bell / sent a notification: your turn.
  static const AgentState AGENT_STATE_NEEDS_INPUT =
      AgentState._(1, _omitEnumNames ? '' : 'AGENT_STATE_NEEDS_INPUT');
  static const AgentState AGENT_STATE_EXITED =
      AgentState._(2, _omitEnumNames ? '' : 'AGENT_STATE_EXITED');

  static const $core.List<AgentState> values = <AgentState>[
    AGENT_STATE_WORKING,
    AGENT_STATE_NEEDS_INPUT,
    AGENT_STATE_EXITED,
  ];

  static final $core.List<AgentState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static AgentState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AgentState._(super.value, super.name);
}

class TaskSourceKind extends $pb.ProtobufEnum {
  static const TaskSourceKind TASK_SOURCE_KIND_UNSPECIFIED =
      TaskSourceKind._(0, _omitEnumNames ? '' : 'TASK_SOURCE_KIND_UNSPECIFIED');

  /// Options: vault (folder).
  static const TaskSourceKind TASK_SOURCE_KIND_OBSIDIAN =
      TaskSourceKind._(1, _omitEnumNames ? '' : 'TASK_SOURCE_KIND_OBSIDIAN');

  /// Options: database (optional path to Bear's database).
  static const TaskSourceKind TASK_SOURCE_KIND_BEAR =
      TaskSourceKind._(2, _omitEnumNames ? '' : 'TASK_SOURCE_KIND_BEAR');

  /// Options: query (GitHub search syntax). Signs in through `gh`.
  static const TaskSourceKind TASK_SOURCE_KIND_GITHUB =
      TaskSourceKind._(3, _omitEnumNames ? '' : 'TASK_SOURCE_KIND_GITHUB');

  /// Options: site, email, jql. Secret: API token.
  static const TaskSourceKind TASK_SOURCE_KIND_JIRA =
      TaskSourceKind._(4, _omitEnumNames ? '' : 'TASK_SOURCE_KIND_JIRA');

  /// Options: project (optional). Secret: API token.
  static const TaskSourceKind TASK_SOURCE_KIND_TODOIST =
      TaskSourceKind._(5, _omitEnumNames ? '' : 'TASK_SOURCE_KIND_TODOIST');

  static const $core.List<TaskSourceKind> values = <TaskSourceKind>[
    TASK_SOURCE_KIND_UNSPECIFIED,
    TASK_SOURCE_KIND_OBSIDIAN,
    TASK_SOURCE_KIND_BEAR,
    TASK_SOURCE_KIND_GITHUB,
    TASK_SOURCE_KIND_JIRA,
    TASK_SOURCE_KIND_TODOIST,
  ];

  static final $core.List<TaskSourceKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static TaskSourceKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TaskSourceKind._(super.value, super.name);
}

class TaskStatus extends $pb.ProtobufEnum {
  static const TaskStatus TASK_STATUS_TODO =
      TaskStatus._(0, _omitEnumNames ? '' : 'TASK_STATUS_TODO');
  static const TaskStatus TASK_STATUS_DOING =
      TaskStatus._(1, _omitEnumNames ? '' : 'TASK_STATUS_DOING');
  static const TaskStatus TASK_STATUS_REVIEW =
      TaskStatus._(2, _omitEnumNames ? '' : 'TASK_STATUS_REVIEW');
  static const TaskStatus TASK_STATUS_DONE =
      TaskStatus._(3, _omitEnumNames ? '' : 'TASK_STATUS_DONE');

  static const $core.List<TaskStatus> values = <TaskStatus>[
    TASK_STATUS_TODO,
    TASK_STATUS_DOING,
    TASK_STATUS_REVIEW,
    TASK_STATUS_DONE,
  ];

  static final $core.List<TaskStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static TaskStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TaskStatus._(super.value, super.name);
}

class TaskPriority extends $pb.ProtobufEnum {
  static const TaskPriority TASK_PRIORITY_NONE =
      TaskPriority._(0, _omitEnumNames ? '' : 'TASK_PRIORITY_NONE');
  static const TaskPriority TASK_PRIORITY_LOW =
      TaskPriority._(1, _omitEnumNames ? '' : 'TASK_PRIORITY_LOW');
  static const TaskPriority TASK_PRIORITY_MEDIUM =
      TaskPriority._(2, _omitEnumNames ? '' : 'TASK_PRIORITY_MEDIUM');
  static const TaskPriority TASK_PRIORITY_HIGH =
      TaskPriority._(3, _omitEnumNames ? '' : 'TASK_PRIORITY_HIGH');
  static const TaskPriority TASK_PRIORITY_URGENT =
      TaskPriority._(4, _omitEnumNames ? '' : 'TASK_PRIORITY_URGENT');

  static const $core.List<TaskPriority> values = <TaskPriority>[
    TASK_PRIORITY_NONE,
    TASK_PRIORITY_LOW,
    TASK_PRIORITY_MEDIUM,
    TASK_PRIORITY_HIGH,
    TASK_PRIORITY_URGENT,
  ];

  static final $core.List<TaskPriority?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static TaskPriority? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TaskPriority._(super.value, super.name);
}

class TaskType extends $pb.ProtobufEnum {
  static const TaskType TASK_TYPE_UNSPECIFIED =
      TaskType._(0, _omitEnumNames ? '' : 'TASK_TYPE_UNSPECIFIED');
  static const TaskType TASK_TYPE_STORY =
      TaskType._(1, _omitEnumNames ? '' : 'TASK_TYPE_STORY');
  static const TaskType TASK_TYPE_BUG =
      TaskType._(2, _omitEnumNames ? '' : 'TASK_TYPE_BUG');
  static const TaskType TASK_TYPE_TASK =
      TaskType._(3, _omitEnumNames ? '' : 'TASK_TYPE_TASK');
  static const TaskType TASK_TYPE_SUBTASK =
      TaskType._(4, _omitEnumNames ? '' : 'TASK_TYPE_SUBTASK');
  static const TaskType TASK_TYPE_EPIC =
      TaskType._(5, _omitEnumNames ? '' : 'TASK_TYPE_EPIC');

  /// A GitHub issue.
  static const TaskType TASK_TYPE_ISSUE =
      TaskType._(6, _omitEnumNames ? '' : 'TASK_TYPE_ISSUE');

  /// A note checkbox or a to-do (Obsidian, Bear, Todoist).
  static const TaskType TASK_TYPE_TODO =
      TaskType._(7, _omitEnumNames ? '' : 'TASK_TYPE_TODO');

  static const $core.List<TaskType> values = <TaskType>[
    TASK_TYPE_UNSPECIFIED,
    TASK_TYPE_STORY,
    TASK_TYPE_BUG,
    TASK_TYPE_TASK,
    TASK_TYPE_SUBTASK,
    TASK_TYPE_EPIC,
    TASK_TYPE_ISSUE,
    TASK_TYPE_TODO,
  ];

  static final $core.List<TaskType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static TaskType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TaskType._(super.value, super.name);
}

class TaskRelation extends $pb.ProtobufEnum {
  static const TaskRelation TASK_RELATION_UNSPECIFIED =
      TaskRelation._(0, _omitEnumNames ? '' : 'TASK_RELATION_UNSPECIFIED');
  static const TaskRelation TASK_RELATION_ASSIGNED =
      TaskRelation._(1, _omitEnumNames ? '' : 'TASK_RELATION_ASSIGNED');
  static const TaskRelation TASK_RELATION_REPORTED =
      TaskRelation._(2, _omitEnumNames ? '' : 'TASK_RELATION_REPORTED');
  static const TaskRelation TASK_RELATION_WATCHING =
      TaskRelation._(3, _omitEnumNames ? '' : 'TASK_RELATION_WATCHING');

  static const $core.List<TaskRelation> values = <TaskRelation>[
    TASK_RELATION_UNSPECIFIED,
    TASK_RELATION_ASSIGNED,
    TASK_RELATION_REPORTED,
    TASK_RELATION_WATCHING,
  ];

  static final $core.List<TaskRelation?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static TaskRelation? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TaskRelation._(super.value, super.name);
}

class SprintState extends $pb.ProtobufEnum {
  static const SprintState SPRINT_STATE_UNSPECIFIED =
      SprintState._(0, _omitEnumNames ? '' : 'SPRINT_STATE_UNSPECIFIED');
  static const SprintState SPRINT_STATE_CLOSED =
      SprintState._(1, _omitEnumNames ? '' : 'SPRINT_STATE_CLOSED');
  static const SprintState SPRINT_STATE_ACTIVE =
      SprintState._(2, _omitEnumNames ? '' : 'SPRINT_STATE_ACTIVE');
  static const SprintState SPRINT_STATE_FUTURE =
      SprintState._(3, _omitEnumNames ? '' : 'SPRINT_STATE_FUTURE');

  static const $core.List<SprintState> values = <SprintState>[
    SPRINT_STATE_UNSPECIFIED,
    SPRINT_STATE_CLOSED,
    SPRINT_STATE_ACTIVE,
    SPRINT_STATE_FUTURE,
  ];

  static final $core.List<SprintState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static SprintState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SprintState._(super.value, super.name);
}

class LinkKind extends $pb.ProtobufEnum {
  static const LinkKind LINK_KIND_OTHER =
      LinkKind._(0, _omitEnumNames ? '' : 'LINK_KIND_OTHER');
  static const LinkKind LINK_KIND_BLOCKS =
      LinkKind._(1, _omitEnumNames ? '' : 'LINK_KIND_BLOCKS');
  static const LinkKind LINK_KIND_BLOCKED_BY =
      LinkKind._(2, _omitEnumNames ? '' : 'LINK_KIND_BLOCKED_BY');
  static const LinkKind LINK_KIND_RELATES =
      LinkKind._(3, _omitEnumNames ? '' : 'LINK_KIND_RELATES');
  static const LinkKind LINK_KIND_DUPLICATES =
      LinkKind._(4, _omitEnumNames ? '' : 'LINK_KIND_DUPLICATES');
  static const LinkKind LINK_KIND_DUPLICATED_BY =
      LinkKind._(5, _omitEnumNames ? '' : 'LINK_KIND_DUPLICATED_BY');

  static const $core.List<LinkKind> values = <LinkKind>[
    LINK_KIND_OTHER,
    LINK_KIND_BLOCKS,
    LINK_KIND_BLOCKED_BY,
    LINK_KIND_RELATES,
    LINK_KIND_DUPLICATES,
    LINK_KIND_DUPLICATED_BY,
  ];

  static final $core.List<LinkKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static LinkKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const LinkKind._(super.value, super.name);
}

class CiProvider extends $pb.ProtobufEnum {
  static const CiProvider CI_PROVIDER_NONE =
      CiProvider._(0, _omitEnumNames ? '' : 'CI_PROVIDER_NONE');
  static const CiProvider CI_PROVIDER_GITHUB_ACTIONS =
      CiProvider._(1, _omitEnumNames ? '' : 'CI_PROVIDER_GITHUB_ACTIONS');
  static const CiProvider CI_PROVIDER_GITLAB_CI =
      CiProvider._(2, _omitEnumNames ? '' : 'CI_PROVIDER_GITLAB_CI');
  static const CiProvider CI_PROVIDER_BITBUCKET_PIPELINES =
      CiProvider._(3, _omitEnumNames ? '' : 'CI_PROVIDER_BITBUCKET_PIPELINES');

  static const $core.List<CiProvider> values = <CiProvider>[
    CI_PROVIDER_NONE,
    CI_PROVIDER_GITHUB_ACTIONS,
    CI_PROVIDER_GITLAB_CI,
    CI_PROVIDER_BITBUCKET_PIPELINES,
  ];

  static final $core.List<CiProvider?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static CiProvider? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CiProvider._(super.value, super.name);
}

class CiState extends $pb.ProtobufEnum {
  static const CiState CI_STATE_QUEUED =
      CiState._(0, _omitEnumNames ? '' : 'CI_STATE_QUEUED');
  static const CiState CI_STATE_RUNNING =
      CiState._(1, _omitEnumNames ? '' : 'CI_STATE_RUNNING');
  static const CiState CI_STATE_PASSED =
      CiState._(2, _omitEnumNames ? '' : 'CI_STATE_PASSED');
  static const CiState CI_STATE_FAILED =
      CiState._(3, _omitEnumNames ? '' : 'CI_STATE_FAILED');
  static const CiState CI_STATE_CANCELED =
      CiState._(4, _omitEnumNames ? '' : 'CI_STATE_CANCELED');
  static const CiState CI_STATE_SKIPPED =
      CiState._(5, _omitEnumNames ? '' : 'CI_STATE_SKIPPED');

  static const $core.List<CiState> values = <CiState>[
    CI_STATE_QUEUED,
    CI_STATE_RUNNING,
    CI_STATE_PASSED,
    CI_STATE_FAILED,
    CI_STATE_CANCELED,
    CI_STATE_SKIPPED,
  ];

  static final $core.List<CiState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static CiState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CiState._(super.value, super.name);
}

class CiProblemKind extends $pb.ProtobufEnum {
  static const CiProblemKind CI_PROBLEM_KIND_UNSPECIFIED =
      CiProblemKind._(0, _omitEnumNames ? '' : 'CI_PROBLEM_KIND_UNSPECIFIED');

  /// No token for the host.
  static const CiProblemKind CI_PROBLEM_KIND_NOT_CONNECTED =
      CiProblemKind._(1, _omitEnumNames ? '' : 'CI_PROBLEM_KIND_NOT_CONNECTED');

  /// 401: the token expired or was revoked.
  static const CiProblemKind CI_PROBLEM_KIND_UNAUTHORIZED =
      CiProblemKind._(2, _omitEnumNames ? '' : 'CI_PROBLEM_KIND_UNAUTHORIZED');

  /// 403: the token can't read pipelines (see missing_scope).
  static const CiProblemKind CI_PROBLEM_KIND_FORBIDDEN =
      CiProblemKind._(3, _omitEnumNames ? '' : 'CI_PROBLEM_KIND_FORBIDDEN');
  static const CiProblemKind CI_PROBLEM_KIND_NOT_FOUND =
      CiProblemKind._(4, _omitEnumNames ? '' : 'CI_PROBLEM_KIND_NOT_FOUND');

  /// 429, or 403 with no requests left (see retry_at).
  static const CiProblemKind CI_PROBLEM_KIND_RATE_LIMITED =
      CiProblemKind._(5, _omitEnumNames ? '' : 'CI_PROBLEM_KIND_RATE_LIMITED');

  /// Timeouts, DNS, 5xx.
  static const CiProblemKind CI_PROBLEM_KIND_UNREACHABLE =
      CiProblemKind._(6, _omitEnumNames ? '' : 'CI_PROBLEM_KIND_UNREACHABLE');

  /// The branch has no upstream yet (see commits_waiting).
  static const CiProblemKind CI_PROBLEM_KIND_NOT_PUSHED =
      CiProblemKind._(7, _omitEnumNames ? '' : 'CI_PROBLEM_KIND_NOT_PUSHED');

  /// The repository's host has no supported CI (or no remote).
  static const CiProblemKind CI_PROBLEM_KIND_UNSUPPORTED =
      CiProblemKind._(8, _omitEnumNames ? '' : 'CI_PROBLEM_KIND_UNSUPPORTED');

  static const $core.List<CiProblemKind> values = <CiProblemKind>[
    CI_PROBLEM_KIND_UNSPECIFIED,
    CI_PROBLEM_KIND_NOT_CONNECTED,
    CI_PROBLEM_KIND_UNAUTHORIZED,
    CI_PROBLEM_KIND_FORBIDDEN,
    CI_PROBLEM_KIND_NOT_FOUND,
    CI_PROBLEM_KIND_RATE_LIMITED,
    CI_PROBLEM_KIND_UNREACHABLE,
    CI_PROBLEM_KIND_NOT_PUSHED,
    CI_PROBLEM_KIND_UNSUPPORTED,
  ];

  static final $core.List<CiProblemKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 8);
  static CiProblemKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CiProblemKind._(super.value, super.name);
}

class PrState extends $pb.ProtobufEnum {
  static const PrState PR_STATE_OPEN =
      PrState._(0, _omitEnumNames ? '' : 'PR_STATE_OPEN');
  static const PrState PR_STATE_MERGED =
      PrState._(1, _omitEnumNames ? '' : 'PR_STATE_MERGED');
  static const PrState PR_STATE_CLOSED =
      PrState._(2, _omitEnumNames ? '' : 'PR_STATE_CLOSED');

  static const $core.List<PrState> values = <PrState>[
    PR_STATE_OPEN,
    PR_STATE_MERGED,
    PR_STATE_CLOSED,
  ];

  static final $core.List<PrState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static PrState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PrState._(super.value, super.name);
}

class ReviewState extends $pb.ProtobufEnum {
  /// No review asked for or given.
  static const ReviewState REVIEW_STATE_NONE =
      ReviewState._(0, _omitEnumNames ? '' : 'REVIEW_STATE_NONE');

  /// Reviewers were asked; nobody approved yet.
  static const ReviewState REVIEW_STATE_REQUIRED =
      ReviewState._(1, _omitEnumNames ? '' : 'REVIEW_STATE_REQUIRED');
  static const ReviewState REVIEW_STATE_CHANGES_REQUESTED =
      ReviewState._(2, _omitEnumNames ? '' : 'REVIEW_STATE_CHANGES_REQUESTED');
  static const ReviewState REVIEW_STATE_APPROVED =
      ReviewState._(3, _omitEnumNames ? '' : 'REVIEW_STATE_APPROVED');

  static const $core.List<ReviewState> values = <ReviewState>[
    REVIEW_STATE_NONE,
    REVIEW_STATE_REQUIRED,
    REVIEW_STATE_CHANGES_REQUESTED,
    REVIEW_STATE_APPROVED,
  ];

  static final $core.List<ReviewState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ReviewState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ReviewState._(super.value, super.name);
}

class DocKind extends $pb.ProtobufEnum {
  static const DocKind DOC_KIND_UNSPECIFIED =
      DocKind._(0, _omitEnumNames ? '' : 'DOC_KIND_UNSPECIFIED');
  static const DocKind DOC_KIND_CONFLUENCE =
      DocKind._(1, _omitEnumNames ? '' : 'DOC_KIND_CONFLUENCE');
  static const DocKind DOC_KIND_OBSIDIAN =
      DocKind._(2, _omitEnumNames ? '' : 'DOC_KIND_OBSIDIAN');

  static const $core.List<DocKind> values = <DocKind>[
    DOC_KIND_UNSPECIFIED,
    DOC_KIND_CONFLUENCE,
    DOC_KIND_OBSIDIAN,
  ];

  static final $core.List<DocKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static DocKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DocKind._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
