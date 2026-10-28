import 'models.dart';

/// Mock data matching the design canvas. Replace with daemon streams later.
abstract final class Mock {
  static const repos = <Repo>[
    Repo(name: 'price-admin', host: 'GH', worktrees: [
      Worktree(branch: 'main', note: 'clean', tone: WorktreeTone.idle, path: '~/dev/price-admin', sync: 'up to date', agent: 'No agent', changes: 'clean'),
      Worktree(branch: 'feat/PRC-412-bulk-discounts', note: 'Claude · running', tone: WorktreeTone.running, path: '~/wt/price-admin/PRC-412', sync: '↑2 ↓0', agent: 'Claude · running', changes: '4 files', unpushed: 2),
      Worktree(branch: 'fix/PRC-398-rounding', note: 'Codex · needs you', tone: WorktreeTone.warn, path: '~/wt/price-admin/PRC-398', sync: '↑1 ↓0', agent: 'Codex · needs you', changes: '2 files', unpushed: 1, everPushed: false),
    ]),
    Repo(name: 'price-reader-v2', host: 'GL', worktrees: [
      Worktree(branch: 'main', note: 'clean', tone: WorktreeTone.idle, path: '~/dev/price-reader-v2', sync: '↓1 behind', agent: 'No agent', changes: 'clean'),
      Worktree(branch: 'perf/cache-warmup', note: 'MR !231 · ready', tone: WorktreeTone.ok, path: '~/wt/price-reader-v2/cache', sync: 'up to date', agent: 'Done · MR !231', changes: 'clean'),
    ]),
    Repo(name: 'users-permissions', host: 'BB', worktrees: [
      Worktree(branch: 'main', note: 'clean', tone: WorktreeTone.idle, path: '~/dev/users-permissions', sync: 'up to date', agent: 'No agent', changes: 'clean'),
      Worktree(branch: 'feat/audit-log', note: 'Gemini · running', tone: WorktreeTone.running, path: '~/wt/users-permissions/audit', sync: 'local only', agent: 'Gemini · running', changes: 'no changes', everPushed: false),
    ]),
  ];

  /// Everything the "Repositories in namespace" picker can offer: the three
  /// repos above plus others detected on the hosts or on disk.
  static const candidates = <RepoCandidate>[
    RepoCandidate(host: 'GH', fullName: 'pricing/price-admin', meta: '~/dev/price-admin · 3 worktrees', cloned: true, repo: _priceAdmin),
    RepoCandidate(host: 'GL', fullName: 'pricing/price-reader-v2', meta: '~/dev/price-reader-v2 · 2 worktrees', cloned: true, repo: _priceReader),
    RepoCandidate(host: 'GH', fullName: 'pricing/price-events-consumer', meta: 'Not cloned yet', cloned: false, repo: Repo(name: 'price-events-consumer', host: 'GH', worktrees: [
      Worktree(branch: 'main', note: 'cloning…', tone: WorktreeTone.running, path: '~/dev/price-events-consumer', sync: 'cloning', agent: 'No agent', changes: 'clean'),
    ])),
    RepoCandidate(host: 'BB', fullName: 'identity/users-permissions', meta: '~/dev/users-permissions · 2 worktrees', cloned: true, repo: _usersPermissions),
    RepoCandidate(host: 'GH', fullName: 'catalog/catalog-api', meta: '~/dev/catalog-api · 1 worktree', cloned: true, repo: Repo(name: 'catalog-api', host: 'GH', worktrees: [
      Worktree(branch: 'main', note: 'clean', tone: WorktreeTone.idle, path: '~/dev/catalog-api', sync: 'up to date', agent: 'No agent', changes: 'clean'),
    ])),
    RepoCandidate(host: 'GL', fullName: 'platform/infra-k8s', meta: 'Not cloned yet', cloned: false, repo: Repo(name: 'infra-k8s', host: 'GL', worktrees: [
      Worktree(branch: 'main', note: 'cloning…', tone: WorktreeTone.running, path: '~/dev/infra-k8s', sync: 'cloning', agent: 'No agent', changes: 'clean'),
    ])),
    RepoCandidate(host: 'LO', fullName: '~/workspace/kumo', meta: 'Local folder · no remote', cloned: true, repo: Repo(name: 'kumo', host: 'LO', worktrees: [
      Worktree(branch: 'main', note: 'local only', tone: WorktreeTone.idle, path: '~/workspace/kumo', sync: 'local only', agent: 'No agent', changes: 'clean', everPushed: false),
    ])),
  ];

