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

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
