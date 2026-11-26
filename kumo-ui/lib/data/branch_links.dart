import 'package:flutter/foundation.dart';

import 'pull_requests_source.dart';

/// Hosts whose web pages Kumo knows how to link to.
enum WebHost { github, gitlab, bitbucket }

/// A repository's page on its host, read from its remote URL.
@immutable
class RemoteWeb {
  const RemoteWeb({required this.host, required this.url});

  final WebHost host;

  /// e.g. `https://github.com/platform/repo-a`, never with credentials.
  final String url;

  String get hostName => switch (host) {
        WebHost.github => 'GitHub',
        WebHost.gitlab => 'GitLab',
        WebHost.bitbucket => 'Bitbucket',
      };

  /// What the host calls a pull request.
  String get request => host == WebHost.gitlab ? 'merge request' : 'pull request';

  /// [request], short: `PR`, `MR`.
  String get requestShort => host == WebHost.gitlab ? 'MR' : 'PR';

  /// The branch's page. Slashes in [branch] stay (the hosts read them as
  /// part of the name); anything else that needs it is encoded.
  String branchUrl(String branch) => switch (host) {
        WebHost.github => '$url/tree/${_path(branch)}',
        WebHost.gitlab => '$url/-/tree/${_path(branch)}',
        WebHost.bitbucket => '$url/branch/${_path(branch)}',
      };

  /// The page that opens a pull (merge) request from [branch] into [base];
  /// an empty [base] leaves the host's default branch.
  String newRequestUrl(String branch, {String base = ''}) => switch (host) {
        WebHost.github => '$url/compare/${base.isEmpty ? '' : '${_path(base)}...'}${_path(branch)}?expand=1',
        WebHost.gitlab => '$url/-/merge_requests/new?${_query({
                'merge_request[source_branch]': branch,
                if (base.isNotEmpty) 'merge_request[target_branch]': base,
              })}',
        WebHost.bitbucket => '$url/pull-requests/new?${_query({'source': branch, if (base.isNotEmpty) 'dest': base})}',
      };

  static String _path(String branch) => branch.split('/').map(Uri.encodeComponent).join('/');

  static String _query(Map<String, String> params) => [for (final MapEntry(:key, :value) in params.entries) '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}'].join('&');
}

/// The web page of the repository at [remoteUrl] (`git@host:owner/name.git`,
/// `ssh://user@host:port/owner/name.git`, `https://host/owner/name(.git)`),
/// or null: no remote, a local path, or a host Kumo doesn't know.
RemoteWeb? remoteWebOf(String remoteUrl) {
  final remote = remoteUrl.trim();
  if (remote.isEmpty) return null;
  String domain;
  String path;
  String scheme = 'https';
  final sep = remote.indexOf('://');
  if (sep >= 0) {
    final given = remote.substring(0, sep).toLowerCase();
    if (given == 'http') scheme = 'http';
    if (given != 'http' && given != 'https' && given != 'ssh' && given != 'git') return null;
    final rest = remote.substring(sep + 3);
    final slash = rest.indexOf('/');
    if (slash < 0) return null;
    final authority = rest.substring(0, slash);
    final hostPort = authority.substring(authority.lastIndexOf('@') + 1);
    // A web remote's port is the web page's too; an ssh or git one isn't.
    domain = given == 'http' || given == 'https' ? hostPort : hostPort.split(':').first;
    path = rest.substring(slash + 1);
  } else {
    // scp-like: [user@]host:path. A drive letter (C:\…) is a local path.
    final colon = remote.indexOf(':');
    if (colon <= 1 || remote.substring(0, colon).contains('/') || remote.substring(0, colon).contains(r'\')) return null;
    final authority = remote.substring(0, colon);
    domain = authority.substring(authority.lastIndexOf('@') + 1);
    path = remote.substring(colon + 1);
  }
  domain = domain.toLowerCase();
  final host = domain.contains('github')
      ? WebHost.github
      : domain.contains('gitlab')
          ? WebHost.gitlab
          : domain.contains('bitbucket')
              ? WebHost.bitbucket
              : null;
  if (host == null || domain.isEmpty) return null;
  var name = path;
  while (name.startsWith('/')) {
    name = name.substring(1);
  }
  while (name.endsWith('/')) {
    name = name.substring(0, name.length - 1);
  }
  if (name.endsWith('.git')) name = name.substring(0, name.length - 4);
  if (name.split('/').where((p) => p.isNotEmpty).length < 2) return null;
  return RemoteWeb(host: host, url: '$scheme://$domain/$name');
}

/// The branch [base] names on the remote: `origin/main` → `main`.
String baseBranchOf(String base) => base.startsWith('origin/') ? base.substring('origin/'.length) : base;

final _release = RegExp(r'^origin/(release/(\d+)\.(\d+)\.(\d+))$');

/// The open release among [remoteBranches] (`origin/release/0.10.0`): the
/// highest `release/X.Y.Z` on origin, compared as numbers. Null when there
/// is none.
String? openReleaseOf(Iterable<String> remoteBranches) {
  (String, List<int>)? best;
  for (final ref in remoteBranches) {
    final m = _release.firstMatch(ref);
    if (m == null) continue;
    final version = [for (var i = 2; i <= 4; i++) int.parse(m[i]!)];
    if (best == null || _compare(version, best.$2) > 0) best = (m[1]!, version);
  }
  return best?.$1;
}

int _compare(List<int> a, List<int> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}

/// Where a pushed branch can be seen on its host, and its pull request (or
/// where to open one).
@immutable
class BranchLinks {
  const BranchLinks({required this.web, required this.branch, required this.branchUrl, this.newRequestUrl, this.pullRequest});

  final RemoteWeb web;
  final String branch;
  final String branchUrl;

  /// Where to open a pull request; null for the base branch itself.
  final String? newRequestUrl;

  /// The branch's open pull request, when known.
  final PullRequestInfo? pullRequest;

  /// The one link worth a button: the pull request, else where to open
  /// one, else the branch.
  String get primaryUrl => pullRequest?.url ?? newRequestUrl ?? branchUrl;

  String get primaryLabel => pullRequest != null
      ? 'Open ${web.request} ${pullRequest!.label} on ${web.hostName}'
      : newRequestUrl != null
          ? 'Create ${web.request} on ${web.hostName}'
          : 'Open $branch on ${web.hostName}';
}

/// The links of [branch] once it is [pushed] to the remote at [remoteUrl];
/// null before, or when the host is unknown. [pullRequest] counts only when
/// open and with an address. Pull requests to create target the open
/// release among [remoteBranches] (see [openReleaseOf]), else [base], what
/// the branch is compared with (`origin/main`). A release branch itself
/// targets [base]; [base] itself has none to create.
BranchLinks? branchLinksOf({
  required String remoteUrl,
  required String branch,
  required String base,
  required bool pushed,
  PullRequestInfo? pullRequest,
  Iterable<String> remoteBranches = const [],
}) {
  if (!pushed || branch.isEmpty) return null;
  final web = remoteWebOf(remoteUrl);
  if (web == null) return null;
  final baseBranch = baseBranchOf(base);
  final release = branch.startsWith('release/') ? null : openReleaseOf(remoteBranches);
  final target = release ?? baseBranch;
  final open = pullRequest != null && pullRequest.state == PrOpenState.open && pullRequest.url.isNotEmpty ? pullRequest : null;
  return BranchLinks(
    web: web,
    branch: branch,
    branchUrl: web.branchUrl(branch),
    newRequestUrl: branch == target || branch == baseBranch ? null : web.newRequestUrl(branch, base: target),
    pullRequest: open,
  );
}
