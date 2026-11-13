import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../terminal/command_marks.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/controls.dart';

/// Settings → Appearance → Your lines in the terminal: the color swatches
/// (with a hex field for any other color) and a preview of both terminals.

/// Presets for a light terminal: the dark ones, darkened to read there.
List<(String, Color)> lightPresets() {
  final bg = terminalBackground(KumoPalette.light);
  return [for (final (name, color) in yourLinesPresets) (name, forLightTerminal(color, bg))];
}

/// "This one is hard to see here" when [color] doesn't have the contrast a
/// mark needs on [palette]'s terminal; null when it does.
String? lowContrastNote(Color color, KumoPalette palette) {
  final ratio = contrastRatio(color, terminalBackground(palette));
  if (ratio >= markContrast) return null;
  return 'This one is hard to see here: ${ratio.toStringAsFixed(1)}:1, aim for ${markContrast.toStringAsFixed(0)}:1.';
}

/// Ten swatches, then a hex field for a color of your own.
class MarkSwatches extends StatelessWidget {
  const MarkSwatches({super.key, required this.label, required this.presets, required this.value, required this.onChanged});

  final String label;
  final List<(String, Color)> presets;
  final Color value;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final preset = presets.any((p) => p.$2.toARGB32() == value.toARGB32());
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      SizedBox(
        width: 150,
        child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
          for (final (name, color) in presets)
            _Swatch(color: color, name: name, selected: color.toARGB32() == value.toARGB32(), onTap: () => onChanged(color)),
        ]),
      ),
      const SizedBox(height: 10),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Custom', style: sans(11.5, color: c.text3)),
        const SizedBox(width: 8),
        if (!preset) ...[
          _Swatch(color: value, name: 'Your color', selected: true, onTap: null),
          const SizedBox(width: 8),
        ],
        _HexField(label: '$label, hex', value: value, onChanged: onChanged),
      ]),
    ]);
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.name, required this.selected, required this.onTap});
  final Color color;
  final String name;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      semanticLabel: name,
      tooltip: '$name  ${hexOf(color)}',
      selected: selected,
      builder: (context, hover, focus) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? c.text : (hover || focus ? c.text3 : const Color(0x00000000)), width: 2),
        ),
      ),
    );
  }
}

/// `#RRGGBB`: a valid one applies as you type; anything else gets a red
/// border and changes nothing.
class _HexField extends StatefulWidget {
  const _HexField({required this.label, required this.value, required this.onChanged});
  final String label;
  final Color value;
  final ValueChanged<Color> onChanged;

  @override
  State<_HexField> createState() => _HexFieldState();
}

class _HexFieldState extends State<_HexField> {
  late final _ctrl = TextEditingController(text: hexOf(widget.value));
  final _focus = FocusNode();

  @override
  void didUpdateWidget(_HexField old) {
    super.didUpdateWidget(old);
    // A swatch picked elsewhere shows here, unless you're typing.
    if (!_focus.hasFocus && parseHexColor(_ctrl.text)?.toARGB32() != widget.value.toARGB32()) _ctrl.text = hexOf(widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ok = parseHexColor(_ctrl.text) != null;
    return Container(
      width: 84,
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(8), border: Border.all(color: ok ? c.chipBorder : c.err)),
      child: Semantics(
        label: widget.label,
        textField: true,
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          inputFormatters: [LengthLimitingTextInputFormatter(7)],
          style: mono(12, color: c.text),
          cursorColor: c.acc,
          decoration: const InputDecoration.collapsed(hintText: '#RRGGBB'),
          onChanged: (text) {
            setState(() {});
            final color = parseHexColor(text);
            if (color != null) widget.onChanged(color);
          },
        ),
      ),
    );
  }
}

/// What your lines look like on a dark and on a light terminal, with
/// these settings.
class YourLinesPreview extends StatelessWidget {
  const YourLinesPreview({super.key, required this.lines});
  final YourLines lines;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final (label, palette) in [('Dark terminal', KumoPalette.dark), ('Light terminal', KumoPalette.light)]) ...[
        Text('$label · ${hexOf(lines.colorFor(palette))}', style: sans(11, color: c.text3)),
        const SizedBox(height: 4),
        _MiniTerminal(lines: lines, palette: palette),
        const SizedBox(height: 8),
      ],
    ]);
  }
}

class _MiniTerminal extends StatelessWidget {
  const _MiniTerminal({required this.lines, required this.palette});
  final YourLines lines;
  final KumoPalette palette;

  /// A [command] you ran (with its [mark] when marks are on), or output.
  Widget _line(String text, {bool command = false, Color? mark, String? meta, Color? color}) {
    final style = mono(11.5, color: color ?? (command ? palette.text : palette.text2), height: 1.4);
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: mark == null
          ? null
          : BoxDecoration(
              color: lines.band ? mark.withValues(alpha: lines.bandAlpha) : null,
              border: Border(left: BorderSide(color: mark, width: lines.bar)),
            ),
      child: Row(children: [
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        if (meta != null) Text(meta, style: mono(10.5, color: mark ?? palette.text3, height: 1.4)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final on = lines.marks;
    final mine = on ? lines.colorFor(palette) : null;
    final failed = on ? palette.err : null;
    return Container(
      width: 300,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: terminalBackground(palette),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.paneBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _line('❯ git pull --rebase', command: true, mark: mine),
        _line('Already up to date.'),
        _line('❯ go test ./kafka/...', command: true, mark: failed, meta: on && lines.meta ? 'exit 1 · 12s' : null),
        _line('--- FAIL: TestConsumerRebalance (12.04s)', color: palette.err),
      ]),
    );
  }
}
