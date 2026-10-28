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

@$pb.GrpcServiceName('kumo.v1.Git')
class GitClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  GitClient(super.channel, {super.options, super.interceptors});

  /// Status now, then again whenever files or the index change.
  $grpc.ResponseStream<$0.WorktreeChanges> watchStatus(
    $0.WatchStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$watchStatus, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Tracked and untracked (not ignored) files.
  $grpc.ResponseFuture<$0.ListFilesResponse> listFiles(
    $0.ListFilesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listFiles, request, options: options);
  }

  $grpc.ResponseFuture<$0.ReadFileResponse> readFile(
    $0.ReadFileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$readFile, request, options: options);
  }

  $grpc.ResponseFuture<$0.WriteFileResponse> writeFile(
    $0.WriteFileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$writeFile, request, options: options);
  }

  /// The whole file with its changes (unchanged lines as context).
  $grpc.ResponseFuture<$0.DiffResponse> diff(
    $0.DiffRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$diff, request, options: options);
  }

  $grpc.ResponseFuture<$0.GitActionResponse> stage(
    $0.PathsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$stage, request, options: options);
  }

  $grpc.ResponseFuture<$0.GitActionResponse> unstage(
    $0.PathsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$unstage, request, options: options);
  }

  /// Back to HEAD (staged and working tree). Untracked files are left alone.
  $grpc.ResponseFuture<$0.GitActionResponse> restore(
    $0.PathsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$restore, request, options: options);
  }

  $grpc.ResponseFuture<$0.CommitResponse> commit(
    $0.CommitRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$commit, request, options: options);
  }

  $grpc.ResponseFuture<$0.GitActionResponse> push(
    $0.WorktreeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$push, request, options: options);
  }

  /// `git reset --soft HEAD~1`: the changes stay, staged.
  $grpc.ResponseFuture<$0.GitActionResponse> undoLastCommit(
    $0.WorktreeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$undoLastCommit, request, options: options);
  }

  $grpc.ResponseFuture<$0.LogResponse> log(
    $0.LogRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$log, request, options: options);
  }

  // method descriptors

  static final _$watchStatus =
      $grpc.ClientMethod<$0.WatchStatusRequest, $0.WorktreeChanges>(
          '/kumo.v1.Git/WatchStatus',
          ($0.WatchStatusRequest value) => value.writeToBuffer(),
          $0.WorktreeChanges.fromBuffer);
  static final _$listFiles =
      $grpc.ClientMethod<$0.ListFilesRequest, $0.ListFilesResponse>(
          '/kumo.v1.Git/ListFiles',
          ($0.ListFilesRequest value) => value.writeToBuffer(),
          $0.ListFilesResponse.fromBuffer);
  static final _$readFile =
      $grpc.ClientMethod<$0.ReadFileRequest, $0.ReadFileResponse>(
          '/kumo.v1.Git/ReadFile',
          ($0.ReadFileRequest value) => value.writeToBuffer(),
          $0.ReadFileResponse.fromBuffer);
  static final _$writeFile =
      $grpc.ClientMethod<$0.WriteFileRequest, $0.WriteFileResponse>(
          '/kumo.v1.Git/WriteFile',
          ($0.WriteFileRequest value) => value.writeToBuffer(),
          $0.WriteFileResponse.fromBuffer);
  static final _$diff = $grpc.ClientMethod<$0.DiffRequest, $0.DiffResponse>(
      '/kumo.v1.Git/Diff',
      ($0.DiffRequest value) => value.writeToBuffer(),
      $0.DiffResponse.fromBuffer);
  static final _$stage =
      $grpc.ClientMethod<$0.PathsRequest, $0.GitActionResponse>(
          '/kumo.v1.Git/Stage',
          ($0.PathsRequest value) => value.writeToBuffer(),
          $0.GitActionResponse.fromBuffer);
  static final _$unstage =
      $grpc.ClientMethod<$0.PathsRequest, $0.GitActionResponse>(
          '/kumo.v1.Git/Unstage',
          ($0.PathsRequest value) => value.writeToBuffer(),
          $0.GitActionResponse.fromBuffer);
  static final _$restore =
      $grpc.ClientMethod<$0.PathsRequest, $0.GitActionResponse>(
          '/kumo.v1.Git/Restore',
          ($0.PathsRequest value) => value.writeToBuffer(),
          $0.GitActionResponse.fromBuffer);
  static final _$commit =
      $grpc.ClientMethod<$0.CommitRequest, $0.CommitResponse>(
          '/kumo.v1.Git/Commit',
          ($0.CommitRequest value) => value.writeToBuffer(),
          $0.CommitResponse.fromBuffer);
  static final _$push =
      $grpc.ClientMethod<$0.WorktreeRequest, $0.GitActionResponse>(
          '/kumo.v1.Git/Push',
          ($0.WorktreeRequest value) => value.writeToBuffer(),
          $0.GitActionResponse.fromBuffer);
  static final _$undoLastCommit =
      $grpc.ClientMethod<$0.WorktreeRequest, $0.GitActionResponse>(
          '/kumo.v1.Git/UndoLastCommit',
          ($0.WorktreeRequest value) => value.writeToBuffer(),
          $0.GitActionResponse.fromBuffer);
  static final _$log = $grpc.ClientMethod<$0.LogRequest, $0.LogResponse>(
      '/kumo.v1.Git/Log',
      ($0.LogRequest value) => value.writeToBuffer(),
      $0.LogResponse.fromBuffer);
}

