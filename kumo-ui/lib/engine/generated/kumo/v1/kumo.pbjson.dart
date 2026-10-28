// This is a generated file - do not edit.
//
// Generated from kumo/v1/kumo.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use gitHostDescriptor instead')
const GitHost$json = {
  '1': 'GitHost',
  '2': [
    {'1': 'GIT_HOST_UNSPECIFIED', '2': 0},
    {'1': 'GIT_HOST_LOCAL', '2': 1},
    {'1': 'GIT_HOST_GITHUB', '2': 2},
    {'1': 'GIT_HOST_GITLAB', '2': 3},
    {'1': 'GIT_HOST_BITBUCKET', '2': 4},
    {'1': 'GIT_HOST_OTHER', '2': 5},
  ],
};

/// Descriptor for `GitHost`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List gitHostDescriptor = $convert.base64Decode(
    'CgdHaXRIb3N0EhgKFEdJVF9IT1NUX1VOU1BFQ0lGSUVEEAASEgoOR0lUX0hPU1RfTE9DQUwQAR'
    'ITCg9HSVRfSE9TVF9HSVRIVUIQAhITCg9HSVRfSE9TVF9HSVRMQUIQAxIWChJHSVRfSE9TVF9C'
    'SVRCVUNLRVQQBBISCg5HSVRfSE9TVF9PVEhFUhAF');

@$core.Deprecated('Use changeKindDescriptor instead')
const ChangeKind$json = {
  '1': 'ChangeKind',
  '2': [
    {'1': 'CHANGE_KIND_NONE', '2': 0},
    {'1': 'CHANGE_KIND_MODIFIED', '2': 1},
    {'1': 'CHANGE_KIND_ADDED', '2': 2},
    {'1': 'CHANGE_KIND_DELETED', '2': 3},
    {'1': 'CHANGE_KIND_RENAMED', '2': 4},
    {'1': 'CHANGE_KIND_UNTRACKED', '2': 5},
    {'1': 'CHANGE_KIND_TYPE_CHANGED', '2': 6},
  ],
};

/// Descriptor for `ChangeKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List changeKindDescriptor = $convert.base64Decode(
    'CgpDaGFuZ2VLaW5kEhQKEENIQU5HRV9LSU5EX05PTkUQABIYChRDSEFOR0VfS0lORF9NT0RJRk'
    'lFRBABEhUKEUNIQU5HRV9LSU5EX0FEREVEEAISFwoTQ0hBTkdFX0tJTkRfREVMRVRFRBADEhcK'
    'E0NIQU5HRV9LSU5EX1JFTkFNRUQQBBIZChVDSEFOR0VfS0lORF9VTlRSQUNLRUQQBRIcChhDSE'
    'FOR0VfS0lORF9UWVBFX0NIQU5HRUQQBg==');

@$core.Deprecated('Use diffScopeDescriptor instead')
const DiffScope$json = {
  '1': 'DiffScope',
  '2': [
    {'1': 'DIFF_SCOPE_WORKING', '2': 0},
    {'1': 'DIFF_SCOPE_COMMITTED', '2': 1},
  ],
};

/// Descriptor for `DiffScope`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List diffScopeDescriptor = $convert.base64Decode(
    'CglEaWZmU2NvcGUSFgoSRElGRl9TQ09QRV9XT1JLSU5HEAASGAoURElGRl9TQ09QRV9DT01NSV'
    'RURUQQAQ==');

@$core.Deprecated('Use diffLineKindDescriptor instead')
const DiffLineKind$json = {
  '1': 'DiffLineKind',
  '2': [
    {'1': 'DIFF_LINE_KIND_CONTEXT', '2': 0},
    {'1': 'DIFF_LINE_KIND_ADDED', '2': 1},
    {'1': 'DIFF_LINE_KIND_DELETED', '2': 2},
  ],
};

/// Descriptor for `DiffLineKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List diffLineKindDescriptor = $convert.base64Decode(
    'CgxEaWZmTGluZUtpbmQSGgoWRElGRl9MSU5FX0tJTkRfQ09OVEVYVBAAEhgKFERJRkZfTElORV'
    '9LSU5EX0FEREVEEAESGgoWRElGRl9MSU5FX0tJTkRfREVMRVRFRBAC');

@$core.Deprecated('Use agentStateDescriptor instead')
const AgentState$json = {
  '1': 'AgentState',
  '2': [
    {'1': 'AGENT_STATE_WORKING', '2': 0},
    {'1': 'AGENT_STATE_NEEDS_INPUT', '2': 1},
    {'1': 'AGENT_STATE_EXITED', '2': 2},
  ],
};

/// Descriptor for `AgentState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List agentStateDescriptor = $convert.base64Decode(
    'CgpBZ2VudFN0YXRlEhcKE0FHRU5UX1NUQVRFX1dPUktJTkcQABIbChdBR0VOVF9TVEFURV9ORU'
    'VEU19JTlBVVBABEhYKEkFHRU5UX1NUQVRFX0VYSVRFRBAC');

@$core.Deprecated('Use taskSourceKindDescriptor instead')
const TaskSourceKind$json = {
  '1': 'TaskSourceKind',
  '2': [
    {'1': 'TASK_SOURCE_KIND_UNSPECIFIED', '2': 0},
    {'1': 'TASK_SOURCE_KIND_OBSIDIAN', '2': 1},
    {'1': 'TASK_SOURCE_KIND_BEAR', '2': 2},
    {'1': 'TASK_SOURCE_KIND_GITHUB', '2': 3},
    {'1': 'TASK_SOURCE_KIND_JIRA', '2': 4},
    {'1': 'TASK_SOURCE_KIND_TODOIST', '2': 5},
  ],
};

/// Descriptor for `TaskSourceKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List taskSourceKindDescriptor = $convert.base64Decode(
    'Cg5UYXNrU291cmNlS2luZBIgChxUQVNLX1NPVVJDRV9LSU5EX1VOU1BFQ0lGSUVEEAASHQoZVE'
    'FTS19TT1VSQ0VfS0lORF9PQlNJRElBThABEhkKFVRBU0tfU09VUkNFX0tJTkRfQkVBUhACEhsK'
    'F1RBU0tfU09VUkNFX0tJTkRfR0lUSFVCEAMSGQoVVEFTS19TT1VSQ0VfS0lORF9KSVJBEAQSHA'
    'oYVEFTS19TT1VSQ0VfS0lORF9UT0RPSVNUEAU=');

@$core.Deprecated('Use taskStatusDescriptor instead')
const TaskStatus$json = {
  '1': 'TaskStatus',
  '2': [
    {'1': 'TASK_STATUS_TODO', '2': 0},
    {'1': 'TASK_STATUS_DOING', '2': 1},
    {'1': 'TASK_STATUS_REVIEW', '2': 2},
    {'1': 'TASK_STATUS_DONE', '2': 3},
  ],
};

/// Descriptor for `TaskStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List taskStatusDescriptor = $convert.base64Decode(
    'CgpUYXNrU3RhdHVzEhQKEFRBU0tfU1RBVFVTX1RPRE8QABIVChFUQVNLX1NUQVRVU19ET0lORx'
    'ABEhYKElRBU0tfU1RBVFVTX1JFVklFVxACEhQKEFRBU0tfU1RBVFVTX0RPTkUQAw==');

@$core.Deprecated('Use taskPriorityDescriptor instead')
const TaskPriority$json = {
  '1': 'TaskPriority',
  '2': [
    {'1': 'TASK_PRIORITY_NONE', '2': 0},
    {'1': 'TASK_PRIORITY_LOW', '2': 1},
    {'1': 'TASK_PRIORITY_MEDIUM', '2': 2},
    {'1': 'TASK_PRIORITY_HIGH', '2': 3},
    {'1': 'TASK_PRIORITY_URGENT', '2': 4},
  ],
};

/// Descriptor for `TaskPriority`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List taskPriorityDescriptor = $convert.base64Decode(
    'CgxUYXNrUHJpb3JpdHkSFgoSVEFTS19QUklPUklUWV9OT05FEAASFQoRVEFTS19QUklPUklUWV'
    '9MT1cQARIYChRUQVNLX1BSSU9SSVRZX01FRElVTRACEhYKElRBU0tfUFJJT1JJVFlfSElHSBAD'
    'EhgKFFRBU0tfUFJJT1JJVFlfVVJHRU5UEAQ=');

@$core.Deprecated('Use ciProviderDescriptor instead')
const CiProvider$json = {
  '1': 'CiProvider',
  '2': [
    {'1': 'CI_PROVIDER_NONE', '2': 0},
    {'1': 'CI_PROVIDER_GITHUB_ACTIONS', '2': 1},
    {'1': 'CI_PROVIDER_GITLAB_CI', '2': 2},
    {'1': 'CI_PROVIDER_BITBUCKET_PIPELINES', '2': 3},
  ],
};

/// Descriptor for `CiProvider`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List ciProviderDescriptor = $convert.base64Decode(
    'CgpDaVByb3ZpZGVyEhQKEENJX1BST1ZJREVSX05PTkUQABIeChpDSV9QUk9WSURFUl9HSVRIVU'
    'JfQUNUSU9OUxABEhkKFUNJX1BST1ZJREVSX0dJVExBQl9DSRACEiMKH0NJX1BST1ZJREVSX0JJ'
    'VEJVQ0tFVF9QSVBFTElORVMQAw==');

@$core.Deprecated('Use ciStateDescriptor instead')
const CiState$json = {
  '1': 'CiState',
  '2': [
    {'1': 'CI_STATE_QUEUED', '2': 0},
    {'1': 'CI_STATE_RUNNING', '2': 1},
    {'1': 'CI_STATE_PASSED', '2': 2},
    {'1': 'CI_STATE_FAILED', '2': 3},
    {'1': 'CI_STATE_CANCELED', '2': 4},
    {'1': 'CI_STATE_SKIPPED', '2': 5},
  ],
};

/// Descriptor for `CiState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List ciStateDescriptor = $convert.base64Decode(
    'CgdDaVN0YXRlEhMKD0NJX1NUQVRFX1FVRVVFRBAAEhQKEENJX1NUQVRFX1JVTk5JTkcQARITCg'
    '9DSV9TVEFURV9QQVNTRUQQAhITCg9DSV9TVEFURV9GQUlMRUQQAxIVChFDSV9TVEFURV9DQU5D'
    'RUxFRBAEEhQKEENJX1NUQVRFX1NLSVBQRUQQBQ==');

@$core.Deprecated('Use ciProblemKindDescriptor instead')
const CiProblemKind$json = {
  '1': 'CiProblemKind',
  '2': [
    {'1': 'CI_PROBLEM_KIND_UNSPECIFIED', '2': 0},
    {'1': 'CI_PROBLEM_KIND_NOT_CONNECTED', '2': 1},
    {'1': 'CI_PROBLEM_KIND_UNAUTHORIZED', '2': 2},
    {'1': 'CI_PROBLEM_KIND_FORBIDDEN', '2': 3},
    {'1': 'CI_PROBLEM_KIND_NOT_FOUND', '2': 4},
    {'1': 'CI_PROBLEM_KIND_RATE_LIMITED', '2': 5},
    {'1': 'CI_PROBLEM_KIND_UNREACHABLE', '2': 6},
    {'1': 'CI_PROBLEM_KIND_NOT_PUSHED', '2': 7},
    {'1': 'CI_PROBLEM_KIND_UNSUPPORTED', '2': 8},
  ],
};

/// Descriptor for `CiProblemKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List ciProblemKindDescriptor = $convert.base64Decode(
    'Cg1DaVByb2JsZW1LaW5kEh8KG0NJX1BST0JMRU1fS0lORF9VTlNQRUNJRklFRBAAEiEKHUNJX1'
    'BST0JMRU1fS0lORF9OT1RfQ09OTkVDVEVEEAESIAocQ0lfUFJPQkxFTV9LSU5EX1VOQVVUSE9S'
    'SVpFRBACEh0KGUNJX1BST0JMRU1fS0lORF9GT1JCSURERU4QAxIdChlDSV9QUk9CTEVNX0tJTk'
    'RfTk9UX0ZPVU5EEAQSIAocQ0lfUFJPQkxFTV9LSU5EX1JBVEVfTElNSVRFRBAFEh8KG0NJX1BS'
    'T0JMRU1fS0lORF9VTlJFQUNIQUJMRRAGEh4KGkNJX1BST0JMRU1fS0lORF9OT1RfUFVTSEVEEA'
    'cSHwobQ0lfUFJPQkxFTV9LSU5EX1VOU1VQUE9SVEVEEAg=');

