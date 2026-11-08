# Engine: commits, releases & tags, review threads (Git view)

## Why

Branch `feat/git-history` adds three things to the Git view in kumo-ui. All three are built and tested against mocks:

1. **Commits**
   - The panel filters by branch: `main`, every branch, or one branch (its own commits, then main's history under them).
   - It also filters by author.
   - A commit opens a sheet with **its files and their diff**.
2. **Releases & tags**
   - An Overview / Releases switch lists releases and bare tags, newest first.
   - For each one it shows its notes and **what changed since the release it's compared with**: commits, merged PRs, tickets, people, +/- lines.
   - Actions:
     - an agent writes the notes;
     - publish a pre-release;
     - create a release from a bare tag.
3. **Resolve comments**
   - Each PR row shows its **open review threads**.
   - "Resolve comments…" lists them. An agent changes the code and drafts a reply per thread. The user **posts the replies and resolves the threads** from Kumo.

The UI reads all of this through `RepoActivitySource` (`kumo-ui/lib/data/repo_activity.dart`). The new members have defaults that say "unsupported" (see the "Releases and tags" and "Review threads" blocks at the end of the abstract class). `EngineRepoActivity` (`kumo-ui/lib/engine/engine_repo_activity.dart`) doesn't override them yet. So today the app:
- disables the branch picker ("Needs a newer kumod"; `allBranchesSupported` is false);
- shows "Kumo's engine can't read a commit's changes yet" in the commit sheet;
- shows "can't list tags and releases yet" in Releases;
- falls back to the plain agent job for review comments.

The author filter already works on today's `Git.Log`.

This task makes the daemon serve the data, then wires `EngineRepoActivity`. **Read the UI models in `kumo-ui/lib/data/repo_history.dart` first**: the proto below mirrors them.

Depends on: `PullRequests.Edit` (spec `pull-request-edit-engine.md`) is separate and still useful (PR descriptions), but nothing here needs it.

---

## 1. History

### 1a. `Git.Log` with a branch, every branch, and PR refs

Extend `LogRequest` / `Commit` (`proto/kumo/v1/kumo.proto`, around line 613):

```proto
message LogRequest {
  string worktree_path = 1;
  uint32 limit = 2;
  // Main plus the commits of every other branch (local and remote) that
  // aren't on main yet, each with `branch` set. Newest first.
  bool all_branches = 3;
}

message Commit {
  string sha = 1;
  string short_sha = 2;
  string subject = 3;
  string author = 4;
  uint64 time_unix = 5;
  // The branch it's on when it isn't on main yet (all_branches only).
  string branch = 6;
  // The pull request it came from: `#518` (GitHub/Bitbucket), `!228`
  // (GitLab), read from the subject; empty when none.
  string pr_ref = 7;
}
```

- **`all_branches`**:
  - Start with main's log.
  - For each branch that isn't main, local or `origin/*` (skip `origin/HEAD` and main's own remote), add `git log <main>..<branch> -n<limit>` with `branch` set. Prefer the local name when both exist.
  - Deduplicate by sha, keeping the first branch seen.
  - Sort by time, newest first.
  - Cap at about 30 branches, the most recently committed ones.
- **`pr_ref`**, parsed from the subject:
  - `Merge pull request #518 from …` → `#518`
  - a squash `… (#518)` → `#518`
  - GitLab's `See merge request group/repo!228` in the body → `!228`. Asking for the body costs `%b`, so add it only if cheap.
- Test with a fixture repo that has two branches, one of them merged into main by a merge commit.

### 1b. `Git.ShowCommit`: what one commit changed

```proto
  // What one commit changed, file by file, with its hunks.
  rpc ShowCommit(ShowCommitRequest) returns (CommitDetail);

message ShowCommitRequest {
  string worktree_path = 1;
  string sha = 2;
}

message DiffHunk {
  uint32 old_start = 1;
  uint32 new_start = 2;
  // What git prints after the second @@ (the enclosing function).
  string section = 3;
  repeated DiffLine lines = 4;   // existing DiffLine / DiffLineKind
}

message CommitFile {
  string path = 1;
  string old_path = 2;          // renames
  ChangeKind kind = 3;          // existing enum: ADDED, MODIFIED, DELETED, RENAMED
  uint32 added = 4;
  uint32 deleted = 5;
  bool binary = 6;
  repeated DiffHunk hunks = 7;  // empty for binary or when cut
  bool cut = 8;                 // hunks left out (file too big)
}

message CommitDetail {
  string sha = 1;
  string body = 2;              // the message after the subject line
  repeated string parents = 3;  // short shas
  uint64 time_unix = 4;
  repeated CommitFile files = 5;
}
```

Implementation (in `crates/infrastructure/src/git/changes.rs`, next to `log`):
- **Header:** `git show -s --format=%H%x1f%p%x1f%at%x1f%b <sha>`.
- **Counts:** `git show --numstat -M --format= <sha>`. `-` `-` means binary. Renames come as `old => new` (also in the `{a => b}` brace form).
- **Hunks:** `git show -p -M --unified=3 --format= --no-color <sha>`. Parse the `diff --git` / `@@ -a,b +c,d @@ section` headers and the ` `, `+`, `-` lines. Ignore `\ No newline at end of file`.
- **Limits:** at most 300 files. Over 2,000 lines in one file, keep the counts but no hunks, with `cut = true`. Merge commits: diff against the first parent (`-m --first-parent`).
- **Tests** (fixture repo):
  - one commit that adds, modifies, deletes and renames a file;
  - a binary file;
  - the hunk numbers and section;
  - a merge commit.

---

## 2. Releases & tags

### Proto: a new service, so the UI can check it per daemon

```proto
// Tags of a repository and, where the host has them, their releases.
service Releases {
  // Newest version first: releases and bare tags. Answers are reused for a
  // minute unless `refresh`.
  rpc List(ListReleasesRequest) returns (ReleaseList);
  // What changed in `tag` since `since` (empty: since the first commit).
  rpc Range(ReleaseRangeRequest) returns (ReleaseRange);
  // Sets a release's name and/or notes; for a bare tag, creates its
  // release; `publish` turns a pre-release or draft into the latest.
  rpc Edit(EditReleaseRequest) returns (Release);
}

enum ReleaseKind {
  RELEASE_KIND_RELEASE = 0;
  RELEASE_KIND_PRE_RELEASE = 1;
  RELEASE_KIND_DRAFT = 2;
  RELEASE_KIND_TAG_ONLY = 3;
}

message ReleaseAsset { string name = 1; uint64 size = 2; }

message Release {
  string tag = 1;
  ReleaseKind kind = 2;
  string name = 3;
  string notes = 4;           // Markdown; empty = none
  string author = 5;          // display name (or login)
  string sha = 6;             // the tagged commit
  uint64 time_unix = 7;       // published, else tagged
  string url = 8;             // the release page, else the tag's
  CiState checks = 9;         // latest run on the tagged commit; unset = unknown
  bool has_checks = 10;
  repeated ReleaseAsset assets = 11;
}

message ListReleasesRequest { string repo_path = 1; uint32 limit = 2; bool refresh = 3; }
message ReleaseList { repeated Release releases = 1; uint32 older = 2; }

message ReleaseRangeRequest { string repo_path = 1; string tag = 2; string since = 3; }

message MergedPr { string ref = 1; string title = 2; string author = 3; string ticket = 4; }

message ReleaseRange {
  string since = 1;
  uint32 commits = 2;
  uint32 added = 3;
  uint32 deleted = 4;
  uint32 files = 5;
  repeated MergedPr prs = 6;
}

message EditReleaseRequest {
  string repo_path = 1;
  string tag = 2;
  optional string name = 3;
  optional string notes = 4;
  bool publish = 5;
}
```

### List
- **Tags** come from git: `git fetch --tags` (at most once per `refresh`) then `git for-each-ref refs/tags --sort=-v:refname --format=…`. Each gives its tag, the commit sha (`%(*objectname)` for annotated tags) and its time. Version order puts `v1.9.0-rc.1` above `v1.8.0`, which is what the UI expects.
- **Releases** come from the host, using the same token resolution as `PullRequests.List` (the workspace's):
  - **GitHub**: `GET /repos/{o}/{r}/releases?per_page=100`. Use `prerelease` and `draft`, plus `name`, `body`, `author.login`, `html_url`, `published_at` and `assets[].{name,size}`.
  - **GitLab**: `GET /projects/:id/releases`. Use `name`, `description`, `author.name`, `_links.self` and `assets.sources`. GitLab has no pre-release flag: an `upcoming_release: true` maps to `PRE_RELEASE`.
  - **Bitbucket**: no releases. Every tag is `TAG_ONLY` and `url` is `…/src/<tag>`.
- **Merge:** a tag with a release takes the release's fields. A tag without one is `TAG_ONLY`. A draft release with no tag yet is listed by its `tag_name`.
- **Checks:** the latest pipeline run on the tagged sha, if the pipelines client can ask cheaply. Otherwise leave `has_checks = false`.
- `older`: what's beyond `limit` (default 50).
- Tests use the existing host test servers: GitHub with a pre-release, a draft and a bare tag; GitLab; Bitbucket (all tags).

### Range
- **Counts:** `git rev-list --count since..tag` (or `tag` alone when `since` is empty), then `git diff --shortstat since..tag` for added, deleted and files.
- **Merged PRs:** read `git log --format=%s%x1f%an%x1f%b since..tag` and pick out `pr_ref` the same way as `Git.Log`.
  - Title: the host's PR title if the client has it cached. Otherwise the squash subject without `(#n)`, or the merge's body line.
  - Author: the commit author.
  - Ticket: the first `[A-Z][A-Z0-9]+-\d+` in the PR's branch name or title.
- Tests:
  - a range across a merge commit and a squash commit;
  - an empty `since`;
  - a `since` that isn't an ancestor (diff the merge base and say so in an error? decide and document).

### Edit
- **GitHub:**
  - existing release: `PATCH /repos/{o}/{r}/releases/{id}` with `name`/`body`, and on `publish` with `prerelease: false, draft: false, make_latest: "true"`;
  - bare tag: `POST /repos/{o}/{r}/releases` with `tag_name`, `name`, `body`.
- **GitLab:**
  - existing release: `PUT /projects/:id/releases/:tag_name` with `name`/`description`;
  - bare tag: `POST /projects/:id/releases` with `tag_name`, `name`, `description`;
  - `publish` does nothing (return it unchanged).
- **Bitbucket:** `UNIMPLEMENTED` with "Bitbucket has tags but no releases". The UI then copies the notes.
- **Errors:** a 403 says which permission is missing (GitHub "Contents: Read and write", GitLab `api`).
- Drop the cached `List` for the repo afterwards.

---

## 3. Review threads

### Proto (in `service PullRequests`)

```proto
  // A pull request's review threads, open and resolved, oldest first.
  rpc Threads(PullRequestThreadsRequest) returns (ThreadList);
  // Replies to a thread (when `reply` isn't empty) and resolves it.
  rpc AnswerThread(AnswerThreadRequest) returns (ReviewThread);

message PullRequestThreadsRequest { string repo_path = 1; uint64 number = 2; }

message ReviewThread {
  string id = 1;            // the host's thread / discussion id
  string author = 2;        // of its first comment
  string path = 3;
  uint32 line = 4;          // 0 = not on a line
  string body = 5;          // its first comment
  uint64 time_unix = 6;
  bool resolved = 7;
}

message ThreadList { repeated ReviewThread threads = 1; }

message AnswerThreadRequest {
  string repo_path = 1;
  uint64 number = 2;
  string thread_id = 3;
  string reply = 4;
  bool resolve = 5;
}
```

Also add **`uint32 open_threads = <next>`** and **`bool has_threads`** to `PullRequest`, filled by `List` when it's cheap:
- **GitHub:** the GraphQL list query can add `reviewThreads(first: 100) { nodes { isResolved } }`.
- **GitLab / Bitbucket:** leave `has_threads = false` unless the list endpoint carries it.

### Hosts (**verify against the current docs**)
- **GitHub (GraphQL):**
  - read: `pullRequest(number:) { reviewThreads(first: 100) { nodes { id isResolved path line comments(first: 1) { nodes { author { login } body createdAt } } } } }`;
  - reply: `addPullRequestReviewThreadReply(input: { pullRequestReviewThreadId, body })`;
  - resolve: `resolveReviewThread(input: { threadId })`.
- **GitLab:**
  - read: `GET /projects/:id/merge_requests/:iid/discussions`, keeping `resolvable` ones. Path and line come from the first note's `position`.
  - reply: `POST …/discussions/:discussion_id/notes`.
  - resolve: `PUT …/discussions/:discussion_id?resolved=true`.
- **Bitbucket:**
  - read: `GET /2.0/repositories/{ws}/{repo}/pullrequests/{id}/comments`, keeping top-level inline comments; check whether `resolution` is exposed.
  - reply: `POST …/comments` with `parent.id`.
  - resolve: `POST …/comments/{id}/resolve` (verify).
- Tests: per host, against the test servers. Cover reading threads, a reply only, resolve only, both, and a 403 with the missing permission.

---

## 4. UI wiring (after `make proto`, on `feat/git-history`)

All of this goes in `kumo-ui/lib/engine/engine_repo_activity.dart`. Each feature turns on when the daemon answers: catch `StatusCode.unimplemented` once, then report unsupported so the view keeps its "update kumod" notes.

- **History**
  - `allBranchesSupported` → true once `Log(all_branches)` answers.
  - `commits(allBranches: true)` returns the all-branches list.
  - Map `Commit.branch` and `Commit.pr_ref` into `RepoCommit.branch` / `prRef`.
- **`commitDetailsSupported` / `commitDetail`**
  - Call `ShowCommit` on the main checkout.
  - Map to `CommitDetail`:
    - each hunk becomes `DiffHunk(oldStart:, newStart:, section:, lines:)`;
    - number the `HunkLine`s like `DiffHunk.parse` does, from `old_start`/`new_start`;
    - `CommitFile.added`/`deleted` come from the counts (the constructor takes them);
    - `kind` maps from `ChangeKind`.
- **Releases**
  - `releasesSupported`, `releases` and `olderReleases` come from `Releases.List`, loaded with the PRs and refreshed with them.
  - `releaseRange` uses `Releases.Range`.
  - `releasesEditable` is true when the host isn't Bitbucket.
  - `editRelease` calls `Releases.Edit` and then re-lists.
- **Threads**
  - `threadsSupported` → true once `Threads` answers.
  - `openThreadsOf(pr)` reads `PullRequest.open_threads` when `has_threads` (keep it on `RepoPullRequest` via `toRepo()`).
  - `reviewThreads` calls `Threads`.
  - `threadsWritable` → true.
  - `answerThread` calls `AnswerThread`, then refreshes the PR list.

Nothing in the views changes. The mock (`MockRepoActivity`) shows what each member should return.

## Done when

- `cargo test` passes, including the new git fixture tests and the host-client tests.
- `make proto` is done. `flutter analyze` and `flutter test` pass (`test/git_history_test.dart` covers the UI against the mock).
- Against a real repository:
  - `feat/…` in the branch picker lists that branch's commits;
  - a commit opens with its diff;
  - Releases lists tags and releases with their ranges;
  - an agent's notes update a GitHub release;
  - "Resolve comments" posts replies and resolves threads on GitHub.
- Nothing is committed unless the user asks.
