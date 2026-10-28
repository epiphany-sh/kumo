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

@$pb.GrpcServiceName('kumo.v1.Workspace')
class WorkspaceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  WorkspaceClient(super.channel, {super.options, super.interceptors});

  /// Current snapshot first, then a new one after every change.
  $grpc.ResponseStream<$0.WorkspaceSnapshot> watch(
    $0.WatchWorkspaceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$watch, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Re-reads git state (e.g. when the window gets focus).
  $grpc.ResponseFuture<$0.RefreshWorkspaceResponse> refresh(
    $0.RefreshWorkspaceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$refresh, request, options: options);
  }

  /// Git repositories found on disk, to pick from when editing a namespace.
  $grpc.ResponseFuture<$0.DiscoverReposResponse> discoverRepos(
    $0.DiscoverReposRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$discoverRepos, request, options: options);
  }

  /// Creates (empty id) or replaces a namespace. Unknown repo paths are
  /// registered; they must be git repositories.
  $grpc.ResponseFuture<$0.SaveNamespaceResponse> saveNamespace(
    $0.SaveNamespaceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$saveNamespace, request, options: options);
  }

  /// Only the group: repositories and worktrees stay on disk.
  $grpc.ResponseFuture<$0.DeleteNamespaceResponse> deleteNamespace(
    $0.DeleteNamespaceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteNamespace, request, options: options);
  }

  $grpc.ResponseFuture<$0.CreateWorktreeResponse> createWorktree(
    $0.CreateWorktreeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createWorktree, request, options: options);
  }

  /// `git worktree remove`; the branch stays. The main checkout can't be removed.
  $grpc.ResponseFuture<$0.RemoveWorktreeResponse> removeWorktree(
    $0.RemoveWorktreeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$removeWorktree, request, options: options);
  }

  /// Branches to start a worktree from or check out.
  $grpc.ResponseFuture<$0.ListBranchesResponse> listBranches(
    $0.ListBranchesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listBranches, request, options: options);
  }

  // method descriptors

  static final _$watch =
      $grpc.ClientMethod<$0.WatchWorkspaceRequest, $0.WorkspaceSnapshot>(
          '/kumo.v1.Workspace/Watch',
          ($0.WatchWorkspaceRequest value) => value.writeToBuffer(),
          $0.WorkspaceSnapshot.fromBuffer);
  static final _$refresh = $grpc.ClientMethod<$0.RefreshWorkspaceRequest,
          $0.RefreshWorkspaceResponse>(
      '/kumo.v1.Workspace/Refresh',
      ($0.RefreshWorkspaceRequest value) => value.writeToBuffer(),
      $0.RefreshWorkspaceResponse.fromBuffer);
  static final _$discoverRepos =
      $grpc.ClientMethod<$0.DiscoverReposRequest, $0.DiscoverReposResponse>(
          '/kumo.v1.Workspace/DiscoverRepos',
          ($0.DiscoverReposRequest value) => value.writeToBuffer(),
          $0.DiscoverReposResponse.fromBuffer);
  static final _$saveNamespace =
      $grpc.ClientMethod<$0.SaveNamespaceRequest, $0.SaveNamespaceResponse>(
          '/kumo.v1.Workspace/SaveNamespace',
          ($0.SaveNamespaceRequest value) => value.writeToBuffer(),
          $0.SaveNamespaceResponse.fromBuffer);
  static final _$deleteNamespace =
      $grpc.ClientMethod<$0.DeleteNamespaceRequest, $0.DeleteNamespaceResponse>(
          '/kumo.v1.Workspace/DeleteNamespace',
          ($0.DeleteNamespaceRequest value) => value.writeToBuffer(),
          $0.DeleteNamespaceResponse.fromBuffer);
  static final _$createWorktree =
      $grpc.ClientMethod<$0.CreateWorktreeRequest, $0.CreateWorktreeResponse>(
          '/kumo.v1.Workspace/CreateWorktree',
          ($0.CreateWorktreeRequest value) => value.writeToBuffer(),
          $0.CreateWorktreeResponse.fromBuffer);
  static final _$removeWorktree =
      $grpc.ClientMethod<$0.RemoveWorktreeRequest, $0.RemoveWorktreeResponse>(
          '/kumo.v1.Workspace/RemoveWorktree',
          ($0.RemoveWorktreeRequest value) => value.writeToBuffer(),
          $0.RemoveWorktreeResponse.fromBuffer);
  static final _$listBranches =
      $grpc.ClientMethod<$0.ListBranchesRequest, $0.ListBranchesResponse>(
          '/kumo.v1.Workspace/ListBranches',
          ($0.ListBranchesRequest value) => value.writeToBuffer(),
          $0.ListBranchesResponse.fromBuffer);
}