@$core.Deprecated('Use helloRequestDescriptor instead')
const HelloRequest$json = {
  '1': 'HelloRequest',
  '2': [
    {
      '1': 'client_api_version',
      '3': 1,
      '4': 1,
      '5': 13,
      '10': 'clientApiVersion'
    },
    {'1': 'client_name', '3': 2, '4': 1, '5': 9, '10': 'clientName'},
  ],
};

/// Descriptor for `HelloRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List helloRequestDescriptor = $convert.base64Decode(
    'CgxIZWxsb1JlcXVlc3QSLAoSY2xpZW50X2FwaV92ZXJzaW9uGAEgASgNUhBjbGllbnRBcGlWZX'
    'JzaW9uEh8KC2NsaWVudF9uYW1lGAIgASgJUgpjbGllbnROYW1l');

@$core.Deprecated('Use helloResponseDescriptor instead')
const HelloResponse$json = {
  '1': 'HelloResponse',
  '2': [
    {
      '1': 'server_api_version',
      '3': 1,
      '4': 1,
      '5': 13,
      '10': 'serverApiVersion'
    },
    {'1': 'server_version', '3': 2, '4': 1, '5': 9, '10': 'serverVersion'},
    {
      '1': 'server_time_unix_nanos',
      '3': 3,
      '4': 1,
      '5': 4,
      '10': 'serverTimeUnixNanos'
    },
  ],
};

/// Descriptor for `HelloResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List helloResponseDescriptor = $convert.base64Decode(
    'Cg1IZWxsb1Jlc3BvbnNlEiwKEnNlcnZlcl9hcGlfdmVyc2lvbhgBIAEoDVIQc2VydmVyQXBpVm'
    'Vyc2lvbhIlCg5zZXJ2ZXJfdmVyc2lvbhgCIAEoCVINc2VydmVyVmVyc2lvbhIzChZzZXJ2ZXJf'
    'dGltZV91bml4X25hbm9zGAMgASgEUhNzZXJ2ZXJUaW1lVW5peE5hbm9z');

@$core.Deprecated('Use openRequestDescriptor instead')
const OpenRequest$json = {
  '1': 'OpenRequest',
  '2': [
    {'1': 'program', '3': 1, '4': 1, '5': 9, '10': 'program'},
    {'1': 'args', '3': 2, '4': 3, '5': 9, '10': 'args'},
    {'1': 'cwd', '3': 3, '4': 1, '5': 9, '10': 'cwd'},
    {
      '1': 'env',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.OpenRequest.EnvEntry',
      '10': 'env'
    },
    {'1': 'cols', '3': 5, '4': 1, '5': 13, '10': 'cols'},
    {'1': 'rows', '3': 6, '4': 1, '5': 13, '10': 'rows'},
  ],
  '3': [OpenRequest_EnvEntry$json],
};

@$core.Deprecated('Use openRequestDescriptor instead')
const OpenRequest_EnvEntry$json = {
  '1': 'EnvEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `OpenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List openRequestDescriptor = $convert.base64Decode(
    'CgtPcGVuUmVxdWVzdBIYCgdwcm9ncmFtGAEgASgJUgdwcm9ncmFtEhIKBGFyZ3MYAiADKAlSBG'
    'FyZ3MSEAoDY3dkGAMgASgJUgNjd2QSLwoDZW52GAQgAygLMh0ua3Vtby52MS5PcGVuUmVxdWVz'
    'dC5FbnZFbnRyeVIDZW52EhIKBGNvbHMYBSABKA1SBGNvbHMSEgoEcm93cxgGIAEoDVIEcm93cx'
    'o2CghFbnZFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use openResponseDescriptor instead')
const OpenResponse$json = {
  '1': 'OpenResponse',
  '2': [
    {'1': 'terminal_id', '3': 1, '4': 1, '5': 9, '10': 'terminalId'},
  ],
};

/// Descriptor for `OpenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List openResponseDescriptor = $convert.base64Decode(
    'CgxPcGVuUmVzcG9uc2USHwoLdGVybWluYWxfaWQYASABKAlSCnRlcm1pbmFsSWQ=');

@$core.Deprecated('Use terminalInputDescriptor instead')
const TerminalInput$json = {
  '1': 'TerminalInput',
  '2': [
    {
      '1': 'attach',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.kumo.v1.AttachTo',
      '9': 0,
      '10': 'attach'
    },
    {'1': 'data', '3': 2, '4': 1, '5': 12, '9': 0, '10': 'data'},
    {
      '1': 'resize',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.kumo.v1.Resize',
      '9': 0,
      '10': 'resize'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `TerminalInput`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List terminalInputDescriptor = $convert.base64Decode(
    'Cg1UZXJtaW5hbElucHV0EisKBmF0dGFjaBgBIAEoCzIRLmt1bW8udjEuQXR0YWNoVG9IAFIGYX'
    'R0YWNoEhQKBGRhdGEYAiABKAxIAFIEZGF0YRIpCgZyZXNpemUYAyABKAsyDy5rdW1vLnYxLlJl'
    'c2l6ZUgAUgZyZXNpemVCBgoEa2luZA==');

@$core.Deprecated('Use attachToDescriptor instead')
const AttachTo$json = {
  '1': 'AttachTo',
  '2': [
    {'1': 'terminal_id', '3': 1, '4': 1, '5': 9, '10': 'terminalId'},
    {
      '1': 'replay_scrollback',
      '3': 2,
      '4': 1,
      '5': 8,
      '10': 'replayScrollback'
    },
  ],
};

/// Descriptor for `AttachTo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attachToDescriptor = $convert.base64Decode(
    'CghBdHRhY2hUbxIfCgt0ZXJtaW5hbF9pZBgBIAEoCVIKdGVybWluYWxJZBIrChFyZXBsYXlfc2'
    'Nyb2xsYmFjaxgCIAEoCFIQcmVwbGF5U2Nyb2xsYmFjaw==');

@$core.Deprecated('Use resizeDescriptor instead')
const Resize$json = {
  '1': 'Resize',
  '2': [
    {'1': 'cols', '3': 1, '4': 1, '5': 13, '10': 'cols'},
    {'1': 'rows', '3': 2, '4': 1, '5': 13, '10': 'rows'},
  ],
};

/// Descriptor for `Resize`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resizeDescriptor = $convert.base64Decode(
    'CgZSZXNpemUSEgoEY29scxgBIAEoDVIEY29scxISCgRyb3dzGAIgASgNUgRyb3dz');

@$core.Deprecated('Use terminalOutputDescriptor instead')
const TerminalOutput$json = {
  '1': 'TerminalOutput',
  '2': [
    {
      '1': 'output',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.kumo.v1.OutputBatch',
      '9': 0,
      '10': 'output'
    },
    {
      '1': 'exited',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.kumo.v1.Exited',
      '9': 0,
      '10': 'exited'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `TerminalOutput`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List terminalOutputDescriptor = $convert.base64Decode(
    'Cg5UZXJtaW5hbE91dHB1dBIuCgZvdXRwdXQYASABKAsyFC5rdW1vLnYxLk91dHB1dEJhdGNoSA'
    'BSBm91dHB1dBIpCgZleGl0ZWQYAiABKAsyDy5rdW1vLnYxLkV4aXRlZEgAUgZleGl0ZWRCBgoE'
    'a2luZA==');

@$core.Deprecated('Use outputBatchDescriptor instead')
const OutputBatch$json = {
  '1': 'OutputBatch',
  '2': [
    {'1': 'seq', '3': 1, '4': 1, '5': 4, '10': 'seq'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
    {
      '1': 'first_read_unix_nanos',
      '3': 3,
      '4': 1,
      '5': 4,
      '10': 'firstReadUnixNanos'
    },
    {'1': 'chunks', '3': 4, '4': 1, '5': 13, '10': 'chunks'},
  ],
};

/// Descriptor for `OutputBatch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List outputBatchDescriptor = $convert.base64Decode(
    'CgtPdXRwdXRCYXRjaBIQCgNzZXEYASABKARSA3NlcRISCgRkYXRhGAIgASgMUgRkYXRhEjEKFW'
    'ZpcnN0X3JlYWRfdW5peF9uYW5vcxgDIAEoBFISZmlyc3RSZWFkVW5peE5hbm9zEhYKBmNodW5r'
    'cxgEIAEoDVIGY2h1bmtz');

@$core.Deprecated('Use exitedDescriptor instead')
const Exited$json = {
  '1': 'Exited',
  '2': [
    {'1': 'exit_code', '3': 1, '4': 1, '5': 5, '10': 'exitCode'},
  ],
};

/// Descriptor for `Exited`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exitedDescriptor = $convert
    .base64Decode('CgZFeGl0ZWQSGwoJZXhpdF9jb2RlGAEgASgFUghleGl0Q29kZQ==');

@$core.Deprecated('Use closeRequestDescriptor instead')
const CloseRequest$json = {
  '1': 'CloseRequest',
  '2': [
    {'1': 'terminal_id', '3': 1, '4': 1, '5': 9, '10': 'terminalId'},
  ],
};

/// Descriptor for `CloseRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List closeRequestDescriptor = $convert.base64Decode(
    'CgxDbG9zZVJlcXVlc3QSHwoLdGVybWluYWxfaWQYASABKAlSCnRlcm1pbmFsSWQ=');

@$core.Deprecated('Use closeResponseDescriptor instead')
const CloseResponse$json = {
  '1': 'CloseResponse',
};

/// Descriptor for `CloseResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List closeResponseDescriptor =
    $convert.base64Decode('Cg1DbG9zZVJlc3BvbnNl');

@$core.Deprecated('Use listRequestDescriptor instead')
const ListRequest$json = {
  '1': 'ListRequest',
};

/// Descriptor for `ListRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listRequestDescriptor =
    $convert.base64Decode('CgtMaXN0UmVxdWVzdA==');

@$core.Deprecated('Use listResponseDescriptor instead')
const ListResponse$json = {
  '1': 'ListResponse',
  '2': [
    {
      '1': 'terminals',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.TerminalInfo',
      '10': 'terminals'
    },
  ],
};

/// Descriptor for `ListResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listResponseDescriptor = $convert.base64Decode(
    'CgxMaXN0UmVzcG9uc2USMwoJdGVybWluYWxzGAEgAygLMhUua3Vtby52MS5UZXJtaW5hbEluZm'
    '9SCXRlcm1pbmFscw==');

@$core.Deprecated('Use terminalInfoDescriptor instead')
const TerminalInfo$json = {
  '1': 'TerminalInfo',
  '2': [
    {'1': 'terminal_id', '3': 1, '4': 1, '5': 9, '10': 'terminalId'},
    {'1': 'program', '3': 2, '4': 1, '5': 9, '10': 'program'},
    {'1': 'exited', '3': 3, '4': 1, '5': 8, '10': 'exited'},
    {'1': 'exit_code', '3': 4, '4': 1, '5': 5, '10': 'exitCode'},
    {'1': 'cwd', '3': 5, '4': 1, '5': 9, '10': 'cwd'},
  ],
};

/// Descriptor for `TerminalInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List terminalInfoDescriptor = $convert.base64Decode(
    'CgxUZXJtaW5hbEluZm8SHwoLdGVybWluYWxfaWQYASABKAlSCnRlcm1pbmFsSWQSGAoHcHJvZ3'
    'JhbRgCIAEoCVIHcHJvZ3JhbRIWCgZleGl0ZWQYAyABKAhSBmV4aXRlZBIbCglleGl0X2NvZGUY'
    'BCABKAVSCGV4aXRDb2RlEhAKA2N3ZBgFIAEoCVIDY3dk');

@$core.Deprecated('Use watchWorkspaceRequestDescriptor instead')
const WatchWorkspaceRequest$json = {
  '1': 'WatchWorkspaceRequest',
};

/// Descriptor for `WatchWorkspaceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchWorkspaceRequestDescriptor =
    $convert.base64Decode('ChVXYXRjaFdvcmtzcGFjZVJlcXVlc3Q=');

@$core.Deprecated('Use workspaceSnapshotDescriptor instead')
const WorkspaceSnapshot$json = {
  '1': 'WorkspaceSnapshot',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 4, '10': 'version'},
    {
      '1': 'namespaces',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.Namespace',
      '10': 'namespaces'
    },
    {
      '1': 'repositories',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.Repository',
      '10': 'repositories'
    },
  ],
};

