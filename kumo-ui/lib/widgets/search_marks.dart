import 'package:flutter/widgets.dart';

import '../theme/palette.dart';

/// The words of a search box, lower case.
List<String> searchWords(String query) => query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// [text] with every searched word marked (the pickers' lists).
Widget markedText(KumoPalette c, String text, List<String> words, TextStyle base, {int maxLines = 1}) {
  if (words.isEmpty) return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: base);
  final lower = text.toLowerCase();
  final marks = List<bool>.filled(text.length, false);
  for (final w in words) {
    var from = 0;
    while (true) {
      final at = lower.indexOf(w, from);
      if (at < 0) break;
      for (var i = at; i < at + w.length && i < text.length; i++) {
        marks[i] = true;
      }
      from = at + w.length;
    }
  }
  final spans = <TextSpan>[];
  var i = 0;
  while (i < text.length) {
    final on = marks[i];
    var j = i;
    while (j < text.length && marks[j] == on) {
      j++;
    }
    spans.add(TextSpan(text: text.substring(i, j), style: on ? base.copyWith(color: c.acc, backgroundColor: c.accSoft) : base));
    i = j;
  }
  return Text.rich(TextSpan(children: spans), maxLines: maxLines, overflow: TextOverflow.ellipsis);
}