@$pb.GrpcServiceName('kumo.v1.Workspace')
abstract class WorkspaceServiceBase extends $grpc.Service {
  $core.String get $name => 'kumo.v1.Workspace';

  WorkspaceServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.WatchWorkspaceRequest, $0.WorkspaceSnapshot>(
            'Watch',
            watch_Pre,
            false,
            true,
            ($core.List<$core.int> value) =>
                $0.WatchWorkspaceRequest.fromBuffer(value),
            ($0.WorkspaceSnapshot value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RefreshWorkspaceRequest,
            $0.RefreshWorkspaceResponse>(
        'Refresh',
        refresh_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RefreshWorkspaceRequest.fromBuffer(value),
        ($0.RefreshWorkspaceResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.DiscoverReposRequest, $0.DiscoverReposResponse>(
            'DiscoverRepos',
            discoverRepos_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.DiscoverReposRequest.fromBuffer(value),
            ($0.DiscoverReposResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SaveNamespaceRequest, $0.SaveNamespaceResponse>(
            'SaveNamespace',
            saveNamespace_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SaveNamespaceRequest.fromBuffer(value),
            ($0.SaveNamespaceResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteNamespaceRequest,
            $0.DeleteNamespaceResponse>(
        'DeleteNamespace',
        deleteNamespace_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteNamespaceRequest.fromBuffer(value),
        ($0.DeleteNamespaceResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CreateWorktreeRequest,
            $0.CreateWorktreeResponse>(
        'CreateWorktree',
        createWorktree_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreateWorktreeRequest.fromBuffer(value),
        ($0.CreateWorktreeResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RemoveWorktreeRequest,
            $0.RemoveWorktreeResponse>(
        'RemoveWorktree',
        removeWorktree_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RemoveWorktreeRequest.fromBuffer(value),
        ($0.RemoveWorktreeResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListBranchesRequest, $0.ListBranchesResponse>(
            'ListBranches',
            listBranches_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListBranchesRequest.fromBuffer(value),
            ($0.ListBranchesResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.WorkspaceSnapshot> watch_Pre($grpc.ServiceCall $call,
      $async.Future<$0.WatchWorkspaceRequest> $request) async* {
    yield* watch($call, await $request);
  }

  $async.Stream<$0.WorkspaceSnapshot> watch(
      $grpc.ServiceCall call, $0.WatchWorkspaceRequest request);

  $async.Future<$0.RefreshWorkspaceResponse> refresh_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RefreshWorkspaceRequest> $request) async {
    return refresh($call, await $request);
  }

  $async.Future<$0.RefreshWorkspaceResponse> refresh(
      $grpc.ServiceCall call, $0.RefreshWorkspaceRequest request);

  $async.Future<$0.DiscoverReposResponse> discoverRepos_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DiscoverReposRequest> $request) async {
    return discoverRepos($call, await $request);
  }

  $async.Future<$0.DiscoverReposResponse> discoverRepos(
      $grpc.ServiceCall call, $0.DiscoverReposRequest request);

  $async.Future<$0.SaveNamespaceResponse> saveNamespace_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SaveNamespaceRequest> $request) async {
    return saveNamespace($call, await $request);
  }

  $async.Future<$0.SaveNamespaceResponse> saveNamespace(
      $grpc.ServiceCall call, $0.SaveNamespaceRequest request);

  $async.Future<$0.DeleteNamespaceResponse> deleteNamespace_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DeleteNamespaceRequest> $request) async {
    return deleteNamespace($call, await $request);
  }

  $async.Future<$0.DeleteNamespaceResponse> deleteNamespace(
      $grpc.ServiceCall call, $0.DeleteNamespaceRequest request);

  $async.Future<$0.CreateWorktreeResponse> createWorktree_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CreateWorktreeRequest> $request) async {
    return createWorktree($call, await $request);
  }

  $async.Future<$0.CreateWorktreeResponse> createWorktree(
      $grpc.ServiceCall call, $0.CreateWorktreeRequest request);

  $async.Future<$0.RemoveWorktreeResponse> removeWorktree_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RemoveWorktreeRequest> $request) async {
    return removeWorktree($call, await $request);
  }

  $async.Future<$0.RemoveWorktreeResponse> removeWorktree(
      $grpc.ServiceCall call, $0.RemoveWorktreeRequest request);

  $async.Future<$0.ListBranchesResponse> listBranches_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListBranchesRequest> $request) async {
    return listBranches($call, await $request);
  }

  $async.Future<$0.ListBranchesResponse> listBranches(
      $grpc.ServiceCall call, $0.ListBranchesRequest request);
}
