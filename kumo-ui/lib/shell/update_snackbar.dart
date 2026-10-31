import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';

/// "Kumo X is ready", bottom right, once Sparkle downloaded an update:
/// restart now, or close it. Closed, the toolbar keeps its "Restart to
/// update" and the update installs when Kumo quits; a newer one shows again.
class UpdateSnackbar extends StatefulWidget {
  const UpdateSnackbar({super.key});

  @override
  State<UpdateSnackbar> createState() => _UpdateSnackbarState();
}

class _UpdateSnackbarState extends State<UpdateSnackbar> {
  /// The version closed with the X.
  String? _closed;

  /// The version shown, kept while it fades away.
  String? _version;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final ready = s.updates.ready;
    final shown = ready != null && ready != _closed;
    if (shown) _version = ready;
    final version = _version;
    return Align(
      alignment: Alignment.bottomRight,
      // Above the status bar.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: IgnorePointer(
          ignoring: !shown,
          child: AnimatedSlide(
            offset: shown ? Offset.zero : const Offset(0, 0.4),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: shown ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              // Gone once it faded out.
              onEnd: () {
                if (!shown) setState(() => _version = null);
              },
              child: version == null
                  ? const SizedBox.shrink()
                  : Semantics(
                      liveRegion: true,
                      child: GlassOverlay(
                        width: 360,
                        radius: 14,
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(children: [
                          Icon(KIcons.download, size: 18, color: c.acc),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              Text('Kumo $version is ready', style: sans(13, weight: FontWeight.w600, color: c.text)),
                              const SizedBox(height: 2),
                              Text('Restarting closes terminals, or it installs on quit.', style: sans(12, color: c.text3)),
                            ]),
                          ),
                          const SizedBox(width: 10),
                          KButton.primary(label: 'Restart', height: 30, fontSize: 12.5, onTap: s.updates.installAndRelaunch),
                          const SizedBox(width: 2),
                          KIconButton(icon: KIcons.close, label: 'Not now', size: 26, iconSize: 13, color: c.text3, onTap: () => setState(() => _closed = version)),
                        ]),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
