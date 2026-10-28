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

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
