import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/platform/open_url.dart';
import 'package:kumo_ui/widgets/open_link.dart';

void main() {
  test('only known schemes can be opened', () {
    for (final url in ['https://a.example', 'http://a.example', 'obsidian://open?vault=v', 'bear://x', 'todoist://y']) {
      expect(isOpenable(url), isTrue, reason: url);
    }
    for (final url in ['file:///etc/passwd', 'javascript:x', 'ssh://a', 'relative/path']) {
      expect(isOpenable(url), isFalse, reason: url);
    }
  });

  testWidgets('a link into another app asks first, and Cancel opens nothing', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      context = c;
      return const SizedBox();
    })));
    final opened = openDocumentLink(context, 'obsidian://open?vault=v');
    await tester.pumpAndSettle();
    expect(find.text('Open this link in another app?'), findsOneWidget);
    expect(find.text('obsidian://open?vault=v'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await opened, isFalse);
  });
}
