import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A panel centered in its parent that the user can drag around by any
/// [FloatingPanelHandle] inside it. It always stays fully inside the parent
/// (scrolling when the parent is too short), and double-clicking a handle
/// centers it again.
///
/// With a [positionKey], where it was left is remembered for the next time
/// a panel with the same key opens.
class FloatingPanel extends StatefulWidget {
  const FloatingPanel({super.key, required this.child, this.positionKey, this.margin = 16});

  final Widget child;
  final Object? positionKey;

  /// Minimum gap to the parent's edges.
  final double margin;

  static final _remembered = <Object, Offset>{};

  @override
  State<FloatingPanel> createState() => _FloatingPanelState();
}

class _FloatingPanelState extends State<FloatingPanel> {
  final _child = GlobalKey();
  late Offset _offset = FloatingPanel._remembered[widget.positionKey] ?? Offset.zero;
  Size _parent = Size.zero;

  void _move(Offset delta) {
    final size = _child.currentContext?.size ?? Size.zero;
    setState(() => _offset = _clamp(_offset + delta, size));
  }

  void _center() => setState(() => _offset = Offset.zero);

  void _remember() {
    final key = widget.positionKey;
    if (key != null) FloatingPanel._remembered[key] = _offset;
  }

  /// Keeps the offset (from the centered position) inside the parent, so
  /// dragging past an edge doesn't build up a dead zone.
  Offset _clamp(Offset offset, Size child) {
    final dx = math.max(0.0, (_parent.width - child.width) / 2 - widget.margin);
    final dy = math.max(0.0, (_parent.height - child.height) / 2 - widget.margin);
    return Offset(offset.dx.clamp(-dx, dx), offset.dy.clamp(-dy, dy));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _parent = constraints.biggest;
      return _FloatingScope(
        state: this,
        child: CustomSingleChildLayout(
          delegate: _Layout(offset: _offset, margin: widget.margin),
          child: SingleChildScrollView(
            clipBehavior: Clip.none,
            child: KeyedSubtree(key: _child, child: widget.child),
          ),
        ),
      );
    });
  }
}

class _Layout extends SingleChildLayoutDelegate {
  _Layout({required this.offset, required this.margin});

  final Offset offset;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints.loose(
        Size(math.max(0, constraints.maxWidth - 2 * margin), math.max(0, constraints.maxHeight - 2 * margin)),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double place(double parent, double child, double shift) {
      final centered = (parent - child) / 2 + shift;
      return parent - child < 2 * margin ? margin : centered.clamp(margin, parent - child - margin);
    }

    return Offset(place(size.width, childSize.width, offset.dx), place(size.height, childSize.height, offset.dy));
  }

  @override
  bool shouldRelayout(_Layout old) => old.offset != offset || old.margin != margin;
}

class _FloatingScope extends InheritedWidget {
  const _FloatingScope({required this.state, required super.child});

  final _FloatingPanelState state;

  @override
  bool updateShouldNotify(_FloatingScope old) => old.state != state;
}

/// The part of a [FloatingPanel] that drags it (usually its header). Outside
/// a floating panel it's just [child].
class FloatingPanelHandle extends StatelessWidget {
  const FloatingPanelHandle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final panel = context.dependOnInheritedWidgetOfExactType<_FloatingScope>()?.state;
    if (panel == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Moves with the pointer from where it was pressed, slop included.
        dragStartBehavior: DragStartBehavior.down,
        onPanUpdate: (d) => panel._move(d.delta),
        onPanEnd: (_) => panel._remember(),
        onDoubleTap: () {
          panel._center();
          panel._remember();
        },
        child: child,
      ),
    );
  }
}
