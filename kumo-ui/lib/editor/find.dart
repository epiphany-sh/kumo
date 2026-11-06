import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/kicons.dart';
import 'code_editor.dart';

// ---- Search (pure) ----

/// What to look for in a file, and how.
@immutable
class FindQuery {
  const FindQuery(this.text, {this.caseSensitive = false, this.wholeWord = false, this.regex = false});
  final String text;
  final bool caseSensitive;
  final bool wholeWord;
  final bool regex;
}

/// The matches of a search, or why it couldn't run.
@immutable
class FindResult {
  const FindResult(this.matches, {this.error, this.capped = false});
  final List<TextRange> matches;

  /// The regular expression doesn't parse.
  final String? error;

  /// There were more than the limit: only the first ones are here.
  final bool capped;

  static const none = FindResult([]);
}

/// Letters, digits and `_`: what a whole word is made of.
const _wordChar = r'[\p{L}\p{N}_]';

/// The pattern [q] searches with; throws [FormatException] for a bad regex.
RegExp findPattern(FindQuery q) {
  var p = q.regex ? q.text : RegExp.escape(q.text);
  if (q.wholeWord) p = '(?<!$_wordChar)(?:$p)(?!$_wordChar)';
  return RegExp(p, caseSensitive: q.caseSensitive, multiLine: true, unicode: true);
}

/// Every match of [q] in [text], in order; empty matches (a regex like
/// `x*`) are skipped. Stops after [limit].
FindResult findMatches(String text, FindQuery q, {int limit = 10000}) {
  if (q.text.isEmpty) return FindResult.none;
  final RegExp re;
  try {
    re = findPattern(q);
  } on FormatException catch (e) {
    return FindResult(const [], error: e.message);
  }
  final out = <TextRange>[];
  for (final m in re.allMatches(text)) {
    if (m.end == m.start) continue;
    if (out.length == limit) return FindResult(out, capped: true);
    out.add(TextRange(start: m.start, end: m.end));
  }
  return FindResult(out);
}

/// What replaces [m]: with a regex, `$1`…`$99` and `$&` are its groups and
/// `$$` a dollar; otherwise [replacement] as it is.
String expandReplacement(Match m, String replacement, {required bool regex}) {
  if (!regex) return replacement;
  return replacement.replaceAllMapped(RegExp(r'\$(\$|&|\d{1,2})'), (r) {
    final g = r.group(1)!;
    if (g == r'$') return r'$';
    if (g == '&') return m.group(0) ?? '';
    final i = int.parse(g);
    return i <= m.groupCount ? (m.group(i) ?? '') : r.group(0)!;
  });
}

/// [text] with the match at [range] replaced, and where the replacement
/// ends.
(String, int) replaceMatch(String text, TextRange range, FindQuery q, String replacement) {
  final m = findPattern(q).matchAsPrefix(text, range.start);
  final with_ = m == null || m.end != range.end ? replacement : expandReplacement(m, replacement, regex: q.regex);
  return (text.replaceRange(range.start, range.end, with_), range.start + with_.length);
}

/// [text] with every match of [q] replaced, and how many there were.
(String, int) replaceAllMatches(String text, FindQuery q, String replacement) {
  if (q.text.isEmpty) return (text, 0);
  final RegExp re;
  try {
    re = findPattern(q);
  } on FormatException {
    return (text, 0);
  }
  var n = 0;
  final out = text.replaceAllMapped(re, (m) {
    if (m.end == m.start) return '';
    n++;
    return expandReplacement(m, replacement, regex: q.regex);
  });
  return (out, n);
}

// ---- State ----

/// Find and replace in one editor: the query and its options, the matches
/// (painted in the editor) and which one is current. Lives as long as the
/// view that shows it; [attach] moves it to another file's editor.
class EditorFind extends ChangeNotifier {
  EditorFind() {
    query.addListener(_onQuery);
  }

  /// The last thing searched for, so ⌘F in another file starts with it.
  static String lastQuery = '';

  final query = TextEditingController();
  final replacement = TextEditingController();
  final queryFocus = FocusNode(debugLabel: 'find');
  final replaceFocus = FocusNode(debugLabel: 'replace');

