import 'package:flutter/material.dart';

import 'syntax.dart';
import '../theme/palette.dart';

/// Diff-only palette: soft add/delete row tints plus syntax colors picked to
/// keep contrast on top of them (shared by the Git view and file tabs).
class DiffColors {
  const DiffColors({
    required this.add,
    required this.del,
    required this.kw,
    required this.str,
    required this.num,
    required this.type,
    required this.fn,
    required this.com,
    required this.punct,
    required this.text,
  });

  final Color add;
  final Color del;
  final Color kw;
  final Color str;
  final Color num;
  final Color type;
  final Color fn;
  final Color com;
  final Color punct;
  final Color text;

  static const light = DiffColors(
    add: Color(0x21137A43), // 13%
    del: Color(0x1AB42318), // 10%
    kw: Color(0xFF5B21B6),
    str: Color(0xFF92400E),
    num: Color(0xFFB4370A),
    type: Color(0xFFA21CAF),
    fn: Color(0xFF1D4ED8),
    com: Color(0xFF475569),
    punct: Color(0xFF334155),
    text: Color(0xFF0F1014),
  );

  static const dark = DiffColors(
    add: Color(0x1F5EE09A), // 12%
    del: Color(0x1FFF8A8A), // 12%
    kw: Color(0xFFD8B4FE),
    str: Color(0xFFFCD34D),
    num: Color(0xFFFDBA74),
    type: Color(0xFFF0ABFC),
    fn: Color(0xFF93C5FD),
    com: Color(0xFF9AA3B5),
    punct: Color(0xFFCBD5E1),
    text: Color(0xFFFFFFFF),
  );

  static DiffColors of(KumoPalette c) => c.isDark ? dark : light;

  TextStyle styleFor(Tok t) => switch (t) {
        Tok.kw => TextStyle(color: kw, fontWeight: FontWeight.w600),
        Tok.str => TextStyle(color: str),
        Tok.num => TextStyle(color: num),
        Tok.type => TextStyle(color: type),
        Tok.fn => TextStyle(color: fn, fontWeight: FontWeight.w500),
        Tok.com => TextStyle(color: com, fontStyle: FontStyle.italic),
        Tok.punct => TextStyle(color: punct),
        Tok.key => TextStyle(color: fn),
        Tok.head => TextStyle(color: kw, fontWeight: FontWeight.w600),
        Tok.text => TextStyle(color: text),
      };
}