  static const _priceAdmin = Repo(name: 'price-admin', host: 'GH', worktrees: []);
  static const _priceReader = Repo(name: 'price-reader-v2', host: 'GL', worktrees: []);
  static const _usersPermissions = Repo(name: 'users-permissions', host: 'BB', worktrees: []);

  /// Full repo (with worktrees) by name, across [repos] and [candidates].
  static Repo? repoNamed(String name) {
    for (final r in repos) {
      if (r.name == name) return r;
    }
    for (final c in candidates) {
      if (c.repo.name == name) return c.repo;
    }
    return null;
  }

  static const initialNamespaces = <Namespace>[
    Namespace(id: 'pricing', name: 'pricing', repos: ['price-admin', 'price-reader-v2']),
    Namespace(id: 'identity', name: 'identity', repos: ['users-permissions']),
  ];

  static const hostNames = {'GH': 'GitHub', 'GL': 'GitLab', 'BB': 'Bitbucket', 'LO': 'Local'};
  static const ciNames = {'GH': 'GitHub Actions', 'GL': 'GitLab CI', 'BB': 'Bitbucket Pipelines'};

  /// Repo that owns a worktree branch (branches are unique in the mock).
  static Repo repoOf(String branch, {String? path}) {
    for (final r in repos) {
      for (final w in r.worktrees) {
        if (path != null ? w.path == path : w.branch == branch) return r;
      }
    }
    return repos.first;
  }

  static const integrations = <Integration>[
    Integration('GH', 'GitHub'),
    Integration('GL', 'GitLab'),
    Integration('BB', 'Bitbucket'),
    Integration('JI', 'Jira'),
    Integration('TR', 'Trello'),
    Integration('CU', 'ClickUp'),
    Integration('TD', 'Todoist'),
    Integration('CF', 'Confluence'),
    Integration('NO', 'Notion'),
    Integration('OB', 'Obsidian'),
  ];

  static const agents = <AgentSession>[
    AgentSession(
      id: 'a1', agent: 'Claude Code', k: 'CC', mode: 'auto-approve edits', status: AgentStatus.running,
      title: 'Bulk discounts by category', src: 'JI', key: 'PRC-412', srcName: 'Jira',
      where: 'price-admin · feat/PRC-412-bulk-discounts', whereIsDoc: false, step: 3, stepLabel: 'Implement · step 3 of 4',
      last: 'Edit internal/kafka/bulk_consumer.go', meta: '4 files · +146 −12', time: '12m',
    ),
    AgentSession(
      id: 'a2', agent: 'Codex', k: 'CX', mode: 'ask before shell', status: AgentStatus.needsYou,
      title: 'Rounding error on installment prices', src: 'JI', key: 'PRC-398', srcName: 'Jira',
      where: 'price-admin · fix/PRC-398-rounding', whereIsDoc: false, step: 3, stepLabel: 'Test · step 3 of 4',
      last: 'Waiting: migration on staging', meta: '2 files · +18 −9', time: '7m', approvalCommand: 'make migrate-up ENV=staging',
    ),
    AgentSession(
      id: 'a3', agent: 'Gemini CLI', k: 'GM', mode: 'read-only until plan approved', status: AgentStatus.running,
      title: 'Audit log for permission changes', src: 'CU', key: 'CU-2291', srcName: 'ClickUp',
      where: 'users-permissions · feat/audit-log', whereIsDoc: false, step: 1, stepLabel: 'Plan · step 1 of 4',
      last: 'Read internal/authz/policy.go', meta: 'no changes yet', time: '3m',
    ),
    AgentSession(
      id: 'a4', agent: 'Claude Code', k: 'CC', mode: 'auto-approve edits', status: AgentStatus.done,
      title: 'Warm cache on deploy', src: 'JI', key: 'PRC-405', srcName: 'Jira',
      where: 'price-reader-v2 · perf/cache-warmup', whereIsDoc: false, step: 4, stepLabel: 'Merge request !231 opened',
      last: 'Pipeline passed · 12 of 12 jobs', meta: '3 files · +64 −11', time: '38m',
    ),
    AgentSession(
      id: 'a5', agent: 'Claude Code', k: 'CC', mode: 'docs only', status: AgentStatus.done,
      title: 'Update pricing on-call runbook', src: 'TD', key: 'Todoist', srcName: 'Inbox',
      where: 'Notion › On-call › Pricing runbook', whereIsDoc: true, step: 4, stepLabel: 'Page updated · 2 sections',
      last: 'Published to Notion', meta: '1 page', time: '9m',
    ),
  ];

