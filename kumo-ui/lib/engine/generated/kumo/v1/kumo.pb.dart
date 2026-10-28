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
  }) {
    final result = HelloResponse._();
    if (serverApiVersion != null) result.serverApiVersion = serverApiVersion;
    if (serverVersion != null) result.serverVersion = serverVersion;
    if (serverTimeUnixNanos != null)
      result.serverTimeUnixNanos = serverTimeUnixNanos;
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
  }) {
    final result = TerminalInfo._();
    if (terminalId != null) result.terminalId = terminalId;
    if (program != null) result.program = program;
    if (exited != null) result.exited = exited;
    if (exitCode != null) result.exitCode = exitCode;
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
  }) {
    final result = RemoveWorktreeRequest._();
    if (repoPath != null) result.repoPath = repoPath;
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (force != null) result.force = force;
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
}

class RemoveWorktreeResponse extends $pb.GeneratedMessage {
  factory RemoveWorktreeResponse() => RemoveWorktreeResponse._();

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
  }) {
    final result = SaveProviderRequest._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (program != null) result.program = program;
    if (args != null) result.args = args;
    if (enabled != null) result.enabled = enabled;
    if (isDefault != null) result.isDefault = isDefault;
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
  }) {
    final result = StartAgentRequest._();
    if (providerId != null) result.providerId = providerId;
    if (worktreePath != null) result.worktreePath = worktreePath;
    if (prompt != null) result.prompt = prompt;
    if (title != null) result.title = title;
    if (cols != null) result.cols = cols;
    if (rows != null) result.rows = rows;
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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
