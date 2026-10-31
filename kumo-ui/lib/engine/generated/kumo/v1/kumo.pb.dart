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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'kumo.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'kumo.pbenum.dart';

class HelloRequest extends $pb.GeneratedMessage {
  factory HelloRequest({
    $core.int? clientApiVersion,
    $core.String? clientName,
  }) {
    final result = HelloRequest._();
    if (clientApiVersion != null) result.clientApiVersion = clientApiVersion;
    if (clientName != null) result.clientName = clientName;
    return result;
  }

  HelloRequest._();

  factory HelloRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HelloRequest()..mergeFromBuffer(data, registry);
  factory HelloRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HelloRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HelloRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: HelloRequest.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'clientApiVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'clientName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HelloRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HelloRequest copyWith(void Function(HelloRequest) updates) =>
      super.copyWith((message) => updates(message as HelloRequest))
          as HelloRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use HelloRequest() / HelloRequest.new instead')
  static HelloRequest create() => HelloRequest._();
  static $pb.GeneratedMessage $_createMessage() => HelloRequest._();
  @$core.override
  HelloRequest createEmptyInstance() => HelloRequest._();
  @$core.pragma('dart2js:noInline')
  static HelloRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HelloRequest>(
          HelloRequest.$_createMessage);
  static HelloRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get clientApiVersion => $_getIZ(0);
  @$pb.TagNumber(1)
  set clientApiVersion($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClientApiVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearClientApiVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get clientName => $_getSZ(1);
  @$pb.TagNumber(2)
  set clientName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasClientName() => $_has(1);
  @$pb.TagNumber(2)
  void clearClientName() => $_clearField(2);
}

class HelloResponse extends $pb.GeneratedMessage {
  factory HelloResponse({
    $core.int? serverApiVersion,
    $core.String? serverVersion,
    $fixnum.Int64? serverTimeUnixNanos,
    $core.bool? outdated,
  }) {
    final result = HelloResponse._();
    if (serverApiVersion != null) result.serverApiVersion = serverApiVersion;
    if (serverVersion != null) result.serverVersion = serverVersion;
    if (serverTimeUnixNanos != null)
      result.serverTimeUnixNanos = serverTimeUnixNanos;
    if (outdated != null) result.outdated = outdated;
    return result;
  }

  HelloResponse._();

