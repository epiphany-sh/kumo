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

  $grpc.ResponseFuture<$0.GitActionResponse> fetch(
    $0.WorktreeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$fetch, request, options: options);
  }

  /// `git pull --ff-only`: fails instead of creating a merge commit.
  $grpc.ResponseFuture<$0.GitActionResponse> pull(
    $0.WorktreeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$pull, request, options: options);
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
  static final _$fetch =
      $grpc.ClientMethod<$0.WorktreeRequest, $0.GitActionResponse>(
          '/kumo.v1.Git/Fetch',
          ($0.WorktreeRequest value) => value.writeToBuffer(),
          $0.GitActionResponse.fromBuffer);
  static final _$pull =
      $grpc.ClientMethod<$0.WorktreeRequest, $0.GitActionResponse>(
          '/kumo.v1.Git/Pull',
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
        'Fetch',
        fetch_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.WorktreeRequest.fromBuffer(value),
        ($0.GitActionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.WorktreeRequest, $0.GitActionResponse>(
        'Pull',
        pull_Pre,
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

  $async.Future<$0.GitActionResponse> fetch_Pre($grpc.ServiceCall $call,
      $async.Future<$0.WorktreeRequest> $request) async {
    return fetch($call, await $request);
  }

  $async.Future<$0.GitActionResponse> fetch(
      $grpc.ServiceCall call, $0.WorktreeRequest request);

  $async.Future<$0.GitActionResponse> pull_Pre($grpc.ServiceCall $call,
      $async.Future<$0.WorktreeRequest> $request) async {
    return pull($call, await $request);
  }

  $async.Future<$0.GitActionResponse> pull(
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

/// Tasks from the tools the user already works with. The board is served
/// from a local cache and pushed whenever a source's tasks change; sources
/// are re-read in the background (on file changes for local ones, on an
/// interval for APIs). Nothing here waits on the network except Test,
/// SetStatus and Detect.
@$pb.GrpcServiceName('kumo.v1.Tasks')
class TasksClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  TasksClient(super.channel, {super.options, super.interceptors});

  /// The board now, then again whenever it changes (last wins). Each update
  /// carries every source but only the task lists that changed.
  $grpc.ResponseStream<$0.TasksUpdate> watch(
    $0.WatchTasksRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$watch, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Sources found on this machine that aren't configured yet (Obsidian
  /// vaults, Bear, a signed-in `gh`).
  $grpc.ResponseFuture<$0.DetectSourcesResponse> detect(
    $0.DetectSourcesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$detect, request, options: options);
  }

  /// Checks options and credentials without saving them.
  $grpc.ResponseFuture<$0.TestSourceResponse> testSource(
    $0.TestSourceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$testSource, request, options: options);
  }

  /// Creates (empty id) or updates a source.
  $grpc.ResponseFuture<$0.TaskSource> saveSource(
    $0.SaveSourceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$saveSource, request, options: options);
  }

  /// Forgets a source, its cached tasks, links and stored token.
  $grpc.ResponseFuture<$0.DeleteSourceResponse> deleteSource(
    $0.DeleteSourceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteSource, request, options: options);
  }

  /// Reads a source (empty id: all) now.
  $grpc.ResponseFuture<$0.SyncTasksResponse> sync(
    $0.SyncTasksRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$sync, request, options: options);
  }

  /// Writes the status back to the source (only `writable` ones).
  $grpc.ResponseFuture<$0.Task> setStatus(
    $0.SetTaskStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$setStatus, request, options: options);
  }

  /// Records that a task is being worked on in a worktree.
  $grpc.ResponseFuture<$0.TaskLink> link(
    $0.LinkTaskRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$link, request, options: options);
  }

  $grpc.ResponseFuture<$0.UnlinkTaskResponse> unlink(
    $0.UnlinkTaskRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$unlink, request, options: options);
  }

  // method descriptors

  static final _$watch =
      $grpc.ClientMethod<$0.WatchTasksRequest, $0.TasksUpdate>(
          '/kumo.v1.Tasks/Watch',
          ($0.WatchTasksRequest value) => value.writeToBuffer(),
          $0.TasksUpdate.fromBuffer);
  static final _$detect =
      $grpc.ClientMethod<$0.DetectSourcesRequest, $0.DetectSourcesResponse>(
          '/kumo.v1.Tasks/Detect',
          ($0.DetectSourcesRequest value) => value.writeToBuffer(),
          $0.DetectSourcesResponse.fromBuffer);
  static final _$testSource =
      $grpc.ClientMethod<$0.TestSourceRequest, $0.TestSourceResponse>(
          '/kumo.v1.Tasks/TestSource',
          ($0.TestSourceRequest value) => value.writeToBuffer(),
          $0.TestSourceResponse.fromBuffer);
  static final _$saveSource =
      $grpc.ClientMethod<$0.SaveSourceRequest, $0.TaskSource>(
          '/kumo.v1.Tasks/SaveSource',
          ($0.SaveSourceRequest value) => value.writeToBuffer(),
          $0.TaskSource.fromBuffer);
  static final _$deleteSource =
      $grpc.ClientMethod<$0.DeleteSourceRequest, $0.DeleteSourceResponse>(
          '/kumo.v1.Tasks/DeleteSource',
          ($0.DeleteSourceRequest value) => value.writeToBuffer(),
          $0.DeleteSourceResponse.fromBuffer);
  static final _$sync =
      $grpc.ClientMethod<$0.SyncTasksRequest, $0.SyncTasksResponse>(
          '/kumo.v1.Tasks/Sync',
          ($0.SyncTasksRequest value) => value.writeToBuffer(),
          $0.SyncTasksResponse.fromBuffer);
  static final _$setStatus =
      $grpc.ClientMethod<$0.SetTaskStatusRequest, $0.Task>(
          '/kumo.v1.Tasks/SetStatus',
          ($0.SetTaskStatusRequest value) => value.writeToBuffer(),
          $0.Task.fromBuffer);
  static final _$link = $grpc.ClientMethod<$0.LinkTaskRequest, $0.TaskLink>(
      '/kumo.v1.Tasks/Link',
      ($0.LinkTaskRequest value) => value.writeToBuffer(),
      $0.TaskLink.fromBuffer);
  static final _$unlink =
      $grpc.ClientMethod<$0.UnlinkTaskRequest, $0.UnlinkTaskResponse>(
          '/kumo.v1.Tasks/Unlink',
          ($0.UnlinkTaskRequest value) => value.writeToBuffer(),
          $0.UnlinkTaskResponse.fromBuffer);
}

