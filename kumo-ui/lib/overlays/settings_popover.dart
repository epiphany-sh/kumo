import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../platform/window_effects.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';

/// Appearance: theme (Dark / Light / Hybrid), window translucency and the
/// painted demo wallpaper (handy when native translucency isn't available).
class SettingsPopover extends StatelessWidget {
  const SettingsPopover({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    return GlassOverlay(
      width: 300,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('Appearance', style: sans(14, weight: FontWeight.w600, color: c.text)),
        const SizedBox(height: 12),
        Text('Theme', style: sans(11, color: c.text3)),
        const SizedBox(height: 6),
        KSegmented<KumoThemeMode>(
          expand: true,
          label: 'Theme',
          value: s.mode,
          onChanged: (m) => s.mode = m,
          items: const [
            (KumoThemeMode.dark, 'Dark', null),
            (KumoThemeMode.light, 'Light', null),
            (KumoThemeMode.hybrid, 'Hybrid', null),
          ],
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Text('Window translucency', style: sans(12.5, color: c.text2))),
          Text('${(s.translucency * 100).round()}%', style: mono(11.5, color: c.text3)),
        ]),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: c.accFill,
            inactiveTrackColor: c.tile,
            thumbColor: const Color(0xFFFFFFFF),
            overlayColor: c.accSoft,
          ),
          child: Slider(
            value: s.translucency,
            min: 0.25,
            max: 0.9,
            onChanged: (v) => s.translucency = v,
            semanticFormatterCallback: (v) => 'Translucency ${(v * 100).round()} percent',
          ),
        ),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Demo wallpaper', style: sans(12.5, weight: FontWeight.w500, color: c.text)),
              Text(
                WindowEffects.nativeBackdrop ? 'Paint the canvas backdrop instead of the desktop' : 'Native translucency unavailable here',
                style: sans(11, color: c.text3),
              ),
            ]),
          ),
          KSwitch(value: s.demoWallpaper, onChanged: (_) => s.toggleDemoWallpaper(), label: 'Demo wallpaper'),
        ]),
      ]),
    );
  }
}
