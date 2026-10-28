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

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