  static const activity = <ActivityEvent>[
    ActivityEvent('Edited internal/discount/repository.go', '14:05', 'Claude · PRC-412', WorktreeTone.running),
    ActivityEvent('Opened MR !231 on GitLab', '13:58', 'Claude · PRC-405', WorktreeTone.ok),
    ActivityEvent('Pipeline passed, 12 of 12 jobs', '13:57', 'GitLab CI', WorktreeTone.ok),
    ActivityEvent('Started from ClickUp CU-2291', '13:56', 'Gemini CLI', WorktreeTone.running),
    ActivityEvent('Created worktree fix/PRC-398-rounding', '13:51', 'Codex', WorktreeTone.idle),
    ActivityEvent('Updated Notion page Pricing runbook', '13:44', 'Claude · Todoist', WorktreeTone.ok),
  ];

  static const tasks = <TaskItem>[
    TaskItem(col: TaskColumn.todo, src: 'JI', key: 'PRC-421', title: 'Expose price history in admin API', prio: 'High', meta: 'Sprint 44 · 5 pts'),
    TaskItem(col: TaskColumn.todo, src: 'CU', key: 'CU-2302', title: 'Role templates for store managers', prio: 'Med', meta: 'users-permissions'),
    TaskItem(col: TaskColumn.todo, src: 'TR', key: 'Marketing', title: 'Review Q4 discount banner copy', prio: 'Low', meta: 'due Fri'),
    TaskItem(col: TaskColumn.todo, src: 'TD', key: 'Inbox', title: 'Rotate staging Kafka credentials', prio: 'High', meta: 'due today'),
    TaskItem(col: TaskColumn.doing, src: 'JI', key: 'PRC-412', title: 'Bulk discounts by category', prio: 'High', meta: 'Sprint 44 · 8 pts', agent: 'Claude · running', branch: 'feat/PRC-412-bulk-discounts'),
    TaskItem(col: TaskColumn.doing, src: 'JI', key: 'PRC-398', title: 'Rounding error on installment prices', prio: 'High', meta: 'Bug · Sprint 44', agent: 'Codex · needs you', agentNeedsYou: true, branch: 'fix/PRC-398-rounding'),
    TaskItem(col: TaskColumn.doing, src: 'CU', key: 'CU-2291', title: 'Audit log for permission changes', prio: 'Med', meta: 'users-permissions', agent: 'Gemini · planning', branch: 'feat/audit-log'),
    TaskItem(col: TaskColumn.review, src: 'JI', key: 'PRC-405', title: 'Warm cache on deploy', prio: 'Med', meta: 'MR !231 · pipeline passed'),
    TaskItem(col: TaskColumn.review, src: 'TR', key: 'Pricing', title: 'Discount banner rules for campaigns', prio: 'Low', meta: 'waiting on marketing'),
    TaskItem(col: TaskColumn.done, src: 'TD', key: 'Inbox', title: 'Update pricing on-call runbook', prio: 'Low', meta: 'done by Claude · Notion'),
    TaskItem(col: TaskColumn.done, src: 'JI', key: 'PRC-377', title: 'Fix currency rounding in exports', prio: 'Med', meta: 'PR #518 merged'),
    TaskItem(col: TaskColumn.done, src: 'JI', key: 'PRC-370', title: 'Remove legacy v1 price endpoints', prio: 'Low', meta: 'PR #509 merged'),
  ];

