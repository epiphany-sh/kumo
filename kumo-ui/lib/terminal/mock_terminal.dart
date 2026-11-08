import 'dart:async';

import 'package:flutter/foundation.dart';

import 'terminal_surface.dart';

/// Scripted terminal for the UI mock. Optionally "streams" [script] lines one
/// by one so the painter path is exercised like a real session.
class MockTerminalSurface implements TerminalSurface {
  MockTerminalSurface({
    required this.title,
    required this.cwd,
    required List<TermLine> initial,
    List<TermLine> script = const [],
    Duration interval = const Duration(milliseconds: 1400),
    this.loop = false,
  })  : _buffer = ValueNotifier(TermBuffer(initial)),
        _initial = initial,
        _script = script {
    if (script.isNotEmpty) _timer = Timer.periodic(interval, (_) => _tick());
  }

  @override
  final String title;
  @override
  final String cwd;
  final bool loop;

  final ValueNotifier<TermBuffer> _buffer;
  final List<TermLine> _initial;
  final List<TermLine> _script;
  Timer? _timer;
  int _next = 0;
  int cols = 0;
  int rows = 0;

  @override
  ValueListenable<TermBuffer> get buffer => _buffer;

  void _tick() {
    if (_next >= _script.length) {
      if (!loop) {
        _timer?.cancel();
        return;
      }
      _next = 0;
      _buffer.value = TermBuffer(_initial, seq: _buffer.value.seq + 1);
    }
    _buffer.value = _buffer.value.append([_script[_next++]]);
  }

  @override
  void sendText(String text) {
    if (text.trim().isEmpty) return;
    _buffer.value = _buffer.value.append([
      TermLine.of([('› you  ', TermRole.purple), (text, TermRole.text)]),
    ]);
  }

  @override
  bool get interactive => false;

  @override
  void sendBytes(List<int> bytes) {}

  @override
  void resize(int cols, int rows) {
    this.cols = cols;
    this.rows = rows;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _buffer.dispose();
  }
}

/// The sessions shown in the Terminal view.
abstract final class MockSessions {
  /// A fresh shell opened with + / ⌘D / ⌘⇧D. [n] = 1 is "zsh", then "zsh 2"…
  static MockTerminalSurface shell(int n) => MockTerminalSurface(
        title: n == 1 ? 'zsh' : 'zsh $n',
        cwd: '~/wt/price-admin/PRC-412',
        initial: [
          TermLine.of([('~/wt/price-admin/PRC-412 ', TermRole.cyan), ('on ', TermRole.text3), ('feat/PRC-412-bulk-discounts', TermRole.ok)]),
        ],
      );

  /// A shell in Home: the home folder, no repository.
  static MockTerminalSurface homeShell(int n) => MockTerminalSurface(
        title: n == 1 ? 'zsh' : 'zsh $n',
        cwd: '~',
        initial: [
          TermLine.of([('Last login: Wed Oct 28 14:58 on ttys004', TermRole.text3)]),
          TermLine.of([('~ ', TermRole.cyan), ('❯', TermRole.text3)]),
        ],
      );

  static MockTerminalSurface agent() => MockTerminalSurface(
        title: 'Claude Code',
        cwd: '~/wt/price-admin/PRC-412',
        loop: true,
        initial: [
          TermLine.of([('❯ ', TermRole.acc), ('kumo agent run ', TermRole.text), ('--ticket ', TermRole.text3), ('PRC-412 ', TermRole.purple), ('--agent ', TermRole.text3), ('claude', TermRole.text)]),
          TermLine.of([('  worktree ', TermRole.text3), ('~/wt/price-admin/PRC-412', TermRole.cyan), ('  branch ', TermRole.text3), ('feat/PRC-412-bulk-discounts', TermRole.ok)]),
          TermLine.empty,
          TermLine.of([('● ', TermRole.acc), ('Read  ', TermRole.text), ('internal/discount/service.go', TermRole.text2)]),
          TermLine.of([('● ', TermRole.acc), ('Read  ', TermRole.text), ('internal/discount/repository.go', TermRole.text2)]),
          TermLine.of([('● ', TermRole.acc), ('Read  ', TermRole.text), ('Confluence › Pricing › Discount rules v3', TermRole.text2)]),
          TermLine.empty,
          TermLine.of([('◆ Plan', TermRole.purple)], bold: true),
          TermLine.of([('  1  ', TermRole.text3), ('BulkDiscount aggregate + validation', TermRole.text)]),
          TermLine.of([('  2  ', TermRole.text3), ('Kafka consumer ', TermRole.text), ('price.discounts.bulk.v1', TermRole.yellow)]),
          TermLine.of([('  3  ', TermRole.text3), ('Batch upsert with pgx CopyFrom', TermRole.text)]),
          TermLine.of([('  4  ', TermRole.text3), ('Table tests + testcontainers', TermRole.text)]),
          TermLine.empty,
        ],
        script: [
          TermLine.of([('✓ ', TermRole.ok), ('Edit  ', TermRole.text), ('internal/discount/bulk.go', TermRole.text2), ('  +84', TermRole.ok), (' −0', TermRole.err)]),
          TermLine.of([('✓ ', TermRole.ok), ('Edit  ', TermRole.text), ('internal/discount/repository.go', TermRole.text2), ('  +31', TermRole.ok), (' −6', TermRole.err)]),
          TermLine.of([('✓ ', TermRole.ok), ('Run   ', TermRole.text), ('go test ./internal/discount/...', TermRole.text2)]),
          TermLine.of([('      ok  ', TermRole.ok), ('price-admin/internal/discount  0.412s', TermRole.text3)]),
          TermLine.of([('● ', TermRole.acc), ('Edit  ', TermRole.text), ('internal/kafka/bulk_consumer.go', TermRole.text2), ('  writing…', TermRole.text3)]),
        ],
      );