@$pb.GrpcServiceName('kumo.v1.Git')
abstract class GitServiceBase extends $grpc.Service {
  $core.String get $name => 'kumo.v1.Git';

  GitServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.WatchStatusRequest, $0.WorktreeChanges>(
        'WatchStatus',
        watchStatus_Pre,
        false,
        true,
        ($core.List<$core.int> value) =>
            $0.WatchStatusRequest.fromBuffer(value),
        ($0.WorktreeChanges value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListFilesRequest, $0.ListFilesResponse>(
        'ListFiles',
        listFiles_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListFilesRequest.fromBuffer(value),
        ($0.ListFilesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ReadFileRequest, $0.ReadFileResponse>(
        'ReadFile',
        readFile_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ReadFileRequest.fromBuffer(value),
        ($0.ReadFileResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.WriteFileRequest, $0.WriteFileResponse>(
        'WriteFile',
        writeFile_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.WriteFileRequest.fromBuffer(value),
        ($0.WriteFileResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DiffRequest, $0.DiffResponse>(
        'Diff',
        diff_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DiffRequest.fromBuffer(value),
        ($0.DiffResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PathsRequest, $0.GitActionResponse>(
        'Stage',
        stage_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PathsRequest.fromBuffer(value),
        ($0.GitActionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PathsRequest, $0.GitActionResponse>(
        'Unstage',
        unstage_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PathsRequest.fromBuffer(value),
        ($0.GitActionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PathsRequest, $0.GitActionResponse>(
        'Restore',
        restore_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PathsRequest.fromBuffer(value),
        ($0.GitActionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CommitRequest, $0.CommitResponse>(
        'Commit',
        commit_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CommitRequest.fromBuffer(value),
        ($0.CommitResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.WorktreeRequest, $0.GitActionResponse>(
        'Push',
        push_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.WorktreeRequest.fromBuffer(value),
        ($0.GitActionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.WorktreeRequest, $0.GitActionResponse>(
        'UndoLastCommit',
        undoLastCommit_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.WorktreeRequest.fromBuffer(value),
        ($0.GitActionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LogRequest, $0.LogResponse>(
        'Log',
        log_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.LogRequest.fromBuffer(value),
        ($0.LogResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.WorktreeChanges> watchStatus_Pre($grpc.ServiceCall $call,
      $async.Future<$0.WatchStatusRequest> $request) async* {
    yield* watchStatus($call, await $request);
  }

  $async.Stream<$0.WorktreeChanges> watchStatus(
      $grpc.ServiceCall call, $0.WatchStatusRequest request);

  $async.Future<$0.ListFilesResponse> listFiles_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListFilesRequest> $request) async {
    return listFiles($call, await $request);
  }

  $async.Future<$0.ListFilesResponse> listFiles(
      $grpc.ServiceCall call, $0.ListFilesRequest request);

  $async.Future<$0.ReadFileResponse> readFile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ReadFileRequest> $request) async {
    return readFile($call, await $request);
  }

  $async.Future<$0.ReadFileResponse> readFile(
      $grpc.ServiceCall call, $0.ReadFileRequest request);

  $async.Future<$0.WriteFileResponse> writeFile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.WriteFileRequest> $request) async {
    return writeFile($call, await $request);
  }

  $async.Future<$0.WriteFileResponse> writeFile(
      $grpc.ServiceCall call, $0.WriteFileRequest request);

  $async.Future<$0.DiffResponse> diff_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.DiffRequest> $request) async {
    return diff($call, await $request);
  }

  $async.Future<$0.DiffResponse> diff(
      $grpc.ServiceCall call, $0.DiffRequest request);

  $async.Future<$0.GitActionResponse> stage_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PathsRequest> $request) async {
    return stage($call, await $request);
  }

  $async.Future<$0.GitActionResponse> stage(
      $grpc.ServiceCall call, $0.PathsRequest request);

  $async.Future<$0.GitActionResponse> unstage_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PathsRequest> $request) async {
    return unstage($call, await $request);
  }

  $async.Future<$0.GitActionResponse> unstage(
      $grpc.ServiceCall call, $0.PathsRequest request);

  $async.Future<$0.GitActionResponse> restore_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PathsRequest> $request) async {
    return restore($call, await $request);
  }

  $async.Future<$0.GitActionResponse> restore(
      $grpc.ServiceCall call, $0.PathsRequest request);

  $async.Future<$0.CommitResponse> commit_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.CommitRequest> $request) async {
    return commit($call, await $request);
  }

  $async.Future<$0.CommitResponse> commit(
      $grpc.ServiceCall call, $0.CommitRequest request);

  $async.Future<$0.GitActionResponse> push_Pre($grpc.ServiceCall $call,
      $async.Future<$0.WorktreeRequest> $request) async {
    return push($call, await $request);
  }

  $async.Future<$0.GitActionResponse> push(
      $grpc.ServiceCall call, $0.WorktreeRequest request);

  $async.Future<$0.GitActionResponse> undoLastCommit_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.WorktreeRequest> $request) async {
    return undoLastCommit($call, await $request);
  }

  $async.Future<$0.GitActionResponse> undoLastCommit(
      $grpc.ServiceCall call, $0.WorktreeRequest request);

  $async.Future<$0.LogResponse> log_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.LogRequest> $request) async {
    return log($call, await $request);
  }

  $async.Future<$0.LogResponse> log(
      $grpc.ServiceCall call, $0.LogRequest request);
}

@$pb.GrpcServiceName('kumo.v1.Agents')
class AgentsClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AgentsClient(super.channel, {super.options, super.interceptors});

  /// Known CLIs (installed or not) plus the user's custom ones.
  $grpc.ResponseFuture<$0.ListProvidersResponse> listProviders(
    $0.ListProvidersRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listProviders, request, options: options);
  }

  /// Creates (empty id) a custom provider or updates any provider.
  $grpc.ResponseFuture<$0.AgentProvider> saveProvider(
    $0.SaveProviderRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$saveProvider, request, options: options);
  }

  /// Custom providers only; known ones are disabled instead.
  $grpc.ResponseFuture<$0.DeleteProviderResponse> deleteProvider(
    $0.DeleteProviderRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteProvider, request, options: options);
  }

  /// Runs `<program> --version`.
  $grpc.ResponseFuture<$0.TestProviderResponse> testProvider(
    $0.TestProviderRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$testProvider, request, options: options);
  }

  /// Opens a terminal running the CLI's own sign-in; Kumo never sees
  /// credentials.
  $grpc.ResponseFuture<$0.LoginProviderResponse> loginProvider(
    $0.LoginProviderRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$loginProvider, request, options: options);
  }

  $grpc.ResponseFuture<$0.AgentSession> start(
    $0.StartAgentRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$start, request, options: options);
  }

  /// Kills the agent's process.
  $grpc.ResponseFuture<$0.StopAgentResponse> stop(
    $0.StopAgentRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$stop, request, options: options);
  }

  /// Forgets a finished session.
  $grpc.ResponseFuture<$0.DismissAgentResponse> dismiss(
    $0.DismissAgentRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$dismiss, request, options: options);
  }

  /// Every session now, then again whenever one changes (last wins).
  $grpc.ResponseStream<$0.AgentsSnapshot> watch(
    $0.WatchAgentsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$watch, $async.Stream.fromIterable([request]),
        options: options);
  }

  // method descriptors

  static final _$listProviders =
      $grpc.ClientMethod<$0.ListProvidersRequest, $0.ListProvidersResponse>(
          '/kumo.v1.Agents/ListProviders',
          ($0.ListProvidersRequest value) => value.writeToBuffer(),
          $0.ListProvidersResponse.fromBuffer);
  static final _$saveProvider =
      $grpc.ClientMethod<$0.SaveProviderRequest, $0.AgentProvider>(
          '/kumo.v1.Agents/SaveProvider',
          ($0.SaveProviderRequest value) => value.writeToBuffer(),
          $0.AgentProvider.fromBuffer);
  static final _$deleteProvider =
      $grpc.ClientMethod<$0.DeleteProviderRequest, $0.DeleteProviderResponse>(
          '/kumo.v1.Agents/DeleteProvider',
          ($0.DeleteProviderRequest value) => value.writeToBuffer(),
          $0.DeleteProviderResponse.fromBuffer);
  static final _$testProvider =
      $grpc.ClientMethod<$0.TestProviderRequest, $0.TestProviderResponse>(
          '/kumo.v1.Agents/TestProvider',
          ($0.TestProviderRequest value) => value.writeToBuffer(),
          $0.TestProviderResponse.fromBuffer);
  static final _$loginProvider =
      $grpc.ClientMethod<$0.LoginProviderRequest, $0.LoginProviderResponse>(
          '/kumo.v1.Agents/LoginProvider',
          ($0.LoginProviderRequest value) => value.writeToBuffer(),
          $0.LoginProviderResponse.fromBuffer);
  static final _$start =
      $grpc.ClientMethod<$0.StartAgentRequest, $0.AgentSession>(
          '/kumo.v1.Agents/Start',
          ($0.StartAgentRequest value) => value.writeToBuffer(),
          $0.AgentSession.fromBuffer);
  static final _$stop =
      $grpc.ClientMethod<$0.StopAgentRequest, $0.StopAgentResponse>(
          '/kumo.v1.Agents/Stop',
          ($0.StopAgentRequest value) => value.writeToBuffer(),
          $0.StopAgentResponse.fromBuffer);
  static final _$dismiss =
      $grpc.ClientMethod<$0.DismissAgentRequest, $0.DismissAgentResponse>(
          '/kumo.v1.Agents/Dismiss',
          ($0.DismissAgentRequest value) => value.writeToBuffer(),
          $0.DismissAgentResponse.fromBuffer);
  static final _$watch =
      $grpc.ClientMethod<$0.WatchAgentsRequest, $0.AgentsSnapshot>(
          '/kumo.v1.Agents/Watch',
          ($0.WatchAgentsRequest value) => value.writeToBuffer(),
          $0.AgentsSnapshot.fromBuffer);
}

@$pb.GrpcServiceName('kumo.v1.Agents')
abstract class AgentsServiceBase extends $grpc.Service {
  $core.String get $name => 'kumo.v1.Agents';

  AgentsServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.ListProvidersRequest, $0.ListProvidersResponse>(
            'ListProviders',
            listProviders_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListProvidersRequest.fromBuffer(value),
            ($0.ListProvidersResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SaveProviderRequest, $0.AgentProvider>(
        'SaveProvider',
        saveProvider_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SaveProviderRequest.fromBuffer(value),
        ($0.AgentProvider value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteProviderRequest,
            $0.DeleteProviderResponse>(
        'DeleteProvider',
        deleteProvider_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteProviderRequest.fromBuffer(value),
        ($0.DeleteProviderResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.TestProviderRequest, $0.TestProviderResponse>(
            'TestProvider',
            testProvider_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.TestProviderRequest.fromBuffer(value),
            ($0.TestProviderResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.LoginProviderRequest, $0.LoginProviderResponse>(
            'LoginProvider',
            loginProvider_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.LoginProviderRequest.fromBuffer(value),
            ($0.LoginProviderResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.StartAgentRequest, $0.AgentSession>(
        'Start',
        start_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.StartAgentRequest.fromBuffer(value),
        ($0.AgentSession value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.StopAgentRequest, $0.StopAgentResponse>(
        'Stop',
        stop_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.StopAgentRequest.fromBuffer(value),
        ($0.StopAgentResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.DismissAgentRequest, $0.DismissAgentResponse>(
            'Dismiss',
            dismiss_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.DismissAgentRequest.fromBuffer(value),
            ($0.DismissAgentResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.WatchAgentsRequest, $0.AgentsSnapshot>(
        'Watch',
        watch_Pre,
        false,
        true,
        ($core.List<$core.int> value) =>
            $0.WatchAgentsRequest.fromBuffer(value),
        ($0.AgentsSnapshot value) => value.writeToBuffer()));
  }

  $async.Future<$0.ListProvidersResponse> listProviders_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListProvidersRequest> $request) async {
    return listProviders($call, await $request);
  }

  $async.Future<$0.ListProvidersResponse> listProviders(
      $grpc.ServiceCall call, $0.ListProvidersRequest request);

  $async.Future<$0.AgentProvider> saveProvider_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SaveProviderRequest> $request) async {
    return saveProvider($call, await $request);
  }

  $async.Future<$0.AgentProvider> saveProvider(
      $grpc.ServiceCall call, $0.SaveProviderRequest request);

  $async.Future<$0.DeleteProviderResponse> deleteProvider_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DeleteProviderRequest> $request) async {
    return deleteProvider($call, await $request);
  }

  $async.Future<$0.DeleteProviderResponse> deleteProvider(
      $grpc.ServiceCall call, $0.DeleteProviderRequest request);

  $async.Future<$0.TestProviderResponse> testProvider_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.TestProviderRequest> $request) async {
    return testProvider($call, await $request);
  }

  $async.Future<$0.TestProviderResponse> testProvider(
      $grpc.ServiceCall call, $0.TestProviderRequest request);

  $async.Future<$0.LoginProviderResponse> loginProvider_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.LoginProviderRequest> $request) async {
    return loginProvider($call, await $request);
  }

  $async.Future<$0.LoginProviderResponse> loginProvider(
      $grpc.ServiceCall call, $0.LoginProviderRequest request);

  $async.Future<$0.AgentSession> start_Pre($grpc.ServiceCall $call,
      $async.Future<$0.StartAgentRequest> $request) async {
    return start($call, await $request);
  }

  $async.Future<$0.AgentSession> start(
      $grpc.ServiceCall call, $0.StartAgentRequest request);

  $async.Future<$0.StopAgentResponse> stop_Pre($grpc.ServiceCall $call,
      $async.Future<$0.StopAgentRequest> $request) async {
    return stop($call, await $request);
  }

  $async.Future<$0.StopAgentResponse> stop(
      $grpc.ServiceCall call, $0.StopAgentRequest request);

  $async.Future<$0.DismissAgentResponse> dismiss_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DismissAgentRequest> $request) async {
    return dismiss($call, await $request);
  }

  $async.Future<$0.DismissAgentResponse> dismiss(
      $grpc.ServiceCall call, $0.DismissAgentRequest request);

  $async.Stream<$0.AgentsSnapshot> watch_Pre($grpc.ServiceCall $call,
      $async.Future<$0.WatchAgentsRequest> $request) async* {
    yield* watch($call, await $request);
  }

  $async.Stream<$0.AgentsSnapshot> watch(
      $grpc.ServiceCall call, $0.WatchAgentsRequest request);
}
