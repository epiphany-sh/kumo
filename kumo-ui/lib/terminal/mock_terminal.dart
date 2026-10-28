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