@$pb.GrpcServiceName('kumo.v1.Tasks')
abstract class TasksServiceBase extends $grpc.Service {
  $core.String get $name => 'kumo.v1.Tasks';

  TasksServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.WatchTasksRequest, $0.TasksUpdate>(
        'Watch',
        watch_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.WatchTasksRequest.fromBuffer(value),
        ($0.TasksUpdate value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.DetectSourcesRequest, $0.DetectSourcesResponse>(
            'Detect',
            detect_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.DetectSourcesRequest.fromBuffer(value),
            ($0.DetectSourcesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TestSourceRequest, $0.TestSourceResponse>(
        'TestSource',
        testSource_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.TestSourceRequest.fromBuffer(value),
        ($0.TestSourceResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SaveSourceRequest, $0.TaskSource>(
        'SaveSource',
        saveSource_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SaveSourceRequest.fromBuffer(value),
        ($0.TaskSource value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.DeleteSourceRequest, $0.DeleteSourceResponse>(
            'DeleteSource',
            deleteSource_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.DeleteSourceRequest.fromBuffer(value),
            ($0.DeleteSourceResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SyncTasksRequest, $0.SyncTasksResponse>(
        'Sync',
        sync_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SyncTasksRequest.fromBuffer(value),
        ($0.SyncTasksResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SetTaskStatusRequest, $0.Task>(
        'SetStatus',
        setStatus_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SetTaskStatusRequest.fromBuffer(value),
        ($0.Task value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LinkTaskRequest, $0.TaskLink>(
        'Link',
        link_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.LinkTaskRequest.fromBuffer(value),
        ($0.TaskLink value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UnlinkTaskRequest, $0.UnlinkTaskResponse>(
        'Unlink',
        unlink_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UnlinkTaskRequest.fromBuffer(value),
        ($0.UnlinkTaskResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.TasksUpdate> watch_Pre($grpc.ServiceCall $call,
      $async.Future<$0.WatchTasksRequest> $request) async* {
    yield* watch($call, await $request);
  }

  $async.Stream<$0.TasksUpdate> watch(
      $grpc.ServiceCall call, $0.WatchTasksRequest request);

  $async.Future<$0.DetectSourcesResponse> detect_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DetectSourcesRequest> $request) async {
    return detect($call, await $request);
  }

  $async.Future<$0.DetectSourcesResponse> detect(
      $grpc.ServiceCall call, $0.DetectSourcesRequest request);

  $async.Future<$0.TestSourceResponse> testSource_Pre($grpc.ServiceCall $call,
      $async.Future<$0.TestSourceRequest> $request) async {
    return testSource($call, await $request);
  }

  $async.Future<$0.TestSourceResponse> testSource(
      $grpc.ServiceCall call, $0.TestSourceRequest request);

  $async.Future<$0.TaskSource> saveSource_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SaveSourceRequest> $request) async {
    return saveSource($call, await $request);
  }

  $async.Future<$0.TaskSource> saveSource(
      $grpc.ServiceCall call, $0.SaveSourceRequest request);

  $async.Future<$0.DeleteSourceResponse> deleteSource_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DeleteSourceRequest> $request) async {
    return deleteSource($call, await $request);
  }

  $async.Future<$0.DeleteSourceResponse> deleteSource(
      $grpc.ServiceCall call, $0.DeleteSourceRequest request);

  $async.Future<$0.SyncTasksResponse> sync_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SyncTasksRequest> $request) async {
    return sync($call, await $request);
  }

  $async.Future<$0.SyncTasksResponse> sync(
      $grpc.ServiceCall call, $0.SyncTasksRequest request);

  $async.Future<$0.Task> setStatus_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SetTaskStatusRequest> $request) async {
    return setStatus($call, await $request);
  }

  $async.Future<$0.Task> setStatus(
      $grpc.ServiceCall call, $0.SetTaskStatusRequest request);

  $async.Future<$0.TaskLink> link_Pre($grpc.ServiceCall $call,
      $async.Future<$0.LinkTaskRequest> $request) async {
    return link($call, await $request);
  }

  $async.Future<$0.TaskLink> link(
      $grpc.ServiceCall call, $0.LinkTaskRequest request);

  $async.Future<$0.UnlinkTaskResponse> unlink_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UnlinkTaskRequest> $request) async {
    return unlink($call, await $request);
  }

  $async.Future<$0.UnlinkTaskResponse> unlink(
      $grpc.ServiceCall call, $0.UnlinkTaskRequest request);
}

@$pb.GrpcServiceName('kumo.v1.Pipelines')
class PipelinesClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  PipelinesClient(super.channel, {super.options, super.interceptors});

  /// The latest run of the worktree's branch, pushed whenever it changes.
  /// The first message is the first answer (or problem).
  $grpc.ResponseStream<$0.PipelinesSnapshot> watch(
    $0.WatchPipelinesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$watch, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Asks the provider now; returns once the new snapshot was pushed.
  $grpc.ResponseFuture<$0.PipelinesActionResponse> refresh(
    $0.WorktreeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$refresh, request, options: options);
  }

  /// Re-runs the failed jobs of a run (Bitbucket: a new pipeline for the
  /// same commit).
  $grpc.ResponseFuture<$0.PipelinesActionResponse> rerunFailed(
    $0.RerunFailedRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$rerunFailed, request, options: options);
  }

  /// Hosts of the workspace's repositories, and whether each has a token.
  $grpc.ResponseFuture<$0.ListHostsResponse> listHosts(
    $0.ListHostsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listHosts, request, options: options);
  }

  /// Saves the host's token in the keychain; an empty token removes it.
  $grpc.ResponseFuture<$0.CiHostInfo> saveHostToken(
    $0.SaveHostTokenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$saveHostToken, request, options: options);
  }

  /// Checks a token (the given one, or the saved one when empty).
  $grpc.ResponseFuture<$0.TestHostResponse> testHost(
    $0.TestHostRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$testHost, request, options: options);
  }

  /// Opens a terminal running `gh auth login` for a GitHub host; once it's
  /// signed in, the host's pipelines are asked again on their own. Kumo
  /// never sees what's typed there.
  $grpc.ResponseFuture<$0.SignInWithGhResponse> signInWithGh(
    $0.SignInWithGhRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$signInWithGh, request, options: options);
  }

  // method descriptors

  static final _$watch =
      $grpc.ClientMethod<$0.WatchPipelinesRequest, $0.PipelinesSnapshot>(
          '/kumo.v1.Pipelines/Watch',
          ($0.WatchPipelinesRequest value) => value.writeToBuffer(),
          $0.PipelinesSnapshot.fromBuffer);
  static final _$refresh =
      $grpc.ClientMethod<$0.WorktreeRequest, $0.PipelinesActionResponse>(
          '/kumo.v1.Pipelines/Refresh',
          ($0.WorktreeRequest value) => value.writeToBuffer(),
          $0.PipelinesActionResponse.fromBuffer);
  static final _$rerunFailed =
      $grpc.ClientMethod<$0.RerunFailedRequest, $0.PipelinesActionResponse>(
          '/kumo.v1.Pipelines/RerunFailed',
          ($0.RerunFailedRequest value) => value.writeToBuffer(),
          $0.PipelinesActionResponse.fromBuffer);
  static final _$listHosts =
      $grpc.ClientMethod<$0.ListHostsRequest, $0.ListHostsResponse>(
          '/kumo.v1.Pipelines/ListHosts',
          ($0.ListHostsRequest value) => value.writeToBuffer(),
          $0.ListHostsResponse.fromBuffer);
  static final _$saveHostToken =
      $grpc.ClientMethod<$0.SaveHostTokenRequest, $0.CiHostInfo>(
          '/kumo.v1.Pipelines/SaveHostToken',
          ($0.SaveHostTokenRequest value) => value.writeToBuffer(),
          $0.CiHostInfo.fromBuffer);
  static final _$testHost =
      $grpc.ClientMethod<$0.TestHostRequest, $0.TestHostResponse>(
          '/kumo.v1.Pipelines/TestHost',
          ($0.TestHostRequest value) => value.writeToBuffer(),
          $0.TestHostResponse.fromBuffer);
  static final _$signInWithGh =
      $grpc.ClientMethod<$0.SignInWithGhRequest, $0.SignInWithGhResponse>(
          '/kumo.v1.Pipelines/SignInWithGh',
          ($0.SignInWithGhRequest value) => value.writeToBuffer(),
          $0.SignInWithGhResponse.fromBuffer);
}

@$pb.GrpcServiceName('kumo.v1.Pipelines')
abstract class PipelinesServiceBase extends $grpc.Service {
  $core.String get $name => 'kumo.v1.Pipelines';

  PipelinesServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.WatchPipelinesRequest, $0.PipelinesSnapshot>(
            'Watch',
            watch_Pre,
            false,
            true,
            ($core.List<$core.int> value) =>
                $0.WatchPipelinesRequest.fromBuffer(value),
            ($0.PipelinesSnapshot value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.WorktreeRequest, $0.PipelinesActionResponse>(
            'Refresh',
            refresh_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.WorktreeRequest.fromBuffer(value),
            ($0.PipelinesActionResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RerunFailedRequest, $0.PipelinesActionResponse>(
            'RerunFailed',
            rerunFailed_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RerunFailedRequest.fromBuffer(value),
            ($0.PipelinesActionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListHostsRequest, $0.ListHostsResponse>(
        'ListHosts',
        listHosts_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListHostsRequest.fromBuffer(value),
        ($0.ListHostsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SaveHostTokenRequest, $0.CiHostInfo>(
        'SaveHostToken',
        saveHostToken_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SaveHostTokenRequest.fromBuffer(value),
        ($0.CiHostInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TestHostRequest, $0.TestHostResponse>(
        'TestHost',
        testHost_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.TestHostRequest.fromBuffer(value),
        ($0.TestHostResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SignInWithGhRequest, $0.SignInWithGhResponse>(
            'SignInWithGh',
            signInWithGh_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SignInWithGhRequest.fromBuffer(value),
            ($0.SignInWithGhResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.PipelinesSnapshot> watch_Pre($grpc.ServiceCall $call,
      $async.Future<$0.WatchPipelinesRequest> $request) async* {
    yield* watch($call, await $request);
  }

  $async.Stream<$0.PipelinesSnapshot> watch(
      $grpc.ServiceCall call, $0.WatchPipelinesRequest request);

  $async.Future<$0.PipelinesActionResponse> refresh_Pre($grpc.ServiceCall $call,
      $async.Future<$0.WorktreeRequest> $request) async {
    return refresh($call, await $request);
  }

  $async.Future<$0.PipelinesActionResponse> refresh(
      $grpc.ServiceCall call, $0.WorktreeRequest request);

  $async.Future<$0.PipelinesActionResponse> rerunFailed_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RerunFailedRequest> $request) async {
    return rerunFailed($call, await $request);
  }

  $async.Future<$0.PipelinesActionResponse> rerunFailed(
      $grpc.ServiceCall call, $0.RerunFailedRequest request);

  $async.Future<$0.ListHostsResponse> listHosts_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListHostsRequest> $request) async {
    return listHosts($call, await $request);
  }

  $async.Future<$0.ListHostsResponse> listHosts(
      $grpc.ServiceCall call, $0.ListHostsRequest request);

  $async.Future<$0.CiHostInfo> saveHostToken_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SaveHostTokenRequest> $request) async {
    return saveHostToken($call, await $request);
  }

  $async.Future<$0.CiHostInfo> saveHostToken(
      $grpc.ServiceCall call, $0.SaveHostTokenRequest request);

  $async.Future<$0.TestHostResponse> testHost_Pre($grpc.ServiceCall $call,
      $async.Future<$0.TestHostRequest> $request) async {
    return testHost($call, await $request);
  }

  $async.Future<$0.TestHostResponse> testHost(
      $grpc.ServiceCall call, $0.TestHostRequest request);

  $async.Future<$0.SignInWithGhResponse> signInWithGh_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SignInWithGhRequest> $request) async {
    return signInWithGh($call, await $request);
  }

  $async.Future<$0.SignInWithGhResponse> signInWithGh(
      $grpc.ServiceCall call, $0.SignInWithGhRequest request);
}