  static const prs = <PullRequest>[
    PullRequest(host: 'GH', repo: 'price-admin', branch: 'feat/PRC-412-bulk-discounts', number: '#521', title: 'feat: bulk discounts by category', state: PrState.draft, note: 'Claude pushing'),
    PullRequest(host: 'GH', repo: 'price-admin', branch: 'chore/pgx-v5.7', number: '#519', title: 'chore: bump pgx to v5.7', state: PrState.reviewRequested, note: 'from Lucía'),
    PullRequest(host: 'GH', repo: 'price-admin', branch: 'fix/PRC-377-export-rounding', number: '#518', title: 'fix: currency rounding in exports', state: PrState.merged, note: '2h ago'),
    PullRequest(host: 'GH', repo: 'price-admin', branch: 'refactor/remove-v1', number: '#509', title: 'refactor: remove v1 price endpoints', state: PrState.merged, note: '2d ago'),
    PullRequest(host: 'GL', repo: 'price-reader-v2', branch: 'perf/cache-warmup', number: '!231', title: 'perf: warm cache on deploy', state: PrState.ready, note: 'pipeline passed'),
    PullRequest(host: 'GL', repo: 'price-reader-v2', branch: 'fix/stale-cache-ttl', number: '!228', title: 'fix: stale cache TTL on SKU updates', state: PrState.merged, note: '1d ago'),
    PullRequest(host: 'BB', repo: 'users-permissions', branch: 'feat/role-templates', number: '#64', title: 'feat: role templates', state: PrState.changesRequested, note: '2 comments'),
    PullRequest(host: 'BB', repo: 'users-permissions', branch: 'fix/scope-cache', number: '#61', title: 'fix: invalidate scope cache on role change', state: PrState.merged, note: '3d ago'),
  ];

  /// Latest pipeline run per worktree path. Branches that were never pushed
  /// have none.
  static const runs = <String, PipelineRun>{
    '~/wt/price-admin/PRC-412': PipelineRun(
      id: 'run #8812 · 4e1b2c0',
      commit: 'feat: BulkDiscount aggregate · pushed 9 min ago',
      status: RunStatus.running,
      checks: [
        ('build', '1m 12s', CheckState.ok),
        ('unit tests', '2m 40s', CheckState.ok),
        ('golangci-lint', '48s', CheckState.ok),
        ('integration · testcontainers', 'running', CheckState.running),
        ('deploy to staging', 'waiting', CheckState.waiting),
      ],
    ),
    '~/dev/price-admin': PipelineRun(
      id: 'run #8790 · 9d02e1f',
      commit: 'Merge #518 currency rounding in exports · 2h ago',
      status: RunStatus.passed,
      checks: [
        ('build', '1m 08s', CheckState.ok),
        ('unit tests', '2m 31s', CheckState.ok),
        ('golangci-lint', '45s', CheckState.ok),
        ('integration · testcontainers', '3m 58s', CheckState.ok),
        ('deploy to staging', '1m 27s', CheckState.ok),
      ],
    ),
    '~/wt/price-reader-v2/cache': PipelineRun(
      id: 'pipeline #4417 · a81c3d2',
      commit: 'perf: warm cache on deploy · 38 min ago',
      status: RunStatus.passed,
      checks: [
        ('build', '1m 12s', CheckState.ok),
        ('unit tests', '2m 40s', CheckState.ok),
        ('golangci-lint', '48s', CheckState.ok),
        ('integration · testcontainers', '4m 05s', CheckState.ok),
        ('deploy to staging', '1m 31s', CheckState.ok),
      ],
    ),
    '~/dev/price-reader-v2': PipelineRun(
      id: 'pipeline #4402 · 77be019',
      commit: 'Merge !228 stale cache TTL · 1d ago',
      status: RunStatus.passed,
      checks: [
        ('build', '1m 10s', CheckState.ok),
        ('unit tests', '2m 22s', CheckState.ok),
        ('golangci-lint', '51s', CheckState.ok),
      ],
    ),
  };
}