/// Descriptor for `WorkspaceSnapshot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workspaceSnapshotDescriptor = $convert.base64Decode(
    'ChFXb3Jrc3BhY2VTbmFwc2hvdBIYCgd2ZXJzaW9uGAEgASgEUgd2ZXJzaW9uEjIKCm5hbWVzcG'
    'FjZXMYAiADKAsyEi5rdW1vLnYxLk5hbWVzcGFjZVIKbmFtZXNwYWNlcxI3CgxyZXBvc2l0b3Jp'
    'ZXMYAyADKAsyEy5rdW1vLnYxLlJlcG9zaXRvcnlSDHJlcG9zaXRvcmllcw==');

@$core.Deprecated('Use namespaceDescriptor instead')
const Namespace$json = {
  '1': 'Namespace',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'repo_paths', '3': 3, '4': 3, '5': 9, '10': 'repoPaths'},
    {'1': 'collapsed', '3': 4, '4': 1, '5': 8, '10': 'collapsed'},
  ],
};

/// Descriptor for `Namespace`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List namespaceDescriptor = $convert.base64Decode(
    'CglOYW1lc3BhY2USDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSHQoKcmVwb1'
    '9wYXRocxgDIAMoCVIJcmVwb1BhdGhzEhwKCWNvbGxhcHNlZBgEIAEoCFIJY29sbGFwc2Vk');

@$core.Deprecated('Use repositoryDescriptor instead')
const Repository$json = {
  '1': 'Repository',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'host',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.GitHost',
      '10': 'host'
    },
    {'1': 'full_name', '3': 4, '4': 1, '5': 9, '10': 'fullName'},
    {'1': 'remote_url', '3': 5, '4': 1, '5': 9, '10': 'remoteUrl'},
    {
      '1': 'worktrees',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.Worktree',
      '10': 'worktrees'
    },
    {'1': 'error', '3': 7, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `Repository`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List repositoryDescriptor = $convert.base64Decode(
    'CgpSZXBvc2l0b3J5EhIKBHBhdGgYASABKAlSBHBhdGgSEgoEbmFtZRgCIAEoCVIEbmFtZRIkCg'
    'Rob3N0GAMgASgOMhAua3Vtby52MS5HaXRIb3N0UgRob3N0EhsKCWZ1bGxfbmFtZRgEIAEoCVII'
    'ZnVsbE5hbWUSHQoKcmVtb3RlX3VybBgFIAEoCVIJcmVtb3RlVXJsEi8KCXdvcmt0cmVlcxgGIA'
    'MoCzIRLmt1bW8udjEuV29ya3RyZWVSCXdvcmt0cmVlcxIUCgVlcnJvchgHIAEoCVIFZXJyb3I=');

@$core.Deprecated('Use worktreeDescriptor instead')
const Worktree$json = {
  '1': 'Worktree',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'branch', '3': 2, '4': 1, '5': 9, '10': 'branch'},
    {'1': 'head', '3': 3, '4': 1, '5': 9, '10': 'head'},
    {'1': 'is_main', '3': 4, '4': 1, '5': 8, '10': 'isMain'},
    {'1': 'locked', '3': 5, '4': 1, '5': 8, '10': 'locked'},
    {
      '1': 'status',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.kumo.v1.WorktreeStatus',
      '10': 'status'
    },
  ],
};

/// Descriptor for `Worktree`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List worktreeDescriptor = $convert.base64Decode(
    'CghXb3JrdHJlZRISCgRwYXRoGAEgASgJUgRwYXRoEhYKBmJyYW5jaBgCIAEoCVIGYnJhbmNoEh'
    'IKBGhlYWQYAyABKAlSBGhlYWQSFwoHaXNfbWFpbhgEIAEoCFIGaXNNYWluEhYKBmxvY2tlZBgF'
    'IAEoCFIGbG9ja2VkEi8KBnN0YXR1cxgGIAEoCzIXLmt1bW8udjEuV29ya3RyZWVTdGF0dXNSBn'
    'N0YXR1cw==');

@$core.Deprecated('Use worktreeStatusDescriptor instead')
const WorktreeStatus$json = {
  '1': 'WorktreeStatus',
  '2': [
    {'1': 'changed_files', '3': 1, '4': 1, '5': 13, '10': 'changedFiles'},
    {'1': 'ahead', '3': 2, '4': 1, '5': 13, '10': 'ahead'},
    {'1': 'behind', '3': 3, '4': 1, '5': 13, '10': 'behind'},
    {'1': 'upstream', '3': 4, '4': 1, '5': 9, '10': 'upstream'},
  ],
};

/// Descriptor for `WorktreeStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List worktreeStatusDescriptor = $convert.base64Decode(
    'Cg5Xb3JrdHJlZVN0YXR1cxIjCg1jaGFuZ2VkX2ZpbGVzGAEgASgNUgxjaGFuZ2VkRmlsZXMSFA'
    'oFYWhlYWQYAiABKA1SBWFoZWFkEhYKBmJlaGluZBgDIAEoDVIGYmVoaW5kEhoKCHVwc3RyZWFt'
    'GAQgASgJUgh1cHN0cmVhbQ==');

@$core.Deprecated('Use refreshWorkspaceRequestDescriptor instead')
const RefreshWorkspaceRequest$json = {
  '1': 'RefreshWorkspaceRequest',
};

/// Descriptor for `RefreshWorkspaceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshWorkspaceRequestDescriptor =
    $convert.base64Decode('ChdSZWZyZXNoV29ya3NwYWNlUmVxdWVzdA==');

@$core.Deprecated('Use refreshWorkspaceResponseDescriptor instead')
const RefreshWorkspaceResponse$json = {
  '1': 'RefreshWorkspaceResponse',
};

/// Descriptor for `RefreshWorkspaceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshWorkspaceResponseDescriptor =
    $convert.base64Decode('ChhSZWZyZXNoV29ya3NwYWNlUmVzcG9uc2U=');

@$core.Deprecated('Use discoverReposRequestDescriptor instead')
const DiscoverReposRequest$json = {
  '1': 'DiscoverReposRequest',
  '2': [
    {'1': 'roots', '3': 1, '4': 3, '5': 9, '10': 'roots'},
  ],
};

/// Descriptor for `DiscoverReposRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List discoverReposRequestDescriptor =
    $convert.base64Decode(
        'ChREaXNjb3ZlclJlcG9zUmVxdWVzdBIUCgVyb290cxgBIAMoCVIFcm9vdHM=');

@$core.Deprecated('Use discoverReposResponseDescriptor instead')
const DiscoverReposResponse$json = {
  '1': 'DiscoverReposResponse',
  '2': [
    {
      '1': 'candidates',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.RepoCandidate',
      '10': 'candidates'
    },
  ],
};

/// Descriptor for `DiscoverReposResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List discoverReposResponseDescriptor = $convert.base64Decode(
    'ChVEaXNjb3ZlclJlcG9zUmVzcG9uc2USNgoKY2FuZGlkYXRlcxgBIAMoCzIWLmt1bW8udjEuUm'
    'Vwb0NhbmRpZGF0ZVIKY2FuZGlkYXRlcw==');

@$core.Deprecated('Use repoCandidateDescriptor instead')
const RepoCandidate$json = {
  '1': 'RepoCandidate',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'host',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.GitHost',
      '10': 'host'
    },
    {'1': 'full_name', '3': 4, '4': 1, '5': 9, '10': 'fullName'},
    {'1': 'worktree_count', '3': 5, '4': 1, '5': 13, '10': 'worktreeCount'},
  ],
};

/// Descriptor for `RepoCandidate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List repoCandidateDescriptor = $convert.base64Decode(
    'Cg1SZXBvQ2FuZGlkYXRlEhIKBHBhdGgYASABKAlSBHBhdGgSEgoEbmFtZRgCIAEoCVIEbmFtZR'
    'IkCgRob3N0GAMgASgOMhAua3Vtby52MS5HaXRIb3N0UgRob3N0EhsKCWZ1bGxfbmFtZRgEIAEo'
    'CVIIZnVsbE5hbWUSJQoOd29ya3RyZWVfY291bnQYBSABKA1SDXdvcmt0cmVlQ291bnQ=');

@$core.Deprecated('Use saveNamespaceRequestDescriptor instead')
const SaveNamespaceRequest$json = {
  '1': 'SaveNamespaceRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'repo_paths', '3': 3, '4': 3, '5': 9, '10': 'repoPaths'},
    {'1': 'collapsed', '3': 4, '4': 1, '5': 8, '10': 'collapsed'},
    {
      '1': 'position',
      '3': 5,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'position',
      '17': true
    },
  ],
  '8': [
    {'1': '_position'},
  ],
};

/// Descriptor for `SaveNamespaceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveNamespaceRequestDescriptor = $convert.base64Decode(
    'ChRTYXZlTmFtZXNwYWNlUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbm'
    'FtZRIdCgpyZXBvX3BhdGhzGAMgAygJUglyZXBvUGF0aHMSHAoJY29sbGFwc2VkGAQgASgIUglj'
    'b2xsYXBzZWQSHwoIcG9zaXRpb24YBSABKA1IAFIIcG9zaXRpb26IAQFCCwoJX3Bvc2l0aW9u');

@$core.Deprecated('Use saveNamespaceResponseDescriptor instead')
const SaveNamespaceResponse$json = {
  '1': 'SaveNamespaceResponse',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `SaveNamespaceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveNamespaceResponseDescriptor = $convert
    .base64Decode('ChVTYXZlTmFtZXNwYWNlUmVzcG9uc2USDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use deleteNamespaceRequestDescriptor instead')
const DeleteNamespaceRequest$json = {
  '1': 'DeleteNamespaceRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteNamespaceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteNamespaceRequestDescriptor = $convert
    .base64Decode('ChZEZWxldGVOYW1lc3BhY2VSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use deleteNamespaceResponseDescriptor instead')
const DeleteNamespaceResponse$json = {
  '1': 'DeleteNamespaceResponse',
};

/// Descriptor for `DeleteNamespaceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteNamespaceResponseDescriptor =
    $convert.base64Decode('ChdEZWxldGVOYW1lc3BhY2VSZXNwb25zZQ==');

@$core.Deprecated('Use createWorktreeRequestDescriptor instead')
const CreateWorktreeRequest$json = {
  '1': 'CreateWorktreeRequest',
  '2': [
    {'1': 'repo_path', '3': 1, '4': 1, '5': 9, '10': 'repoPath'},
    {'1': 'branch', '3': 2, '4': 1, '5': 9, '10': 'branch'},
    {'1': 'create_branch', '3': 3, '4': 1, '5': 8, '10': 'createBranch'},
    {'1': 'base', '3': 4, '4': 1, '5': 9, '10': 'base'},
    {'1': 'path', '3': 5, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `CreateWorktreeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createWorktreeRequestDescriptor = $convert.base64Decode(
    'ChVDcmVhdGVXb3JrdHJlZVJlcXVlc3QSGwoJcmVwb19wYXRoGAEgASgJUghyZXBvUGF0aBIWCg'
    'ZicmFuY2gYAiABKAlSBmJyYW5jaBIjCg1jcmVhdGVfYnJhbmNoGAMgASgIUgxjcmVhdGVCcmFu'
    'Y2gSEgoEYmFzZRgEIAEoCVIEYmFzZRISCgRwYXRoGAUgASgJUgRwYXRo');

@$core.Deprecated('Use createWorktreeResponseDescriptor instead')
const CreateWorktreeResponse$json = {
  '1': 'CreateWorktreeResponse',
  '2': [
    {
      '1': 'worktree',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.kumo.v1.Worktree',
      '10': 'worktree'
    },
  ],
};

/// Descriptor for `CreateWorktreeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createWorktreeResponseDescriptor =
    $convert.base64Decode(
        'ChZDcmVhdGVXb3JrdHJlZVJlc3BvbnNlEi0KCHdvcmt0cmVlGAEgASgLMhEua3Vtby52MS5Xb3'
        'JrdHJlZVIId29ya3RyZWU=');

@$core.Deprecated('Use removeWorktreeRequestDescriptor instead')
const RemoveWorktreeRequest$json = {
  '1': 'RemoveWorktreeRequest',
  '2': [
    {'1': 'repo_path', '3': 1, '4': 1, '5': 9, '10': 'repoPath'},
    {'1': 'worktree_path', '3': 2, '4': 1, '5': 9, '10': 'worktreePath'},
    {'1': 'force', '3': 3, '4': 1, '5': 8, '10': 'force'},
  ],
};

/// Descriptor for `RemoveWorktreeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeWorktreeRequestDescriptor = $convert.base64Decode(
    'ChVSZW1vdmVXb3JrdHJlZVJlcXVlc3QSGwoJcmVwb19wYXRoGAEgASgJUghyZXBvUGF0aBIjCg'
    '13b3JrdHJlZV9wYXRoGAIgASgJUgx3b3JrdHJlZVBhdGgSFAoFZm9yY2UYAyABKAhSBWZvcmNl');

@$core.Deprecated('Use removeWorktreeResponseDescriptor instead')
const RemoveWorktreeResponse$json = {
  '1': 'RemoveWorktreeResponse',
};

/// Descriptor for `RemoveWorktreeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeWorktreeResponseDescriptor =
    $convert.base64Decode('ChZSZW1vdmVXb3JrdHJlZVJlc3BvbnNl');

@$core.Deprecated('Use listBranchesRequestDescriptor instead')
const ListBranchesRequest$json = {
  '1': 'ListBranchesRequest',
  '2': [
    {'1': 'repo_path', '3': 1, '4': 1, '5': 9, '10': 'repoPath'},
  ],
};

/// Descriptor for `ListBranchesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listBranchesRequestDescriptor =
    $convert.base64Decode(
        'ChNMaXN0QnJhbmNoZXNSZXF1ZXN0EhsKCXJlcG9fcGF0aBgBIAEoCVIIcmVwb1BhdGg=');

@$core.Deprecated('Use listBranchesResponseDescriptor instead')
const ListBranchesResponse$json = {
  '1': 'ListBranchesResponse',
  '2': [
    {'1': 'current', '3': 1, '4': 1, '5': 9, '10': 'current'},
    {'1': 'local', '3': 2, '4': 3, '5': 9, '10': 'local'},
    {'1': 'remote', '3': 3, '4': 3, '5': 9, '10': 'remote'},
  ],
};

/// Descriptor for `ListBranchesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listBranchesResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0QnJhbmNoZXNSZXNwb25zZRIYCgdjdXJyZW50GAEgASgJUgdjdXJyZW50EhQKBWxvY2'
    'FsGAIgAygJUgVsb2NhbBIWCgZyZW1vdGUYAyADKAlSBnJlbW90ZQ==');

@$core.Deprecated('Use worktreeRequestDescriptor instead')
const WorktreeRequest$json = {
  '1': 'WorktreeRequest',
  '2': [
    {'1': 'worktree_path', '3': 1, '4': 1, '5': 9, '10': 'worktreePath'},
  ],
};

/// Descriptor for `WorktreeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List worktreeRequestDescriptor = $convert.base64Decode(
    'Cg9Xb3JrdHJlZVJlcXVlc3QSIwoNd29ya3RyZWVfcGF0aBgBIAEoCVIMd29ya3RyZWVQYXRo');

@$core.Deprecated('Use watchStatusRequestDescriptor instead')
const WatchStatusRequest$json = {
  '1': 'WatchStatusRequest',
  '2': [
    {'1': 'worktree_path', '3': 1, '4': 1, '5': 9, '10': 'worktreePath'},
  ],
};

/// Descriptor for `WatchStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchStatusRequestDescriptor = $convert.base64Decode(
    'ChJXYXRjaFN0YXR1c1JlcXVlc3QSIwoNd29ya3RyZWVfcGF0aBgBIAEoCVIMd29ya3RyZWVQYX'
    'Ro');