  bool visible = false;
  bool replacing = false;
  bool caseSensitive = false;
  bool wholeWord = false;
  bool regex = false;

  /// The file can't be changed: replacing is off.
  bool readOnly = false;

  FindResult result = FindResult.none;
  List<TextRange> get matches => result.matches;
  int current = -1;

  CodeController? _ctrl;
  String? _searchedText;
  String _searchedQuery = '';

  FindQuery get _q => FindQuery(query.text, caseSensitive: caseSensitive, wholeWord: wholeWord, regex: regex);

  /// Searches [ctrl]'s text from now on (null: none).
  void attach(CodeController? ctrl) {
    if (identical(ctrl, _ctrl)) return;
    _ctrl?.removeListener(_onText);
    _ctrl?.setHighlights(const [], -1);
    _ctrl = ctrl;
    ctrl?.addListener(_onText);
    _searchedText = null;
    if (visible) _search(reveal: false);
  }

  /// ⌘F (or ⌥⌘F with [replace]): shows the bar with the selected text, or
  /// the last query, and puts the cursor in it.
  void open({bool replace = false}) {
    final ctrl = _ctrl;
    final sel = ctrl?.selection;
    if (ctrl != null && sel != null && sel.isValid && !sel.isCollapsed) {
      final picked = sel.textInside(ctrl.text);
      if (picked.isNotEmpty && !picked.contains('\n')) query.text = regex ? RegExp.escape(picked) : picked;
    } else if (query.text.isEmpty && lastQuery.isNotEmpty) {
      query.text = lastQuery;
    }
    query.selection = TextSelection(baseOffset: 0, extentOffset: query.text.length);
    visible = true;
    if (replace && !readOnly) replacing = true;
    _search();
    notifyListeners();
    _focusLater(replace && !readOnly && query.text.isNotEmpty ? replaceFocus : queryFocus);
  }

