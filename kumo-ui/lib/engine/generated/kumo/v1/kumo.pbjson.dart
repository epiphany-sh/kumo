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
  ],
};

/// Descriptor for `TerminalInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List terminalInfoDescriptor = $convert.base64Decode(
    'CgxUZXJtaW5hbEluZm8SHwoLdGVybWluYWxfaWQYASABKAlSCnRlcm1pbmFsSWQSGAoHcHJvZ3'
    'JhbRgCIAEoCVIHcHJvZ3JhbRIWCgZleGl0ZWQYAyABKAhSBmV4aXRlZBIbCglleGl0X2NvZGUY'
    'BCABKAVSCGV4aXRDb2Rl');

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