@$core.Deprecated('Use fileChangeDescriptor instead')
const FileChange$json = {
  '1': 'FileChange',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'old_path', '3': 2, '4': 1, '5': 9, '10': 'oldPath'},
    {
      '1': 'staged',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.ChangeKind',
      '10': 'staged'
    },
    {
      '1': 'unstaged',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.ChangeKind',
      '10': 'unstaged'
    },
    {'1': 'conflict', '3': 5, '4': 1, '5': 8, '10': 'conflict'},
    {'1': 'additions', '3': 6, '4': 1, '5': 13, '10': 'additions'},
    {'1': 'deletions', '3': 7, '4': 1, '5': 13, '10': 'deletions'},
    {'1': 'binary', '3': 8, '4': 1, '5': 8, '10': 'binary'},
  ],
};

/// Descriptor for `FileChange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileChangeDescriptor = $convert.base64Decode(
    'CgpGaWxlQ2hhbmdlEhIKBHBhdGgYASABKAlSBHBhdGgSGQoIb2xkX3BhdGgYAiABKAlSB29sZF'
    'BhdGgSKwoGc3RhZ2VkGAMgASgOMhMua3Vtby52MS5DaGFuZ2VLaW5kUgZzdGFnZWQSLwoIdW5z'
    'dGFnZWQYBCABKA4yEy5rdW1vLnYxLkNoYW5nZUtpbmRSCHVuc3RhZ2VkEhoKCGNvbmZsaWN0GA'
    'UgASgIUghjb25mbGljdBIcCglhZGRpdGlvbnMYBiABKA1SCWFkZGl0aW9ucxIcCglkZWxldGlv'
    'bnMYByABKA1SCWRlbGV0aW9ucxIWCgZiaW5hcnkYCCABKAhSBmJpbmFyeQ==');

@$core.Deprecated('Use worktreeChangesDescriptor instead')
const WorktreeChanges$json = {
  '1': 'WorktreeChanges',
  '2': [
    {'1': 'branch', '3': 1, '4': 1, '5': 9, '10': 'branch'},
    {'1': 'upstream', '3': 2, '4': 1, '5': 9, '10': 'upstream'},
    {'1': 'ahead', '3': 3, '4': 1, '5': 13, '10': 'ahead'},
    {'1': 'behind', '3': 4, '4': 1, '5': 13, '10': 'behind'},
    {
      '1': 'working',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.FileChange',
      '10': 'working'
    },
    {'1': 'base', '3': 6, '4': 1, '5': 9, '10': 'base'},
    {
      '1': 'committed',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.FileChange',
      '10': 'committed'
    },
  ],
};

/// Descriptor for `WorktreeChanges`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List worktreeChangesDescriptor = $convert.base64Decode(
    'Cg9Xb3JrdHJlZUNoYW5nZXMSFgoGYnJhbmNoGAEgASgJUgZicmFuY2gSGgoIdXBzdHJlYW0YAi'
    'ABKAlSCHVwc3RyZWFtEhQKBWFoZWFkGAMgASgNUgVhaGVhZBIWCgZiZWhpbmQYBCABKA1SBmJl'
    'aGluZBItCgd3b3JraW5nGAUgAygLMhMua3Vtby52MS5GaWxlQ2hhbmdlUgd3b3JraW5nEhIKBG'
    'Jhc2UYBiABKAlSBGJhc2USMQoJY29tbWl0dGVkGAcgAygLMhMua3Vtby52MS5GaWxlQ2hhbmdl'
    'Ugljb21taXR0ZWQ=');

@$core.Deprecated('Use listFilesRequestDescriptor instead')
const ListFilesRequest$json = {
  '1': 'ListFilesRequest',
  '2': [
    {'1': 'worktree_path', '3': 1, '4': 1, '5': 9, '10': 'worktreePath'},
  ],
};

/// Descriptor for `ListFilesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listFilesRequestDescriptor = $convert.base64Decode(
    'ChBMaXN0RmlsZXNSZXF1ZXN0EiMKDXdvcmt0cmVlX3BhdGgYASABKAlSDHdvcmt0cmVlUGF0aA'
    '==');

@$core.Deprecated('Use listFilesResponseDescriptor instead')
const ListFilesResponse$json = {
  '1': 'ListFilesResponse',
  '2': [
    {'1': 'paths', '3': 1, '4': 3, '5': 9, '10': 'paths'},
    {'1': 'truncated', '3': 2, '4': 1, '5': 8, '10': 'truncated'},
  ],
};

/// Descriptor for `ListFilesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listFilesResponseDescriptor = $convert.base64Decode(
    'ChFMaXN0RmlsZXNSZXNwb25zZRIUCgVwYXRocxgBIAMoCVIFcGF0aHMSHAoJdHJ1bmNhdGVkGA'
    'IgASgIUgl0cnVuY2F0ZWQ=');

@$core.Deprecated('Use readFileRequestDescriptor instead')
const ReadFileRequest$json = {
  '1': 'ReadFileRequest',
  '2': [
    {'1': 'worktree_path', '3': 1, '4': 1, '5': 9, '10': 'worktreePath'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `ReadFileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List readFileRequestDescriptor = $convert.base64Decode(
    'Cg9SZWFkRmlsZVJlcXVlc3QSIwoNd29ya3RyZWVfcGF0aBgBIAEoCVIMd29ya3RyZWVQYXRoEh'
    'IKBHBhdGgYAiABKAlSBHBhdGg=');

@$core.Deprecated('Use readFileResponseDescriptor instead')
const ReadFileResponse$json = {
  '1': 'ReadFileResponse',
  '2': [
    {'1': 'content', '3': 1, '4': 1, '5': 12, '10': 'content'},
    {'1': 'binary', '3': 2, '4': 1, '5': 8, '10': 'binary'},
    {'1': 'truncated', '3': 3, '4': 1, '5': 8, '10': 'truncated'},
    {'1': 'size', '3': 4, '4': 1, '5': 4, '10': 'size'},
  ],
};

/// Descriptor for `ReadFileResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List readFileResponseDescriptor = $convert.base64Decode(
    'ChBSZWFkRmlsZVJlc3BvbnNlEhgKB2NvbnRlbnQYASABKAxSB2NvbnRlbnQSFgoGYmluYXJ5GA'
    'IgASgIUgZiaW5hcnkSHAoJdHJ1bmNhdGVkGAMgASgIUgl0cnVuY2F0ZWQSEgoEc2l6ZRgEIAEo'
    'BFIEc2l6ZQ==');

@$core.Deprecated('Use writeFileRequestDescriptor instead')
const WriteFileRequest$json = {
  '1': 'WriteFileRequest',
  '2': [
    {'1': 'worktree_path', '3': 1, '4': 1, '5': 9, '10': 'worktreePath'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
    {'1': 'content', '3': 3, '4': 1, '5': 12, '10': 'content'},
  ],
};

/// Descriptor for `WriteFileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List writeFileRequestDescriptor = $convert.base64Decode(
    'ChBXcml0ZUZpbGVSZXF1ZXN0EiMKDXdvcmt0cmVlX3BhdGgYASABKAlSDHdvcmt0cmVlUGF0aB'
    'ISCgRwYXRoGAIgASgJUgRwYXRoEhgKB2NvbnRlbnQYAyABKAxSB2NvbnRlbnQ=');

@$core.Deprecated('Use writeFileResponseDescriptor instead')
const WriteFileResponse$json = {
  '1': 'WriteFileResponse',
};

/// Descriptor for `WriteFileResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List writeFileResponseDescriptor =
    $convert.base64Decode('ChFXcml0ZUZpbGVSZXNwb25zZQ==');

@$core.Deprecated('Use diffRequestDescriptor instead')
const DiffRequest$json = {
  '1': 'DiffRequest',
  '2': [
    {'1': 'worktree_path', '3': 1, '4': 1, '5': 9, '10': 'worktreePath'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
    {
      '1': 'scope',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.DiffScope',
      '10': 'scope'
    },
  ],
};

/// Descriptor for `DiffRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List diffRequestDescriptor = $convert.base64Decode(
    'CgtEaWZmUmVxdWVzdBIjCg13b3JrdHJlZV9wYXRoGAEgASgJUgx3b3JrdHJlZVBhdGgSEgoEcG'
    'F0aBgCIAEoCVIEcGF0aBIoCgVzY29wZRgDIAEoDjISLmt1bW8udjEuRGlmZlNjb3BlUgVzY29w'
    'ZQ==');

@$core.Deprecated('Use diffLineDescriptor instead')
const DiffLine$json = {
  '1': 'DiffLine',
  '2': [
    {
      '1': 'kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.DiffLineKind',
      '10': 'kind'
    },
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `DiffLine`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List diffLineDescriptor = $convert.base64Decode(
    'CghEaWZmTGluZRIpCgRraW5kGAEgASgOMhUua3Vtby52MS5EaWZmTGluZUtpbmRSBGtpbmQSEg'
    'oEdGV4dBgCIAEoCVIEdGV4dA==');

@$core.Deprecated('Use diffResponseDescriptor instead')
const DiffResponse$json = {
  '1': 'DiffResponse',
  '2': [
    {
      '1': 'lines',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.DiffLine',
      '10': 'lines'
    },
    {'1': 'binary', '3': 2, '4': 1, '5': 8, '10': 'binary'},
  ],
};

/// Descriptor for `DiffResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List diffResponseDescriptor = $convert.base64Decode(
    'CgxEaWZmUmVzcG9uc2USJwoFbGluZXMYASADKAsyES5rdW1vLnYxLkRpZmZMaW5lUgVsaW5lcx'
    'IWCgZiaW5hcnkYAiABKAhSBmJpbmFyeQ==');

@$core.Deprecated('Use pathsRequestDescriptor instead')
const PathsRequest$json = {
  '1': 'PathsRequest',
  '2': [
    {'1': 'worktree_path', '3': 1, '4': 1, '5': 9, '10': 'worktreePath'},
    {'1': 'paths', '3': 2, '4': 3, '5': 9, '10': 'paths'},
  ],
};

/// Descriptor for `PathsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pathsRequestDescriptor = $convert.base64Decode(
    'CgxQYXRoc1JlcXVlc3QSIwoNd29ya3RyZWVfcGF0aBgBIAEoCVIMd29ya3RyZWVQYXRoEhQKBX'
    'BhdGhzGAIgAygJUgVwYXRocw==');

@$core.Deprecated('Use gitActionResponseDescriptor instead')
const GitActionResponse$json = {
  '1': 'GitActionResponse',
};

/// Descriptor for `GitActionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitActionResponseDescriptor =
    $convert.base64Decode('ChFHaXRBY3Rpb25SZXNwb25zZQ==');

@$core.Deprecated('Use commitRequestDescriptor instead')
const CommitRequest$json = {
  '1': 'CommitRequest',
  '2': [
    {'1': 'worktree_path', '3': 1, '4': 1, '5': 9, '10': 'worktreePath'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'all', '3': 3, '4': 1, '5': 8, '10': 'all'},
    {'1': 'amend', '3': 4, '4': 1, '5': 8, '10': 'amend'},
  ],
};

/// Descriptor for `CommitRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commitRequestDescriptor = $convert.base64Decode(
    'Cg1Db21taXRSZXF1ZXN0EiMKDXdvcmt0cmVlX3BhdGgYASABKAlSDHdvcmt0cmVlUGF0aBIYCg'
    'dtZXNzYWdlGAIgASgJUgdtZXNzYWdlEhAKA2FsbBgDIAEoCFIDYWxsEhQKBWFtZW5kGAQgASgI'
    'UgVhbWVuZA==');

@$core.Deprecated('Use commitResponseDescriptor instead')
const CommitResponse$json = {
  '1': 'CommitResponse',
  '2': [
    {'1': 'sha', '3': 1, '4': 1, '5': 9, '10': 'sha'},
    {'1': 'short_sha', '3': 2, '4': 1, '5': 9, '10': 'shortSha'},
  ],
};

/// Descriptor for `CommitResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commitResponseDescriptor = $convert.base64Decode(
    'Cg5Db21taXRSZXNwb25zZRIQCgNzaGEYASABKAlSA3NoYRIbCglzaG9ydF9zaGEYAiABKAlSCH'
    'Nob3J0U2hh');

@$core.Deprecated('Use logRequestDescriptor instead')
const LogRequest$json = {
  '1': 'LogRequest',
  '2': [
    {'1': 'worktree_path', '3': 1, '4': 1, '5': 9, '10': 'worktreePath'},
    {'1': 'limit', '3': 2, '4': 1, '5': 13, '10': 'limit'},
  ],
};

/// Descriptor for `LogRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logRequestDescriptor = $convert.base64Decode(
    'CgpMb2dSZXF1ZXN0EiMKDXdvcmt0cmVlX3BhdGgYASABKAlSDHdvcmt0cmVlUGF0aBIUCgVsaW'
    '1pdBgCIAEoDVIFbGltaXQ=');

