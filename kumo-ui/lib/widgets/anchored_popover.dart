import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows [popoverBuilder] in the overlay, anchored to the trigger with a
/// LayerLink. Click outside or Esc closes it. Optional [openSignal] opens it
/// programmatically (e.g. from a keyboard shortcut).
class AnchoredPopover extends StatefulWidget {
  const AnchoredPopover({
    super.key,
    required this.triggerBuilder,
    required this.popoverBuilder,
    this.targetAnchor = Alignment.topRight,
    this.followerAnchor = Alignment.topLeft,
    this.offset = const Offset(12, -24),
    this.openSignal,
  });

  final Widget Function(BuildContext context, VoidCallback toggle, bool open) triggerBuilder;
  final Widget Function(BuildContext context, VoidCallback close) popoverBuilder;
  final Alignment targetAnchor;
  final Alignment followerAnchor;
  final Offset offset;
  final ValueListenable<int>? openSignal;

  @override
  State<AnchoredPopover> createState() => _AnchoredPopoverState();
}

class _AnchoredPopoverState extends State<AnchoredPopover> {
  final _controller = OverlayPortalController();
  final _link = LayerLink();

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
    super.dispose();
  }

  void _open() {
    if (!_controller.isShowing) setState(_controller.show);
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
        overlayChildBuilder: (context) => Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _close),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: _link,
                targetAnchor: widget.targetAnchor,
                followerAnchor: widget.followerAnchor,
                offset: widget.offset,
                child: CallbackShortcuts(
                  bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
                  child: FocusScope(
                    autofocus: true,
                    child: Material(type: MaterialType.transparency, child: widget.popoverBuilder(context, _close)),
                  ),
                ),
              ),
            ),
          ],
        ),
        child: widget.triggerBuilder(context, _toggle, _controller.isShowing),
      ),
    );
  }
}