  static MockTerminalSurface tests() => MockTerminalSurface(
        title: 'gotestsum',
        cwd: 'watch',
        initial: [
          TermLine.of([('PRC-412 ', TermRole.cyan), ('❯ ', TermRole.acc), ('gotestsum --watch ./...', TermRole.text)]),
          TermLine.of([('✓ ', TermRole.ok), ('internal/discount ', TermRole.text), ('412ms', TermRole.text3)]),
          TermLine.of([('✓ ', TermRole.ok), ('internal/http ', TermRole.text), ('1.21s', TermRole.text3)]),
          TermLine.of([('✓ ', TermRole.ok), ('internal/kafka ', TermRole.text), ('838ms', TermRole.text3)]),
          TermLine.of([('✓ ', TermRole.ok), ('internal/store/pg ', TermRole.text), ('2.04s', TermRole.text3)]),
          TermLine.empty,
          TermLine.of([('DONE ', TermRole.ok), ('148 tests in 3.1s', TermRole.text)]),
          TermLine.of([('watching for changes…', TermRole.text3)]),
        ],
      );

  static MockTerminalSurface logs() => MockTerminalSurface(
        title: 'k8s logs',
        cwd: 'gke-staging / pricing',
        loop: true,
        interval: const Duration(milliseconds: 900),
        initial: [
          TermLine.of([('❯ ', TermRole.acc), ('kubectl logs -f deploy/price-reader-v2', TermRole.text)]),
          TermLine.of([('14:02:11 ', TermRole.text3), ('INFO ', TermRole.ok), ('cache warm keys=18240 took=912ms', TermRole.text2)]),
          TermLine.of([('14:02:12 ', TermRole.text3), ('INFO ', TermRole.ok), ('consumer joined group=price-reader', TermRole.text2)]),
          TermLine.of([('14:02:19 ', TermRole.text3), ('WARN ', TermRole.warn), ('slow query table=prices p99=184ms', TermRole.text2)]),
        ],
        script: [
          TermLine.of([('14:02:24 ', TermRole.text3), ('INFO ', TermRole.ok), ('GET /v2/prices/sku 200 4.1ms', TermRole.text2)]),
          TermLine.of([('14:02:24 ', TermRole.text3), ('INFO ', TermRole.ok), ('GET /v2/prices/sku 200 3.8ms', TermRole.text2)]),
          TermLine.of([('14:02:31 ', TermRole.text3), ('INFO ', TermRole.ok), ('GET /v2/prices/batch 200 22ms', TermRole.text2)]),
          TermLine.of([('14:02:33 ', TermRole.text3), ('INFO ', TermRole.ok), ('GET /v2/prices/sku 200 4.4ms', TermRole.text2)]),
        ],
      );
}

/// Agents' terminals as the Agents view shows them in the design.
abstract final class MockAgentTerminals {
  static TermLine _l(List<(String, TermRole)> parts, {bool bold = false}) => TermLine.of(parts, bold: bold);

  /// Codex in fix/PRC-398, waiting for an approval.
  static MockTerminalSurface codex() => MockTerminalSurface(
        title: 'Codex',
        cwd: '~/wt/price-admin/PRC-398',
        initial: [
          _l([('>_ ', TermRole.acc), ('Codex', TermRole.text), ('  · ask before shell', TermRole.text3)], bold: true),
          _l([('> ', TermRole.text3), ('Fix PRC-398: installment prices round wrong for 18 cuotas.', TermRole.text2)]),
          TermLine.empty,
          _l([('• ', TermRole.text), ('Found it: Installment() divides before rounding, so 18 cuotas lose a cent each.', TermRole.text)]),
          _l([('• ', TermRole.ok), ('Edited ', TermRole.text), ('internal/price/installments.go', TermRole.text2), (' (+9 −6)', TermRole.text3)]),
          _l([('• ', TermRole.ok), ('Ran ', TermRole.text), ('go test ./internal/price/...', TermRole.text2)]),
          _l([('  └ ', TermRole.text3), ('ok  price-admin/internal/price  0.41s  (14 tests)', TermRole.text3)]),
          _l([('• ', TermRole.text), ('The integration test needs the new column on staging.', TermRole.text)]),
          TermLine.empty,
          _l([('▌ ', TermRole.warn), ('Allow command?  ', TermRole.warn), ('make migrate-up ENV=staging', TermRole.text)], bold: true),
          _l([('  y ', TermRole.text), ('yes, once   ', TermRole.text3), ('a ', TermRole.text), ('always, this session   ', TermRole.text3), ('n ', TermRole.text), ('no, and tell Codex what to do', TermRole.text3)]),
        ],
      );