@$core.Deprecated('Use commitDescriptor instead')
const Commit$json = {
  '1': 'Commit',
  '2': [
    {'1': 'sha', '3': 1, '4': 1, '5': 9, '10': 'sha'},
    {'1': 'short_sha', '3': 2, '4': 1, '5': 9, '10': 'shortSha'},
    {'1': 'subject', '3': 3, '4': 1, '5': 9, '10': 'subject'},
    {'1': 'author', '3': 4, '4': 1, '5': 9, '10': 'author'},
    {'1': 'time_unix', '3': 5, '4': 1, '5': 4, '10': 'timeUnix'},
  ],
};

/// Descriptor for `Commit`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commitDescriptor = $convert.base64Decode(
    'CgZDb21taXQSEAoDc2hhGAEgASgJUgNzaGESGwoJc2hvcnRfc2hhGAIgASgJUghzaG9ydFNoYR'
    'IYCgdzdWJqZWN0GAMgASgJUgdzdWJqZWN0EhYKBmF1dGhvchgEIAEoCVIGYXV0aG9yEhsKCXRp'
    'bWVfdW5peBgFIAEoBFIIdGltZVVuaXg=');

@$core.Deprecated('Use logResponseDescriptor instead')
const LogResponse$json = {
  '1': 'LogResponse',
  '2': [
    {
      '1': 'commits',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.Commit',
      '10': 'commits'
    },
  ],
};

/// Descriptor for `LogResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logResponseDescriptor = $convert.base64Decode(
    'CgtMb2dSZXNwb25zZRIpCgdjb21taXRzGAEgAygLMg8ua3Vtby52MS5Db21taXRSB2NvbW1pdH'
    'M=');

@$core.Deprecated('Use agentProviderDescriptor instead')
const AgentProvider$json = {
  '1': 'AgentProvider',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'short', '3': 3, '4': 1, '5': 9, '10': 'short'},
    {'1': 'program', '3': 4, '4': 1, '5': 9, '10': 'program'},
    {'1': 'args', '3': 5, '4': 1, '5': 9, '10': 'args'},
    {'1': 'custom', '3': 6, '4': 1, '5': 8, '10': 'custom'},
    {'1': 'enabled', '3': 7, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'is_default', '3': 8, '4': 1, '5': 8, '10': 'isDefault'},
    {'1': 'installed', '3': 9, '4': 1, '5': 8, '10': 'installed'},
    {'1': 'resolved_path', '3': 10, '4': 1, '5': 9, '10': 'resolvedPath'},
    {'1': 'install_hint', '3': 11, '4': 1, '5': 9, '10': 'installHint'},
    {
      '1': 'takes_prompt_argument',
      '3': 12,
      '4': 1,
      '5': 8,
      '10': 'takesPromptArgument'
    },
    {'1': 'has_login', '3': 13, '4': 1, '5': 8, '10': 'hasLogin'},
  ],
};

/// Descriptor for `AgentProvider`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentProviderDescriptor = $convert.base64Decode(
    'Cg1BZ2VudFByb3ZpZGVyEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEhQKBX'
    'Nob3J0GAMgASgJUgVzaG9ydBIYCgdwcm9ncmFtGAQgASgJUgdwcm9ncmFtEhIKBGFyZ3MYBSAB'
    'KAlSBGFyZ3MSFgoGY3VzdG9tGAYgASgIUgZjdXN0b20SGAoHZW5hYmxlZBgHIAEoCFIHZW5hYm'
    'xlZBIdCgppc19kZWZhdWx0GAggASgIUglpc0RlZmF1bHQSHAoJaW5zdGFsbGVkGAkgASgIUglp'
    'bnN0YWxsZWQSIwoNcmVzb2x2ZWRfcGF0aBgKIAEoCVIMcmVzb2x2ZWRQYXRoEiEKDGluc3RhbG'
    'xfaGludBgLIAEoCVILaW5zdGFsbEhpbnQSMgoVdGFrZXNfcHJvbXB0X2FyZ3VtZW50GAwgASgI'
    'UhN0YWtlc1Byb21wdEFyZ3VtZW50EhsKCWhhc19sb2dpbhgNIAEoCFIIaGFzTG9naW4=');

@$core.Deprecated('Use listProvidersRequestDescriptor instead')
const ListProvidersRequest$json = {
  '1': 'ListProvidersRequest',
};

/// Descriptor for `ListProvidersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listProvidersRequestDescriptor =
    $convert.base64Decode('ChRMaXN0UHJvdmlkZXJzUmVxdWVzdA==');

@$core.Deprecated('Use listProvidersResponseDescriptor instead')
const ListProvidersResponse$json = {
  '1': 'ListProvidersResponse',
  '2': [
    {
      '1': 'providers',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.AgentProvider',
      '10': 'providers'
    },
  ],
};

/// Descriptor for `ListProvidersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listProvidersResponseDescriptor = $convert.base64Decode(
    'ChVMaXN0UHJvdmlkZXJzUmVzcG9uc2USNAoJcHJvdmlkZXJzGAEgAygLMhYua3Vtby52MS5BZ2'
    'VudFByb3ZpZGVyUglwcm92aWRlcnM=');

@$core.Deprecated('Use saveProviderRequestDescriptor instead')
const SaveProviderRequest$json = {
  '1': 'SaveProviderRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'program', '3': 3, '4': 1, '5': 9, '10': 'program'},
    {'1': 'args', '3': 4, '4': 1, '5': 9, '10': 'args'},
    {'1': 'enabled', '3': 5, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'is_default', '3': 6, '4': 1, '5': 8, '10': 'isDefault'},
  ],
};

/// Descriptor for `SaveProviderRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveProviderRequestDescriptor = $convert.base64Decode(
    'ChNTYXZlUHJvdmlkZXJSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW'
    '1lEhgKB3Byb2dyYW0YAyABKAlSB3Byb2dyYW0SEgoEYXJncxgEIAEoCVIEYXJncxIYCgdlbmFi'
    'bGVkGAUgASgIUgdlbmFibGVkEh0KCmlzX2RlZmF1bHQYBiABKAhSCWlzRGVmYXVsdA==');

@$core.Deprecated('Use deleteProviderRequestDescriptor instead')
const DeleteProviderRequest$json = {
  '1': 'DeleteProviderRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteProviderRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteProviderRequestDescriptor = $convert
    .base64Decode('ChVEZWxldGVQcm92aWRlclJlcXVlc3QSDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use deleteProviderResponseDescriptor instead')
const DeleteProviderResponse$json = {
  '1': 'DeleteProviderResponse',
};

/// Descriptor for `DeleteProviderResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteProviderResponseDescriptor =
    $convert.base64Decode('ChZEZWxldGVQcm92aWRlclJlc3BvbnNl');

@$core.Deprecated('Use testProviderRequestDescriptor instead')
const TestProviderRequest$json = {
  '1': 'TestProviderRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `TestProviderRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testProviderRequestDescriptor = $convert
    .base64Decode('ChNUZXN0UHJvdmlkZXJSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use testProviderResponseDescriptor instead')
const TestProviderResponse$json = {
  '1': 'TestProviderResponse',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 9, '10': 'version'},
  ],
};

/// Descriptor for `TestProviderResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testProviderResponseDescriptor =
    $convert.base64Decode(
        'ChRUZXN0UHJvdmlkZXJSZXNwb25zZRIYCgd2ZXJzaW9uGAEgASgJUgd2ZXJzaW9u');

@$core.Deprecated('Use loginProviderRequestDescriptor instead')
const LoginProviderRequest$json = {
  '1': 'LoginProviderRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `LoginProviderRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginProviderRequestDescriptor = $convert
    .base64Decode('ChRMb2dpblByb3ZpZGVyUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use loginProviderResponseDescriptor instead')
const LoginProviderResponse$json = {
  '1': 'LoginProviderResponse',
  '2': [
    {'1': 'terminal_id', '3': 1, '4': 1, '5': 9, '10': 'terminalId'},
  ],
};

/// Descriptor for `LoginProviderResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginProviderResponseDescriptor = $convert.base64Decode(
    'ChVMb2dpblByb3ZpZGVyUmVzcG9uc2USHwoLdGVybWluYWxfaWQYASABKAlSCnRlcm1pbmFsSW'
    'Q=');

