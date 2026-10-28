import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/data/mock_project.dart';
import 'package:kumo_ui/editor/working_copy.dart';

void main() {
  test('every tree file has content', () {
    final paths = <String>[];
    void walk(List<TreeNode> nodes, String prefix) {
      for (final n in nodes) {
        final p = prefix.isEmpty ? n.name : '$prefix/${n.name}';
        n.isDir ? walk(n.children!, p) : paths.add(p);
      }
    }

    walk(MockProject.tree, '');
    for (final p in paths) {
      expect(MockProject.files.containsKey(p), isTrue, reason: p);
    }
  });

  test('a merge conflict blocks the commit until resolved', () {
    final wc = WorkingCopy();
    expect(wc.statusOf(MockProject.conflictPath), GitStatus.conflict);
    expect(wc.dirStatus('deploy'), GitStatus.conflict);
    expect(wc.canCommit, isFalse);
    expect(wc.commit(), isFalse);

    wc.resolve('current');
    expect(wc.statusOf(MockProject.conflictPath), GitStatus.modified);
    expect(wc.canCommit, isTrue);

    final staged = wc.stagedList.length;
    expect(wc.commit(), isTrue);
    expect(wc.lastCommitSize, staged);
    expect(wc.ahead, 3);
    expect(wc.stagedList, isEmpty);
    expect(wc.statusOf('internal/discount/repository.go'), isNull);
  });

  test('stage, unstage and restore', () {
    final wc = WorkingCopy(staged: {});
    expect(wc.untracked, contains('testdata/bulk_discount.json'));
    wc.stage('testdata/bulk_discount.json');
    expect(wc.untracked, isEmpty);
    expect(wc.stagedList, contains('testdata/bulk_discount.json'));
    wc.unstage('testdata/bulk_discount.json');
    expect(wc.stagedList, isEmpty);

    expect(wc.statusOf(MockProject.deletedPath), GitStatus.deleted);
    wc.restore();
    expect(wc.statusOf(MockProject.deletedPath), isNull);
  });

  test('resolveConflict keeps the chosen side', () {
    final text = MockProject.files[MockProject.conflictPath]!;
    expect(MockProject.hasConflictMarkers(text), isTrue);
    final current = MockProject.resolveConflict(text, 'current');
    final incoming = MockProject.resolveConflict(text, 'incoming');
    final both = MockProject.resolveConflict(text, 'both');
    expect(MockProject.hasConflictMarkers(current), isFalse);
    expect(current, contains('2026.10.27-prc412'));
    expect(current, isNot(contains('2026.10.24')));
    expect(incoming, contains('2026.10.24'));
    expect(incoming, isNot(contains('2026.10.27-prc412')));
    expect(both, allOf(contains('2026.10.24'), contains('2026.10.27-prc412')));
  });
}