  void _focusLater(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (node.context != null) node.requestFocus();
    });
  }

  void close() {
    if (!visible) return;
    visible = false;
    replacing = false;
    _ctrl?.setHighlights(const [], -1);
    notifyListeners();
  }

  void toggleReplace() {
    replacing = !replacing && !readOnly;
    notifyListeners();
    _focusLater(replacing ? replaceFocus : queryFocus);
  }

  void toggleCase() => _option(() => caseSensitive = !caseSensitive);
  void toggleWord() => _option(() => wholeWord = !wholeWord);
  void toggleRegex() => _option(() => regex = !regex);

  void _option(VoidCallback change) {
    change();
    _search();
    notifyListeners();
    _keepFocus(queryFocus);
  }

  /// After a click on one of the bar's buttons, the focus goes back to its
  /// field (a click takes it away on desktop): ↵ and Esc keep working.
  void _keepFocus(FocusNode field) {
    if (!replaceFocus.hasFocus && !queryFocus.hasFocus) _focusLater(field);
  }

  /// The bar's buttons: the same as their keys, then back to the field.
  void clickNext() {
    next();
    _keepFocus(queryFocus);
  }

  void clickPrevious() {
    previous();
    _keepFocus(queryFocus);
  }

  void clickReplace() {
    replaceOne();
    _keepFocus(replaceFocus);
  }

  void clickReplaceAll() {
    replaceAll();
    _keepFocus(replaceFocus);
  }

  void _onQuery() {
    if (query.text == _searchedQuery) return;
    lastQuery = query.text;
    if (visible) {
      _search();
      notifyListeners();
    }
  }

  void _onText() {
    final ctrl = _ctrl;
    if (!visible || ctrl == null || ctrl.text == _searchedText) return;
    // Typed in the editor: the matches move; the current one stays where
    // the caret is.
    _search(reveal: false);
    notifyListeners();
  }

  /// Runs the search; the current match is the first at or after the
  /// selection (where ⌘F was pressed, or the last match picked).
  void _search({bool reveal = true}) {
    final ctrl = _ctrl;
    _searchedQuery = query.text;
    if (ctrl == null) {
      result = FindResult.none;
      current = -1;
      return;
    }
    _searchedText = ctrl.text;
    result = findMatches(ctrl.text, _q);
    final from = ctrl.selection.isValid ? ctrl.selection.start : 0;
    final i = matches.indexWhere((m) => m.start >= from);
    current = matches.isEmpty ? -1 : (i < 0 ? 0 : i);
    if (reveal && current >= 0) {
      _select();
    } else {
      ctrl.setHighlights(matches, current);
    }
  }

  void next() => _step(1);
  void previous() => _step(-1);

  void _step(int delta) {
    if (!visible) {
      // ⌘G with the bar closed: search again for the last query.
      open();
      return;
    }
    if (matches.isEmpty) return;
    current = (current + delta + matches.length) % matches.length;
    _select();
    notifyListeners();
  }

  void _select() {
    final ctrl = _ctrl!;
    final m = matches[current];
    ctrl.selection = TextSelection(baseOffset: m.start, extentOffset: m.end);
    ctrl.setHighlights(matches, current);
    ctrl.reveal(m.start);
  }

  /// Replaces the current match and moves to the next one.
  void replaceOne() {
    final ctrl = _ctrl;
    if (ctrl == null || readOnly || matches.isEmpty) return;
    if (current < 0) current = 0;
    final (text, end) = replaceMatch(ctrl.text, matches[current], _q, replacement.text);
    ctrl.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: end));
    _search();
    notifyListeners();
  }

  /// Replaces every match; returns how many.
  int replaceAll() {
    final ctrl = _ctrl;
    if (ctrl == null || readOnly) return 0;
    final (text, n) = replaceAllMatches(ctrl.text, _q, replacement.text);
    if (n == 0) return 0;
    final caret = ctrl.selection.isValid ? ctrl.selection.start.clamp(0, text.length) : 0;
    ctrl.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: caret));
    _search(reveal: false);
    notifyListeners();
    return n;
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onText);
    _ctrl?.setHighlights(const [], -1);
    query.dispose();
    replacement.dispose();
    queryFocus.dispose();
    replaceFocus.dispose();
    super.dispose();
  }
}

// ---- Bar ----

/// The find (and replace) bar over the top right of an editor.
class FindBar extends StatelessWidget {
  const FindBar({super.key, required this.find, required this.onClose});
  final EditorFind find;

  /// Closes the bar and gives the editor its focus back.
  final VoidCallback onClose;