@$core.Deprecated('Use startAgentRequestDescriptor instead')
const StartAgentRequest$json = {
  '1': 'StartAgentRequest',
  '2': [
    {'1': 'provider_id', '3': 1, '4': 1, '5': 9, '10': 'providerId'},
    {'1': 'worktree_path', '3': 2, '4': 1, '5': 9, '10': 'worktreePath'},
    {'1': 'prompt', '3': 3, '4': 1, '5': 9, '10': 'prompt'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {'1': 'cols', '3': 5, '4': 1, '5': 13, '10': 'cols'},
    {'1': 'rows', '3': 6, '4': 1, '5': 13, '10': 'rows'},
  ],
};

/// Descriptor for `StartAgentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startAgentRequestDescriptor = $convert.base64Decode(
    'ChFTdGFydEFnZW50UmVxdWVzdBIfCgtwcm92aWRlcl9pZBgBIAEoCVIKcHJvdmlkZXJJZBIjCg'
    '13b3JrdHJlZV9wYXRoGAIgASgJUgx3b3JrdHJlZVBhdGgSFgoGcHJvbXB0GAMgASgJUgZwcm9t'
    'cHQSFAoFdGl0bGUYBCABKAlSBXRpdGxlEhIKBGNvbHMYBSABKA1SBGNvbHMSEgoEcm93cxgGIA'
    'EoDVIEcm93cw==');

@$core.Deprecated('Use agentSessionDescriptor instead')
const AgentSession$json = {
  '1': 'AgentSession',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'provider_id', '3': 2, '4': 1, '5': 9, '10': 'providerId'},
    {'1': 'provider_name', '3': 3, '4': 1, '5': 9, '10': 'providerName'},
    {'1': 'short', '3': 4, '4': 1, '5': 9, '10': 'short'},
    {'1': 'worktree_path', '3': 5, '4': 1, '5': 9, '10': 'worktreePath'},
    {'1': 'terminal_id', '3': 6, '4': 1, '5': 9, '10': 'terminalId'},
    {'1': 'title', '3': 7, '4': 1, '5': 9, '10': 'title'},
    {'1': 'prompt', '3': 8, '4': 1, '5': 9, '10': 'prompt'},
    {
      '1': 'state',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.AgentState',
      '10': 'state'
    },
    {'1': 'exit_code', '3': 10, '4': 1, '5': 5, '10': 'exitCode'},
    {'1': 'started_unix_ms', '3': 11, '4': 1, '5': 4, '10': 'startedUnixMs'},
    {
      '1': 'state_since_unix_ms',
      '3': 12,
      '4': 1,
      '5': 4,
      '10': 'stateSinceUnixMs'
    },
    {'1': 'last_line', '3': 13, '4': 1, '5': 9, '10': 'lastLine'},
  ],
};

/// Descriptor for `AgentSession`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentSessionDescriptor = $convert.base64Decode(
    'CgxBZ2VudFNlc3Npb24SDgoCaWQYASABKAlSAmlkEh8KC3Byb3ZpZGVyX2lkGAIgASgJUgpwcm'
    '92aWRlcklkEiMKDXByb3ZpZGVyX25hbWUYAyABKAlSDHByb3ZpZGVyTmFtZRIUCgVzaG9ydBgE'
    'IAEoCVIFc2hvcnQSIwoNd29ya3RyZWVfcGF0aBgFIAEoCVIMd29ya3RyZWVQYXRoEh8KC3Rlcm'
    '1pbmFsX2lkGAYgASgJUgp0ZXJtaW5hbElkEhQKBXRpdGxlGAcgASgJUgV0aXRsZRIWCgZwcm9t'
    'cHQYCCABKAlSBnByb21wdBIpCgVzdGF0ZRgJIAEoDjITLmt1bW8udjEuQWdlbnRTdGF0ZVIFc3'
    'RhdGUSGwoJZXhpdF9jb2RlGAogASgFUghleGl0Q29kZRImCg9zdGFydGVkX3VuaXhfbXMYCyAB'
    'KARSDXN0YXJ0ZWRVbml4TXMSLQoTc3RhdGVfc2luY2VfdW5peF9tcxgMIAEoBFIQc3RhdGVTaW'
    '5jZVVuaXhNcxIbCglsYXN0X2xpbmUYDSABKAlSCGxhc3RMaW5l');

@$core.Deprecated('Use stopAgentRequestDescriptor instead')
const StopAgentRequest$json = {
  '1': 'StopAgentRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `StopAgentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopAgentRequestDescriptor =
    $convert.base64Decode('ChBTdG9wQWdlbnRSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use stopAgentResponseDescriptor instead')
const StopAgentResponse$json = {
  '1': 'StopAgentResponse',
};

/// Descriptor for `StopAgentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopAgentResponseDescriptor =
    $convert.base64Decode('ChFTdG9wQWdlbnRSZXNwb25zZQ==');

@$core.Deprecated('Use dismissAgentRequestDescriptor instead')
const DismissAgentRequest$json = {
  '1': 'DismissAgentRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DismissAgentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dismissAgentRequestDescriptor = $convert
    .base64Decode('ChNEaXNtaXNzQWdlbnRSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use dismissAgentResponseDescriptor instead')
const DismissAgentResponse$json = {
  '1': 'DismissAgentResponse',
};

/// Descriptor for `DismissAgentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dismissAgentResponseDescriptor =
    $convert.base64Decode('ChREaXNtaXNzQWdlbnRSZXNwb25zZQ==');

@$core.Deprecated('Use watchAgentsRequestDescriptor instead')
const WatchAgentsRequest$json = {
  '1': 'WatchAgentsRequest',
};

/// Descriptor for `WatchAgentsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchAgentsRequestDescriptor =
    $convert.base64Decode('ChJXYXRjaEFnZW50c1JlcXVlc3Q=');

@$core.Deprecated('Use agentsSnapshotDescriptor instead')
const AgentsSnapshot$json = {
  '1': 'AgentsSnapshot',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 4, '10': 'version'},
    {
      '1': 'sessions',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.AgentSession',
      '10': 'sessions'
    },
  ],
};

/// Descriptor for `AgentsSnapshot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentsSnapshotDescriptor = $convert.base64Decode(
    'Cg5BZ2VudHNTbmFwc2hvdBIYCgd2ZXJzaW9uGAEgASgEUgd2ZXJzaW9uEjEKCHNlc3Npb25zGA'
    'IgAygLMhUua3Vtby52MS5BZ2VudFNlc3Npb25SCHNlc3Npb25z');

@$core.Deprecated('Use taskSourceDescriptor instead')
const TaskSource$json = {
  '1': 'TaskSource',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'kind',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.TaskSourceKind',
      '10': 'kind'
    },
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'options',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.TaskSource.OptionsEntry',
      '10': 'options'
    },
    {'1': 'enabled', '3': 5, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'badge', '3': 6, '4': 1, '5': 9, '10': 'badge'},
    {'1': 'needs_secret', '3': 7, '4': 1, '5': 8, '10': 'needsSecret'},
    {'1': 'has_secret', '3': 8, '4': 1, '5': 8, '10': 'hasSecret'},
    {
      '1': 'writable',
      '3': 9,
      '4': 3,
      '5': 14,
      '6': '.kumo.v1.TaskStatus',
      '10': 'writable'
    },
    {'1': 'syncing', '3': 10, '4': 1, '5': 8, '10': 'syncing'},
    {
      '1': 'last_synced_unix_ms',
      '3': 11,
      '4': 1,
      '5': 4,
      '10': 'lastSyncedUnixMs'
    },
    {'1': 'error', '3': 12, '4': 1, '5': 9, '10': 'error'},
    {'1': 'task_count', '3': 13, '4': 1, '5': 13, '10': 'taskCount'},
  ],
  '3': [TaskSource_OptionsEntry$json],
};

@$core.Deprecated('Use taskSourceDescriptor instead')
const TaskSource_OptionsEntry$json = {
  '1': 'OptionsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `TaskSource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List taskSourceDescriptor = $convert.base64Decode(
    'CgpUYXNrU291cmNlEg4KAmlkGAEgASgJUgJpZBIrCgRraW5kGAIgASgOMhcua3Vtby52MS5UYX'
    'NrU291cmNlS2luZFIEa2luZBISCgRuYW1lGAMgASgJUgRuYW1lEjoKB29wdGlvbnMYBCADKAsy'
    'IC5rdW1vLnYxLlRhc2tTb3VyY2UuT3B0aW9uc0VudHJ5UgdvcHRpb25zEhgKB2VuYWJsZWQYBS'
    'ABKAhSB2VuYWJsZWQSFAoFYmFkZ2UYBiABKAlSBWJhZGdlEiEKDG5lZWRzX3NlY3JldBgHIAEo'
    'CFILbmVlZHNTZWNyZXQSHQoKaGFzX3NlY3JldBgIIAEoCFIJaGFzU2VjcmV0Ei8KCHdyaXRhYm'
    'xlGAkgAygOMhMua3Vtby52MS5UYXNrU3RhdHVzUgh3cml0YWJsZRIYCgdzeW5jaW5nGAogASgI'
    'UgdzeW5jaW5nEi0KE2xhc3Rfc3luY2VkX3VuaXhfbXMYCyABKARSEGxhc3RTeW5jZWRVbml4TX'
    'MSFAoFZXJyb3IYDCABKAlSBWVycm9yEh0KCnRhc2tfY291bnQYDSABKA1SCXRhc2tDb3VudBo6'
    'CgxPcHRpb25zRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOg'
    'I4AQ==');

@$core.Deprecated('Use taskDescriptor instead')
const Task$json = {
  '1': 'Task',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'source_id', '3': 2, '4': 1, '5': 9, '10': 'sourceId'},
    {'1': 'key', '3': 3, '4': 1, '5': 9, '10': 'key'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {
      '1': 'status',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.TaskStatus',
      '10': 'status'
    },
    {
      '1': 'priority',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.TaskPriority',
      '10': 'priority'
    },
    {'1': 'due', '3': 7, '4': 1, '5': 9, '10': 'due'},
    {'1': 'url', '3': 8, '4': 1, '5': 9, '10': 'url'},
    {'1': 'context', '3': 9, '4': 1, '5': 9, '10': 'context'},
    {'1': 'labels', '3': 10, '4': 3, '5': 9, '10': 'labels'},
    {'1': 'updated_unix_ms', '3': 11, '4': 1, '5': 4, '10': 'updatedUnixMs'},
    {'1': 'suggested_branch', '3': 12, '4': 1, '5': 9, '10': 'suggestedBranch'},
  ],
};

/// Descriptor for `Task`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List taskDescriptor = $convert.base64Decode(
    'CgRUYXNrEg4KAmlkGAEgASgJUgJpZBIbCglzb3VyY2VfaWQYAiABKAlSCHNvdXJjZUlkEhAKA2'
    'tleRgDIAEoCVIDa2V5EhQKBXRpdGxlGAQgASgJUgV0aXRsZRIrCgZzdGF0dXMYBSABKA4yEy5r'
    'dW1vLnYxLlRhc2tTdGF0dXNSBnN0YXR1cxIxCghwcmlvcml0eRgGIAEoDjIVLmt1bW8udjEuVG'
    'Fza1ByaW9yaXR5Ughwcmlvcml0eRIQCgNkdWUYByABKAlSA2R1ZRIQCgN1cmwYCCABKAlSA3Vy'
    'bBIYCgdjb250ZXh0GAkgASgJUgdjb250ZXh0EhYKBmxhYmVscxgKIAMoCVIGbGFiZWxzEiYKD3'
    'VwZGF0ZWRfdW5peF9tcxgLIAEoBFINdXBkYXRlZFVuaXhNcxIpChBzdWdnZXN0ZWRfYnJhbmNo'
    'GAwgASgJUg9zdWdnZXN0ZWRCcmFuY2g=');

@$core.Deprecated('Use sourceTasksDescriptor instead')
const SourceTasks$json = {
  '1': 'SourceTasks',
  '2': [
    {'1': 'source_id', '3': 1, '4': 1, '5': 9, '10': 'sourceId'},
    {'1': 'version', '3': 2, '4': 1, '5': 4, '10': 'version'},
    {
      '1': 'tasks',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.Task',
      '10': 'tasks'
    },
  ],
};

/// Descriptor for `SourceTasks`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sourceTasksDescriptor = $convert.base64Decode(
    'CgtTb3VyY2VUYXNrcxIbCglzb3VyY2VfaWQYASABKAlSCHNvdXJjZUlkEhgKB3ZlcnNpb24YAi'
    'ABKARSB3ZlcnNpb24SIwoFdGFza3MYAyADKAsyDS5rdW1vLnYxLlRhc2tSBXRhc2tz');

@$core.Deprecated('Use taskLinkDescriptor instead')
const TaskLink$json = {
  '1': 'TaskLink',
  '2': [
    {'1': 'task_id', '3': 1, '4': 1, '5': 9, '10': 'taskId'},
    {'1': 'worktree_path', '3': 2, '4': 1, '5': 9, '10': 'worktreePath'},
    {'1': 'branch', '3': 3, '4': 1, '5': 9, '10': 'branch'},
    {'1': 'created_unix_ms', '3': 4, '4': 1, '5': 4, '10': 'createdUnixMs'},
  ],
};

