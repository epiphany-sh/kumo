import 'package:flutter/material.dart';

import '../platform/open_url.dart';

/// Opens a link found in a document, which anyone may have written. Web pages
/// open; a link into another app (Obsidian, Bear, Todoist) can make that app
/// act, so it asks first.
Future<bool> openDocumentLink(BuildContext context, String url) async {
  final scheme = Uri.tryParse(url)?.scheme;
  if (scheme == 'http' || scheme == 'https') return openUrl(url);
  if (!isOpenable(url)) return false;
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Open this link in another app?'),
      content: SelectableText(url),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Open')),
      ],
    ),
  );
  return yes == true && await openUrl(url);
}
