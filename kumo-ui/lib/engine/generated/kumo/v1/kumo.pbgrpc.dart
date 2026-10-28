// This is a generated file - do not edit.
//
// Generated from kumo/v1/kumo.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'kumo.pb.dart' as $0;

export 'kumo.pb.dart';

@$pb.GrpcServiceName('kumo.v1.Core')
class CoreClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  CoreClient(super.channel, {super.options, super.interceptors});

  /// Version handshake. Clients must refuse to operate if
  /// `server_api_version` differs from their own.
  $grpc.ResponseFuture<$0.HelloResponse> hello(
    $0.HelloRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$hello, request, options: options);
  }

  // method descriptors

  static final _$hello = $grpc.ClientMethod<$0.HelloRequest, $0.HelloResponse>(
      '/kumo.v1.Core/Hello',
      ($0.HelloRequest value) => value.writeToBuffer(),
      $0.HelloResponse.fromBuffer);
}

@$pb.GrpcServiceName('kumo.v1.Core')
abstract class CoreServiceBase extends $grpc.Service {
  $core.String get $name => 'kumo.v1.Core';

  CoreServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.HelloRequest, $0.HelloResponse>(
        'Hello',
        hello_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.HelloRequest.fromBuffer(value),
        ($0.HelloResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.HelloResponse> hello_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.HelloRequest> $request) async {
    return hello($call, await $request);
  }

  $async.Future<$0.HelloResponse> hello(
      $grpc.ServiceCall call, $0.HelloRequest request);
}

@$pb.GrpcServiceName('kumo.v1.Terminals')
class TerminalsClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  TerminalsClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.OpenResponse> open(
    $0.OpenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$open, request, options: options);
  }

  /// First client message must be `attach`. After that: `data` / `resize`.
  /// The server streams output batches and, last, `exited`.
  $grpc.ResponseStream<$0.TerminalOutput> attach(
    $async.Stream<$0.TerminalInput> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$attach, request, options: options);
  }

  /// Kills the process (if still running) and forgets the session.
  $grpc.ResponseFuture<$0.CloseResponse> close(
    $0.CloseRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$close, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListResponse> list(
    $0.ListRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$list, request, options: options);
  }

  // method descriptors

  static final _$open = $grpc.ClientMethod<$0.OpenRequest, $0.OpenResponse>(
      '/kumo.v1.Terminals/Open',
      ($0.OpenRequest value) => value.writeToBuffer(),
      $0.OpenResponse.fromBuffer);
  static final _$attach =
      $grpc.ClientMethod<$0.TerminalInput, $0.TerminalOutput>(
          '/kumo.v1.Terminals/Attach',
          ($0.TerminalInput value) => value.writeToBuffer(),
          $0.TerminalOutput.fromBuffer);
  static final _$close = $grpc.ClientMethod<$0.CloseRequest, $0.CloseResponse>(
      '/kumo.v1.Terminals/Close',
      ($0.CloseRequest value) => value.writeToBuffer(),
      $0.CloseResponse.fromBuffer);
  static final _$list = $grpc.ClientMethod<$0.ListRequest, $0.ListResponse>(
      '/kumo.v1.Terminals/List',
      ($0.ListRequest value) => value.writeToBuffer(),
      $0.ListResponse.fromBuffer);
}

@$pb.GrpcServiceName('kumo.v1.Terminals')
abstract class TerminalsServiceBase extends $grpc.Service {
  $core.String get $name => 'kumo.v1.Terminals';

  TerminalsServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.OpenRequest, $0.OpenResponse>(
        'Open',
        open_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.OpenRequest.fromBuffer(value),
        ($0.OpenResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TerminalInput, $0.TerminalOutput>(
        'Attach',
        attach,
        true,
        true,
        ($core.List<$core.int> value) => $0.TerminalInput.fromBuffer(value),
        ($0.TerminalOutput value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CloseRequest, $0.CloseResponse>(
        'Close',
        close_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CloseRequest.fromBuffer(value),
        ($0.CloseResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListRequest, $0.ListResponse>(
        'List',
        list_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListRequest.fromBuffer(value),
        ($0.ListResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.OpenResponse> open_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.OpenRequest> $request) async {
    return open($call, await $request);
  }

  $async.Future<$0.OpenResponse> open(
      $grpc.ServiceCall call, $0.OpenRequest request);

  $async.Stream<$0.TerminalOutput> attach(
      $grpc.ServiceCall call, $async.Stream<$0.TerminalInput> request);

  $async.Future<$0.CloseResponse> close_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.CloseRequest> $request) async {
    return close($call, await $request);
  }

  $async.Future<$0.CloseResponse> close(
      $grpc.ServiceCall call, $0.CloseRequest request);

  $async.Future<$0.ListResponse> list_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ListRequest> $request) async {
    return list($call, await $request);
  }

  $async.Future<$0.ListResponse> list(
      $grpc.ServiceCall call, $0.ListRequest request);
}