/// Descriptor for `TaskLink`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List taskLinkDescriptor = $convert.base64Decode(
    'CghUYXNrTGluaxIXCgd0YXNrX2lkGAEgASgJUgZ0YXNrSWQSIwoNd29ya3RyZWVfcGF0aBgCIA'
    'EoCVIMd29ya3RyZWVQYXRoEhYKBmJyYW5jaBgDIAEoCVIGYnJhbmNoEiYKD2NyZWF0ZWRfdW5p'
    'eF9tcxgEIAEoBFINY3JlYXRlZFVuaXhNcw==');

@$core.Deprecated('Use watchTasksRequestDescriptor instead')
const WatchTasksRequest$json = {
  '1': 'WatchTasksRequest',
};

/// Descriptor for `WatchTasksRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchTasksRequestDescriptor =
    $convert.base64Decode('ChFXYXRjaFRhc2tzUmVxdWVzdA==');

@$core.Deprecated('Use tasksUpdateDescriptor instead')
const TasksUpdate$json = {
  '1': 'TasksUpdate',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 4, '10': 'version'},
    {
      '1': 'sources',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.TaskSource',
      '10': 'sources'
    },
    {
      '1': 'changed',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.SourceTasks',
      '10': 'changed'
    },
    {
      '1': 'links',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.TaskLink',
      '10': 'links'
    },
  ],
};

/// Descriptor for `TasksUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tasksUpdateDescriptor = $convert.base64Decode(
    'CgtUYXNrc1VwZGF0ZRIYCgd2ZXJzaW9uGAEgASgEUgd2ZXJzaW9uEi0KB3NvdXJjZXMYAiADKA'
    'syEy5rdW1vLnYxLlRhc2tTb3VyY2VSB3NvdXJjZXMSLgoHY2hhbmdlZBgDIAMoCzIULmt1bW8u'
    'djEuU291cmNlVGFza3NSB2NoYW5nZWQSJwoFbGlua3MYBCADKAsyES5rdW1vLnYxLlRhc2tMaW'
    '5rUgVsaW5rcw==');

@$core.Deprecated('Use detectSourcesRequestDescriptor instead')
const DetectSourcesRequest$json = {
  '1': 'DetectSourcesRequest',
};

/// Descriptor for `DetectSourcesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List detectSourcesRequestDescriptor =
    $convert.base64Decode('ChREZXRlY3RTb3VyY2VzUmVxdWVzdA==');

@$core.Deprecated('Use detectedSourceDescriptor instead')
const DetectedSource$json = {
  '1': 'DetectedSource',
  '2': [
    {
      '1': 'kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.TaskSourceKind',
      '10': 'kind'
    },
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'options',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.DetectedSource.OptionsEntry',
      '10': 'options'
    },
  ],
  '3': [DetectedSource_OptionsEntry$json],
};

@$core.Deprecated('Use detectedSourceDescriptor instead')
const DetectedSource_OptionsEntry$json = {
  '1': 'OptionsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `DetectedSource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List detectedSourceDescriptor = $convert.base64Decode(
    'Cg5EZXRlY3RlZFNvdXJjZRIrCgRraW5kGAEgASgOMhcua3Vtby52MS5UYXNrU291cmNlS2luZF'
    'IEa2luZBISCgRuYW1lGAIgASgJUgRuYW1lEj4KB29wdGlvbnMYAyADKAsyJC5rdW1vLnYxLkRl'
    'dGVjdGVkU291cmNlLk9wdGlvbnNFbnRyeVIHb3B0aW9ucxo6CgxPcHRpb25zRW50cnkSEAoDa2'
    'V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use detectSourcesResponseDescriptor instead')
const DetectSourcesResponse$json = {
  '1': 'DetectSourcesResponse',
  '2': [
    {
      '1': 'sources',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.DetectedSource',
      '10': 'sources'
    },
  ],
};

/// Descriptor for `DetectSourcesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List detectSourcesResponseDescriptor = $convert.base64Decode(
    'ChVEZXRlY3RTb3VyY2VzUmVzcG9uc2USMQoHc291cmNlcxgBIAMoCzIXLmt1bW8udjEuRGV0ZW'
    'N0ZWRTb3VyY2VSB3NvdXJjZXM=');

@$core.Deprecated('Use testSourceRequestDescriptor instead')
const TestSourceRequest$json = {
  '1': 'TestSourceRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'kind',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.TaskSourceKind',
      '10': 'kind'
    },
    {
      '1': 'options',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.TestSourceRequest.OptionsEntry',
      '10': 'options'
    },
    {'1': 'secret', '3': 4, '4': 1, '5': 9, '10': 'secret'},
  ],
  '3': [TestSourceRequest_OptionsEntry$json],
};

@$core.Deprecated('Use testSourceRequestDescriptor instead')
const TestSourceRequest_OptionsEntry$json = {
  '1': 'OptionsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `TestSourceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testSourceRequestDescriptor = $convert.base64Decode(
    'ChFUZXN0U291cmNlUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQSKwoEa2luZBgCIAEoDjIXLmt1bW'
    '8udjEuVGFza1NvdXJjZUtpbmRSBGtpbmQSQQoHb3B0aW9ucxgDIAMoCzInLmt1bW8udjEuVGVz'
    'dFNvdXJjZVJlcXVlc3QuT3B0aW9uc0VudHJ5UgdvcHRpb25zEhYKBnNlY3JldBgEIAEoCVIGc2'
    'VjcmV0GjoKDE9wdGlvbnNFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIF'
    'dmFsdWU6AjgB');

@$core.Deprecated('Use testSourceResponseDescriptor instead')
const TestSourceResponse$json = {
  '1': 'TestSourceResponse',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `TestSourceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testSourceResponseDescriptor =
    $convert.base64Decode(
        'ChJUZXN0U291cmNlUmVzcG9uc2USGAoHbWVzc2FnZRgBIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use saveSourceRequestDescriptor instead')
const SaveSourceRequest$json = {
  '1': 'SaveSourceRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'kind',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.TaskSourceKind',
      '10': 'kind'
    },
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'options',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.SaveSourceRequest.OptionsEntry',
      '10': 'options'
    },
    {'1': 'enabled', '3': 5, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'secret', '3': 6, '4': 1, '5': 9, '10': 'secret'},
  ],
  '3': [SaveSourceRequest_OptionsEntry$json],
};

@$core.Deprecated('Use saveSourceRequestDescriptor instead')
const SaveSourceRequest_OptionsEntry$json = {
  '1': 'OptionsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `SaveSourceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveSourceRequestDescriptor = $convert.base64Decode(
    'ChFTYXZlU291cmNlUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQSKwoEa2luZBgCIAEoDjIXLmt1bW'
    '8udjEuVGFza1NvdXJjZUtpbmRSBGtpbmQSEgoEbmFtZRgDIAEoCVIEbmFtZRJBCgdvcHRpb25z'
    'GAQgAygLMicua3Vtby52MS5TYXZlU291cmNlUmVxdWVzdC5PcHRpb25zRW50cnlSB29wdGlvbn'
    'MSGAoHZW5hYmxlZBgFIAEoCFIHZW5hYmxlZBIWCgZzZWNyZXQYBiABKAlSBnNlY3JldBo6CgxP'
    'cHRpb25zRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ'
    '==');

@$core.Deprecated('Use deleteSourceRequestDescriptor instead')
const DeleteSourceRequest$json = {
  '1': 'DeleteSourceRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteSourceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteSourceRequestDescriptor = $convert
    .base64Decode('ChNEZWxldGVTb3VyY2VSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use deleteSourceResponseDescriptor instead')
const DeleteSourceResponse$json = {
  '1': 'DeleteSourceResponse',
};

/// Descriptor for `DeleteSourceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteSourceResponseDescriptor =
    $convert.base64Decode('ChREZWxldGVTb3VyY2VSZXNwb25zZQ==');

@$core.Deprecated('Use syncTasksRequestDescriptor instead')
const SyncTasksRequest$json = {
  '1': 'SyncTasksRequest',
  '2': [
    {'1': 'source_id', '3': 1, '4': 1, '5': 9, '10': 'sourceId'},
  ],
};

/// Descriptor for `SyncTasksRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncTasksRequestDescriptor = $convert.base64Decode(
    'ChBTeW5jVGFza3NSZXF1ZXN0EhsKCXNvdXJjZV9pZBgBIAEoCVIIc291cmNlSWQ=');

@$core.Deprecated('Use syncTasksResponseDescriptor instead')
const SyncTasksResponse$json = {
  '1': 'SyncTasksResponse',
};

/// Descriptor for `SyncTasksResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncTasksResponseDescriptor =
    $convert.base64Decode('ChFTeW5jVGFza3NSZXNwb25zZQ==');

@$core.Deprecated('Use setTaskStatusRequestDescriptor instead')
const SetTaskStatusRequest$json = {
  '1': 'SetTaskStatusRequest',
  '2': [
    {'1': 'task_id', '3': 1, '4': 1, '5': 9, '10': 'taskId'},
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.TaskStatus',
      '10': 'status'
    },
  ],
};

/// Descriptor for `SetTaskStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setTaskStatusRequestDescriptor = $convert.base64Decode(
    'ChRTZXRUYXNrU3RhdHVzUmVxdWVzdBIXCgd0YXNrX2lkGAEgASgJUgZ0YXNrSWQSKwoGc3RhdH'
    'VzGAIgASgOMhMua3Vtby52MS5UYXNrU3RhdHVzUgZzdGF0dXM=');

@$core.Deprecated('Use linkTaskRequestDescriptor instead')
const LinkTaskRequest$json = {
  '1': 'LinkTaskRequest',
  '2': [
    {'1': 'task_id', '3': 1, '4': 1, '5': 9, '10': 'taskId'},
    {'1': 'worktree_path', '3': 2, '4': 1, '5': 9, '10': 'worktreePath'},
    {'1': 'branch', '3': 3, '4': 1, '5': 9, '10': 'branch'},
  ],
};

/// Descriptor for `LinkTaskRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List linkTaskRequestDescriptor = $convert.base64Decode(
    'Cg9MaW5rVGFza1JlcXVlc3QSFwoHdGFza19pZBgBIAEoCVIGdGFza0lkEiMKDXdvcmt0cmVlX3'
    'BhdGgYAiABKAlSDHdvcmt0cmVlUGF0aBIWCgZicmFuY2gYAyABKAlSBmJyYW5jaA==');

@$core.Deprecated('Use unlinkTaskRequestDescriptor instead')
const UnlinkTaskRequest$json = {
  '1': 'UnlinkTaskRequest',
  '2': [
    {'1': 'task_id', '3': 1, '4': 1, '5': 9, '10': 'taskId'},
    {'1': 'worktree_path', '3': 2, '4': 1, '5': 9, '10': 'worktreePath'},
  ],
};

/// Descriptor for `UnlinkTaskRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unlinkTaskRequestDescriptor = $convert.base64Decode(
    'ChFVbmxpbmtUYXNrUmVxdWVzdBIXCgd0YXNrX2lkGAEgASgJUgZ0YXNrSWQSIwoNd29ya3RyZW'
    'VfcGF0aBgCIAEoCVIMd29ya3RyZWVQYXRo');

@$core.Deprecated('Use unlinkTaskResponseDescriptor instead')
const UnlinkTaskResponse$json = {
  '1': 'UnlinkTaskResponse',
};

/// Descriptor for `UnlinkTaskResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unlinkTaskResponseDescriptor =
    $convert.base64Decode('ChJVbmxpbmtUYXNrUmVzcG9uc2U=');

@$core.Deprecated('Use watchPipelinesRequestDescriptor instead')
const WatchPipelinesRequest$json = {
  '1': 'WatchPipelinesRequest',
  '2': [
    {'1': 'worktree_path', '3': 1, '4': 1, '5': 9, '10': 'worktreePath'},
  ],
};

/// Descriptor for `WatchPipelinesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchPipelinesRequestDescriptor = $convert.base64Decode(
    'ChVXYXRjaFBpcGVsaW5lc1JlcXVlc3QSIwoNd29ya3RyZWVfcGF0aBgBIAEoCVIMd29ya3RyZW'
    'VQYXRo');