  /// Gemini planning the audit log.
  static MockTerminalSurface gemini() => MockTerminalSurface(
        title: 'Gemini CLI',
        cwd: '~/wt/users-permissions/audit',
        loop: true,
        initial: [
          _l([('✦ ', TermRole.purple), ('Gemini CLI', TermRole.text), ('  · read-only until the plan is approved', TermRole.text3)], bold: true),
          _l([('> ', TermRole.text3), ('Plan CU-2291: an audit log for permission changes.', TermRole.text2)]),
          TermLine.empty,
          _l([('✦ ', TermRole.ok), ('ReadFile ', TermRole.text), ('internal/authz/policy.go', TermRole.text2)]),
          _l([('  └ ', TermRole.text3), ('Read 240 lines', TermRole.text3)]),
        ],
        script: [
          _l([('✦ ', TermRole.ok), ('SearchText ', TermRole.text), ('"func (s *Service) Grant" in internal/', TermRole.text2)]),
          _l([('  └ ', TermRole.text3), ('3 matches', TermRole.text3)]),
          _l([('⠋ ', TermRole.warn), ('Drafting the plan…', TermRole.warn)]),
        ],
      );

  /// A session that ended.
  static MockTerminalSurface finished(String title, String cwd, String prompt, List<String> said) => MockTerminalSurface(
        title: title,
        cwd: cwd,
        initial: [
          _l([('✻ ', TermRole.acc), (title, TermRole.text)], bold: true),
          _l([('> ', TermRole.text3), (prompt, TermRole.text2)]),
          TermLine.empty,
          for (final s in said) _l([('⏺ ', TermRole.text), (s, TermRole.text)]),
          TermLine.empty,
          _l([('✓ ', TermRole.ok), ('Done', TermRole.ok), (' · exit 0', TermRole.text3)]),
        ],
      );

  /// go-pr-reviewer reviewing PR #521.
  static MockTerminalSurface reviewer() => MockTerminalSurface(
        title: 'go-pr-reviewer',
        cwd: '~/wt/price-admin/PRC-412',
        initial: [
          _l([('✻ ', TermRole.acc), ('Claude Code', TermRole.text), ('  · agent go-pr-reviewer', TermRole.text3)], bold: true),
          _l([('  context ', TermRole.text3), ('~/.kumo/runs/go-pr-reviewer-2 · 3 items', TermRole.text3)]),
          _l([('> ', TermRole.text3), ('Review PR #521 against main. Point out code that already existed and could have been reused.', TermRole.text2)]),
          TermLine.empty,
          _l([('⏺ ', TermRole.text), ('I’ll read the PR’s diff first, then look for existing code for each new function.', TermRole.text)]),
          _l([('⏺ ', TermRole.ok), ('Read', TermRole.text), ('(~/.kumo/runs/go-pr-reviewer-2/pr-521.diff)', TermRole.text2)], bold: true),
          _l([('  ⎿ ', TermRole.text3), ('Read 412 lines', TermRole.text3)]),
          _l([('⏺ ', TermRole.ok), ('Grep', TermRole.text), ('(pattern: "func (\\w*Percent|round\\w*)", path: "internal/")', TermRole.text2)], bold: true),
          _l([('  ⎿ ', TermRole.text3), ('Found 3 matches', TermRole.text3)]),
        ],
        script: [
          _l([('⏺ ', TermRole.ok), ('Read', TermRole.text), ('(internal/money/round.go)', TermRole.text2)], bold: true),
          _l([('  ⎿ ', TermRole.text3), ('Read 40 lines', TermRole.text3)]),
          _l([('⏺ ', TermRole.text), ('Two so far: bulkPercent repeats applyPercent; roundCents repeats money.RoundCents.', TermRole.text)]),
          _l([('✻ ', TermRole.warn), ('Checking the repository layer…', TermRole.warn), (' (esc to interrupt)', TermRole.text3)]),
        ],
      );

  /// One of your agents, just started.
  static MockTerminalSurface started(String agent, String prompt) => MockTerminalSurface(
        title: agent,
        cwd: '~',
        initial: [
          _l([('✻ ', TermRole.acc), ('Claude Code', TermRole.text), ('  · agent $agent', TermRole.text3)], bold: true),
          if (prompt.isNotEmpty) _l([('> ', TermRole.text3), (prompt, TermRole.text2)]),
          TermLine.empty,
          _l([('✻ ', TermRole.warn), (prompt.isEmpty ? 'Ready: type its first message.' : 'Reading the context folder…', TermRole.warn)]),
        ],
      );
}