  factory HelloResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HelloResponse()..mergeFromBuffer(data, registry);
  factory HelloResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HelloResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HelloResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: HelloResponse.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'serverApiVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'serverVersion')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'serverTimeUnixNanos', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(4, _omitFieldNames ? '' : 'outdated')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HelloResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HelloResponse copyWith(void Function(HelloResponse) updates) =>
      super.copyWith((message) => updates(message as HelloResponse))
          as HelloResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use HelloResponse() / HelloResponse.new instead')
  static HelloResponse create() => HelloResponse._();
  static $pb.GeneratedMessage $_createMessage() => HelloResponse._();
  @$core.override
  HelloResponse createEmptyInstance() => HelloResponse._();
  @$core.pragma('dart2js:noInline')
  static HelloResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HelloResponse>(
          HelloResponse.$_createMessage);
  static HelloResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get serverApiVersion => $_getIZ(0);
  @$pb.TagNumber(1)
  set serverApiVersion($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasServerApiVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerApiVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get serverVersion => $_getSZ(1);
  @$pb.TagNumber(2)
  set serverVersion($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasServerVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearServerVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get serverTimeUnixNanos => $_getI64(2);
  @$pb.TagNumber(3)
  set serverTimeUnixNanos($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasServerTimeUnixNanos() => $_has(2);
  @$pb.TagNumber(3)
  void clearServerTimeUnixNanos() => $_clearField(3);

  /// The daemon's program was replaced on disk (an update or a rebuild):
  /// restarting it runs the new one.
  @$pb.TagNumber(4)
  $core.bool get outdated => $_getBF(3);
  @$pb.TagNumber(4)
  set outdated($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOutdated() => $_has(3);
  @$pb.TagNumber(4)
  void clearOutdated() => $_clearField(4);
}

class ShutdownRequest extends $pb.GeneratedMessage {
  factory ShutdownRequest({
    $core.bool? ifIdle,
  }) {
    final result = ShutdownRequest._();
    if (ifIdle != null) result.ifIdle = ifIdle;
    return result;
  }

  ShutdownRequest._();

  factory ShutdownRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShutdownRequest()..mergeFromBuffer(data, registry);
  factory ShutdownRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShutdownRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShutdownRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ShutdownRequest.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'ifIdle')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShutdownRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShutdownRequest copyWith(void Function(ShutdownRequest) updates) =>
      super.copyWith((message) => updates(message as ShutdownRequest))
          as ShutdownRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ShutdownRequest() / ShutdownRequest.new instead')
  static ShutdownRequest create() => ShutdownRequest._();
  static $pb.GeneratedMessage $_createMessage() => ShutdownRequest._();
  @$core.override
  ShutdownRequest createEmptyInstance() => ShutdownRequest._();
  @$core.pragma('dart2js:noInline')
  static ShutdownRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShutdownRequest>(
          ShutdownRequest.$_createMessage);
  static ShutdownRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ifIdle => $_getBF(0);
  @$pb.TagNumber(1)
  set ifIdle($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIfIdle() => $_has(0);
  @$pb.TagNumber(1)
  void clearIfIdle() => $_clearField(1);
}

class ShutdownResponse extends $pb.GeneratedMessage {
  factory ShutdownResponse() => ShutdownResponse._();

  ShutdownResponse._();

  factory ShutdownResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShutdownResponse()..mergeFromBuffer(data, registry);
  factory ShutdownResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShutdownResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShutdownResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ShutdownResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShutdownResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShutdownResponse copyWith(void Function(ShutdownResponse) updates) =>
      super.copyWith((message) => updates(message as ShutdownResponse))
          as ShutdownResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ShutdownResponse() / ShutdownResponse.new instead')
  static ShutdownResponse create() => ShutdownResponse._();
  static $pb.GeneratedMessage $_createMessage() => ShutdownResponse._();
  @$core.override
  ShutdownResponse createEmptyInstance() => ShutdownResponse._();
  @$core.pragma('dart2js:noInline')
  static ShutdownResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShutdownResponse>(
          ShutdownResponse.$_createMessage);
  static ShutdownResponse? _defaultInstance;
}

class OpenRequest extends $pb.GeneratedMessage {
  factory OpenRequest({
    $core.String? program,
    $core.Iterable<$core.String>? args,
    $core.String? cwd,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? env,
    $core.int? cols,
    $core.int? rows,
  }) {
    final result = OpenRequest._();
    if (program != null) result.program = program;
    if (args != null) result.args.addAll(args);
    if (cwd != null) result.cwd = cwd;
    if (env != null) result.env.addEntries(env);
    if (cols != null) result.cols = cols;
    if (rows != null) result.rows = rows;
    return result;
  }

  OpenRequest._();

  factory OpenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OpenRequest()..mergeFromBuffer(data, registry);
  factory OpenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OpenRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OpenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: OpenRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'program')
    ..pPS(2, _omitFieldNames ? '' : 'args')
    ..aOS(3, _omitFieldNames ? '' : 'cwd')
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'env',
        entryClassName: 'OpenRequest.EnvEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('kumo.v1'))
    ..aI(5, _omitFieldNames ? '' : 'cols', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'rows', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenRequest copyWith(void Function(OpenRequest) updates) =>
      super.copyWith((message) => updates(message as OpenRequest))
          as OpenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OpenRequest() / OpenRequest.new instead')
  static OpenRequest create() => OpenRequest._();
  static $pb.GeneratedMessage $_createMessage() => OpenRequest._();
  @$core.override
  OpenRequest createEmptyInstance() => OpenRequest._();
  @$core.pragma('dart2js:noInline')
  static OpenRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OpenRequest>(
          OpenRequest.$_createMessage);
  static OpenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get program => $_getSZ(0);
  @$pb.TagNumber(1)
  set program($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProgram() => $_has(0);
  @$pb.TagNumber(1)
  void clearProgram() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get args => $_getList(1);

  /// Empty means the daemon's working directory.
  @$pb.TagNumber(3)
  $core.String get cwd => $_getSZ(2);
  @$pb.TagNumber(3)
  set cwd($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCwd() => $_has(2);
  @$pb.TagNumber(3)
  void clearCwd() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.String> get env => $_getMap(3);

  @$pb.TagNumber(5)
  $core.int get cols => $_getIZ(4);
  @$pb.TagNumber(5)
  set cols($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCols() => $_has(4);
  @$pb.TagNumber(5)
  void clearCols() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get rows => $_getIZ(5);
  @$pb.TagNumber(6)
  set rows($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRows() => $_has(5);
  @$pb.TagNumber(6)
  void clearRows() => $_clearField(6);
}

class OpenResponse extends $pb.GeneratedMessage {
  factory OpenResponse({
    $core.String? terminalId,
  }) {
    final result = OpenResponse._();
    if (terminalId != null) result.terminalId = terminalId;
    return result;
  }

  OpenResponse._();

  factory OpenResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OpenResponse()..mergeFromBuffer(data, registry);
  factory OpenResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OpenResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OpenResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: OpenResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'terminalId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenResponse copyWith(void Function(OpenResponse) updates) =>
      super.copyWith((message) => updates(message as OpenResponse))
          as OpenResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OpenResponse() / OpenResponse.new instead')
  static OpenResponse create() => OpenResponse._();
  static $pb.GeneratedMessage $_createMessage() => OpenResponse._();
  @$core.override
  OpenResponse createEmptyInstance() => OpenResponse._();
  @$core.pragma('dart2js:noInline')
  static OpenResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OpenResponse>(
          OpenResponse.$_createMessage);
  static OpenResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get terminalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set terminalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTerminalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTerminalId() => $_clearField(1);
}

enum TerminalInput_Kind { attach, data, resize, notSet }

class TerminalInput extends $pb.GeneratedMessage {
  factory TerminalInput({
    AttachTo? attach,
    $core.List<$core.int>? data,
    Resize? resize,
  }) {
    final result = TerminalInput._();
    if (attach != null) result.attach = attach;
    if (data != null) result.data = data;
    if (resize != null) result.resize = resize;
    return result;
  }

  TerminalInput._();

  factory TerminalInput.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TerminalInput()..mergeFromBuffer(data, registry);
  factory TerminalInput.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TerminalInput()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, TerminalInput_Kind>
      _TerminalInput_KindByTag = {
    1: TerminalInput_Kind.attach,
    2: TerminalInput_Kind.data,
    3: TerminalInput_Kind.resize,
    0: TerminalInput_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TerminalInput',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TerminalInput.$_createMessage)
    ..oo(0, [1, 2, 3])
    ..aOM<AttachTo>(1, _omitFieldNames ? '' : 'attach',
        subBuilder: AttachTo.$_createMessage)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aOM<Resize>(3, _omitFieldNames ? '' : 'resize',
        subBuilder: Resize.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TerminalInput clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TerminalInput copyWith(void Function(TerminalInput) updates) =>
      super.copyWith((message) => updates(message as TerminalInput))
          as TerminalInput;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TerminalInput() / TerminalInput.new instead')
  static TerminalInput create() => TerminalInput._();
  static $pb.GeneratedMessage $_createMessage() => TerminalInput._();
  @$core.override
  TerminalInput createEmptyInstance() => TerminalInput._();
  @$core.pragma('dart2js:noInline')
  static TerminalInput getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TerminalInput>(
          TerminalInput.$_createMessage);
  static TerminalInput? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  TerminalInput_Kind whichKind() => _TerminalInput_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearKind() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  AttachTo get attach => $_getN(0);
  @$pb.TagNumber(1)
  set attach(AttachTo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAttach() => $_has(0);
  @$pb.TagNumber(1)
  void clearAttach() => $_clearField(1);
  @$pb.TagNumber(1)
  AttachTo ensureAttach() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);

  @$pb.TagNumber(3)
  Resize get resize => $_getN(2);
  @$pb.TagNumber(3)
  set resize(Resize value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasResize() => $_has(2);
  @$pb.TagNumber(3)
  void clearResize() => $_clearField(3);
  @$pb.TagNumber(3)
  Resize ensureResize() => $_ensure(2);
}

class AttachTo extends $pb.GeneratedMessage {
  factory AttachTo({
    $core.String? terminalId,
    $core.bool? replayScrollback,
  }) {
    final result = AttachTo._();
    if (terminalId != null) result.terminalId = terminalId;
    if (replayScrollback != null) result.replayScrollback = replayScrollback;
    return result;
  }

  AttachTo._();

  factory AttachTo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AttachTo()..mergeFromBuffer(data, registry);
  factory AttachTo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AttachTo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AttachTo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: AttachTo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'terminalId')
    ..aOB(2, _omitFieldNames ? '' : 'replayScrollback')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttachTo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttachTo copyWith(void Function(AttachTo) updates) =>
      super.copyWith((message) => updates(message as AttachTo)) as AttachTo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AttachTo() / AttachTo.new instead')
  static AttachTo create() => AttachTo._();
  static $pb.GeneratedMessage $_createMessage() => AttachTo._();
  @$core.override
  AttachTo createEmptyInstance() => AttachTo._();
  @$core.pragma('dart2js:noInline')
  static AttachTo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AttachTo>(AttachTo.$_createMessage);
  static AttachTo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get terminalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set terminalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTerminalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTerminalId() => $_clearField(1);

  /// Send the bounded replay buffer before live output. Replay and live
  /// output never overlap: `seq` is strictly increasing across both.
  @$pb.TagNumber(2)
  $core.bool get replayScrollback => $_getBF(1);
  @$pb.TagNumber(2)
  set replayScrollback($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReplayScrollback() => $_has(1);
  @$pb.TagNumber(2)
  void clearReplayScrollback() => $_clearField(2);
}

class Resize extends $pb.GeneratedMessage {
  factory Resize({
    $core.int? cols,
    $core.int? rows,
  }) {
    final result = Resize._();
    if (cols != null) result.cols = cols;
    if (rows != null) result.rows = rows;
    return result;
  }

  Resize._();

  factory Resize.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Resize()..mergeFromBuffer(data, registry);
  factory Resize.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Resize()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Resize',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: Resize.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'cols', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'rows', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Resize clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Resize copyWith(void Function(Resize) updates) =>
      super.copyWith((message) => updates(message as Resize)) as Resize;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Resize() / Resize.new instead')
  static Resize create() => Resize._();
  static $pb.GeneratedMessage $_createMessage() => Resize._();
  @$core.override
  Resize createEmptyInstance() => Resize._();
  @$core.pragma('dart2js:noInline')
  static Resize getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Resize>(Resize.$_createMessage);
  static Resize? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get cols => $_getIZ(0);
  @$pb.TagNumber(1)
  set cols($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCols() => $_has(0);
  @$pb.TagNumber(1)
  void clearCols() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get rows => $_getIZ(1);
  @$pb.TagNumber(2)
  set rows($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRows() => $_has(1);
  @$pb.TagNumber(2)
  void clearRows() => $_clearField(2);
}

enum TerminalOutput_Kind { output, exited, notSet }

class TerminalOutput extends $pb.GeneratedMessage {
  factory TerminalOutput({
    OutputBatch? output,
    Exited? exited,
  }) {
    final result = TerminalOutput._();
    if (output != null) result.output = output;
    if (exited != null) result.exited = exited;
    return result;
  }

  TerminalOutput._();

  factory TerminalOutput.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TerminalOutput()..mergeFromBuffer(data, registry);
  factory TerminalOutput.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TerminalOutput()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, TerminalOutput_Kind>
      _TerminalOutput_KindByTag = {
    1: TerminalOutput_Kind.output,
    2: TerminalOutput_Kind.exited,
    0: TerminalOutput_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TerminalOutput',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TerminalOutput.$_createMessage)
    ..oo(0, [1, 2])
    ..aOM<OutputBatch>(1, _omitFieldNames ? '' : 'output',
        subBuilder: OutputBatch.$_createMessage)
    ..aOM<Exited>(2, _omitFieldNames ? '' : 'exited',
        subBuilder: Exited.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TerminalOutput clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TerminalOutput copyWith(void Function(TerminalOutput) updates) =>
      super.copyWith((message) => updates(message as TerminalOutput))
          as TerminalOutput;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TerminalOutput() / TerminalOutput.new instead')
  static TerminalOutput create() => TerminalOutput._();
  static $pb.GeneratedMessage $_createMessage() => TerminalOutput._();
  @$core.override
  TerminalOutput createEmptyInstance() => TerminalOutput._();
  @$core.pragma('dart2js:noInline')
  static TerminalOutput getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TerminalOutput>(
          TerminalOutput.$_createMessage);
  static TerminalOutput? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  TerminalOutput_Kind whichKind() =>
      _TerminalOutput_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearKind() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  OutputBatch get output => $_getN(0);
  @$pb.TagNumber(1)
  set output(OutputBatch value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasOutput() => $_has(0);
  @$pb.TagNumber(1)
  void clearOutput() => $_clearField(1);
  @$pb.TagNumber(1)
  OutputBatch ensureOutput() => $_ensure(0);

  @$pb.TagNumber(2)
  Exited get exited => $_getN(1);
  @$pb.TagNumber(2)
  set exited(Exited value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasExited() => $_has(1);
  @$pb.TagNumber(2)
  void clearExited() => $_clearField(2);
  @$pb.TagNumber(2)
  Exited ensureExited() => $_ensure(1);
}

class OutputBatch extends $pb.GeneratedMessage {
  factory OutputBatch({
    $fixnum.Int64? seq,
    $core.List<$core.int>? data,
    $fixnum.Int64? firstReadUnixNanos,
    $core.int? chunks,
  }) {
    final result = OutputBatch._();
    if (seq != null) result.seq = seq;
    if (data != null) result.data = data;
    if (firstReadUnixNanos != null)
      result.firstReadUnixNanos = firstReadUnixNanos;
    if (chunks != null) result.chunks = chunks;
    return result;
  }

  OutputBatch._();

  factory OutputBatch.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OutputBatch()..mergeFromBuffer(data, registry);
  factory OutputBatch.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OutputBatch()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OutputBatch',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: OutputBatch.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'seq', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'firstReadUnixNanos', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(4, _omitFieldNames ? '' : 'chunks', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OutputBatch clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OutputBatch copyWith(void Function(OutputBatch) updates) =>
      super.copyWith((message) => updates(message as OutputBatch))
          as OutputBatch;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OutputBatch() / OutputBatch.new instead')
  static OutputBatch create() => OutputBatch._();
  static $pb.GeneratedMessage $_createMessage() => OutputBatch._();
  @$core.override
  OutputBatch createEmptyInstance() => OutputBatch._();
  @$core.pragma('dart2js:noInline')
  static OutputBatch getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OutputBatch>(
          OutputBatch.$_createMessage);
  static OutputBatch? _defaultInstance;

  /// Monotonic per session, starting at 1.
  @$pb.TagNumber(1)
  $fixnum.Int64 get seq => $_getI64(0);
  @$pb.TagNumber(1)
  set seq($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeq() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeq() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);

  /// When the first coalesced chunk was read from the PTY (latency tracing).
  @$pb.TagNumber(3)
  $fixnum.Int64 get firstReadUnixNanos => $_getI64(2);
  @$pb.TagNumber(3)
  set firstReadUnixNanos($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFirstReadUnixNanos() => $_has(2);
  @$pb.TagNumber(3)
  void clearFirstReadUnixNanos() => $_clearField(3);

  /// How many PTY reads were coalesced into this batch.
  @$pb.TagNumber(4)
  $core.int get chunks => $_getIZ(3);
  @$pb.TagNumber(4)
  set chunks($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasChunks() => $_has(3);
  @$pb.TagNumber(4)
  void clearChunks() => $_clearField(4);
}

class Exited extends $pb.GeneratedMessage {
  factory Exited({
    $core.int? exitCode,
  }) {
    final result = Exited._();
    if (exitCode != null) result.exitCode = exitCode;
    return result;
  }

  Exited._();

  factory Exited.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Exited()..mergeFromBuffer(data, registry);
  factory Exited.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Exited()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Exited',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: Exited.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'exitCode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Exited clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Exited copyWith(void Function(Exited) updates) =>
      super.copyWith((message) => updates(message as Exited)) as Exited;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Exited() / Exited.new instead')
  static Exited create() => Exited._();
  static $pb.GeneratedMessage $_createMessage() => Exited._();
  @$core.override
  Exited createEmptyInstance() => Exited._();
  @$core.pragma('dart2js:noInline')
  static Exited getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Exited>(Exited.$_createMessage);
  static Exited? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get exitCode => $_getIZ(0);
  @$pb.TagNumber(1)
  set exitCode($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasExitCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearExitCode() => $_clearField(1);
}

class CloseRequest extends $pb.GeneratedMessage {
  factory CloseRequest({
    $core.String? terminalId,
  }) {
    final result = CloseRequest._();
    if (terminalId != null) result.terminalId = terminalId;
    return result;
  }

  CloseRequest._();

  factory CloseRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CloseRequest()..mergeFromBuffer(data, registry);
  factory CloseRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CloseRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CloseRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: CloseRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'terminalId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseRequest copyWith(void Function(CloseRequest) updates) =>
      super.copyWith((message) => updates(message as CloseRequest))
          as CloseRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CloseRequest() / CloseRequest.new instead')
  static CloseRequest create() => CloseRequest._();
  static $pb.GeneratedMessage $_createMessage() => CloseRequest._();
  @$core.override
  CloseRequest createEmptyInstance() => CloseRequest._();
  @$core.pragma('dart2js:noInline')
  static CloseRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CloseRequest>(
          CloseRequest.$_createMessage);
  static CloseRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get terminalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set terminalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTerminalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTerminalId() => $_clearField(1);
}

class CloseResponse extends $pb.GeneratedMessage {
  factory CloseResponse() => CloseResponse._();

  CloseResponse._();

  factory CloseResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CloseResponse()..mergeFromBuffer(data, registry);
  factory CloseResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CloseResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CloseResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: CloseResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseResponse copyWith(void Function(CloseResponse) updates) =>
      super.copyWith((message) => updates(message as CloseResponse))
          as CloseResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CloseResponse() / CloseResponse.new instead')
  static CloseResponse create() => CloseResponse._();
  static $pb.GeneratedMessage $_createMessage() => CloseResponse._();
  @$core.override
  CloseResponse createEmptyInstance() => CloseResponse._();
  @$core.pragma('dart2js:noInline')
  static CloseResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CloseResponse>(
          CloseResponse.$_createMessage);
  static CloseResponse? _defaultInstance;
}

class ListRequest extends $pb.GeneratedMessage {
  factory ListRequest() => ListRequest._();

  ListRequest._();

  factory ListRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListRequest()..mergeFromBuffer(data, registry);
  factory ListRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ListRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListRequest copyWith(void Function(ListRequest) updates) =>
      super.copyWith((message) => updates(message as ListRequest))
          as ListRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListRequest() / ListRequest.new instead')
  static ListRequest create() => ListRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListRequest._();
  @$core.override
  ListRequest createEmptyInstance() => ListRequest._();
  @$core.pragma('dart2js:noInline')
  static ListRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListRequest>(
          ListRequest.$_createMessage);
  static ListRequest? _defaultInstance;
}

class ListResponse extends $pb.GeneratedMessage {
  factory ListResponse({
    $core.Iterable<TerminalInfo>? terminals,
  }) {
    final result = ListResponse._();
    if (terminals != null) result.terminals.addAll(terminals);
    return result;
  }

  ListResponse._();

  factory ListResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListResponse()..mergeFromBuffer(data, registry);
  factory ListResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ListResponse.$_createMessage)
    ..pPM<TerminalInfo>(1, _omitFieldNames ? '' : 'terminals',
        subBuilder: TerminalInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListResponse copyWith(void Function(ListResponse) updates) =>
      super.copyWith((message) => updates(message as ListResponse))
          as ListResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListResponse() / ListResponse.new instead')
  static ListResponse create() => ListResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListResponse._();
  @$core.override
  ListResponse createEmptyInstance() => ListResponse._();
  @$core.pragma('dart2js:noInline')
  static ListResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListResponse>(
          ListResponse.$_createMessage);
  static ListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TerminalInfo> get terminals => $_getList(0);
}

class TerminalInfo extends $pb.GeneratedMessage {
  factory TerminalInfo({
    $core.String? terminalId,
    $core.String? program,
    $core.bool? exited,
    $core.int? exitCode,
    $core.String? cwd,
  }) {
    final result = TerminalInfo._();
    if (terminalId != null) result.terminalId = terminalId;
    if (program != null) result.program = program;
    if (exited != null) result.exited = exited;
    if (exitCode != null) result.exitCode = exitCode;
    if (cwd != null) result.cwd = cwd;
    return result;
  }

  TerminalInfo._();

  factory TerminalInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TerminalInfo()..mergeFromBuffer(data, registry);
  factory TerminalInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TerminalInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TerminalInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TerminalInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'terminalId')
    ..aOS(2, _omitFieldNames ? '' : 'program')
    ..aOB(3, _omitFieldNames ? '' : 'exited')
    ..aI(4, _omitFieldNames ? '' : 'exitCode')
    ..aOS(5, _omitFieldNames ? '' : 'cwd')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TerminalInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TerminalInfo copyWith(void Function(TerminalInfo) updates) =>
      super.copyWith((message) => updates(message as TerminalInfo))
          as TerminalInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TerminalInfo() / TerminalInfo.new instead')
  static TerminalInfo create() => TerminalInfo._();
  static $pb.GeneratedMessage $_createMessage() => TerminalInfo._();
  @$core.override
  TerminalInfo createEmptyInstance() => TerminalInfo._();
  @$core.pragma('dart2js:noInline')
  static TerminalInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TerminalInfo>(
          TerminalInfo.$_createMessage);
  static TerminalInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get terminalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set terminalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTerminalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTerminalId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get program => $_getSZ(1);
  @$pb.TagNumber(2)
  set program($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProgram() => $_has(1);
  @$pb.TagNumber(2)
  void clearProgram() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get exited => $_getBF(2);
  @$pb.TagNumber(3)
  set exited($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExited() => $_has(2);
  @$pb.TagNumber(3)
  void clearExited() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get exitCode => $_getIZ(3);
  @$pb.TagNumber(4)
  set exitCode($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExitCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearExitCode() => $_clearField(4);

  /// Where it started (absolute); empty if it started in the daemon's own
  /// directory. Lets a UI put terminals back with their worktree.
  @$pb.TagNumber(5)
  $core.String get cwd => $_getSZ(4);
  @$pb.TagNumber(5)
  set cwd($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCwd() => $_has(4);
  @$pb.TagNumber(5)
  void clearCwd() => $_clearField(5);
}

class WatchWorkspaceRequest extends $pb.GeneratedMessage {
  factory WatchWorkspaceRequest() => WatchWorkspaceRequest._();

  WatchWorkspaceRequest._();

  factory WatchWorkspaceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchWorkspaceRequest()..mergeFromBuffer(data, registry);
  factory WatchWorkspaceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchWorkspaceRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WatchWorkspaceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: WatchWorkspaceRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchWorkspaceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchWorkspaceRequest copyWith(
          void Function(WatchWorkspaceRequest) updates) =>
      super.copyWith((message) => updates(message as WatchWorkspaceRequest))
          as WatchWorkspaceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use WatchWorkspaceRequest() / WatchWorkspaceRequest.new instead')
  static WatchWorkspaceRequest create() => WatchWorkspaceRequest._();
  static $pb.GeneratedMessage $_createMessage() => WatchWorkspaceRequest._();
  @$core.override
  WatchWorkspaceRequest createEmptyInstance() => WatchWorkspaceRequest._();
  @$core.pragma('dart2js:noInline')
  static WatchWorkspaceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WatchWorkspaceRequest>(
          WatchWorkspaceRequest.$_createMessage);
  static WatchWorkspaceRequest? _defaultInstance;
}

class WorkspaceSnapshot extends $pb.GeneratedMessage {
  factory WorkspaceSnapshot({
    $fixnum.Int64? version,
    $core.Iterable<Namespace>? namespaces,
    $core.Iterable<Repository>? repositories,
  }) {
    final result = WorkspaceSnapshot._();
    if (version != null) result.version = version;
    if (namespaces != null) result.namespaces.addAll(namespaces);
    if (repositories != null) result.repositories.addAll(repositories);
    return result;
  }

  WorkspaceSnapshot._();

  factory WorkspaceSnapshot.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorkspaceSnapshot()..mergeFromBuffer(data, registry);
  factory WorkspaceSnapshot.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorkspaceSnapshot()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkspaceSnapshot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: WorkspaceSnapshot.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'version', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<Namespace>(2, _omitFieldNames ? '' : 'namespaces',
        subBuilder: Namespace.$_createMessage)
    ..pPM<Repository>(3, _omitFieldNames ? '' : 'repositories',
        subBuilder: Repository.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkspaceSnapshot clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkspaceSnapshot copyWith(void Function(WorkspaceSnapshot) updates) =>
      super.copyWith((message) => updates(message as WorkspaceSnapshot))
          as WorkspaceSnapshot;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WorkspaceSnapshot() / WorkspaceSnapshot.new instead')
  static WorkspaceSnapshot create() => WorkspaceSnapshot._();
  static $pb.GeneratedMessage $_createMessage() => WorkspaceSnapshot._();
  @$core.override
  WorkspaceSnapshot createEmptyInstance() => WorkspaceSnapshot._();
  @$core.pragma('dart2js:noInline')
  static WorkspaceSnapshot getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WorkspaceSnapshot>(
          WorkspaceSnapshot.$_createMessage);
  static WorkspaceSnapshot? _defaultInstance;

  /// Increases with every change.
  @$pb.TagNumber(1)
  $fixnum.Int64 get version => $_getI64(0);
  @$pb.TagNumber(1)
  set version($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<Namespace> get namespaces => $_getList(1);

  /// Every repository referenced by a namespace.
  @$pb.TagNumber(3)
  $pb.PbList<Repository> get repositories => $_getList(2);
}

class Namespace extends $pb.GeneratedMessage {
  factory Namespace({
    $core.String? id,
    $core.String? name,
    $core.Iterable<$core.String>? repoPaths,
    $core.bool? collapsed,
  }) {
    final result = Namespace._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (repoPaths != null) result.repoPaths.addAll(repoPaths);
    if (collapsed != null) result.collapsed = collapsed;
    return result;
  }

  Namespace._();

  factory Namespace.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Namespace()..mergeFromBuffer(data, registry);
  factory Namespace.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Namespace()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Namespace',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: Namespace.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..pPS(3, _omitFieldNames ? '' : 'repoPaths')
    ..aOB(4, _omitFieldNames ? '' : 'collapsed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Namespace clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Namespace copyWith(void Function(Namespace) updates) =>
      super.copyWith((message) => updates(message as Namespace)) as Namespace;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Namespace() / Namespace.new instead')
  static Namespace create() => Namespace._();
  static $pb.GeneratedMessage $_createMessage() => Namespace._();
  @$core.override
  Namespace createEmptyInstance() => Namespace._();
  @$core.pragma('dart2js:noInline')
  static Namespace getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Namespace>(Namespace.$_createMessage);
  static Namespace? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  /// Repository paths, in sidebar order.
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get repoPaths => $_getList(2);

  @$pb.TagNumber(4)
  $core.bool get collapsed => $_getBF(3);
  @$pb.TagNumber(4)
  set collapsed($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCollapsed() => $_has(3);
  @$pb.TagNumber(4)
  void clearCollapsed() => $_clearField(4);
}

class Repository extends $pb.GeneratedMessage {
  factory Repository({
    $core.String? path,
    $core.String? name,
    GitHost? host,
    $core.String? fullName,
    $core.String? remoteUrl,
    $core.Iterable<Worktree>? worktrees,
    $core.String? error,
  }) {
    final result = Repository._();
    if (path != null) result.path = path;
    if (name != null) result.name = name;
    if (host != null) result.host = host;
    if (fullName != null) result.fullName = fullName;
    if (remoteUrl != null) result.remoteUrl = remoteUrl;
    if (worktrees != null) result.worktrees.addAll(worktrees);
    if (error != null) result.error = error;
    return result;
  }

  Repository._();

  factory Repository.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Repository()..mergeFromBuffer(data, registry);
  factory Repository.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Repository()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Repository',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: Repository.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aE<GitHost>(3, _omitFieldNames ? '' : 'host', enumValues: GitHost.values)
    ..aOS(4, _omitFieldNames ? '' : 'fullName')
    ..aOS(5, _omitFieldNames ? '' : 'remoteUrl')
    ..pPM<Worktree>(6, _omitFieldNames ? '' : 'worktrees',
        subBuilder: Worktree.$_createMessage)
    ..aOS(7, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Repository clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Repository copyWith(void Function(Repository) updates) =>
      super.copyWith((message) => updates(message as Repository)) as Repository;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Repository() / Repository.new instead')
  static Repository create() => Repository._();
  static $pb.GeneratedMessage $_createMessage() => Repository._();
  @$core.override
  Repository createEmptyInstance() => Repository._();
  @$core.pragma('dart2js:noInline')
  static Repository getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Repository>(Repository.$_createMessage);
  static Repository? _defaultInstance;

  /// Absolute path of the main checkout: the repository's identity.
  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  GitHost get host => $_getN(2);
  @$pb.TagNumber(3)
  set host(GitHost value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasHost() => $_has(2);
  @$pb.TagNumber(3)
  void clearHost() => $_clearField(3);

  /// "owner/name" on the host, empty without a remote.
  @$pb.TagNumber(4)
  $core.String get fullName => $_getSZ(3);
  @$pb.TagNumber(4)
  set fullName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFullName() => $_has(3);
  @$pb.TagNumber(4)
  void clearFullName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get remoteUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set remoteUrl($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRemoteUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearRemoteUrl() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<Worktree> get worktrees => $_getList(5);

  /// Set when git could not be read (moved or deleted folder…).
  @$pb.TagNumber(7)
  $core.String get error => $_getSZ(6);
  @$pb.TagNumber(7)
  set error($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasError() => $_has(6);
  @$pb.TagNumber(7)
  void clearError() => $_clearField(7);
}

class Worktree extends $pb.GeneratedMessage {
  factory Worktree({
    $core.String? path,
    $core.String? branch,
    $core.String? head,
    $core.bool? isMain,
    $core.bool? locked,
    WorktreeStatus? status,
  }) {
    final result = Worktree._();
    if (path != null) result.path = path;
    if (branch != null) result.branch = branch;
    if (head != null) result.head = head;
    if (isMain != null) result.isMain = isMain;
    if (locked != null) result.locked = locked;
    if (status != null) result.status = status;
    return result;
  }

  Worktree._();

  factory Worktree.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Worktree()..mergeFromBuffer(data, registry);
  factory Worktree.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Worktree()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Worktree',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: Worktree.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'branch')
    ..aOS(3, _omitFieldNames ? '' : 'head')
    ..aOB(4, _omitFieldNames ? '' : 'isMain')
    ..aOB(5, _omitFieldNames ? '' : 'locked')
    ..aOM<WorktreeStatus>(6, _omitFieldNames ? '' : 'status',
        subBuilder: WorktreeStatus.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Worktree clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Worktree copyWith(void Function(Worktree) updates) =>
      super.copyWith((message) => updates(message as Worktree)) as Worktree;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Worktree() / Worktree.new instead')
  static Worktree create() => Worktree._();
  static $pb.GeneratedMessage $_createMessage() => Worktree._();
  @$core.override
  Worktree createEmptyInstance() => Worktree._();
  @$core.pragma('dart2js:noInline')
  static Worktree getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Worktree>(Worktree.$_createMessage);
  static Worktree? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  /// Empty when HEAD is detached.
  @$pb.TagNumber(2)
  $core.String get branch => $_getSZ(1);
  @$pb.TagNumber(2)
  set branch($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBranch() => $_has(1);
  @$pb.TagNumber(2)
  void clearBranch() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get head => $_getSZ(2);
  @$pb.TagNumber(3)
  set head($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHead() => $_has(2);
  @$pb.TagNumber(3)
  void clearHead() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isMain => $_getBF(3);
  @$pb.TagNumber(4)
  set isMain($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsMain() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsMain() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get locked => $_getBF(4);
  @$pb.TagNumber(5)
  set locked($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLocked() => $_has(4);
  @$pb.TagNumber(5)
  void clearLocked() => $_clearField(5);

  @$pb.TagNumber(6)
  WorktreeStatus get status => $_getN(5);
  @$pb.TagNumber(6)
  set status(WorktreeStatus value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);
  @$pb.TagNumber(6)
  WorktreeStatus ensureStatus() => $_ensure(5);
}

class WorktreeStatus extends $pb.GeneratedMessage {
  factory WorktreeStatus({
    $core.int? changedFiles,
    $core.int? ahead,
    $core.int? behind,
    $core.String? upstream,
  }) {
    final result = WorktreeStatus._();
    if (changedFiles != null) result.changedFiles = changedFiles;
    if (ahead != null) result.ahead = ahead;
    if (behind != null) result.behind = behind;
    if (upstream != null) result.upstream = upstream;
    return result;
  }

  WorktreeStatus._();

  factory WorktreeStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorktreeStatus()..mergeFromBuffer(data, registry);
  factory WorktreeStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorktreeStatus()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorktreeStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: WorktreeStatus.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'changedFiles',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'ahead', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'behind', fieldType: $pb.PbFieldType.OU3)
    ..aOS(4, _omitFieldNames ? '' : 'upstream')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorktreeStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorktreeStatus copyWith(void Function(WorktreeStatus) updates) =>
      super.copyWith((message) => updates(message as WorktreeStatus))
          as WorktreeStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WorktreeStatus() / WorktreeStatus.new instead')
  static WorktreeStatus create() => WorktreeStatus._();
  static $pb.GeneratedMessage $_createMessage() => WorktreeStatus._();
  @$core.override
  WorktreeStatus createEmptyInstance() => WorktreeStatus._();
  @$core.pragma('dart2js:noInline')
  static WorktreeStatus getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WorktreeStatus>(
          WorktreeStatus.$_createMessage);
  static WorktreeStatus? _defaultInstance;

  /// Files with staged, unstaged or untracked changes.
  @$pb.TagNumber(1)
  $core.int get changedFiles => $_getIZ(0);
  @$pb.TagNumber(1)
  set changedFiles($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChangedFiles() => $_has(0);
  @$pb.TagNumber(1)
  void clearChangedFiles() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get ahead => $_getIZ(1);
  @$pb.TagNumber(2)
  set ahead($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAhead() => $_has(1);
  @$pb.TagNumber(2)
  void clearAhead() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get behind => $_getIZ(2);
  @$pb.TagNumber(3)
  set behind($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBehind() => $_has(2);
  @$pb.TagNumber(3)
  void clearBehind() => $_clearField(3);

  /// e.g. "origin/main"; empty if the branch was never pushed.
  @$pb.TagNumber(4)
  $core.String get upstream => $_getSZ(3);
  @$pb.TagNumber(4)
  set upstream($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUpstream() => $_has(3);
  @$pb.TagNumber(4)
  void clearUpstream() => $_clearField(4);
}

class RefreshWorkspaceRequest extends $pb.GeneratedMessage {
  factory RefreshWorkspaceRequest() => RefreshWorkspaceRequest._();

  RefreshWorkspaceRequest._();

  factory RefreshWorkspaceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RefreshWorkspaceRequest()..mergeFromBuffer(data, registry);
  factory RefreshWorkspaceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RefreshWorkspaceRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefreshWorkspaceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: RefreshWorkspaceRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshWorkspaceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshWorkspaceRequest copyWith(
          void Function(RefreshWorkspaceRequest) updates) =>
      super.copyWith((message) => updates(message as RefreshWorkspaceRequest))
          as RefreshWorkspaceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RefreshWorkspaceRequest() / RefreshWorkspaceRequest.new instead')
  static RefreshWorkspaceRequest create() => RefreshWorkspaceRequest._();
  static $pb.GeneratedMessage $_createMessage() => RefreshWorkspaceRequest._();
  @$core.override
  RefreshWorkspaceRequest createEmptyInstance() => RefreshWorkspaceRequest._();
  @$core.pragma('dart2js:noInline')
  static RefreshWorkspaceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefreshWorkspaceRequest>(
          RefreshWorkspaceRequest.$_createMessage);
  static RefreshWorkspaceRequest? _defaultInstance;
}

class RefreshWorkspaceResponse extends $pb.GeneratedMessage {
  factory RefreshWorkspaceResponse() => RefreshWorkspaceResponse._();

  RefreshWorkspaceResponse._();

  factory RefreshWorkspaceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RefreshWorkspaceResponse()..mergeFromBuffer(data, registry);
  factory RefreshWorkspaceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RefreshWorkspaceResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefreshWorkspaceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: RefreshWorkspaceResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshWorkspaceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshWorkspaceResponse copyWith(
          void Function(RefreshWorkspaceResponse) updates) =>
      super.copyWith((message) => updates(message as RefreshWorkspaceResponse))
          as RefreshWorkspaceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RefreshWorkspaceResponse() / RefreshWorkspaceResponse.new instead')
  static RefreshWorkspaceResponse create() => RefreshWorkspaceResponse._();
  static $pb.GeneratedMessage $_createMessage() => RefreshWorkspaceResponse._();
  @$core.override
  RefreshWorkspaceResponse createEmptyInstance() =>
      RefreshWorkspaceResponse._();
  @$core.pragma('dart2js:noInline')
  static RefreshWorkspaceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefreshWorkspaceResponse>(
          RefreshWorkspaceResponse.$_createMessage);
  static RefreshWorkspaceResponse? _defaultInstance;
}

class DiscoverReposRequest extends $pb.GeneratedMessage {
  factory DiscoverReposRequest({
    $core.Iterable<$core.String>? roots,
  }) {
    final result = DiscoverReposRequest._();
    if (roots != null) result.roots.addAll(roots);
    return result;
  }

  DiscoverReposRequest._();

  factory DiscoverReposRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DiscoverReposRequest()..mergeFromBuffer(data, registry);
  factory DiscoverReposRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DiscoverReposRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiscoverReposRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DiscoverReposRequest.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'roots')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscoverReposRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscoverReposRequest copyWith(void Function(DiscoverReposRequest) updates) =>
      super.copyWith((message) => updates(message as DiscoverReposRequest))
          as DiscoverReposRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DiscoverReposRequest() / DiscoverReposRequest.new instead')
  static DiscoverReposRequest create() => DiscoverReposRequest._();
  static $pb.GeneratedMessage $_createMessage() => DiscoverReposRequest._();
  @$core.override
  DiscoverReposRequest createEmptyInstance() => DiscoverReposRequest._();
  @$core.pragma('dart2js:noInline')
  static DiscoverReposRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DiscoverReposRequest>(
          DiscoverReposRequest.$_createMessage);
  static DiscoverReposRequest? _defaultInstance;

  /// Folders to scan; empty means the usual ones (~/workspace, ~/dev, ~/code…).
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get roots => $_getList(0);
}

class DiscoverReposResponse extends $pb.GeneratedMessage {
  factory DiscoverReposResponse({
    $core.Iterable<RepoCandidate>? candidates,
  }) {
    final result = DiscoverReposResponse._();
    if (candidates != null) result.candidates.addAll(candidates);
    return result;
  }

  DiscoverReposResponse._();

  factory DiscoverReposResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DiscoverReposResponse()..mergeFromBuffer(data, registry);
  factory DiscoverReposResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DiscoverReposResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiscoverReposResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DiscoverReposResponse.$_createMessage)
    ..pPM<RepoCandidate>(1, _omitFieldNames ? '' : 'candidates',
        subBuilder: RepoCandidate.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscoverReposResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscoverReposResponse copyWith(
          void Function(DiscoverReposResponse) updates) =>
      super.copyWith((message) => updates(message as DiscoverReposResponse))
          as DiscoverReposResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DiscoverReposResponse() / DiscoverReposResponse.new instead')
  static DiscoverReposResponse create() => DiscoverReposResponse._();
  static $pb.GeneratedMessage $_createMessage() => DiscoverReposResponse._();
  @$core.override
  DiscoverReposResponse createEmptyInstance() => DiscoverReposResponse._();
  @$core.pragma('dart2js:noInline')
  static DiscoverReposResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DiscoverReposResponse>(
          DiscoverReposResponse.$_createMessage);
  static DiscoverReposResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<RepoCandidate> get candidates => $_getList(0);
}

class RepoCandidate extends $pb.GeneratedMessage {
  factory RepoCandidate({
    $core.String? path,
    $core.String? name,
    GitHost? host,
    $core.String? fullName,
    $core.int? worktreeCount,
  }) {
    final result = RepoCandidate._();
    if (path != null) result.path = path;
    if (name != null) result.name = name;
    if (host != null) result.host = host;
    if (fullName != null) result.fullName = fullName;
    if (worktreeCount != null) result.worktreeCount = worktreeCount;
    return result;
  }

  RepoCandidate._();

  factory RepoCandidate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RepoCandidate()..mergeFromBuffer(data, registry);
  factory RepoCandidate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RepoCandidate()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RepoCandidate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: RepoCandidate.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aE<GitHost>(3, _omitFieldNames ? '' : 'host', enumValues: GitHost.values)
    ..aOS(4, _omitFieldNames ? '' : 'fullName')
    ..aI(5, _omitFieldNames ? '' : 'worktreeCount',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RepoCandidate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RepoCandidate copyWith(void Function(RepoCandidate) updates) =>
      super.copyWith((message) => updates(message as RepoCandidate))
          as RepoCandidate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RepoCandidate() / RepoCandidate.new instead')
  static RepoCandidate create() => RepoCandidate._();
  static $pb.GeneratedMessage $_createMessage() => RepoCandidate._();
  @$core.override
  RepoCandidate createEmptyInstance() => RepoCandidate._();
  @$core.pragma('dart2js:noInline')
  static RepoCandidate getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RepoCandidate>(
          RepoCandidate.$_createMessage);
  static RepoCandidate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  GitHost get host => $_getN(2);
  @$pb.TagNumber(3)
  set host(GitHost value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasHost() => $_has(2);
  @$pb.TagNumber(3)
  void clearHost() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get fullName => $_getSZ(3);
  @$pb.TagNumber(4)
  set fullName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFullName() => $_has(3);
  @$pb.TagNumber(4)
  void clearFullName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get worktreeCount => $_getIZ(4);
  @$pb.TagNumber(5)
  set worktreeCount($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasWorktreeCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearWorktreeCount() => $_clearField(5);
}

class SaveNamespaceRequest extends $pb.GeneratedMessage {
  factory SaveNamespaceRequest({
    $core.String? id,
    $core.String? name,
    $core.Iterable<$core.String>? repoPaths,
    $core.bool? collapsed,
    $core.int? position,
  }) {
    final result = SaveNamespaceRequest._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (repoPaths != null) result.repoPaths.addAll(repoPaths);
    if (collapsed != null) result.collapsed = collapsed;
    if (position != null) result.position = position;
    return result;
  }

  SaveNamespaceRequest._();

  factory SaveNamespaceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveNamespaceRequest()..mergeFromBuffer(data, registry);
  factory SaveNamespaceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveNamespaceRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveNamespaceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: SaveNamespaceRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..pPS(3, _omitFieldNames ? '' : 'repoPaths')
    ..aOB(4, _omitFieldNames ? '' : 'collapsed')
    ..aI(5, _omitFieldNames ? '' : 'position', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveNamespaceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveNamespaceRequest copyWith(void Function(SaveNamespaceRequest) updates) =>
      super.copyWith((message) => updates(message as SaveNamespaceRequest))
          as SaveNamespaceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SaveNamespaceRequest() / SaveNamespaceRequest.new instead')
  static SaveNamespaceRequest create() => SaveNamespaceRequest._();
  static $pb.GeneratedMessage $_createMessage() => SaveNamespaceRequest._();
  @$core.override
  SaveNamespaceRequest createEmptyInstance() => SaveNamespaceRequest._();
  @$core.pragma('dart2js:noInline')
  static SaveNamespaceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SaveNamespaceRequest>(
          SaveNamespaceRequest.$_createMessage);
  static SaveNamespaceRequest? _defaultInstance;

  /// Empty to create one.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get repoPaths => $_getList(2);

  @$pb.TagNumber(4)
  $core.bool get collapsed => $_getBF(3);
  @$pb.TagNumber(4)
  set collapsed($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCollapsed() => $_has(3);
  @$pb.TagNumber(4)
  void clearCollapsed() => $_clearField(4);

  /// Position among namespaces (past the end appends). Unset: new ones are
  /// appended, existing ones keep their place.
  @$pb.TagNumber(5)
  $core.int get position => $_getIZ(4);
  @$pb.TagNumber(5)
  set position($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPosition() => $_has(4);
  @$pb.TagNumber(5)
  void clearPosition() => $_clearField(5);
}

class SaveNamespaceResponse extends $pb.GeneratedMessage {
  factory SaveNamespaceResponse({
    $core.String? id,
  }) {
    final result = SaveNamespaceResponse._();
    if (id != null) result.id = id;
    return result;
  }

  SaveNamespaceResponse._();

  factory SaveNamespaceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveNamespaceResponse()..mergeFromBuffer(data, registry);
  factory SaveNamespaceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveNamespaceResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveNamespaceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: SaveNamespaceResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveNamespaceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveNamespaceResponse copyWith(
          void Function(SaveNamespaceResponse) updates) =>
      super.copyWith((message) => updates(message as SaveNamespaceResponse))
          as SaveNamespaceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SaveNamespaceResponse() / SaveNamespaceResponse.new instead')
  static SaveNamespaceResponse create() => SaveNamespaceResponse._();
  static $pb.GeneratedMessage $_createMessage() => SaveNamespaceResponse._();
  @$core.override
  SaveNamespaceResponse createEmptyInstance() => SaveNamespaceResponse._();
  @$core.pragma('dart2js:noInline')
  static SaveNamespaceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SaveNamespaceResponse>(
          SaveNamespaceResponse.$_createMessage);
  static SaveNamespaceResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class DeleteNamespaceRequest extends $pb.GeneratedMessage {
  factory DeleteNamespaceRequest({
    $core.String? id,
  }) {
    final result = DeleteNamespaceRequest._();
    if (id != null) result.id = id;
    return result;
  }

  DeleteNamespaceRequest._();

  factory DeleteNamespaceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteNamespaceRequest()..mergeFromBuffer(data, registry);
  factory DeleteNamespaceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteNamespaceRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteNamespaceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DeleteNamespaceRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteNamespaceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteNamespaceRequest copyWith(
          void Function(DeleteNamespaceRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteNamespaceRequest))
          as DeleteNamespaceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DeleteNamespaceRequest() / DeleteNamespaceRequest.new instead')
  static DeleteNamespaceRequest create() => DeleteNamespaceRequest._();
  static $pb.GeneratedMessage $_createMessage() => DeleteNamespaceRequest._();
  @$core.override
  DeleteNamespaceRequest createEmptyInstance() => DeleteNamespaceRequest._();
  @$core.pragma('dart2js:noInline')
  static DeleteNamespaceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteNamespaceRequest>(
          DeleteNamespaceRequest.$_createMessage);
  static DeleteNamespaceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class DeleteNamespaceResponse extends $pb.GeneratedMessage {
  factory DeleteNamespaceResponse() => DeleteNamespaceResponse._();

  DeleteNamespaceResponse._();

  factory DeleteNamespaceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteNamespaceResponse()..mergeFromBuffer(data, registry);
  factory DeleteNamespaceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteNamespaceResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteNamespaceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DeleteNamespaceResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteNamespaceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteNamespaceResponse copyWith(
          void Function(DeleteNamespaceResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteNamespaceResponse))
          as DeleteNamespaceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DeleteNamespaceResponse() / DeleteNamespaceResponse.new instead')
  static DeleteNamespaceResponse create() => DeleteNamespaceResponse._();
  static $pb.GeneratedMessage $_createMessage() => DeleteNamespaceResponse._();
  @$core.override
  DeleteNamespaceResponse createEmptyInstance() => DeleteNamespaceResponse._();
  @$core.pragma('dart2js:noInline')
  static DeleteNamespaceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteNamespaceResponse>(
          DeleteNamespaceResponse.$_createMessage);
  static DeleteNamespaceResponse? _defaultInstance;
}

class CreateWorktreeRequest extends $pb.GeneratedMessage {
  factory CreateWorktreeRequest({
    $core.String? repoPath,
    $core.String? branch,
    $core.bool? createBranch,
    $core.String? base,
    $core.String? path,
  }) {
    final result = CreateWorktreeRequest._();
    if (repoPath != null) result.repoPath = repoPath;
    if (branch != null) result.branch = branch;
    if (createBranch != null) result.createBranch = createBranch;
    if (base != null) result.base = base;
    if (path != null) result.path = path;
    return result;
  }

  CreateWorktreeRequest._();

  factory CreateWorktreeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateWorktreeRequest()..mergeFromBuffer(data, registry);
  factory CreateWorktreeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateWorktreeRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateWorktreeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: CreateWorktreeRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'repoPath')
    ..aOS(2, _omitFieldNames ? '' : 'branch')
    ..aOB(3, _omitFieldNames ? '' : 'createBranch')
    ..aOS(4, _omitFieldNames ? '' : 'base')
    ..aOS(5, _omitFieldNames ? '' : 'path')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateWorktreeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateWorktreeRequest copyWith(
          void Function(CreateWorktreeRequest) updates) =>
      super.copyWith((message) => updates(message as CreateWorktreeRequest))
          as CreateWorktreeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CreateWorktreeRequest() / CreateWorktreeRequest.new instead')
  static CreateWorktreeRequest create() => CreateWorktreeRequest._();
  static $pb.GeneratedMessage $_createMessage() => CreateWorktreeRequest._();
  @$core.override
  CreateWorktreeRequest createEmptyInstance() => CreateWorktreeRequest._();
  @$core.pragma('dart2js:noInline')
  static CreateWorktreeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateWorktreeRequest>(
          CreateWorktreeRequest.$_createMessage);
  static CreateWorktreeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get repoPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set repoPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRepoPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearRepoPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get branch => $_getSZ(1);
  @$pb.TagNumber(2)
  set branch($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBranch() => $_has(1);
  @$pb.TagNumber(2)
  void clearBranch() => $_clearField(2);

  /// Create `branch` from `base` (default: the repo's current HEAD); false
  /// checks out an existing branch.
  @$pb.TagNumber(3)
  $core.bool get createBranch => $_getBF(2);
  @$pb.TagNumber(3)
  set createBranch($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCreateBranch() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreateBranch() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get base => $_getSZ(3);
  @$pb.TagNumber(4)
  set base($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBase() => $_has(3);
  @$pb.TagNumber(4)
  void clearBase() => $_clearField(4);

  /// Where to put it; "~" is expanded. Empty: ~/wt/<repo>/<branch>.
  @$pb.TagNumber(5)
  $core.String get path => $_getSZ(4);
  @$pb.TagNumber(5)
  set path($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPath() => $_has(4);
  @$pb.TagNumber(5)
  void clearPath() => $_clearField(5);
}

class CreateWorktreeResponse extends $pb.GeneratedMessage {
  factory CreateWorktreeResponse({
    Worktree? worktree,
  }) {
    final result = CreateWorktreeResponse._();
    if (worktree != null) result.worktree = worktree;
    return result;
  }

  CreateWorktreeResponse._();

  factory CreateWorktreeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateWorktreeResponse()..mergeFromBuffer(data, registry);
  factory CreateWorktreeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateWorktreeResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateWorktreeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: CreateWorktreeResponse.$_createMessage)
    ..aOM<Worktree>(1, _omitFieldNames ? '' : 'worktree',
        subBuilder: Worktree.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateWorktreeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateWorktreeResponse copyWith(
          void Function(CreateWorktreeResponse) updates) =>
      super.copyWith((message) => updates(message as CreateWorktreeResponse))
          as CreateWorktreeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CreateWorktreeResponse() / CreateWorktreeResponse.new instead')
  static CreateWorktreeResponse create() => CreateWorktreeResponse._();
  static $pb.GeneratedMessage $_createMessage() => CreateWorktreeResponse._();
  @$core.override
  CreateWorktreeResponse createEmptyInstance() => CreateWorktreeResponse._();
  @$core.pragma('dart2js:noInline')
  static CreateWorktreeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateWorktreeResponse>(
          CreateWorktreeResponse.$_createMessage);
  static CreateWorktreeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Worktree get worktree => $_getN(0);
  @$pb.TagNumber(1)
  set worktree(Worktree value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktree() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktree() => $_clearField(1);
  @$pb.TagNumber(1)
  Worktree ensureWorktree() => $_ensure(0);
}

class RemoveWorktreeRequest extends $pb.GeneratedMessage {
  factory RemoveWorktreeRequest({
    $core.String? repoPath,
    $core.String? worktreePath,
    $core.bool? force,
    $core.bool? deleteBranch,
  }) {
    final result = RemoveWorktreeRequest._();
    if (repoPath != null) result.repoPath = repoPath;
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (force != null) result.force = force;
    if (deleteBranch != null) result.deleteBranch = deleteBranch;
    return result;
  }

  RemoveWorktreeRequest._();

  factory RemoveWorktreeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveWorktreeRequest()..mergeFromBuffer(data, registry);
  factory RemoveWorktreeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveWorktreeRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveWorktreeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: RemoveWorktreeRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'repoPath')
    ..aOS(2, _omitFieldNames ? '' : 'worktreePath')
    ..aOB(3, _omitFieldNames ? '' : 'force')
    ..aOB(4, _omitFieldNames ? '' : 'deleteBranch')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveWorktreeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveWorktreeRequest copyWith(
          void Function(RemoveWorktreeRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveWorktreeRequest))
          as RemoveWorktreeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RemoveWorktreeRequest() / RemoveWorktreeRequest.new instead')
  static RemoveWorktreeRequest create() => RemoveWorktreeRequest._();
  static $pb.GeneratedMessage $_createMessage() => RemoveWorktreeRequest._();
  @$core.override
  RemoveWorktreeRequest createEmptyInstance() => RemoveWorktreeRequest._();
  @$core.pragma('dart2js:noInline')
  static RemoveWorktreeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveWorktreeRequest>(
          RemoveWorktreeRequest.$_createMessage);
  static RemoveWorktreeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get repoPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set repoPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRepoPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearRepoPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get worktreePath => $_getSZ(1);
  @$pb.TagNumber(2)
  set worktreePath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorktreePath() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorktreePath() => $_clearField(2);

  /// Also remove it with uncommitted changes.
  @$pb.TagNumber(3)
  $core.bool get force => $_getBF(2);
  @$pb.TagNumber(3)
  set force($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasForce() => $_has(2);
  @$pb.TagNumber(3)
  void clearForce() => $_clearField(3);

  /// Also delete its branch, if merged (`git branch -d`).
  @$pb.TagNumber(4)
  $core.bool get deleteBranch => $_getBF(3);
  @$pb.TagNumber(4)
  set deleteBranch($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeleteBranch() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeleteBranch() => $_clearField(4);
}

class RemoveWorktreeResponse extends $pb.GeneratedMessage {
  factory RemoveWorktreeResponse({
    $core.bool? removed,
    $core.int? changedFiles,
    $core.String? branchKept,
  }) {
    final result = RemoveWorktreeResponse._();
    if (removed != null) result.removed = removed;
    if (changedFiles != null) result.changedFiles = changedFiles;
    if (branchKept != null) result.branchKept = branchKept;
    return result;
  }

  RemoveWorktreeResponse._();

  factory RemoveWorktreeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveWorktreeResponse()..mergeFromBuffer(data, registry);
  factory RemoveWorktreeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveWorktreeResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveWorktreeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: RemoveWorktreeResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'removed')
    ..aI(2, _omitFieldNames ? '' : 'changedFiles',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'branchKept')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveWorktreeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveWorktreeResponse copyWith(
          void Function(RemoveWorktreeResponse) updates) =>
      super.copyWith((message) => updates(message as RemoveWorktreeResponse))
          as RemoveWorktreeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RemoveWorktreeResponse() / RemoveWorktreeResponse.new instead')
  static RemoveWorktreeResponse create() => RemoveWorktreeResponse._();
  static $pb.GeneratedMessage $_createMessage() => RemoveWorktreeResponse._();
  @$core.override
  RemoveWorktreeResponse createEmptyInstance() => RemoveWorktreeResponse._();
  @$core.pragma('dart2js:noInline')
  static RemoveWorktreeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveWorktreeResponse>(
          RemoveWorktreeResponse.$_createMessage);
  static RemoveWorktreeResponse? _defaultInstance;

  /// False when it has changes and `force` wasn't set: nothing was touched.
  @$pb.TagNumber(1)
  $core.bool get removed => $_getBF(0);
  @$pb.TagNumber(1)
  set removed($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRemoved() => $_has(0);
  @$pb.TagNumber(1)
  void clearRemoved() => $_clearField(1);

  /// Files with changes, when that's why it wasn't removed.
  @$pb.TagNumber(2)
  $core.int get changedFiles => $_getIZ(1);
  @$pb.TagNumber(2)
  set changedFiles($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChangedFiles() => $_has(1);
  @$pb.TagNumber(2)
  void clearChangedFiles() => $_clearField(2);

  /// `delete_branch` was set but the branch stays: why (e.g. not merged).
  @$pb.TagNumber(3)
  $core.String get branchKept => $_getSZ(2);
  @$pb.TagNumber(3)
  set branchKept($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBranchKept() => $_has(2);
  @$pb.TagNumber(3)
  void clearBranchKept() => $_clearField(3);
}

class ListBranchesRequest extends $pb.GeneratedMessage {
  factory ListBranchesRequest({
    $core.String? repoPath,
  }) {
    final result = ListBranchesRequest._();
    if (repoPath != null) result.repoPath = repoPath;
    return result;
  }

  ListBranchesRequest._();

  factory ListBranchesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListBranchesRequest()..mergeFromBuffer(data, registry);
  factory ListBranchesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListBranchesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListBranchesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ListBranchesRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'repoPath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBranchesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBranchesRequest copyWith(void Function(ListBranchesRequest) updates) =>
      super.copyWith((message) => updates(message as ListBranchesRequest))
          as ListBranchesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use ListBranchesRequest() / ListBranchesRequest.new instead')
  static ListBranchesRequest create() => ListBranchesRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListBranchesRequest._();
  @$core.override
  ListBranchesRequest createEmptyInstance() => ListBranchesRequest._();
  @$core.pragma('dart2js:noInline')
  static ListBranchesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListBranchesRequest>(
          ListBranchesRequest.$_createMessage);
  static ListBranchesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get repoPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set repoPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRepoPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearRepoPath() => $_clearField(1);
}

class ListBranchesResponse extends $pb.GeneratedMessage {
  factory ListBranchesResponse({
    $core.String? current,
    $core.Iterable<$core.String>? local,
    $core.Iterable<$core.String>? remote,
  }) {
    final result = ListBranchesResponse._();
    if (current != null) result.current = current;
    if (local != null) result.local.addAll(local);
    if (remote != null) result.remote.addAll(remote);
    return result;
  }

  ListBranchesResponse._();

  factory ListBranchesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListBranchesResponse()..mergeFromBuffer(data, registry);
  factory ListBranchesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListBranchesResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListBranchesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ListBranchesResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'current')
    ..pPS(2, _omitFieldNames ? '' : 'local')
    ..pPS(3, _omitFieldNames ? '' : 'remote')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBranchesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBranchesResponse copyWith(void Function(ListBranchesResponse) updates) =>
      super.copyWith((message) => updates(message as ListBranchesResponse))
          as ListBranchesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListBranchesResponse() / ListBranchesResponse.new instead')
  static ListBranchesResponse create() => ListBranchesResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListBranchesResponse._();
  @$core.override
  ListBranchesResponse createEmptyInstance() => ListBranchesResponse._();
  @$core.pragma('dart2js:noInline')
  static ListBranchesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListBranchesResponse>(
          ListBranchesResponse.$_createMessage);
  static ListBranchesResponse? _defaultInstance;

  /// Branch checked out in the main checkout; empty if detached.
  @$pb.TagNumber(1)
  $core.String get current => $_getSZ(0);
  @$pb.TagNumber(1)
  set current($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCurrent() => $_has(0);
  @$pb.TagNumber(1)
  void clearCurrent() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get local => $_getList(1);

  /// e.g. "origin/feat/x", without the remotes' HEAD aliases.
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get remote => $_getList(2);
}

class WorktreeRequest extends $pb.GeneratedMessage {
  factory WorktreeRequest({
    $core.String? worktreePath,
  }) {
    final result = WorktreeRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    return result;
  }

  WorktreeRequest._();

  factory WorktreeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorktreeRequest()..mergeFromBuffer(data, registry);
  factory WorktreeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorktreeRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorktreeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: WorktreeRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorktreeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorktreeRequest copyWith(void Function(WorktreeRequest) updates) =>
      super.copyWith((message) => updates(message as WorktreeRequest))
          as WorktreeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WorktreeRequest() / WorktreeRequest.new instead')
  static WorktreeRequest create() => WorktreeRequest._();
  static $pb.GeneratedMessage $_createMessage() => WorktreeRequest._();
  @$core.override
  WorktreeRequest createEmptyInstance() => WorktreeRequest._();
  @$core.pragma('dart2js:noInline')
  static WorktreeRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WorktreeRequest>(
          WorktreeRequest.$_createMessage);
  static WorktreeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);
}

class WatchStatusRequest extends $pb.GeneratedMessage {
  factory WatchStatusRequest({
    $core.String? worktreePath,
  }) {
    final result = WatchStatusRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    return result;
  }

  WatchStatusRequest._();

  factory WatchStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchStatusRequest()..mergeFromBuffer(data, registry);
  factory WatchStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchStatusRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WatchStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: WatchStatusRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchStatusRequest copyWith(void Function(WatchStatusRequest) updates) =>
      super.copyWith((message) => updates(message as WatchStatusRequest))
          as WatchStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WatchStatusRequest() / WatchStatusRequest.new instead')
  static WatchStatusRequest create() => WatchStatusRequest._();
  static $pb.GeneratedMessage $_createMessage() => WatchStatusRequest._();
  @$core.override
  WatchStatusRequest createEmptyInstance() => WatchStatusRequest._();
  @$core.pragma('dart2js:noInline')
  static WatchStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WatchStatusRequest>(
          WatchStatusRequest.$_createMessage);
  static WatchStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);
}

class FileChange extends $pb.GeneratedMessage {
  factory FileChange({
    $core.String? path,
    $core.String? oldPath,
    ChangeKind? staged,
    ChangeKind? unstaged,
    $core.bool? conflict,
    $core.int? additions,
    $core.int? deletions,
    $core.bool? binary,
  }) {
    final result = FileChange._();
    if (path != null) result.path = path;
    if (oldPath != null) result.oldPath = oldPath;
    if (staged != null) result.staged = staged;
    if (unstaged != null) result.unstaged = unstaged;
    if (conflict != null) result.conflict = conflict;
    if (additions != null) result.additions = additions;
    if (deletions != null) result.deletions = deletions;
    if (binary != null) result.binary = binary;
    return result;
  }

  FileChange._();

  factory FileChange.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FileChange()..mergeFromBuffer(data, registry);
  factory FileChange.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FileChange()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FileChange',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: FileChange.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'oldPath')
    ..aE<ChangeKind>(3, _omitFieldNames ? '' : 'staged',
        enumValues: ChangeKind.values)
    ..aE<ChangeKind>(4, _omitFieldNames ? '' : 'unstaged',
        enumValues: ChangeKind.values)
    ..aOB(5, _omitFieldNames ? '' : 'conflict')
    ..aI(6, _omitFieldNames ? '' : 'additions', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'deletions', fieldType: $pb.PbFieldType.OU3)
    ..aOB(8, _omitFieldNames ? '' : 'binary')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileChange clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileChange copyWith(void Function(FileChange) updates) =>
      super.copyWith((message) => updates(message as FileChange)) as FileChange;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FileChange() / FileChange.new instead')
  static FileChange create() => FileChange._();
  static $pb.GeneratedMessage $_createMessage() => FileChange._();
  @$core.override
  FileChange createEmptyInstance() => FileChange._();
  @$core.pragma('dart2js:noInline')
  static FileChange getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FileChange>(FileChange.$_createMessage);
  static FileChange? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  /// Renames: where it came from.
  @$pb.TagNumber(2)
  $core.String get oldPath => $_getSZ(1);
  @$pb.TagNumber(2)
  set oldPath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOldPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearOldPath() => $_clearField(2);

  /// Staged (index vs HEAD) and unstaged (working tree vs index) changes.
  @$pb.TagNumber(3)
  ChangeKind get staged => $_getN(2);
  @$pb.TagNumber(3)
  set staged(ChangeKind value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStaged() => $_has(2);
  @$pb.TagNumber(3)
  void clearStaged() => $_clearField(3);

  @$pb.TagNumber(4)
  ChangeKind get unstaged => $_getN(3);
  @$pb.TagNumber(4)
  set unstaged(ChangeKind value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasUnstaged() => $_has(3);
  @$pb.TagNumber(4)
  void clearUnstaged() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get conflict => $_getBF(4);
  @$pb.TagNumber(5)
  set conflict($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasConflict() => $_has(4);
  @$pb.TagNumber(5)
  void clearConflict() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get additions => $_getIZ(5);
  @$pb.TagNumber(6)
  set additions($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAdditions() => $_has(5);
  @$pb.TagNumber(6)
  void clearAdditions() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get deletions => $_getIZ(6);
  @$pb.TagNumber(7)
  set deletions($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDeletions() => $_has(6);
  @$pb.TagNumber(7)
  void clearDeletions() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get binary => $_getBF(7);
  @$pb.TagNumber(8)
  set binary($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBinary() => $_has(7);
  @$pb.TagNumber(8)
  void clearBinary() => $_clearField(8);
}

class WorktreeChanges extends $pb.GeneratedMessage {
  factory WorktreeChanges({
    $core.String? branch,
    $core.String? upstream,
    $core.int? ahead,
    $core.int? behind,
    $core.Iterable<FileChange>? working,
    $core.String? base,
    $core.Iterable<FileChange>? committed,
  }) {
    final result = WorktreeChanges._();
    if (branch != null) result.branch = branch;
    if (upstream != null) result.upstream = upstream;
    if (ahead != null) result.ahead = ahead;
    if (behind != null) result.behind = behind;
    if (working != null) result.working.addAll(working);
    if (base != null) result.base = base;
    if (committed != null) result.committed.addAll(committed);
    return result;
  }

  WorktreeChanges._();

  factory WorktreeChanges.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorktreeChanges()..mergeFromBuffer(data, registry);
  factory WorktreeChanges.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorktreeChanges()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorktreeChanges',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: WorktreeChanges.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'branch')
    ..aOS(2, _omitFieldNames ? '' : 'upstream')
    ..aI(3, _omitFieldNames ? '' : 'ahead', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'behind', fieldType: $pb.PbFieldType.OU3)
    ..pPM<FileChange>(5, _omitFieldNames ? '' : 'working',
        subBuilder: FileChange.$_createMessage)
    ..aOS(6, _omitFieldNames ? '' : 'base')
    ..pPM<FileChange>(7, _omitFieldNames ? '' : 'committed',
        subBuilder: FileChange.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorktreeChanges clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorktreeChanges copyWith(void Function(WorktreeChanges) updates) =>
      super.copyWith((message) => updates(message as WorktreeChanges))
          as WorktreeChanges;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WorktreeChanges() / WorktreeChanges.new instead')
  static WorktreeChanges create() => WorktreeChanges._();
  static $pb.GeneratedMessage $_createMessage() => WorktreeChanges._();
  @$core.override
  WorktreeChanges createEmptyInstance() => WorktreeChanges._();
  @$core.pragma('dart2js:noInline')
  static WorktreeChanges getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WorktreeChanges>(
          WorktreeChanges.$_createMessage);
  static WorktreeChanges? _defaultInstance;

  /// Empty when HEAD is detached.
  @$pb.TagNumber(1)
  $core.String get branch => $_getSZ(0);
  @$pb.TagNumber(1)
  set branch($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBranch() => $_has(0);
  @$pb.TagNumber(1)
  void clearBranch() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get upstream => $_getSZ(1);
  @$pb.TagNumber(2)
  set upstream($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUpstream() => $_has(1);
  @$pb.TagNumber(2)
  void clearUpstream() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get ahead => $_getIZ(2);
  @$pb.TagNumber(3)
  set ahead($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAhead() => $_has(2);
  @$pb.TagNumber(3)
  void clearAhead() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get behind => $_getIZ(3);
  @$pb.TagNumber(4)
  set behind($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBehind() => $_has(3);
  @$pb.TagNumber(4)
  void clearBehind() => $_clearField(4);

  /// Uncommitted changes, staged or not.
  @$pb.TagNumber(5)
  $pb.PbList<FileChange> get working => $_getList(4);

  /// Committed on this branch since it left `base` (e.g. "origin/main").
  @$pb.TagNumber(6)
  $core.String get base => $_getSZ(5);
  @$pb.TagNumber(6)
  set base($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBase() => $_has(5);
  @$pb.TagNumber(6)
  void clearBase() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<FileChange> get committed => $_getList(6);
}

class ListFilesRequest extends $pb.GeneratedMessage {
  factory ListFilesRequest({
    $core.String? worktreePath,
  }) {
    final result = ListFilesRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    return result;
  }

  ListFilesRequest._();

  factory ListFilesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListFilesRequest()..mergeFromBuffer(data, registry);
  factory ListFilesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListFilesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListFilesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ListFilesRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListFilesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListFilesRequest copyWith(void Function(ListFilesRequest) updates) =>
      super.copyWith((message) => updates(message as ListFilesRequest))
          as ListFilesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListFilesRequest() / ListFilesRequest.new instead')
  static ListFilesRequest create() => ListFilesRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListFilesRequest._();
  @$core.override
  ListFilesRequest createEmptyInstance() => ListFilesRequest._();
  @$core.pragma('dart2js:noInline')
  static ListFilesRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListFilesRequest>(
          ListFilesRequest.$_createMessage);
  static ListFilesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);
}

class ListFilesResponse extends $pb.GeneratedMessage {
  factory ListFilesResponse({
    $core.Iterable<$core.String>? paths,
    $core.bool? truncated,
  }) {
    final result = ListFilesResponse._();
    if (paths != null) result.paths.addAll(paths);
    if (truncated != null) result.truncated = truncated;
    return result;
  }

  ListFilesResponse._();

  factory ListFilesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListFilesResponse()..mergeFromBuffer(data, registry);
  factory ListFilesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListFilesResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListFilesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ListFilesResponse.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'paths')
    ..aOB(2, _omitFieldNames ? '' : 'truncated')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListFilesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListFilesResponse copyWith(void Function(ListFilesResponse) updates) =>
      super.copyWith((message) => updates(message as ListFilesResponse))
          as ListFilesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListFilesResponse() / ListFilesResponse.new instead')
  static ListFilesResponse create() => ListFilesResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListFilesResponse._();
  @$core.override
  ListFilesResponse createEmptyInstance() => ListFilesResponse._();
  @$core.pragma('dart2js:noInline')
  static ListFilesResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListFilesResponse>(
          ListFilesResponse.$_createMessage);
  static ListFilesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get paths => $_getList(0);

  /// More files than the daemon lists at once.
  @$pb.TagNumber(2)
  $core.bool get truncated => $_getBF(1);
  @$pb.TagNumber(2)
  set truncated($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTruncated() => $_has(1);
  @$pb.TagNumber(2)
  void clearTruncated() => $_clearField(2);
}

class ReadFileRequest extends $pb.GeneratedMessage {
  factory ReadFileRequest({
    $core.String? worktreePath,
    $core.String? path,
  }) {
    final result = ReadFileRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (path != null) result.path = path;
    return result;
  }

  ReadFileRequest._();

  factory ReadFileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReadFileRequest()..mergeFromBuffer(data, registry);
  factory ReadFileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReadFileRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReadFileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ReadFileRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..aOS(2, _omitFieldNames ? '' : 'path')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReadFileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReadFileRequest copyWith(void Function(ReadFileRequest) updates) =>
      super.copyWith((message) => updates(message as ReadFileRequest))
          as ReadFileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReadFileRequest() / ReadFileRequest.new instead')
  static ReadFileRequest create() => ReadFileRequest._();
  static $pb.GeneratedMessage $_createMessage() => ReadFileRequest._();
  @$core.override
  ReadFileRequest createEmptyInstance() => ReadFileRequest._();
  @$core.pragma('dart2js:noInline')
  static ReadFileRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ReadFileRequest>(
          ReadFileRequest.$_createMessage);
  static ReadFileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get path => $_getSZ(1);
  @$pb.TagNumber(2)
  set path($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearPath() => $_clearField(2);
}

class ReadFileResponse extends $pb.GeneratedMessage {
  factory ReadFileResponse({
    $core.List<$core.int>? content,
    $core.bool? binary,
    $core.bool? truncated,
    $fixnum.Int64? size,
  }) {
    final result = ReadFileResponse._();
    if (content != null) result.content = content;
    if (binary != null) result.binary = binary;
    if (truncated != null) result.truncated = truncated;
    if (size != null) result.size = size;
    return result;
  }

  ReadFileResponse._();

  factory ReadFileResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReadFileResponse()..mergeFromBuffer(data, registry);
  factory ReadFileResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReadFileResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReadFileResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ReadFileResponse.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'content', $pb.PbFieldType.OY)
    ..aOB(2, _omitFieldNames ? '' : 'binary')
    ..aOB(3, _omitFieldNames ? '' : 'truncated')
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'size', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReadFileResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReadFileResponse copyWith(void Function(ReadFileResponse) updates) =>
      super.copyWith((message) => updates(message as ReadFileResponse))
          as ReadFileResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReadFileResponse() / ReadFileResponse.new instead')
  static ReadFileResponse create() => ReadFileResponse._();
  static $pb.GeneratedMessage $_createMessage() => ReadFileResponse._();
  @$core.override
  ReadFileResponse createEmptyInstance() => ReadFileResponse._();
  @$core.pragma('dart2js:noInline')
  static ReadFileResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ReadFileResponse>(
          ReadFileResponse.$_createMessage);
  static ReadFileResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get content => $_getN(0);
  @$pb.TagNumber(1)
  set content($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasContent() => $_has(0);
  @$pb.TagNumber(1)
  void clearContent() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get binary => $_getBF(1);
  @$pb.TagNumber(2)
  set binary($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBinary() => $_has(1);
  @$pb.TagNumber(2)
  void clearBinary() => $_clearField(2);

  /// Only the first bytes were sent (big file).
  @$pb.TagNumber(3)
  $core.bool get truncated => $_getBF(2);
  @$pb.TagNumber(3)
  set truncated($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTruncated() => $_has(2);
  @$pb.TagNumber(3)
  void clearTruncated() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get size => $_getI64(3);
  @$pb.TagNumber(4)
  set size($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearSize() => $_clearField(4);
}

class WriteFileRequest extends $pb.GeneratedMessage {
  factory WriteFileRequest({
    $core.String? worktreePath,
    $core.String? path,
    $core.List<$core.int>? content,
  }) {
    final result = WriteFileRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (path != null) result.path = path;
    if (content != null) result.content = content;
    return result;
  }

  WriteFileRequest._();

  factory WriteFileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteFileRequest()..mergeFromBuffer(data, registry);
  factory WriteFileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteFileRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WriteFileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: WriteFileRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..aOS(2, _omitFieldNames ? '' : 'path')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'content', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteFileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteFileRequest copyWith(void Function(WriteFileRequest) updates) =>
      super.copyWith((message) => updates(message as WriteFileRequest))
          as WriteFileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WriteFileRequest() / WriteFileRequest.new instead')
  static WriteFileRequest create() => WriteFileRequest._();
  static $pb.GeneratedMessage $_createMessage() => WriteFileRequest._();
  @$core.override
  WriteFileRequest createEmptyInstance() => WriteFileRequest._();
  @$core.pragma('dart2js:noInline')
  static WriteFileRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WriteFileRequest>(
          WriteFileRequest.$_createMessage);
  static WriteFileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get path => $_getSZ(1);
  @$pb.TagNumber(2)
  set path($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearPath() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get content => $_getN(2);
  @$pb.TagNumber(3)
  set content($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContent() => $_has(2);
  @$pb.TagNumber(3)
  void clearContent() => $_clearField(3);
}

class WriteFileResponse extends $pb.GeneratedMessage {
  factory WriteFileResponse() => WriteFileResponse._();

  WriteFileResponse._();

  factory WriteFileResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteFileResponse()..mergeFromBuffer(data, registry);
  factory WriteFileResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteFileResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WriteFileResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: WriteFileResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteFileResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteFileResponse copyWith(void Function(WriteFileResponse) updates) =>
      super.copyWith((message) => updates(message as WriteFileResponse))
          as WriteFileResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WriteFileResponse() / WriteFileResponse.new instead')
  static WriteFileResponse create() => WriteFileResponse._();
  static $pb.GeneratedMessage $_createMessage() => WriteFileResponse._();
  @$core.override
  WriteFileResponse createEmptyInstance() => WriteFileResponse._();
  @$core.pragma('dart2js:noInline')
  static WriteFileResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WriteFileResponse>(
          WriteFileResponse.$_createMessage);
  static WriteFileResponse? _defaultInstance;
}

class MovePathRequest extends $pb.GeneratedMessage {
  factory MovePathRequest({
    $core.String? worktreePath,
    $core.String? from,
    $core.String? to,
  }) {
    final result = MovePathRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (from != null) result.from = from;
    if (to != null) result.to = to;
    return result;
  }

  MovePathRequest._();

  factory MovePathRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MovePathRequest()..mergeFromBuffer(data, registry);
  factory MovePathRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MovePathRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MovePathRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: MovePathRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..aOS(2, _omitFieldNames ? '' : 'from')
    ..aOS(3, _omitFieldNames ? '' : 'to')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MovePathRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MovePathRequest copyWith(void Function(MovePathRequest) updates) =>
      super.copyWith((message) => updates(message as MovePathRequest))
          as MovePathRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MovePathRequest() / MovePathRequest.new instead')
  static MovePathRequest create() => MovePathRequest._();
  static $pb.GeneratedMessage $_createMessage() => MovePathRequest._();
  @$core.override
  MovePathRequest createEmptyInstance() => MovePathRequest._();
  @$core.pragma('dart2js:noInline')
  static MovePathRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MovePathRequest>(
          MovePathRequest.$_createMessage);
  static MovePathRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get from => $_getSZ(1);
  @$pb.TagNumber(2)
  set from($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFrom() => $_has(1);
  @$pb.TagNumber(2)
  void clearFrom() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get to => $_getSZ(2);
  @$pb.TagNumber(3)
  set to($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTo() => $_has(2);
  @$pb.TagNumber(3)
  void clearTo() => $_clearField(3);
}

class DiffRequest extends $pb.GeneratedMessage {
  factory DiffRequest({
    $core.String? worktreePath,
    $core.String? path,
    DiffScope? scope,
  }) {
    final result = DiffRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (path != null) result.path = path;
    if (scope != null) result.scope = scope;
    return result;
  }

  DiffRequest._();

  factory DiffRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DiffRequest()..mergeFromBuffer(data, registry);
  factory DiffRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DiffRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiffRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DiffRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..aOS(2, _omitFieldNames ? '' : 'path')
    ..aE<DiffScope>(3, _omitFieldNames ? '' : 'scope',
        enumValues: DiffScope.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiffRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiffRequest copyWith(void Function(DiffRequest) updates) =>
      super.copyWith((message) => updates(message as DiffRequest))
          as DiffRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DiffRequest() / DiffRequest.new instead')
  static DiffRequest create() => DiffRequest._();
  static $pb.GeneratedMessage $_createMessage() => DiffRequest._();
  @$core.override
  DiffRequest createEmptyInstance() => DiffRequest._();
  @$core.pragma('dart2js:noInline')
  static DiffRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DiffRequest>(
          DiffRequest.$_createMessage);
  static DiffRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get path => $_getSZ(1);
  @$pb.TagNumber(2)
  set path($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearPath() => $_clearField(2);

  @$pb.TagNumber(3)
  DiffScope get scope => $_getN(2);
  @$pb.TagNumber(3)
  set scope(DiffScope value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasScope() => $_has(2);
  @$pb.TagNumber(3)
  void clearScope() => $_clearField(3);
}

class DiffLine extends $pb.GeneratedMessage {
  factory DiffLine({
    DiffLineKind? kind,
    $core.String? text,
  }) {
    final result = DiffLine._();
    if (kind != null) result.kind = kind;
    if (text != null) result.text = text;
    return result;
  }

  DiffLine._();

  factory DiffLine.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DiffLine()..mergeFromBuffer(data, registry);
  factory DiffLine.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DiffLine()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiffLine',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DiffLine.$_createMessage)
    ..aE<DiffLineKind>(1, _omitFieldNames ? '' : 'kind',
        enumValues: DiffLineKind.values)
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiffLine clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiffLine copyWith(void Function(DiffLine) updates) =>
      super.copyWith((message) => updates(message as DiffLine)) as DiffLine;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DiffLine() / DiffLine.new instead')
  static DiffLine create() => DiffLine._();
  static $pb.GeneratedMessage $_createMessage() => DiffLine._();
  @$core.override
  DiffLine createEmptyInstance() => DiffLine._();
  @$core.pragma('dart2js:noInline')
  static DiffLine getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DiffLine>(DiffLine.$_createMessage);
  static DiffLine? _defaultInstance;

  @$pb.TagNumber(1)
  DiffLineKind get kind => $_getN(0);
  @$pb.TagNumber(1)
  set kind(DiffLineKind value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);
}

class DiffResponse extends $pb.GeneratedMessage {
  factory DiffResponse({
    $core.Iterable<DiffLine>? lines,
    $core.bool? binary,
  }) {
    final result = DiffResponse._();
    if (lines != null) result.lines.addAll(lines);
    if (binary != null) result.binary = binary;
    return result;
  }

  DiffResponse._();

  factory DiffResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DiffResponse()..mergeFromBuffer(data, registry);
  factory DiffResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DiffResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiffResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DiffResponse.$_createMessage)
    ..pPM<DiffLine>(1, _omitFieldNames ? '' : 'lines',
        subBuilder: DiffLine.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'binary')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiffResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiffResponse copyWith(void Function(DiffResponse) updates) =>
      super.copyWith((message) => updates(message as DiffResponse))
          as DiffResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DiffResponse() / DiffResponse.new instead')
  static DiffResponse create() => DiffResponse._();
  static $pb.GeneratedMessage $_createMessage() => DiffResponse._();
  @$core.override
  DiffResponse createEmptyInstance() => DiffResponse._();
  @$core.pragma('dart2js:noInline')
  static DiffResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DiffResponse>(
          DiffResponse.$_createMessage);
  static DiffResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DiffLine> get lines => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get binary => $_getBF(1);
  @$pb.TagNumber(2)
  set binary($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBinary() => $_has(1);
  @$pb.TagNumber(2)
  void clearBinary() => $_clearField(2);
}

class PathsRequest extends $pb.GeneratedMessage {
  factory PathsRequest({
    $core.String? worktreePath,
    $core.Iterable<$core.String>? paths,
  }) {
    final result = PathsRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (paths != null) result.paths.addAll(paths);
    return result;
  }

  PathsRequest._();

  factory PathsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PathsRequest()..mergeFromBuffer(data, registry);
  factory PathsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PathsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PathsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: PathsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..pPS(2, _omitFieldNames ? '' : 'paths')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PathsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PathsRequest copyWith(void Function(PathsRequest) updates) =>
      super.copyWith((message) => updates(message as PathsRequest))
          as PathsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PathsRequest() / PathsRequest.new instead')
  static PathsRequest create() => PathsRequest._();
  static $pb.GeneratedMessage $_createMessage() => PathsRequest._();
  @$core.override
  PathsRequest createEmptyInstance() => PathsRequest._();
  @$core.pragma('dart2js:noInline')
  static PathsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PathsRequest>(
          PathsRequest.$_createMessage);
  static PathsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get paths => $_getList(1);
}

class GitActionResponse extends $pb.GeneratedMessage {
  factory GitActionResponse() => GitActionResponse._();

  GitActionResponse._();

  factory GitActionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitActionResponse()..mergeFromBuffer(data, registry);
  factory GitActionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitActionResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitActionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: GitActionResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitActionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitActionResponse copyWith(void Function(GitActionResponse) updates) =>
      super.copyWith((message) => updates(message as GitActionResponse))
          as GitActionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitActionResponse() / GitActionResponse.new instead')
  static GitActionResponse create() => GitActionResponse._();
  static $pb.GeneratedMessage $_createMessage() => GitActionResponse._();
  @$core.override
  GitActionResponse createEmptyInstance() => GitActionResponse._();
  @$core.pragma('dart2js:noInline')
  static GitActionResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GitActionResponse>(
          GitActionResponse.$_createMessage);
  static GitActionResponse? _defaultInstance;
}

class CommitRequest extends $pb.GeneratedMessage {
  factory CommitRequest({
    $core.String? worktreePath,
    $core.String? message,
    $core.bool? all,
    $core.bool? amend,
  }) {
    final result = CommitRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (message != null) result.message = message;
    if (all != null) result.all = all;
    if (amend != null) result.amend = amend;
    return result;
  }

  CommitRequest._();

  factory CommitRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommitRequest()..mergeFromBuffer(data, registry);
  factory CommitRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommitRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommitRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: CommitRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aOB(3, _omitFieldNames ? '' : 'all')
    ..aOB(4, _omitFieldNames ? '' : 'amend')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommitRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommitRequest copyWith(void Function(CommitRequest) updates) =>
      super.copyWith((message) => updates(message as CommitRequest))
          as CommitRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommitRequest() / CommitRequest.new instead')
  static CommitRequest create() => CommitRequest._();
  static $pb.GeneratedMessage $_createMessage() => CommitRequest._();
  @$core.override
  CommitRequest createEmptyInstance() => CommitRequest._();
  @$core.pragma('dart2js:noInline')
  static CommitRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CommitRequest>(
          CommitRequest.$_createMessage);
  static CommitRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);

  /// Stage every change first (`git add -A`).
  @$pb.TagNumber(3)
  $core.bool get all => $_getBF(2);
  @$pb.TagNumber(3)
  set all($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAll() => $_has(2);
  @$pb.TagNumber(3)
  void clearAll() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get amend => $_getBF(3);
  @$pb.TagNumber(4)
  set amend($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAmend() => $_has(3);
  @$pb.TagNumber(4)
  void clearAmend() => $_clearField(4);
}

class CommitResponse extends $pb.GeneratedMessage {
  factory CommitResponse({
    $core.String? sha,
    $core.String? shortSha,
  }) {
    final result = CommitResponse._();
    if (sha != null) result.sha = sha;
    if (shortSha != null) result.shortSha = shortSha;
    return result;
  }

  CommitResponse._();

  factory CommitResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommitResponse()..mergeFromBuffer(data, registry);
  factory CommitResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommitResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommitResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: CommitResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sha')
    ..aOS(2, _omitFieldNames ? '' : 'shortSha')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommitResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommitResponse copyWith(void Function(CommitResponse) updates) =>
      super.copyWith((message) => updates(message as CommitResponse))
          as CommitResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommitResponse() / CommitResponse.new instead')
  static CommitResponse create() => CommitResponse._();
  static $pb.GeneratedMessage $_createMessage() => CommitResponse._();
  @$core.override
  CommitResponse createEmptyInstance() => CommitResponse._();
  @$core.pragma('dart2js:noInline')
  static CommitResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CommitResponse>(
          CommitResponse.$_createMessage);
  static CommitResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sha => $_getSZ(0);
  @$pb.TagNumber(1)
  set sha($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSha() => $_has(0);
  @$pb.TagNumber(1)
  void clearSha() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get shortSha => $_getSZ(1);
  @$pb.TagNumber(2)
  set shortSha($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasShortSha() => $_has(1);
  @$pb.TagNumber(2)
  void clearShortSha() => $_clearField(2);
}

class LogRequest extends $pb.GeneratedMessage {
  factory LogRequest({
    $core.String? worktreePath,
    $core.int? limit,
  }) {
    final result = LogRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (limit != null) result.limit = limit;
    return result;
  }

  LogRequest._();

  factory LogRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LogRequest()..mergeFromBuffer(data, registry);
  factory LogRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LogRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: LogRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..aI(2, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogRequest copyWith(void Function(LogRequest) updates) =>
      super.copyWith((message) => updates(message as LogRequest)) as LogRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LogRequest() / LogRequest.new instead')
  static LogRequest create() => LogRequest._();
  static $pb.GeneratedMessage $_createMessage() => LogRequest._();
  @$core.override
  LogRequest createEmptyInstance() => LogRequest._();
  @$core.pragma('dart2js:noInline')
  static LogRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LogRequest>(LogRequest.$_createMessage);
  static LogRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get limit => $_getIZ(1);
  @$pb.TagNumber(2)
  set limit($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLimit() => $_has(1);
  @$pb.TagNumber(2)
  void clearLimit() => $_clearField(2);
}

class Commit extends $pb.GeneratedMessage {
  factory Commit({
    $core.String? sha,
    $core.String? shortSha,
    $core.String? subject,
    $core.String? author,
    $fixnum.Int64? timeUnix,
  }) {
    final result = Commit._();
    if (sha != null) result.sha = sha;
    if (shortSha != null) result.shortSha = shortSha;
    if (subject != null) result.subject = subject;
    if (author != null) result.author = author;
    if (timeUnix != null) result.timeUnix = timeUnix;
    return result;
  }

  Commit._();

  factory Commit.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Commit()..mergeFromBuffer(data, registry);
  factory Commit.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Commit()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Commit',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: Commit.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sha')
    ..aOS(2, _omitFieldNames ? '' : 'shortSha')
    ..aOS(3, _omitFieldNames ? '' : 'subject')
    ..aOS(4, _omitFieldNames ? '' : 'author')
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'timeUnix', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Commit clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Commit copyWith(void Function(Commit) updates) =>
      super.copyWith((message) => updates(message as Commit)) as Commit;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Commit() / Commit.new instead')
  static Commit create() => Commit._();
  static $pb.GeneratedMessage $_createMessage() => Commit._();
  @$core.override
  Commit createEmptyInstance() => Commit._();
  @$core.pragma('dart2js:noInline')
  static Commit getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Commit>(Commit.$_createMessage);
  static Commit? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sha => $_getSZ(0);
  @$pb.TagNumber(1)
  set sha($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSha() => $_has(0);
  @$pb.TagNumber(1)
  void clearSha() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get shortSha => $_getSZ(1);
  @$pb.TagNumber(2)
  set shortSha($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasShortSha() => $_has(1);
  @$pb.TagNumber(2)
  void clearShortSha() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get subject => $_getSZ(2);
  @$pb.TagNumber(3)
  set subject($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubject() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubject() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get author => $_getSZ(3);
  @$pb.TagNumber(4)
  set author($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAuthor() => $_has(3);
  @$pb.TagNumber(4)
  void clearAuthor() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timeUnix => $_getI64(4);
  @$pb.TagNumber(5)
  set timeUnix($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTimeUnix() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimeUnix() => $_clearField(5);
}

class LogResponse extends $pb.GeneratedMessage {
  factory LogResponse({
    $core.Iterable<Commit>? commits,
  }) {
    final result = LogResponse._();
    if (commits != null) result.commits.addAll(commits);
    return result;
  }

  LogResponse._();

  factory LogResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LogResponse()..mergeFromBuffer(data, registry);
  factory LogResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LogResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: LogResponse.$_createMessage)
    ..pPM<Commit>(1, _omitFieldNames ? '' : 'commits',
        subBuilder: Commit.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogResponse copyWith(void Function(LogResponse) updates) =>
      super.copyWith((message) => updates(message as LogResponse))
          as LogResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LogResponse() / LogResponse.new instead')
  static LogResponse create() => LogResponse._();
  static $pb.GeneratedMessage $_createMessage() => LogResponse._();
  @$core.override
  LogResponse createEmptyInstance() => LogResponse._();
  @$core.pragma('dart2js:noInline')
  static LogResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LogResponse>(
          LogResponse.$_createMessage);
  static LogResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Commit> get commits => $_getList(0);
}

class AgentProvider extends $pb.GeneratedMessage {
  factory AgentProvider({
    $core.String? id,
    $core.String? name,
    $core.String? short,
    $core.String? program,
    $core.String? args,
    $core.bool? custom,
    $core.bool? enabled,
    $core.bool? isDefault,
    $core.bool? installed,
    $core.String? resolvedPath,
    $core.String? installHint,
    $core.bool? takesPromptArgument,
    $core.bool? hasLogin,
    $core.bool? usageReadable,
    $core.bool? readUsage,
  }) {
    final result = AgentProvider._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (short != null) result.short = short;
    if (program != null) result.program = program;
    if (args != null) result.args = args;
    if (custom != null) result.custom = custom;
    if (enabled != null) result.enabled = enabled;
    if (isDefault != null) result.isDefault = isDefault;
    if (installed != null) result.installed = installed;
    if (resolvedPath != null) result.resolvedPath = resolvedPath;
    if (installHint != null) result.installHint = installHint;
    if (takesPromptArgument != null)
      result.takesPromptArgument = takesPromptArgument;
    if (hasLogin != null) result.hasLogin = hasLogin;
    if (usageReadable != null) result.usageReadable = usageReadable;
    if (readUsage != null) result.readUsage = readUsage;
    return result;
  }

  AgentProvider._();

  factory AgentProvider.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentProvider()..mergeFromBuffer(data, registry);
  factory AgentProvider.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentProvider()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentProvider',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: AgentProvider.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'short')
    ..aOS(4, _omitFieldNames ? '' : 'program')
    ..aOS(5, _omitFieldNames ? '' : 'args')
    ..aOB(6, _omitFieldNames ? '' : 'custom')
    ..aOB(7, _omitFieldNames ? '' : 'enabled')
    ..aOB(8, _omitFieldNames ? '' : 'isDefault')
    ..aOB(9, _omitFieldNames ? '' : 'installed')
    ..aOS(10, _omitFieldNames ? '' : 'resolvedPath')
    ..aOS(11, _omitFieldNames ? '' : 'installHint')
    ..aOB(12, _omitFieldNames ? '' : 'takesPromptArgument')
    ..aOB(13, _omitFieldNames ? '' : 'hasLogin')
    ..aOB(14, _omitFieldNames ? '' : 'usageReadable')
    ..aOB(15, _omitFieldNames ? '' : 'readUsage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentProvider clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentProvider copyWith(void Function(AgentProvider) updates) =>
      super.copyWith((message) => updates(message as AgentProvider))
          as AgentProvider;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AgentProvider() / AgentProvider.new instead')
  static AgentProvider create() => AgentProvider._();
  static $pb.GeneratedMessage $_createMessage() => AgentProvider._();
  @$core.override
  AgentProvider createEmptyInstance() => AgentProvider._();
  @$core.pragma('dart2js:noInline')
  static AgentProvider getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AgentProvider>(
          AgentProvider.$_createMessage);
  static AgentProvider? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  /// Two-letter badge, e.g. "CC".
  @$pb.TagNumber(3)
  $core.String get short => $_getSZ(2);
  @$pb.TagNumber(3)
  set short($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasShort() => $_has(2);
  @$pb.TagNumber(3)
  void clearShort() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get program => $_getSZ(3);
  @$pb.TagNumber(4)
  set program($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasProgram() => $_has(3);
  @$pb.TagNumber(4)
  void clearProgram() => $_clearField(4);

  /// Extra arguments, shell-quoted (e.g. "--model x").
  @$pb.TagNumber(5)
  $core.String get args => $_getSZ(4);
  @$pb.TagNumber(5)
  set args($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasArgs() => $_has(4);
  @$pb.TagNumber(5)
  void clearArgs() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get custom => $_getBF(5);
  @$pb.TagNumber(6)
  set custom($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCustom() => $_has(5);
  @$pb.TagNumber(6)
  void clearCustom() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get enabled => $_getBF(6);
  @$pb.TagNumber(7)
  set enabled($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEnabled() => $_has(6);
  @$pb.TagNumber(7)
  void clearEnabled() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get isDefault => $_getBF(7);
  @$pb.TagNumber(8)
  set isDefault($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIsDefault() => $_has(7);
  @$pb.TagNumber(8)
  void clearIsDefault() => $_clearField(8);

  /// Found on the user's PATH.
  @$pb.TagNumber(9)
  $core.bool get installed => $_getBF(8);
  @$pb.TagNumber(9)
  set installed($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasInstalled() => $_has(8);
  @$pb.TagNumber(9)
  void clearInstalled() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get resolvedPath => $_getSZ(9);
  @$pb.TagNumber(10)
  set resolvedPath($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasResolvedPath() => $_has(9);
  @$pb.TagNumber(10)
  void clearResolvedPath() => $_clearField(10);

  /// How to install it (known CLIs).
  @$pb.TagNumber(11)
  $core.String get installHint => $_getSZ(10);
  @$pb.TagNumber(11)
  set installHint($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasInstallHint() => $_has(10);
  @$pb.TagNumber(11)
  void clearInstallHint() => $_clearField(11);

  /// The prompt can be passed at start; otherwise Kumo types it in.
  @$pb.TagNumber(12)
  $core.bool get takesPromptArgument => $_getBF(11);
  @$pb.TagNumber(12)
  set takesPromptArgument($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasTakesPromptArgument() => $_has(11);
  @$pb.TagNumber(12)
  void clearTakesPromptArgument() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get hasLogin => $_getBF(12);
  @$pb.TagNumber(13)
  set hasLogin($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasHasLogin() => $_has(12);
  @$pb.TagNumber(13)
  void clearHasLogin() => $_clearField(13);

  /// Kumo can read its plan limits and context window (Claude Code, Codex).
  @$pb.TagNumber(14)
  $core.bool get usageReadable => $_getBF(13);
  @$pb.TagNumber(14)
  set usageReadable($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasUsageReadable() => $_has(13);
  @$pb.TagNumber(14)
  void clearUsageReadable() => $_clearField(14);

  /// The setting: read them ("Read Claude Code's usage through its status
  /// line"). On by default.
  @$pb.TagNumber(15)
  $core.bool get readUsage => $_getBF(14);
  @$pb.TagNumber(15)
  set readUsage($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(15)
  $core.bool hasReadUsage() => $_has(14);
  @$pb.TagNumber(15)
  void clearReadUsage() => $_clearField(15);
}

class ListProvidersRequest extends $pb.GeneratedMessage {
  factory ListProvidersRequest() => ListProvidersRequest._();

  ListProvidersRequest._();

  factory ListProvidersRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListProvidersRequest()..mergeFromBuffer(data, registry);
  factory ListProvidersRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListProvidersRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListProvidersRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ListProvidersRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListProvidersRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListProvidersRequest copyWith(void Function(ListProvidersRequest) updates) =>
      super.copyWith((message) => updates(message as ListProvidersRequest))
          as ListProvidersRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListProvidersRequest() / ListProvidersRequest.new instead')
  static ListProvidersRequest create() => ListProvidersRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListProvidersRequest._();
  @$core.override
  ListProvidersRequest createEmptyInstance() => ListProvidersRequest._();
  @$core.pragma('dart2js:noInline')
  static ListProvidersRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListProvidersRequest>(
          ListProvidersRequest.$_createMessage);
  static ListProvidersRequest? _defaultInstance;
}

class ListProvidersResponse extends $pb.GeneratedMessage {
  factory ListProvidersResponse({
    $core.Iterable<AgentProvider>? providers,
  }) {
    final result = ListProvidersResponse._();
    if (providers != null) result.providers.addAll(providers);
    return result;
  }

  ListProvidersResponse._();

  factory ListProvidersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListProvidersResponse()..mergeFromBuffer(data, registry);
  factory ListProvidersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListProvidersResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListProvidersResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ListProvidersResponse.$_createMessage)
    ..pPM<AgentProvider>(1, _omitFieldNames ? '' : 'providers',
        subBuilder: AgentProvider.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListProvidersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListProvidersResponse copyWith(
          void Function(ListProvidersResponse) updates) =>
      super.copyWith((message) => updates(message as ListProvidersResponse))
          as ListProvidersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListProvidersResponse() / ListProvidersResponse.new instead')
  static ListProvidersResponse create() => ListProvidersResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListProvidersResponse._();
  @$core.override
  ListProvidersResponse createEmptyInstance() => ListProvidersResponse._();
  @$core.pragma('dart2js:noInline')
  static ListProvidersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListProvidersResponse>(
          ListProvidersResponse.$_createMessage);
  static ListProvidersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AgentProvider> get providers => $_getList(0);
}

class SaveProviderRequest extends $pb.GeneratedMessage {
  factory SaveProviderRequest({
    $core.String? id,
    $core.String? name,
    $core.String? program,
    $core.String? args,
    $core.bool? enabled,
    $core.bool? isDefault,
    $core.bool? readUsage,
  }) {
    final result = SaveProviderRequest._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (program != null) result.program = program;
    if (args != null) result.args = args;
    if (enabled != null) result.enabled = enabled;
    if (isDefault != null) result.isDefault = isDefault;
    if (readUsage != null) result.readUsage = readUsage;
    return result;
  }

  SaveProviderRequest._();

  factory SaveProviderRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveProviderRequest()..mergeFromBuffer(data, registry);
  factory SaveProviderRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveProviderRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveProviderRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: SaveProviderRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'program')
    ..aOS(4, _omitFieldNames ? '' : 'args')
    ..aOB(5, _omitFieldNames ? '' : 'enabled')
    ..aOB(6, _omitFieldNames ? '' : 'isDefault')
    ..aOB(7, _omitFieldNames ? '' : 'readUsage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveProviderRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveProviderRequest copyWith(void Function(SaveProviderRequest) updates) =>
      super.copyWith((message) => updates(message as SaveProviderRequest))
          as SaveProviderRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use SaveProviderRequest() / SaveProviderRequest.new instead')
  static SaveProviderRequest create() => SaveProviderRequest._();
  static $pb.GeneratedMessage $_createMessage() => SaveProviderRequest._();
  @$core.override
  SaveProviderRequest createEmptyInstance() => SaveProviderRequest._();
  @$core.pragma('dart2js:noInline')
  static SaveProviderRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SaveProviderRequest>(
          SaveProviderRequest.$_createMessage);
  static SaveProviderRequest? _defaultInstance;

  /// Empty: a new custom provider.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get program => $_getSZ(2);
  @$pb.TagNumber(3)
  set program($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProgram() => $_has(2);
  @$pb.TagNumber(3)
  void clearProgram() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get args => $_getSZ(3);
  @$pb.TagNumber(4)
  set args($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasArgs() => $_has(3);
  @$pb.TagNumber(4)
  void clearArgs() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get enabled => $_getBF(4);
  @$pb.TagNumber(5)
  set enabled($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEnabled() => $_has(4);
  @$pb.TagNumber(5)
  void clearEnabled() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isDefault => $_getBF(5);
  @$pb.TagNumber(6)
  set isDefault($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsDefault() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsDefault() => $_clearField(6);

  /// Unset: unchanged (on for a new provider).
  @$pb.TagNumber(7)
  $core.bool get readUsage => $_getBF(6);
  @$pb.TagNumber(7)
  set readUsage($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasReadUsage() => $_has(6);
  @$pb.TagNumber(7)
  void clearReadUsage() => $_clearField(7);
}

class DeleteProviderRequest extends $pb.GeneratedMessage {
  factory DeleteProviderRequest({
    $core.String? id,
  }) {
    final result = DeleteProviderRequest._();
    if (id != null) result.id = id;
    return result;
  }

  DeleteProviderRequest._();

  factory DeleteProviderRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteProviderRequest()..mergeFromBuffer(data, registry);
  factory DeleteProviderRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteProviderRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteProviderRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DeleteProviderRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProviderRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProviderRequest copyWith(
          void Function(DeleteProviderRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteProviderRequest))
          as DeleteProviderRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DeleteProviderRequest() / DeleteProviderRequest.new instead')
  static DeleteProviderRequest create() => DeleteProviderRequest._();
  static $pb.GeneratedMessage $_createMessage() => DeleteProviderRequest._();
  @$core.override
  DeleteProviderRequest createEmptyInstance() => DeleteProviderRequest._();
  @$core.pragma('dart2js:noInline')
  static DeleteProviderRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteProviderRequest>(
          DeleteProviderRequest.$_createMessage);
  static DeleteProviderRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class DeleteProviderResponse extends $pb.GeneratedMessage {
  factory DeleteProviderResponse() => DeleteProviderResponse._();

  DeleteProviderResponse._();

  factory DeleteProviderResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteProviderResponse()..mergeFromBuffer(data, registry);
  factory DeleteProviderResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteProviderResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteProviderResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DeleteProviderResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProviderResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProviderResponse copyWith(
          void Function(DeleteProviderResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteProviderResponse))
          as DeleteProviderResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DeleteProviderResponse() / DeleteProviderResponse.new instead')
  static DeleteProviderResponse create() => DeleteProviderResponse._();
  static $pb.GeneratedMessage $_createMessage() => DeleteProviderResponse._();
  @$core.override
  DeleteProviderResponse createEmptyInstance() => DeleteProviderResponse._();
  @$core.pragma('dart2js:noInline')
  static DeleteProviderResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteProviderResponse>(
          DeleteProviderResponse.$_createMessage);
  static DeleteProviderResponse? _defaultInstance;
}

class TestProviderRequest extends $pb.GeneratedMessage {
  factory TestProviderRequest({
    $core.String? id,
  }) {
    final result = TestProviderRequest._();
    if (id != null) result.id = id;
    return result;
  }

  TestProviderRequest._();

  factory TestProviderRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestProviderRequest()..mergeFromBuffer(data, registry);
  factory TestProviderRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestProviderRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestProviderRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TestProviderRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestProviderRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestProviderRequest copyWith(void Function(TestProviderRequest) updates) =>
      super.copyWith((message) => updates(message as TestProviderRequest))
          as TestProviderRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use TestProviderRequest() / TestProviderRequest.new instead')
  static TestProviderRequest create() => TestProviderRequest._();
  static $pb.GeneratedMessage $_createMessage() => TestProviderRequest._();
  @$core.override
  TestProviderRequest createEmptyInstance() => TestProviderRequest._();
  @$core.pragma('dart2js:noInline')
  static TestProviderRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TestProviderRequest>(
          TestProviderRequest.$_createMessage);
  static TestProviderRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class TestProviderResponse extends $pb.GeneratedMessage {
  factory TestProviderResponse({
    $core.String? version,
  }) {
    final result = TestProviderResponse._();
    if (version != null) result.version = version;
    return result;
  }

  TestProviderResponse._();

  factory TestProviderResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestProviderResponse()..mergeFromBuffer(data, registry);
  factory TestProviderResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestProviderResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestProviderResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TestProviderResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestProviderResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestProviderResponse copyWith(void Function(TestProviderResponse) updates) =>
      super.copyWith((message) => updates(message as TestProviderResponse))
          as TestProviderResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TestProviderResponse() / TestProviderResponse.new instead')
  static TestProviderResponse create() => TestProviderResponse._();
  static $pb.GeneratedMessage $_createMessage() => TestProviderResponse._();
  @$core.override
  TestProviderResponse createEmptyInstance() => TestProviderResponse._();
  @$core.pragma('dart2js:noInline')
  static TestProviderResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TestProviderResponse>(
          TestProviderResponse.$_createMessage);
  static TestProviderResponse? _defaultInstance;

  /// e.g. "2.1.0 (Claude Code)".
  @$pb.TagNumber(1)
  $core.String get version => $_getSZ(0);
  @$pb.TagNumber(1)
  set version($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);
}

class LoginProviderRequest extends $pb.GeneratedMessage {
  factory LoginProviderRequest({
    $core.String? id,
  }) {
    final result = LoginProviderRequest._();
    if (id != null) result.id = id;
    return result;
  }

  LoginProviderRequest._();

  factory LoginProviderRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoginProviderRequest()..mergeFromBuffer(data, registry);
  factory LoginProviderRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoginProviderRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginProviderRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: LoginProviderRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginProviderRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginProviderRequest copyWith(void Function(LoginProviderRequest) updates) =>
      super.copyWith((message) => updates(message as LoginProviderRequest))
          as LoginProviderRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use LoginProviderRequest() / LoginProviderRequest.new instead')
  static LoginProviderRequest create() => LoginProviderRequest._();
  static $pb.GeneratedMessage $_createMessage() => LoginProviderRequest._();
  @$core.override
  LoginProviderRequest createEmptyInstance() => LoginProviderRequest._();
  @$core.pragma('dart2js:noInline')
  static LoginProviderRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoginProviderRequest>(
          LoginProviderRequest.$_createMessage);
  static LoginProviderRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class LoginProviderResponse extends $pb.GeneratedMessage {
  factory LoginProviderResponse({
    $core.String? terminalId,
  }) {
    final result = LoginProviderResponse._();
    if (terminalId != null) result.terminalId = terminalId;
    return result;
  }

  LoginProviderResponse._();

  factory LoginProviderResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoginProviderResponse()..mergeFromBuffer(data, registry);
  factory LoginProviderResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoginProviderResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginProviderResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: LoginProviderResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'terminalId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginProviderResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginProviderResponse copyWith(
          void Function(LoginProviderResponse) updates) =>
      super.copyWith((message) => updates(message as LoginProviderResponse))
          as LoginProviderResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use LoginProviderResponse() / LoginProviderResponse.new instead')
  static LoginProviderResponse create() => LoginProviderResponse._();
  static $pb.GeneratedMessage $_createMessage() => LoginProviderResponse._();
  @$core.override
  LoginProviderResponse createEmptyInstance() => LoginProviderResponse._();
  @$core.pragma('dart2js:noInline')
  static LoginProviderResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoginProviderResponse>(
          LoginProviderResponse.$_createMessage);
  static LoginProviderResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get terminalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set terminalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTerminalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTerminalId() => $_clearField(1);
}

class StartAgentRequest extends $pb.GeneratedMessage {
  factory StartAgentRequest({
    $core.String? providerId,
    $core.String? worktreePath,
    $core.String? prompt,
    $core.String? title,
    $core.int? cols,
    $core.int? rows,
    $core.Iterable<AgentContext>? context,
  }) {
    final result = StartAgentRequest._();
    if (providerId != null) result.providerId = providerId;
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (prompt != null) result.prompt = prompt;
    if (title != null) result.title = title;
    if (cols != null) result.cols = cols;
    if (rows != null) result.rows = rows;
    if (context != null) result.context.addAll(context);
    return result;
  }

  StartAgentRequest._();

  factory StartAgentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StartAgentRequest()..mergeFromBuffer(data, registry);
  factory StartAgentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StartAgentRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartAgentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: StartAgentRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'providerId')
    ..aOS(2, _omitFieldNames ? '' : 'worktreePath')
    ..aOS(3, _omitFieldNames ? '' : 'prompt')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aI(5, _omitFieldNames ? '' : 'cols', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'rows', fieldType: $pb.PbFieldType.OU3)
    ..pPM<AgentContext>(7, _omitFieldNames ? '' : 'context',
        subBuilder: AgentContext.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartAgentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartAgentRequest copyWith(void Function(StartAgentRequest) updates) =>
      super.copyWith((message) => updates(message as StartAgentRequest))
          as StartAgentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StartAgentRequest() / StartAgentRequest.new instead')
  static StartAgentRequest create() => StartAgentRequest._();
  static $pb.GeneratedMessage $_createMessage() => StartAgentRequest._();
  @$core.override
  StartAgentRequest createEmptyInstance() => StartAgentRequest._();
  @$core.pragma('dart2js:noInline')
  static StartAgentRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StartAgentRequest>(
          StartAgentRequest.$_createMessage);
  static StartAgentRequest? _defaultInstance;

  /// Empty: the default provider.
  @$pb.TagNumber(1)
  $core.String get providerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set providerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProviderId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProviderId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get worktreePath => $_getSZ(1);
  @$pb.TagNumber(2)
  set worktreePath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorktreePath() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorktreePath() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get prompt => $_getSZ(2);
  @$pb.TagNumber(3)
  set prompt($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPrompt() => $_has(2);
  @$pb.TagNumber(3)
  void clearPrompt() => $_clearField(3);

  /// Shown on the card; empty uses the prompt's first line.
  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get cols => $_getIZ(4);
  @$pb.TagNumber(5)
  set cols($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCols() => $_has(4);
  @$pb.TagNumber(5)
  void clearCols() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get rows => $_getIZ(5);
  @$pb.TagNumber(6)
  set rows($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRows() => $_has(5);
  @$pb.TagNumber(6)
  void clearRows() => $_clearField(6);

  /// What the prompt hands it (a ticket, a page), for the record.
  @$pb.TagNumber(7)
  $pb.PbList<AgentContext> get context => $_getList(6);
}

/// A ticket, page or piece of code an agent was given.
class AgentContext extends $pb.GeneratedMessage {
  factory AgentContext({
    AgentContextKind? kind,
    $core.String? title,
    $core.String? detail,
    $core.String? url,
  }) {
    final result = AgentContext._();
    if (kind != null) result.kind = kind;
    if (title != null) result.title = title;
    if (detail != null) result.detail = detail;
    if (url != null) result.url = url;
    return result;
  }

  AgentContext._();

  factory AgentContext.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentContext()..mergeFromBuffer(data, registry);
  factory AgentContext.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentContext()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentContext',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: AgentContext.$_createMessage)
    ..aE<AgentContextKind>(1, _omitFieldNames ? '' : 'kind',
        enumValues: AgentContextKind.values)
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'detail')
    ..aOS(4, _omitFieldNames ? '' : 'url')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentContext clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentContext copyWith(void Function(AgentContext) updates) =>
      super.copyWith((message) => updates(message as AgentContext))
          as AgentContext;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AgentContext() / AgentContext.new instead')
  static AgentContext create() => AgentContext._();
  static $pb.GeneratedMessage $_createMessage() => AgentContext._();
  @$core.override
  AgentContext createEmptyInstance() => AgentContext._();
  @$core.pragma('dart2js:noInline')
  static AgentContext getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AgentContext>(
          AgentContext.$_createMessage);
  static AgentContext? _defaultInstance;

  @$pb.TagNumber(1)
  AgentContextKind get kind => $_getN(0);
  @$pb.TagNumber(1)
  set kind(AgentContextKind value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  /// e.g. "PRC-412 · Bulk discounts by category".
  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// Where it lives, e.g. "Jira" or "Confluence · Pricing".
  @$pb.TagNumber(3)
  $core.String get detail => $_getSZ(2);
  @$pb.TagNumber(3)
  set detail($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDetail() => $_has(2);
  @$pb.TagNumber(3)
  void clearDetail() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get url => $_getSZ(3);
  @$pb.TagNumber(4)
  set url($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearUrl() => $_clearField(4);
}

/// One step of an agent's timeline, read from its terminal.
class AgentEvent extends $pb.GeneratedMessage {
  factory AgentEvent({
    $fixnum.Int64? atUnixMs,
    AgentEventKind? kind,
    $core.String? text,
  }) {
    final result = AgentEvent._();
    if (atUnixMs != null) result.atUnixMs = atUnixMs;
    if (kind != null) result.kind = kind;
    if (text != null) result.text = text;
    return result;
  }

  AgentEvent._();

  factory AgentEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentEvent()..mergeFromBuffer(data, registry);
  factory AgentEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentEvent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: AgentEvent.$_createMessage)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'atUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aE<AgentEventKind>(2, _omitFieldNames ? '' : 'kind',
        enumValues: AgentEventKind.values)
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentEvent copyWith(void Function(AgentEvent) updates) =>
      super.copyWith((message) => updates(message as AgentEvent)) as AgentEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AgentEvent() / AgentEvent.new instead')
  static AgentEvent create() => AgentEvent._();
  static $pb.GeneratedMessage $_createMessage() => AgentEvent._();
  @$core.override
  AgentEvent createEmptyInstance() => AgentEvent._();
  @$core.pragma('dart2js:noInline')
  static AgentEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentEvent>(AgentEvent.$_createMessage);
  static AgentEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get atUnixMs => $_getI64(0);
  @$pb.TagNumber(1)
  set atUnixMs($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAtUnixMs() => $_has(0);
  @$pb.TagNumber(1)
  void clearAtUnixMs() => $_clearField(1);

  @$pb.TagNumber(2)
  AgentEventKind get kind => $_getN(1);
  @$pb.TagNumber(2)
  set kind(AgentEventKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  /// The file, command or tool it acted on.
  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);
}

class AgentSession extends $pb.GeneratedMessage {
  factory AgentSession({
    $core.String? id,
    $core.String? providerId,
    $core.String? providerName,
    $core.String? short,
    $core.String? worktreePath,
    $core.String? terminalId,
    $core.String? title,
    $core.String? prompt,
    AgentState? state,
    $core.int? exitCode,
    $fixnum.Int64? startedUnixMs,
    $fixnum.Int64? stateSinceUnixMs,
    $core.String? lastLine,
    $core.Iterable<AgentContext>? context,
    $core.Iterable<AgentEvent>? events,
  }) {
    final result = AgentSession._();
    if (id != null) result.id = id;
    if (providerId != null) result.providerId = providerId;
    if (providerName != null) result.providerName = providerName;
    if (short != null) result.short = short;
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (terminalId != null) result.terminalId = terminalId;
    if (title != null) result.title = title;
    if (prompt != null) result.prompt = prompt;
    if (state != null) result.state = state;
    if (exitCode != null) result.exitCode = exitCode;
    if (startedUnixMs != null) result.startedUnixMs = startedUnixMs;
    if (stateSinceUnixMs != null) result.stateSinceUnixMs = stateSinceUnixMs;
    if (lastLine != null) result.lastLine = lastLine;
    if (context != null) result.context.addAll(context);
    if (events != null) result.events.addAll(events);
    return result;
  }

  AgentSession._();

  factory AgentSession.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentSession()..mergeFromBuffer(data, registry);
  factory AgentSession.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentSession()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentSession',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: AgentSession.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'providerId')
    ..aOS(3, _omitFieldNames ? '' : 'providerName')
    ..aOS(4, _omitFieldNames ? '' : 'short')
    ..aOS(5, _omitFieldNames ? '' : 'worktreePath')
    ..aOS(6, _omitFieldNames ? '' : 'terminalId')
    ..aOS(7, _omitFieldNames ? '' : 'title')
    ..aOS(8, _omitFieldNames ? '' : 'prompt')
    ..aE<AgentState>(9, _omitFieldNames ? '' : 'state',
        enumValues: AgentState.values)
    ..aI(10, _omitFieldNames ? '' : 'exitCode')
    ..a<$fixnum.Int64>(
        11, _omitFieldNames ? '' : 'startedUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        12, _omitFieldNames ? '' : 'stateSinceUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(13, _omitFieldNames ? '' : 'lastLine')
    ..pPM<AgentContext>(14, _omitFieldNames ? '' : 'context',
        subBuilder: AgentContext.$_createMessage)
    ..pPM<AgentEvent>(15, _omitFieldNames ? '' : 'events',
        subBuilder: AgentEvent.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentSession clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentSession copyWith(void Function(AgentSession) updates) =>
      super.copyWith((message) => updates(message as AgentSession))
          as AgentSession;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AgentSession() / AgentSession.new instead')
  static AgentSession create() => AgentSession._();
  static $pb.GeneratedMessage $_createMessage() => AgentSession._();
  @$core.override
  AgentSession createEmptyInstance() => AgentSession._();
  @$core.pragma('dart2js:noInline')
  static AgentSession getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AgentSession>(
          AgentSession.$_createMessage);
  static AgentSession? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get providerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set providerId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProviderId() => $_has(1);
  @$pb.TagNumber(2)
  void clearProviderId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get providerName => $_getSZ(2);
  @$pb.TagNumber(3)
  set providerName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProviderName() => $_has(2);
  @$pb.TagNumber(3)
  void clearProviderName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get short => $_getSZ(3);
  @$pb.TagNumber(4)
  set short($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasShort() => $_has(3);
  @$pb.TagNumber(4)
  void clearShort() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get worktreePath => $_getSZ(4);
  @$pb.TagNumber(5)
  set worktreePath($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasWorktreePath() => $_has(4);
  @$pb.TagNumber(5)
  void clearWorktreePath() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get terminalId => $_getSZ(5);
  @$pb.TagNumber(6)
  set terminalId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTerminalId() => $_has(5);
  @$pb.TagNumber(6)
  void clearTerminalId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get title => $_getSZ(6);
  @$pb.TagNumber(7)
  set title($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTitle() => $_has(6);
  @$pb.TagNumber(7)
  void clearTitle() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get prompt => $_getSZ(7);
  @$pb.TagNumber(8)
  set prompt($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPrompt() => $_has(7);
  @$pb.TagNumber(8)
  void clearPrompt() => $_clearField(8);

  @$pb.TagNumber(9)
  AgentState get state => $_getN(8);
  @$pb.TagNumber(9)
  set state(AgentState value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasState() => $_has(8);
  @$pb.TagNumber(9)
  void clearState() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get exitCode => $_getIZ(9);
  @$pb.TagNumber(10)
  set exitCode($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasExitCode() => $_has(9);
  @$pb.TagNumber(10)
  void clearExitCode() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get startedUnixMs => $_getI64(10);
  @$pb.TagNumber(11)
  set startedUnixMs($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasStartedUnixMs() => $_has(10);
  @$pb.TagNumber(11)
  void clearStartedUnixMs() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get stateSinceUnixMs => $_getI64(11);
  @$pb.TagNumber(12)
  set stateSinceUnixMs($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasStateSinceUnixMs() => $_has(11);
  @$pb.TagNumber(12)
  void clearStateSinceUnixMs() => $_clearField(12);

  /// Last readable line of output.
  @$pb.TagNumber(13)
  $core.String get lastLine => $_getSZ(12);
  @$pb.TagNumber(13)
  set lastLine($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasLastLine() => $_has(12);
  @$pb.TagNumber(13)
  void clearLastLine() => $_clearField(13);

  @$pb.TagNumber(14)
  $pb.PbList<AgentContext> get context => $_getList(13);

  /// Oldest first; the last 80.
  @$pb.TagNumber(15)
  $pb.PbList<AgentEvent> get events => $_getList(14);
}

class StopAgentRequest extends $pb.GeneratedMessage {
  factory StopAgentRequest({
    $core.String? id,
  }) {
    final result = StopAgentRequest._();
    if (id != null) result.id = id;
    return result;
  }

  StopAgentRequest._();

  factory StopAgentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopAgentRequest()..mergeFromBuffer(data, registry);
  factory StopAgentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopAgentRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StopAgentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: StopAgentRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopAgentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopAgentRequest copyWith(void Function(StopAgentRequest) updates) =>
      super.copyWith((message) => updates(message as StopAgentRequest))
          as StopAgentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StopAgentRequest() / StopAgentRequest.new instead')
  static StopAgentRequest create() => StopAgentRequest._();
  static $pb.GeneratedMessage $_createMessage() => StopAgentRequest._();
  @$core.override
  StopAgentRequest createEmptyInstance() => StopAgentRequest._();
  @$core.pragma('dart2js:noInline')
  static StopAgentRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StopAgentRequest>(
          StopAgentRequest.$_createMessage);
  static StopAgentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class StopAgentResponse extends $pb.GeneratedMessage {
  factory StopAgentResponse() => StopAgentResponse._();

  StopAgentResponse._();

  factory StopAgentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopAgentResponse()..mergeFromBuffer(data, registry);
  factory StopAgentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopAgentResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StopAgentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: StopAgentResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopAgentResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopAgentResponse copyWith(void Function(StopAgentResponse) updates) =>
      super.copyWith((message) => updates(message as StopAgentResponse))
          as StopAgentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StopAgentResponse() / StopAgentResponse.new instead')
  static StopAgentResponse create() => StopAgentResponse._();
  static $pb.GeneratedMessage $_createMessage() => StopAgentResponse._();
  @$core.override
  StopAgentResponse createEmptyInstance() => StopAgentResponse._();
  @$core.pragma('dart2js:noInline')
  static StopAgentResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StopAgentResponse>(
          StopAgentResponse.$_createMessage);
  static StopAgentResponse? _defaultInstance;
}

class AddAgentContextRequest extends $pb.GeneratedMessage {
  factory AddAgentContextRequest({
    $core.String? id,
    AgentContext? context,
    $core.String? text,
  }) {
    final result = AddAgentContextRequest._();
    if (id != null) result.id = id;
    if (context != null) result.context = context;
    if (text != null) result.text = text;
    return result;
  }

  AddAgentContextRequest._();

  factory AddAgentContextRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddAgentContextRequest()..mergeFromBuffer(data, registry);
  factory AddAgentContextRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddAgentContextRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddAgentContextRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: AddAgentContextRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOM<AgentContext>(2, _omitFieldNames ? '' : 'context',
        subBuilder: AgentContext.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddAgentContextRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddAgentContextRequest copyWith(
          void Function(AddAgentContextRequest) updates) =>
      super.copyWith((message) => updates(message as AddAgentContextRequest))
          as AddAgentContextRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AddAgentContextRequest() / AddAgentContextRequest.new instead')
  static AddAgentContextRequest create() => AddAgentContextRequest._();
  static $pb.GeneratedMessage $_createMessage() => AddAgentContextRequest._();
  @$core.override
  AddAgentContextRequest createEmptyInstance() => AddAgentContextRequest._();
  @$core.pragma('dart2js:noInline')
  static AddAgentContextRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddAgentContextRequest>(
          AddAgentContextRequest.$_createMessage);
  static AddAgentContextRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  AgentContext get context => $_getN(1);
  @$pb.TagNumber(2)
  set context(AgentContext value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasContext() => $_has(1);
  @$pb.TagNumber(2)
  void clearContext() => $_clearField(2);
  @$pb.TagNumber(2)
  AgentContext ensureContext() => $_ensure(1);

  /// Typed into the agent's terminal and submitted; empty only records it.
  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);
}

class DismissAgentRequest extends $pb.GeneratedMessage {
  factory DismissAgentRequest({
    $core.String? id,
  }) {
    final result = DismissAgentRequest._();
    if (id != null) result.id = id;
    return result;
  }

  DismissAgentRequest._();

  factory DismissAgentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DismissAgentRequest()..mergeFromBuffer(data, registry);
  factory DismissAgentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DismissAgentRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DismissAgentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DismissAgentRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DismissAgentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DismissAgentRequest copyWith(void Function(DismissAgentRequest) updates) =>
      super.copyWith((message) => updates(message as DismissAgentRequest))
          as DismissAgentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use DismissAgentRequest() / DismissAgentRequest.new instead')
  static DismissAgentRequest create() => DismissAgentRequest._();
  static $pb.GeneratedMessage $_createMessage() => DismissAgentRequest._();
  @$core.override
  DismissAgentRequest createEmptyInstance() => DismissAgentRequest._();
  @$core.pragma('dart2js:noInline')
  static DismissAgentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DismissAgentRequest>(
          DismissAgentRequest.$_createMessage);
  static DismissAgentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class DismissAgentResponse extends $pb.GeneratedMessage {
  factory DismissAgentResponse() => DismissAgentResponse._();

  DismissAgentResponse._();

  factory DismissAgentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DismissAgentResponse()..mergeFromBuffer(data, registry);
  factory DismissAgentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DismissAgentResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DismissAgentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DismissAgentResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DismissAgentResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DismissAgentResponse copyWith(void Function(DismissAgentResponse) updates) =>
      super.copyWith((message) => updates(message as DismissAgentResponse))
          as DismissAgentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DismissAgentResponse() / DismissAgentResponse.new instead')
  static DismissAgentResponse create() => DismissAgentResponse._();
  static $pb.GeneratedMessage $_createMessage() => DismissAgentResponse._();
  @$core.override
  DismissAgentResponse createEmptyInstance() => DismissAgentResponse._();
  @$core.pragma('dart2js:noInline')
  static DismissAgentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DismissAgentResponse>(
          DismissAgentResponse.$_createMessage);
  static DismissAgentResponse? _defaultInstance;
}

class WatchAgentsRequest extends $pb.GeneratedMessage {
  factory WatchAgentsRequest() => WatchAgentsRequest._();

  WatchAgentsRequest._();

  factory WatchAgentsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchAgentsRequest()..mergeFromBuffer(data, registry);
  factory WatchAgentsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchAgentsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WatchAgentsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: WatchAgentsRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchAgentsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchAgentsRequest copyWith(void Function(WatchAgentsRequest) updates) =>
      super.copyWith((message) => updates(message as WatchAgentsRequest))
          as WatchAgentsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WatchAgentsRequest() / WatchAgentsRequest.new instead')
  static WatchAgentsRequest create() => WatchAgentsRequest._();
  static $pb.GeneratedMessage $_createMessage() => WatchAgentsRequest._();
  @$core.override
  WatchAgentsRequest createEmptyInstance() => WatchAgentsRequest._();
  @$core.pragma('dart2js:noInline')
  static WatchAgentsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WatchAgentsRequest>(
          WatchAgentsRequest.$_createMessage);
  static WatchAgentsRequest? _defaultInstance;
}

class AgentsSnapshot extends $pb.GeneratedMessage {
  factory AgentsSnapshot({
    $fixnum.Int64? version,
    $core.Iterable<AgentSession>? sessions,
  }) {
    final result = AgentsSnapshot._();
    if (version != null) result.version = version;
    if (sessions != null) result.sessions.addAll(sessions);
    return result;
  }

  AgentsSnapshot._();

  factory AgentsSnapshot.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentsSnapshot()..mergeFromBuffer(data, registry);
  factory AgentsSnapshot.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentsSnapshot()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentsSnapshot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: AgentsSnapshot.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'version', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<AgentSession>(2, _omitFieldNames ? '' : 'sessions',
        subBuilder: AgentSession.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentsSnapshot clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentsSnapshot copyWith(void Function(AgentsSnapshot) updates) =>
      super.copyWith((message) => updates(message as AgentsSnapshot))
          as AgentsSnapshot;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AgentsSnapshot() / AgentsSnapshot.new instead')
  static AgentsSnapshot create() => AgentsSnapshot._();
  static $pb.GeneratedMessage $_createMessage() => AgentsSnapshot._();
  @$core.override
  AgentsSnapshot createEmptyInstance() => AgentsSnapshot._();
  @$core.pragma('dart2js:noInline')
  static AgentsSnapshot getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AgentsSnapshot>(
          AgentsSnapshot.$_createMessage);
  static AgentsSnapshot? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get version => $_getI64(0);
  @$pb.TagNumber(1)
  set version($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<AgentSession> get sessions => $_getList(1);
}

class UsageWindow extends $pb.GeneratedMessage {
  factory UsageWindow({
    $core.String? label,
    $core.String? short,
    $core.double? left,
    $core.double? of,
    UsageUnit? unit,
    $fixnum.Int64? resetsAt,
  }) {
    final result = UsageWindow._();
    if (label != null) result.label = label;
    if (short != null) result.short = short;
    if (left != null) result.left = left;
    if (of != null) result.of = of;
    if (unit != null) result.unit = unit;
    if (resetsAt != null) result.resetsAt = resetsAt;
    return result;
  }

  UsageWindow._();

  factory UsageWindow.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UsageWindow()..mergeFromBuffer(data, registry);
  factory UsageWindow.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UsageWindow()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UsageWindow',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: UsageWindow.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aOS(2, _omitFieldNames ? '' : 'short')
    ..aD(3, _omitFieldNames ? '' : 'left')
    ..aD(4, _omitFieldNames ? '' : 'of')
    ..aE<UsageUnit>(5, _omitFieldNames ? '' : 'unit',
        enumValues: UsageUnit.values)
    ..aInt64(6, _omitFieldNames ? '' : 'resetsAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageWindow clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageWindow copyWith(void Function(UsageWindow) updates) =>
      super.copyWith((message) => updates(message as UsageWindow))
          as UsageWindow;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UsageWindow() / UsageWindow.new instead')
  static UsageWindow create() => UsageWindow._();
  static $pb.GeneratedMessage $_createMessage() => UsageWindow._();
  @$core.override
  UsageWindow createEmptyInstance() => UsageWindow._();
  @$core.pragma('dart2js:noInline')
  static UsageWindow getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UsageWindow>(
          UsageWindow.$_createMessage);
  static UsageWindow? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get short => $_getSZ(1);
  @$pb.TagNumber(2)
  set short($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasShort() => $_has(1);
  @$pb.TagNumber(2)
  void clearShort() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get left => $_getN(2);
  @$pb.TagNumber(3)
  set left($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLeft() => $_has(2);
  @$pb.TagNumber(3)
  void clearLeft() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get of => $_getN(3);
  @$pb.TagNumber(4)
  set of($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOf() => $_has(3);
  @$pb.TagNumber(4)
  void clearOf() => $_clearField(4);

  @$pb.TagNumber(5)
  UsageUnit get unit => $_getN(4);
  @$pb.TagNumber(5)
  set unit(UsageUnit value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasUnit() => $_has(4);
  @$pb.TagNumber(5)
  void clearUnit() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get resetsAt => $_getI64(5);
  @$pb.TagNumber(6)
  set resetsAt($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasResetsAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearResetsAt() => $_clearField(6);
}

class PlanUsage extends $pb.GeneratedMessage {
  factory PlanUsage({
    $core.String? providerId,
    $core.String? plan,
    $core.Iterable<UsageWindow>? windows,
    $core.String? problem,
    $fixnum.Int64? readAt,
  }) {
    final result = PlanUsage._();
    if (providerId != null) result.providerId = providerId;
    if (plan != null) result.plan = plan;
    if (windows != null) result.windows.addAll(windows);
    if (problem != null) result.problem = problem;
    if (readAt != null) result.readAt = readAt;
    return result;
  }

  PlanUsage._();

  factory PlanUsage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlanUsage()..mergeFromBuffer(data, registry);
  factory PlanUsage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlanUsage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlanUsage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: PlanUsage.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'providerId')
    ..aOS(2, _omitFieldNames ? '' : 'plan')
    ..pPM<UsageWindow>(3, _omitFieldNames ? '' : 'windows',
        subBuilder: UsageWindow.$_createMessage)
    ..aOS(4, _omitFieldNames ? '' : 'problem')
    ..aInt64(5, _omitFieldNames ? '' : 'readAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanUsage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanUsage copyWith(void Function(PlanUsage) updates) =>
      super.copyWith((message) => updates(message as PlanUsage)) as PlanUsage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlanUsage() / PlanUsage.new instead')
  static PlanUsage create() => PlanUsage._();
  static $pb.GeneratedMessage $_createMessage() => PlanUsage._();
  @$core.override
  PlanUsage createEmptyInstance() => PlanUsage._();
  @$core.pragma('dart2js:noInline')
  static PlanUsage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlanUsage>(PlanUsage.$_createMessage);
  static PlanUsage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get providerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set providerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProviderId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProviderId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get plan => $_getSZ(1);
  @$pb.TagNumber(2)
  set plan($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlan() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlan() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<UsageWindow> get windows => $_getList(2);

  @$pb.TagNumber(4)
  $core.String get problem => $_getSZ(3);
  @$pb.TagNumber(4)
  set problem($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasProblem() => $_has(3);
  @$pb.TagNumber(4)
  void clearProblem() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get readAt => $_getI64(4);
  @$pb.TagNumber(5)
  set readAt($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReadAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearReadAt() => $_clearField(5);
}

class ContextSlice extends $pb.GeneratedMessage {
  factory ContextSlice({
    ContextSliceKind? kind,
    $fixnum.Int64? tokens,
  }) {
    final result = ContextSlice._();
    if (kind != null) result.kind = kind;
    if (tokens != null) result.tokens = tokens;
    return result;
  }

  ContextSlice._();

  factory ContextSlice.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContextSlice()..mergeFromBuffer(data, registry);
  factory ContextSlice.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContextSlice()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContextSlice',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ContextSlice.$_createMessage)
    ..aE<ContextSliceKind>(1, _omitFieldNames ? '' : 'kind',
        enumValues: ContextSliceKind.values)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'tokens', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContextSlice clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContextSlice copyWith(void Function(ContextSlice) updates) =>
      super.copyWith((message) => updates(message as ContextSlice))
          as ContextSlice;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ContextSlice() / ContextSlice.new instead')
  static ContextSlice create() => ContextSlice._();
  static $pb.GeneratedMessage $_createMessage() => ContextSlice._();
  @$core.override
  ContextSlice createEmptyInstance() => ContextSlice._();
  @$core.pragma('dart2js:noInline')
  static ContextSlice getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContextSlice>(
          ContextSlice.$_createMessage);
  static ContextSlice? _defaultInstance;

  @$pb.TagNumber(1)
  ContextSliceKind get kind => $_getN(0);
  @$pb.TagNumber(1)
  set kind(ContextSliceKind value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get tokens => $_getI64(1);
  @$pb.TagNumber(2)
  set tokens($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTokens() => $_has(1);
  @$pb.TagNumber(2)
  void clearTokens() => $_clearField(2);
}

class SessionUsage extends $pb.GeneratedMessage {
  factory SessionUsage({
    $core.String? sessionId,
    $core.String? model,
    $fixnum.Int64? contextMax,
    $core.Iterable<ContextSlice>? slices,
    $core.int? turns,
    $core.String? compactCommand,
    $fixnum.Int64? readAt,
  }) {
    final result = SessionUsage._();
    if (sessionId != null) result.sessionId = sessionId;
    if (model != null) result.model = model;
    if (contextMax != null) result.contextMax = contextMax;
    if (slices != null) result.slices.addAll(slices);
    if (turns != null) result.turns = turns;
    if (compactCommand != null) result.compactCommand = compactCommand;
    if (readAt != null) result.readAt = readAt;
    return result;
  }

  SessionUsage._();

  factory SessionUsage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionUsage()..mergeFromBuffer(data, registry);
  factory SessionUsage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionUsage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionUsage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: SessionUsage.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'model')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'contextMax', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<ContextSlice>(4, _omitFieldNames ? '' : 'slices',
        subBuilder: ContextSlice.$_createMessage)
    ..aI(5, _omitFieldNames ? '' : 'turns', fieldType: $pb.PbFieldType.OU3)
    ..aOS(6, _omitFieldNames ? '' : 'compactCommand')
    ..aInt64(7, _omitFieldNames ? '' : 'readAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionUsage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionUsage copyWith(void Function(SessionUsage) updates) =>
      super.copyWith((message) => updates(message as SessionUsage))
          as SessionUsage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SessionUsage() / SessionUsage.new instead')
  static SessionUsage create() => SessionUsage._();
  static $pb.GeneratedMessage $_createMessage() => SessionUsage._();
  @$core.override
  SessionUsage createEmptyInstance() => SessionUsage._();
  @$core.pragma('dart2js:noInline')
  static SessionUsage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SessionUsage>(
          SessionUsage.$_createMessage);
  static SessionUsage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get model => $_getSZ(1);
  @$pb.TagNumber(2)
  set model($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModel() => $_has(1);
  @$pb.TagNumber(2)
  void clearModel() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get contextMax => $_getI64(2);
  @$pb.TagNumber(3)
  set contextMax($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContextMax() => $_has(2);
  @$pb.TagNumber(3)
  void clearContextMax() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<ContextSlice> get slices => $_getList(3);

  @$pb.TagNumber(5)
  $core.int get turns => $_getIZ(4);
  @$pb.TagNumber(5)
  set turns($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTurns() => $_has(4);
  @$pb.TagNumber(5)
  void clearTurns() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get compactCommand => $_getSZ(5);
  @$pb.TagNumber(6)
  set compactCommand($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCompactCommand() => $_has(5);
  @$pb.TagNumber(6)
  void clearCompactCommand() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get readAt => $_getI64(6);
  @$pb.TagNumber(7)
  set readAt($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasReadAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearReadAt() => $_clearField(7);
}

class UsageRequest extends $pb.GeneratedMessage {
  factory UsageRequest() => UsageRequest._();

  UsageRequest._();

  factory UsageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UsageRequest()..mergeFromBuffer(data, registry);
  factory UsageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UsageRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UsageRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: UsageRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageRequest copyWith(void Function(UsageRequest) updates) =>
      super.copyWith((message) => updates(message as UsageRequest))
          as UsageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UsageRequest() / UsageRequest.new instead')
  static UsageRequest create() => UsageRequest._();
  static $pb.GeneratedMessage $_createMessage() => UsageRequest._();
  @$core.override
  UsageRequest createEmptyInstance() => UsageRequest._();
  @$core.pragma('dart2js:noInline')
  static UsageRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UsageRequest>(
          UsageRequest.$_createMessage);
  static UsageRequest? _defaultInstance;
}

class UsageReport extends $pb.GeneratedMessage {
  factory UsageReport({
    $core.Iterable<PlanUsage>? plans,
    $core.Iterable<SessionUsage>? sessions,
  }) {
    final result = UsageReport._();
    if (plans != null) result.plans.addAll(plans);
    if (sessions != null) result.sessions.addAll(sessions);
    return result;
  }

  UsageReport._();

  factory UsageReport.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UsageReport()..mergeFromBuffer(data, registry);
  factory UsageReport.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UsageReport()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UsageReport',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: UsageReport.$_createMessage)
    ..pPM<PlanUsage>(1, _omitFieldNames ? '' : 'plans',
        subBuilder: PlanUsage.$_createMessage)
    ..pPM<SessionUsage>(2, _omitFieldNames ? '' : 'sessions',
        subBuilder: SessionUsage.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageReport clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageReport copyWith(void Function(UsageReport) updates) =>
      super.copyWith((message) => updates(message as UsageReport))
          as UsageReport;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UsageReport() / UsageReport.new instead')
  static UsageReport create() => UsageReport._();
  static $pb.GeneratedMessage $_createMessage() => UsageReport._();
  @$core.override
  UsageReport createEmptyInstance() => UsageReport._();
  @$core.pragma('dart2js:noInline')
  static UsageReport getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UsageReport>(
          UsageReport.$_createMessage);
  static UsageReport? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PlanUsage> get plans => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<SessionUsage> get sessions => $_getList(1);
}

class CompactAgentRequest extends $pb.GeneratedMessage {
  factory CompactAgentRequest({
    $core.String? id,
  }) {
    final result = CompactAgentRequest._();
    if (id != null) result.id = id;
    return result;
  }

  CompactAgentRequest._();

  factory CompactAgentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CompactAgentRequest()..mergeFromBuffer(data, registry);
  factory CompactAgentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CompactAgentRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompactAgentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: CompactAgentRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompactAgentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompactAgentRequest copyWith(void Function(CompactAgentRequest) updates) =>
      super.copyWith((message) => updates(message as CompactAgentRequest))
          as CompactAgentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use CompactAgentRequest() / CompactAgentRequest.new instead')
  static CompactAgentRequest create() => CompactAgentRequest._();
  static $pb.GeneratedMessage $_createMessage() => CompactAgentRequest._();
  @$core.override
  CompactAgentRequest createEmptyInstance() => CompactAgentRequest._();
  @$core.pragma('dart2js:noInline')
  static CompactAgentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompactAgentRequest>(
          CompactAgentRequest.$_createMessage);
  static CompactAgentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class TaskSource extends $pb.GeneratedMessage {
  factory TaskSource({
    $core.String? id,
    TaskSourceKind? kind,
    $core.String? name,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? options,
    $core.bool? enabled,
    $core.String? badge,
    $core.bool? needsSecret,
    $core.bool? hasSecret,
    $core.Iterable<TaskStatus>? writable,
    $core.bool? syncing,
    $fixnum.Int64? lastSyncedUnixMs,
    $core.String? error,
    $core.int? taskCount,
  }) {
    final result = TaskSource._();
    if (id != null) result.id = id;
    if (kind != null) result.kind = kind;
    if (name != null) result.name = name;
    if (options != null) result.options.addEntries(options);
    if (enabled != null) result.enabled = enabled;
    if (badge != null) result.badge = badge;
    if (needsSecret != null) result.needsSecret = needsSecret;
    if (hasSecret != null) result.hasSecret = hasSecret;
    if (writable != null) result.writable.addAll(writable);
    if (syncing != null) result.syncing = syncing;
    if (lastSyncedUnixMs != null) result.lastSyncedUnixMs = lastSyncedUnixMs;
    if (error != null) result.error = error;
    if (taskCount != null) result.taskCount = taskCount;
    return result;
  }

  TaskSource._();

  factory TaskSource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TaskSource()..mergeFromBuffer(data, registry);
  factory TaskSource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TaskSource()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TaskSource',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TaskSource.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aE<TaskSourceKind>(2, _omitFieldNames ? '' : 'kind',
        enumValues: TaskSourceKind.values)
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'options',
        entryClassName: 'TaskSource.OptionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('kumo.v1'))
    ..aOB(5, _omitFieldNames ? '' : 'enabled')
    ..aOS(6, _omitFieldNames ? '' : 'badge')
    ..aOB(7, _omitFieldNames ? '' : 'needsSecret')
    ..aOB(8, _omitFieldNames ? '' : 'hasSecret')
    ..pc<TaskStatus>(9, _omitFieldNames ? '' : 'writable', $pb.PbFieldType.KE,
        valueOf: TaskStatus.valueOf,
        enumValues: TaskStatus.values,
        defaultEnumValue: TaskStatus.TASK_STATUS_TODO)
    ..aOB(10, _omitFieldNames ? '' : 'syncing')
    ..a<$fixnum.Int64>(
        11, _omitFieldNames ? '' : 'lastSyncedUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(12, _omitFieldNames ? '' : 'error')
    ..aI(13, _omitFieldNames ? '' : 'taskCount', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaskSource clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaskSource copyWith(void Function(TaskSource) updates) =>
      super.copyWith((message) => updates(message as TaskSource)) as TaskSource;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TaskSource() / TaskSource.new instead')
  static TaskSource create() => TaskSource._();
  static $pb.GeneratedMessage $_createMessage() => TaskSource._();
  @$core.override
  TaskSource createEmptyInstance() => TaskSource._();
  @$core.pragma('dart2js:noInline')
  static TaskSource getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TaskSource>(TaskSource.$_createMessage);
  static TaskSource? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  TaskSourceKind get kind => $_getN(1);
  @$pb.TagNumber(2)
  set kind(TaskSourceKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.String> get options => $_getMap(3);

  @$pb.TagNumber(5)
  $core.bool get enabled => $_getBF(4);
  @$pb.TagNumber(5)
  set enabled($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEnabled() => $_has(4);
  @$pb.TagNumber(5)
  void clearEnabled() => $_clearField(5);

  /// Two-letter badge, e.g. "JI".
  @$pb.TagNumber(6)
  $core.String get badge => $_getSZ(5);
  @$pb.TagNumber(6)
  set badge($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBadge() => $_has(5);
  @$pb.TagNumber(6)
  void clearBadge() => $_clearField(6);

  /// Needs an API token, and whether one is stored (in the OS keychain).
  @$pb.TagNumber(7)
  $core.bool get needsSecret => $_getBF(6);
  @$pb.TagNumber(7)
  set needsSecret($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNeedsSecret() => $_has(6);
  @$pb.TagNumber(7)
  void clearNeedsSecret() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get hasSecret => $_getBF(7);
  @$pb.TagNumber(8)
  set hasSecret($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasHasSecret() => $_has(7);
  @$pb.TagNumber(8)
  void clearHasSecret() => $_clearField(8);

  /// Statuses Kumo can write back.
  @$pb.TagNumber(9)
  $pb.PbList<TaskStatus> get writable => $_getList(8);

  @$pb.TagNumber(10)
  $core.bool get syncing => $_getBF(9);
  @$pb.TagNumber(10)
  set syncing($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSyncing() => $_has(9);
  @$pb.TagNumber(10)
  void clearSyncing() => $_clearField(10);

  /// 0: not read since it was configured or the daemon started.
  @$pb.TagNumber(11)
  $fixnum.Int64 get lastSyncedUnixMs => $_getI64(10);
  @$pb.TagNumber(11)
  set lastSyncedUnixMs($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasLastSyncedUnixMs() => $_has(10);
  @$pb.TagNumber(11)
  void clearLastSyncedUnixMs() => $_clearField(11);

  /// Why the last read failed; its cached tasks are still shown.
  @$pb.TagNumber(12)
  $core.String get error => $_getSZ(11);
  @$pb.TagNumber(12)
  set error($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasError() => $_has(11);
  @$pb.TagNumber(12)
  void clearError() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get taskCount => $_getIZ(12);
  @$pb.TagNumber(13)
  set taskCount($core.int value) => $_setUnsignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasTaskCount() => $_has(12);
  @$pb.TagNumber(13)
  void clearTaskCount() => $_clearField(13);
}

class Task extends $pb.GeneratedMessage {
  factory Task({
    $core.String? id,
    $core.String? sourceId,
    $core.String? key,
    $core.String? title,
    TaskStatus? status,
    TaskPriority? priority,
    $core.String? due,
    $core.String? url,
    $core.String? context,
    $core.Iterable<$core.String>? labels,
    $fixnum.Int64? updatedUnixMs,
    $core.String? suggestedBranch,
    TaskType? type,
    $core.String? typeName,
    $core.String? sourceStatus,
    Person? assignee,
    $core.Iterable<TaskRelation>? relations,
    $core.bool? mine,
    $core.double? points,
    $core.int? subtasksDone,
    $core.int? subtasksTotal,
    $core.int? commentCount,
    TaskRef? parent,
    $core.bool? blocked,
    Sprint? sprint,
  }) {
    final result = Task._();
    if (id != null) result.id = id;
    if (sourceId != null) result.sourceId = sourceId;
    if (key != null) result.key = key;
    if (title != null) result.title = title;
    if (status != null) result.status = status;
    if (priority != null) result.priority = priority;
    if (due != null) result.due = due;
    if (url != null) result.url = url;
    if (context != null) result.context = context;
    if (labels != null) result.labels.addAll(labels);
    if (updatedUnixMs != null) result.updatedUnixMs = updatedUnixMs;
    if (suggestedBranch != null) result.suggestedBranch = suggestedBranch;
    if (type != null) result.type = type;
    if (typeName != null) result.typeName = typeName;
    if (sourceStatus != null) result.sourceStatus = sourceStatus;
    if (assignee != null) result.assignee = assignee;
    if (relations != null) result.relations.addAll(relations);
    if (mine != null) result.mine = mine;
    if (points != null) result.points = points;
    if (subtasksDone != null) result.subtasksDone = subtasksDone;
    if (subtasksTotal != null) result.subtasksTotal = subtasksTotal;
    if (commentCount != null) result.commentCount = commentCount;
    if (parent != null) result.parent = parent;
    if (blocked != null) result.blocked = blocked;
    if (sprint != null) result.sprint = sprint;
    return result;
  }

  Task._();

  factory Task.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Task()..mergeFromBuffer(data, registry);
  factory Task.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Task()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Task',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: Task.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'sourceId')
    ..aOS(3, _omitFieldNames ? '' : 'key')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aE<TaskStatus>(5, _omitFieldNames ? '' : 'status',
        enumValues: TaskStatus.values)
    ..aE<TaskPriority>(6, _omitFieldNames ? '' : 'priority',
        enumValues: TaskPriority.values)
    ..aOS(7, _omitFieldNames ? '' : 'due')
    ..aOS(8, _omitFieldNames ? '' : 'url')
    ..aOS(9, _omitFieldNames ? '' : 'context')
    ..pPS(10, _omitFieldNames ? '' : 'labels')
    ..a<$fixnum.Int64>(
        11, _omitFieldNames ? '' : 'updatedUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(12, _omitFieldNames ? '' : 'suggestedBranch')
    ..aE<TaskType>(13, _omitFieldNames ? '' : 'type',
        enumValues: TaskType.values)
    ..aOS(14, _omitFieldNames ? '' : 'typeName')
    ..aOS(15, _omitFieldNames ? '' : 'sourceStatus')
    ..aOM<Person>(16, _omitFieldNames ? '' : 'assignee',
        subBuilder: Person.$_createMessage)
    ..pc<TaskRelation>(
        17, _omitFieldNames ? '' : 'relations', $pb.PbFieldType.KE,
        valueOf: TaskRelation.valueOf,
        enumValues: TaskRelation.values,
        defaultEnumValue: TaskRelation.TASK_RELATION_UNSPECIFIED)
    ..aOB(18, _omitFieldNames ? '' : 'mine')
    ..aD(19, _omitFieldNames ? '' : 'points')
    ..aI(20, _omitFieldNames ? '' : 'subtasksDone',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(21, _omitFieldNames ? '' : 'subtasksTotal',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(22, _omitFieldNames ? '' : 'commentCount',
        fieldType: $pb.PbFieldType.OU3)
    ..aOM<TaskRef>(23, _omitFieldNames ? '' : 'parent',
        subBuilder: TaskRef.$_createMessage)
    ..aOB(24, _omitFieldNames ? '' : 'blocked')
    ..aOM<Sprint>(25, _omitFieldNames ? '' : 'sprint',
        subBuilder: Sprint.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Task clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Task copyWith(void Function(Task) updates) =>
      super.copyWith((message) => updates(message as Task)) as Task;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Task() / Task.new instead')
  static Task create() => Task._();
  static $pb.GeneratedMessage $_createMessage() => Task._();
  @$core.override
  Task createEmptyInstance() => Task._();
  @$core.pragma('dart2js:noInline')
  static Task getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Task>(Task.$_createMessage);
  static Task? _defaultInstance;

  /// The source's id, a slash, and the id the task has in its source.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sourceId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSourceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSourceId() => $_clearField(2);

  /// Short label: issue key (PRC-412, #18), project or note.
  @$pb.TagNumber(3)
  $core.String get key => $_getSZ(2);
  @$pb.TagNumber(3)
  set key($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearKey() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  @$pb.TagNumber(5)
  TaskStatus get status => $_getN(4);
  @$pb.TagNumber(5)
  set status(TaskStatus value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearStatus() => $_clearField(5);

  @$pb.TagNumber(6)
  TaskPriority get priority => $_getN(5);
  @$pb.TagNumber(6)
  set priority(TaskPriority value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPriority() => $_has(5);
  @$pb.TagNumber(6)
  void clearPriority() => $_clearField(6);

  /// YYYY-MM-DD, or empty.
  @$pb.TagNumber(7)
  $core.String get due => $_getSZ(6);
  @$pb.TagNumber(7)
  set due($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDue() => $_has(6);
  @$pb.TagNumber(7)
  void clearDue() => $_clearField(7);

  /// Opens the task in its tool.
  @$pb.TagNumber(8)
  $core.String get url => $_getSZ(7);
  @$pb.TagNumber(8)
  set url($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasUrl() => $_has(7);
  @$pb.TagNumber(8)
  void clearUrl() => $_clearField(8);

  /// Repository, project or folder.
  @$pb.TagNumber(9)
  $core.String get context => $_getSZ(8);
  @$pb.TagNumber(9)
  set context($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasContext() => $_has(8);
  @$pb.TagNumber(9)
  void clearContext() => $_clearField(9);

  @$pb.TagNumber(10)
  $pb.PbList<$core.String> get labels => $_getList(9);

  @$pb.TagNumber(11)
  $fixnum.Int64 get updatedUnixMs => $_getI64(10);
  @$pb.TagNumber(11)
  set updatedUnixMs($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasUpdatedUnixMs() => $_has(10);
  @$pb.TagNumber(11)
  void clearUpdatedUnixMs() => $_clearField(11);

  /// Branch to work on it, e.g. "feat/PRC-412-bulk-discounts".
  @$pb.TagNumber(12)
  $core.String get suggestedBranch => $_getSZ(11);
  @$pb.TagNumber(12)
  set suggestedBranch($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasSuggestedBranch() => $_has(11);
  @$pb.TagNumber(12)
  void clearSuggestedBranch() => $_clearField(12);

  @$pb.TagNumber(13)
  TaskType get type => $_getN(12);
  @$pb.TagNumber(13)
  set type(TaskType value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasType() => $_has(12);
  @$pb.TagNumber(13)
  void clearType() => $_clearField(13);

  /// The source's own name for the type ("Story", "Sub-task").
  @$pb.TagNumber(14)
  $core.String get typeName => $_getSZ(13);
  @$pb.TagNumber(14)
  set typeName($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasTypeName() => $_has(13);
  @$pb.TagNumber(14)
  void clearTypeName() => $_clearField(14);

  /// The source's own status ("Code Review", "QA"); `status` is its column.
  @$pb.TagNumber(15)
  $core.String get sourceStatus => $_getSZ(14);
  @$pb.TagNumber(15)
  set sourceStatus($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasSourceStatus() => $_has(14);
  @$pb.TagNumber(15)
  void clearSourceStatus() => $_clearField(15);

  @$pb.TagNumber(16)
  Person get assignee => $_getN(15);
  @$pb.TagNumber(16)
  set assignee(Person value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasAssignee() => $_has(15);
  @$pb.TagNumber(16)
  void clearAssignee() => $_clearField(16);
  @$pb.TagNumber(16)
  Person ensureAssignee() => $_ensure(15);

  /// How the task relates to the user. Today only ASSIGNED is filled; room
  /// for REPORTED and WATCHING later.
  @$pb.TagNumber(17)
  $pb.PbList<TaskRelation> get relations => $_getList(16);

  /// The user's own: assigned to them, or from a personal source (Obsidian,
  /// Bear, Todoist). What "Mine" shows.
  @$pb.TagNumber(18)
  $core.bool get mine => $_getBF(17);
  @$pb.TagNumber(18)
  set mine($core.bool value) => $_setBool(17, value);
  @$pb.TagNumber(18)
  $core.bool hasMine() => $_has(17);
  @$pb.TagNumber(18)
  void clearMine() => $_clearField(18);

  /// Story points; 0 = none.
  @$pb.TagNumber(19)
  $core.double get points => $_getN(18);
  @$pb.TagNumber(19)
  set points($core.double value) => $_setDouble(18, value);
  @$pb.TagNumber(19)
  $core.bool hasPoints() => $_has(18);
  @$pb.TagNumber(19)
  void clearPoints() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.int get subtasksDone => $_getIZ(19);
  @$pb.TagNumber(20)
  set subtasksDone($core.int value) => $_setUnsignedInt32(19, value);
  @$pb.TagNumber(20)
  $core.bool hasSubtasksDone() => $_has(19);
  @$pb.TagNumber(20)
  void clearSubtasksDone() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.int get subtasksTotal => $_getIZ(20);
  @$pb.TagNumber(21)
  set subtasksTotal($core.int value) => $_setUnsignedInt32(20, value);
  @$pb.TagNumber(21)
  $core.bool hasSubtasksTotal() => $_has(20);
  @$pb.TagNumber(21)
  void clearSubtasksTotal() => $_clearField(21);

  @$pb.TagNumber(22)
  $core.int get commentCount => $_getIZ(21);
  @$pb.TagNumber(22)
  set commentCount($core.int value) => $_setUnsignedInt32(21, value);
  @$pb.TagNumber(22)
  $core.bool hasCommentCount() => $_has(21);
  @$pb.TagNumber(22)
  void clearCommentCount() => $_clearField(22);

  /// Epic, or parent of a sub-task.
  @$pb.TagNumber(23)
  TaskRef get parent => $_getN(22);
  @$pb.TagNumber(23)
  set parent(TaskRef value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasParent() => $_has(22);
  @$pb.TagNumber(23)
  void clearParent() => $_clearField(23);
  @$pb.TagNumber(23)
  TaskRef ensureParent() => $_ensure(22);

  /// An issue that blocks this one isn't done yet.
  @$pb.TagNumber(24)
  $core.bool get blocked => $_getBF(23);
  @$pb.TagNumber(24)
  set blocked($core.bool value) => $_setBool(23, value);
  @$pb.TagNumber(24)
  $core.bool hasBlocked() => $_has(23);
  @$pb.TagNumber(24)
  void clearBlocked() => $_clearField(24);

  @$pb.TagNumber(25)
  Sprint get sprint => $_getN(24);
  @$pb.TagNumber(25)
  set sprint(Sprint value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasSprint() => $_has(24);
  @$pb.TagNumber(25)
  void clearSprint() => $_clearField(25);
  @$pb.TagNumber(25)
  Sprint ensureSprint() => $_ensure(24);
}

class Person extends $pb.GeneratedMessage {
  factory Person({
    $core.String? id,
    $core.String? name,
    $core.String? initials,
    $core.bool? you,
  }) {
    final result = Person._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (initials != null) result.initials = initials;
    if (you != null) result.you = you;
    return result;
  }

  Person._();

  factory Person.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Person()..mergeFromBuffer(data, registry);
  factory Person.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Person()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Person',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: Person.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'initials')
    ..aOB(4, _omitFieldNames ? '' : 'you')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Person clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Person copyWith(void Function(Person) updates) =>
      super.copyWith((message) => updates(message as Person)) as Person;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Person() / Person.new instead')
  static Person create() => Person._();
  static $pb.GeneratedMessage $_createMessage() => Person._();
  @$core.override
  Person createEmptyInstance() => Person._();
  @$core.pragma('dart2js:noInline')
  static Person getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Person>(Person.$_createMessage);
  static Person? _defaultInstance;

  /// The source's id (Jira accountId, GitHub login).
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  /// "AG"; one letter for one-word names.
  @$pb.TagNumber(3)
  $core.String get initials => $_getSZ(2);
  @$pb.TagNumber(3)
  set initials($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInitials() => $_has(2);
  @$pb.TagNumber(3)
  void clearInitials() => $_clearField(3);

  /// The signed-in user.
  @$pb.TagNumber(4)
  $core.bool get you => $_getBF(3);
  @$pb.TagNumber(4)
  set you($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasYou() => $_has(3);
  @$pb.TagNumber(4)
  void clearYou() => $_clearField(4);
}

class Sprint extends $pb.GeneratedMessage {
  factory Sprint({
    $core.String? name,
    SprintState? state,
    $fixnum.Int64? startUnixMs,
    $fixnum.Int64? endUnixMs,
  }) {
    final result = Sprint._();
    if (name != null) result.name = name;
    if (state != null) result.state = state;
    if (startUnixMs != null) result.startUnixMs = startUnixMs;
    if (endUnixMs != null) result.endUnixMs = endUnixMs;
    return result;
  }

  Sprint._();

  factory Sprint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Sprint()..mergeFromBuffer(data, registry);
  factory Sprint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Sprint()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Sprint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: Sprint.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aE<SprintState>(2, _omitFieldNames ? '' : 'state',
        enumValues: SprintState.values)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'startUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'endUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Sprint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Sprint copyWith(void Function(Sprint) updates) =>
      super.copyWith((message) => updates(message as Sprint)) as Sprint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Sprint() / Sprint.new instead')
  static Sprint create() => Sprint._();
  static $pb.GeneratedMessage $_createMessage() => Sprint._();
  @$core.override
  Sprint createEmptyInstance() => Sprint._();
  @$core.pragma('dart2js:noInline')
  static Sprint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Sprint>(Sprint.$_createMessage);
  static Sprint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  SprintState get state => $_getN(1);
  @$pb.TagNumber(2)
  set state(SprintState value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasState() => $_has(1);
  @$pb.TagNumber(2)
  void clearState() => $_clearField(2);

  /// 0 = unknown.
  @$pb.TagNumber(3)
  $fixnum.Int64 get startUnixMs => $_getI64(2);
  @$pb.TagNumber(3)
  set startUnixMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartUnixMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartUnixMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get endUnixMs => $_getI64(3);
  @$pb.TagNumber(4)
  set endUnixMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEndUnixMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearEndUnixMs() => $_clearField(4);
}

/// Another ticket, as a detail or a card mentions it.
class TaskRef extends $pb.GeneratedMessage {
  factory TaskRef({
    $core.String? id,
    $core.String? key,
    $core.String? title,
    TaskType? type,
    $core.String? sourceStatus,
    TaskStatus? status,
    Person? assignee,
    $core.String? color,
    $core.String? url,
  }) {
    final result = TaskRef._();
    if (id != null) result.id = id;
    if (key != null) result.key = key;
    if (title != null) result.title = title;
    if (type != null) result.type = type;
    if (sourceStatus != null) result.sourceStatus = sourceStatus;
    if (status != null) result.status = status;
    if (assignee != null) result.assignee = assignee;
    if (color != null) result.color = color;
    if (url != null) result.url = url;
    return result;
  }

  TaskRef._();

  factory TaskRef.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TaskRef()..mergeFromBuffer(data, registry);
  factory TaskRef.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TaskRef()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TaskRef',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TaskRef.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'key')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aE<TaskType>(4, _omitFieldNames ? '' : 'type',
        enumValues: TaskType.values)
    ..aOS(5, _omitFieldNames ? '' : 'sourceStatus')
    ..aE<TaskStatus>(6, _omitFieldNames ? '' : 'status',
        enumValues: TaskStatus.values)
    ..aOM<Person>(7, _omitFieldNames ? '' : 'assignee',
        subBuilder: Person.$_createMessage)
    ..aOS(8, _omitFieldNames ? '' : 'color')
    ..aOS(9, _omitFieldNames ? '' : 'url')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaskRef clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaskRef copyWith(void Function(TaskRef) updates) =>
      super.copyWith((message) => updates(message as TaskRef)) as TaskRef;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TaskRef() / TaskRef.new instead')
  static TaskRef create() => TaskRef._();
  static $pb.GeneratedMessage $_createMessage() => TaskRef._();
  @$core.override
  TaskRef createEmptyInstance() => TaskRef._();
  @$core.pragma('dart2js:noInline')
  static TaskRef getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TaskRef>(TaskRef.$_createMessage);
  static TaskRef? _defaultInstance;

  /// Kumo's id ("source/external") when it's a task of a source; empty for
  /// tickets the source didn't send (opening it asks GetTask anyway).
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get key => $_getSZ(1);
  @$pb.TagNumber(2)
  set key($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearKey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  TaskType get type => $_getN(3);
  @$pb.TagNumber(4)
  set type(TaskType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get sourceStatus => $_getSZ(4);
  @$pb.TagNumber(5)
  set sourceStatus($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSourceStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearSourceStatus() => $_clearField(5);

  @$pb.TagNumber(6)
  TaskStatus get status => $_getN(5);
  @$pb.TagNumber(6)
  set status(TaskStatus value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);

  @$pb.TagNumber(7)
  Person get assignee => $_getN(6);
  @$pb.TagNumber(7)
  set assignee(Person value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasAssignee() => $_has(6);
  @$pb.TagNumber(7)
  void clearAssignee() => $_clearField(7);
  @$pb.TagNumber(7)
  Person ensureAssignee() => $_ensure(6);

  /// Epics: a palette name ("violet", "teal", "amber"…), empty = by key.
  @$pb.TagNumber(8)
  $core.String get color => $_getSZ(7);
  @$pb.TagNumber(8)
  set color($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasColor() => $_has(7);
  @$pb.TagNumber(8)
  void clearColor() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get url => $_getSZ(8);
  @$pb.TagNumber(9)
  set url($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasUrl() => $_has(8);
  @$pb.TagNumber(9)
  void clearUrl() => $_clearField(9);
}

class LinkedTask extends $pb.GeneratedMessage {
  factory LinkedTask({
    LinkKind? kind,
    $core.String? relation,
    TaskRef? task,
  }) {
    final result = LinkedTask._();
    if (kind != null) result.kind = kind;
    if (relation != null) result.relation = relation;
    if (task != null) result.task = task;
    return result;
  }

  LinkedTask._();

  factory LinkedTask.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LinkedTask()..mergeFromBuffer(data, registry);
  factory LinkedTask.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LinkedTask()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LinkedTask',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: LinkedTask.$_createMessage)
    ..aE<LinkKind>(1, _omitFieldNames ? '' : 'kind',
        enumValues: LinkKind.values)
    ..aOS(2, _omitFieldNames ? '' : 'relation')
    ..aOM<TaskRef>(3, _omitFieldNames ? '' : 'task',
        subBuilder: TaskRef.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LinkedTask clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LinkedTask copyWith(void Function(LinkedTask) updates) =>
      super.copyWith((message) => updates(message as LinkedTask)) as LinkedTask;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LinkedTask() / LinkedTask.new instead')
  static LinkedTask create() => LinkedTask._();
  static $pb.GeneratedMessage $_createMessage() => LinkedTask._();
  @$core.override
  LinkedTask createEmptyInstance() => LinkedTask._();
  @$core.pragma('dart2js:noInline')
  static LinkedTask getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LinkedTask>(LinkedTask.$_createMessage);
  static LinkedTask? _defaultInstance;

  @$pb.TagNumber(1)
  LinkKind get kind => $_getN(0);
  @$pb.TagNumber(1)
  set kind(LinkKind value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  /// The source's wording ("is blocked by", "clones").
  @$pb.TagNumber(2)
  $core.String get relation => $_getSZ(1);
  @$pb.TagNumber(2)
  set relation($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRelation() => $_has(1);
  @$pb.TagNumber(2)
  void clearRelation() => $_clearField(2);

  @$pb.TagNumber(3)
  TaskRef get task => $_getN(2);
  @$pb.TagNumber(3)
  set task(TaskRef value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasTask() => $_has(2);
  @$pb.TagNumber(3)
  void clearTask() => $_clearField(3);
  @$pb.TagNumber(3)
  TaskRef ensureTask() => $_ensure(2);
}

class TaskAttachment extends $pb.GeneratedMessage {
  factory TaskAttachment({
    $core.String? name,
    $core.String? kind,
    $fixnum.Int64? sizeBytes,
    $core.String? url,
  }) {
    final result = TaskAttachment._();
    if (name != null) result.name = name;
    if (kind != null) result.kind = kind;
    if (sizeBytes != null) result.sizeBytes = sizeBytes;
    if (url != null) result.url = url;
    return result;
  }

  TaskAttachment._();

  factory TaskAttachment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TaskAttachment()..mergeFromBuffer(data, registry);
  factory TaskAttachment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TaskAttachment()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TaskAttachment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TaskAttachment.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'kind')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'sizeBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(4, _omitFieldNames ? '' : 'url')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaskAttachment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaskAttachment copyWith(void Function(TaskAttachment) updates) =>
      super.copyWith((message) => updates(message as TaskAttachment))
          as TaskAttachment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TaskAttachment() / TaskAttachment.new instead')
  static TaskAttachment create() => TaskAttachment._();
  static $pb.GeneratedMessage $_createMessage() => TaskAttachment._();
  @$core.override
  TaskAttachment createEmptyInstance() => TaskAttachment._();
  @$core.pragma('dart2js:noInline')
  static TaskAttachment getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TaskAttachment>(
          TaskAttachment.$_createMessage);
  static TaskAttachment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// "PNG image", "CSV", "PDF".
  @$pb.TagNumber(2)
  $core.String get kind => $_getSZ(1);
  @$pb.TagNumber(2)
  set kind($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get sizeBytes => $_getI64(2);
  @$pb.TagNumber(3)
  set sizeBytes($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSizeBytes() => $_has(2);
  @$pb.TagNumber(3)
  void clearSizeBytes() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get url => $_getSZ(3);
  @$pb.TagNumber(4)
  set url($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearUrl() => $_clearField(4);
}

class TaskComment extends $pb.GeneratedMessage {
  factory TaskComment({
    Person? author,
    $fixnum.Int64? createdUnixMs,
    $core.String? body,
  }) {
    final result = TaskComment._();
    if (author != null) result.author = author;
    if (createdUnixMs != null) result.createdUnixMs = createdUnixMs;
    if (body != null) result.body = body;
    return result;
  }

  TaskComment._();

  factory TaskComment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TaskComment()..mergeFromBuffer(data, registry);
  factory TaskComment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TaskComment()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TaskComment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TaskComment.$_createMessage)
    ..aOM<Person>(1, _omitFieldNames ? '' : 'author',
        subBuilder: Person.$_createMessage)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'createdUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(3, _omitFieldNames ? '' : 'body')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaskComment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaskComment copyWith(void Function(TaskComment) updates) =>
      super.copyWith((message) => updates(message as TaskComment))
          as TaskComment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TaskComment() / TaskComment.new instead')
  static TaskComment create() => TaskComment._();
  static $pb.GeneratedMessage $_createMessage() => TaskComment._();
  @$core.override
  TaskComment createEmptyInstance() => TaskComment._();
  @$core.pragma('dart2js:noInline')
  static TaskComment getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TaskComment>(
          TaskComment.$_createMessage);
  static TaskComment? _defaultInstance;

  @$pb.TagNumber(1)
  Person get author => $_getN(0);
  @$pb.TagNumber(1)
  set author(Person value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAuthor() => $_has(0);
  @$pb.TagNumber(1)
  void clearAuthor() => $_clearField(1);
  @$pb.TagNumber(1)
  Person ensureAuthor() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get createdUnixMs => $_getI64(1);
  @$pb.TagNumber(2)
  set createdUnixMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCreatedUnixMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearCreatedUnixMs() => $_clearField(2);

  /// Markdown.
  @$pb.TagNumber(3)
  $core.String get body => $_getSZ(2);
  @$pb.TagNumber(3)
  set body($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBody() => $_has(2);
  @$pb.TagNumber(3)
  void clearBody() => $_clearField(3);
}

class TimeTracking extends $pb.GeneratedMessage {
  factory TimeTracking({
    $core.String? estimate,
    $core.String? logged,
    $core.String? remaining,
    $fixnum.Int64? estimateSeconds,
    $fixnum.Int64? loggedSeconds,
    $fixnum.Int64? remainingSeconds,
  }) {
    final result = TimeTracking._();
    if (estimate != null) result.estimate = estimate;
    if (logged != null) result.logged = logged;
    if (remaining != null) result.remaining = remaining;
    if (estimateSeconds != null) result.estimateSeconds = estimateSeconds;
    if (loggedSeconds != null) result.loggedSeconds = loggedSeconds;
    if (remainingSeconds != null) result.remainingSeconds = remainingSeconds;
    return result;
  }

  TimeTracking._();

  factory TimeTracking.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TimeTracking()..mergeFromBuffer(data, registry);
  factory TimeTracking.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TimeTracking()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TimeTracking',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TimeTracking.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'estimate')
    ..aOS(2, _omitFieldNames ? '' : 'logged')
    ..aOS(3, _omitFieldNames ? '' : 'remaining')
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'estimateSeconds', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'loggedSeconds', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'remainingSeconds', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimeTracking clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimeTracking copyWith(void Function(TimeTracking) updates) =>
      super.copyWith((message) => updates(message as TimeTracking))
          as TimeTracking;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TimeTracking() / TimeTracking.new instead')
  static TimeTracking create() => TimeTracking._();
  static $pb.GeneratedMessage $_createMessage() => TimeTracking._();
  @$core.override
  TimeTracking createEmptyInstance() => TimeTracking._();
  @$core.pragma('dart2js:noInline')
  static TimeTracking getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TimeTracking>(
          TimeTracking.$_createMessage);
  static TimeTracking? _defaultInstance;

  /// The source's own wording ("3d", "1d 4h"), and seconds for the bar.
  @$pb.TagNumber(1)
  $core.String get estimate => $_getSZ(0);
  @$pb.TagNumber(1)
  set estimate($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEstimate() => $_has(0);
  @$pb.TagNumber(1)
  void clearEstimate() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get logged => $_getSZ(1);
  @$pb.TagNumber(2)
  set logged($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLogged() => $_has(1);
  @$pb.TagNumber(2)
  void clearLogged() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get remaining => $_getSZ(2);
  @$pb.TagNumber(3)
  set remaining($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRemaining() => $_has(2);
  @$pb.TagNumber(3)
  void clearRemaining() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get estimateSeconds => $_getI64(3);
  @$pb.TagNumber(4)
  set estimateSeconds($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEstimateSeconds() => $_has(3);
  @$pb.TagNumber(4)
  void clearEstimateSeconds() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get loggedSeconds => $_getI64(4);
  @$pb.TagNumber(5)
  set loggedSeconds($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLoggedSeconds() => $_has(4);
  @$pb.TagNumber(5)
  void clearLoggedSeconds() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get remainingSeconds => $_getI64(5);
  @$pb.TagNumber(6)
  set remainingSeconds($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRemainingSeconds() => $_has(5);
  @$pb.TagNumber(6)
  void clearRemainingSeconds() => $_clearField(6);
}

class GetTaskRequest extends $pb.GeneratedMessage {
  factory GetTaskRequest({
    $core.String? id,
    $core.bool? refresh,
  }) {
    final result = GetTaskRequest._();
    if (id != null) result.id = id;
    if (refresh != null) result.refresh = refresh;
    return result;
  }

  GetTaskRequest._();

  factory GetTaskRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetTaskRequest()..mergeFromBuffer(data, registry);
  factory GetTaskRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetTaskRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTaskRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: GetTaskRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOB(2, _omitFieldNames ? '' : 'refresh')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTaskRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTaskRequest copyWith(void Function(GetTaskRequest) updates) =>
      super.copyWith((message) => updates(message as GetTaskRequest))
          as GetTaskRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetTaskRequest() / GetTaskRequest.new instead')
  static GetTaskRequest create() => GetTaskRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetTaskRequest._();
  @$core.override
  GetTaskRequest createEmptyInstance() => GetTaskRequest._();
  @$core.pragma('dart2js:noInline')
  static GetTaskRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetTaskRequest>(
          GetTaskRequest.$_createMessage);
  static GetTaskRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// Ask the source even if the cached detail is fresh.
  @$pb.TagNumber(2)
  $core.bool get refresh => $_getBF(1);
  @$pb.TagNumber(2)
  set refresh($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRefresh() => $_has(1);
  @$pb.TagNumber(2)
  void clearRefresh() => $_clearField(2);
}

class TaskDetail extends $pb.GeneratedMessage {
  factory TaskDetail({
    Task? task,
    Person? reporter,
    $fixnum.Int64? createdUnixMs,
    $core.String? description,
    $core.String? acceptanceCriteria,
    $core.Iterable<TaskRef>? subtasks,
    $core.Iterable<LinkedTask>? links,
    $core.Iterable<TaskAttachment>? attachments,
    $core.Iterable<TaskComment>? comments,
    $core.Iterable<$core.String>? components,
    $core.Iterable<$core.String>? fixVersions,
    TimeTracking? timeTracking,
    $fixnum.Int64? fetchedUnixMs,
    $core.bool? stale,
    $core.String? staleReason,
    $core.String? location,
  }) {
    final result = TaskDetail._();
    if (task != null) result.task = task;
    if (reporter != null) result.reporter = reporter;
    if (createdUnixMs != null) result.createdUnixMs = createdUnixMs;
    if (description != null) result.description = description;
    if (acceptanceCriteria != null)
      result.acceptanceCriteria = acceptanceCriteria;
    if (subtasks != null) result.subtasks.addAll(subtasks);
    if (links != null) result.links.addAll(links);
    if (attachments != null) result.attachments.addAll(attachments);
    if (comments != null) result.comments.addAll(comments);
    if (components != null) result.components.addAll(components);
    if (fixVersions != null) result.fixVersions.addAll(fixVersions);
    if (timeTracking != null) result.timeTracking = timeTracking;
    if (fetchedUnixMs != null) result.fetchedUnixMs = fetchedUnixMs;
    if (stale != null) result.stale = stale;
    if (staleReason != null) result.staleReason = staleReason;
    if (location != null) result.location = location;
    return result;
  }

  TaskDetail._();

  factory TaskDetail.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TaskDetail()..mergeFromBuffer(data, registry);
  factory TaskDetail.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TaskDetail()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TaskDetail',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TaskDetail.$_createMessage)
    ..aOM<Task>(1, _omitFieldNames ? '' : 'task',
        subBuilder: Task.$_createMessage)
    ..aOM<Person>(2, _omitFieldNames ? '' : 'reporter',
        subBuilder: Person.$_createMessage)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'createdUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(4, _omitFieldNames ? '' : 'description')
    ..aOS(5, _omitFieldNames ? '' : 'acceptanceCriteria')
    ..pPM<TaskRef>(6, _omitFieldNames ? '' : 'subtasks',
        subBuilder: TaskRef.$_createMessage)
    ..pPM<LinkedTask>(7, _omitFieldNames ? '' : 'links',
        subBuilder: LinkedTask.$_createMessage)
    ..pPM<TaskAttachment>(8, _omitFieldNames ? '' : 'attachments',
        subBuilder: TaskAttachment.$_createMessage)
    ..pPM<TaskComment>(9, _omitFieldNames ? '' : 'comments',
        subBuilder: TaskComment.$_createMessage)
    ..pPS(10, _omitFieldNames ? '' : 'components')
    ..pPS(11, _omitFieldNames ? '' : 'fixVersions')
    ..aOM<TimeTracking>(12, _omitFieldNames ? '' : 'timeTracking',
        subBuilder: TimeTracking.$_createMessage)
    ..a<$fixnum.Int64>(
        13, _omitFieldNames ? '' : 'fetchedUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(14, _omitFieldNames ? '' : 'stale')
    ..aOS(15, _omitFieldNames ? '' : 'staleReason')
    ..aOS(16, _omitFieldNames ? '' : 'location')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaskDetail clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaskDetail copyWith(void Function(TaskDetail) updates) =>
      super.copyWith((message) => updates(message as TaskDetail)) as TaskDetail;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TaskDetail() / TaskDetail.new instead')
  static TaskDetail create() => TaskDetail._();
  static $pb.GeneratedMessage $_createMessage() => TaskDetail._();
  @$core.override
  TaskDetail createEmptyInstance() => TaskDetail._();
  @$core.pragma('dart2js:noInline')
  static TaskDetail getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TaskDetail>(TaskDetail.$_createMessage);
  static TaskDetail? _defaultInstance;

  /// The card's fields, as fresh as the detail.
  @$pb.TagNumber(1)
  Task get task => $_getN(0);
  @$pb.TagNumber(1)
  set task(Task value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTask() => $_has(0);
  @$pb.TagNumber(1)
  void clearTask() => $_clearField(1);
  @$pb.TagNumber(1)
  Task ensureTask() => $_ensure(0);

  @$pb.TagNumber(2)
  Person get reporter => $_getN(1);
  @$pb.TagNumber(2)
  set reporter(Person value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasReporter() => $_has(1);
  @$pb.TagNumber(2)
  void clearReporter() => $_clearField(2);
  @$pb.TagNumber(2)
  Person ensureReporter() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get createdUnixMs => $_getI64(2);
  @$pb.TagNumber(3)
  set createdUnixMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCreatedUnixMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreatedUnixMs() => $_clearField(3);

  /// Markdown (Jira's rich text converted).
  @$pb.TagNumber(4)
  $core.String get description => $_getSZ(3);
  @$pb.TagNumber(4)
  set description($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDescription() => $_has(3);
  @$pb.TagNumber(4)
  void clearDescription() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get acceptanceCriteria => $_getSZ(4);
  @$pb.TagNumber(5)
  set acceptanceCriteria($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAcceptanceCriteria() => $_has(4);
  @$pb.TagNumber(5)
  void clearAcceptanceCriteria() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<TaskRef> get subtasks => $_getList(5);

  @$pb.TagNumber(7)
  $pb.PbList<LinkedTask> get links => $_getList(6);

  @$pb.TagNumber(8)
  $pb.PbList<TaskAttachment> get attachments => $_getList(7);

  /// Oldest first, all of them.
  @$pb.TagNumber(9)
  $pb.PbList<TaskComment> get comments => $_getList(8);

  @$pb.TagNumber(10)
  $pb.PbList<$core.String> get components => $_getList(9);

  @$pb.TagNumber(11)
  $pb.PbList<$core.String> get fixVersions => $_getList(10);

  @$pb.TagNumber(12)
  TimeTracking get timeTracking => $_getN(11);
  @$pb.TagNumber(12)
  set timeTracking(TimeTracking value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasTimeTracking() => $_has(11);
  @$pb.TagNumber(12)
  void clearTimeTracking() => $_clearField(12);
  @$pb.TagNumber(12)
  TimeTracking ensureTimeTracking() => $_ensure(11);

  /// When the source answered.
  @$pb.TagNumber(13)
  $fixnum.Int64 get fetchedUnixMs => $_getI64(12);
  @$pb.TagNumber(13)
  set fetchedUnixMs($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(13)
  $core.bool hasFetchedUnixMs() => $_has(12);
  @$pb.TagNumber(13)
  void clearFetchedUnixMs() => $_clearField(13);

  /// Served from the cache: the source couldn't be reached.
  @$pb.TagNumber(14)
  $core.bool get stale => $_getBF(13);
  @$pb.TagNumber(14)
  set stale($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasStale() => $_has(13);
  @$pb.TagNumber(14)
  void clearStale() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get staleReason => $_getSZ(14);
  @$pb.TagNumber(15)
  set staleReason($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasStaleReason() => $_has(14);
  @$pb.TagNumber(15)
  void clearStaleReason() => $_clearField(15);

  /// Where a personal task lives ("Weekly.md · line 14", "Todoist · Inbox").
  @$pb.TagNumber(16)
  $core.String get location => $_getSZ(15);
  @$pb.TagNumber(16)
  set location($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasLocation() => $_has(15);
  @$pb.TagNumber(16)
  void clearLocation() => $_clearField(16);
}

class SourceTasks extends $pb.GeneratedMessage {
  factory SourceTasks({
    $core.String? sourceId,
    $fixnum.Int64? version,
    $core.Iterable<Task>? tasks,
  }) {
    final result = SourceTasks._();
    if (sourceId != null) result.sourceId = sourceId;
    if (version != null) result.version = version;
    if (tasks != null) result.tasks.addAll(tasks);
    return result;
  }

  SourceTasks._();

  factory SourceTasks.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SourceTasks()..mergeFromBuffer(data, registry);
  factory SourceTasks.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SourceTasks()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SourceTasks',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: SourceTasks.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sourceId')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'version', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<Task>(3, _omitFieldNames ? '' : 'tasks',
        subBuilder: Task.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SourceTasks clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SourceTasks copyWith(void Function(SourceTasks) updates) =>
      super.copyWith((message) => updates(message as SourceTasks))
          as SourceTasks;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SourceTasks() / SourceTasks.new instead')
  static SourceTasks create() => SourceTasks._();
  static $pb.GeneratedMessage $_createMessage() => SourceTasks._();
  @$core.override
  SourceTasks createEmptyInstance() => SourceTasks._();
  @$core.pragma('dart2js:noInline')
  static SourceTasks getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SourceTasks>(
          SourceTasks.$_createMessage);
  static SourceTasks? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sourceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get version => $_getI64(1);
  @$pb.TagNumber(2)
  set version($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<Task> get tasks => $_getList(2);
}

class TaskLink extends $pb.GeneratedMessage {
  factory TaskLink({
    $core.String? taskId,
    $core.String? worktreePath,
    $core.String? branch,
    $fixnum.Int64? createdUnixMs,
  }) {
    final result = TaskLink._();
    if (taskId != null) result.taskId = taskId;
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (branch != null) result.branch = branch;
    if (createdUnixMs != null) result.createdUnixMs = createdUnixMs;
    return result;
  }

  TaskLink._();

  factory TaskLink.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TaskLink()..mergeFromBuffer(data, registry);
  factory TaskLink.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TaskLink()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TaskLink',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TaskLink.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'taskId')
    ..aOS(2, _omitFieldNames ? '' : 'worktreePath')
    ..aOS(3, _omitFieldNames ? '' : 'branch')
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'createdUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaskLink clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaskLink copyWith(void Function(TaskLink) updates) =>
      super.copyWith((message) => updates(message as TaskLink)) as TaskLink;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TaskLink() / TaskLink.new instead')
  static TaskLink create() => TaskLink._();
  static $pb.GeneratedMessage $_createMessage() => TaskLink._();
  @$core.override
  TaskLink createEmptyInstance() => TaskLink._();
  @$core.pragma('dart2js:noInline')
  static TaskLink getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TaskLink>(TaskLink.$_createMessage);
  static TaskLink? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get taskId => $_getSZ(0);
  @$pb.TagNumber(1)
  set taskId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTaskId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTaskId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get worktreePath => $_getSZ(1);
  @$pb.TagNumber(2)
  set worktreePath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorktreePath() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorktreePath() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get branch => $_getSZ(2);
  @$pb.TagNumber(3)
  set branch($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBranch() => $_has(2);
  @$pb.TagNumber(3)
  void clearBranch() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get createdUnixMs => $_getI64(3);
  @$pb.TagNumber(4)
  set createdUnixMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCreatedUnixMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearCreatedUnixMs() => $_clearField(4);
}

class WatchTasksRequest extends $pb.GeneratedMessage {
  factory WatchTasksRequest() => WatchTasksRequest._();

  WatchTasksRequest._();

  factory WatchTasksRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchTasksRequest()..mergeFromBuffer(data, registry);
  factory WatchTasksRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchTasksRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WatchTasksRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: WatchTasksRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchTasksRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchTasksRequest copyWith(void Function(WatchTasksRequest) updates) =>
      super.copyWith((message) => updates(message as WatchTasksRequest))
          as WatchTasksRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WatchTasksRequest() / WatchTasksRequest.new instead')
  static WatchTasksRequest create() => WatchTasksRequest._();
  static $pb.GeneratedMessage $_createMessage() => WatchTasksRequest._();
  @$core.override
  WatchTasksRequest createEmptyInstance() => WatchTasksRequest._();
  @$core.pragma('dart2js:noInline')
  static WatchTasksRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WatchTasksRequest>(
          WatchTasksRequest.$_createMessage);
  static WatchTasksRequest? _defaultInstance;
}

class TasksUpdate extends $pb.GeneratedMessage {
  factory TasksUpdate({
    $fixnum.Int64? version,
    $core.Iterable<TaskSource>? sources,
    $core.Iterable<SourceTasks>? changed,
    $core.Iterable<TaskLink>? links,
  }) {
    final result = TasksUpdate._();
    if (version != null) result.version = version;
    if (sources != null) result.sources.addAll(sources);
    if (changed != null) result.changed.addAll(changed);
    if (links != null) result.links.addAll(links);
    return result;
  }

  TasksUpdate._();

  factory TasksUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TasksUpdate()..mergeFromBuffer(data, registry);
  factory TasksUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TasksUpdate()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TasksUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TasksUpdate.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'version', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<TaskSource>(2, _omitFieldNames ? '' : 'sources',
        subBuilder: TaskSource.$_createMessage)
    ..pPM<SourceTasks>(3, _omitFieldNames ? '' : 'changed',
        subBuilder: SourceTasks.$_createMessage)
    ..pPM<TaskLink>(4, _omitFieldNames ? '' : 'links',
        subBuilder: TaskLink.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TasksUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TasksUpdate copyWith(void Function(TasksUpdate) updates) =>
      super.copyWith((message) => updates(message as TasksUpdate))
          as TasksUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TasksUpdate() / TasksUpdate.new instead')
  static TasksUpdate create() => TasksUpdate._();
  static $pb.GeneratedMessage $_createMessage() => TasksUpdate._();
  @$core.override
  TasksUpdate createEmptyInstance() => TasksUpdate._();
  @$core.pragma('dart2js:noInline')
  static TasksUpdate getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TasksUpdate>(
          TasksUpdate.$_createMessage);
  static TasksUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get version => $_getI64(0);
  @$pb.TagNumber(1)
  set version($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);

  /// Every configured source, in order. Tasks of sources not listed are gone.
  @$pb.TagNumber(2)
  $pb.PbList<TaskSource> get sources => $_getList(1);

  /// Task lists that changed since the previous update (all of them in the
  /// first one). Lists of other sources stay as they were.
  @$pb.TagNumber(3)
  $pb.PbList<SourceTasks> get changed => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<TaskLink> get links => $_getList(3);
}

class DetectSourcesRequest extends $pb.GeneratedMessage {
  factory DetectSourcesRequest() => DetectSourcesRequest._();

  DetectSourcesRequest._();

  factory DetectSourcesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DetectSourcesRequest()..mergeFromBuffer(data, registry);
  factory DetectSourcesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DetectSourcesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DetectSourcesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DetectSourcesRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DetectSourcesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DetectSourcesRequest copyWith(void Function(DetectSourcesRequest) updates) =>
      super.copyWith((message) => updates(message as DetectSourcesRequest))
          as DetectSourcesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DetectSourcesRequest() / DetectSourcesRequest.new instead')
  static DetectSourcesRequest create() => DetectSourcesRequest._();
  static $pb.GeneratedMessage $_createMessage() => DetectSourcesRequest._();
  @$core.override
  DetectSourcesRequest createEmptyInstance() => DetectSourcesRequest._();
  @$core.pragma('dart2js:noInline')
  static DetectSourcesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DetectSourcesRequest>(
          DetectSourcesRequest.$_createMessage);
  static DetectSourcesRequest? _defaultInstance;
}

class DetectedSource extends $pb.GeneratedMessage {
  factory DetectedSource({
    TaskSourceKind? kind,
    $core.String? name,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? options,
  }) {
    final result = DetectedSource._();
    if (kind != null) result.kind = kind;
    if (name != null) result.name = name;
    if (options != null) result.options.addEntries(options);
    return result;
  }

  DetectedSource._();

  factory DetectedSource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DetectedSource()..mergeFromBuffer(data, registry);
  factory DetectedSource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DetectedSource()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DetectedSource',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DetectedSource.$_createMessage)
    ..aE<TaskSourceKind>(1, _omitFieldNames ? '' : 'kind',
        enumValues: TaskSourceKind.values)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'options',
        entryClassName: 'DetectedSource.OptionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('kumo.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DetectedSource clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DetectedSource copyWith(void Function(DetectedSource) updates) =>
      super.copyWith((message) => updates(message as DetectedSource))
          as DetectedSource;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DetectedSource() / DetectedSource.new instead')
  static DetectedSource create() => DetectedSource._();
  static $pb.GeneratedMessage $_createMessage() => DetectedSource._();
  @$core.override
  DetectedSource createEmptyInstance() => DetectedSource._();
  @$core.pragma('dart2js:noInline')
  static DetectedSource getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DetectedSource>(
          DetectedSource.$_createMessage);
  static DetectedSource? _defaultInstance;

  @$pb.TagNumber(1)
  TaskSourceKind get kind => $_getN(0);
  @$pb.TagNumber(1)
  set kind(TaskSourceKind value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $core.String> get options => $_getMap(2);
}

class DetectSourcesResponse extends $pb.GeneratedMessage {
  factory DetectSourcesResponse({
    $core.Iterable<DetectedSource>? sources,
  }) {
    final result = DetectSourcesResponse._();
    if (sources != null) result.sources.addAll(sources);
    return result;
  }

  DetectSourcesResponse._();

  factory DetectSourcesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DetectSourcesResponse()..mergeFromBuffer(data, registry);
  factory DetectSourcesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DetectSourcesResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DetectSourcesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DetectSourcesResponse.$_createMessage)
    ..pPM<DetectedSource>(1, _omitFieldNames ? '' : 'sources',
        subBuilder: DetectedSource.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DetectSourcesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DetectSourcesResponse copyWith(
          void Function(DetectSourcesResponse) updates) =>
      super.copyWith((message) => updates(message as DetectSourcesResponse))
          as DetectSourcesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DetectSourcesResponse() / DetectSourcesResponse.new instead')
  static DetectSourcesResponse create() => DetectSourcesResponse._();
  static $pb.GeneratedMessage $_createMessage() => DetectSourcesResponse._();
  @$core.override
  DetectSourcesResponse createEmptyInstance() => DetectSourcesResponse._();
  @$core.pragma('dart2js:noInline')
  static DetectSourcesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DetectSourcesResponse>(
          DetectSourcesResponse.$_createMessage);
  static DetectSourcesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DetectedSource> get sources => $_getList(0);
}

class TestSourceRequest extends $pb.GeneratedMessage {
  factory TestSourceRequest({
    $core.String? id,
    TaskSourceKind? kind,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? options,
    $core.String? secret,
  }) {
    final result = TestSourceRequest._();
    if (id != null) result.id = id;
    if (kind != null) result.kind = kind;
    if (options != null) result.options.addEntries(options);
    if (secret != null) result.secret = secret;
    return result;
  }

  TestSourceRequest._();

  factory TestSourceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestSourceRequest()..mergeFromBuffer(data, registry);
  factory TestSourceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestSourceRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestSourceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TestSourceRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aE<TaskSourceKind>(2, _omitFieldNames ? '' : 'kind',
        enumValues: TaskSourceKind.values)
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'options',
        entryClassName: 'TestSourceRequest.OptionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('kumo.v1'))
    ..aOS(4, _omitFieldNames ? '' : 'secret')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestSourceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestSourceRequest copyWith(void Function(TestSourceRequest) updates) =>
      super.copyWith((message) => updates(message as TestSourceRequest))
          as TestSourceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TestSourceRequest() / TestSourceRequest.new instead')
  static TestSourceRequest create() => TestSourceRequest._();
  static $pb.GeneratedMessage $_createMessage() => TestSourceRequest._();
  @$core.override
  TestSourceRequest createEmptyInstance() => TestSourceRequest._();
  @$core.pragma('dart2js:noInline')
  static TestSourceRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TestSourceRequest>(
          TestSourceRequest.$_createMessage);
  static TestSourceRequest? _defaultInstance;

  /// Set to test with the token stored for that source.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  TaskSourceKind get kind => $_getN(1);
  @$pb.TagNumber(2)
  set kind(TaskSourceKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $core.String> get options => $_getMap(2);

  /// A new token; empty uses the stored one.
  @$pb.TagNumber(4)
  $core.String get secret => $_getSZ(3);
  @$pb.TagNumber(4)
  set secret($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSecret() => $_has(3);
  @$pb.TagNumber(4)
  void clearSecret() => $_clearField(4);
}

class TestSourceResponse extends $pb.GeneratedMessage {
  factory TestSourceResponse({
    $core.String? message,
  }) {
    final result = TestSourceResponse._();
    if (message != null) result.message = message;
    return result;
  }

  TestSourceResponse._();

  factory TestSourceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestSourceResponse()..mergeFromBuffer(data, registry);
  factory TestSourceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestSourceResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestSourceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TestSourceResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestSourceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestSourceResponse copyWith(void Function(TestSourceResponse) updates) =>
      super.copyWith((message) => updates(message as TestSourceResponse))
          as TestSourceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TestSourceResponse() / TestSourceResponse.new instead')
  static TestSourceResponse create() => TestSourceResponse._();
  static $pb.GeneratedMessage $_createMessage() => TestSourceResponse._();
  @$core.override
  TestSourceResponse createEmptyInstance() => TestSourceResponse._();
  @$core.pragma('dart2js:noInline')
  static TestSourceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TestSourceResponse>(
          TestSourceResponse.$_createMessage);
  static TestSourceResponse? _defaultInstance;

  /// E.g. "signed in as Ana", "12 open tasks, 40 in total".
  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);
}

class SaveSourceRequest extends $pb.GeneratedMessage {
  factory SaveSourceRequest({
    $core.String? id,
    TaskSourceKind? kind,
    $core.String? name,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? options,
    $core.bool? enabled,
    $core.String? secret,
  }) {
    final result = SaveSourceRequest._();
    if (id != null) result.id = id;
    if (kind != null) result.kind = kind;
    if (name != null) result.name = name;
    if (options != null) result.options.addEntries(options);
    if (enabled != null) result.enabled = enabled;
    if (secret != null) result.secret = secret;
    return result;
  }

  SaveSourceRequest._();

  factory SaveSourceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveSourceRequest()..mergeFromBuffer(data, registry);
  factory SaveSourceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveSourceRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveSourceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: SaveSourceRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aE<TaskSourceKind>(2, _omitFieldNames ? '' : 'kind',
        enumValues: TaskSourceKind.values)
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'options',
        entryClassName: 'SaveSourceRequest.OptionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('kumo.v1'))
    ..aOB(5, _omitFieldNames ? '' : 'enabled')
    ..aOS(6, _omitFieldNames ? '' : 'secret')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveSourceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveSourceRequest copyWith(void Function(SaveSourceRequest) updates) =>
      super.copyWith((message) => updates(message as SaveSourceRequest))
          as SaveSourceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SaveSourceRequest() / SaveSourceRequest.new instead')
  static SaveSourceRequest create() => SaveSourceRequest._();
  static $pb.GeneratedMessage $_createMessage() => SaveSourceRequest._();
  @$core.override
  SaveSourceRequest createEmptyInstance() => SaveSourceRequest._();
  @$core.pragma('dart2js:noInline')
  static SaveSourceRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SaveSourceRequest>(
          SaveSourceRequest.$_createMessage);
  static SaveSourceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  TaskSourceKind get kind => $_getN(1);
  @$pb.TagNumber(2)
  set kind(TaskSourceKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.String> get options => $_getMap(3);

  @$pb.TagNumber(5)
  $core.bool get enabled => $_getBF(4);
  @$pb.TagNumber(5)
  set enabled($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEnabled() => $_has(4);
  @$pb.TagNumber(5)
  void clearEnabled() => $_clearField(5);

  /// A new token; empty keeps the stored one.
  @$pb.TagNumber(6)
  $core.String get secret => $_getSZ(5);
  @$pb.TagNumber(6)
  set secret($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSecret() => $_has(5);
  @$pb.TagNumber(6)
  void clearSecret() => $_clearField(6);
}

class DeleteSourceRequest extends $pb.GeneratedMessage {
  factory DeleteSourceRequest({
    $core.String? id,
  }) {
    final result = DeleteSourceRequest._();
    if (id != null) result.id = id;
    return result;
  }

  DeleteSourceRequest._();

  factory DeleteSourceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteSourceRequest()..mergeFromBuffer(data, registry);
  factory DeleteSourceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteSourceRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteSourceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DeleteSourceRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSourceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSourceRequest copyWith(void Function(DeleteSourceRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteSourceRequest))
          as DeleteSourceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use DeleteSourceRequest() / DeleteSourceRequest.new instead')
  static DeleteSourceRequest create() => DeleteSourceRequest._();
  static $pb.GeneratedMessage $_createMessage() => DeleteSourceRequest._();
  @$core.override
  DeleteSourceRequest createEmptyInstance() => DeleteSourceRequest._();
  @$core.pragma('dart2js:noInline')
  static DeleteSourceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteSourceRequest>(
          DeleteSourceRequest.$_createMessage);
  static DeleteSourceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class DeleteSourceResponse extends $pb.GeneratedMessage {
  factory DeleteSourceResponse() => DeleteSourceResponse._();

  DeleteSourceResponse._();

  factory DeleteSourceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteSourceResponse()..mergeFromBuffer(data, registry);
  factory DeleteSourceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteSourceResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteSourceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DeleteSourceResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSourceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSourceResponse copyWith(void Function(DeleteSourceResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteSourceResponse))
          as DeleteSourceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DeleteSourceResponse() / DeleteSourceResponse.new instead')
  static DeleteSourceResponse create() => DeleteSourceResponse._();
  static $pb.GeneratedMessage $_createMessage() => DeleteSourceResponse._();
  @$core.override
  DeleteSourceResponse createEmptyInstance() => DeleteSourceResponse._();
  @$core.pragma('dart2js:noInline')
  static DeleteSourceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteSourceResponse>(
          DeleteSourceResponse.$_createMessage);
  static DeleteSourceResponse? _defaultInstance;
}

class SyncTasksRequest extends $pb.GeneratedMessage {
  factory SyncTasksRequest({
    $core.String? sourceId,
  }) {
    final result = SyncTasksRequest._();
    if (sourceId != null) result.sourceId = sourceId;
    return result;
  }

  SyncTasksRequest._();

  factory SyncTasksRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncTasksRequest()..mergeFromBuffer(data, registry);
  factory SyncTasksRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncTasksRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncTasksRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: SyncTasksRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sourceId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncTasksRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncTasksRequest copyWith(void Function(SyncTasksRequest) updates) =>
      super.copyWith((message) => updates(message as SyncTasksRequest))
          as SyncTasksRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SyncTasksRequest() / SyncTasksRequest.new instead')
  static SyncTasksRequest create() => SyncTasksRequest._();
  static $pb.GeneratedMessage $_createMessage() => SyncTasksRequest._();
  @$core.override
  SyncTasksRequest createEmptyInstance() => SyncTasksRequest._();
  @$core.pragma('dart2js:noInline')
  static SyncTasksRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SyncTasksRequest>(
          SyncTasksRequest.$_createMessage);
  static SyncTasksRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sourceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourceId() => $_clearField(1);
}

class SyncTasksResponse extends $pb.GeneratedMessage {
  factory SyncTasksResponse() => SyncTasksResponse._();

  SyncTasksResponse._();

  factory SyncTasksResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncTasksResponse()..mergeFromBuffer(data, registry);
  factory SyncTasksResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncTasksResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncTasksResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: SyncTasksResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncTasksResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncTasksResponse copyWith(void Function(SyncTasksResponse) updates) =>
      super.copyWith((message) => updates(message as SyncTasksResponse))
          as SyncTasksResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SyncTasksResponse() / SyncTasksResponse.new instead')
  static SyncTasksResponse create() => SyncTasksResponse._();
  static $pb.GeneratedMessage $_createMessage() => SyncTasksResponse._();
  @$core.override
  SyncTasksResponse createEmptyInstance() => SyncTasksResponse._();
  @$core.pragma('dart2js:noInline')
  static SyncTasksResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SyncTasksResponse>(
          SyncTasksResponse.$_createMessage);
  static SyncTasksResponse? _defaultInstance;
}

class SetTaskStatusRequest extends $pb.GeneratedMessage {
  factory SetTaskStatusRequest({
    $core.String? taskId,
    TaskStatus? status,
  }) {
    final result = SetTaskStatusRequest._();
    if (taskId != null) result.taskId = taskId;
    if (status != null) result.status = status;
    return result;
  }

  SetTaskStatusRequest._();

  factory SetTaskStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetTaskStatusRequest()..mergeFromBuffer(data, registry);
  factory SetTaskStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetTaskStatusRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetTaskStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: SetTaskStatusRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'taskId')
    ..aE<TaskStatus>(2, _omitFieldNames ? '' : 'status',
        enumValues: TaskStatus.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetTaskStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetTaskStatusRequest copyWith(void Function(SetTaskStatusRequest) updates) =>
      super.copyWith((message) => updates(message as SetTaskStatusRequest))
          as SetTaskStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetTaskStatusRequest() / SetTaskStatusRequest.new instead')
  static SetTaskStatusRequest create() => SetTaskStatusRequest._();
  static $pb.GeneratedMessage $_createMessage() => SetTaskStatusRequest._();
  @$core.override
  SetTaskStatusRequest createEmptyInstance() => SetTaskStatusRequest._();
  @$core.pragma('dart2js:noInline')
  static SetTaskStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetTaskStatusRequest>(
          SetTaskStatusRequest.$_createMessage);
  static SetTaskStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get taskId => $_getSZ(0);
  @$pb.TagNumber(1)
  set taskId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTaskId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTaskId() => $_clearField(1);

  @$pb.TagNumber(2)
  TaskStatus get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(TaskStatus value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);
}

class LinkTaskRequest extends $pb.GeneratedMessage {
  factory LinkTaskRequest({
    $core.String? taskId,
    $core.String? worktreePath,
    $core.String? branch,
  }) {
    final result = LinkTaskRequest._();
    if (taskId != null) result.taskId = taskId;
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (branch != null) result.branch = branch;
    return result;
  }

  LinkTaskRequest._();

  factory LinkTaskRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LinkTaskRequest()..mergeFromBuffer(data, registry);
  factory LinkTaskRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LinkTaskRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LinkTaskRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: LinkTaskRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'taskId')
    ..aOS(2, _omitFieldNames ? '' : 'worktreePath')
    ..aOS(3, _omitFieldNames ? '' : 'branch')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LinkTaskRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LinkTaskRequest copyWith(void Function(LinkTaskRequest) updates) =>
      super.copyWith((message) => updates(message as LinkTaskRequest))
          as LinkTaskRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LinkTaskRequest() / LinkTaskRequest.new instead')
  static LinkTaskRequest create() => LinkTaskRequest._();
  static $pb.GeneratedMessage $_createMessage() => LinkTaskRequest._();
  @$core.override
  LinkTaskRequest createEmptyInstance() => LinkTaskRequest._();
  @$core.pragma('dart2js:noInline')
  static LinkTaskRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LinkTaskRequest>(
          LinkTaskRequest.$_createMessage);
  static LinkTaskRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get taskId => $_getSZ(0);
  @$pb.TagNumber(1)
  set taskId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTaskId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTaskId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get worktreePath => $_getSZ(1);
  @$pb.TagNumber(2)
  set worktreePath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorktreePath() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorktreePath() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get branch => $_getSZ(2);
  @$pb.TagNumber(3)
  set branch($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBranch() => $_has(2);
  @$pb.TagNumber(3)
  void clearBranch() => $_clearField(3);
}

class UnlinkTaskRequest extends $pb.GeneratedMessage {
  factory UnlinkTaskRequest({
    $core.String? taskId,
    $core.String? worktreePath,
  }) {
    final result = UnlinkTaskRequest._();
    if (taskId != null) result.taskId = taskId;
    if (worktreePath != null) result.worktreePath = worktreePath;
    return result;
  }

  UnlinkTaskRequest._();

  factory UnlinkTaskRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UnlinkTaskRequest()..mergeFromBuffer(data, registry);
  factory UnlinkTaskRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UnlinkTaskRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnlinkTaskRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: UnlinkTaskRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'taskId')
    ..aOS(2, _omitFieldNames ? '' : 'worktreePath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnlinkTaskRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnlinkTaskRequest copyWith(void Function(UnlinkTaskRequest) updates) =>
      super.copyWith((message) => updates(message as UnlinkTaskRequest))
          as UnlinkTaskRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UnlinkTaskRequest() / UnlinkTaskRequest.new instead')
  static UnlinkTaskRequest create() => UnlinkTaskRequest._();
  static $pb.GeneratedMessage $_createMessage() => UnlinkTaskRequest._();
  @$core.override
  UnlinkTaskRequest createEmptyInstance() => UnlinkTaskRequest._();
  @$core.pragma('dart2js:noInline')
  static UnlinkTaskRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UnlinkTaskRequest>(
          UnlinkTaskRequest.$_createMessage);
  static UnlinkTaskRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get taskId => $_getSZ(0);
  @$pb.TagNumber(1)
  set taskId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTaskId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTaskId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get worktreePath => $_getSZ(1);
  @$pb.TagNumber(2)
  set worktreePath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorktreePath() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorktreePath() => $_clearField(2);
}

class UnlinkTaskResponse extends $pb.GeneratedMessage {
  factory UnlinkTaskResponse() => UnlinkTaskResponse._();

  UnlinkTaskResponse._();

  factory UnlinkTaskResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UnlinkTaskResponse()..mergeFromBuffer(data, registry);
  factory UnlinkTaskResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UnlinkTaskResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnlinkTaskResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: UnlinkTaskResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnlinkTaskResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnlinkTaskResponse copyWith(void Function(UnlinkTaskResponse) updates) =>
      super.copyWith((message) => updates(message as UnlinkTaskResponse))
          as UnlinkTaskResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UnlinkTaskResponse() / UnlinkTaskResponse.new instead')
  static UnlinkTaskResponse create() => UnlinkTaskResponse._();
  static $pb.GeneratedMessage $_createMessage() => UnlinkTaskResponse._();
  @$core.override
  UnlinkTaskResponse createEmptyInstance() => UnlinkTaskResponse._();
  @$core.pragma('dart2js:noInline')
  static UnlinkTaskResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnlinkTaskResponse>(
          UnlinkTaskResponse.$_createMessage);
  static UnlinkTaskResponse? _defaultInstance;
}

class WatchPipelinesRequest extends $pb.GeneratedMessage {
  factory WatchPipelinesRequest({
    $core.String? worktreePath,
  }) {
    final result = WatchPipelinesRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    return result;
  }

  WatchPipelinesRequest._();

  factory WatchPipelinesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchPipelinesRequest()..mergeFromBuffer(data, registry);
  factory WatchPipelinesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchPipelinesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WatchPipelinesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: WatchPipelinesRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchPipelinesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchPipelinesRequest copyWith(
          void Function(WatchPipelinesRequest) updates) =>
      super.copyWith((message) => updates(message as WatchPipelinesRequest))
          as WatchPipelinesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use WatchPipelinesRequest() / WatchPipelinesRequest.new instead')
  static WatchPipelinesRequest create() => WatchPipelinesRequest._();
  static $pb.GeneratedMessage $_createMessage() => WatchPipelinesRequest._();
  @$core.override
  WatchPipelinesRequest createEmptyInstance() => WatchPipelinesRequest._();
  @$core.pragma('dart2js:noInline')
  static WatchPipelinesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WatchPipelinesRequest>(
          WatchPipelinesRequest.$_createMessage);
  static WatchPipelinesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);
}

class PipelinesSnapshot extends $pb.GeneratedMessage {
  factory PipelinesSnapshot({
    CiProvider? provider,
    $core.String? repo,
    $core.String? branch,
    CiRun? latest,
    CiProblem? problem,
    $fixnum.Int64? checkedAt,
  }) {
    final result = PipelinesSnapshot._();
    if (provider != null) result.provider = provider;
    if (repo != null) result.repo = repo;
    if (branch != null) result.branch = branch;
    if (latest != null) result.latest = latest;
    if (problem != null) result.problem = problem;
    if (checkedAt != null) result.checkedAt = checkedAt;
    return result;
  }

  PipelinesSnapshot._();

  factory PipelinesSnapshot.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PipelinesSnapshot()..mergeFromBuffer(data, registry);
  factory PipelinesSnapshot.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PipelinesSnapshot()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PipelinesSnapshot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: PipelinesSnapshot.$_createMessage)
    ..aE<CiProvider>(1, _omitFieldNames ? '' : 'provider',
        enumValues: CiProvider.values)
    ..aOS(2, _omitFieldNames ? '' : 'repo')
    ..aOS(3, _omitFieldNames ? '' : 'branch')
    ..aOM<CiRun>(4, _omitFieldNames ? '' : 'latest',
        subBuilder: CiRun.$_createMessage)
    ..aOM<CiProblem>(5, _omitFieldNames ? '' : 'problem',
        subBuilder: CiProblem.$_createMessage)
    ..aInt64(6, _omitFieldNames ? '' : 'checkedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PipelinesSnapshot clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PipelinesSnapshot copyWith(void Function(PipelinesSnapshot) updates) =>
      super.copyWith((message) => updates(message as PipelinesSnapshot))
          as PipelinesSnapshot;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PipelinesSnapshot() / PipelinesSnapshot.new instead')
  static PipelinesSnapshot create() => PipelinesSnapshot._();
  static $pb.GeneratedMessage $_createMessage() => PipelinesSnapshot._();
  @$core.override
  PipelinesSnapshot createEmptyInstance() => PipelinesSnapshot._();
  @$core.pragma('dart2js:noInline')
  static PipelinesSnapshot getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PipelinesSnapshot>(
          PipelinesSnapshot.$_createMessage);
  static PipelinesSnapshot? _defaultInstance;

  @$pb.TagNumber(1)
  CiProvider get provider => $_getN(0);
  @$pb.TagNumber(1)
  set provider(CiProvider value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasProvider() => $_has(0);
  @$pb.TagNumber(1)
  void clearProvider() => $_clearField(1);

  /// "owner/name" on the host.
  @$pb.TagNumber(2)
  $core.String get repo => $_getSZ(1);
  @$pb.TagNumber(2)
  set repo($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRepo() => $_has(1);
  @$pb.TagNumber(2)
  void clearRepo() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get branch => $_getSZ(2);
  @$pb.TagNumber(3)
  set branch($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBranch() => $_has(2);
  @$pb.TagNumber(3)
  void clearBranch() => $_clearField(3);

  /// The latest run; with a rate-limited or unreachable problem, the last
  /// one seen.
  @$pb.TagNumber(4)
  CiRun get latest => $_getN(3);
  @$pb.TagNumber(4)
  set latest(CiRun value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasLatest() => $_has(3);
  @$pb.TagNumber(4)
  void clearLatest() => $_clearField(4);
  @$pb.TagNumber(4)
  CiRun ensureLatest() => $_ensure(3);

  @$pb.TagNumber(5)
  CiProblem get problem => $_getN(4);
  @$pb.TagNumber(5)
  set problem(CiProblem value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasProblem() => $_has(4);
  @$pb.TagNumber(5)
  void clearProblem() => $_clearField(5);
  @$pb.TagNumber(5)
  CiProblem ensureProblem() => $_ensure(4);

  /// When the provider last answered (Unix ms, 0 = never).
  @$pb.TagNumber(6)
  $fixnum.Int64 get checkedAt => $_getI64(5);
  @$pb.TagNumber(6)
  set checkedAt($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCheckedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCheckedAt() => $_clearField(6);
}

class CiRun extends $pb.GeneratedMessage {
  factory CiRun({
    $core.String? id,
    $core.String? label,
    $core.String? shortSha,
    $core.String? title,
    CiState? state,
    $fixnum.Int64? createdAt,
    $fixnum.Int64? finishedAt,
    $core.String? url,
    $core.Iterable<CiJob>? jobs,
  }) {
    final result = CiRun._();
    if (id != null) result.id = id;
    if (label != null) result.label = label;
    if (shortSha != null) result.shortSha = shortSha;
    if (title != null) result.title = title;
    if (state != null) result.state = state;
    if (createdAt != null) result.createdAt = createdAt;
    if (finishedAt != null) result.finishedAt = finishedAt;
    if (url != null) result.url = url;
    if (jobs != null) result.jobs.addAll(jobs);
    return result;
  }

  CiRun._();

  factory CiRun.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CiRun()..mergeFromBuffer(data, registry);
  factory CiRun.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CiRun()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CiRun',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: CiRun.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'shortSha')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aE<CiState>(5, _omitFieldNames ? '' : 'state', enumValues: CiState.values)
    ..aInt64(6, _omitFieldNames ? '' : 'createdAt')
    ..aInt64(7, _omitFieldNames ? '' : 'finishedAt')
    ..aOS(8, _omitFieldNames ? '' : 'url')
    ..pPM<CiJob>(9, _omitFieldNames ? '' : 'jobs',
        subBuilder: CiJob.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CiRun clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CiRun copyWith(void Function(CiRun) updates) =>
      super.copyWith((message) => updates(message as CiRun)) as CiRun;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CiRun() / CiRun.new instead')
  static CiRun create() => CiRun._();
  static $pb.GeneratedMessage $_createMessage() => CiRun._();
  @$core.override
  CiRun createEmptyInstance() => CiRun._();
  @$core.pragma('dart2js:noInline')
  static CiRun getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CiRun>(CiRun.$_createMessage);
  static CiRun? _defaultInstance;

  /// The provider's id, for RerunFailed.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// What the provider calls it: "run #8812", "pipeline #4417".
  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get shortSha => $_getSZ(2);
  @$pb.TagNumber(3)
  set shortSha($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasShortSha() => $_has(2);
  @$pb.TagNumber(3)
  void clearShortSha() => $_clearField(3);

  /// Subject of the commit it ran for.
  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  @$pb.TagNumber(5)
  CiState get state => $_getN(4);
  @$pb.TagNumber(5)
  set state(CiState value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasState() => $_has(4);
  @$pb.TagNumber(5)
  void clearState() => $_clearField(5);

  /// Unix ms, 0 = unknown.
  @$pb.TagNumber(6)
  $fixnum.Int64 get createdAt => $_getI64(5);
  @$pb.TagNumber(6)
  set createdAt($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAt() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get finishedAt => $_getI64(6);
  @$pb.TagNumber(7)
  set finishedAt($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFinishedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearFinishedAt() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get url => $_getSZ(7);
  @$pb.TagNumber(8)
  set url($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasUrl() => $_has(7);
  @$pb.TagNumber(8)
  void clearUrl() => $_clearField(8);

  @$pb.TagNumber(9)
  $pb.PbList<CiJob> get jobs => $_getList(8);
}

class CiJob extends $pb.GeneratedMessage {
  factory CiJob({
    $core.String? name,
    CiState? state,
    $fixnum.Int64? durationMs,
    $fixnum.Int64? startedAt,
    $core.String? failure,
    $core.String? url,
  }) {
    final result = CiJob._();
    if (name != null) result.name = name;
    if (state != null) result.state = state;
    if (durationMs != null) result.durationMs = durationMs;
    if (startedAt != null) result.startedAt = startedAt;
    if (failure != null) result.failure = failure;
    if (url != null) result.url = url;
    return result;
  }

  CiJob._();

  factory CiJob.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CiJob()..mergeFromBuffer(data, registry);
  factory CiJob.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CiJob()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CiJob',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: CiJob.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aE<CiState>(2, _omitFieldNames ? '' : 'state', enumValues: CiState.values)
    ..aInt64(3, _omitFieldNames ? '' : 'durationMs')
    ..aInt64(4, _omitFieldNames ? '' : 'startedAt')
    ..aOS(5, _omitFieldNames ? '' : 'failure')
    ..aOS(6, _omitFieldNames ? '' : 'url')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CiJob clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CiJob copyWith(void Function(CiJob) updates) =>
      super.copyWith((message) => updates(message as CiJob)) as CiJob;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CiJob() / CiJob.new instead')
  static CiJob create() => CiJob._();
  static $pb.GeneratedMessage $_createMessage() => CiJob._();
  @$core.override
  CiJob createEmptyInstance() => CiJob._();
  @$core.pragma('dart2js:noInline')
  static CiJob getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CiJob>(CiJob.$_createMessage);
  static CiJob? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  CiState get state => $_getN(1);
  @$pb.TagNumber(2)
  set state(CiState value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasState() => $_has(1);
  @$pb.TagNumber(2)
  void clearState() => $_clearField(2);

  /// Finished jobs; 0 = unknown.
  @$pb.TagNumber(3)
  $fixnum.Int64 get durationMs => $_getI64(2);
  @$pb.TagNumber(3)
  set durationMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDurationMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearDurationMs() => $_clearField(3);

  /// Unix ms, 0 = not started.
  @$pb.TagNumber(4)
  $fixnum.Int64 get startedAt => $_getI64(3);
  @$pb.TagNumber(4)
  set startedAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStartedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearStartedAt() => $_clearField(4);

  /// First useful line of the error, for failed jobs (best effort).
  @$pb.TagNumber(5)
  $core.String get failure => $_getSZ(4);
  @$pb.TagNumber(5)
  set failure($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFailure() => $_has(4);
  @$pb.TagNumber(5)
  void clearFailure() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get url => $_getSZ(5);
  @$pb.TagNumber(6)
  set url($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearUrl() => $_clearField(6);
}

class CiProblem extends $pb.GeneratedMessage {
  factory CiProblem({
    CiProblemKind? kind,
    $core.String? detail,
    $core.String? missingScope,
    $fixnum.Int64? retryAt,
    $core.int? commitsWaiting,
  }) {
    final result = CiProblem._();
    if (kind != null) result.kind = kind;
    if (detail != null) result.detail = detail;
    if (missingScope != null) result.missingScope = missingScope;
    if (retryAt != null) result.retryAt = retryAt;
    if (commitsWaiting != null) result.commitsWaiting = commitsWaiting;
    return result;
  }

  CiProblem._();

  factory CiProblem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CiProblem()..mergeFromBuffer(data, registry);
  factory CiProblem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CiProblem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CiProblem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: CiProblem.$_createMessage)
    ..aE<CiProblemKind>(1, _omitFieldNames ? '' : 'kind',
        enumValues: CiProblemKind.values)
    ..aOS(2, _omitFieldNames ? '' : 'detail')
    ..aOS(3, _omitFieldNames ? '' : 'missingScope')
    ..aInt64(4, _omitFieldNames ? '' : 'retryAt')
    ..aI(5, _omitFieldNames ? '' : 'commitsWaiting',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CiProblem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CiProblem copyWith(void Function(CiProblem) updates) =>
      super.copyWith((message) => updates(message as CiProblem)) as CiProblem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CiProblem() / CiProblem.new instead')
  static CiProblem create() => CiProblem._();
  static $pb.GeneratedMessage $_createMessage() => CiProblem._();
  @$core.override
  CiProblem createEmptyInstance() => CiProblem._();
  @$core.pragma('dart2js:noInline')
  static CiProblem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CiProblem>(CiProblem.$_createMessage);
  static CiProblem? _defaultInstance;

  @$pb.TagNumber(1)
  CiProblemKind get kind => $_getN(0);
  @$pb.TagNumber(1)
  set kind(CiProblemKind value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  /// The provider's answer, short: "HTTP 403 · Resource not accessible by
  /// personal access token". Never contains a token.
  @$pb.TagNumber(2)
  $core.String get detail => $_getSZ(1);
  @$pb.TagNumber(2)
  set detail($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDetail() => $_has(1);
  @$pb.TagNumber(2)
  void clearDetail() => $_clearField(2);

  /// The permission the token lacks, when the provider says which.
  @$pb.TagNumber(3)
  $core.String get missingScope => $_getSZ(2);
  @$pb.TagNumber(3)
  set missingScope($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMissingScope() => $_has(2);
  @$pb.TagNumber(3)
  void clearMissingScope() => $_clearField(3);

  /// When the daemon tries again on its own (Unix ms, 0 = unknown).
  @$pb.TagNumber(4)
  $fixnum.Int64 get retryAt => $_getI64(3);
  @$pb.TagNumber(4)
  set retryAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRetryAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearRetryAt() => $_clearField(4);

  /// Local commits waiting for the first push.
  @$pb.TagNumber(5)
  $core.int get commitsWaiting => $_getIZ(4);
  @$pb.TagNumber(5)
  set commitsWaiting($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCommitsWaiting() => $_has(4);
  @$pb.TagNumber(5)
  void clearCommitsWaiting() => $_clearField(5);
}

class RerunFailedRequest extends $pb.GeneratedMessage {
  factory RerunFailedRequest({
    $core.String? worktreePath,
    $core.String? runId,
  }) {
    final result = RerunFailedRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (runId != null) result.runId = runId;
    return result;
  }

  RerunFailedRequest._();

  factory RerunFailedRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RerunFailedRequest()..mergeFromBuffer(data, registry);
  factory RerunFailedRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RerunFailedRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RerunFailedRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: RerunFailedRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..aOS(2, _omitFieldNames ? '' : 'runId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RerunFailedRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RerunFailedRequest copyWith(void Function(RerunFailedRequest) updates) =>
      super.copyWith((message) => updates(message as RerunFailedRequest))
          as RerunFailedRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RerunFailedRequest() / RerunFailedRequest.new instead')
  static RerunFailedRequest create() => RerunFailedRequest._();
  static $pb.GeneratedMessage $_createMessage() => RerunFailedRequest._();
  @$core.override
  RerunFailedRequest createEmptyInstance() => RerunFailedRequest._();
  @$core.pragma('dart2js:noInline')
  static RerunFailedRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RerunFailedRequest>(
          RerunFailedRequest.$_createMessage);
  static RerunFailedRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get runId => $_getSZ(1);
  @$pb.TagNumber(2)
  set runId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRunId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRunId() => $_clearField(2);
}

class PipelinesActionResponse extends $pb.GeneratedMessage {
  factory PipelinesActionResponse() => PipelinesActionResponse._();

  PipelinesActionResponse._();

  factory PipelinesActionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PipelinesActionResponse()..mergeFromBuffer(data, registry);
  factory PipelinesActionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PipelinesActionResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PipelinesActionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: PipelinesActionResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PipelinesActionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PipelinesActionResponse copyWith(
          void Function(PipelinesActionResponse) updates) =>
      super.copyWith((message) => updates(message as PipelinesActionResponse))
          as PipelinesActionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PipelinesActionResponse() / PipelinesActionResponse.new instead')
  static PipelinesActionResponse create() => PipelinesActionResponse._();
  static $pb.GeneratedMessage $_createMessage() => PipelinesActionResponse._();
  @$core.override
  PipelinesActionResponse createEmptyInstance() => PipelinesActionResponse._();
  @$core.pragma('dart2js:noInline')
  static PipelinesActionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PipelinesActionResponse>(
          PipelinesActionResponse.$_createMessage);
  static PipelinesActionResponse? _defaultInstance;
}

class ListHostsRequest extends $pb.GeneratedMessage {
  factory ListHostsRequest() => ListHostsRequest._();

  ListHostsRequest._();

  factory ListHostsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListHostsRequest()..mergeFromBuffer(data, registry);
  factory ListHostsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListHostsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListHostsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ListHostsRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListHostsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListHostsRequest copyWith(void Function(ListHostsRequest) updates) =>
      super.copyWith((message) => updates(message as ListHostsRequest))
          as ListHostsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListHostsRequest() / ListHostsRequest.new instead')
  static ListHostsRequest create() => ListHostsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListHostsRequest._();
  @$core.override
  ListHostsRequest createEmptyInstance() => ListHostsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListHostsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListHostsRequest>(
          ListHostsRequest.$_createMessage);
  static ListHostsRequest? _defaultInstance;
}

class ListHostsResponse extends $pb.GeneratedMessage {
  factory ListHostsResponse({
    $core.Iterable<CiHostInfo>? hosts,
  }) {
    final result = ListHostsResponse._();
    if (hosts != null) result.hosts.addAll(hosts);
    return result;
  }

  ListHostsResponse._();

  factory ListHostsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListHostsResponse()..mergeFromBuffer(data, registry);
  factory ListHostsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListHostsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListHostsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ListHostsResponse.$_createMessage)
    ..pPM<CiHostInfo>(1, _omitFieldNames ? '' : 'hosts',
        subBuilder: CiHostInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListHostsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListHostsResponse copyWith(void Function(ListHostsResponse) updates) =>
      super.copyWith((message) => updates(message as ListHostsResponse))
          as ListHostsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListHostsResponse() / ListHostsResponse.new instead')
  static ListHostsResponse create() => ListHostsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListHostsResponse._();
  @$core.override
  ListHostsResponse createEmptyInstance() => ListHostsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListHostsResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListHostsResponse>(
          ListHostsResponse.$_createMessage);
  static ListHostsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CiHostInfo> get hosts => $_getList(0);
}

class CiHostInfo extends $pb.GeneratedMessage {
  factory CiHostInfo({
    $core.String? host,
    CiProvider? provider,
    $core.bool? hasToken,
    $core.bool? usesGh,
    $core.Iterable<$core.String>? repos,
    $core.String? ghAccount,
    $core.bool? ghAvailable,
  }) {
    final result = CiHostInfo._();
    if (host != null) result.host = host;
    if (provider != null) result.provider = provider;
    if (hasToken != null) result.hasToken = hasToken;
    if (usesGh != null) result.usesGh = usesGh;
    if (repos != null) result.repos.addAll(repos);
    if (ghAccount != null) result.ghAccount = ghAccount;
    if (ghAvailable != null) result.ghAvailable = ghAvailable;
    return result;
  }

  CiHostInfo._();

  factory CiHostInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CiHostInfo()..mergeFromBuffer(data, registry);
  factory CiHostInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CiHostInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CiHostInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: CiHostInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aE<CiProvider>(2, _omitFieldNames ? '' : 'provider',
        enumValues: CiProvider.values)
    ..aOB(3, _omitFieldNames ? '' : 'hasToken')
    ..aOB(4, _omitFieldNames ? '' : 'usesGh')
    ..pPS(5, _omitFieldNames ? '' : 'repos')
    ..aOS(6, _omitFieldNames ? '' : 'ghAccount')
    ..aOB(7, _omitFieldNames ? '' : 'ghAvailable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CiHostInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CiHostInfo copyWith(void Function(CiHostInfo) updates) =>
      super.copyWith((message) => updates(message as CiHostInfo)) as CiHostInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CiHostInfo() / CiHostInfo.new instead')
  static CiHostInfo create() => CiHostInfo._();
  static $pb.GeneratedMessage $_createMessage() => CiHostInfo._();
  @$core.override
  CiHostInfo createEmptyInstance() => CiHostInfo._();
  @$core.pragma('dart2js:noInline')
  static CiHostInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CiHostInfo>(CiHostInfo.$_createMessage);
  static CiHostInfo? _defaultInstance;

  /// "github.com", "gitlab.example.com".
  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  @$pb.TagNumber(2)
  CiProvider get provider => $_getN(1);
  @$pb.TagNumber(2)
  set provider(CiProvider value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProvider() => $_has(1);
  @$pb.TagNumber(2)
  void clearProvider() => $_clearField(2);

  /// A token is saved in the keychain.
  @$pb.TagNumber(3)
  $core.bool get hasToken => $_getBF(2);
  @$pb.TagNumber(3)
  set hasToken($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHasToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearHasToken() => $_clearField(3);

  /// No saved token, but the gh CLI is signed in to the host.
  @$pb.TagNumber(4)
  $core.bool get usesGh => $_getBF(3);
  @$pb.TagNumber(4)
  set usesGh($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUsesGh() => $_has(3);
  @$pb.TagNumber(4)
  void clearUsesGh() => $_clearField(4);

  /// Repositories of the workspace on this host ("owner/name").
  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get repos => $_getList(4);

  /// The account gh is signed in as on the host, when it is.
  @$pb.TagNumber(6)
  $core.String get ghAccount => $_getSZ(5);
  @$pb.TagNumber(6)
  set ghAccount($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasGhAccount() => $_has(5);
  @$pb.TagNumber(6)
  void clearGhAccount() => $_clearField(6);

  /// gh is installed and can sign in to this host (GitHub hosts).
  @$pb.TagNumber(7)
  $core.bool get ghAvailable => $_getBF(6);
  @$pb.TagNumber(7)
  set ghAvailable($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasGhAvailable() => $_has(6);
  @$pb.TagNumber(7)
  void clearGhAvailable() => $_clearField(7);
}

class SignInWithGhRequest extends $pb.GeneratedMessage {
  factory SignInWithGhRequest({
    $core.String? host,
  }) {
    final result = SignInWithGhRequest._();
    if (host != null) result.host = host;
    return result;
  }

  SignInWithGhRequest._();

  factory SignInWithGhRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SignInWithGhRequest()..mergeFromBuffer(data, registry);
  factory SignInWithGhRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SignInWithGhRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignInWithGhRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: SignInWithGhRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignInWithGhRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignInWithGhRequest copyWith(void Function(SignInWithGhRequest) updates) =>
      super.copyWith((message) => updates(message as SignInWithGhRequest))
          as SignInWithGhRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use SignInWithGhRequest() / SignInWithGhRequest.new instead')
  static SignInWithGhRequest create() => SignInWithGhRequest._();
  static $pb.GeneratedMessage $_createMessage() => SignInWithGhRequest._();
  @$core.override
  SignInWithGhRequest createEmptyInstance() => SignInWithGhRequest._();
  @$core.pragma('dart2js:noInline')
  static SignInWithGhRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignInWithGhRequest>(
          SignInWithGhRequest.$_createMessage);
  static SignInWithGhRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);
}

class SignInWithGhResponse extends $pb.GeneratedMessage {
  factory SignInWithGhResponse({
    $core.String? terminalId,
  }) {
    final result = SignInWithGhResponse._();
    if (terminalId != null) result.terminalId = terminalId;
    return result;
  }

  SignInWithGhResponse._();

  factory SignInWithGhResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SignInWithGhResponse()..mergeFromBuffer(data, registry);
  factory SignInWithGhResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SignInWithGhResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignInWithGhResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: SignInWithGhResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'terminalId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignInWithGhResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignInWithGhResponse copyWith(void Function(SignInWithGhResponse) updates) =>
      super.copyWith((message) => updates(message as SignInWithGhResponse))
          as SignInWithGhResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SignInWithGhResponse() / SignInWithGhResponse.new instead')
  static SignInWithGhResponse create() => SignInWithGhResponse._();
  static $pb.GeneratedMessage $_createMessage() => SignInWithGhResponse._();
  @$core.override
  SignInWithGhResponse createEmptyInstance() => SignInWithGhResponse._();
  @$core.pragma('dart2js:noInline')
  static SignInWithGhResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignInWithGhResponse>(
          SignInWithGhResponse.$_createMessage);
  static SignInWithGhResponse? _defaultInstance;

  /// The terminal running `gh auth login`, to show.
  @$pb.TagNumber(1)
  $core.String get terminalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set terminalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTerminalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTerminalId() => $_clearField(1);
}

class SaveHostTokenRequest extends $pb.GeneratedMessage {
  factory SaveHostTokenRequest({
    $core.String? host,
    $core.String? token,
  }) {
    final result = SaveHostTokenRequest._();
    if (host != null) result.host = host;
    if (token != null) result.token = token;
    return result;
  }

  SaveHostTokenRequest._();

  factory SaveHostTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveHostTokenRequest()..mergeFromBuffer(data, registry);
  factory SaveHostTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveHostTokenRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveHostTokenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: SaveHostTokenRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aOS(2, _omitFieldNames ? '' : 'token')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveHostTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveHostTokenRequest copyWith(void Function(SaveHostTokenRequest) updates) =>
      super.copyWith((message) => updates(message as SaveHostTokenRequest))
          as SaveHostTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SaveHostTokenRequest() / SaveHostTokenRequest.new instead')
  static SaveHostTokenRequest create() => SaveHostTokenRequest._();
  static $pb.GeneratedMessage $_createMessage() => SaveHostTokenRequest._();
  @$core.override
  SaveHostTokenRequest createEmptyInstance() => SaveHostTokenRequest._();
  @$core.pragma('dart2js:noInline')
  static SaveHostTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SaveHostTokenRequest>(
          SaveHostTokenRequest.$_createMessage);
  static SaveHostTokenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get token => $_getSZ(1);
  @$pb.TagNumber(2)
  set token($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearToken() => $_clearField(2);
}

class TestHostRequest extends $pb.GeneratedMessage {
  factory TestHostRequest({
    $core.String? host,
    $core.String? token,
  }) {
    final result = TestHostRequest._();
    if (host != null) result.host = host;
    if (token != null) result.token = token;
    return result;
  }

  TestHostRequest._();

  factory TestHostRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestHostRequest()..mergeFromBuffer(data, registry);
  factory TestHostRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestHostRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestHostRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TestHostRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aOS(2, _omitFieldNames ? '' : 'token')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestHostRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestHostRequest copyWith(void Function(TestHostRequest) updates) =>
      super.copyWith((message) => updates(message as TestHostRequest))
          as TestHostRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TestHostRequest() / TestHostRequest.new instead')
  static TestHostRequest create() => TestHostRequest._();
  static $pb.GeneratedMessage $_createMessage() => TestHostRequest._();
  @$core.override
  TestHostRequest createEmptyInstance() => TestHostRequest._();
  @$core.pragma('dart2js:noInline')
  static TestHostRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TestHostRequest>(
          TestHostRequest.$_createMessage);
  static TestHostRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  /// Empty: test the saved one.
  @$pb.TagNumber(2)
  $core.String get token => $_getSZ(1);
  @$pb.TagNumber(2)
  set token($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearToken() => $_clearField(2);
}

class TestHostResponse extends $pb.GeneratedMessage {
  factory TestHostResponse({
    $core.String? message,
    CiProblem? problem,
  }) {
    final result = TestHostResponse._();
    if (message != null) result.message = message;
    if (problem != null) result.problem = problem;
    return result;
  }

  TestHostResponse._();

  factory TestHostResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestHostResponse()..mergeFromBuffer(data, registry);
  factory TestHostResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestHostResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestHostResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TestHostResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'message')
    ..aOM<CiProblem>(2, _omitFieldNames ? '' : 'problem',
        subBuilder: CiProblem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestHostResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestHostResponse copyWith(void Function(TestHostResponse) updates) =>
      super.copyWith((message) => updates(message as TestHostResponse))
          as TestHostResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TestHostResponse() / TestHostResponse.new instead')
  static TestHostResponse create() => TestHostResponse._();
  static $pb.GeneratedMessage $_createMessage() => TestHostResponse._();
  @$core.override
  TestHostResponse createEmptyInstance() => TestHostResponse._();
  @$core.pragma('dart2js:noInline')
  static TestHostResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TestHostResponse>(
          TestHostResponse.$_createMessage);
  static TestHostResponse? _defaultInstance;

  /// "Signed in as ana" on success.
  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);

  /// Set when the token doesn't work.
  @$pb.TagNumber(2)
  CiProblem get problem => $_getN(1);
  @$pb.TagNumber(2)
  set problem(CiProblem value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProblem() => $_has(1);
  @$pb.TagNumber(2)
  void clearProblem() => $_clearField(2);
  @$pb.TagNumber(2)
  CiProblem ensureProblem() => $_ensure(1);
}

class PullRequest extends $pb.GeneratedMessage {
  factory PullRequest({
    $fixnum.Int64? number,
    $core.String? label,
    $core.String? title,
    Person? author,
    $core.String? branch,
    $core.String? base,
    $core.bool? draft,
    PrState? state,
    ReviewState? review,
    $core.bool? reviewRequestedFromYou,
    $core.Iterable<Person>? reviewers,
    $core.int? checksPassed,
    $core.int? checksTotal,
    CiState? checksState,
    $core.String? url,
    $fixnum.Int64? createdAt,
    $fixnum.Int64? updatedAt,
    $core.int? commentCount,
  }) {
    final result = PullRequest._();
    if (number != null) result.number = number;
    if (label != null) result.label = label;
    if (title != null) result.title = title;
    if (author != null) result.author = author;
    if (branch != null) result.branch = branch;
    if (base != null) result.base = base;
    if (draft != null) result.draft = draft;
    if (state != null) result.state = state;
    if (review != null) result.review = review;
    if (reviewRequestedFromYou != null)
      result.reviewRequestedFromYou = reviewRequestedFromYou;
    if (reviewers != null) result.reviewers.addAll(reviewers);
    if (checksPassed != null) result.checksPassed = checksPassed;
    if (checksTotal != null) result.checksTotal = checksTotal;
    if (checksState != null) result.checksState = checksState;
    if (url != null) result.url = url;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    if (commentCount != null) result.commentCount = commentCount;
    return result;
  }

  PullRequest._();

  factory PullRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PullRequest()..mergeFromBuffer(data, registry);
  factory PullRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PullRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PullRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: PullRequest.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'number', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOM<Person>(4, _omitFieldNames ? '' : 'author',
        subBuilder: Person.$_createMessage)
    ..aOS(5, _omitFieldNames ? '' : 'branch')
    ..aOS(6, _omitFieldNames ? '' : 'base')
    ..aOB(7, _omitFieldNames ? '' : 'draft')
    ..aE<PrState>(8, _omitFieldNames ? '' : 'state', enumValues: PrState.values)
    ..aE<ReviewState>(9, _omitFieldNames ? '' : 'review',
        enumValues: ReviewState.values)
    ..aOB(10, _omitFieldNames ? '' : 'reviewRequestedFromYou')
    ..pPM<Person>(11, _omitFieldNames ? '' : 'reviewers',
        subBuilder: Person.$_createMessage)
    ..aI(12, _omitFieldNames ? '' : 'checksPassed',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(13, _omitFieldNames ? '' : 'checksTotal',
        fieldType: $pb.PbFieldType.OU3)
    ..aE<CiState>(14, _omitFieldNames ? '' : 'checksState',
        enumValues: CiState.values)
    ..aOS(15, _omitFieldNames ? '' : 'url')
    ..aInt64(16, _omitFieldNames ? '' : 'createdAt')
    ..aInt64(17, _omitFieldNames ? '' : 'updatedAt')
    ..aI(18, _omitFieldNames ? '' : 'commentCount',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullRequest copyWith(void Function(PullRequest) updates) =>
      super.copyWith((message) => updates(message as PullRequest))
          as PullRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PullRequest() / PullRequest.new instead')
  static PullRequest create() => PullRequest._();
  static $pb.GeneratedMessage $_createMessage() => PullRequest._();
  @$core.override
  PullRequest createEmptyInstance() => PullRequest._();
  @$core.pragma('dart2js:noInline')
  static PullRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PullRequest>(
          PullRequest.$_createMessage);
  static PullRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get number => $_getI64(0);
  @$pb.TagNumber(1)
  set number($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNumber() => $_has(0);
  @$pb.TagNumber(1)
  void clearNumber() => $_clearField(1);

  /// As the host shows it: "#521", "!231".
  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  Person get author => $_getN(3);
  @$pb.TagNumber(4)
  set author(Person value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasAuthor() => $_has(3);
  @$pb.TagNumber(4)
  void clearAuthor() => $_clearField(4);
  @$pb.TagNumber(4)
  Person ensureAuthor() => $_ensure(3);

  /// Source and target branches.
  @$pb.TagNumber(5)
  $core.String get branch => $_getSZ(4);
  @$pb.TagNumber(5)
  set branch($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBranch() => $_has(4);
  @$pb.TagNumber(5)
  void clearBranch() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get base => $_getSZ(5);
  @$pb.TagNumber(6)
  set base($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBase() => $_has(5);
  @$pb.TagNumber(6)
  void clearBase() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get draft => $_getBF(6);
  @$pb.TagNumber(7)
  set draft($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDraft() => $_has(6);
  @$pb.TagNumber(7)
  void clearDraft() => $_clearField(7);

  @$pb.TagNumber(8)
  PrState get state => $_getN(7);
  @$pb.TagNumber(8)
  set state(PrState value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasState() => $_has(7);
  @$pb.TagNumber(8)
  void clearState() => $_clearField(8);

  @$pb.TagNumber(9)
  ReviewState get review => $_getN(8);
  @$pb.TagNumber(9)
  set review(ReviewState value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasReview() => $_has(8);
  @$pb.TagNumber(9)
  void clearReview() => $_clearField(9);

  /// Someone asked the user to review it.
  @$pb.TagNumber(10)
  $core.bool get reviewRequestedFromYou => $_getBF(9);
  @$pb.TagNumber(10)
  set reviewRequestedFromYou($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasReviewRequestedFromYou() => $_has(9);
  @$pb.TagNumber(10)
  void clearReviewRequestedFromYou() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<Person> get reviewers => $_getList(10);

  /// Checks on its latest commit: passed of total (0 of 0 = none ran).
  @$pb.TagNumber(12)
  $core.int get checksPassed => $_getIZ(11);
  @$pb.TagNumber(12)
  set checksPassed($core.int value) => $_setUnsignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasChecksPassed() => $_has(11);
  @$pb.TagNumber(12)
  void clearChecksPassed() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get checksTotal => $_getIZ(12);
  @$pb.TagNumber(13)
  set checksTotal($core.int value) => $_setUnsignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasChecksTotal() => $_has(12);
  @$pb.TagNumber(13)
  void clearChecksTotal() => $_clearField(13);

  /// Overall state of those checks; unset when none ran.
  @$pb.TagNumber(14)
  CiState get checksState => $_getN(13);
  @$pb.TagNumber(14)
  set checksState(CiState value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasChecksState() => $_has(13);
  @$pb.TagNumber(14)
  void clearChecksState() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get url => $_getSZ(14);
  @$pb.TagNumber(15)
  set url($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasUrl() => $_has(14);
  @$pb.TagNumber(15)
  void clearUrl() => $_clearField(15);

  /// Unix ms.
  @$pb.TagNumber(16)
  $fixnum.Int64 get createdAt => $_getI64(15);
  @$pb.TagNumber(16)
  set createdAt($fixnum.Int64 value) => $_setInt64(15, value);
  @$pb.TagNumber(16)
  $core.bool hasCreatedAt() => $_has(15);
  @$pb.TagNumber(16)
  void clearCreatedAt() => $_clearField(16);

  @$pb.TagNumber(17)
  $fixnum.Int64 get updatedAt => $_getI64(16);
  @$pb.TagNumber(17)
  set updatedAt($fixnum.Int64 value) => $_setInt64(16, value);
  @$pb.TagNumber(17)
  $core.bool hasUpdatedAt() => $_has(16);
  @$pb.TagNumber(17)
  void clearUpdatedAt() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.int get commentCount => $_getIZ(17);
  @$pb.TagNumber(18)
  set commentCount($core.int value) => $_setUnsignedInt32(17, value);
  @$pb.TagNumber(18)
  $core.bool hasCommentCount() => $_has(17);
  @$pb.TagNumber(18)
  void clearCommentCount() => $_clearField(18);
}

class ListPullRequestsRequest extends $pb.GeneratedMessage {
  factory ListPullRequestsRequest({
    $core.String? repoPath,
    $core.bool? refresh,
  }) {
    final result = ListPullRequestsRequest._();
    if (repoPath != null) result.repoPath = repoPath;
    if (refresh != null) result.refresh = refresh;
    return result;
  }

  ListPullRequestsRequest._();

  factory ListPullRequestsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListPullRequestsRequest()..mergeFromBuffer(data, registry);
  factory ListPullRequestsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListPullRequestsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListPullRequestsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ListPullRequestsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'repoPath')
    ..aOB(2, _omitFieldNames ? '' : 'refresh')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPullRequestsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPullRequestsRequest copyWith(
          void Function(ListPullRequestsRequest) updates) =>
      super.copyWith((message) => updates(message as ListPullRequestsRequest))
          as ListPullRequestsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListPullRequestsRequest() / ListPullRequestsRequest.new instead')
  static ListPullRequestsRequest create() => ListPullRequestsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListPullRequestsRequest._();
  @$core.override
  ListPullRequestsRequest createEmptyInstance() => ListPullRequestsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListPullRequestsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListPullRequestsRequest>(
          ListPullRequestsRequest.$_createMessage);
  static ListPullRequestsRequest? _defaultInstance;

  /// The repository's main checkout.
  @$pb.TagNumber(1)
  $core.String get repoPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set repoPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRepoPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearRepoPath() => $_clearField(1);

  /// Ask the host even if the last answer is recent.
  @$pb.TagNumber(2)
  $core.bool get refresh => $_getBF(1);
  @$pb.TagNumber(2)
  set refresh($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRefresh() => $_has(1);
  @$pb.TagNumber(2)
  void clearRefresh() => $_clearField(2);
}

class PullRequestList extends $pb.GeneratedMessage {
  factory PullRequestList({
    CiProvider? provider,
    $core.Iterable<PullRequest>? pullRequests,
    CiProblem? problem,
  }) {
    final result = PullRequestList._();
    if (provider != null) result.provider = provider;
    if (pullRequests != null) result.pullRequests.addAll(pullRequests);
    if (problem != null) result.problem = problem;
    return result;
  }

  PullRequestList._();

  factory PullRequestList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PullRequestList()..mergeFromBuffer(data, registry);
  factory PullRequestList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PullRequestList()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PullRequestList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: PullRequestList.$_createMessage)
    ..aE<CiProvider>(1, _omitFieldNames ? '' : 'provider',
        enumValues: CiProvider.values)
    ..pPM<PullRequest>(2, _omitFieldNames ? '' : 'pullRequests',
        subBuilder: PullRequest.$_createMessage)
    ..aOM<CiProblem>(3, _omitFieldNames ? '' : 'problem',
        subBuilder: CiProblem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullRequestList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullRequestList copyWith(void Function(PullRequestList) updates) =>
      super.copyWith((message) => updates(message as PullRequestList))
          as PullRequestList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PullRequestList() / PullRequestList.new instead')
  static PullRequestList create() => PullRequestList._();
  static $pb.GeneratedMessage $_createMessage() => PullRequestList._();
  @$core.override
  PullRequestList createEmptyInstance() => PullRequestList._();
  @$core.pragma('dart2js:noInline')
  static PullRequestList getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PullRequestList>(
          PullRequestList.$_createMessage);
  static PullRequestList? _defaultInstance;

  @$pb.TagNumber(1)
  CiProvider get provider => $_getN(0);
  @$pb.TagNumber(1)
  set provider(CiProvider value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasProvider() => $_has(0);
  @$pb.TagNumber(1)
  void clearProvider() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<PullRequest> get pullRequests => $_getList(1);

  /// Why they couldn't be read (the list is then empty).
  @$pb.TagNumber(3)
  CiProblem get problem => $_getN(2);
  @$pb.TagNumber(3)
  set problem(CiProblem value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasProblem() => $_has(2);
  @$pb.TagNumber(3)
  void clearProblem() => $_clearField(3);
  @$pb.TagNumber(3)
  CiProblem ensureProblem() => $_ensure(2);
}

class BranchPullRequestRequest extends $pb.GeneratedMessage {
  factory BranchPullRequestRequest({
    $core.String? worktreePath,
    $core.bool? refresh,
  }) {
    final result = BranchPullRequestRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (refresh != null) result.refresh = refresh;
    return result;
  }

  BranchPullRequestRequest._();

  factory BranchPullRequestRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BranchPullRequestRequest()..mergeFromBuffer(data, registry);
  factory BranchPullRequestRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BranchPullRequestRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BranchPullRequestRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: BranchPullRequestRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..aOB(2, _omitFieldNames ? '' : 'refresh')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BranchPullRequestRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BranchPullRequestRequest copyWith(
          void Function(BranchPullRequestRequest) updates) =>
      super.copyWith((message) => updates(message as BranchPullRequestRequest))
          as BranchPullRequestRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use BranchPullRequestRequest() / BranchPullRequestRequest.new instead')
  static BranchPullRequestRequest create() => BranchPullRequestRequest._();
  static $pb.GeneratedMessage $_createMessage() => BranchPullRequestRequest._();
  @$core.override
  BranchPullRequestRequest createEmptyInstance() =>
      BranchPullRequestRequest._();
  @$core.pragma('dart2js:noInline')
  static BranchPullRequestRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BranchPullRequestRequest>(
          BranchPullRequestRequest.$_createMessage);
  static BranchPullRequestRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get refresh => $_getBF(1);
  @$pb.TagNumber(2)
  set refresh($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRefresh() => $_has(1);
  @$pb.TagNumber(2)
  void clearRefresh() => $_clearField(2);
}

class BranchPullRequest extends $pb.GeneratedMessage {
  factory BranchPullRequest({
    CiProvider? provider,
    PullRequest? pullRequest,
    CiProblem? problem,
  }) {
    final result = BranchPullRequest._();
    if (provider != null) result.provider = provider;
    if (pullRequest != null) result.pullRequest = pullRequest;
    if (problem != null) result.problem = problem;
    return result;
  }

  BranchPullRequest._();

  factory BranchPullRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BranchPullRequest()..mergeFromBuffer(data, registry);
  factory BranchPullRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BranchPullRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BranchPullRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: BranchPullRequest.$_createMessage)
    ..aE<CiProvider>(1, _omitFieldNames ? '' : 'provider',
        enumValues: CiProvider.values)
    ..aOM<PullRequest>(2, _omitFieldNames ? '' : 'pullRequest',
        subBuilder: PullRequest.$_createMessage)
    ..aOM<CiProblem>(3, _omitFieldNames ? '' : 'problem',
        subBuilder: CiProblem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BranchPullRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BranchPullRequest copyWith(void Function(BranchPullRequest) updates) =>
      super.copyWith((message) => updates(message as BranchPullRequest))
          as BranchPullRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BranchPullRequest() / BranchPullRequest.new instead')
  static BranchPullRequest create() => BranchPullRequest._();
  static $pb.GeneratedMessage $_createMessage() => BranchPullRequest._();
  @$core.override
  BranchPullRequest createEmptyInstance() => BranchPullRequest._();
  @$core.pragma('dart2js:noInline')
  static BranchPullRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BranchPullRequest>(
          BranchPullRequest.$_createMessage);
  static BranchPullRequest? _defaultInstance;

  @$pb.TagNumber(1)
  CiProvider get provider => $_getN(0);
  @$pb.TagNumber(1)
  set provider(CiProvider value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasProvider() => $_has(0);
  @$pb.TagNumber(1)
  void clearProvider() => $_clearField(1);

  @$pb.TagNumber(2)
  PullRequest get pullRequest => $_getN(1);
  @$pb.TagNumber(2)
  set pullRequest(PullRequest value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPullRequest() => $_has(1);
  @$pb.TagNumber(2)
  void clearPullRequest() => $_clearField(2);
  @$pb.TagNumber(2)
  PullRequest ensurePullRequest() => $_ensure(1);

  @$pb.TagNumber(3)
  CiProblem get problem => $_getN(2);
  @$pb.TagNumber(3)
  set problem(CiProblem value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasProblem() => $_has(2);
  @$pb.TagNumber(3)
  void clearProblem() => $_clearField(3);
  @$pb.TagNumber(3)
  CiProblem ensureProblem() => $_ensure(2);
}

class CreatePullRequestRequest extends $pb.GeneratedMessage {
  factory CreatePullRequestRequest({
    $core.String? worktreePath,
    $core.String? title,
    $core.String? body,
    $core.String? base,
    $core.bool? draft,
  }) {
    final result = CreatePullRequestRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (title != null) result.title = title;
    if (body != null) result.body = body;
    if (base != null) result.base = base;
    if (draft != null) result.draft = draft;
    return result;
  }

  CreatePullRequestRequest._();

  factory CreatePullRequestRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreatePullRequestRequest()..mergeFromBuffer(data, registry);
  factory CreatePullRequestRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreatePullRequestRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreatePullRequestRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: CreatePullRequestRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'body')
    ..aOS(4, _omitFieldNames ? '' : 'base')
    ..aOB(5, _omitFieldNames ? '' : 'draft')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePullRequestRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePullRequestRequest copyWith(
          void Function(CreatePullRequestRequest) updates) =>
      super.copyWith((message) => updates(message as CreatePullRequestRequest))
          as CreatePullRequestRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CreatePullRequestRequest() / CreatePullRequestRequest.new instead')
  static CreatePullRequestRequest create() => CreatePullRequestRequest._();
  static $pb.GeneratedMessage $_createMessage() => CreatePullRequestRequest._();
  @$core.override
  CreatePullRequestRequest createEmptyInstance() =>
      CreatePullRequestRequest._();
  @$core.pragma('dart2js:noInline')
  static CreatePullRequestRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreatePullRequestRequest>(
          CreatePullRequestRequest.$_createMessage);
  static CreatePullRequestRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// Markdown.
  @$pb.TagNumber(3)
  $core.String get body => $_getSZ(2);
  @$pb.TagNumber(3)
  set body($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBody() => $_has(2);
  @$pb.TagNumber(3)
  void clearBody() => $_clearField(3);

  /// Target branch; empty = the repository's default branch.
  @$pb.TagNumber(4)
  $core.String get base => $_getSZ(3);
  @$pb.TagNumber(4)
  set base($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBase() => $_has(3);
  @$pb.TagNumber(4)
  void clearBase() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get draft => $_getBF(4);
  @$pb.TagNumber(5)
  set draft($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDraft() => $_has(4);
  @$pb.TagNumber(5)
  void clearDraft() => $_clearField(5);
}

class DocSource extends $pb.GeneratedMessage {
  factory DocSource({
    $core.String? id,
    DocKind? kind,
    $core.String? name,
    $core.String? location,
  }) {
    final result = DocSource._();
    if (id != null) result.id = id;
    if (kind != null) result.kind = kind;
    if (name != null) result.name = name;
    if (location != null) result.location = location;
    return result;
  }

  DocSource._();

  factory DocSource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocSource()..mergeFromBuffer(data, registry);
  factory DocSource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocSource()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DocSource',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DocSource.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aE<DocKind>(2, _omitFieldNames ? '' : 'kind', enumValues: DocKind.values)
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'location')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocSource clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocSource copyWith(void Function(DocSource) updates) =>
      super.copyWith((message) => updates(message as DocSource)) as DocSource;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DocSource() / DocSource.new instead')
  static DocSource create() => DocSource._();
  static $pb.GeneratedMessage $_createMessage() => DocSource._();
  @$core.override
  DocSource createEmptyInstance() => DocSource._();
  @$core.pragma('dart2js:noInline')
  static DocSource getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DocSource>(DocSource.$_createMessage);
  static DocSource? _defaultInstance;

  /// The task source it reads through.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  DocKind get kind => $_getN(1);
  @$pb.TagNumber(2)
  set kind(DocKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  /// `acme.atlassian.net`, the vault's folder name.
  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  /// The site URL or the vault's path.
  @$pb.TagNumber(4)
  $core.String get location => $_getSZ(3);
  @$pb.TagNumber(4)
  set location($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLocation() => $_has(3);
  @$pb.TagNumber(4)
  void clearLocation() => $_clearField(4);
}

class DocSummary extends $pb.GeneratedMessage {
  factory DocSummary({
    $core.String? id,
    $core.String? title,
    $core.String? place,
    $fixnum.Int64? updatedAt,
    $core.String? author,
    $core.String? url,
    $core.String? excerpt,
  }) {
    final result = DocSummary._();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (place != null) result.place = place;
    if (updatedAt != null) result.updatedAt = updatedAt;
    if (author != null) result.author = author;
    if (url != null) result.url = url;
    if (excerpt != null) result.excerpt = excerpt;
    return result;
  }

  DocSummary._();

  factory DocSummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocSummary()..mergeFromBuffer(data, registry);
  factory DocSummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocSummary()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DocSummary',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DocSummary.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'place')
    ..aInt64(4, _omitFieldNames ? '' : 'updatedAt')
    ..aOS(5, _omitFieldNames ? '' : 'author')
    ..aOS(6, _omitFieldNames ? '' : 'url')
    ..aOS(7, _omitFieldNames ? '' : 'excerpt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocSummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocSummary copyWith(void Function(DocSummary) updates) =>
      super.copyWith((message) => updates(message as DocSummary)) as DocSummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DocSummary() / DocSummary.new instead')
  static DocSummary create() => DocSummary._();
  static $pb.GeneratedMessage $_createMessage() => DocSummary._();
  @$core.override
  DocSummary createEmptyInstance() => DocSummary._();
  @$core.pragma('dart2js:noInline')
  static DocSummary getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DocSummary>(DocSummary.$_createMessage);
  static DocSummary? _defaultInstance;

  /// `<source>/<external>`.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// The Confluence space, or the note's folder.
  @$pb.TagNumber(3)
  $core.String get place => $_getSZ(2);
  @$pb.TagNumber(3)
  set place($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPlace() => $_has(2);
  @$pb.TagNumber(3)
  void clearPlace() => $_clearField(3);

  /// Unix ms; 0 when unknown.
  @$pb.TagNumber(4)
  $fixnum.Int64 get updatedAt => $_getI64(3);
  @$pb.TagNumber(4)
  set updatedAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUpdatedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearUpdatedAt() => $_clearField(4);

  /// Who last edited it; empty when unknown.
  @$pb.TagNumber(5)
  $core.String get author => $_getSZ(4);
  @$pb.TagNumber(5)
  set author($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAuthor() => $_has(4);
  @$pb.TagNumber(5)
  void clearAuthor() => $_clearField(5);

  /// Where it opens: the page on the site, `obsidian://` for a note.
  @$pb.TagNumber(6)
  $core.String get url => $_getSZ(5);
  @$pb.TagNumber(6)
  set url($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearUrl() => $_clearField(6);

  /// Text around a search match; empty outside a search.
  @$pb.TagNumber(7)
  $core.String get excerpt => $_getSZ(6);
  @$pb.TagNumber(7)
  set excerpt($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasExcerpt() => $_has(6);
  @$pb.TagNumber(7)
  void clearExcerpt() => $_clearField(7);
}

class DocGroup extends $pb.GeneratedMessage {
  factory DocGroup({
    DocSource? source,
    $core.Iterable<DocSummary>? docs,
    $core.String? problem,
    $core.bool? problemIsAuth,
  }) {
    final result = DocGroup._();
    if (source != null) result.source = source;
    if (docs != null) result.docs.addAll(docs);
    if (problem != null) result.problem = problem;
    if (problemIsAuth != null) result.problemIsAuth = problemIsAuth;
    return result;
  }

  DocGroup._();

  factory DocGroup.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocGroup()..mergeFromBuffer(data, registry);
  factory DocGroup.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocGroup()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DocGroup',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DocGroup.$_createMessage)
    ..aOM<DocSource>(1, _omitFieldNames ? '' : 'source',
        subBuilder: DocSource.$_createMessage)
    ..pPM<DocSummary>(2, _omitFieldNames ? '' : 'docs',
        subBuilder: DocSummary.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'problem')
    ..aOB(4, _omitFieldNames ? '' : 'problemIsAuth')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocGroup clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocGroup copyWith(void Function(DocGroup) updates) =>
      super.copyWith((message) => updates(message as DocGroup)) as DocGroup;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DocGroup() / DocGroup.new instead')
  static DocGroup create() => DocGroup._();
  static $pb.GeneratedMessage $_createMessage() => DocGroup._();
  @$core.override
  DocGroup createEmptyInstance() => DocGroup._();
  @$core.pragma('dart2js:noInline')
  static DocGroup getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DocGroup>(DocGroup.$_createMessage);
  static DocGroup? _defaultInstance;

  @$pb.TagNumber(1)
  DocSource get source => $_getN(0);
  @$pb.TagNumber(1)
  set source(DocSource value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSource() => $_has(0);
  @$pb.TagNumber(1)
  void clearSource() => $_clearField(1);
  @$pb.TagNumber(1)
  DocSource ensureSource() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<DocSummary> get docs => $_getList(1);

  /// Why its pages can't be read; empty when they can.
  @$pb.TagNumber(3)
  $core.String get problem => $_getSZ(2);
  @$pb.TagNumber(3)
  set problem($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProblem() => $_has(2);
  @$pb.TagNumber(3)
  void clearProblem() => $_clearField(3);

  /// The problem is the account's credentials (fixed in Settings › Tasks).
  @$pb.TagNumber(4)
  $core.bool get problemIsAuth => $_getBF(3);
  @$pb.TagNumber(4)
  set problemIsAuth($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasProblemIsAuth() => $_has(3);
  @$pb.TagNumber(4)
  void clearProblemIsAuth() => $_clearField(4);
}

class ListDocsRequest extends $pb.GeneratedMessage {
  factory ListDocsRequest({
    $core.String? query,
    $core.int? limit,
    $core.bool? refresh,
  }) {
    final result = ListDocsRequest._();
    if (query != null) result.query = query;
    if (limit != null) result.limit = limit;
    if (refresh != null) result.refresh = refresh;
    return result;
  }

  ListDocsRequest._();

  factory ListDocsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListDocsRequest()..mergeFromBuffer(data, registry);
  factory ListDocsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListDocsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListDocsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ListDocsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'query')
    ..aI(2, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'refresh')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDocsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDocsRequest copyWith(void Function(ListDocsRequest) updates) =>
      super.copyWith((message) => updates(message as ListDocsRequest))
          as ListDocsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListDocsRequest() / ListDocsRequest.new instead')
  static ListDocsRequest create() => ListDocsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListDocsRequest._();
  @$core.override
  ListDocsRequest createEmptyInstance() => ListDocsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListDocsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListDocsRequest>(
          ListDocsRequest.$_createMessage);
  static ListDocsRequest? _defaultInstance;

  /// Empty: recent pages.
  @$pb.TagNumber(1)
  $core.String get query => $_getSZ(0);
  @$pb.TagNumber(1)
  set query($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuery() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuery() => $_clearField(1);

  /// Per knowledge base; 0 = 30.
  @$pb.TagNumber(2)
  $core.int get limit => $_getIZ(1);
  @$pb.TagNumber(2)
  set limit($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLimit() => $_has(1);
  @$pb.TagNumber(2)
  void clearLimit() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get refresh => $_getBF(2);
  @$pb.TagNumber(3)
  set refresh($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRefresh() => $_has(2);
  @$pb.TagNumber(3)
  void clearRefresh() => $_clearField(3);
}

class DocList extends $pb.GeneratedMessage {
  factory DocList({
    $core.Iterable<DocGroup>? groups,
  }) {
    final result = DocList._();
    if (groups != null) result.groups.addAll(groups);
    return result;
  }

  DocList._();

  factory DocList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocList()..mergeFromBuffer(data, registry);
  factory DocList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocList()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DocList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DocList.$_createMessage)
    ..pPM<DocGroup>(1, _omitFieldNames ? '' : 'groups',
        subBuilder: DocGroup.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocList copyWith(void Function(DocList) updates) =>
      super.copyWith((message) => updates(message as DocList)) as DocList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DocList() / DocList.new instead')
  static DocList create() => DocList._();
  static $pb.GeneratedMessage $_createMessage() => DocList._();
  @$core.override
  DocList createEmptyInstance() => DocList._();
  @$core.pragma('dart2js:noInline')
  static DocList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DocList>(DocList.$_createMessage);
  static DocList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DocGroup> get groups => $_getList(0);
}

class ReadDocRequest extends $pb.GeneratedMessage {
  factory ReadDocRequest({
    $core.String? id,
  }) {
    final result = ReadDocRequest._();
    if (id != null) result.id = id;
    return result;
  }

  ReadDocRequest._();

  factory ReadDocRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReadDocRequest()..mergeFromBuffer(data, registry);
  factory ReadDocRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReadDocRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReadDocRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: ReadDocRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReadDocRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReadDocRequest copyWith(void Function(ReadDocRequest) updates) =>
      super.copyWith((message) => updates(message as ReadDocRequest))
          as ReadDocRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReadDocRequest() / ReadDocRequest.new instead')
  static ReadDocRequest create() => ReadDocRequest._();
  static $pb.GeneratedMessage $_createMessage() => ReadDocRequest._();
  @$core.override
  ReadDocRequest createEmptyInstance() => ReadDocRequest._();
  @$core.pragma('dart2js:noInline')
  static ReadDocRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ReadDocRequest>(
          ReadDocRequest.$_createMessage);
  static ReadDocRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class Doc extends $pb.GeneratedMessage {
  factory Doc({
    DocSummary? summary,
    DocSource? source,
    $core.String? markdown,
    $core.Iterable<$core.String>? path,
    $core.String? file,
  }) {
    final result = Doc._();
    if (summary != null) result.summary = summary;
    if (source != null) result.source = source;
    if (markdown != null) result.markdown = markdown;
    if (path != null) result.path.addAll(path);
    if (file != null) result.file = file;
    return result;
  }

  Doc._();

  factory Doc.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Doc()..mergeFromBuffer(data, registry);
  factory Doc.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Doc()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Doc',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: Doc.$_createMessage)
    ..aOM<DocSummary>(1, _omitFieldNames ? '' : 'summary',
        subBuilder: DocSummary.$_createMessage)
    ..aOM<DocSource>(2, _omitFieldNames ? '' : 'source',
        subBuilder: DocSource.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'markdown')
    ..pPS(4, _omitFieldNames ? '' : 'path')
    ..aOS(5, _omitFieldNames ? '' : 'file')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Doc clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Doc copyWith(void Function(Doc) updates) =>
      super.copyWith((message) => updates(message as Doc)) as Doc;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Doc() / Doc.new instead')
  static Doc create() => Doc._();
  static $pb.GeneratedMessage $_createMessage() => Doc._();
  @$core.override
  Doc createEmptyInstance() => Doc._();
  @$core.pragma('dart2js:noInline')
  static Doc getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Doc>(Doc.$_createMessage);
  static Doc? _defaultInstance;

  @$pb.TagNumber(1)
  DocSummary get summary => $_getN(0);
  @$pb.TagNumber(1)
  set summary(DocSummary value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSummary() => $_has(0);
  @$pb.TagNumber(1)
  void clearSummary() => $_clearField(1);
  @$pb.TagNumber(1)
  DocSummary ensureSummary() => $_ensure(0);

  @$pb.TagNumber(2)
  DocSource get source => $_getN(1);
  @$pb.TagNumber(2)
  set source(DocSource value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSource() => $_has(1);
  @$pb.TagNumber(2)
  void clearSource() => $_clearField(2);
  @$pb.TagNumber(2)
  DocSource ensureSource() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get markdown => $_getSZ(2);
  @$pb.TagNumber(3)
  set markdown($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMarkdown() => $_has(2);
  @$pb.TagNumber(3)
  void clearMarkdown() => $_clearField(3);

  /// Titles above the page: the space or vault, then folders.
  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get path => $_getList(3);

  /// The note's file, for a vault; empty otherwise.
  @$pb.TagNumber(5)
  $core.String get file => $_getSZ(4);
  @$pb.TagNumber(5)
  set file($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFile() => $_has(4);
  @$pb.TagNumber(5)
  void clearFile() => $_clearField(5);
}

class BrowseDocsRequest extends $pb.GeneratedMessage {
  factory BrowseDocsRequest({
    $core.String? sourceId,
    $core.String? parent,
    $core.int? limit,
    $core.bool? refresh,
  }) {
    final result = BrowseDocsRequest._();
    if (sourceId != null) result.sourceId = sourceId;
    if (parent != null) result.parent = parent;
    if (limit != null) result.limit = limit;
    if (refresh != null) result.refresh = refresh;
    return result;
  }

  BrowseDocsRequest._();

  factory BrowseDocsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BrowseDocsRequest()..mergeFromBuffer(data, registry);
  factory BrowseDocsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BrowseDocsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BrowseDocsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: BrowseDocsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sourceId')
    ..aOS(2, _omitFieldNames ? '' : 'parent')
    ..aI(3, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..aOB(4, _omitFieldNames ? '' : 'refresh')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BrowseDocsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BrowseDocsRequest copyWith(void Function(BrowseDocsRequest) updates) =>
      super.copyWith((message) => updates(message as BrowseDocsRequest))
          as BrowseDocsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BrowseDocsRequest() / BrowseDocsRequest.new instead')
  static BrowseDocsRequest create() => BrowseDocsRequest._();
  static $pb.GeneratedMessage $_createMessage() => BrowseDocsRequest._();
  @$core.override
  BrowseDocsRequest createEmptyInstance() => BrowseDocsRequest._();
  @$core.pragma('dart2js:noInline')
  static BrowseDocsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BrowseDocsRequest>(
          BrowseDocsRequest.$_createMessage);
  static BrowseDocsRequest? _defaultInstance;

  /// DocSource.id.
  @$pb.TagNumber(1)
  $core.String get sourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sourceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourceId() => $_clearField(1);

  /// A DocNode.key from the level above; empty for the top level.
  @$pb.TagNumber(2)
  $core.String get parent => $_getSZ(1);
  @$pb.TagNumber(2)
  set parent($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasParent() => $_has(1);
  @$pb.TagNumber(2)
  void clearParent() => $_clearField(2);

  /// 0 = 200.
  @$pb.TagNumber(3)
  $core.int get limit => $_getIZ(2);
  @$pb.TagNumber(3)
  set limit($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimit() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get refresh => $_getBF(3);
  @$pb.TagNumber(4)
  set refresh($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRefresh() => $_has(3);
  @$pb.TagNumber(4)
  void clearRefresh() => $_clearField(4);
}

/// A space, a folder or a page within a level.
class DocNode extends $pb.GeneratedMessage {
  factory DocNode({
    $core.String? key,
    $core.String? title,
    DocSummary? doc,
    $core.int? children,
    $core.String? note,
  }) {
    final result = DocNode._();
    if (key != null) result.key = key;
    if (title != null) result.title = title;
    if (doc != null) result.doc = doc;
    if (children != null) result.children = children;
    if (note != null) result.note = note;
    return result;
  }

  DocNode._();

  factory DocNode.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocNode()..mergeFromBuffer(data, registry);
  factory DocNode.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocNode()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DocNode',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DocNode.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOM<DocSummary>(3, _omitFieldNames ? '' : 'doc',
        subBuilder: DocSummary.$_createMessage)
    ..aI(4, _omitFieldNames ? '' : 'children', fieldType: $pb.PbFieldType.OU3)
    ..aOS(5, _omitFieldNames ? '' : 'note')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocNode clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocNode copyWith(void Function(DocNode) updates) =>
      super.copyWith((message) => updates(message as DocNode)) as DocNode;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DocNode() / DocNode.new instead')
  static DocNode create() => DocNode._();
  static $pb.GeneratedMessage $_createMessage() => DocNode._();
  @$core.override
  DocNode createEmptyInstance() => DocNode._();
  @$core.pragma('dart2js:noInline')
  static DocNode getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DocNode>(DocNode.$_createMessage);
  static DocNode? _defaultInstance;

  /// Opaque; sent back as `parent` to list what is under it. Unique in its level.
  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// Set when it is a page that can be read (Docs.Read with doc.id); unset
  /// for a space or a folder.
  @$pb.TagNumber(3)
  DocSummary get doc => $_getN(2);
  @$pb.TagNumber(3)
  set doc(DocSummary value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDoc() => $_has(2);
  @$pb.TagNumber(3)
  void clearDoc() => $_clearField(3);
  @$pb.TagNumber(3)
  DocSummary ensureDoc() => $_ensure(2);

  /// Entries under it; 0 = nothing to go into. When counting would cost a
  /// request per node, 1 stands for "has children" (Confluence pages).
  @$pb.TagNumber(4)
  $core.int get children => $_getIZ(3);
  @$pb.TagNumber(4)
  set children($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasChildren() => $_has(3);
  @$pb.TagNumber(4)
  void clearChildren() => $_clearField(4);

  /// A short tag shown next to the title, e.g. "archived"; usually empty.
  @$pb.TagNumber(5)
  $core.String get note => $_getSZ(4);
  @$pb.TagNumber(5)
  set note($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasNote() => $_has(4);
  @$pb.TagNumber(5)
  void clearNote() => $_clearField(5);
}

class DocLevel extends $pb.GeneratedMessage {
  factory DocLevel({
    $core.Iterable<DocNode>? nodes,
    $core.bool? truncated,
  }) {
    final result = DocLevel._();
    if (nodes != null) result.nodes.addAll(nodes);
    if (truncated != null) result.truncated = truncated;
    return result;
  }

  DocLevel._();

  factory DocLevel.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocLevel()..mergeFromBuffer(data, registry);
  factory DocLevel.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocLevel()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DocLevel',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: DocLevel.$_createMessage)
    ..pPM<DocNode>(1, _omitFieldNames ? '' : 'nodes',
        subBuilder: DocNode.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'truncated')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocLevel clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocLevel copyWith(void Function(DocLevel) updates) =>
      super.copyWith((message) => updates(message as DocLevel)) as DocLevel;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DocLevel() / DocLevel.new instead')
  static DocLevel create() => DocLevel._();
  static $pb.GeneratedMessage $_createMessage() => DocLevel._();
  @$core.override
  DocLevel createEmptyInstance() => DocLevel._();
  @$core.pragma('dart2js:noInline')
  static DocLevel getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DocLevel>(DocLevel.$_createMessage);
  static DocLevel? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DocNode> get nodes => $_getList(0);

  /// More entries exist than `limit`.
  @$pb.TagNumber(2)
  $core.bool get truncated => $_getBF(1);
  @$pb.TagNumber(2)
  set truncated($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTruncated() => $_has(1);
  @$pb.TagNumber(2)
  void clearTruncated() => $_clearField(2);
}

class WatchTestsRequest extends $pb.GeneratedMessage {
  factory WatchTestsRequest({
    $core.String? worktreePath,
  }) {
    final result = WatchTestsRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    return result;
  }

  WatchTestsRequest._();

  factory WatchTestsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchTestsRequest()..mergeFromBuffer(data, registry);
  factory WatchTestsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WatchTestsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WatchTestsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: WatchTestsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchTestsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WatchTestsRequest copyWith(void Function(WatchTestsRequest) updates) =>
      super.copyWith((message) => updates(message as WatchTestsRequest))
          as WatchTestsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WatchTestsRequest() / WatchTestsRequest.new instead')
  static WatchTestsRequest create() => WatchTestsRequest._();
  static $pb.GeneratedMessage $_createMessage() => WatchTestsRequest._();
  @$core.override
  WatchTestsRequest createEmptyInstance() => WatchTestsRequest._();
  @$core.pragma('dart2js:noInline')
  static WatchTestsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WatchTestsRequest>(
          WatchTestsRequest.$_createMessage);
  static WatchTestsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);
}

class TestsSnapshot extends $pb.GeneratedMessage {
  factory TestsSnapshot({
    $core.String? command,
    $core.String? commandOrigin,
    TestRun? run,
  }) {
    final result = TestsSnapshot._();
    if (command != null) result.command = command;
    if (commandOrigin != null) result.commandOrigin = commandOrigin;
    if (run != null) result.run = run;
    return result;
  }

  TestsSnapshot._();

  factory TestsSnapshot.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestsSnapshot()..mergeFromBuffer(data, registry);
  factory TestsSnapshot.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestsSnapshot()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestsSnapshot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TestsSnapshot.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'command')
    ..aOS(2, _omitFieldNames ? '' : 'commandOrigin')
    ..aOM<TestRun>(3, _omitFieldNames ? '' : 'run',
        subBuilder: TestRun.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestsSnapshot clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestsSnapshot copyWith(void Function(TestsSnapshot) updates) =>
      super.copyWith((message) => updates(message as TestsSnapshot))
          as TestsSnapshot;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TestsSnapshot() / TestsSnapshot.new instead')
  static TestsSnapshot create() => TestsSnapshot._();
  static $pb.GeneratedMessage $_createMessage() => TestsSnapshot._();
  @$core.override
  TestsSnapshot createEmptyInstance() => TestsSnapshot._();
  @$core.pragma('dart2js:noInline')
  static TestsSnapshot getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TestsSnapshot>(
          TestsSnapshot.$_createMessage);
  static TestsSnapshot? _defaultInstance;

  /// Empty when none was found.
  @$pb.TagNumber(1)
  $core.String get command => $_getSZ(0);
  @$pb.TagNumber(1)
  set command($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCommand() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommand() => $_clearField(1);

  /// Why it was picked, e.g. "Makefile".
  @$pb.TagNumber(2)
  $core.String get commandOrigin => $_getSZ(1);
  @$pb.TagNumber(2)
  set commandOrigin($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCommandOrigin() => $_has(1);
  @$pb.TagNumber(2)
  void clearCommandOrigin() => $_clearField(2);

  /// Absent until the worktree runs its tests.
  @$pb.TagNumber(3)
  TestRun get run => $_getN(2);
  @$pb.TagNumber(3)
  set run(TestRun value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRun() => $_has(2);
  @$pb.TagNumber(3)
  void clearRun() => $_clearField(3);
  @$pb.TagNumber(3)
  TestRun ensureRun() => $_ensure(2);
}

/// One package, crate or file of tests.
class TestSuite extends $pb.GeneratedMessage {
  factory TestSuite({
    $core.String? name,
    $core.bool? passed,
    $fixnum.Int64? durationMs,
    $core.int? tests,
  }) {
    final result = TestSuite._();
    if (name != null) result.name = name;
    if (passed != null) result.passed = passed;
    if (durationMs != null) result.durationMs = durationMs;
    if (tests != null) result.tests = tests;
    return result;
  }

  TestSuite._();

  factory TestSuite.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestSuite()..mergeFromBuffer(data, registry);
  factory TestSuite.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestSuite()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestSuite',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TestSuite.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOB(2, _omitFieldNames ? '' : 'passed')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'durationMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(4, _omitFieldNames ? '' : 'tests', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestSuite clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestSuite copyWith(void Function(TestSuite) updates) =>
      super.copyWith((message) => updates(message as TestSuite)) as TestSuite;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TestSuite() / TestSuite.new instead')
  static TestSuite create() => TestSuite._();
  static $pb.GeneratedMessage $_createMessage() => TestSuite._();
  @$core.override
  TestSuite createEmptyInstance() => TestSuite._();
  @$core.pragma('dart2js:noInline')
  static TestSuite getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TestSuite>(TestSuite.$_createMessage);
  static TestSuite? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get passed => $_getBF(1);
  @$pb.TagNumber(2)
  set passed($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPassed() => $_has(1);
  @$pb.TagNumber(2)
  void clearPassed() => $_clearField(2);

  /// 0 when the runner doesn't say.
  @$pb.TagNumber(3)
  $fixnum.Int64 get durationMs => $_getI64(2);
  @$pb.TagNumber(3)
  set durationMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDurationMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearDurationMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get tests => $_getIZ(3);
  @$pb.TagNumber(4)
  set tests($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTests() => $_has(3);
  @$pb.TagNumber(4)
  void clearTests() => $_clearField(4);
}

class TestRun extends $pb.GeneratedMessage {
  factory TestRun({
    $core.String? worktreePath,
    $core.String? command,
    $core.String? terminalId,
    TestRunState? state,
    $core.int? exitCode,
    $fixnum.Int64? startedUnixMs,
    $fixnum.Int64? finishedUnixMs,
    $core.int? passed,
    $core.int? failed,
    $core.int? skipped,
    $core.Iterable<TestSuite>? suites,
    $core.Iterable<$core.String>? failures,
    $core.String? lastLine,
  }) {
    final result = TestRun._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (command != null) result.command = command;
    if (terminalId != null) result.terminalId = terminalId;
    if (state != null) result.state = state;
    if (exitCode != null) result.exitCode = exitCode;
    if (startedUnixMs != null) result.startedUnixMs = startedUnixMs;
    if (finishedUnixMs != null) result.finishedUnixMs = finishedUnixMs;
    if (passed != null) result.passed = passed;
    if (failed != null) result.failed = failed;
    if (skipped != null) result.skipped = skipped;
    if (suites != null) result.suites.addAll(suites);
    if (failures != null) result.failures.addAll(failures);
    if (lastLine != null) result.lastLine = lastLine;
    return result;
  }

  TestRun._();

  factory TestRun.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestRun()..mergeFromBuffer(data, registry);
  factory TestRun.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestRun()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestRun',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: TestRun.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..aOS(2, _omitFieldNames ? '' : 'command')
    ..aOS(3, _omitFieldNames ? '' : 'terminalId')
    ..aE<TestRunState>(4, _omitFieldNames ? '' : 'state',
        enumValues: TestRunState.values)
    ..aI(5, _omitFieldNames ? '' : 'exitCode')
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'startedUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        7, _omitFieldNames ? '' : 'finishedUnixMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(8, _omitFieldNames ? '' : 'passed', fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'failed', fieldType: $pb.PbFieldType.OU3)
    ..aI(10, _omitFieldNames ? '' : 'skipped', fieldType: $pb.PbFieldType.OU3)
    ..pPM<TestSuite>(11, _omitFieldNames ? '' : 'suites',
        subBuilder: TestSuite.$_createMessage)
    ..pPS(12, _omitFieldNames ? '' : 'failures')
    ..aOS(13, _omitFieldNames ? '' : 'lastLine')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestRun clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestRun copyWith(void Function(TestRun) updates) =>
      super.copyWith((message) => updates(message as TestRun)) as TestRun;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TestRun() / TestRun.new instead')
  static TestRun create() => TestRun._();
  static $pb.GeneratedMessage $_createMessage() => TestRun._();
  @$core.override
  TestRun createEmptyInstance() => TestRun._();
  @$core.pragma('dart2js:noInline')
  static TestRun getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TestRun>(TestRun.$_createMessage);
  static TestRun? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get command => $_getSZ(1);
  @$pb.TagNumber(2)
  set command($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCommand() => $_has(1);
  @$pb.TagNumber(2)
  void clearCommand() => $_clearField(2);

  /// Where it runs (open it to see the whole output).
  @$pb.TagNumber(3)
  $core.String get terminalId => $_getSZ(2);
  @$pb.TagNumber(3)
  set terminalId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTerminalId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTerminalId() => $_clearField(3);

  @$pb.TagNumber(4)
  TestRunState get state => $_getN(3);
  @$pb.TagNumber(4)
  set state(TestRunState value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasState() => $_has(3);
  @$pb.TagNumber(4)
  void clearState() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get exitCode => $_getIZ(4);
  @$pb.TagNumber(5)
  set exitCode($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasExitCode() => $_has(4);
  @$pb.TagNumber(5)
  void clearExitCode() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get startedUnixMs => $_getI64(5);
  @$pb.TagNumber(6)
  set startedUnixMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStartedUnixMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearStartedUnixMs() => $_clearField(6);

  /// 0 while running.
  @$pb.TagNumber(7)
  $fixnum.Int64 get finishedUnixMs => $_getI64(6);
  @$pb.TagNumber(7)
  set finishedUnixMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFinishedUnixMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearFinishedUnixMs() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get passed => $_getIZ(7);
  @$pb.TagNumber(8)
  set passed($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPassed() => $_has(7);
  @$pb.TagNumber(8)
  void clearPassed() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get failed => $_getIZ(8);
  @$pb.TagNumber(9)
  set failed($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasFailed() => $_has(8);
  @$pb.TagNumber(9)
  void clearFailed() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get skipped => $_getIZ(9);
  @$pb.TagNumber(10)
  set skipped($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSkipped() => $_has(9);
  @$pb.TagNumber(10)
  void clearSkipped() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<TestSuite> get suites => $_getList(10);

  /// Names of the failing tests.
  @$pb.TagNumber(12)
  $pb.PbList<$core.String> get failures => $_getList(11);

  /// The latest line printed.
  @$pb.TagNumber(13)
  $core.String get lastLine => $_getSZ(12);
  @$pb.TagNumber(13)
  set lastLine($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasLastLine() => $_has(12);
  @$pb.TagNumber(13)
  void clearLastLine() => $_clearField(13);
}

class RunTestsRequest extends $pb.GeneratedMessage {
  factory RunTestsRequest({
    $core.String? worktreePath,
    $core.String? command,
    $core.int? cols,
    $core.int? rows,
  }) {
    final result = RunTestsRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (command != null) result.command = command;
    if (cols != null) result.cols = cols;
    if (rows != null) result.rows = rows;
    return result;
  }

  RunTestsRequest._();

  factory RunTestsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RunTestsRequest()..mergeFromBuffer(data, registry);
  factory RunTestsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RunTestsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RunTestsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: RunTestsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..aOS(2, _omitFieldNames ? '' : 'command')
    ..aI(3, _omitFieldNames ? '' : 'cols', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'rows', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunTestsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunTestsRequest copyWith(void Function(RunTestsRequest) updates) =>
      super.copyWith((message) => updates(message as RunTestsRequest))
          as RunTestsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RunTestsRequest() / RunTestsRequest.new instead')
  static RunTestsRequest create() => RunTestsRequest._();
  static $pb.GeneratedMessage $_createMessage() => RunTestsRequest._();
  @$core.override
  RunTestsRequest createEmptyInstance() => RunTestsRequest._();
  @$core.pragma('dart2js:noInline')
  static RunTestsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RunTestsRequest>(
          RunTestsRequest.$_createMessage);
  static RunTestsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);

  /// Empty: the detected command.
  @$pb.TagNumber(2)
  $core.String get command => $_getSZ(1);
  @$pb.TagNumber(2)
  set command($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCommand() => $_has(1);
  @$pb.TagNumber(2)
  void clearCommand() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get cols => $_getIZ(2);
  @$pb.TagNumber(3)
  set cols($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCols() => $_has(2);
  @$pb.TagNumber(3)
  void clearCols() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get rows => $_getIZ(3);
  @$pb.TagNumber(4)
  set rows($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRows() => $_has(3);
  @$pb.TagNumber(4)
  void clearRows() => $_clearField(4);
}

class StopTestsRequest extends $pb.GeneratedMessage {
  factory StopTestsRequest({
    $core.String? worktreePath,
  }) {
    final result = StopTestsRequest._();
    if (worktreePath != null) result.worktreePath = worktreePath;
    return result;
  }

  StopTestsRequest._();

  factory StopTestsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopTestsRequest()..mergeFromBuffer(data, registry);
  factory StopTestsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopTestsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StopTestsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: StopTestsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'worktreePath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopTestsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopTestsRequest copyWith(void Function(StopTestsRequest) updates) =>
      super.copyWith((message) => updates(message as StopTestsRequest))
          as StopTestsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StopTestsRequest() / StopTestsRequest.new instead')
  static StopTestsRequest create() => StopTestsRequest._();
  static $pb.GeneratedMessage $_createMessage() => StopTestsRequest._();
  @$core.override
  StopTestsRequest createEmptyInstance() => StopTestsRequest._();
  @$core.pragma('dart2js:noInline')
  static StopTestsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StopTestsRequest>(
          StopTestsRequest.$_createMessage);
  static StopTestsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get worktreePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set worktreePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktreePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktreePath() => $_clearField(1);
}

class StopTestsResponse extends $pb.GeneratedMessage {
  factory StopTestsResponse() => StopTestsResponse._();

  StopTestsResponse._();

  factory StopTestsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopTestsResponse()..mergeFromBuffer(data, registry);
  factory StopTestsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopTestsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StopTestsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kumo.v1'),
      createEmptyInstance: StopTestsResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopTestsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopTestsResponse copyWith(void Function(StopTestsResponse) updates) =>
      super.copyWith((message) => updates(message as StopTestsResponse))
          as StopTestsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StopTestsResponse() / StopTestsResponse.new instead')
  static StopTestsResponse create() => StopTestsResponse._();
  static $pb.GeneratedMessage $_createMessage() => StopTestsResponse._();
  @$core.override
  StopTestsResponse createEmptyInstance() => StopTestsResponse._();
  @$core.pragma('dart2js:noInline')
  static StopTestsResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StopTestsResponse>(
          StopTestsResponse.$_createMessage);
  static StopTestsResponse? _defaultInstance;
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