@$core.Deprecated('Use pipelinesSnapshotDescriptor instead')
const PipelinesSnapshot$json = {
  '1': 'PipelinesSnapshot',
  '2': [
    {
      '1': 'provider',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.CiProvider',
      '10': 'provider'
    },
    {'1': 'repo', '3': 2, '4': 1, '5': 9, '10': 'repo'},
    {'1': 'branch', '3': 3, '4': 1, '5': 9, '10': 'branch'},
    {
      '1': 'latest',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.kumo.v1.CiRun',
      '9': 0,
      '10': 'latest',
      '17': true
    },
    {
      '1': 'problem',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.kumo.v1.CiProblem',
      '9': 1,
      '10': 'problem',
      '17': true
    },
    {'1': 'checked_at', '3': 6, '4': 1, '5': 3, '10': 'checkedAt'},
  ],
  '8': [
    {'1': '_latest'},
    {'1': '_problem'},
  ],
};

/// Descriptor for `PipelinesSnapshot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pipelinesSnapshotDescriptor = $convert.base64Decode(
    'ChFQaXBlbGluZXNTbmFwc2hvdBIvCghwcm92aWRlchgBIAEoDjITLmt1bW8udjEuQ2lQcm92aW'
    'RlclIIcHJvdmlkZXISEgoEcmVwbxgCIAEoCVIEcmVwbxIWCgZicmFuY2gYAyABKAlSBmJyYW5j'
    'aBIrCgZsYXRlc3QYBCABKAsyDi5rdW1vLnYxLkNpUnVuSABSBmxhdGVzdIgBARIxCgdwcm9ibG'
    'VtGAUgASgLMhIua3Vtby52MS5DaVByb2JsZW1IAVIHcHJvYmxlbYgBARIdCgpjaGVja2VkX2F0'
    'GAYgASgDUgljaGVja2VkQXRCCQoHX2xhdGVzdEIKCghfcHJvYmxlbQ==');

@$core.Deprecated('Use ciRunDescriptor instead')
const CiRun$json = {
  '1': 'CiRun',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
    {'1': 'short_sha', '3': 3, '4': 1, '5': 9, '10': 'shortSha'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {
      '1': 'state',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.CiState',
      '10': 'state'
    },
    {'1': 'created_at', '3': 6, '4': 1, '5': 3, '10': 'createdAt'},
    {'1': 'finished_at', '3': 7, '4': 1, '5': 3, '10': 'finishedAt'},
    {'1': 'url', '3': 8, '4': 1, '5': 9, '10': 'url'},
    {'1': 'jobs', '3': 9, '4': 3, '5': 11, '6': '.kumo.v1.CiJob', '10': 'jobs'},
  ],
};

/// Descriptor for `CiRun`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ciRunDescriptor = $convert.base64Decode(
    'CgVDaVJ1bhIOCgJpZBgBIAEoCVICaWQSFAoFbGFiZWwYAiABKAlSBWxhYmVsEhsKCXNob3J0X3'
    'NoYRgDIAEoCVIIc2hvcnRTaGESFAoFdGl0bGUYBCABKAlSBXRpdGxlEiYKBXN0YXRlGAUgASgO'
    'MhAua3Vtby52MS5DaVN0YXRlUgVzdGF0ZRIdCgpjcmVhdGVkX2F0GAYgASgDUgljcmVhdGVkQX'
    'QSHwoLZmluaXNoZWRfYXQYByABKANSCmZpbmlzaGVkQXQSEAoDdXJsGAggASgJUgN1cmwSIgoE'
    'am9icxgJIAMoCzIOLmt1bW8udjEuQ2lKb2JSBGpvYnM=');

@$core.Deprecated('Use ciJobDescriptor instead')
const CiJob$json = {
  '1': 'CiJob',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'state',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.CiState',
      '10': 'state'
    },
    {'1': 'duration_ms', '3': 3, '4': 1, '5': 3, '10': 'durationMs'},
    {'1': 'started_at', '3': 4, '4': 1, '5': 3, '10': 'startedAt'},
    {'1': 'failure', '3': 5, '4': 1, '5': 9, '10': 'failure'},
    {'1': 'url', '3': 6, '4': 1, '5': 9, '10': 'url'},
  ],
};

/// Descriptor for `CiJob`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ciJobDescriptor = $convert.base64Decode(
    'CgVDaUpvYhISCgRuYW1lGAEgASgJUgRuYW1lEiYKBXN0YXRlGAIgASgOMhAua3Vtby52MS5DaV'
    'N0YXRlUgVzdGF0ZRIfCgtkdXJhdGlvbl9tcxgDIAEoA1IKZHVyYXRpb25NcxIdCgpzdGFydGVk'
    'X2F0GAQgASgDUglzdGFydGVkQXQSGAoHZmFpbHVyZRgFIAEoCVIHZmFpbHVyZRIQCgN1cmwYBi'
    'ABKAlSA3VybA==');

@$core.Deprecated('Use ciProblemDescriptor instead')
const CiProblem$json = {
  '1': 'CiProblem',
  '2': [
    {
      '1': 'kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.CiProblemKind',
      '10': 'kind'
    },
    {'1': 'detail', '3': 2, '4': 1, '5': 9, '10': 'detail'},
    {'1': 'missing_scope', '3': 3, '4': 1, '5': 9, '10': 'missingScope'},
    {'1': 'retry_at', '3': 4, '4': 1, '5': 3, '10': 'retryAt'},
    {'1': 'commits_waiting', '3': 5, '4': 1, '5': 13, '10': 'commitsWaiting'},
  ],
};

/// Descriptor for `CiProblem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ciProblemDescriptor = $convert.base64Decode(
    'CglDaVByb2JsZW0SKgoEa2luZBgBIAEoDjIWLmt1bW8udjEuQ2lQcm9ibGVtS2luZFIEa2luZB'
    'IWCgZkZXRhaWwYAiABKAlSBmRldGFpbBIjCg1taXNzaW5nX3Njb3BlGAMgASgJUgxtaXNzaW5n'
    'U2NvcGUSGQoIcmV0cnlfYXQYBCABKANSB3JldHJ5QXQSJwoPY29tbWl0c193YWl0aW5nGAUgAS'
    'gNUg5jb21taXRzV2FpdGluZw==');

@$core.Deprecated('Use rerunFailedRequestDescriptor instead')
const RerunFailedRequest$json = {
  '1': 'RerunFailedRequest',
  '2': [
    {'1': 'worktree_path', '3': 1, '4': 1, '5': 9, '10': 'worktreePath'},
    {'1': 'run_id', '3': 2, '4': 1, '5': 9, '10': 'runId'},
  ],
};

/// Descriptor for `RerunFailedRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rerunFailedRequestDescriptor = $convert.base64Decode(
    'ChJSZXJ1bkZhaWxlZFJlcXVlc3QSIwoNd29ya3RyZWVfcGF0aBgBIAEoCVIMd29ya3RyZWVQYX'
    'RoEhUKBnJ1bl9pZBgCIAEoCVIFcnVuSWQ=');

@$core.Deprecated('Use pipelinesActionResponseDescriptor instead')
const PipelinesActionResponse$json = {
  '1': 'PipelinesActionResponse',
};

/// Descriptor for `PipelinesActionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pipelinesActionResponseDescriptor =
    $convert.base64Decode('ChdQaXBlbGluZXNBY3Rpb25SZXNwb25zZQ==');

@$core.Deprecated('Use listHostsRequestDescriptor instead')
const ListHostsRequest$json = {
  '1': 'ListHostsRequest',
};

/// Descriptor for `ListHostsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listHostsRequestDescriptor =
    $convert.base64Decode('ChBMaXN0SG9zdHNSZXF1ZXN0');

@$core.Deprecated('Use listHostsResponseDescriptor instead')
const ListHostsResponse$json = {
  '1': 'ListHostsResponse',
  '2': [
    {
      '1': 'hosts',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.kumo.v1.CiHostInfo',
      '10': 'hosts'
    },
  ],
};

/// Descriptor for `ListHostsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listHostsResponseDescriptor = $convert.base64Decode(
    'ChFMaXN0SG9zdHNSZXNwb25zZRIpCgVob3N0cxgBIAMoCzITLmt1bW8udjEuQ2lIb3N0SW5mb1'
    'IFaG9zdHM=');

@$core.Deprecated('Use ciHostInfoDescriptor instead')
const CiHostInfo$json = {
  '1': 'CiHostInfo',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {
      '1': 'provider',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.kumo.v1.CiProvider',
      '10': 'provider'
    },
    {'1': 'has_token', '3': 3, '4': 1, '5': 8, '10': 'hasToken'},
    {'1': 'uses_gh', '3': 4, '4': 1, '5': 8, '10': 'usesGh'},
    {'1': 'repos', '3': 5, '4': 3, '5': 9, '10': 'repos'},
    {'1': 'gh_account', '3': 6, '4': 1, '5': 9, '10': 'ghAccount'},
    {'1': 'gh_available', '3': 7, '4': 1, '5': 8, '10': 'ghAvailable'},
  ],
};

/// Descriptor for `CiHostInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ciHostInfoDescriptor = $convert.base64Decode(
    'CgpDaUhvc3RJbmZvEhIKBGhvc3QYASABKAlSBGhvc3QSLwoIcHJvdmlkZXIYAiABKA4yEy5rdW'
    '1vLnYxLkNpUHJvdmlkZXJSCHByb3ZpZGVyEhsKCWhhc190b2tlbhgDIAEoCFIIaGFzVG9rZW4S'
    'FwoHdXNlc19naBgEIAEoCFIGdXNlc0doEhQKBXJlcG9zGAUgAygJUgVyZXBvcxIdCgpnaF9hY2'
    'NvdW50GAYgASgJUglnaEFjY291bnQSIQoMZ2hfYXZhaWxhYmxlGAcgASgIUgtnaEF2YWlsYWJs'
    'ZQ==');

@$core.Deprecated('Use signInWithGhRequestDescriptor instead')
const SignInWithGhRequest$json = {
  '1': 'SignInWithGhRequest',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
  ],
};

/// Descriptor for `SignInWithGhRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signInWithGhRequestDescriptor = $convert
    .base64Decode('ChNTaWduSW5XaXRoR2hSZXF1ZXN0EhIKBGhvc3QYASABKAlSBGhvc3Q=');

@$core.Deprecated('Use signInWithGhResponseDescriptor instead')
const SignInWithGhResponse$json = {
  '1': 'SignInWithGhResponse',
  '2': [
    {'1': 'terminal_id', '3': 1, '4': 1, '5': 9, '10': 'terminalId'},
  ],
};

/// Descriptor for `SignInWithGhResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signInWithGhResponseDescriptor = $convert.base64Decode(
    'ChRTaWduSW5XaXRoR2hSZXNwb25zZRIfCgt0ZXJtaW5hbF9pZBgBIAEoCVIKdGVybWluYWxJZA'
    '==');

@$core.Deprecated('Use saveHostTokenRequestDescriptor instead')
const SaveHostTokenRequest$json = {
  '1': 'SaveHostTokenRequest',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'token', '3': 2, '4': 1, '5': 9, '10': 'token'},
  ],
};

/// Descriptor for `SaveHostTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveHostTokenRequestDescriptor = $convert.base64Decode(
    'ChRTYXZlSG9zdFRva2VuUmVxdWVzdBISCgRob3N0GAEgASgJUgRob3N0EhQKBXRva2VuGAIgAS'
    'gJUgV0b2tlbg==');

@$core.Deprecated('Use testHostRequestDescriptor instead')
const TestHostRequest$json = {
  '1': 'TestHostRequest',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'token', '3': 2, '4': 1, '5': 9, '10': 'token'},
  ],
};

/// Descriptor for `TestHostRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testHostRequestDescriptor = $convert.base64Decode(
    'Cg9UZXN0SG9zdFJlcXVlc3QSEgoEaG9zdBgBIAEoCVIEaG9zdBIUCgV0b2tlbhgCIAEoCVIFdG'
    '9rZW4=');

@$core.Deprecated('Use testHostResponseDescriptor instead')
const TestHostResponse$json = {
  '1': 'TestHostResponse',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
    {
      '1': 'problem',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.kumo.v1.CiProblem',
      '9': 0,
      '10': 'problem',
      '17': true
    },
  ],
  '8': [
    {'1': '_problem'},
  ],
};

/// Descriptor for `TestHostResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testHostResponseDescriptor = $convert.base64Decode(
    'ChBUZXN0SG9zdFJlc3BvbnNlEhgKB21lc3NhZ2UYASABKAlSB21lc3NhZ2USMQoHcHJvYmxlbR'
    'gCIAEoCzISLmt1bW8udjEuQ2lQcm9ibGVtSABSB3Byb2JsZW2IAQFCCgoIX3Byb2JsZW0=');
