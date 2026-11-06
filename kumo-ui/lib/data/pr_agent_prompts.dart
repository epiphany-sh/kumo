/// What Kumo asks an agent to do with a pull request (from the Git view's
/// PR menu), as prompts. Pure functions, so they can be tested as text.
library;

import 'repo_activity.dart';

/// The jobs an agent can take on for a pull request.
enum PrAgentJob {
  describe('Description'),
  review('Review'),
  explain('Walkthrough'),
  fixChecks('Fix checks'),
  addressComments('Review comments');

  const PrAgentJob(this.label);

  /// For the agent's card: “#521 · Review”.
  final String label;
}

/// How long a written description should be.
enum PrDescriptionLength {
  short('Short', 'A few lines: what changes and why.'),
  standard('Standard', 'A summary, the main changes and how to test them.'),
  detailed('Detailed', 'Also notes for reviewers and how it rolls out.');

  const PrDescriptionLength(this.label, this.hint);
  final String label;
  final String hint;
}

/// Where the agent runs, and what it knows about the pull request.
class PrAgentTarget {
  const PrAgentTarget({required this.pr, required this.repoName, required this.host, required this.base, required this.inWorktree});

  final RepoPullRequest pr;
  final String repoName;

  /// `GH`, `GL`, `BB`…
  final String host;

  /// The branch it merges into (`main`).
  final String base;

  /// True when the agent runs in the PR branch's own worktree; false when it
  /// runs in the main checkout and has to read the branch from origin.
  final bool inWorktree;

  /// “pull request #521” / “merge request !231”.
  String get what => '${host == 'GL' ? 'merge request' : 'pull request'} ${pr.number}';

  /// The host's CLI, when it has one agents commonly have.
  String? get cli => switch (host) {
        'GH' => 'gh',
        'GL' => 'glab',
        _ => null,
      };

  /// How to see the changes from where the agent runs.
  String get diffCommand => inWorktree ? 'git fetch origin $base && git diff origin/$base...HEAD' : 'git fetch origin $base ${pr.branch} && git diff origin/$base...origin/${pr.branch}';

  String get _intro => '${_cap(what)} “${pr.title}” of $repoName merges `${pr.branch}` into `$base`. '
      '${inWorktree ? 'You are in its worktree.' : 'You are in the main checkout: read the branch from origin and don’t check it out.'}';

  String get _readDiff => 'Read the changes: `$diffCommand`'
      '${cli == 'gh' ? ' (or `gh pr diff ${pr.id}`)' : cli == 'glab' ? ' (or `glab mr diff ${pr.id}`)' : ''}.';
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// The prompt for [job] on [t]. [describe] has its own builder.
String prAgentPrompt(PrAgentJob job, PrAgentTarget t) {
  final n = t.pr.id;
  final failedJobs = switch (t.cli) {
    'gh' => ' Read the failed jobs: `gh pr checks $n`, then `gh run view <run id> --log-failed`.',
    'glab' => ' Read the failed jobs: `glab ci view` or `glab ci trace <job id>`.',
    _ => '',
  };
  final threads = switch (t.cli) {
    'gh' => ' Read them: `gh pr view $n --comments`, and the review threads with `gh api repos/{owner}/{repo}/pulls/$n/comments`.',
    'glab' => ' Read them: `glab mr view $n --comments`.',
    _ => '',
  };
  final where = t.inWorktree ? ' here' : ' (this is the main checkout: ask me before switching branches)';
  final lines = switch (job) {
    PrAgentJob.review => [
        t._intro,
        t._readDiff,
        'Review it as a teammate would. Don’t change any file and don’t post anything on the ${t.host == 'GL' ? 'merge request' : 'pull request'}.',
        'List what you would comment, most important first: the file and line, the problem, and a suggested fix. Then say whether you would approve it.',
        'I’ll decide what to post.',
      ],
    PrAgentJob.explain => [
        t._intro,
        t._readDiff,
        'Explain it to someone about to review it: what it changes and why, the files worth reading in the order to read them, and anything risky or surprising.',
        'Don’t change any file.',
      ],
    PrAgentJob.fixChecks => [
        t._intro,
        'Its checks are failing.$failedJobs',
        'Find the cause and fix it$where. Run the failing tests locally if you can.',
        'Commit the fix, but don’t push until I say so.',
      ],
    PrAgentJob.addressComments => [
        t._intro,
        'Reviewers asked for changes.$threads',
        'Make the changes$where, and for each thread tell me what you changed or why you didn’t.',
        'Commit, but don’t push or reply on the ${t.host == 'GL' ? 'merge request' : 'pull request'} until I say so.',
      ],
    PrAgentJob.describe => throw ArgumentError('Use prDescriptionPrompt'),
  };
  return lines.join('\n\n');
}

/// The prompt that has an agent write [t]'s description into [draftPath]
/// (and, with [titlePath], a better title into it), for Kumo to show the
/// user before anything changes on the host.
String prDescriptionPrompt(
  PrAgentTarget t, {
  required String draftPath,
  String? titlePath,
  bool commits = true,
  String? ticket,
  String? templatePath,
  bool keepCurrent = true,
  PrDescriptionLength length = PrDescriptionLength.standard,
  String extra = '',
}) {
  final n = t.pr.id;
  final current = switch (t.cli) {
    'gh' => '`gh pr view $n --json body --jq .body`',
    'glab' => '`glab mr view $n`',
    _ => null,
  };
  return [
    'Write the description of ${t.what} (“${t.pr.title}”) of ${t.repoName}, which merges `${t.pr.branch}` into `${t.base}`. '
        '${t.inWorktree ? 'You are in its worktree.' : 'You are in the main checkout: read the branch from origin and don’t check it out.'}',
    'Read:',
    [
      '- The changes: `${t.diffCommand}`.',
      if (commits) '- Its commit messages: `git log --format=%B origin/${t.base}..${t.inWorktree ? 'HEAD' : 'origin/${t.pr.branch}'}`.',
      if (templatePath != null) '- The team’s template, `$templatePath`: keep its sections and fill them in.',
      if (keepCurrent && current != null) '- The current description ($current): keep what is still true in it.',
      if (ticket != null) '- The ticket it implements, below.',
    ].join('\n'),
    'Length: ${length.hint}',
    if (extra.trim().isNotEmpty) 'Also: ${extra.trim()}',
    'Write it for reviewers, in the language of the commits and the ticket. Name files and identifiers in backticks. Don’t invent anything you didn’t read: no test results you didn’t see, no ticket you weren’t given.',
    '${titlePath == null ? 'Save the description' : 'First save a better title for it, one line, in the style of the repository’s commits, to `$titlePath`. Then save the description'}'
        ', in Markdown, to `$draftPath`: only the description, no title line and no preamble.',
    'Don’t change any other file, don’t commit, and don’t edit the ${t.host == 'GL' ? 'merge request' : 'pull request'}: I’ll check the draft in Kumo and update it from there. When the file is written, say “Done”.',
    if (ticket != null) '## The ticket\n\n${ticket.trim()}',
  ].join('\n\n');
}

/// The follow-up typed into the same agent: change the draft as asked.
String prDescriptionRevision(String draftPath, String ask) =>
    'Change the description in `$draftPath` as follows, and save it to the same file: ${ask.trim()}. Don’t change anything else. When the file is written, say “Done”.';

/// A ticket key in a branch name (`feat/PRC-412-bulk-discounts` → PRC-412).
String? ticketKeyIn(String branch) => RegExp(r'[A-Z][A-Z0-9]+-\d+').firstMatch(branch)?.group(0);
