import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/kumo_theme.dart';
import 'floating_panel.dart';

/// Shows [popoverBuilder] in the overlay, anchored to the trigger with a
/// LayerLink. Click outside or Esc closes it. Optional [openSignal] opens it
/// programmatically (e.g. from a keyboard shortcut).
///
/// With [floating], the popover isn't anchored: it opens centered in the
/// window over a dimmed background and can be dragged (see [FloatingPanel]).
class AnchoredPopover extends StatefulWidget {
  const AnchoredPopover({
    super.key,
    required this.triggerBuilder,
    required this.popoverBuilder,
    this.targetAnchor = Alignment.topRight,
    this.followerAnchor = Alignment.topLeft,
    this.offset = const Offset(12, -24),
    this.openSignal,
    this.floating = false,
    this.positionKey,
  });

  final Widget Function(BuildContext context, VoidCallback toggle, bool open) triggerBuilder;
  final Widget Function(BuildContext context, VoidCallback close) popoverBuilder;
  final Alignment targetAnchor;
  final Alignment followerAnchor;
  final Offset offset;
  final ValueListenable<int>? openSignal;
  final bool floating;

  /// Floating popovers with the same key reopen where the last one was left.
  final Object? positionKey;

  @override
  State<AnchoredPopover> createState() => _AnchoredPopoverState();
}

class _AnchoredPopoverState extends State<AnchoredPopover> {
  final _controller = OverlayPortalController();
  final _link = LayerLink();
  final _focus = FocusScopeNode(debugLabel: 'popover');

  @override
  void initState() {
    super.initState();
    widget.openSignal?.addListener(_open);
  }

  @override
  void didUpdateWidget(covariant AnchoredPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openSignal != widget.openSignal) {
      oldWidget.openSignal?.removeListener(_open);
      widget.openSignal?.addListener(_open);
    }
  }

  @override
  void dispose() {
    widget.openSignal?.removeListener(_open);
    _focus.dispose();
    super.dispose();
  }

  void _open() {
    if (_controller.isShowing) return;
    setState(_controller.show);
    // autofocus alone loses to whatever had focus (e.g. a terminal), and
    // then Esc wouldn't reach the popover.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.isShowing && !_focus.hasFocus) _focus.requestFocus();
    });
  }

  void _close() {
    if (_controller.isShowing) setState(_controller.hide);
  }

  void _toggle() => _controller.isShowing ? _close() : _open();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (context) {
          final popover = CallbackShortcuts(
            bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
            child: FocusScope(
              node: _focus,
              autofocus: true,
              child: Material(type: MaterialType.transparency, child: widget.popoverBuilder(context, _close)),
            ),
          );
          final c = context.c;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: widget.floating ? ColoredBox(color: c.isDark ? const Color(0x66000000) : const Color(0x33141428)) : null,
                ),
              ),
              if (widget.floating)
                Positioned.fill(child: FloatingPanel(positionKey: widget.positionKey, child: popover))
              else
                Positioned(
                  left: 0,
                  top: 0,
                  child: CompositedTransformFollower(
                    link: _link,
                    targetAnchor: widget.targetAnchor,
                    followerAnchor: widget.followerAnchor,
                    offset: widget.offset,
                    child: popover,
                  ),
                ),
            ],
          );
        },
        child: widget.triggerBuilder(context, _toggle, _controller.isShowing),
      ),
    );
  }
}
