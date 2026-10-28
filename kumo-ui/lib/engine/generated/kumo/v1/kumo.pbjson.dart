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