  static bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: find,
      builder: (context, _) {
        final c = context.c;
        final f = find;
        final n = f.matches.length;
        final status = f.result.error != null
            ? 'Invalid pattern'
            : f.query.text.isEmpty
                ? ''
                : (n == 0 ? 'No results' : '${f.current + 1} of $n${f.result.capped ? '+' : ''}');
        final statusColor = f.result.error != null || (n == 0 && f.query.text.isNotEmpty) ? c.err : c.text2;
        final mod = _mac ? '⌘' : 'Ctrl+';
        // Glass, like the app's other floating panels: the code under it
        // blurs instead of showing through the text.
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? 0.35 : 0.12), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 460,
                padding: const EdgeInsets.fromLTRB(4, 5, 6, 5),
                decoration: BoxDecoration(
                  color: c.pop,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: c.popBorder),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    height: 28,
                    child: f.readOnly
                        ? const SizedBox(width: 6)
                        : KIconButton(
                            icon: f.replacing ? KIcons.chevronDown : KIcons.chevronRight,
                            label: f.replacing ? 'Hide replace' : 'Replace (${_mac ? '⌥⌘F' : 'Ctrl+H'})',
                            size: 22,
                            iconSize: 15,
                            onTap: f.toggleReplace,
                          ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(
                          child: _Field(
                            key: const ValueKey('find-query'),
                            controller: f.query,
                            focusNode: f.queryFocus,
                            hint: 'Find',
                            error: f.result.error != null,
                            bindings: {
                              const SingleActivator(LogicalKeyboardKey.enter): f.next,
                              const SingleActivator(LogicalKeyboardKey.numpadEnter): f.next,
                              const SingleActivator(LogicalKeyboardKey.enter, shift: true): f.previous,
                              const SingleActivator(LogicalKeyboardKey.escape): onClose,
                            },
                            trailing: [
                              _Toggle(label: 'Aa', tooltip: 'Match case', on: f.caseSensitive, onTap: f.toggleCase),
                              _Toggle(label: 'ab', tooltip: 'Whole word', on: f.wholeWord, onTap: f.toggleWord, underline: true),
                              _Toggle(label: '.*', tooltip: 'Regular expression', on: f.regex, onTap: f.toggleRegex),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 74,
                          child: Tooltip(
                            message: f.result.error ?? '',
                            child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: statusColor)),
                          ),
                        ),
                        KIconButton(icon: KIcons.chevronUp, label: 'Previous match (⇧↵ · ⇧${mod}G)', size: 24, iconSize: 16, onTap: n == 0 ? null : f.clickPrevious),
                        KIconButton(icon: KIcons.chevronDown, label: 'Next match (↵ · ${mod}G)', size: 24, iconSize: 16, onTap: n == 0 ? null : f.clickNext),
                        KIconButton(icon: KIcons.close, label: 'Close (Esc)', size: 24, iconSize: 13, onTap: onClose),
                      ]),
                      if (f.replacing) ...[
                        const SizedBox(height: 5),
                        Row(children: [
                          Expanded(
                            child: _Field(
                              key: const ValueKey('find-replacement'),
                              controller: f.replacement,
                              focusNode: f.replaceFocus,
                              hint: f.regex ? r'Replace ($1 for a group)' : 'Replace',
                              bindings: {
                                const SingleActivator(LogicalKeyboardKey.enter): f.replaceOne,
                                const SingleActivator(LogicalKeyboardKey.numpadEnter): f.replaceOne,
                                SingleActivator(LogicalKeyboardKey.enter, meta: _mac, control: !_mac): f.replaceAll,
                                const SingleActivator(LogicalKeyboardKey.escape): onClose,
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          KButton(label: 'Replace', kind: KButtonKind.ghost, height: 26, fontSize: 11.5, onTap: n == 0 ? null : f.clickReplace),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: 'Replace all ($mod↵)',
                            child: KButton(label: 'All', kind: KButtonKind.ghost, height: 26, fontSize: 11.5, onTap: n == 0 ? null : f.clickReplaceAll),
                          ),
                        ]),
                      ],
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({super.key, required this.controller, required this.focusNode, required this.hint, required this.bindings, this.trailing = const [], this.error = false});
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final Map<ShortcutActivator, VoidCallback> bindings;
  final List<Widget> trailing;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CallbackShortcuts(
      bindings: bindings,
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) => Container(
          height: 28,
          padding: const EdgeInsets.only(left: 8, right: 3),
          decoration: BoxDecoration(
            color: c.chip,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: error ? c.err : (focusNode.hasFocus ? c.acc : c.chipBorder)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: mono(12, color: c.text),
                cursorColor: c.acc,
                // Enter is the bindings' (next match), not a submit.
                onSubmitted: (_) {},
                onEditingComplete: () {},
                decoration: InputDecoration.collapsed(hintText: hint, hintStyle: sans(12, color: c.text3)),
              ),
            ),
            ...trailing,
          ]),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.tooltip, required this.on, required this.onTap, this.underline = false});
  final String label;
  final String tooltip;
  final bool on;
  final VoidCallback onTap;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      tooltip: tooltip,
      semanticLabel: tooltip,
      selected: on,
      builder: (context, hover, focus) => Container(
        width: 24,
        height: 20,
        margin: const EdgeInsets.only(left: 1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? c.accSoft : (hover ? c.tile : null),
          borderRadius: BorderRadius.circular(5),
          border: on ? Border.all(color: c.acc.withValues(alpha: 0.6)) : null,
        ),
        child: Text(label, style: mono(11, weight: FontWeight.w600, color: on ? c.acc : c.text2, decoration: underline ? TextDecoration.underline : null)),
      ),
    );
  }
}
